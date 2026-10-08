import 'dart:convert';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../screens/ai_settings_screen.dart';
import '../services/ai_key_store.dart';
import '../services/gemini_service.dart';
import '../services/report_service.dart' show ReportSource;
import 'report_dialog.dart';

/// 08.10.2026 (kanka isteği) — Sektör formlarında "AI ile doldur".
///
/// Kullanıcı işletmesini 1-2 cümleyle anlatır; kendi Gemini anahtarıyla (bkz. AiKeyStore) slogan,
/// hakkında, hizmetler, SSS gibi METİN alanları profesyonelce yazılır. Sonuç ÖNCE önizlenir, alan alan
/// seçilir ve "Uygula" ile forma yazılır; kullanıcı yine elle düzenleyebilir. Hiçbir şey otomatik kaydedilmez.
///
/// BİLEREK doldurulmayanlar (uydurma/yasal risk): müşteri yorumları, sertifika/unvan rozetleri, fiyat,
/// telefon, adres, çalışma saatleri, menü fiyatları, deneyim yılı/rakam.
class AiFormFillCard extends StatelessWidget {
  const AiFormFillCard({
    super.key,
    required this.sector,
    required this.fields,
    required this.siteLang,
    this.name,
    this.title,
    this.extra = const {},
    this.regulated = false,
    this.firstPerson = false,
    this.onApplied,
  });

  /// Sektör adı (TR), prompt'a girer. Örn. "Kuaför".
  final String sector;

  /// Alan anahtarı -> controller. Desteklenen anahtarlar: tagline, about, bio, shortbio, services, faq, skills.
  final Map<String, TextEditingController> fields;
  final String siteLang; // 'tr' | 'en'
  final TextEditingController? name;
  final TextEditingController? title;

  /// Ek bağlam: etiket -> controller (örn. 'Şirket' -> _companyCtrl).
  final Map<String, TextEditingController> extra;

  /// Reklam kısıtı olan meslekler (avukat, hekim, diş hekimi, diyetisyen, veteriner, klinik).
  final bool regulated;

