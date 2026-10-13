import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/free/free_model.dart';
import 'package:sitora_ai/free/free_templates.dart';

void main() {
  group('buildFreeSectionPreset', () {
    test('her hazır yerleşim serbest alan (canvas) bölümüdür ve öğeleri vardır', () {
      for (final p in kFreeSectionPresets) {
        for (final lang in ['tr', 'en']) {
          final s = buildFreeSectionPreset(p.id, lang: lang);
          expect(s.isCanvas, isTrue, reason: p.id);
          expect(s.els, isNotEmpty, reason: p.id);
          for (final e in s.els) {
            expect(e.c >= 0 && e.c + e.w <= kCols, isTrue, reason: '${p.id}/${e.type} taşıyor');
          }
        }
      }
    });

    test('öğe id leri benzersiz; iki çağrı aynı id yi üretmez', () {
      final a = buildFreeSectionPreset('boxes3');
      final b = buildFreeSectionPreset('boxes3');
      final ids = {...a.els.map((e) => e.id), ...b.els.map((e) => e.id)};
      expect(ids.length, a.els.length + b.els.length);
    });

    test('bilinmeyen id hero a düşer', () {
      expect(buildFreeSectionPreset('yok').els.length, buildFreeSectionPreset('hero').els.length);
    });
  });
}
