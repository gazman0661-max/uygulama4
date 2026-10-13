import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_strings.dart';
import '../services/ai_key_store.dart';
import '../services/gemini_service.dart';
import '../widgets/gemini_key_guide.dart';

/// Yapay zekâ ayarları: kendi Gemini API anahtarını gir, model seç.
/// Anahtar yapıştırılınca otomatik doğrulanır ve modeller çekilir.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

enum _KeyState { idle, checking, ok, error }

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _ctrl = TextEditingController();
  bool _hide = true;
  _KeyState _state = _KeyState.idle;
  String _error = '';
  List<GeminiModel> _models = [];
  String? _selected;
  bool _showAll = false;
  Timer? _debounce;
  bool _hadSaved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final k = await AiKeyStore.readKey();
    final m = await AiKeyStore.readModel();
    if (k == null || !mounted) return;
    _hadSaved = true;
    _ctrl.text = k;
    _selected = m;
    await _verify();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 30) {
      setState(() => _state = _KeyState.idle);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 700), _verify);
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final v = d?.text?.trim() ?? '';
    if (v.isEmpty) return;
    _ctrl.text = v;
    await _verify();
  }

  Future<void> _verify() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _state = _KeyState.checking;
      _error = '';
    });
    try {
      final list = await GeminiService(key).listModels();
      if (!mounted || key != _ctrl.text.trim()) return;
      final rec = GeminiService.recommended(list);
      setState(() {
        _models = list;
        _state = _KeyState.ok;
        if (_selected == null || !list.any((m) => m.id == _selected)) _selected = rec?.id;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _KeyState.error;
        _error = e.message;
        _models = [];
      });
    }
  }

  Future<void> _save() async {
    if (_state != _KeyState.ok || _selected == null) return;
    await AiKeyStore.saveKey(_ctrl.text);
    await AiKeyStore.saveModel(_selected!);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t(context, 'Anahtar silinsin mi?')),
        content: Text(t(context, 'Anahtar bu cihazdan kaldırılır. AI ile site oluşturmak için tekrar eklemen gerekir.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t(context, 'Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t(context, 'Sil'), style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    await AiKeyStore.deleteKey();
    if (!mounted) return;
    setState(() {
      _ctrl.clear();
      _models = [];
      _selected = null;
      _hadSaved = false;
      _state = _KeyState.idle;
    });
  }

  List<GeminiModel> get _featured {
    final byTag = <String, GeminiModel>{};
    final rec = GeminiService.recommended(_models);
    if (rec != null) byTag[rec.tag] = rec;
    for (final tag in ['Gelişmiş', 'En hızlı']) {
      final c = _models.where((m) => m.tag == tag && !m.isPreview).toList()..sort((a, b) => b.id.compareTo(a.id));
      if (c.isNotEmpty) byTag[tag] = c.first;
    }
    return byTag.values.toList();
  }

  Widget _modelCard(GeminiModel m, {required bool recommended}) {
    final cs = Theme.of(context).colorScheme;
    final sel = _selected == m.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selected = m.id),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? cs.primary : cs.outlineVariant, width: sel ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              if (sel) Icon(Icons.check_circle, color: cs.primary, size: 20),
            ]),
            const SizedBox(height: 4),
            Text(t(context, m.description), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (recommended) _chip(t(context, 'Önerilen'), Colors.green),
              _chip(t(context, m.tag), cs.onSurfaceVariant),
              if (m.isPreview) _chip(t(context, 'Deneme sürümü'), Colors.orange),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(s, style: TextStyle(fontSize: 12, color: c)),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rec = GeminiService.recommended(_models);
    final shown = _showAll ? (_models.toList()..sort((a, b) => a.id.compareTo(b.id))) : _featured;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'Yapay zekâ ayarları'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // Anahtar henüz doğrulanmadıysa: adım adım anlatım + anahtar sayfasını açan düğme.
          if (_state != _KeyState.ok) ...[
            const GeminiKeyGuideCard(),
            const SizedBox(height: 16),
          ],
          Text(t(context, 'API anahtarı (Google Gemini)'), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            obscureText: _hide,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: _onChanged,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'AIza...',
              border: const OutlineInputBorder(),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide)),
                IconButton(icon: const Icon(Icons.content_paste), tooltip: t(context, 'Yapıştır'), onPressed: _paste),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          if (_state == _KeyState.checking)
            Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text(t(context, 'Anahtar kontrol ediliyor…'), style: const TextStyle(fontSize: 13)),
            ]),
          if (_state == _KeyState.ok)
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text('${t(context, 'Anahtar doğrulandı')}, ${_models.length} ${t(context, 'model bulundu')}', style: const TextStyle(fontSize: 13, color: Colors.green))),
            ]),
          if (_state == _KeyState.error)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(t(context, _error), style: const TextStyle(fontSize: 13, color: Colors.redAccent))),
            ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(t(context, 'Anahtar sadece bu cihazda saklanır. Sunucumuza gönderilmez.'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
          ]),
          const SizedBox(height: 4),
          Text(
            t(context, 'Not: Yazdıkların ve oluşturulan içerik, yapay zekâ üretimi için Google\'a gönderilir.'),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          if (_state == _KeyState.ok)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => showGeminiKeyGuideSheet(context),
                child: Text(t(context, 'Anahtarı nasıl alırım?')),
              ),
            ),
          if (_state == _KeyState.ok) ...[
            const SizedBox(height: 8),
            Text(t(context, 'Model'), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final m in shown) _modelCard(m, recommended: rec != null && m.id == rec.id),
            TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
              label: Text(t(context, _showAll ? 'Önerilenleri göster' : 'Tüm modelleri göster')),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: FilledButton(onPressed: _state == _KeyState.ok && _selected != null ? _save : null, child: Text(t(context, 'Kaydet'))),
          ),
          if (_hadSaved) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: _delete,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                child: Text(t(context, 'Anahtarı sil')),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
