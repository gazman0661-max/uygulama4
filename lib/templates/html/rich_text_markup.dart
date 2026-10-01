library rich_text_markup;

import 'google_font_catalog.dart';

const String kRichOpen = '\u27E6';
const String kRichClose = '\u27E7';
const String kRichEndToken = '\u27E6/\u27E7';

const List<double> kRichSizeSteps = [0.8, 1.3, 1.7, 2.4];

const List<String> kFreePaletteColors = [
  '#111827',
  '#ffffff',
  '#dc2626',
  '#ea580c',
  '#ca8a04',
  '#16a34a',
  '#0891b2',
  '#2563eb',
  '#7c3aed',
  '#db2777',
];

const List<String> kPremiumPaletteColors = [
  '#7f1d1d', '#9a3412', '#854d0e', '#166534', '#155e75', '#1e3a8a',
  '#5b21b6', '#9d174d', '#f87171', '#fb923c', '#facc15', '#4ade80',
  '#22d3ee', '#60a5fa', '#a78bfa', '#f472b6', '#6b7280', '#000000',
];

final RegExp _hexRe = RegExp(r'^#[0-9a-fA-F]{6}$');

String? normalizeHexColor(String? v) {
  if (v == null) return null;
  final s = v.trim();
  if (!_hexRe.hasMatch(s)) return null;
  return s.toLowerCase();
}

bool isFreePaletteColor(String? hex) {
  final n = normalizeHexColor(hex);
  return n != null && kFreePaletteColors.contains(n);
}

String readableTextOn(String hex) {
  final n = normalizeHexColor(hex) ?? '#ffffff';
  final r = int.parse(n.substring(1, 3), radix: 16);
  final g = int.parse(n.substring(3, 5), radix: 16);
  final b = int.parse(n.substring(5, 7), radix: 16);
  final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return lum > 0.6 ? '#111827' : '#ffffff';
}

class RichStyle {
  const RichStyle({
    this.color,
    this.size,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.highlight,
    this.font,
  });

  final String? font;
  final String? color;
  final double? size;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? highlight;

  static const RichStyle none = RichStyle();

  bool get isEmpty =>
      color == null &&
      size == null &&
      !bold &&
      !italic &&
      !underline &&
      !strike &&
      highlight == null &&
      font == null;

  bool get usesPremium =>
      color != null || size != null || strike || highlight != null || font != null;

  RichStyle withoutPremium() => RichStyle(
        bold: bold,
        italic: italic,
        underline: underline,
      );

  RichStyle patched(Map<String, Object?> patch) {
    return RichStyle(
      color: patch.containsKey('color') ? normalizeHexColor(patch['color'] as String?) : color,
      size: patch.containsKey('size') ? _sanitizeSize(patch['size'] as num?) : size,
      bold: patch.containsKey('bold') ? (patch['bold'] == true) : bold,
      italic: patch.containsKey('italic') ? (patch['italic'] == true) : italic,
      underline: patch.containsKey('underline') ? (patch['underline'] == true) : underline,
      strike: patch.containsKey('strike') ? (patch['strike'] == true) : strike,
      highlight: patch.containsKey('highlight')
          ? normalizeHexColor(patch['highlight'] as String?)
          : highlight,
      font: patch.containsKey('font') ? _sanitizeFont(patch['font']) : font,
    );
  }

  static String? _sanitizeFont(Object? v) {
    if (v == null) return null;
    final slug = v.toString().toLowerCase();
    return fontNameFromSlug(slug) == null ? null : slug;
  }

  static double? _sanitizeSize(num? v) {
    if (v == null) return null;
    final d = v.toDouble();
    if (d.isNaN || d < 0.5 || d > 4.0) return null;
    return (d * 10).round() / 10;
  }

  String toPayload() {
    final parts = <String>[];
    if (color != null) parts.add('c=$color');
    if (size != null) parts.add('z=${_fmt(size!)}');
    if (bold) parts.add('b');
    if (italic) parts.add('i');
    if (underline) parts.add('u');
    if (strike) parts.add('s');
    if (highlight != null) parts.add('h=$highlight');
    if (font != null) parts.add('f=$font');
    return parts.join(',');
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static RichStyle fromPayload(String payload) {
    String? c;
    double? z;
    String? h;
    String? f;
    var b = false, i = false, u = false, s = false;
    for (final raw in payload.toLowerCase().split(',')) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      if (part == 'b') {
        b = true;
      } else if (part == 'i') {
        i = true;
      } else if (part == 'u') {
        u = true;
      } else if (part == 's') {
        s = true;
      } else if (part.startsWith('c=')) {
        c = normalizeHexColor(part.substring(2));
      } else if (part.startsWith('h=')) {
        h = normalizeHexColor(part.substring(2));
      } else if (part.startsWith('f=')) {
        f = _sanitizeFont(part.substring(2));
      } else if (part.startsWith('z=')) {
        z = _sanitizeSize(double.tryParse(part.substring(2)));
      }
    }
    return RichStyle(
      color: c,
      size: z,
      bold: b,
      italic: i,
      underline: u,
      strike: s,
      highlight: h,
      font: f,
    );
  }

