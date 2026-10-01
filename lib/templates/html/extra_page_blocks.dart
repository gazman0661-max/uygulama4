import 'dart:convert';

import 'shared_html_blocks.dart';
import 'google_font_catalog.dart';
import 'text_styling.dart';
import '../../services/free_plan_restriction_service.dart';

const List<String> kExtraPageBlockTypes = [
  'text',
  'image',
  'gallery',
  'video',
  'services',
  'faq',
  'button',
];

const List<String> kFreeSiteBlockTypes = [
  ...kExtraPageBlockTypes,
  'hours',
  'map',
  'reviews',
  'contact',
];
const List<String> kFreeSiteHomeBlockTypes = ['hero', ...kFreeSiteBlockTypes];

List<Map<String, dynamic>> decodeExtraPageBlocks(
  String? raw, {
  List<String> allowed = kExtraPageBlockTypes,
}) {
  if (raw == null || raw.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .where((m) => allowed.contains(m['type']))
        .toList();
  } catch (_) {
    return [];
  }
}

String encodeExtraPageBlocks(List<Map<String, dynamic>> blocks) => jsonEncode(blocks);

String _str(dynamic v) => v == null ? '' : v.toString().trim();

List<Map<String, String?>> _images(dynamic raw) {
  if (raw is! List) return [];
  final out = <Map<String, String?>>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final url = _str(e['url']);
    if (url.isEmpty) continue;
    final caption = _str(e['caption']);
    out.add({'url': url, 'caption': caption.isEmpty ? null : caption});
  }
  return out;
}

double? _numOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v == null) return null;
  return double.tryParse(v.toString().trim().replaceAll(',', '.'));
}

List<Map<String, dynamic>> parseTestimonialLines(String raw) {
  final out = <Map<String, dynamic>>[];
  for (final line in raw.split('\n')) {
    final l = line.trim();
    if (l.isEmpty || !l.contains('|')) continue;
    final parts = l.split('|').map((p) => p.trim()).toList();
    final name = parts.isNotEmpty ? parts[0] : '';
    final text = parts.length > 1 ? parts[1] : '';
    if (name.isEmpty || text.isEmpty) continue;
    out.add({'name': name, 'text': text, 'rating': parts.length > 2 ? parts[2] : ''});
  }
  return out;
}

const Set<String> kBlockAligns = {'left', 'center', 'right'};
const Set<String> kBlockTones = {'soft', 'accent', 'dark'};

String blockAlignOf(Map<String, dynamic> b) {
  final v = _str(b['align']);
  return kBlockAligns.contains(v) ? v : '';
}

String blockToneOf(Map<String, dynamic> b) {
  final v = _str(b['tone']);
  return kBlockTones.contains(v) ? v : '';
}

List<Map<String, String?>> hoursOfBlock(dynamic raw) {
  if (raw is! List) return [];
  final out = <Map<String, String?>>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final day = _str(e['day']);
    if (day.isEmpty) continue;
    final range = _str(e['range']);
    final tz = _str(e['tz']);
    out.add({
      'day': day,
      'range': range.isEmpty ? null : range,
      if (tz.isNotEmpty) 'tz': tz,
    });
  }
  return out;
}

bool _safeImageUrl(String url) =>
    url.startsWith('data:image/') || url.startsWith('https://') || url.startsWith('http://');

String? sanitizeButtonUrl(String raw) {
  final u = raw.trim();
  if (u.isEmpty) return null;
  final lower = u.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('tel:')) {
    return u;
  }
  if (u.contains(':') || u.contains(' ') || !u.contains('.')) return null;
  return 'https://$u';
}

String _paragraphs(String content) {
  final ps = content
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  return ps.map((p) => '<p>${escapeHtml(p).replaceAll('\n', '<br>')}</p>').join('\n');
}

List<Map<String, String?>> parseServiceLines(String text) {
  final spaced = RegExp(r'\s+[-–—]\s+');
  final tight = RegExp(r'^(.+?)\s*[-–—]\s*(\d.*)$');
  return text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((line) {
    var parts = line.split(spaced).map((p) => p.trim()).toList();
    if (parts.length == 1) {
      final m = tight.firstMatch(line);
      if (m != null) parts = [m.group(1)!.trim(), m.group(2)!.trim()];
    }
    if (parts.length >= 3) {
      return <String, String?>{'name': parts[0], 'duration': parts[1], 'price': parts.sublist(2).join(' - ')};
    } else if (parts.length == 2) {
      return <String, String?>{'name': parts[0], 'duration': null, 'price': parts[1]};
    }
    return <String, String?>{'name': parts[0], 'duration': null, 'price': ''};
  }).toList();
}

