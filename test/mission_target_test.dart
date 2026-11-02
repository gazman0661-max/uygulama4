import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_theme.dart';

void main() {
  test('bolum basi ortalamalar ilerledikce artar (erken oyun < gec oyun)', () {
    final early = ChapterConfig.missionPerChapter(4);
    final late = ChapterConfig.missionPerChapter(30);
    expect(late[1], greaterThan(early[1])); // birlesme
    expect(late[2], greaterThan(early[2])); // coin
  });

  test('gunluk gorev ~5 bolumluk is: 1 bolumde bitmez', () {
    for (final ch in [8, 20, 30, 80]) {
      final per = ChapterConfig.missionPerChapter(ch);
      final daily = ChapterConfig.niceTarget(per[1] * ChapterConfig.missionDailyChapters);
      expect(daily, greaterThan(per[1] * 3));
    }
  });

  test('niceTarget yuvarlama', () {
    expect(ChapterConfig.niceTarget(46.2), 45);
    expect(ChapterConfig.niceTarget(712), 710);
    expect(ChapterConfig.niceTarget(5123), 5100);
    expect(ChapterConfig.niceTarget(30210), 30000);
  });
}
