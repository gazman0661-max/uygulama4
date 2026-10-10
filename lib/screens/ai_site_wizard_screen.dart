import 'package:flutter/material.dart';
import '../free/ai_site_builder.dart';
import '../localization/app_strings.dart';
import '../services/ai_key_store.dart';
import '../services/ai_prompts.dart';
import '../services/gemini_service.dart';
import '../widgets/location_picker_field.dart';
import '../widgets/report_dialog.dart';
import '../services/report_service.dart' show ReportSource;
import 'ai_settings_screen.dart';
import 'free_builder_screen.dart';

class _Msg {
  final bool user;
  final String text;
  _Msg(this.user, this.text);
}

/// Sohbetle site oluşturma: kısa bir görüşme yapar, sonra sonucu düzenlenebilir
/// sürükle-bırak builder'da açar. AI yalnızca içerik üretir; yerleşim uygulamadadır.
class AiSiteWizardScreen extends StatefulWidget {
  const AiSiteWizardScreen({super.key});
  @override
  State<AiSiteWizardScreen> createState() => _AiSiteWizardScreenState();
}

class _AiSiteWizardScreenState extends State<AiSiteWizardScreen> {
  final _msgs = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  GeminiService? _svc;
  String? _model;
  bool _loading = true; // anahtar kontrolü
  bool _busy = false; // yapay zekâ yanıtı bekleniyor
  bool _ready = false; // yeterli bilgi toplandı
  String _error = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final k = await AiKeyStore.readKey();
    final m = await AiKeyStore.readModel();
    if (!mounted) return;
    setState(() {
      _svc = (k != null && m != null) ? GeminiService(k) : null;
      _model = m;
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen()));
    await _init();
  }

  List<Map<String, String>> get _history => [
        for (final m in _msgs) {'role': m.user ? 'user' : 'model', 'text': m.text},
      ];

  /// Sohbet dökümü (rapor bağlamı): son ~3000 karakter.
  String get _transcript {
    final s = _msgs.map((m) => '${m.user ? 'Kullanıcı' : 'AI'}: ${m.text}').join('\n');
    return s.length > 3000 ? s.substring(s.length - 3000) : s;
  }

  void _report({String? reply}) => showReportDialog(
        context: context,
        source: ReportSource.general,
        chatContext: '[AI site sihirbazı]\n${reply == null ? _transcript : 'Bildirilen AI yanıtı: $reply\n\n--- Sohbet ---\n$_transcript'}',
      );

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy || _svc == null) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
      _error = '';
    });
    _toEnd();
    try {
      final reply = await _svc!.generate(model: _model!, system: AiPrompts.chat, history: _history);
      final done = reply.contains(AiPrompts.readyMarker);
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg(false, reply.replaceAll(AiPrompts.readyMarker, '').trim()));
        if (done) _ready = true;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _msgs.removeLast(); // başarısız mesajı geri al, kullanıcı tekrar gönderebilsin
        _input.text = text;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _toEnd();
    }
  }

  Future<void> _generate() async {
    final contact = await _askContact();
    if (contact == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final hist = [
        ..._history,
        {'role': 'user', 'text': 'Görüşme bitti. Şemaya uygun JSON sitesini oluştur.'},
      ];
      final raw = await _svc!.generate(model: _model!, system: AiPrompts.generate, history: hist, json: true);
      final site = AiSiteBuilder.build(
        AiSiteBuilder.parse(raw),
        phone: contact['phone'] as String,
        whatsapp: contact['wa'] as String,
        instagram: contact['ig'] as String,
        mapAddress: (contact['mapAddress'] as String?) ?? '',
        mapLat: contact['lat'] as double?,
        mapLng: contact['lng'] as double?,
        lang: isEnglish(context) ? 'en' : 'tr',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => FreeBuilderScreen(initialData: {'freeSite': site.toJson()}, aiReportContext: '${_transcript}\n\n--- Üretilen JSON ---\n$raw'),
      ));
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FormatException {
      if (mounted) setState(() => _error = t(context, 'Site taslağı okunamadı. "Siteyi oluştur"a tekrar bas.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Telefon / WhatsApp / Instagram AI'dan değil, ayrı form alanlarından alınır.
  Future<Map<String, dynamic>?> _askContact() {
    String mapAddress = '';
    double? lat, lng;
    final phone = TextEditingController(), wa = TextEditingController(), ig = TextEditingController();
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SingleChildScrollView(
       child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t(context, 'İletişim bilgilerin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(t(context, 'Boş bırakabilirsin. Sonradan builder\'dan ekleyebilirsin.'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t(context, 'Telefon'), hintText: '+90 5xx xxx xx xx', border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: wa, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'WhatsApp', hintText: '905xxxxxxxxx', border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: ig, decoration: InputDecoration(labelText: 'Instagram', hintText: t(context, 'kullanici_adi'), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          Text(t(context, 'Haritada konumun (isteğe bağlı)'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          LocationPickerField(onChanged: (a, la, ln) {
            mapAddress = a;
            lat = la;
            lng = ln;
          }),
          const SizedBox(height: 4),
          Text(t(context, 'Harita sadece premium paketlerde yayınlanır.'), style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: () => Navigator.pop(c, <String, dynamic>{
                'phone': phone.text.trim(),
                'wa': wa.text.trim(),
                'ig': ig.text.trim().replaceAll('@', ''),
                'mapAddress': mapAddress,
                'lat': lat,
                'lng': lng,
              }),
              child: Text(t(context, 'Siteyi oluştur')),
            ),
          ),
        ]),
       ),
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'AI ile site oluştur')),
        actions: [
          if (_msgs.isNotEmpty) IconButton(icon: const Icon(Icons.flag_outlined), tooltip: t(context, 'Bu içeriği bildir'), onPressed: _report),
          IconButton(icon: const Icon(Icons.tune), tooltip: t(context, 'Yapay zekâ ayarları'), onPressed: _openSettings)],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _svc == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome, size: 40),
                        const SizedBox(height: 12),
                        Text(t(context, 'Önce kendi Gemini anahtarını ekle'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(t(context, 'Yapay zekâ kullanımı senin anahtarından yapılır. Biz sadece yayın ve hosting için ücret alırız.'), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _openSettings, child: Text(t(context, 'Anahtarı ekle'))),
                      ]),
                    ),
                  )
                : Column(children: [
                    Expanded(
                      child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
                        _bubble(false, t(context, 'Merhaba! Nasıl bir site yapmak istiyorsun? İşletmeni kısaca anlat.'), cs),
                        for (final m in _msgs) _bubble(m.user, m.text, cs, onReport: m.user ? null : () => _report(reply: m.text)),
                        if (_busy) Padding(padding: const EdgeInsets.all(8), child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
                        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t(context, _error), style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                      ]),
                    ),
                    if (_ready || _msgs.where((m) => m.user).length >= 3)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _generate,
                            icon: const Icon(Icons.auto_awesome),
                            label: Text(t(context, 'Siteyi oluştur')),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(hintText: t(context, 'Mesajını yaz…'), border: const OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
                      ]),
                    ),
                  ]),
      ),
    );
  }

  Widget _bubble(bool user, String text, ColorScheme cs, {VoidCallback? onReport}) => Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: user ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(text, style: const TextStyle(fontSize: 15)),
            if (onReport != null)
              InkWell(
                onTap: onReport,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.flag_outlined, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(t(context, 'Bildir'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ]),
                ),
              ),
          ]),
        ),
      );
}