String _sectionWithHeading(String heading, String inner) {
  final h = heading.isEmpty ? '' : '<h2 class="section-title">${escapeHtml(heading)}</h2>';
  return '<section class="section">\n$h\n$inner\n</section>';
}

String _blockHtml(
  Map<String, dynamic> b, {
  required String lang,
  String? phone,
  String? whatsapp,
  String? googleReviewLink,
  String siteName = '',
  String? logoImage,
  String heroLayoutStyle = 'centered',
  List<Map<String, String?>>? heroHours,
  String? instagram,
  bool includeLeadForm = true,
  Map<String, dynamic>? heroTestimonial,
}) {
  final labels = siteLabels(lang);
  switch (b['type']) {
    case 'hero':
      {
        final coverImgs = _images(b['images']);
        final cover = (coverImgs.isNotEmpty && _safeImageUrl(coverImgs.first['url']!))
            ? coverImgs.first['url']!
            : ''  ;
        final title = _str(b['heading']).isEmpty ? siteName : _str(b['heading']);
        if (title.isEmpty) return '';
        final action = _str(b['action']).isEmpty ? 'whatsapp' : _str(b['action']);
        String? ctaHref;
        var ctaText = _str(b['label']);
        if (action == 'whatsapp' && whatsapp != null && whatsapp.isNotEmpty) {
          ctaHref = 'https://wa.me/$whatsapp';
          if (ctaText.isEmpty) ctaText = 'WhatsApp';
        } else if (action == 'call' && phone != null && phone.isNotEmpty) {
          ctaHref = 'tel:$phone';
          if (ctaText.isEmpty) ctaText = businessSectorLabels('default', lang)['ctaText']!;
        } else if (action == 'link') {
          ctaHref = sanitizeButtonUrl(_str(b['url']));
          if (ctaText.isEmpty) ctaText = businessSectorLabels('default', lang)['ctaText']!;
        }
        if (ctaText.isEmpty) ctaText = businessSectorLabels('default', lang)['ctaText']!;
        return heroBlockHtml(
          name: title,
          tagline: _str(b['tagline']),
          coverImage: cover,
          logoImage: (logoImage != null && logoImage.isNotEmpty) ? logoImage : null,
          ctaText: ctaText,
          ctaHref: ctaHref,
          layoutStyle: heroLayoutStyle,
          workingHours: heroHours,
          featuredTestimonial: heroTestimonial,
          lang: lang,
        );
      }

    case 'map':
      {
        final address = _str(b['address']);
        final lat = _numOf(b['lat']);
        final lng = _numOf(b['lng']);
        if (address.isEmpty || lat == null || lng == null) return '';
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return '';
        final heading = _str(b['heading']);
        return mapBlockHtml(
          title: heading.isEmpty ? labels['location']! : heading,
          address: address,
          lat: lat,
          lng: lng,
          lang: lang,
        );
      }

    case 'reviews':
      {
        if (b['consent'] != true) return '';
        final list = parseTestimonialLines(_str(b['lines']));
        if (list.isEmpty) return '';
        final heading = _str(b['heading']);
        return testimonialBlockHtml(
          testimonials: list,
          lang: lang,
          title: heading.isEmpty ? null : heading,
        );
      }

    case 'contact':
      {
        final heading = _str(b['heading']);
        return contactBlockHtml(
          title: heading.isEmpty ? labels['contact']! : heading,
          phone: phone,
          whatsapp: whatsapp,
          instagram: instagram,
          googleReviewLink: googleReviewLink,
          lang: lang,
          includeLeadForm: includeLeadForm && b['leadForm'] != false,
          siteName: siteName,
        );
      }

    case 'hours':
      {
        final rows = hoursOfBlock(b['hours']);
        if (rows.isEmpty) return '';
        final heading = _str(b['heading']);
        return workingHoursBlockHtml(
          title: heading.isEmpty ? labels['hours']! : heading,
          hours: rows,
          lang: lang,
        );
      }

    case 'text':
      final body = _str(b['body']);
      if (body.isEmpty) return '';
      return _sectionWithHeading(_str(b['heading']), _paragraphs(body));

    case 'image':
      final imgs = _images(b['images']);
      if (imgs.isEmpty || !_safeImageUrl(imgs.first['url']!)) return '';
      final img = imgs.first;
      final cap = img['caption'];
      final alt = escapeHtml(cap ?? '');
      final figcaption = (cap != null && cap.isNotEmpty)
          ? '<figcaption style="margin-top:8px;font-size:0.9em;opacity:0.75;text-align:center">${escapeHtml(cap)}</figcaption>'
          : '';
      final fig = '<figure style="margin:0"><img src="${escapeHtml(img['url']!)}" alt="$alt" loading="lazy" '
          'style="width:100%;height:auto;display:block;border-radius:14px">$figcaption</figure>';
      return _sectionWithHeading(_str(b['heading']), fig);

    case 'gallery':
      final imgs = _images(b['images']).where((i) => _safeImageUrl(i['url']!)).toList();
      if (imgs.isEmpty) return '';
      final heading = _str(b['heading']);
      final style = _str(b['style']).isEmpty ? 'grid' : _str(b['style']);
      return galleryBlockHtml(
        title: heading.isEmpty ? labels['gallery']! : heading,
        images: imgs,
        style: style,
      );

    case 'video':
      final url = _str(b['url']);
      if (url.isEmpty) return '';
      final heading = _str(b['heading']);
      return videoBlockHtml(
        title: heading.isEmpty ? labels['videoTitle']! : heading,
        videoUrl: url,
        orientation: _str(b['orientation']) == 'portrait' ? 'portrait' : 'landscape',
        lang: lang,
      );

    case 'services':
      final services = parseServiceLines(_str(b['lines']));
      if (services.isEmpty) return '';
      final heading = _str(b['heading']);
      return serviceListBlockHtml(
        title: heading.isEmpty ? (lang == 'en' ? 'Services & Prices' : 'Hizmetler ve Fiyatlar') : heading,
        services: services,
      );

    case 'faq':
      final raw = b['items'];
      if (raw is! List) return '';
      final faqs = <Map<String, String>>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final q = _str(e['question']);
        final a = _str(e['answer']);
        if (q.isEmpty || a.isEmpty) continue;
        faqs.add({'question': q, 'answer': a});
      }
      if (faqs.isEmpty) return '';
      final heading = _str(b['heading']);
      return faqBlockHtml(faqs: faqs, lang: lang, title: heading.isEmpty ? null : heading);

    case 'button':
      final label = _str(b['label']);
      if (label.isEmpty) return '';
      String? href;
      String cls = 'contact-btn';
      bool external = false;
      switch (_str(b['action'])) {
        case 'call':
          if (phone == null || phone.isEmpty) return '';
          href = 'tel:$phone';
          cls = 'contact-btn phone';
          break;
        case 'whatsapp':
          if (whatsapp == null || whatsapp.isEmpty) return '';
          href = 'https://wa.me/$whatsapp';
          cls = 'contact-btn whatsapp';
          external = true;
          break;
        case 'review':
          final btn = googleReviewButtonHtml(googleReviewLink, lang: lang);
          if (btn.isEmpty) return '';
          final reviewHref = sanitizeButtonUrl(googleReviewLink!);
          if (reviewHref == null || !reviewHref.toLowerCase().startsWith('http')) return '';
          final review = '<a class="contact-btn review" target="_blank" rel="noopener" '
              'href="${escapeHtml(reviewHref)}">${escapeHtml(label)}</a>';
          return '<section class="section cta-section"><div class="contact-buttons">$review</div></section>';
        default:
          href = sanitizeButtonUrl(_str(b['url']));
          if (href == null) return '';
          external = href.startsWith('http');
      }
      final target = external ? ' target="_blank" rel="noopener"' : '';
      return '<section class="section cta-section"><div class="contact-buttons">'
          '<a class="$cls"$target href="${escapeHtml(href!)}">${escapeHtml(label)}</a>'
          '</div></section>';
  }
  return '';
}

