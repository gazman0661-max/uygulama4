import 'package:flutter/material.dart';

import '../templates/html/extra_page_blocks.dart' show parseServiceLines;
import '../templates/html/shared_html_blocks.dart' show bentoBlockSizes, siteLabels;
import '../localization/app_strings.dart';
import 'free_model.dart';
import 'free_theme.dart';

/// Hazır bölümlerin (galeri/video/hizmet/SSS/iletişim) editördeki GERÇEK
/// görselli, temaya göre boyanmış önizlemesi.
///
/// Aynı veriyi kullanır: renkler [resolveTheme], yazı tipi [resolveFontPackage],
/// bento karo dağılımı [bentoBlockSizes] (HTML üreticiyle birebir aynı fonksiyon).
/// Fark: slayt/marquee/crossfade editörde hareketsizdir; kesin görünüm için
/// editördeki "Canlı Önizleme" kullanılır.
class FreeSectionPreview extends StatelessWidget {
  final FreeSection section;
  final FreeSite site;
  final FreeTheme baseTheme;

  /// Seçilen bölüm arka planına göre türetilmiş tema (yayındaki `_scoped` ile aynı).
  FreeTheme get theme => baseTheme.onBg(section.bg).withTextColor(section.tc);

  /// Gövde / başlık / ikincil metin boyutları — yayındaki `.fb-fsz` oranlarıyla aynı
  /// (başlık 1.6x, ikincil 0.85x). Seçilmemişse eski varsayılanlar.
  double get _body => section.fs > 0 ? section.fs.toDouble() : 14;
  double get _head => section.fs > 0 ? section.fs * 1.6 : 22;
  double get _small => section.fs > 0 ? section.fs * 0.85 : 12;

  /// Talep formu yalnızca premium üretimde yayınlanır (ücretsizde çıktıdan düşer).
  final bool premium;

  const FreeSectionPreview({
    super.key,
    required this.section,
    required this.site,
    required FreeTheme theme,
    required this.premium,
  }) : baseTheme = theme;

  Map<String, dynamic> get b => section.block;
  String _s(String k) => (b[k] ?? '').toString().trim();
  /// Bölüm başlığı varsayılanları SİTE dilini izler (site içeriğidir).
  /// Editör ipuçları ise UYGULAMA dilini izler ([t]).
  bool get _siteEn => site.lang == 'en';