  /// true: "hakkında" metni birinci tekil ("ben") yazılır (serbest meslek / kişisel site). false: "biz".
  final bool firstPerson;
  final VoidCallback? onApplied;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: cs.tertiaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _AiFillSheet(card: this),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(Icons.auto_awesome, size: 28, color: cs.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t(context, 'AI ile doldur'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    t(context, 'İşletmeni 1-2 cümleyle anlat; slogan, hakkında ve hizmetleri profesyonelce yazsın.'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FieldSpec {
  final String label; // TR, kullanıcıya gösterilir
  final String rule; // prompt kuralı
  final int maxLen; // 0 = sınırsız
  const _FieldSpec(this.label, this.rule, {this.maxLen = 0});
}

const Map<String, _FieldSpec> _specs = {
  'tagline': _FieldSpec(
    'Slogan',
    'En fazla 60 karakter, tek kısa cümle, sonunda nokta yok. Kalıp reklam sloganı yerine somut bir fayda veya karakter söyle.',
    maxLen: 70,
  ),
  'about': _FieldSpec(
    'Hakkında',
    'Tek paragraf, 3-5 cümle, yaklaşık 55-90 kelime. Akış: (1) kim olduğun ve ne yaptığın, (2) çalışma yaklaşımı / '
        'müşteriye değeri, (3) davet veya güven veren sakin bir kapanış. Somut ve akıcı yaz; her cümle yeni bir bilgi versin.',
  ),
  'bio': _FieldSpec(
    'Kısa özgeçmiş',
    'Üçüncü tekil şahıs, 2-3 cümle, 40-70 kelime. Uzmanlık alanını ve çalışma yaklaşımını anlat; yalnızca verilen bilgileri kullan.',
  ),
  'shortbio': _FieldSpec(
    'Kısa açıklama',
    'Tek cümle, EN FAZLA 100 karakter, kişinin ne yaptığını söyle.',
    maxLen: 100,
  ),
  'services': _FieldSpec(
    'Hizmetler',
    'Her satıra YALNIZCA bir hizmet adı (2-4 kelime), 5-8 satır. Fiyat, süre, tire veya numara YAZMA. '
        'Sektörde gerçekten verilen, birbirinden farklı hizmetleri seç.',
  ),
  'faq': _FieldSpec(
    'Sık sorulan sorular',
    'Her satır "Soru | Cevap" biçiminde, 4 satır. Cevaplar kısa ve genel olsun; fiyat, saat, adres, rakam veya doğrulanamaz iddia '
        'içermesin. Kesin bilgi gereken yerde "Detaylar için bizimle iletişime geçebilirsiniz." gibi yönlendir.',
  ),
  'skills': _FieldSpec(
    'Yetenekler',
    'Virgülle ayrılmış 6-10 kısa yetenek/etiket. Yalnızca kullanıcının anlattığı bilgilerden makul biçimde çıkarılabilenleri yaz.',
  ),
};

class _AiFillSheet extends StatefulWidget {
  const _AiFillSheet({required this.card});
  final AiFormFillCard card;
  @override
  State<_AiFillSheet> createState() => _AiFillSheetState();
}

class _AiFillSheetState extends State<_AiFillSheet> {
  final _desc = TextEditingController();
  GeminiService? _svc;
  String? _model;
  bool _loadingKey = true, _busy = false;
  String _error = '', _raw = '';
  Map<String, String>? _result; // anahtar -> üretilen metin
  final Set<String> _picked = {};

  AiFormFillCard get c => widget.card;
  List<String> get _keys => [for (final k in _specs.keys) if (c.fields.containsKey(k)) k];

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _desc.dispose();
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

  String _system() {
    final en = c.siteLang == 'en';
    final b = StringBuffer()
      ..writeln('Sen kıdemli bir web metin yazarısın; küçük işletmelerin ve serbest çalışanların web siteleri için metin yazıyorsun.')
      ..writeln('Çıktı dili: ${en ? 'İngilizce' : 'Türkçe'}. Yalnızca istenen alanları içeren TEK bir JSON nesnesi döndür; başka metin yazma.')
      ..writeln()
      ..writeln('GENEL KURALLAR')
      ..writeln('- Sadece kullanıcının verdiği bilgilere dayan. Yıl, rakam, müşteri sayısı, ödül, sertifika, fiyat, telefon, adres, '
          'çalışma saati veya mekân özelliği UYDURMA. Bilgi yoksa genel ama somut ve doğru bir dil kullan.')
      ..writeln('- Klişelerden kaçın ("en iyi", "bir numara", "kaliteli ve güvenilir hizmet", "müşteri memnuniyeti odaklı" gibi boş kalıplar). '
          'Okuyucuya ne kazandırdığını söyle.')
      ..writeln('- Sade, sıcak ve profesyonel bir ton. Emoji, Markdown, tırnak süsü, ünlem yığını ve büyük harfle bağırma YOK.')
      ..writeln('- Yer tutucu ([İşletme Adı], ... gibi) YAZMA. İşletme adı verildiyse doğal biçimde kullan, abartıp tekrarlama.')
      ..writeln('- Kullanıcının forma yazdığı mevcut bir metin varsa anlamını ve içindeki bilgileri koru; yalnızca daha profesyonel ve akıcı hale getir.');
    if (c.regulated) {
      b.writeln('- Bu meslekte reklam kısıtları vardır: üstünlük/karşılaştırma ("en", "tek", "lider"), sonuç garantisi, '
          'kampanya/indirim vaadi ve öncesi-sonrası iddiası YAZMA. Bilgilendirici, ölçülü ve saygılı bir dil kullan.');
    }
    b
      ..writeln()
      ..writeln('İSTENEN ALANLAR (JSON anahtarı: kural)');
    for (final k in _keys) {
      var rule = _specs[k]!.rule;
      if (k == 'about') {
        rule += c.firstPerson
            ? ' Anlatım birinci tekil şahıs ("ben") olsun.'
            : ' Anlatım "biz" diliyle olsun (işletme sesi).';
      }
      b.writeln('- "$k": $rule');
    }
    return b.toString();
  }

  String _userMsg() {
    final b = StringBuffer()..writeln('Sektör: ${c.sector}');
    void add(String label, String? v) {
      if (v != null && v.trim().isNotEmpty) b.writeln('$label: ${v.trim()}');
    }

    add('İşletme / kişi adı', c.name?.text);
    add('Unvan', c.title?.text);
    c.extra.forEach((k, v) => add(k, v.text));
    b.writeln('\nKullanıcının anlattığı:\n${_desc.text.trim()}');
    final existing = StringBuffer();
    for (final k in _keys) {
      final v = c.fields[k]!.text.trim();
      if (v.isNotEmpty) existing.writeln('- $k: $v');
    }
    if (existing.isNotEmpty) b.writeln('\nFormda şu an yazılı olan metinler (koru ve iyileştir):\n$existing');
    return b.toString();
  }

  String _clean(String key, dynamic v) {
    var s = v is List ? v.map((e) => e.toString()).join('\n') : (v ?? '').toString();
    s = s.replaceAll('**', '').replaceAll(RegExp(r'\r'), '').trim();
    if (key == 'services' || key == 'faq') {
      s = s
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^\s*(?:[-•*]|\d+[.)])\s+'), '').trim())
          .where((l) => l.isNotEmpty)
          .join('\n');
    } else {
      s = s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    }
    final max = _specs[key]!.maxLen;
    if (max > 0 && s.length > max) {
      s = s.substring(0, max);
      final cut = s.lastIndexOf(' ');
      if (cut > max * 0.6) s = s.substring(0, cut);
      s = s.replaceAll(RegExp(r'[,;:\s]+$'), '');
    }
    return s;
  }

  Future<void> _run() async {
    if (_busy || _svc == null) return;
    if (_desc.text.trim().length < 8) {
      setState(() => _error = 'Biraz daha anlat: ne iş yapıyorsun, neyle öne çıkıyorsun?');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
      _result = null;
    });
    try {
      final raw = await _svc!.generate(
        model: _model!,
        system: _system(),
        history: [
          {'role': 'user', 'text': _userMsg()},
        ],
        json: true,
      );
      final txt = raw.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), '').trim();
      final j = jsonDecode(txt);
      if (j is! Map) throw const FormatException('json');
      final out = <String, String>{};
      for (final k in _keys) {
        final s = _clean(k, j[k]);
        if (s.isNotEmpty) out[k] = s;
      }
      if (out.isEmpty) throw const FormatException('empty');
      if (!mounted) return;
      setState(() {
        _raw = raw;
        _result = out;
        _picked
          ..clear()
          // Kullanıcının zaten doldurduğu alanlar varsayılan olarak SEÇİLİ gelmez (üzerine yazma kazara olmasın).
          ..addAll(out.keys.where((k) => c.fields[k]!.text.trim().isEmpty));
        // Mevcut metin AI'a iyileştirme için verildiği için, "hakkında" doluysa da seçili gelsin.
        if (out.containsKey('about')) _picked.add('about');
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FormatException {
      if (mounted) setState(() => _error = 'Yapay zekâ yanıtı okunamadı. Anlatımı biraz değiştirip tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply() {
    final r = _result;
    if (r == null) return;
    for (final k in _picked) {
      final v = r[k];
      if (v != null) c.fields[k]!.text = v;
    }
    c.onApplied?.call();
    Navigator.pop(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(t(context, 'Metinler forma yazıldı. İstediğini elle düzenleyebilirsin.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _result;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.auto_awesome),
            const SizedBox(width: 8),
            Expanded(child: Text(t(context, 'AI ile doldur'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            if (r != null)
              IconButton(
                tooltip: t(context, 'Bu içeriği bildir'),
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => showReportDialog(
                  context: context,
                  source: ReportSource.general,
                  chatContext: '[AI form doldurma: ${c.sector}]\nAnlatım: ${_desc.text}\n\nAI yanıtı:\n$_raw',
                ),
              ),
          ]),
          const SizedBox(height: 10),
          if (_loadingKey)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_svc == null) ...[
            Text(t(context, 'AI ile doldurmak için önce kendi Gemini anahtarını ekle.')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen()));
                await _loadKey();
              },
              child: Text(t(context, 'Anahtarı ekle')),
            ),
          ] else if (r == null) ...[
            Text(
              t(context, 'Ne iş yapıyorsun, neyle öne çıkıyorsun? Ne kadar somut anlatırsan metin o kadar iyi olur.'),
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              minLines: 3,
              maxLines: 6,
              enabled: !_busy,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: t(context, 'Örn: Kadıköy\'de 10 yıldır saç boyama ve kesim yapan, kadın kuaförüyüz. Doğal ürünler kullanıyoruz.'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(t(context, _error), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _busy ? null : _run,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(t(context, 'Metinleri yaz')),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(context, 'Fotoğrafların yapay zekâya gönderilmez. Yazdıkların Google\'a gönderilir.'),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ] else ...[
            Text(t(context, 'Forma yazılacak alanları seç:'), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final k in _keys.where(r.containsKey))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CheckboxListTile(
                  value: _picked.contains(k),
                  onChanged: (v) => setState(() => v == true ? _picked.add(k) : _picked.remove(k)),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    t(context, _specs[k]!.label) +
                        (c.fields[k]!.text.trim().isNotEmpty ? ' · ${t(context, 'dolu, üzerine yazılır')}' : ''),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(r[k]!, style: const TextStyle(fontSize: 13.5))),
                ),
              ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _result = null),
                  child: Text(t(context, 'Yeniden yaz')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _picked.isEmpty ? null : _apply,
                  child: Text(t(context, 'Uygula')),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