String _blockStyleCss(Map<String, String> theme) {
  final accent = theme['accent'] ?? '#2563eb';
  final accentText = theme['accentText'] ?? '#ffffff';
  final border = hexToRgba(accentText, 0.3);
  return '''<style id="fs-blk-css">
.fs-tone-soft { background: var(--sitora-chip-bg); background: color-mix(in srgb, var(--sitora-accent) 8%, var(--sitora-bg)); }
.fs-tone-accent { --sitora-bg: $accent; --sitora-text: $accentText; --sitora-subtext: $accentText; --sitora-card-bg: rgba(255,255,255,0.14); --sitora-border: $border; --sitora-chip-bg: rgba(255,255,255,0.14); --sitora-accent: $accentText; --sitora-accent-text: $accent; background: var(--sitora-bg); color: var(--sitora-text); }
.fs-tone-dark { --sitora-bg: #111827; --sitora-text: #f9fafb; --sitora-subtext: #cbd5e1; --sitora-card-bg: #1f2937; --sitora-border: rgba(255,255,255,0.16); --sitora-chip-bg: #1f2937; --sitora-accent: $accent; --sitora-accent-text: $accentText; background: var(--sitora-bg); color: var(--sitora-text); }
.fs-al-left .section { text-align: left; }
.fs-al-center .section { text-align: center; }
.fs-al-center .section-title::before { left: 50%; transform: translateX(-50%); }
.fs-al-center .contact-buttons { justify-content: center; }
.fs-al-right .section { text-align: right; }
.fs-al-right .section-title::before { left: auto; right: 0; }
.fs-al-right .contact-buttons { justify-content: flex-end; }
</style>''';
}

