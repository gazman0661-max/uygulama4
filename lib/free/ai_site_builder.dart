import 'dart:convert';
import 'free_model.dart';
import 'free_templates.dart';

/// AI'ın döndürdüğü JSON'u (şemaya göre doğrulayarak) düzenlenebilir [FreeSite]'a çevirir.
/// AI konum/boyut belirlemez: yerleşim hazır şablonlardan gelir.
class AiSiteBuilder {
  AiSiteBuilder._();

  /// AI'ın seçebileceği değerler: builder'daki gerçek seçeneklerle birebir. Listede yoksa varsayılan.
  static const _themes = {
    'clean_light', 'midnight_dark', 'sunset_gradient', 'neon_cyber',
    'soft_pastel', 'obsidian_gold', 'glass_frost', 'royal_emerald',
  };
  static const _fonts = {'modern_sade', 'editorial', 'sicak_elyazisi', 'klasik', 'kalin_vurgulu'};
  static const _densities = {'ince', 'normal', 'kalin'};
  static const _galleryStyles = {'grid', 'slideshow', 'crossfade', 'marquee', 'bento'};

  static Set<String> get themes => _themes;
  static Set<String> get fonts => _fonts;
  static Set<String> get densities => _densities;
  static Set<String> get galleryStyles => _galleryStyles;
  static String clean(dynamic v, [int max = 600]) => _clean(v, max);

  static String _pick(dynamic v, Set<String> allowed, String fallback) {
    final s = _clean(v, 30);
    return allowed.contains(s) ? s : fallback;
  }

