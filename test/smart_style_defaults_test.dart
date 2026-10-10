import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/templates/html/shared_html_blocks.dart';
import 'package:sitora_ai/templates/smart_style_defaults.dart';

void main() {
  const allowedHeroes = {'centered', 'editorial', 'diagonal', 'split'};
  const allowedGalleries = {'grid', 'slideshow', 'crossfade', 'bento'};

  group('smart style presets', () {
    test('hiçbir ön ayar premium seçenek içermez, hepsi geçerli id', () {
      for (final e in kSmartStylePresets.entries) {
        final p = e.value;
        expect(siteThemes.containsKey(p.themeId), isTrue, reason: '${e.key} tema');
        expect(isPremiumTheme(p.themeId), isFalse, reason: '${e.key} premium tema');
        expect(isPremiumLayoutStyle(p.heroLayout), isFalse, reason: '${e.key} premium hero');
        expect(isPremiumFontPackage(p.fontPackageId), isFalse, reason: '${e.key} premium font');
        expect(allowedHeroes.contains(p.heroLayout), isTrue, reason: '${e.key} hero');
        expect(allowedGalleries.contains(p.galleryStyle), isTrue, reason: '${e.key} galeri');
      }
    });

    test('her sektör listesindeki ön ayar id\'leri mevcut', () {
      for (final e in kSmartStyleBySector.entries) {
        expect(e.value, isNotEmpty, reason: e.key);
        for (final id in e.value) {
          expect(kSmartStylePresets.containsKey(id), isTrue, reason: '${e.key} -> $id');
        }
      }
    });

    test('bilinmeyen sektör genel listeye düşer, seed ile deterministik', () {
      final a = smartStyleFor('yok_boyle_sektor', random: Random(1));
      final b = smartStyleFor('yok_boyle_sektor', random: Random(1));
      expect(a.themeId, b.themeId);
      expect(a.heroLayout, b.heroLayout);
    });
  });
}