const List<String> kBlockTextStyleKeys = ['hc', 'tc', 'hs', 'ts', 'hb', 'hu', 'it', 'hf', 'tf'];

bool blockHasTextStyle(Map<String, dynamic> b) =>
    kBlockTextStyleKeys.any((k) => b[k] != null && b[k] != '' && b[k] != false);

Set<String> _blockFontsAllowed(List<Map<String, dynamic>> blocks) {
  final out = <String>{};
  for (final b in blocks) {
    for (final k in const ['hf', 'tf']) {
      final name = fontNameFromSlug(b[k]?.toString());
      if (name != null && out.length < kMaxExtraFontsPerSite) out.add(name);
    }
  }
  return out;
}

String _wrapText(Map<String, dynamic> b, String html, int index, Set<String> allowedFonts) {
  if (!blockHasTextStyle(b)) return html;
  final st = <String, dynamic>{
    for (final k in kBlockTextStyleKeys)
      if (b[k] != null) k: b[k],
  };
  final premium = FreePlanRestrictionService.isPremiumGeneration;
  final usedFonts = <String>[
    for (final k in const ['hf', 'tf'])
      if (allowedFonts.contains(fontNameFromSlug(b[k]?.toString()))) b[k].toString().toLowerCase(),
  ];
  final cls = 'fsb-t$index';
  final css = TextStyling.sectionStyleCss(
    ['.$cls'],
    st,
    isHero: b['type'] == 'hero',
    allowCustomColor: premium || !TextStylingPolicy.customColorIsPremium,
    allowedFonts: premium ? allowedFonts : <String>{},
  );
  final usesCustomColor = TextStyling.styleUsesCustomColor(st);
  if (css.isEmpty && usedFonts.isEmpty && !usesCustomColor) return html;
  final attrs = [
    if (usesCustomColor) ' data-sx-prem="1"',
    if (usedFonts.isNotEmpty) ' data-sx-font="${usedFonts.join(' ')}"',
  ].join();
  return '<style>\n$css</style>\n<div class="$cls"$attrs>\n$html\n</div>';
}

String _wrapStyled(Map<String, dynamic> b, String html) {
  if (b['type'] == 'hero') return html;
  final align = blockAlignOf(b);
  final tone = blockToneOf(b);
  if (align.isEmpty && tone.isEmpty) return html;
  final cls = [
    'fs-blk',
    if (tone.isNotEmpty) 'fs-tone-$tone',
    if (align.isNotEmpty) 'fs-al-$align',
  ].join(' ');
  return '<div class="$cls">\n$html\n</div>';
}

