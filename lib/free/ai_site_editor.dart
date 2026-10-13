import 'dart:convert';
import 'ai_site_builder.dart';
import 'free_model.dart';

class AiEditResult {
  final FreeSite site; // değiştirilmiş KOPYA (orijinale dokunulmaz)
  final List<String> changes;
  final String summary;
  final String refused;
  AiEditResult(this.site, this.changes, this.summary, this.refused);
}

/// AI'ın düzenleme önerisini doğrulayıp sitenin KOPYASINA uygular. Orijinal site, kullanıcı
/// "Uygula" diyene kadar değişmez. Görseller AI'a hiç gitmez ve AI tarafından değiştirilemez.
class AiSiteEditor {
  AiSiteEditor._();

  static const _allowed = <String, Set<String>>{
    'gallery': {'heading', 'style', 'beforeAfter'},
    'video': {'heading', 'orientation'},
    'services': {'heading', 'lines'},
    'faq': {'heading', 'items'},
    'map': {'heading'},
    'hero': {'layout', 'name', 'tagline', 'eyebrow', 'ctaText', 'ctaHref'},
    'hours': {'heading', 'items'},
    'testimonials': {'heading'}, // yorumları AI değiştiremez/ekleyemez
    'products': {'heading'},
    'menu': {'heading', 'items'},
    'packages': {'heading', 'items'},
    'team': {'heading', 'items'},
    'timeline': {'heading', 'items'},
    'skills': {'heading', 'skills'},
    'review': {'url'},
  };

  static const _itemKeys = <String, Set<String>>{
    'faq': {'question', 'answer'},
    'hours': {'day', 'range'},
    'menu': {'title', 'lines'},
    'packages': {'title', 'sessionLabel', 'price', 'originalPrice', 'services', 'note', 'isFeatured'},
    'team': {'name', 'specialty', 'bio', 'tags'},
    'timeline': {'year', 'title', 'description'},
  };

  static const _heroLayouts = {'centered', 'editorial', 'framed', 'split', 'diagonal', 'social'};
  static final _safeLink = RegExp(r'^(https?://|tel:|mailto:)', caseSensitive: false);

  static String _t(dynamic v, int max) => AiSiteBuilder.clean(v, max);

  /// AI'a gidecek kısa site özeti (görsel verisi YOK).
  static String describe(FreeSite site, int pageIndex) {
    final page = site.pages[pageIndex];
    final els = page.canvas.els.toList()..sort((a, b) => a.r != b.r ? a.r.compareTo(b.r) : a.c.compareTo(b.c));
    final out = <Map<String, dynamic>>[];
    for (final e in els) {
      switch (e.type) {
        case FType.title:
        case FType.text:
        case FType.button:
          out.add({'id': e.id, 'type': e.type.name, 'text': _t(e.text, 300)});
          break;
        case FType.block:
          final fields = <String, dynamic>{};
          e.block.forEach((k, v) {
            if (k == 'type' || k == 'lat' || k == 'lng' || k == 'address') return;
            if (k == 'images') {
              fields['image_count'] = v is List ? v.length : 0;
            } else if (v is String) {
              fields[k] = _t(v, 400);
            } else if (v is bool || v is num) {
              fields[k] = v;
            } else if (v is List) {
              fields[k] = [
                for (final it in v.take(20))
                  if (it is Map) {for (final en in it.entries) en.key.toString(): en.value is String ? _t(en.value, 300) : en.value}
              ];
            }
          });
          out.add({'id': e.id, 'type': 'block', 'block_type': e.block['type'], 'fields': fields});
          break;
        case FType.contact:
          out.add({'id': e.id, 'type': 'contact'});
          break;
        default:
          break;
      }
    }
    return jsonEncode({
      'site': {'name': site.name, 'theme': site.themeId, 'font': site.fontPackageId, 'density': site.density, 'lang': site.lang},
      'elements': out,
    });
  }

