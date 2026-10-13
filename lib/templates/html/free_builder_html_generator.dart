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

    // Sayfa TEK tuvaldir: öğeler, şeritler, hazır bloklar ve iletişim aynı ızgarada.
    final hasButtons = phone.isNotEmpty || whatsapp.isNotEmpty || instagram.isNotEmpty;
    String special(FreeElement e) {
      final sec = FreeSection(
        id: e.id,
        kind: e.type == FType.contact ? 'contact' : 'block',
        bg: e.bg,
        tc: e.color,
        fs: e.fs,
        block: e.block,
      );
      if (e.type == FType.block) {
        return _scoped(
          sec,
          extraPageBlocksHtml(
            [e.block],
            lang: site.lang,
            phone: phone.isEmpty ? null : phone,
            whatsapp: whatsapp.isEmpty ? null : whatsapp,
          ),
        );
      }
      // Free'de talep formu yazılmaz; hiç buton da yoksa boş öğe bırakma.
      if (!hasButtons && !FreePlanRestrictionService.isPremiumGeneration) return '';
      return _scoped(
        sec,
        contactBlockHtml(
          title: labels['contact']!,
          phone: phone.isEmpty ? null : phone,
          whatsapp: whatsapp.isEmpty ? null : whatsapp,
          instagram: instagram.isEmpty ? null : instagram,
          lang: site.lang,
          includeLeadForm: true,
          siteName: site.name,
        ),
      );
    }

    // Ayrı mobil düzen açıksa eksik mobil konumları tamamla (sonradan eklenen öğeler vb.).
    if (p.mobileCustom) p.ensureMobileGeometry();
    body.writeln(_canvasHtml(p.canvas, h1Id, special, mobileCustom: p.mobileCustom));

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