String extraPageBlocksHtml(
  List<Map<String, dynamic>> blocks, {
  String lang = 'tr',
  String? phone,
  String? whatsapp,
  String? googleReviewLink,
  String siteName = '',
  String? logoImage,
  String heroLayoutStyle = 'centered',
  String? instagram,
  bool includeLeadForm = true,
  Map<String, String>? theme,
  bool editorMarkers = false,
}) {
  final buf = StringBuffer();
  List<Map<String, String?>>? heroHours;
  for (final b in blocks) {
    if (b['type'] == 'hours') {
      final rows = hoursOfBlock(b['hours']);
      if (rows.isNotEmpty) {
        heroHours = rows;
        break;
      }
    }
  }
  Map<String, dynamic>? heroTestimonial;
  for (final b in blocks) {
    if (b['type'] == 'reviews' && b['consent'] == true) {
      final list = parseTestimonialLines(_str(b['lines']));
      if (list.isNotEmpty) {
        heroTestimonial = list.first;
        break;
      }
    }
  }
  final styled = blocks.any(
    (b) => b['type'] != 'hero' && (blockAlignOf(b).isNotEmpty || blockToneOf(b).isNotEmpty),
  );
  if (styled) buf.writeln(_blockStyleCss(theme ?? themeOf(null)));
  final allowedBlockFonts = _blockFontsAllowed(blocks);
  var contactDone = false;
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    if (b['type'] == 'contact') {
      if (contactDone) continue;
      contactDone = true;
    }
    final html = _blockHtml(
      b,
      lang: lang,
      phone: phone,
      whatsapp: whatsapp,
      googleReviewLink: googleReviewLink,
      siteName: siteName,
      logoImage: logoImage,
      heroLayoutStyle: heroLayoutStyle,
      heroHours: heroHours,
      instagram: instagram,
      includeLeadForm: includeLeadForm,
      heroTestimonial: heroTestimonial,
    );
    if (editorMarkers) {
      if (html.isEmpty) {
        buf.writeln('<div class="fs-ph" data-fsb="$i">${_phLabel(_str(b['type']), lang)}</div>');
      } else {
        buf.writeln('<div data-fsb="$i" style="display:contents">\n${_wrapStyled(b, _wrapText(b, html, i, allowedBlockFonts))}\n</div>');
      }
    } else if (html.isNotEmpty) {
      buf.writeln(_wrapStyled(b, _wrapText(b, html, i, allowedBlockFonts)));
    }
  }
  return buf.toString();
}

const Map<String, String> _phLabelEn = {
  'hero': 'Cover — tap to edit',
  'hours': 'Working hours — tap to edit',
  'map': 'Map — add an address',
  'reviews': 'Customer reviews — tap to edit',
  'contact': 'Contact / request form — tap to edit',
  'text': 'Text — tap to edit',
  'image': 'Image — add a photo',
  'gallery': 'Gallery — add photos',
  'video': 'Video — add a link',
  'services': 'Price / service list — tap to edit',
  'faq': 'FAQ — tap to edit',
  'button': 'Button — tap to edit',
};

String _phLabel(String type, [String lang = 'tr']) {
  if (lang == 'en') return _phLabelEn[type] ?? 'Block — tap to edit';
  switch (type) {
    case 'hero':
      return 'Kapak — düzenlemek için dokun';
    case 'hours':
      return 'Çalışma saatleri — düzenlemek için dokun';
    case 'map':
      return 'Harita — adres ekle';
    case 'reviews':
      return 'Müşteri yorumları — düzenlemek için dokun';
    case 'contact':
      return 'İletişim / talep formu — düzenlemek için dokun';
    case 'text':
      return 'Yazı — düzenlemek için dokun';
    case 'image':
      return 'Görsel — fotoğraf ekle';
    case 'gallery':
      return 'Galeri — fotoğraf ekle';
    case 'video':
      return 'Video — link ekle';
    case 'services':
      return 'Fiyat / hizmet listesi — düzenlemek için dokun';
    case 'faq':
      return 'Sık sorulan sorular — düzenlemek için dokun';
    case 'button':
      return 'Buton — düzenlemek için dokun';
  }
  return 'Blok — düzenlemek için dokun';
}

String extraPageBlocksMetaText(List<Map<String, dynamic>> blocks) {
  for (final b in blocks) {
    if (b['type'] == 'text') {
      final body = _str(b['body']).replaceAll(RegExp(r'\s+'), ' ');
      if (body.isNotEmpty) return body.length > 160 ? body.substring(0, 157) : body;
    }
  }
  for (final b in blocks) {
    if (b['type'] == 'hero') {
      final tag = _str(b['tagline']).replaceAll(RegExp(r'\s+'), ' ');
      if (tag.isNotEmpty) return tag.length > 160 ? tag.substring(0, 157) : tag;
    }
  }
  return '';
}
