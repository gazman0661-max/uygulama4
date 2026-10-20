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
    expect(ChapterConfig.frozenCount(500), lessThanOrEqualTo(4));
    expect(ChapterConfig.obstacleCount(500), lessThanOrEqualTo(3));
    expect(ChapterConfig.bombChance(500), lessThanOrEqualTo(0.08 + 1e-9));
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
