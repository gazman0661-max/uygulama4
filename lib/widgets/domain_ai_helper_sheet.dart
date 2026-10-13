import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../localization/app_strings.dart';
import '../screens/ai_settings_screen.dart';
import '../services/ai_key_store.dart';
import '../services/ai_prompts.dart';
import '../services/gemini_service.dart';
import '../services/image_compress_service.dart';

/// 06.10.2026 eklendi (kanka isteği) — "Domain Bağlama Asistanı".
/// Kullanıcının KENDİ Gemini anahtarını kullanır (site üretimiyle aynı anahtar/model),
/// ama kendi sistem promptu ve kendi sohbet geçmişi vardır; site üretimiyle karışmaz.
/// Ekran görüntüleri gönderilmeden önce WebP'ye küçültülür (ImageCompressService).
Future<void> showDomainAiHelperSheet(
  BuildContext context, {
  required String domain,
  required String cnameName,
  required String cnameValue,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DomainAiHelperSheet(domain: domain, cnameName: cnameName, cnameValue: cnameValue),
  );
}

class _Msg {
  final String role; // 'user' | 'model'
  final String text;
  final Uint8List? image;
  final String? mime;
  final bool local; // true: yerel karşılama mesajı, API'ye gönderilmez
  const _Msg(this.role, this.text, {this.image, this.mime, this.local = false});
}

class _DomainAiHelperSheet extends StatefulWidget {
  const _DomainAiHelperSheet({required this.domain, required this.cnameName, required this.cnameValue});
  final String domain, cnameName, cnameValue;
  @override
  State<_DomainAiHelperSheet> createState() => _DomainAiHelperSheetState();
}

class _DomainAiHelperSheetState extends State<_DomainAiHelperSheet> {
  static const _providers = ['Natro', 'İsimtescil', 'Turhost', 'GoDaddy', 'Namecheap', 'Diğer'];
  static const _maxHistory = 16;
  static const _maxImagesSent = 2; // eski görseller tekrar tekrar gönderilmesin

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  GeminiService? _svc;
  String? _model;
  String _provider = '';
  bool _loadingKey = true, _busy = false;
  String _error = '';
  Uint8List? _pendingImage;
  String? _pendingMime;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
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

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen()));
    if (mounted) _loadKey();
  }

  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (x == null) return;
      final raw = await x.readAsBytes();
      // isPng:false -> PNG ekran görüntüleri de WebP'ye çevrilsin (yazılar okunur kalsın diye q75).
      final c = await ImageCompressService.compress(raw, isPng: false, maxWidth: 1280, quality: 75);
      if (!mounted) return;
      setState(() {
        _pendingImage = c.bytes;
        _pendingMime = c.mime == 'image/jpeg' ? 'image/jpeg' : c.mime;
      });
    } catch (_) {
      if (mounted) setState(() => _error = t(context, 'Görsel seçilemedi. Tekrar dene.'));
    }
  }

  List<Map<String, String>> _apiHistory() {
    var list = _msgs.where((m) => !m.local).toList();
    if (list.length > _maxHistory) list = list.sublist(list.length - _maxHistory);
    while (list.isNotEmpty && list.first.role != 'user') {
      list = list.sublist(1);
    }
    var imagesLeft = _maxImagesSent;
    final withImg = <int>{};
    for (var i = list.length - 1; i >= 0 && imagesLeft > 0; i--) {
      if (list[i].image != null) {
        withImg.add(i);
        imagesLeft--;
      }
    }
    return [
      for (var i = 0; i < list.length; i++)
        {
          'role': list[i].role,
          'text': list[i].text.isEmpty ? '(ekran görüntüsü)' : list[i].text,
          if (withImg.contains(i)) 'imageB64': base64Encode(list[i].image!),
          if (withImg.contains(i)) 'imageMime': list[i].mime ?? 'image/webp',
        },
    ];
  }

  Future<void> _send() async {
    final svc = _svc, model = _model;
    final text = _ctrl.text.trim();
    if (svc == null || model == null || _busy) return;
    if (text.isEmpty && _pendingImage == null) return;
    setState(() {
      _msgs.add(_Msg('user', text, image: _pendingImage, mime: _pendingMime));
      _ctrl.clear();
      _pendingImage = null;
      _pendingMime = null;
      _busy = true;
      _error = '';
    });
    _toBottom();
    try {
      final reply = await svc.generate(
        model: model,
        system: AiPrompts.domainHelper(
          domain: widget.domain,
          cnameName: widget.cnameName,
          cnameValue: widget.cnameValue,
          provider: _provider == 'Diğer' ? '' : _provider,
          english: isEnglish(context),
        ),
        history: _apiHistory(),
      );
      if (!mounted) return;
      setState(() => _msgs.add(_Msg('model', reply.trim())));
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final greeting = _Msg(
      'model',
      t(context,
          'Merhaba! Ben domain bağlama asistanınım. Domainini nereden aldığını seç, sonra istersen paneldeki ekranın görüntüsünü at; nereye tıklayacağını söyleyeyim.'),
      local: true,
    );
    final shown = [greeting, ..._msgs];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _loadingKey
            ? const Center(child: CircularProgressIndicator())
            : _svc == null
                ? _noKey(cs)
                : Column(
                    children: [
                      _header(cs),
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          itemCount: shown.length + (_busy ? 1 : 0),
                          itemBuilder: (_, i) => i >= shown.length ? _typing(cs) : _bubble(shown[i], cs),
                        ),
                      ),
                      if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: Text(_error, style: TextStyle(color: cs.error, fontSize: 12.5)),
                        ),
                      _composer(cs),
                    ],
                  ),
      ),
    );
  }

  Widget _header(ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.support_agent, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t(context, 'Domain Asistanı'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ]),
            Wrap(
              spacing: 6,
              children: [
                for (final p in _providers)
                  ChoiceChip(
                    label: Text(p),
                    selected: _provider == p,
                    onSelected: (v) => setState(() => _provider = v ? p : ''),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _bubble(_Msg m, ColorScheme cs) {
    final me = m.role == 'user';
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: me ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(m.image!, height: 140, fit: BoxFit.cover),
                ),
              ),
            if (m.text.isNotEmpty) SelectableText(m.text, style: const TextStyle(fontSize: 14, height: 1.35)),
          ],
        ),
      ),
    );
  }

  Widget _typing(ColorScheme cs) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
        ),
      );

  Widget _composer(ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingImage != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 4),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_pendingImage!, height: 64),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => setState(() {
                          _pendingImage = null;
                          _pendingMime = null;
                        }),
                        child: const CircleAvatar(radius: 10, child: Icon(Icons.close, size: 12)),
                      ),
                    ),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t(context, 'Ekran görüntüsünde şifre, e-posta veya kart bilgisi varsa kapatıp gönder.'),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            Row(children: [
              IconButton(
                tooltip: t(context, 'Ekran görüntüsü ekle'),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _busy ? null : _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: t(context, 'Nerede takıldın?'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _busy ? null : _send),
            ]),
          ],
        ),
      );

  Widget _noKey(ColorScheme cs) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vpn_key_outlined, size: 40, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              t(context, 'Asistanı kullanmak için önce yapay zekâ anahtarını eklemen gerekiyor. Site üretiminde kullandığın anahtar burada da geçerli.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _openSettings, child: Text(t(context, 'Anahtar ekle'))),
          ],
        ),
      );
}