  /// 06.10.2026 eklendi (kanka isteği) — "AI ile yeni sayfa" için AI'a gidecek kısa bağlam:
  /// site adı/tema/dil + mevcut sayfa adları ve ana başlıkları (görsel verisi YOK).
  static String describeForNewPage(FreeSite site) {
    final pages = <Map<String, dynamic>>[];
    for (final p in site.pages.take(12)) {
      final titles = <String>[];
      for (final e in p.canvas.els) {
        if (e.type == FType.title && e.text.trim().isNotEmpty && titles.length < 4) titles.add(_t(e.text, 80));
      }
      pages.add({'name': _t(p.name, 40), 'headings': titles});
    }
    return jsonEncode({
      'site': {'name': site.name, 'theme': site.themeId, 'font': site.fontPackageId, 'lang': site.lang},
      'pages': pages,
    });
  }

  /// 06.10.2026 eklendi — AI'ın ürettiği yeni sayfayı sitenin KOPYASINA ekler (orijinale dokunulmaz).
  /// Sayfa sınırı çağıran tarafta (builder'ın mevcut kapısıyla) kontrol edilir; burada yalnızca
  /// güvenli üst sınır ([maxPages]) vardır. Sayfa adı mevcutlarla çakışırsa "(2)" eklenir.
  static const int maxPages = 20;