  String toCss({bool allowPremium = true, Set<String>? allowedFonts}) {
    final st = allowPremium ? this : withoutPremium();
    final css = <String>[];
    final fontName = fontNameFromSlug(st.font);
    if (fontName != null && (allowedFonts == null || allowedFonts.contains(fontName))) {
      css.add('font-family:${fontFamilyCss(fontName)}');
    }
    if (st.color != null) css.add('color:${st.color}');
    if (st.size != null) css.add('font-size:${_fmt(st.size!)}em');
    if (st.bold) css.add('font-weight:700');
    if (st.italic) css.add('font-style:italic');
    final deco = <String>[
      if (st.underline) 'underline',
      if (st.strike) 'line-through',
    ];
    if (deco.isNotEmpty) {
      css.add('text-decoration:${deco.join(' ')}');
      if (st.underline) css.add('text-underline-offset:0.18em');
    }
    if (st.highlight != null) {
      css.add('background:${st.highlight}');
      css.add('padding:0 0.18em');
      css.add('border-radius:0.2em');
      if (st.color == null) css.add('color:${readableTextOn(st.highlight!)}');
    }
    return css.join(';');
  }

  @override
  bool operator ==(Object other) =>
      other is RichStyle &&
      other.color == color &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.highlight == highlight &&
      other.font == font;

  @override
  int get hashCode => Object.hash(color, size, bold, italic, underline, strike, highlight, font);
}

class RichRun {
  const RichRun(this.text, this.style);
  final String text;
  final RichStyle style;
}

final RegExp _tokenRe = RegExp('\u27E6/\u27E7|\u27E6([a-z0-9#=,.]*)\u27E7', caseSensitive: false);

RegExp get kRichTokenRegExp => _tokenRe;

final RegExp _danglingRe = RegExp('\u27E6/\u27E7|\u27E6[a-z0-9#=,.]*\u27E7?|\u27E7', caseSensitive: false);

String stripRichMarkup(String s) {
  if (!s.contains(kRichOpen) && !s.contains(kRichClose)) return s;
  return s.replaceAll(_danglingRe, '');
}

bool hasRichMarkup(String s) => s.contains(kRichOpen);

List<RichRun> parseRichRuns(String raw) {
  final runs = <RichRun>[];
  var cur = RichStyle.none;
  var pos = 0;
  void addText(String t) {
    final clean = t.replaceAll(kRichOpen, '').replaceAll(kRichClose, '');
    if (clean.isEmpty) return;
    runs.add(RichRun(clean, cur));
  }

  for (final m in _tokenRe.allMatches(raw)) {
    if (m.start > pos) addText(raw.substring(pos, m.start));
    final payload = m.group(1);
    cur = payload == null ? RichStyle.none : RichStyle.fromPayload(payload);
    pos = m.end;
  }
  if (pos < raw.length) addText(raw.substring(pos));
  return runs;
}

String serializeRichRuns(List<RichRun> runs) {
  final pieces = <RichRun>[];
  for (final r in runs) {
    if (r.text.isEmpty) continue;
    final parts = r.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) pieces.add(RichRun(parts[i], r.style));
      if (i < parts.length - 1) pieces.add(RichRun('\n', RichStyle.none));
    }
  }
  final merged = <RichRun>[];
  for (final p in pieces) {
    if (merged.isNotEmpty && merged.last.style == p.style && p.text != '\n' && merged.last.text != '\n') {
      merged[merged.length - 1] = RichRun(merged.last.text + p.text, p.style);
    } else {
      merged.add(p);
    }
  }
  final buf = StringBuffer();
  for (final r in merged) {
    if (r.style.isEmpty || r.text == '\n') {
      buf.write(r.text);
    } else {
      buf.write('$kRichOpen${r.style.toPayload()}$kRichClose${r.text}$kRichEndToken');
    }
  }
  return buf.toString();
}

String richPlainText(String raw) => parseRichRuns(raw).map((r) => r.text).join();

