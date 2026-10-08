import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../screens/ai_settings_screen.dart';
import '../services/ai_key_store.dart';
import '../services/ai_prompts.dart';
import '../services/gemini_service.dart';
import '../services/report_service.dart' show ReportSource;
import '../widgets/report_dialog.dart';
import 'ai_site_builder.dart';
import 'ai_site_editor.dart';
import 'free_model.dart';

/// "AI ile düzenle": komutu alır, değişiklik ÖNİZLEMESİ gösterir, kullanıcı "Uygula" derse
/// değiştirilmiş site kopyasını döndürür (null = vazgeçti). Geri alma çağıran tarafta.
///
/// 06.10.2026 (kanka isteği): "Yeni sayfa" sekmesi — AI mevcut siteye yeni bir sayfa üretir.
/// [canAddPage] verilirse (builder'ın plan/sayfa sınırı kapısı) yeni sayfa üretilmeden ÖNCE çağrılır;
/// false dönerse (limit dolu / kilitli) AI'a istek gitmez.
Future<FreeSite?> showAiEditSheet(BuildContext context,
    {required FreeSite site, required int pageIndex, Future<bool> Function()? canAddPage}) {
  return showModalBottomSheet<FreeSite>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AiEditSheet(site: site, pageIndex: pageIndex, canAddPage: canAddPage),
  );
}

class _AiEditSheet extends StatefulWidget {
  const _AiEditSheet({required this.site, required this.pageIndex, this.canAddPage});
  final FreeSite site;
  final int pageIndex;
  final Future<bool> Function()? canAddPage;
  @override
  State<_AiEditSheet> createState() => _AiEditSheetState();
}

class _AiEditSheetState extends State<_AiEditSheet> {
  final _ctrl = TextEditingController();
  GeminiService? _svc;
  String? _model;
  bool _loadingKey = true, _busy = false;
  bool _newPage = false; // false: açık sayfayı düzenle, true: AI ile yeni sayfa üret
  String _error = '', _rawResponse = '', _lastPrompt = '';
  AiEditResult? _result;

  static const _chips = ['Daha lüks göster', 'Koyu tema yap', 'Başlığı daha çarpıcı yaz', 'SSS bölümü ekle', 'Çalışma saatleri ekle'];
  static const _pageChips = ['Hakkımızda sayfası', 'Fiyatlar sayfası', 'SSS sayfası', 'Hizmetlerimiz sayfası', 'Sık sorulan sorular ve çalışma saatleri'];

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final k = await AiKeyStore.readKey(), m = await AiKeyStore.readModel();
    if (!mounted) return;
    setState(() {
      _svc = (k != null && m != null) ? GeminiService(k) : null;
      _model = m;
      _loadingKey = false;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy || _svc == null) return;
    if (_newPage && widget.canAddPage != null && !await widget.canAddPage!()) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = '';
      _result = null;
      _lastPrompt = text;
    });
    try {
      final String raw;
      final AiEditResult res;
      if (_newPage) {
        final ctx = AiSiteEditor.describeForNewPage(widget.site);
        raw = await _svc!.generate(
          model: _model!,
          system: AiPrompts.page,
          history: [
            {'role': 'user', 'text': 'Mevcut site:\n$ctx\n\nYeni sayfa isteği: $text'},
          ],
          json: true,
        );
        res = AiSiteEditor.addPage(widget.site, AiSiteBuilder.parse(raw));
      } else {
        final desc = AiSiteEditor.describe(widget.site, widget.pageIndex);
        raw = await _svc!.generate(
          model: _model!,
          system: AiPrompts.edit,
          history: [
            {'role': 'user', 'text': 'Mevcut site:\n$desc\n\nİstek: $text'},
          ],
          json: true,
        );
        res = AiSiteEditor.apply(widget.site, widget.pageIndex, AiSiteBuilder.parse(raw));
      }
      if (!mounted) return;
      setState(() {
        _result = res;
        _rawResponse = raw;
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FormatException {
      if (mounted) setState(() => _error = t(context, 'Yapay zekâ yanıtı okunamadı. İsteği biraz değiştirip tekrar dene.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _result;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(t(context, _newPage ? 'AI ile yeni sayfa' : 'AI ile düzenle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            if (r != null)
              IconButton(
                tooltip: t(context, 'Bu içeriği bildir'),
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => showReportDialog(
                  context: context,
                  source: ReportSource.general,
                  chatContext: '[AI düzenleme]\nİstek: $_lastPrompt\n\nAI yanıtı:\n$_rawResponse',
                ),
              ),
          ]),
          const SizedBox(height: 10),
          if (_loadingKey)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_svc == null) ...[
            Text(t(context, 'AI ile düzenlemek için önce kendi Gemini anahtarını ekle.')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen()));
                await _loadKey();
              },
              child: Text(t(context, 'Anahtarı ekle')),
            ),
          ] else if (r == null) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(t(context, 'Bu sayfayı düzenle'), style: const TextStyle(fontSize: 12.5))),
                ButtonSegment(value: true, label: Text(t(context, 'Yeni sayfa ekle'), style: const TextStyle(fontSize: 12.5))),
              ],
              selected: {_newPage},
              onSelectionChanged: _busy ? null : (v) => setState(() { _newPage = v.first; _error = ''; }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              minLines: 2,
              maxLines: 5,
              enabled: !_busy,
              decoration: InputDecoration(hintText: t(context, _newPage ? 'Nasıl bir sayfa istiyorsun? Örn: Fiyatlar sayfası' : 'Ne değiştirmek istiyorsun? Örn: Başlığı daha lüks yaz'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in (_newPage ? _pageChips : _chips)) ActionChip(label: Text(t(context, c), style: const TextStyle(fontSize: 12)), onPressed: _busy ? null : () => setState(() => _ctrl.text = c)),
            ]),
            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t(context, _error), style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _busy ? null : _run,
                child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t(context, 'Önizle')),
              ),
            ),
            const SizedBox(height: 6),
            Text(t(context, 'Fotoğrafların yapay zekâya gönderilmez. Metinler Google\'a gönderilir.'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ] else ...[
            if (r.summary.isNotEmpty) Text(r.summary, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            if (r.changes.isEmpty && r.refused.isEmpty) Text(t(context, 'Bu istekle bir değişiklik yapılmadı.'), style: TextStyle(color: cs.onSurfaceVariant)),
            for (final c in r.changes.take(12))
              Padding(padding: const EdgeInsets.only(bottom: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• '), Expanded(child: Text(c, style: const TextStyle(fontSize: 13)))])),
            if (r.refused.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r.refused, style: const TextStyle(fontSize: 13, color: Colors.orange))),
                ]),
              ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _result = null), child: Text(t(context, 'Tekrar dene')))),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: r.changes.isEmpty ? null : () => Navigator.of(context).pop(r.site),
                  child: Text(t(context, 'Uygula')),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(t(context, 'Uyguladıktan sonra üstteki geri al düğmesiyle eski haline dönebilirsin.'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}