/// [mobileCustom] true ise ayrı mobil düzen yazılır: her öğeye `--mc`/`--mr` (mobil grid-column/row)
/// değişkenleri eklenir; ≤820px'de `.fb-m` kuralları alt alta dizmek yerine bu konumları kullanır.
/// false ise çıktı eskisiyle AYNIDIR.
String _canvasHtml(
  FreeSection s,
  String? h1Id,
  String Function(FreeElement) special, {
  bool mobileCustom = false,
}) {
  final mobileOrder = s.ordered;
  final buf = StringBuffer('<section class="fb-sec">'
      '<div class="fb-grid${mobileCustom ? ' fb-m' : ''}" style="--rows:${s.rows}'
      '${mobileCustom ? ';--mrows:${s.rowsOn(true)}' : ''}">');
  String mv(FreeElement e) => mobileCustom && e.hasMobileGeo
      ? '--mc:${e.mc! + 1}/span ${e.mw};--mr:${e.mr! + 1}/span ${e.mh};'
      : '';
  // Şeritler her zaman en arkada; diğer öğeler liste sırasıyla (sonraki = üstte).
  final bands = s.els.where((e) => e.type == FType.band && e.bg != 0).toList();
  for (final b in bands) {
    final hx = _hex(b.bg);
    buf.write('<div class="fb-e fb-band" aria-hidden="true" style="'
        'grid-column:1/span $kCols;grid-row:${b.r + 1}/span ${b.h};${mv(b)}'
        'background:$hx;box-shadow:0 0 0 100vmax $hx;clip-path:inset(0 -100vmax)"></div>');
  }
  // 08.10.2026 — Kart gruplama (mobil "alt alta" modu): bir şeklin (kutu) içine düşen başlık/yazı/buton/
  // resim/sosyal öğeleri, telefonda o kutunun İÇİNDE tek kart olarak görünür (eskiden kutular, başlıklar ve
  // yazılar ayrı ayrı alt alta diziliyordu). Masaüstünde `.fb-grp{display:contents}` olduğu için
  // yerleşim DEĞİŞMEZ. Ayrı mobil düzende (mobileCustom) konumlar zaten açık olduğundan gruplama yok.
  final kidsOf = <FreeElement, List<FreeElement>>{};
  final grouped = <FreeElement>{};
  if (!mobileCustom) {
    for (final k in s.els) {
      if (k.type == FType.band || k.type == FType.shape || k.type == FType.block || k.type == FType.contact) {
        continue;
      }
      final kc = k.c + k.w / 2, kr = k.r + k.h / 2;
      FreeElement? best;
      for (final sh in s.els) {
        if (sh.type != FType.shape) continue;
        if (kc >= sh.c && kc <= sh.c + sh.w && kr >= sh.r && kr <= sh.r + sh.h) {
          if (best == null || sh.w * sh.h < best.w * best.h) best = sh;
        }
      }
      if (best != null) {
        (kidsOf[best] ??= []).add(k);
        grouped.add(k);
      }
    }
  }
  void emit(FreeElement e) {
    if (e.type == FType.band) return;
    final band = s.bandOf(e);
    final secText = band == null ? null : autoContrastTextColor(_hex(band.bg));
    final isSpecial = e.type == FType.block || e.type == FType.contact;
    final inner = isSpecial ? special(e) : _inner(e, e.id == h1Id, secText);
    if (isSpecial && inner.trim().isEmpty) return;
    final fs = (e.type == FType.title || e.type == FType.text || e.type == FType.button)
        ? '--fs:${e.fontPx}px;'
        : '';
    const just = ['flex-start', 'center', 'flex-end'];
    const ta = ['left', 'center', 'right'];
    final align = isSpecial ? '' : 'justify-content:${just[e.align]};text-align:${ta[e.align]}';
    final inb = band == null || mobileCustom ? '' : ' fb-inb';
    final bb = band == null ? '' : '--bb:${_hex(band.bg)};';
    // Ayrı mobil düzen: mobil yazı boyutu ve (şerit üyeliği değiştiyse) mobil yazı rengi.
    var mob = mv(e);
    if (mobileCustom && e.hasMobileGeo) {
      if (e.mfs > 0 && (e.type == FType.title || e.type == FType.text || e.type == FType.button)) {
        mob += '--mfs:${e.mfs}px;';
      }
      if (e.color == 0 && (e.type == FType.title || e.type == FType.text)) {
        final mb = s.bandOf(e, mobile: true);
        if ((mb?.bg ?? 0) != (band?.bg ?? 0)) {
          mob += '--mtc:${mb == null ? 'var(--sitora-text)' : autoContrastTextColor(_hex(mb.bg))};';
        }
      }
    }
    buf.write('<div class="fb-e fb-${e.type.name}$inb" style="'
        'grid-column:${e.c + 1}/span ${e.w};grid-row:${e.r + 1}/span ${e.h};'
        '--h:${e.h};order:${mobileOrder.indexOf(e)};$mob$fs$bb$align">'
        '$inner</div>');
  }

  for (final e in s.els) {
    if (grouped.contains(e)) continue; // kartın içinde yazılacak
    final kids = e.type == FType.shape ? kidsOf[e] : null;
    if (kids == null || kids.isEmpty) {
      emit(e);
      continue;
    }
    final gbg = e.bg != 0 ? _hex(e.bg) : 'var(--sitora-chip-bg)';
    final gbd = e.bg != 0 ? 'none' : '1px solid var(--sitora-border)';
    final sorted = [...kids]..sort((a, b) => mobileOrder.indexOf(a).compareTo(mobileOrder.indexOf(b)));
    buf.write('<div class="fb-grp" style="order:${mobileOrder.indexOf(e)};--gbg:$gbg;--gbd:$gbd">');
    emit(e);
    for (final k in sorted) {
      emit(k);
    }
    buf.write('</div>');
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
    case FType.band:
    case FType.block:
    case FType.contact:
      return '';
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
.fb-sec{width:100%;overflow-x:clip}
/* Satırlar en az 8px; hazır blok (galeri/SSS/hizmet/iletişim) ve yazı içeriği kutudan uzunsa satırlar uzar,
   alttaki öğeler aşağı kayar — üst üste binme ve footer'a taşma olmaz. */
.fb-grid{max-width:1000px;margin:0 auto;display:grid;grid-template-columns:repeat(48,minmax(0,1fr));grid-template-rows:repeat(var(--rows),minmax(8px,auto))}
.fb-e{display:flex;align-items:center;min-width:0;overflow:hidden;overflow-wrap:anywhere}
.fb-t{margin:0;width:100%;font-size:var(--fs,34px);line-height:1.15}
.fb-p{margin:0;width:100%;font-size:var(--fs,16px);line-height:1.5}
.fb-btn{display:flex;width:100%;height:100%;align-items:center;justify-content:center;text-align:center;text-decoration:none;font-weight:600;font-size:var(--fs,16px);border-radius:var(--sitora-radius-btn)}
.fb-image img{width:100%;height:100%;object-fit:cover;display:block;border-radius:var(--sitora-radius-card)}
.fb-fill{width:100%;height:100%;border-radius:var(--sitora-radius-card)}
.fb-soc{display:block;height:100%;max-width:100%;aspect-ratio:1;margin:0 auto;padding:4px}
.fb-soc svg{width:100%;height:100%;display:block}
.fb-band{pointer-events:none}
.fb-grp{display:contents}
.fb-block,.fb-contact{display:block;overflow:visible}
.fb-fsz{font-size:var(--fb-fs)}
.fb-fsz .section-title{font-size:calc(var(--fb-fs)*1.6)!important}
.fb-fsz :is(p,li,td,summary,label,input,textarea,button:not([class*=arrow]),.service-name,.service-price,.faq-question,.faq-answer,.contact-btn,.prd-name,.prd-price,.menu-item-desc){font-size:var(--fb-fs)!important}
.fb-fsz :is(.service-duration,.gallery-caption,.sitora-lead-status){font-size:calc(var(--fb-fs)*.85)!important}
/* Masaüstü: resim/buton/sosyal/şekil/şerit satır yüksekliğini BÜYÜTMEZ (içsel boyutları sıfır sayılır);
   yalnız blok, iletişim, başlık ve yazı içerik kadar uzamaya izin verir. */
@media(min-width:821px){
.fb-band,.fb-image,.fb-button,.fb-social,.fb-shape{contain:size}
}
@media(max-width:820px){
.fb-grid{display:flex;flex-direction:column;gap:10px;padding:12px 16px}
.fb-band{display:none}
.fb-inb{background:var(--bb);box-shadow:0 0 0 100vmax var(--bb);clip-path:inset(-5px -100vmax)}
.fb-block,.fb-contact{min-height:0!important}
.fb-e{width:100%;height:auto;min-height:calc(var(--h)*8px);overflow:visible}
.fb-grp{display:flex;flex-direction:column;align-items:stretch;gap:6px;width:100%;box-sizing:border-box;padding:16px;border-radius:var(--sitora-radius-card);background:var(--gbg);border:var(--gbd)}
.fb-grp>.fb-shape{display:none}
.fb-grp>.fb-e{min-height:0}
.fb-grp .fb-inb{background:none;box-shadow:none;clip-path:none}
.fb-image{height:calc(var(--h)*8px)}
.fb-btn{min-height:calc(var(--h)*8px);padding:10px 14px}
.fb-fill{min-height:calc(var(--h)*8px)}
.fb-soc{height:calc(var(--h)*8px)}
}
/* Ayrı mobil düzen (.fb-m): telefonda aynı 48 kolonlu ızgara, mobil konumlarla. Satırlar en az 8px;
   yalnız hazır bloklar (galeri/SSS...) içerik kadar uzar, böylece alttaki öğeye binmez. */
@media(max-width:820px){
.fb-grid.fb-m{display:grid;gap:0;padding:0;grid-template-columns:repeat(48,minmax(0,1fr));grid-template-rows:repeat(var(--mrows),minmax(8px,auto))}
.fb-m .fb-band{display:block}
.fb-m .fb-e{grid-column:var(--mc)!important;grid-row:var(--mr)!important;width:auto;height:auto;min-height:0;overflow:hidden;contain:size}
.fb-m .fb-block,.fb-m .fb-contact{overflow:visible;contain:none}
.fb-m .fb-image{height:auto}
.fb-m .fb-btn{min-height:0;padding:0 8px}
.fb-m .fb-fill{min-height:0}
.fb-m .fb-soc{height:100%}
.fb-m .fb-t{font-size:var(--mfs,var(--fs,34px))}
.fb-m .fb-p{font-size:var(--mfs,var(--fs,16px))}
.fb-m .fb-btn{font-size:var(--mfs,var(--fs,16px))}
.fb-m .fb-e[style*="--mtc"] :is(.fb-t,.fb-p){color:var(--mtc)!important}
}
</style>''';