int richRawToPlain(String raw, int rawOffset) {
  final limit = rawOffset.clamp(0, raw.length);
  var plain = 0;
  var pos = 0;
  for (final m in _tokenRe.allMatches(raw)) {
    if (m.start >= limit) break;
    plain += m.start - pos;
    pos = m.end;
    if (pos > limit) {
      return plain;
    }
  }
  if (limit > pos) plain += limit - pos;
  return plain;
}

int richPlainToRaw(String raw, int plainOffset, {required bool afterTokens}) {
  var plain = 0;
  var pos = 0;
  for (final m in _tokenRe.allMatches(raw)) {
    final segLen = m.start - pos;
    if (plainOffset < plain + segLen || (!afterTokens && plainOffset == plain + segLen)) {
      return pos + (plainOffset - plain);
    }
    plain += segLen;
    pos = m.end;
  }
  final rest = raw.length - pos;
  return pos + (plainOffset - plain).clamp(0, rest);
}

String applyRichPatch(String raw, int rawStart, int rawEnd, Map<String, Object?> patch) {
  final ps = richRawToPlain(raw, rawStart < rawEnd ? rawStart : rawEnd);
  final pe = richRawToPlain(raw, rawStart < rawEnd ? rawEnd : rawStart);
  if (pe <= ps) return raw;
  final runs = parseRichRuns(raw);
  final out = <RichRun>[];
  var cursor = 0;
  for (final r in runs) {
    final rs = cursor;
    final re = cursor + r.text.length;
    cursor = re;
    if (re <= ps || rs >= pe) {
      out.add(r);
      continue;
    }
    final a = ps > rs ? ps : rs;
    final b = pe < re ? pe : re;
    if (a > rs) out.add(RichRun(r.text.substring(0, a - rs), r.style));
    out.add(RichRun(r.text.substring(a - rs, b - rs), r.style.patched(patch)));
    if (b < re) out.add(RichRun(r.text.substring(b - rs), r.style));
  }
  return serializeRichRuns(out);
}

({int start, int end}) richRawRangeForPlain(String raw, int plainStart, int plainEnd) {
  return (
    start: richPlainToRaw(raw, plainStart, afterTokens: true),
    end: richPlainToRaw(raw, plainEnd, afterTokens: false),
  );
}

RichStyle richStyleAt(String raw, int rawOffset) {
  final p = richRawToPlain(raw, rawOffset);
  var cursor = 0;
  for (final r in parseRichRuns(raw)) {
    final end = cursor + r.text.length;
    if (p >= cursor && p < end) return r.style;
    cursor = end;
  }
  return RichStyle.none;
}

bool richMarkupUsesPremium(String raw) {
  if (!hasRichMarkup(raw)) return false;
  for (final r in parseRichRuns(raw)) {
    if (r.style.usesPremium) return true;
  }
  return false;
}

final RegExp _htmlChunkRe = RegExp(
  r'<!--.*?-->|<script\b[^>]*>.*?</script>|<style\b[^>]*>.*?</style>|<title\b[^>]*>.*?</title>|<textarea\b[^>]*>.*?</textarea>|<[^>]*>',
  caseSensitive: false,
  dotAll: true,
);

String richMarkupToHtml(String html, {bool isPremium = true, Set<String>? allowedFonts}) {
  if (!html.contains(kRichOpen) && !html.contains(kRichClose)) return html;
  final buf = StringBuffer();
  var pos = 0;
  for (final m in _htmlChunkRe.allMatches(html)) {
    if (m.start > pos) buf.write(_convertTextNode(html.substring(pos, m.start), isPremium, allowedFonts));
    buf.write(stripRichMarkup(m.group(0)!));
    pos = m.end;
  }
  if (pos < html.length) buf.write(_convertTextNode(html.substring(pos), isPremium, allowedFonts));
  return buf.toString();
}

String _convertTextNode(String text, bool isPremium, Set<String>? allowedFonts) {
  if (!text.contains(kRichOpen) && !text.contains(kRichClose)) return text;
  final runs = parseRichRuns(text);
  final buf = StringBuffer();
  for (final r in runs) {
    final css = r.style.toCss(allowPremium: isPremium, allowedFonts: allowedFonts);
    if (css.isEmpty) {
      buf.write(r.text);
    } else {
      buf.write('<span class="sx" style="$css">${r.text}</span>');
    }
  }
  return buf.toString();
}

List<String> richMarkupFontNames(String raw) {
  final out = <String>[];
  if (!hasRichMarkup(raw)) return out;
  for (final m in _tokenRe.allMatches(raw)) {
    final payload = m.group(1);
    if (payload == null) continue;
    final name = fontNameFromSlug(RichStyle.fromPayload(payload).font);
    if (name != null && !out.contains(name)) out.add(name);
  }
  return out;
}