  static AiEditResult addPage(FreeSite original, Map<String, dynamic> j) {
    final copy = FreeSite.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(original.toJson())) as Map));
    final summary = AiSiteBuilder.clean(j['summary'], 300);
    final refused = AiSiteBuilder.clean(j['refused'], 300);
    final changes = <String>[];
    if (copy.pages.length >= maxPages) return AiEditResult(copy, changes, summary, refused.isEmpty ? 'Sayfa sayısı sınırına ulaşıldı.' : refused);
    final page = AiSiteBuilder.buildPage(j, phone: copy.phone, whatsapp: copy.whatsapp, lang: copy.lang);
    if (page == null) return AiEditResult(copy, changes, summary, refused);
    var name = page.name;
    final taken = copy.pages.map((p) => p.name.toLowerCase()).toSet();
    var n = 2;
    while (taken.contains(name.toLowerCase())) {
      name = '${page.name} ($n)';
      n++;
    }
    page.name = name;
    copy.pages.add(page);
    final secCount = page.canvas.els.where((e) => e.type == FType.block).length;
    changes.add('Yeni sayfa: $name ($secCount bölüm)');
    return AiEditResult(copy, changes, summary, refused);
  }

  static bool _applyBlock(Map<String, dynamic> block, Map fields, List<String> changes) {
    final type = (block['type'] ?? '').toString();
    final allow = _allowed[type];
    if (allow == null) return false;
    var changed = false;
    fields.forEach((rawK, v) {
      final k = rawK.toString();
      if (!allow.contains(k)) return;
      dynamic nv;
      switch (k) {
        case 'style':
          if (AiSiteBuilder.galleryStyles.contains(v)) nv = v;
          break;
        case 'layout':
          if (_heroLayouts.contains(v)) nv = v;
          break;
        case 'orientation':
          if (v == 'landscape' || v == 'portrait') nv = v;
          break;
        case 'beforeAfter':
          if (v is bool) nv = v;
          break;
        case 'ctaHref':
        case 'url':
          final s = _t(v, 300);
          if (s.isEmpty || _safeLink.hasMatch(s)) nv = s;
          break;
        case 'items':
          final keys = _itemKeys[type];
          if (keys == null || v is! List) break;
          final old = block['items'] is List ? (block['items'] as List).length : 0;
          // ekip/zaman çizelgesinde AI yeni kişi/adım UYDURAMAZ: sayı artamaz
          final cap = (type == 'team' || type == 'timeline') ? old : 20;
          final list = <Map<String, dynamic>>[];
          for (final it in v.whereType<Map>().take(cap)) {
            final m = <String, dynamic>{};
            for (final key in keys) {
              final x = it[key];
              if (x is bool) {
                m[key] = x;
              } else if (x != null) {
                m[key] = _t(x, 400);
              }
            }
            list.add(m);
          }
          if (list.isNotEmpty) nv = list;
          break;
        default:
          nv = _t(v, k == 'lines' || k == 'skills' ? 1200 : 200);
      }
      if (nv != null && jsonEncode(block[k]) != jsonEncode(nv)) {
        block[k] = nv;
        changed = true;
      }
    });
    if (changed) changes.add('Güncellendi: ${_blockTitle(type)}');
    return changed;
  }

  static String _blockTitle(String type) => const {
        'gallery': 'Galeri', 'video': 'Video', 'services': 'Hizmet listesi', 'faq': 'SSS', 'map': 'Harita',
        'hero': 'Hero', 'hours': 'Çalışma saatleri', 'testimonials': 'Yorumlar', 'products': 'Ürünler',
        'menu': 'Menü', 'packages': 'Paketler', 'team': 'Ekip', 'timeline': 'Zaman çizelgesi',
        'skills': 'Etiketler', 'review': 'Google yorum butonu',
      }[type] ?? type;

  static AiEditResult apply(FreeSite original, int pageIndex, Map<String, dynamic> j) {
    final copy = FreeSite.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(original.toJson())) as Map));
    final page = copy.pages[pageIndex];
    final els = page.canvas.els;
    final changes = <String>[];

    // 1) tema / font / kalınlık
    final st = j['site'];
    if (st is Map) {
      final th = st['theme'], fo = st['font'], de = st['density'];
      if (AiSiteBuilder.themes.contains(th) && th != copy.themeId) {
        copy.themeId = th as String;
        changes.add('Tema değişti');
      }
      if (AiSiteBuilder.fonts.contains(fo) && fo != copy.fontPackageId) {
        copy.fontPackageId = fo as String;
        changes.add('Yazı tipi değişti');
      }
      if (AiSiteBuilder.densities.contains(de) && de != copy.density) {
        copy.density = de as String;
        changes.add('Yazı kalınlığı değişti');
      }
    }

    // 2) metinler
    for (final it in (j['set_text'] as List? ?? const []).whereType<Map>().take(30)) {
      final el = els.where((e) => e.id == it['id']?.toString()).firstOrNull;
      if (el == null || !(el.type == FType.title || el.type == FType.text || el.type == FType.button)) continue;
      final nt = _t(it['text'], el.type == FType.button ? 40 : 600);
      if (nt.isEmpty || nt == el.text) continue;
      el.text = nt;
      changes.add('Metin: “${nt.length > 40 ? '${nt.substring(0, 40)}…' : nt}”');
    }

    // 3) bloklar
    for (final it in (j['set_block'] as List? ?? const []).whereType<Map>().take(20)) {
      final el = els.where((e) => e.id == it['id']?.toString() && e.type == FType.block).firstOrNull;
      final f = it['fields'];
      if (el == null || f is! Map) continue;
      _applyBlock(el.block, f, changes);
    }

    // 4) silme
    for (final id in (j['remove'] as List? ?? const []).take(20)) {
      final el = els.where((e) => e.id == id?.toString()).firstOrNull;
      if (el == null || el.type == FType.contact || el.type == FType.band) continue;
      els.remove(el);
      if (el.type == FType.block) {
        // tam genişlik blok: altındakileri yukarı çek
        for (final e2 in els) {
          if (e2.type != FType.band && e2.r >= el.r + el.h) e2.r -= el.h;
        }
      }
      changes.add('Silindi: ${el.type == FType.block ? _blockTitle((el.block['type'] ?? '').toString()) : (el.text.isEmpty ? el.type.name : _t(el.text, 30))}');
    }

    // 5) yeni bölümler (iletişim bölümünün ÜSTÜNE)
    final addRaw = j['add_sections'];
    if (addRaw is List && addRaw.isNotEmpty) {
      final secs = AiSiteBuilder.sectionsFrom(addRaw.take(5).toList(), phone: copy.phone, whatsapp: copy.whatsapp, lang: copy.lang);
      if (secs.isNotEmpty) {
        final contact = els.where((e) => e.type == FType.contact).firstOrNull;
        if (contact != null) els.remove(contact);
        page.appendSections(secs);
        if (contact != null) {
          var bottom = 0;
          for (final e in els) {
            if (e.type != FType.band && e.r + e.h > bottom) bottom = e.r + e.h;
          }
          contact.r = bottom + 1;
          els.add(contact);
        }
        changes.add('${secs.length} bölüm eklendi');
      }
    }

    return AiEditResult(copy, changes, AiSiteBuilder.clean(j['summary'], 300), AiSiteBuilder.clean(j['refused'], 300));
  }
}