  List<Map<String, String>> _images() {
    final raw = b['images'];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map && (e['url'] ?? '').toString().isNotEmpty)
          {'url': e['url'].toString(), 'caption': (e['caption'] ?? '').toString()},
    ];
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.heading(TextStyle(fontSize: _head, fontWeight: FontWeight.w700, color: theme.text)),
        ),
      );

  Widget _tile(Map<String, String> img, {BoxFit fit = BoxFit.cover}) {
    final bytes = freeImageBytes(img['url']);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: bytes == null
          ? Container(color: theme.chipBg, child: Icon(Icons.image_outlined, color: theme.subtext))
          : Image.memory(bytes, fit: fit, width: double.infinity, height: double.infinity, gaplessPlayback: true),
    );
  }

  Widget _empty(IconData icon, String msg) => Container(
        height: 96,
        decoration: BoxDecoration(
          color: theme.chipBg,
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: theme.subtext),
          const SizedBox(height: 6),
          Text(msg, style: TextStyle(color: theme.subtext, fontSize: _small)),
        ]),
      );

  Widget _gallery(BuildContext context) {
    final imgs = _images();
    final style = _s('style').isEmpty ? 'grid' : _s('style');
    final heading = _s('heading').isEmpty ? siteLabels(site.lang)['gallery']! : _s('heading');
    Widget body;
    if (imgs.isEmpty) {
      body = _empty(Icons.photo_library_outlined, t(context, 'Fotoğraf eklemek için düzenle'));
    } else if (style == 'bento') {
      final sizes = bentoBlockSizes(imgs.length);
      var idx = 0;
      body = Column(children: [
        for (final take in sizes)
          Builder(builder: (_) {
            final row = imgs.sublist(idx, idx + take);
            idx += take;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: 110,
                child: Row(children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: _tile(row[i])),
                  ],
                ]),
              ),
            );
          }),
      ]);
    } else if (style == 'slideshow' || style == 'crossfade') {
      body = Column(children: [
        AspectRatio(aspectRatio: 16 / 10, child: _tile(imgs.first)),
        if (style == 'slideshow') ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < imgs.length && i < 12; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == 0 ? theme.accent : theme.border,
                ),
              ),
          ]),
        ],
      ]);
    } else if (style == 'marquee') {
      body = SizedBox(
        height: 104,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final i in imgs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AspectRatio(aspectRatio: 4 / 3, child: _tile(i)),
              ),
          ],
        ),
      );
    } else {
      // grid
      body = LayoutBuilder(builder: (ctx, bc) {
        final cols = bc.maxWidth > 520 ? 4 : 3;
        final w = (bc.maxWidth - (cols - 1) * 6) / cols;
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (final i in imgs) SizedBox(width: w, height: w, child: _tile(i)),
        ]);
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(heading),
      body,
      if (imgs.isNotEmpty && style != 'grid')
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            t(context, 'Sabit önizleme — hareket canlı sayfada çalışır'),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.subtext, fontSize: 11),
          ),
        ),
    ]);
  }

  Widget _video(BuildContext context) {
    final heading = _s('heading').isEmpty ? siteLabels(site.lang)['videoTitle']! : _s('heading');
    final portrait = _s('orientation') == 'portrait';
    final url = _s('url');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(heading),
      Center(
        child: SizedBox(
          width: portrait ? 160 : double.infinity,
          child: AspectRatio(
            aspectRatio: portrait ? 9 / 16 : 16 / 9,
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(10)),
              child: url.isEmpty
                  ? const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.white54))
                  : const Center(child: Icon(Icons.play_circle_fill, size: 54, color: Colors.white)),
            ),
          ),
        ),
      ),
      if (url.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.subtext, fontSize: 11)),
        ),
    ]);
  }

  Widget _services(BuildContext context) {
    final heading = _s('heading').isEmpty
        ? (_siteEn ? 'Services & Prices' : 'Hizmetler ve Fiyatlar')
        : _s('heading');
    final items = parseServiceLines(_s('lines'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(heading),
      if (items.isEmpty)
        _empty(Icons.list_alt, t(context, 'Hizmet eklemek için düzenle'))
      else
        for (final it in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardBg,
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  [it['name'], if ((it['duration'] ?? '').isNotEmpty) it['duration']].join(' · '),
                  style: theme.body(TextStyle(color: theme.text, fontSize: _body, fontWeight: FontWeight.w600)),
                ),
              ),
              Text(it['price'] ?? '',
                  style: theme.body(TextStyle(color: theme.accent, fontSize: _body, fontWeight: FontWeight.w700))),
            ]),
          ),
    ]);
  }

  Widget _faq(BuildContext context) {
    final heading = _s('heading').isEmpty
        ? (_siteEn ? 'Frequently Asked Questions' : 'Sık Sorulan Sorular')
        : _s('heading');
    final raw = b['items'];
    final qs = <String>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map && (e['question'] ?? '').toString().trim().isNotEmpty) {
          qs.add(e['question'].toString().trim());
        }
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(heading),
      if (qs.isEmpty)
        _empty(Icons.help_outline, t(context, 'Soru eklemek için düzenle'))
      else
        for (final q in qs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardBg,
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(child: Text(q, style: theme.body(TextStyle(color: theme.text, fontSize: _body, fontWeight: FontWeight.w600)))),
              Icon(Icons.expand_more, color: theme.subtext),
            ]),
          ),
    ]);
  }

  Widget _contact(BuildContext context) {
    final labels = siteLabels(site.lang);
    Widget btn(IconData i, String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 16, color: theme.accentText),
            const SizedBox(width: 6),
            Text(t, style: theme.body(TextStyle(color: theme.accentText, fontSize: _body, fontWeight: FontWeight.w600))),
          ]),
        );
    final hasAny = site.phone.trim().isNotEmpty || site.whatsapp.trim().isNotEmpty || site.instagram.trim().isNotEmpty;
    Widget field(String hint, {int lines = 1}) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 14.0 + lines * 22,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(hint, style: TextStyle(color: theme.subtext, fontSize: _body)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(labels['contact']!),
      if (hasAny)
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          if (site.phone.trim().isNotEmpty) btn(Icons.phone, labels['call']!),
          if (site.whatsapp.trim().isNotEmpty) btn(Icons.chat, 'WhatsApp'),
          if (site.instagram.trim().isNotEmpty) btn(Icons.camera_alt_outlined, 'Instagram'),
        ])
      else
        _empty(Icons.phone_disabled, t(context, 'Site ayarlarından telefon / WhatsApp ekle')),
      const SizedBox(height: 14),
      if (premium) ...[
        field(labels['yourName']!),
        field(labels['yourPhone']!),
        field(labels['yourMessage']!, lines: 2),
      ] else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.chipBg,
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 18, color: theme.subtext),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t(context, 'Talep formu ücretli planlara dahildir — ücretsiz sitede görünmez.'),
                style: TextStyle(color: theme.subtext, fontSize: 12),
              ),
            ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (section.isContact) {
      child = _contact(context);
    } else {
      switch (section.blockType) {
        case 'gallery':
          child = _gallery(context);
          break;
        case 'video':
          child = _video(context);
          break;
        case 'services':
          child = _services(context);
          break;
        case 'faq':
          child = _faq(context);
          break;
        default:
          child = const SizedBox.shrink();
      }
    }
    return Container(
      color: theme.sectionBg(section.bg),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: child,
    );
  }
}
