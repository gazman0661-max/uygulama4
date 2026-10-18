import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_theme.dart';

void main() {
  test('dolu masa: 1-2. bolumde bos, sonra azar azar artar, tavan maxPrefill', () {
    expect(ChapterConfig.prefillFraction(1), 0);
    expect(ChapterConfig.prefillFraction(2), 0);
    expect(ChapterConfig.prefillFraction(3), greaterThan(0));
    var prev = 0.0;
    for (var c = 3; c <= 300; c++) {
      if (ChapterConfig.kindFor(c) != ChapterKind.normal) continue;
      final f = ChapterConfig.prefillFraction(c);
      expect(f, greaterThanOrEqualTo(prev));
      expect(f, lessThanOrEqualTo(ChapterConfig.maxPrefill));
      prev = f;
    }
    expect(ChapterConfig.prefillFraction(93), ChapterConfig.maxPrefill); // normal
    expect(ChapterConfig.prefillFraction(100), ChapterConfig.maxPrefill); // boss: tam
    expect(ChapterConfig.prefillFraction(95), ChapterConfig.maxPrefill * 0.5); // rahat: yarisi
  });

  test('dolu masa: tehlike cizgisi gevsemesi 0..1 arasi', () {
    for (var c = 1; c <= 300; c++) {
      final e = ChapterConfig.prefillEase(c);
      expect(e, inInclusiveRange(0.0, 1.0));
    }
  });
}
