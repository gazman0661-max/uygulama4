import 'dart:convert';

import 'shared_html_blocks.dart';

/// 28.09.2026 eklendi (kanka isteği) — "Genel İşletme" ek sayfaları artık
/// sadece başlık + düz metin değil, sıralı BLOK listesi.
///
/// Bir ek sayfanın `blocks` alanı (Map<String,String> içinde JSON metni)
/// aşağıdaki türlerden oluşan bir liste taşır. Mevcut blokların (galeri,
/// video, hizmet listesi, SSS) HTML üreticileri (shared_html_blocks.dart)
/// AYNEN yeniden kullanılır — ana sayfadakiyle aynı görünüm.
///
/// Blok türleri ve alanları:
///   text     : heading?, body
///   image    : heading?, images:[{url, caption}] (tek görsel)
///   gallery  : heading?, images:[{url, caption}], style ('grid'|'slideshow'|...)
///   video    : heading?, url, orientation ('landscape'|'portrait')
///   services : heading?, lines ("Ad - Süre - Fiyat" satırları)
///   faq      : heading?, items:[{question, answer}]
///   button   : label, action ('call'|'whatsapp'|'link'|'review'), url?
///
/// `blocks` boş/yoksa (eski sayfalar) generator eski `content` düz metnine
/// düşer — geriye dönük uyumlu.

const List<String> kExtraPageBlockTypes = [
  'text',
  'image',
  'gallery',
  'video',
  'services',
  'faq',
  'button',
];

/// JSON metnini blok listesine çevirir. Bozuk/boş girdi → boş liste.
List<Map<String, dynamic>> decodeExtraPageBlocks(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .where((m) => kExtraPageBlockTypes.contains(m['type']))
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

bool _safeImageUrl(String url) =>
    url.startsWith('data:image/') || url.startsWith('https://') || url.startsWith('http://');

/// Kullanıcı linkini güvenli hale getirir: sadece http(s)/mailto/tel.
/// Şemasız ("ornek.com/randevu") ise https:// eklenir. javascript: vb. → null.
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

/// Fiyat/hizmet satırlarını ayrıştırır: "Ad - Süre - Fiyat" veya "Ad - Fiyat".
///
/// Ayırıcı, İKİ YANINDA BOŞLUK olan tiredir (" - ", " – ", " — "); böylece
/// "Anti-Aging Bakım - 500 TL" gibi adı içinde tire geçen hizmetler bozulmaz.
/// Geriye uyumluluk: boşluksuz yazılmış "Boya-900 TL" gibi satırlarda, tirenin
/// hemen ardından rakamla başlayan bir fiyat varsa yine ad/fiyat olarak bölünür.
/// Hem ek sayfa hizmet bloğu hem Genel İşletme formu (services) bunu kullanır.
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

/// Tek bir bloğu HTML'e çevirir; içerik boşsa/geçersizse '' döner.
String _blockHtml(
  Map<String, dynamic> b, {
  required String lang,
  String? phone,
  String? whatsapp,
  String? googleReviewLink,
}) {
  final labels = siteLabels(lang);
  switch (b['type']) {
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
          // Google yorum butonu premium kilidine tabidir (bkz.
          // googleReviewButtonHtml) — kilitliyse boş döner, bölüm yazılmaz.
          final btn = googleReviewButtonHtml(googleReviewLink, lang: lang);
          if (btn.isEmpty) return '';
          // Link kullanıcı girdisi: sadece http(s) kabul (javascript:/mailto: vb.
          // → bölüm yazılmaz); şemasız ("g.page/x") ise https:// eklenir.
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

/// Tüm blokları sırayla birleştirir.
String extraPageBlocksHtml(
  List<Map<String, dynamic>> blocks, {
  String lang = 'tr',
  String? phone,
  String? whatsapp,
  String? googleReviewLink,
}) {
  final buf = StringBuffer();
  for (final b in blocks) {
    final html = _blockHtml(
      b,
      lang: lang,
      phone: phone,
      whatsapp: whatsapp,
      googleReviewLink: googleReviewLink,
    );
    if (html.isNotEmpty) buf.writeln(html);
  }
  return buf.toString();
}

/// SEO açıklaması için: ilk yazı bloğunun metninden ~157 karakter.
String extraPageBlocksMetaText(List<Map<String, dynamic>> blocks) {
  for (final b in blocks) {
    if (b['type'] == 'text') {
      final body = _str(b['body']).replaceAll(RegExp(r'\s+'), ' ');
      if (body.isNotEmpty) return body.length > 160 ? body.substring(0, 157) : body;
    }
  }
  return '';
}