  static String _clean(dynamic v, [int max = 600]) {
    var s = (v ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('<', '').replaceAll('>', '').trim();
    if (s.length > max) s = s.substring(0, max).trim();
    return s;
  }

  /// Model bazen ```json çiti ekler; temizleyip çözer.
  static Map<String, dynamic> parse(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'^```(?:json)?', multiLine: false), '').replaceAll(RegExp(r'```$'), '').trim();
    final a = s.indexOf('{'), b = s.lastIndexOf('}');
    if (a < 0 || b <= a) throw const FormatException('json yok');
    final j = jsonDecode(s.substring(a, b + 1));
    if (j is! Map) throw const FormatException('json nesnesi değil');
    return Map<String, dynamic>.from(j);
  }

  /// AI bölüm listesini (hero, about, services, hours, menu…) düzenlenebilir bölümlere çevirir.
  /// Hem ilk üretimde hem "AI ile düzenle > bölüm ekle" akışında kullanılır.
  static List<FreeSection> sectionsFrom(List rawList, {String phone = '', String whatsapp = '', String lang = 'tr'}) {
    final digits = (String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
    final out = <FreeSection>[];
    final raw = rawList.whereType<Map>().take(8);
    for (final sec in raw) {
      switch (_clean(sec['type'], 20)) {
        case 'hero':
          final variant = _clean(sec['variant'], 12);
          if (variant == 'editorial' || variant == 'framed') {
            // formlardaki hero düzenleri (görselsiz çalışan iki düzen): builder'ın 'hero' bloğu
            final btn0 = sec['button'];
            final act = btn0 is Map ? _clean(btn0['action'], 10) : 'none';
            final href = (act == 'call' && phone.isNotEmpty)
                ? 'tel:${digits(phone)}'
                : (act == 'whatsapp' && whatsapp.isNotEmpty ? 'https://wa.me/${digits(whatsapp).replaceAll('+', '')}' : '');
            out.add(FreeSection(id: newFreeId(), kind: 'block', block: {
              'type': 'hero',
              'layout': variant,
              'name': _clean(sec['title'], 80),
              'tagline': _clean(sec['text'], 200),
              'eyebrow': '',
              'ctaText': btn0 is Map ? _clean(btn0['label'], 24) : '',
              'ctaHref': href,
              'images': [],
            }));
            break;
          }
          final s = buildFreeSectionPreset('hero', lang: lang);
          if (variant == 'left') {
            // sola yaslı, editoryal düzen
            for (final e in s.els) {
              e.align = 0;
              if (e.type == FType.title) { e.c = 3; e.w = 34; }
              if (e.type == FType.text) { e.c = 3; e.w = 30; }
              if (e.type == FType.button) { e.c = 3; }
            }
          } else if (variant == 'dark') {
            s.bg = 0xFF1E293B; // koyu bantlı, vurgulu
            for (final e in s.els) {
              if (e.type == FType.title || e.type == FType.text) e.color = 0xFFFFFFFF; // koyu zeminde okunur
            }
          }
          final t = s.els.where((e) => e.type == FType.title).firstOrNull;
          final x = s.els.where((e) => e.type == FType.text).firstOrNull;
          final b = s.els.where((e) => e.type == FType.button).firstOrNull;
          if (t != null) t.text = _clean(sec['title'], 80);
          if (x != null) x.text = _clean(sec['text'], 200);
          final btn = sec['button'];
          if (b != null) {
            final action = btn is Map ? _clean(btn['action'], 10) : 'none';
            final label = btn is Map ? _clean(btn['label'], 24) : '';
            if (action == 'call' && phone.isNotEmpty) {
              b.link = 'tel:${digits(phone)}';
            } else if (action == 'whatsapp' && whatsapp.isNotEmpty) {
              b.link = 'https://wa.me/${digits(whatsapp).replaceAll('+', '')}';
            } else {
              s.els.remove(b); // numara yoksa işlevsiz buton koyma
            }
            if (label.isNotEmpty) b.text = label;
          }
          out.add(s);
          break;
        case 'about':
          final body = _clean(sec['body'], 900);
          if (body.isEmpty) break;
          final lines = (body.length / 34).ceil() + body.split('\n').length;
          out.add(FreeSection(id: newFreeId(), kind: 'canvas', els: [
            FreeElement(id: newFreeId(), type: FType.title, c: 4, r: 2, w: 40, h: 5, text: _clean(sec['heading'], 60), size: 1),
            FreeElement(id: newFreeId(), type: FType.text, c: 6, r: 8, w: 36, h: lines * 3 + 2, text: body),
          ]));
          break;
        case 'highlights':
          final items = (sec['items'] as List? ?? const []).whereType<Map>().take(3).toList();
          if (items.isEmpty) break;
          final s = buildFreeSectionPreset('boxes3', lang: lang);
          final titles = s.els.where((e) => e.type == FType.title).toList();
          final texts = s.els.where((e) => e.type == FType.text).toList();
          for (var i = 0; i < 3; i++) {
            if (i < items.length) {
              titles[i].text = _clean(items[i]['title'], 30);
              texts[i].text = _clean(items[i]['text'], 90);
            } else {
              // kullanılmayan kutuyu kaldır (shape + başlık + yazı)
              final shapes = s.els.where((e) => e.type == FType.shape).toList();
              s.els.remove(shapes[i]);
              s.els.remove(titles[i]);
              s.els.remove(texts[i]);
            }
          }
          out.add(s);
          break;
        case 'services':
          final lines = _clean(sec['lines'], 1200);
          if (lines.isEmpty) break;
          out.add(FreeSection(id: newFreeId(), kind: 'block', block: {
            'type': 'services',
            'heading': _clean(sec['heading'], 60),
            'lines': lines,
          }));
          break;
        case 'hours':
          final rows = <Map<String, String>>[];
          for (final e in (sec['items'] as List? ?? const []).whereType<Map>().take(7)) {
            final d = _clean(e['day'], 20);
            if (d.isNotEmpty) rows.add({'day': d, 'range': _clean(e['range'], 20)});
          }
          if (rows.isEmpty) break;
          out.add(FreeSection(id: newFreeId(), kind: 'block', block: {'type': 'hours', 'heading': _clean(sec['heading'], 60), 'items': rows}));
          break;
        case 'menu':
          final cats = <Map<String, String>>[];
          for (final e in (sec['categories'] as List? ?? const []).whereType<Map>().take(6)) {
            final l = _clean(e['lines'], 800);
            if (l.isNotEmpty) cats.add({'title': _clean(e['title'], 40), 'lines': l});
          }
          if (cats.isEmpty) break;
          out.add(FreeSection(id: newFreeId(), kind: 'block', block: {'type': 'menu', 'heading': _clean(sec['heading'], 60), 'items': cats}));
          break;
        case 'packages':
          final pk = <Map<String, dynamic>>[];
          for (final e in (sec['items'] as List? ?? const []).whereType<Map>().take(4)) {
            final t0 = _clean(e['title'], 40);
            if (t0.isEmpty) continue;
            pk.add({
              'title': t0,
              'price': _clean(e['price'], 20),
              'services': _clean(e['services'], 400),
              'isFeatured': e['isFeatured'] == true,
            });
          }
          if (pk.isEmpty) break;
          out.add(FreeSection(id: newFreeId(), kind: 'block', block: {'type': 'packages', 'heading': _clean(sec['heading'], 60), 'items': pk}));
          break;
        case 'gallery':
          out.add(FreeSection(id: newFreeId(), kind: 'block', block: {
            'type': 'gallery',
            'style': _pick(sec['style'], _galleryStyles, 'grid'),
            'heading': _clean(sec['heading'], 60),
            'images': [],
          }));
          break;
        case 'faq':
          final items = <Map<String, String>>[];
          for (final e in (sec['items'] as List? ?? const []).whereType<Map>().take(5)) {
            final q = _clean(e['question'], 120), a = _clean(e['answer'], 300);
            if (q.isNotEmpty && a.isNotEmpty) items.add({'question': q, 'answer': a});
          }
          if (items.isEmpty) break;
          out.add(FreeSection(id: newFreeId(), kind: 'block', block: {
            'type': 'faq',
            'heading': _clean(sec['heading'], 60),
            'items': items,
          }));
          break;
        case 'contact':
          break; // contact her zaman en sona eklenir
      }
    }
    return out;
  }

  /// 06.10.2026 eklendi (kanka isteği) — AI'ın "yeni sayfa" JSON'unu [FreePage]'e çevirir.
  /// Bölüm yoksa ya da sayfa adı boşsa null döner (AI reddettiyse/boş döndüyse sayfa eklenmez).
  /// Yerleşim hazır şablonlardan gelir; AI konum/boyut belirlemez. Sona iletişim her zaman eklenir.
  static FreePage? buildPage(Map<String, dynamic> j, {String phone = '', String whatsapp = '', String lang = 'tr'}) {
    final name = _clean(j['page_name'], 30);
    if (name.isEmpty) return null;
    final out = sectionsFrom(j['sections'] as List? ?? const [], phone: phone, whatsapp: whatsapp, lang: lang);
    if (out.isEmpty) return null;
    out.add(FreeSection(id: newFreeId(), kind: 'contact'));
    final page = FreePage(name, desc: _clean(j['desc'], 155));
    page.setSections(out);
    return page;
  }

  static FreeSite build(Map<String, dynamic> j, {String phone = '', String whatsapp = '', String instagram = '', String lang = 'tr', String mapAddress = '', double? mapLat, double? mapLng}) {
    final site = FreeSite(
      name: _clean(j['site_name'], 60).isEmpty ? 'Sitem' : _clean(j['site_name'], 60),
      themeId: _pick(j['theme'], _themes, 'clean_light'),
      fontPackageId: _pick(j['font'], _fonts, 'modern_sade'),
      density: _pick(j['density'], _densities, 'normal'),
      lang: lang,
      phone: phone,
      whatsapp: whatsapp,
      instagram: instagram,
    );
    final page = site.pages.first;
    page.name = lang == 'en' ? 'Home' : 'Ana Sayfa';
    page.desc = _clean(j['desc'], 155);

    final out = sectionsFrom(j['sections'] as List? ?? const [], phone: phone, whatsapp: whatsapp, lang: lang);
    if (out.isEmpty) throw const FormatException('bölüm yok');
    // Harita: AI koordinat bilemez; yalnızca kullanıcı konum seçtiyse eklenir.
    // (Ücretsiz planda yayın anında mevcut güvenlik ağı 'map-section'ı zaten çıkarır.)
    if (mapLat != null && mapLng != null) {
      out.add(FreeSection(id: newFreeId(), kind: 'block', block: {
        'type': 'map',
        'heading': '',
        'address': _clean(mapAddress, 200),
        'lat': mapLat,
        'lng': mapLng,
      }));
    }
    out.add(FreeSection(id: newFreeId(), kind: 'contact'));
    page.setSections(out);
    return site;
  }
}
