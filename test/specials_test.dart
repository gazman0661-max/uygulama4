import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_theme.dart';

void main() {
  test('ozel objeler: tanitim bolumlerinden once yok, sonra var', () {
    expect(ChapterConfig.bombChance(ChapterConfig.bombStartChapter - 1), 0);
    expect(ChapterConfig.bombChance(ChapterConfig.bombStartChapter), greaterThan(0));
    expect(ChapterConfig.wildChance(ChapterConfig.wildStartChapter - 1), 0);
    expect(ChapterConfig.wildChance(ChapterConfig.wildStartChapter), greaterThan(0));
    expect(ChapterConfig.frozenCount(ChapterConfig.frozenStartChapter - 1), 0);
    expect(ChapterConfig.frozenCount(ChapterConfig.frozenStartChapter), 1);
    expect(ChapterConfig.obstacleCount(ChapterConfig.obstacleStartChapter - 1), 0);
    expect(ChapterConfig.obstacleCount(ChapterConfig.obstacleStartChapter), 1);
  });

  test('ozel objeler: tavanlar asilmaz, tanitim bolumleri boss/rahat degil', () {
    for (var c = 1; c <= 600; c++) {
      expect(ChapterConfig.frozenCount(c), lessThanOrEqualTo(6), reason: 'bolum $c');
      expect(ChapterConfig.obstacleCount(c), lessThanOrEqualTo(5), reason: 'bolum $c');
      expect(ChapterConfig.bombChance(c), lessThanOrEqualTo(0.30 + 1e-9), reason: 'bolum $c');
      expect(ChapterConfig.wildChance(c), lessThanOrEqualTo(0.20 + 1e-9), reason: 'bolum $c');
    }
    for (final c in [
      ChapterConfig.bombStartChapter,
      ChapterConfig.frozenStartChapter,
      ChapterConfig.obstacleStartChapter,
      ChapterConfig.wildStartChapter,
    ]) {
      expect(ChapterConfig.kindFor(c), ChapterKind.normal, reason: 'bolum $c');
    }
  });
}
