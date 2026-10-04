import '../../free/free_model.dart';
import '../../free/free_social.dart';
import '../../services/free_plan_restriction_service.dart';
import 'extra_page_blocks.dart';
import 'shared_html_blocks.dart';

/// 02.10.2026 eklendi — "Sıfırdan Site Oluştur" çıktı üreticisi.
///
/// Kalite için ayrı bir render yolu YOK: her sayfa diğer sektörlerle AYNI
/// [wrapPageHtml] içinden geçer (tema, font paketi, yoğunluk, şekil stili,
/// SEO, favicon, yüzen iletişim butonu). Serbest tuval öğeleri `--sitora-*`
/// CSS değişkenlerini kullandığı için seçilen temaya otomatik uyar.
///
/// Bölümler:
///   canvas  -> `.fb-grid` (masaüstü: 48 kolon x 8px satır; ≤820px: alt alta)
///   block   -> extraPageBlocksHtml (galeri stilleri, video, hizmet, SSS)
///   contact -> contactBlockHtml (butonlar + talep formu; free'de form yazılmaz)
///
/// Rozet/kısıtlar burada UYGULANMAZ: LocalGenerationHelper.generateMultiPage ->
/// AppState.updateQtGeneratedFiles -> _finalizeHtmlFiles hepsini zaten yapar.
Map<String, String> generateFreeBuilderSite(FreeSite site) {
  final names = freePageFiles(site.pages);
  final links = <Map<String, String>>[
    for (var i = 0; i < site.pages.length; i++) {'href': names[i], 'label': site.pages[i].name},
  ];
  final phone = _cleanPhone(site.phone);
  final whatsapp = _digits(site.whatsapp);
  final instagram = _cleanInstagram(site.instagram);
  final labels = siteLabels(site.lang);
  final shapeStyle = pickVariant(site.name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final files = <String, String>{};

  for (var i = 0; i < site.pages.length; i++) {
    final p = site.pages[i];
    final body = StringBuffer()..writeln(_css);
    if (site.pages.length > 1) {
      body.writeln(siteNavHtml(links: links, active: names[i], siteName: site.name));
    }

    final h1Id = _firstTitleId(p);
    if (h1Id == null) {
      body.writeln('<h1 class="fb-sr">${escapeHtml(i == 0 ? site.name : p.name)}</h1>');
    }

    for (final s in p.sections) {
      if (s.isCanvas) {
        body.writeln(_canvasHtml(s, h1Id));
      } else if (s.isBlock) {
        body.writeln(_scoped(
          s,
          extraPageBlocksHtml(
            [s.block],
            lang: site.lang,
            phone: phone.isEmpty ? null : phone,
            whatsapp: whatsapp.isEmpty ? null : whatsapp,
          ),
        ));
      } else if (s.isContact) {
        final hasButtons = phone.isNotEmpty || whatsapp.isNotEmpty || instagram.isNotEmpty;
        // Free'de talep formu yazılmaz; hiç buton da yoksa boş bölüm bırakma.
        if (!hasButtons && !FreePlanRestrictionService.isPremiumGeneration) continue;
        body.writeln(_scoped(
          s,
          contactBlockHtml(
            title: labels['contact']!,
            phone: phone.isEmpty ? null : phone,
            whatsapp: whatsapp.isEmpty ? null : whatsapp,
            instagram: instagram.isEmpty ? null : instagram,
            lang: site.lang,
            includeLeadForm: true,
            siteName: site.name,
          ),
        ));
      }
    }

    files[names[i]] = wrapPageHtml(
      pageTitle: i == 0 ? site.name : '${p.name} — ${site.name}',
      bodyHtml: body.toString(),
      themeId: site.themeId,
      customTheme: site.customTheme,
      fontPackageId: site.fontPackageId,
      customFontPackage: site.customFontPackage,
      density: site.density,
      shapeStyle: shapeStyle,
      metaDescription: _metaDesc(p, site.name),
      schemaType: 'LocalBusiness',
      whatsapp: whatsapp.isEmpty ? null : whatsapp,
      phone: phone.isEmpty ? null : phone,
      lang: site.lang,
    );
  }
  return files;
}

/// Dosya adları: ilk sayfa index.html, diğerleri <slug>.html (çakışmada -2, -3...).
List<String> freePageFiles(List<FreePage> pages) {
  final used = <String>{'index'};
  final out = <String>[];
  for (var i = 0; i < pages.length; i++) {
    if (i == 0) {
      out.add('index.html');
      continue;
    }
    final base = _slug(pages[i].name);
    var s = base, n = 2;
    while (used.contains(s)) {
      s = '$base-${n++}';
    }
    used.add(s);
    out.add('$s.html');
  }
  return out;
}

String _slug(String s) {
  const m = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u'};
  var x = s.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
  m.forEach((k, v) => x = x.replaceAll(k, v));
  x = x.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return x.isEmpty ? 'sayfa' : x;
}

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

String _cleanPhone(String s) {
  final t = s.trim();
  final plus = t.startsWith('+') ? '+' : '';
  return '$plus${_digits(t)}';
}

String _cleanInstagram(String s) {
  var t = s.trim();
  if (t.isEmpty) return '';
  t = t.replaceFirst(RegExp(r'^https?://(www\.)?instagram\.com/', caseSensitive: false), '');
  t = t.replaceAll('@', '').split('/').first.split('?').first;
  return t.replaceAll(RegExp(r'[^A-Za-z0-9._]'), '');
}

String _hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

int _visual(FreeElement a, FreeElement b) {
  final r = a.r.compareTo(b.r);
  return r != 0 ? r : a.c.compareTo(b.c);
}

/// Sayfadaki ilk başlık (görsel sıraya göre) = h1.
String? _firstTitleId(FreePage p) {
  for (final s in p.sections) {
    if (!s.isCanvas) continue;
    final titles = s.els.where((e) => e.type == FType.title).toList()..sort(_visual);
    if (titles.isNotEmpty) return titles.first.id;
  }
  return null;
}

String _metaDesc(FreePage p, String siteName) {
  var d = p.desc.trim();
  if (d.isEmpty) {
    for (final s in p.sections) {
      if (!s.isCanvas) continue;
      for (final e in s.els) {
        if (e.type == FType.text && e.text.trim().isNotEmpty) {
          d = e.text.trim().replaceAll(RegExp(r'\s+'), ' ');
          break;
        }
      }
      if (d.isNotEmpty) break;
    }
  }
  if (d.isEmpty) d = siteName;
  return d.length > 160 ? '${d.substring(0, 157)}...' : d;
}

/// Hazır bölüm (galeri/video/hizmet/SSS/iletişim) için kullanıcı ayarları:
/// arka plan rengi ([FreeSection.bg]), yazı rengi ([FreeSection.tc]) ve yazı
/// boyutu ([FreeSection.fs], px).
///
/// Bloklar renkleri `--sitora-*` değişkenlerinden okuduğu için ayarlar o
/// bölümün kapsamında bu değişkenleri yeniden tanımlayarak uygulanır:
///  • Arka plan seçildiyse metin/kart/kenarlık zemine göre türetilir
///    (açık zemin -> koyu metin, koyu zemin -> beyaz metin) — [FreeTheme.onBg] ile AYNI kural.
///  • Yazı rengi seçildiyse (tc != 0) otomatik metin rengi yerine o kullanılır.
///  • Yazı boyutu seçildiyse (fs > 0) gövde metni `--fb-fs` px olur; bölüm
///    başlığı 1.6x, ikincil metinler (süre, altyazı, durum) 0.85x ölçeklenir.
///    Blokların CSS'i sabit px kullandığı için `.fb-fsz` kuralları `!important` ile ezer.
String _scoped(FreeSection s, String html) {
  if (html.trim().isEmpty) return html;
  if (s.bg == 0 && s.tc == 0 && s.fs <= 0) return html;
  final st = StringBuffer();
  var text = '';
  if (s.bg != 0) {
    final hex = _hex(s.bg);
    final light = autoContrastTextColor(hex) == '#111111';
    text = light ? '#111111' : '#FFFFFF';
    final sub = light ? 'rgba(17,17,17,0.72)' : 'rgba(255,255,255,0.78)';
    final card = light ? 'rgba(255,255,255,0.72)' : 'rgba(255,255,255,0.08)';
    final border = light ? 'rgba(0,0,0,0.12)' : 'rgba(255,255,255,0.18)';
    st.write('background:$hex;--sitora-subtext:$sub;--sitora-card-bg:$card;'
        '--sitora-border:$border;--sitora-chip-bg:$card;');
  }
  if (s.tc != 0) {
    text = _hex(s.tc);
    st.write('--sitora-subtext:$text;');
  }
  if (text.isNotEmpty) st.write('color:$text;--sitora-text:$text;');
  var cls = 'fb-scope';
  if (s.fs > 0) {
    cls += ' fb-fsz';
    st.write('--fb-fs:${s.fs}px;');
  }
  return '<div class="$cls" style="$st">$html</div>';
}

String _canvasHtml(FreeSection s, String? h1Id) {
  final bg = s.bg == 0 ? '' : 'background:${_hex(s.bg)};';
  // Bölüm arka planı seçildiyse tema rengiyle okunamaz hale gelmesin.
  final secText = s.bg == 0 ? null : autoContrastTextColor(_hex(s.bg));
  final mobileOrder = s.ordered;
  final buf = StringBuffer('<section class="fb-sec" style="$bg">'
      '<div class="fb-grid" style="--rows:${s.rows}">');
  final visual = [...s.els]..sort(_visual);
  for (final e in visual) {
    final fs = (e.type == FType.title || e.type == FType.text || e.type == FType.button)
        ? '--fs:${e.fontPx}px;'
        : '';
    const just = ['flex-start', 'center', 'flex-end'];
    const ta = ['left', 'center', 'right'];
    buf.write('<div class="fb-e fb-${e.type.name}" style="'
        'grid-column:${e.c + 1}/span ${e.w};grid-row:${e.r + 1}/span ${e.h};'
        '--h:${e.h};order:${mobileOrder.indexOf(e)};$fs'
        'justify-content:${just[e.align]};text-align:${ta[e.align]}">'
        '${_inner(e, e.id == h1Id, secText)}</div>');
  }
  buf.write('</div></section>');
  return buf.toString();
}

String _inner(FreeElement e, bool h1, String? secText) {
  final col = e.color != 0 ? _hex(e.color) : secText;
  final colorCss = col == null ? '' : 'color:$col;';
  switch (e.type) {
    case FType.title:
      final tag = h1 ? 'h1' : 'h2';
      return '<$tag class="fb-t" style="$colorCss">${escapeHtml(e.text).replaceAll('\n', '<br>')}</$tag>';
    case FType.text:
      return '<p class="fb-p" style="$colorCss">${escapeHtml(e.text).replaceAll('\n', '<br>')}</p>';
    case FType.button:
      final href = sanitizeButtonUrl(e.link) ?? '#';
      final ext = href.startsWith('http') ? ' target="_blank" rel="noopener"' : '';
      final bg = e.bg != 0 ? _hex(e.bg) : 'var(--sitora-accent)';
      final fg = e.color != 0 ? _hex(e.color) : 'var(--sitora-accent-text)';
      return '<a class="fb-btn" href="${escapeHtml(href)}"$ext style="background:$bg;color:$fg">'
          '${escapeHtml(e.text)}</a>';
    case FType.image:
      final src = e.img ?? '';
      if (!src.startsWith('data:image/') && !src.startsWith('http')) return '';
      return '<img loading="lazy" src="${escapeHtml(src)}" alt="${escapeHtml(e.text)}">';
    case FType.social:
      final pf = SocialPlatform.values.firstWhere(
        (x) => x.name == e.platform,
        orElse: () => SocialPlatform.whatsapp,
      );
      final svg = FreeSocial.forPlatform(pf).trim();
      final href = sanitizeButtonUrl(e.link) ?? '#';
      return '<a class="fb-soc" href="${escapeHtml(href)}" target="_blank" rel="noopener" '
          'aria-label="${escapeHtml(FreeSocial.labelFor(pf))}">$svg</a>';
    case FType.shape:
      final bg = e.bg != 0
          ? 'background:${_hex(e.bg)}'
          : 'background:var(--sitora-chip-bg);border:1px solid var(--sitora-border)';
      return '<div class="fb-fill" style="$bg"></div>';
  }
}

const String _css = '''
<style>
.fb-sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
.fb-sec{width:100%}
.fb-grid{max-width:1000px;margin:0 auto;display:grid;grid-template-columns:repeat(48,minmax(0,1fr));grid-template-rows:repeat(var(--rows),8px)}
.fb-e{display:flex;align-items:center;min-width:0;overflow:hidden;overflow-wrap:anywhere}
.fb-t{margin:0;width:100%;font-size:var(--fs,34px);line-height:1.15}
.fb-p{margin:0;width:100%;font-size:var(--fs,16px);line-height:1.5}
.fb-btn{display:flex;width:100%;height:100%;align-items:center;justify-content:center;text-align:center;text-decoration:none;font-weight:600;font-size:var(--fs,16px);border-radius:var(--sitora-radius-btn)}
.fb-image img{width:100%;height:100%;object-fit:cover;display:block;border-radius:var(--sitora-radius-card)}
.fb-fill{width:100%;height:100%;border-radius:var(--sitora-radius-card)}
.fb-soc{display:block;height:100%;max-width:100%;aspect-ratio:1;margin:0 auto;padding:4px}
.fb-soc svg{width:100%;height:100%;display:block}
.fb-fsz{font-size:var(--fb-fs)}
.fb-fsz .section-title{font-size:calc(var(--fb-fs)*1.6)!important}
.fb-fsz :is(p,li,td,summary,label,input,textarea,button:not([class*=arrow]),.service-name,.service-price,.faq-question,.faq-answer,.contact-btn,.prd-name,.prd-price,.menu-item-desc){font-size:var(--fb-fs)!important}
.fb-fsz :is(.service-duration,.gallery-caption,.sitora-lead-status){font-size:calc(var(--fb-fs)*.85)!important}
@media(max-width:820px){
.fb-grid{display:flex;flex-direction:column;gap:10px;padding:12px 16px}
.fb-e{width:100%;height:auto;min-height:calc(var(--h)*8px);overflow:visible}
.fb-image{height:calc(var(--h)*8px)}
.fb-btn{min-height:calc(var(--h)*8px);padding:10px 14px}
.fb-fill{min-height:calc(var(--h)*8px)}
.fb-soc{height:calc(var(--h)*8px)}
}
</style>''';
