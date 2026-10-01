library text_styling;

import 'google_font_catalog.dart';
import 'rich_text_markup.dart';
import 'shared_html_blocks.dart' show escapeHtml;

class TextStylingPolicy {
  TextStylingPolicy._();

  static const int freeCustomSections = 2;

  static const int maxCustomSections = 12;

  static const bool customColorIsPremium = true;

  static const bool wordStyleIsPremium = true;
}

const Map<String, List<String>> kStyleSectionClasses = {
  'hero': ['hero'],
  'about': ['about-section'],
  'services': ['services-section'],
  'products': ['products-section'],
  'gallery': ['gallery-section'],
  'works': ['gallery-section'],
  'video': ['video-section'],
  'hours': ['hours-section'],
  'testimonials': ['testimonial-section'],
  'faq': ['faq-section'],
  'map': ['map-section'],
  'menu': ['menu-section', 'qr-menu-section'],
  'team': ['team-section', 'practitioner-section'],
  'packages': ['packages-section'],
  'schedule': ['schedule-section'],
  'timeline': ['timeline-section'],
  'contact': ['contact-section'],
};

const Set<String> _sizeIds = {'s', 'l', 'xl'};

class TextStyling {
  TextStyling._();

  static bool isEmptyData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return true;
    final sec = data['sections'];
    final cus = data['custom'];
    final hasSec = sec is Map && sec.values.any((v) => v is Map && v.isNotEmpty);
    final hasCus = cus is List && cus.isNotEmpty;
    return !hasSec && !hasCus;
  }

  static bool needsPremium(String composedHtml, Map<String, dynamic>? data) {
    if (richMarkupUsesPremium(composedHtml)) return true;
    if (composedHtml.contains('data-sx-prem="1"')) return true;
    if (RegExp(r'data-sx-font="').hasMatch(composedHtml)) return true;
    if (data == null) return false;
    final custom = data['custom'];
    if (custom is List && custom.length > TextStylingPolicy.freeCustomSections) return true;
    final sec = data['sections'];
    if (sec is Map) {
      for (final v in sec.values) {
        if (v is Map && (styleUsesFont(v) || (TextStylingPolicy.customColorIsPremium && styleUsesCustomColor(v)))) {
          return true;
        }
      }
    }
    if (custom is List) {
      for (final c in custom) {
        if (c is Map && c['style'] is Map) {
          final st = c['style'] as Map;
          if (styleUsesFont(st) || (TextStylingPolicy.customColorIsPremium && styleUsesCustomColor(st))) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool styleUsesFont(Map style) =>
      fontNameFromSlug(style['hf']?.toString()) != null || fontNameFromSlug(style['tf']?.toString()) != null;

  static final RegExp _blockFontRe = RegExp(r'data-sx-font="([^"]+)"');

  static List<String> extraFontsOf(String html, Map<String, dynamic>? data, {required bool isPremium}) {
    if (!isPremium) return const [];
    final out = <String>[];
    void add(String? name) {
      if (name != null && !out.contains(name)) out.add(name);
    }

    for (final m in _blockFontRe.allMatches(html)) {
      for (final slug in m.group(1)!.split(' ')) {
        add(fontNameFromSlug(slug));
      }
    }
    if (data != null) {
      void fromStyle(dynamic st) {
        if (st is! Map) return;
        add(fontNameFromSlug(st['hf']?.toString()));
        add(fontNameFromSlug(st['tf']?.toString()));
      }

      final sec = data['sections'];
      if (sec is Map) sec.values.forEach(fromStyle);
      final cus = data['custom'];
      if (cus is List) {
        for (final c in cus) {
          if (c is Map) fromStyle(c['style']);
        }
      }
    }
    richMarkupFontNames(html).forEach(add);
    return out.take(kMaxExtraFontsPerSite).toList();
  }

  static bool styleUsesCustomColor(Map style) {
    for (final k in const ['hc', 'tc']) {
      final v = normalizeHexColor(style[k]?.toString());
      if (v != null && !isFreePaletteColor(v)) return true;
    }
    return false;
  }

  static String apply(
    String html,
    Map<String, dynamic>? data, {
    required bool isPremium,
    bool insertCustom = true,
  }) {
    final composed = compose(html, data, isPremium: isPremium, insertCustom: insertCustom);
    final fontList = extraFontsOf(composed, data, isPremium: isPremium);
    final converted = richMarkupToHtml(composed, isPremium: isPremium, allowedFonts: fontList.toSet());
    return fontList.isEmpty ? converted : _injectFontLinks(converted, fontList);
  }

  static Map<String, String> applyToFiles(
    Map<String, String> files,
    Map<String, dynamic>? data, {
    required bool isPremium,
  }) {
    final indexName = _indexNameOf(files);
    return files.map((name, content) {
      if (!name.toLowerCase().endsWith('.html')) return MapEntry(name, content);
      return MapEntry(
        name,
        apply(content, data, isPremium: isPremium, insertCustom: name == indexName),
      );
    });
  }

  static String? _indexNameOf(Map<String, String> files) {
    for (final k in files.keys) {
      if (k.toLowerCase() == 'index.html') return k;
    }
    for (final k in files.keys) {
      if (k.toLowerCase().endsWith('.html')) return k;
    }
    return null;
  }

  static bool filesNeedPremium(Map<String, String> files, Map<String, dynamic>? data) {
    final indexName = _indexNameOf(files);
    for (final e in files.entries) {
      if (!e.key.toLowerCase().endsWith('.html')) continue;
      final isIndex = e.key == indexName;
      final composed = compose(e.value, data, isPremium: true, insertCustom: isIndex);
      if (needsPremium(composed, isIndex ? data : null)) return true;
    }
    return false;
  }

  static String compose(
    String html,
    Map<String, dynamic>? data, {
    required bool isPremium,
    bool insertCustom = true,
  }) {
    if (isEmptyData(data)) return html;
    var out = html;
    final sections = _sectionsOf(data!);
    final customs = _customOf(data, isPremium: isPremium);

    sections.forEach((key, st) {
      final title = (st['title'] ?? '').toString().trim();
      if (title.isEmpty || key == 'hero') return;
      out = _replaceSectionTitle(out, key, title);
    });

    if (insertCustom) {
      for (final c in customs.reversed) {
        if ((c['after'] ?? 'end').toString() == 'end') continue;
        final block = _customSectionHtml(c);
        if (block.isEmpty) continue;
        out = _insertAfter(out, (c['after']).toString(), block);
      }
      for (final c in customs) {
        if ((c['after'] ?? 'end').toString() != 'end') continue;
        final block = _customSectionHtml(c);
        if (block.isEmpty) continue;
        out = _insertAfter(out, 'end', block);
      }
    }

    final fonts = extraFontsOf(out, data, isPremium: isPremium).toSet();
    final css = _buildCss(sections, customs, isPremium: isPremium, fonts: fonts);
    if (css.isNotEmpty) out = _injectStyle(out, css);
    return out;
  }

  static Map<String, Map<String, dynamic>> _sectionsOf(Map<String, dynamic> data) {
    final raw = data['sections'];
    final out = <String, Map<String, dynamic>>{};
    if (raw is! Map) return out;
    raw.forEach((k, v) {
      final key = k.toString();
      if (!kStyleSectionClasses.containsKey(key)) return;
      if (v is Map && v.isNotEmpty) {
        out[key] = v.map((a, b) => MapEntry(a.toString(), b));
      }
    });
    return out;
  }

  static final RegExp _idRe = RegExp(r'[^a-z0-9]');

  static List<Map<String, dynamic>> _customOf(Map<String, dynamic> data, {required bool isPremium}) {
    final raw = data['custom'];
    final out = <Map<String, dynamic>>[];
    if (raw is! List) return out;
    final limit = isPremium ? TextStylingPolicy.maxCustomSections : TextStylingPolicy.freeCustomSections;
    for (final e in raw) {
      if (e is! Map) continue;
      if (out.length >= limit) break;
      final m = e.map((k, v) => MapEntry(k.toString(), v));
      var id = (m['id'] ?? '').toString().toLowerCase().replaceAll(_idRe, '');
      if (id.isEmpty) id = 'x${out.length + 1}';
      m['id'] = id;
      out.add(m);
    }
    return out;
  }

  static RegExp _sectionRe(String cls, {bool heroPrefix = false}) {
    if (heroPrefix) {
      return RegExp(r'<section class="hero[^"]*"[^>]*>.*?</section>', dotAll: true);
    }
    return RegExp(
      '<section class="[^"]*\\b${RegExp.escape(cls)}\\b[^"]*"[^>]*>.*?</section>',
      dotAll: true,
    );
  }

  static RegExp? _sectionReForKey(String key) {
    if (key == 'hero') return _sectionRe('hero', heroPrefix: true);
    final classes = kStyleSectionClasses[key];
    if (classes == null || classes.isEmpty) return null;
    return _sectionRe(classes.first);
  }

  static String _replaceSectionTitle(String html, String key, String title) {
    final re = _sectionReForKey(key);
    if (re == null) return html;
    final m = re.firstMatch(html);
    if (m == null) return html;
    final block = m.group(0)!;
    final titleRe = RegExp(r'(<h2 class="section-title"[^>]*>)([^<]*)');
    if (!titleRe.hasMatch(block)) return html;
    final replaced = block.replaceFirstMapped(
      titleRe,
      (t) => '${t.group(1)}${escapeHtml(title)}',
    );
    return html.substring(0, m.start) + replaced + html.substring(m.end);
  }

  static final RegExp _trustBarRe = RegExp(
    r'<div class="trust-bar">.*?</div>\s*</div>\s*</div>',
    dotAll: true,
  );

  static String _insertAfter(String html, String after, String block) {
    if (after != 'end') {
      final re = _sectionReForKey(after);
      if (re != null) {
        final m = re.firstMatch(html);
        if (m != null) {
          var at = m.end;
          if (after == 'hero') {
            final tail = html.substring(at);
            final lead = tail.length - tail.trimLeft().length;
            final tb = _trustBarRe.matchAsPrefix(tail, lead);
            if (tb != null) at = at + tb.end;
          }
          return '${html.substring(0, at)}\n$block${html.substring(at)}';
        }
      }
    }
    final contact = _sectionRe('contact-section').firstMatch(html);
    if (contact != null) {
      return '${html.substring(0, contact.start)}$block\n${html.substring(contact.start)}';
    }
    final bodyStart = html.toLowerCase().indexOf('<body');
    final scriptAt = html.toLowerCase().indexOf('<script', bodyStart < 0 ? 0 : bodyStart);
    if (scriptAt >= 0) {
      return '${html.substring(0, scriptAt)}$block\n${html.substring(scriptAt)}';
    }
    final bodyEnd = html.toLowerCase().lastIndexOf('</body>');
    if (bodyEnd >= 0) {
      return '${html.substring(0, bodyEnd)}$block\n${html.substring(bodyEnd)}';
    }
    return '$html\n$block';
  }

  static String _injectFontLinks(String html, List<String> fonts) {
    final tags = googleFontsLinkTags(fonts);
    if (tags.isEmpty) return html;
    final idx = html.toLowerCase().lastIndexOf('</head>');
    if (idx >= 0) return '${html.substring(0, idx)}$tags\n${html.substring(idx)}';
    return '$tags\n$html';
  }

  static String _injectStyle(String html, String css) {
    final tag = '<style id="sitora-text-styling">\n$css\n</style>';
    final idx = html.toLowerCase().lastIndexOf('</head>');
    if (idx >= 0) return '${html.substring(0, idx)}$tag\n${html.substring(idx)}';
    return '$tag\n$html';
  }

  static String _paragraphs(String body) {
    final parts = body.trim().split(RegExp(r'\n\s*\n'));
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => '<p>${escapeHtml(p).replaceAll('\n', '<br>')}</p>')
        .join('\n  ');
  }

  static String _customSectionHtml(Map<String, dynamic> c) {
    final heading = (c['heading'] ?? '').toString().trim();
    final body = (c['body'] ?? '').toString().trim();
    if (richPlainText(heading).trim().isEmpty && richPlainText(body).trim().isEmpty) return '';
    final align = const {'left', 'center', 'right'}.contains(c['align']) ? c['align'] as String : '';
    final id = c['id'] as String;
    final alignStyle = align.isEmpty ? '' : ' style="text-align:$align"';
    final h = richPlainText(heading).trim().isEmpty
        ? ''
        : '<h2 class="section-title">${escapeHtml(heading)}</h2>\n  ';
    final p = richPlainText(body).trim().isEmpty ? '' : _paragraphs(body);
    return '<section class="section sx-custom sx-c-$id"$alignStyle>\n  $h$p\n</section>';
  }

  static String _buildCss(
    Map<String, Map<String, dynamic>> sections,
    List<Map<String, dynamic>> customs, {
    required bool isPremium,
    required Set<String> fonts,
  }) {
    final buf = StringBuffer();
    sections.forEach((key, st) {
      final classes = kStyleSectionClasses[key]!;
      final scopes = classes.map((c) => '.$c').toList();
      buf.write(sectionStyleCss(scopes, st, isHero: key == 'hero', allowCustomColor: isPremium || !TextStylingPolicy.customColorIsPremium, allowedFonts: fonts));
    });
    for (final c in customs) {
      final st = c['style'];
      if (st is Map) {
        buf.write(sectionStyleCss(
          ['.sx-c-${c['id']}'],
          st.map((k, v) => MapEntry(k.toString(), v)),
          allowCustomColor: isPremium || !TextStylingPolicy.customColorIsPremium,
          allowedFonts: fonts,
        ));
      }
    }
    return buf.toString();
  }

  static const _textTags = 'p,li,span,div,summary,dt,dd,td,th,blockquote,figcaption,small,label';
  static const _sizeTags = 'p,li,summary,dd,td,th,blockquote,figcaption';

  static const _mainHeading = {
    's': 'clamp(20px,3.2vw,26px)',
    'l': 'clamp(32px,5.5vw,46px)',
    'xl': 'clamp(40px,8vw,64px)',
  };
  static const _subHeading = {'s': '15px', 'l': '22px', 'xl': '28px'};
  static const _heroHeading = {
    's': 'clamp(26px,5vw,36px)',
    'l': 'clamp(44px,8vw,68px)',
    'xl': 'clamp(56px,11vw,96px)',
  };
  static const _bodySize = {'s': '14px', 'l': '18px', 'xl': '21px'};
  static const _heroSub = {'s': '13px', 'l': '19px', 'xl': '24px'};

  static String sectionStyleCss(
    List<String> scopes,
    Map<String, dynamic> st, {
    bool isHero = false,
    bool allowCustomColor = true,
    Set<String>? allowedFonts,
  }) {
    String? fontOf(String k) {
      final name = fontNameFromSlug(st[k]?.toString());
      if (name == null) return null;
      if (allowedFonts != null && !allowedFonts.contains(name)) return null;
      return fontFamilyCss(name);
    }

    String? colorOf(String k) {
      final v = normalizeHexColor(st[k]?.toString());
      if (v == null) return null;
      if (!allowCustomColor && !isFreePaletteColor(v)) return null;
      return v;
    }

    String sizeOf(String k) {
      final v = (st[k] ?? '').toString();
      return _sizeIds.contains(v) ? v : '';
    }

    final hc = colorOf('hc');
    final tc = colorOf('tc');
    final hs = sizeOf('hs');
    final ts = sizeOf('ts');
    final hf = fontOf('hf');
    final tf = fontOf('tf');
    final hb = st['hb'] == true;
    final hu = st['hu'] == true;
    final it = st['it'] == true;

    String sel(List<String> subs, {bool notSx = true}) {
      final parts = <String>[];
      for (final s in scopes) {
        for (final sub in subs) {
          parts.add('$s $sub${notSx ? ':not(.sx)' : ''}');
        }
      }
      return parts.join(',');
    }

    final b = StringBuffer();
    final headMain = isHero ? ['.hero-title'] : ['.section-title', 'h2'];
    final headSub = isHero ? <String>[] : ['h3', 'h4'];

    final headRules = <String>[
      if (hf != null) 'font-family:$hf !important',
      if (hc != null) 'color:$hc !important',
      if (hb) 'font-weight:800 !important',
      if (hu)
        'text-decoration:underline !important;text-decoration-thickness:3px !important;'
            'text-underline-offset:8px !important;text-decoration-color:var(--sitora-accent) !important',
    ];
    if (headRules.isNotEmpty) {
      b.writeln('${sel([...headMain, ...headSub])}{${headRules.join(';')}}');
    }
    if (hs.isNotEmpty) {
      final main = isHero ? _heroHeading[hs]! : _mainHeading[hs]!;
      b.writeln('${sel(headMain)}{font-size:$main !important;line-height:1.15 !important}');
      if (headSub.isNotEmpty) b.writeln('${sel(headSub)}{font-size:${_subHeading[hs]!} !important}');
    }

    final textColorTargets = isHero ? ['.hero-tagline'] : _textTags.split(',');
    if (tc != null) {
      final parts = <String>[];
      for (final s in scopes) {
        for (final t in textColorTargets) {
          parts.add('$s $t:not(.sx):not(a):not(a *)');
        }
      }
      b.writeln('${parts.join(',')}{color:$tc !important}');
    }
    if (tf != null) {
      final targets = isHero ? ['.hero-tagline'] : _textTags.split(',');
      b.writeln('${sel(targets)}{font-family:$tf !important}');
    }
    if (ts.isNotEmpty) {
      final size = isHero ? _heroSub[ts]! : _bodySize[ts]!;
      final targets = isHero ? ['.hero-tagline'] : _sizeTags.split(',');
      b.writeln('${sel(targets)}{font-size:$size !important}');
    }
    if (it) {
      final targets = isHero ? ['.hero-tagline'] : _sizeTags.split(',');
      b.writeln('${sel(targets)}{font-style:italic !important}');
    }
    return b.toString();
  }
}
