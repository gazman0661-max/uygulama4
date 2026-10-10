import 'shared_html_blocks.dart';

/// Formlarda olup serbest builder'da OLMAYAN blokların (çalışma saatleri, yorumlar, ürünler,
/// menü, paketler, ekip, zaman çizelgesi, yetenekler, Google yorum butonu, hero düzenleri)
/// builder bloğu → HTML dönüşümü. Hepsi mevcut form blok fonksiyonlarını çağırır; yeni HTML/CSS
/// üretmez. İçerik boşsa '' döner.
const Set<String> kExtraBlockTypes = {
  'hero', 'hours', 'testimonials', 'products', 'menu', 'packages', 'team', 'timeline', 'skills', 'review',
};

String _s(dynamic v) => v == null ? '' : v.toString().trim();

List<Map<String, dynamic>> _items(Map<String, dynamic> b, String key) {
  final raw = b[key];
  if (raw is! List) return [];
  return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
}

bool _safeImg(String u) => u.startsWith('data:image/') || u.startsWith('https://') || u.startsWith('http://');

/// Sadece http(s)/mailto/tel; şemasız ise https:// eklenir; javascript: vb. → null.
String? _safeHref(String raw) {
  final u = raw.trim();
  if (u.isEmpty) return null;
  final l = u.toLowerCase();
  if (l.startsWith('http://') || l.startsWith('https://') || l.startsWith('mailto:') || l.startsWith('tel:')) return u;
  if (l.contains(':')) return null;
  return 'https://$u';
}

List<String> _lines(String s) => s.split(RegExp(r'[\n;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

String extraBlockHtml(String type, Map<String, dynamic> b, {String lang = 'tr'}) {
  final en = lang == 'en';
  final heading = _s(b['heading']);
  switch (type) {
    case 'hero':
      final name = _s(b['name']);
      if (name.isEmpty) return '';
      final imgs = _items(b, 'images');
      final c0 = imgs.isNotEmpty ? _s(imgs.first['url']) : '';
      final cover = _safeImg(c0) ? c0 : '';
      final href = _safeHref(_s(b['ctaHref'])) ?? '';
      return heroBlockHtml(
        name: name,
        tagline: _s(b['tagline']),
        coverImage: cover,
        ctaText: _s(b['ctaText']).isEmpty ? (en ? 'Contact' : 'İletişime Geç') : _s(b['ctaText']),
        ctaHref: href.isEmpty ? null : href,
        layoutStyle: _s(b['layout']).isEmpty ? 'centered' : _s(b['layout']),
        eyebrowLabel: _s(b['eyebrow']).isEmpty ? null : _s(b['eyebrow']),
        lang: lang,
      );

    case 'hours':
      final rows = <Map<String, String?>>[];
      for (final e in _items(b, 'items')) {
        final day = _s(e['day']);
        if (day.isEmpty) continue;
        final r = _s(e['range']);
        rows.add({'day': day, 'range': r.isEmpty ? null : r, if (_s(e['tz']).isNotEmpty) 'tz': _s(e['tz'])});
      }
      if (rows.isEmpty) return '';
      return workingHoursBlockHtml(title: heading.isEmpty ? (en ? 'Opening Hours' : 'Çalışma Saatleri') : heading, hours: rows, lang: lang);

    case 'testimonials':
      final list = [
        for (final e in _items(b, 'items'))
          if (_s(e['name']).isNotEmpty && _s(e['text']).isNotEmpty)
            {'name': _s(e['name']), 'text': _s(e['text']), 'rating': _s(e['rating'])},
      ];
      if (list.isEmpty) return '';
      return testimonialBlockHtml(testimonials: list, lang: lang, title: heading.isEmpty ? null : heading);

    case 'products':
      final prods = [
        for (final e in _items(b, 'images'))
          if (_safeImg(_s(e['url']))) <String, String?>{'url': _s(e['url']), 'caption': _s(e['caption'])},
      ];
      if (prods.isEmpty) return '';
      return productListBlockHtml(title: heading.isEmpty ? (en ? 'Products' : 'Ürünler') : heading, products: prods);

    case 'menu':
      final cats = <Map<String, dynamic>>[];
      for (final c in _items(b, 'items')) {
        final items = <Map<String, dynamic>>[];
        for (final line in _lines(_s(c['lines']))) {
          final p = line.split('|').map((e) => e.trim()).toList();
          if (p.first.isEmpty) continue;
          items.add({
            'name': p[0],
            'description': p.length > 2 ? p[1] : '',
            'price': p.length > 2 ? p[2] : (p.length > 1 ? p[1] : ''),
          });
        }
        if (items.isNotEmpty) cats.add({'title': _s(c['title']), 'items': items});
      }
      if (cats.isEmpty) return '';
      return menuBlockHtml(title: heading.isEmpty ? (en ? 'Menu' : 'Menü') : heading, categories: cats, lang: lang);

    case 'packages':
      final pk = <Map<String, dynamic>>[];
      for (final e in _items(b, 'items')) {
        if (_s(e['title']).isEmpty) continue;
        pk.add({
          'title': _s(e['title']),
          'sessionLabel': _s(e['sessionLabel']),
          'price': _s(e['price']),
          'originalPrice': _s(e['originalPrice']),
          'includedServices': _lines(_s(e['services'])),
          'note': _s(e['note']),
          'isFeatured': e['isFeatured'] == true,
        });
      }
      if (pk.isEmpty) return '';
      return packageCardsBlockHtml(title: heading.isEmpty ? (en ? 'Packages' : 'Paketler') : heading, packages: pk);

    case 'team':
      final ms = <Map<String, dynamic>>[];
      for (final e in _items(b, 'items')) {
        if (_s(e['name']).isEmpty) continue;
        ms.add({
          'name': _s(e['name']),
          'specialty': _s(e['specialty']),
          'photoUrl': '',
          'bio': _s(e['bio']),
          'tags': _s(e['tags']).split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList(),
        });
      }
      if (ms.isEmpty) return '';
      return teamBlockHtml(title: heading.isEmpty ? (en ? 'Our Team' : 'Ekibimiz') : heading, members: ms);

    case 'timeline':
      final en2 = <Map<String, String?>>[
        for (final e in _items(b, 'items'))
          if (_s(e['title']).isNotEmpty) {'year': _s(e['year']), 'title': _s(e['title']), 'description': _s(e['description'])},
      ];
      if (en2.isEmpty) return '';
      return timelineBlockHtml(title: heading.isEmpty ? (en ? 'Our Story' : 'Hikâyemiz') : heading, entries: en2);

    case 'skills':
      final sk = _s(b['skills']).split(RegExp(r'[\n,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (sk.isEmpty) return '';
      final h = heading.isEmpty ? '' : '<h2 class="section-title">${escapeHtml(heading)}</h2>\n  ';
      return '<section class="section">\n  $h${skillChipsBlockHtml(sk)}\n</section>';

    case 'review':
      final link = _safeHref(_s(b['url'])) ?? '';
      if (!link.startsWith('http')) return '';
      final btn = googleReviewButtonHtml(link, lang: lang);
      if (btn.isEmpty) return '';
      return '<section class="section">\n  <div class="contact-buttons">$btn</div>\n</section>';
  }
  return '';
}
