import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../templates/html/shared_html_blocks.dart'
    show resolveTheme, resolveFontPackage, parseHexColor, autoContrastTextColor;
import 'free_model.dart';

/// '#RGB' / '#RRGGBB' / 'rgba(r,g,b,a)' -> Color. Çözülemezse [fallback].
Color cssColor(String? v, Color fallback) {
  if (v == null) return fallback;
  final s = v.trim();
  final m = RegExp(r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$').firstMatch(s);
  if (m != null) {
    final a = m.group(4) == null ? 1.0 : double.tryParse(m.group(4)!) ?? 1.0;
    return Color.fromRGBO(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!), a);
  }
  final c = parseHexColor(s);
  if (c != null) return Color.fromARGB(255, c[0], c[1], c[2]);
  return fallback;
}

/// Editörün kullandığı tema renkleri/fontları — çıktıyı üreten
/// [resolveTheme] / [resolveFontPackage] ile AYNI kaynaktan beslenir,
/// böylece editör ile yayınlanan site aynı paleti kullanır.
class FreeTheme {
  final Color bg, text, subtext, cardBg, border, chipBg, accent, accentText;
  final String headingFamily; // CSS font-family metni
  final String bodyFamily;

  FreeTheme._({
    required this.bg,
    required this.text,
    required this.subtext,
    required this.cardBg,
    required this.border,
    required this.chipBg,
    required this.accent,
    required this.accentText,
    required this.headingFamily,
    required this.bodyFamily,
  });

  factory FreeTheme.of(FreeSite site) {
    final t = resolveTheme(site.themeId, site.customTheme);
    final f = resolveFontPackage(site.fontPackageId, site.customFontPackage);
    return FreeTheme._(
      bg: cssColor(t['bg'], Colors.white),
      text: cssColor(t['text'], const Color(0xFF111111)),
      subtext: cssColor(t['subtext'], const Color(0xFF555555)),
      cardBg: cssColor(t['cardBg'], const Color(0xFFF5F5F5)),
      border: cssColor(t['border'], const Color(0x22000000)),
      chipBg: cssColor(t['chipBg'], const Color(0xFFF1F1F1)),
      accent: cssColor(t['accent'], const Color(0xFF4F46E5)),
      accentText: cssColor(t['accentText'], Colors.white),
      headingFamily: f['heading'] ?? '',
      bodyFamily: f['body'] ?? '',
    );
  }

  /// Bölüm arka planı seçiliyse o bölümün kapsamındaki tema: metin, kart ve
  /// kenarlık renkleri zemine göre türetilir. Yayındaki `_scoped` ile AYNI kural.
  FreeTheme onBg(int sectionBg) {
    if (sectionBg == 0) return this;
    final hex = '#${(sectionBg & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final light = autoContrastTextColor(hex) == '#111111';
    final t = light ? const Color(0xFF111111) : Colors.white;
    final card = light ? const Color(0xB8FFFFFF) : const Color(0x14FFFFFF);
    return FreeTheme._(
      bg: Color(sectionBg),
      text: t,
      subtext: t.withOpacity(light ? 0.72 : 0.78),
      cardBg: card,
      border: light ? const Color(0x1F000000) : const Color(0x2EFFFFFF),
      chipBg: card,
      accent: accent,
      accentText: accentText,
      headingFamily: headingFamily,
      bodyFamily: bodyFamily,
    );
  }

  /// Kullanıcı bölüm yazı rengini seçtiyse (tc != 0) otomatik metin rengi yerine o.
  FreeTheme withTextColor(int tc) {
    if (tc == 0) return this;
    final c = Color(tc);
    return FreeTheme._(
      bg: bg,
      text: c,
      subtext: c,
      cardBg: cardBg,
      border: border,
      chipBg: chipBg,
      accent: accent,
      accentText: accentText,
      headingFamily: headingFamily,
      bodyFamily: bodyFamily,
    );
  }

  /// Bölüm arka planı seçiliyse okunaklı metin rengi (çıktıdaki kuralla aynı).
  Color textOn(int sectionBg) {
    if (sectionBg == 0) return text;
    final hex = '#${(sectionBg & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return cssColor(autoContrastTextColor(hex), text);
  }

  Color sectionBg(int sectionBg) => sectionBg == 0 ? bg : Color(sectionBg);

  TextStyle heading(TextStyle base) => _font(headingFamily, base);
  TextStyle body(TextStyle base) => _font(bodyFamily, base);

  static TextStyle _font(String cssFamily, TextStyle base) {
    final m = RegExp(r"'([^']+)'").firstMatch(cssFamily);
    if (m == null) return base;
    try {
      return GoogleFonts.getFont(m.group(1)!, textStyle: base);
    } catch (_) {
      return base; // font bulunamadı / indirilemedi -> sistem fontu
    }
  }
}

final Map<String, Uint8List> _imgCache = {};

/// data URI -> bayt. Aynı string için AYNI Uint8List döner; böylece
/// sürükleme sırasında Image.memory her karede yeniden çözmez.
Uint8List? freeImageBytes(String? dataUri) {
  if (dataUri == null || dataUri.isEmpty) return null;
  final cached = _imgCache[dataUri];
  if (cached != null) return cached;
  final i = dataUri.indexOf('base64,');
  if (i < 0) return null;
  try {
    final bytes = base64Decode(dataUri.substring(i + 7));
    if (_imgCache.length > 40) _imgCache.remove(_imgCache.keys.first);
    _imgCache[dataUri] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}
