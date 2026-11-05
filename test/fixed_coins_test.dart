import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_theme.dart';
import 'package:fastfood_merge/models/game_progress.dart';

void main() {
  test('taban coin: kademeli sabit (1-5: 100-300, 6-24: 400-900, 25+: 1000+)', () {
    expect(ChapterConfig.baseChapterCoins(1), 100);
    expect(ChapterConfig.baseChapterCoins(5), 300);
    expect(ChapterConfig.baseChapterCoins(6), 400);
    expect(ChapterConfig.baseChapterCoins(24), 900);
    expect(ChapterConfig.baseChapterCoins(25), 1000);
    expect(ChapterConfig.baseChapterCoins(0), ChapterConfig.baseChapterCoins(1));
    for (var c = 2; c < 500; c++) {
      expect(ChapterConfig.baseChapterCoins(c), greaterThanOrEqualTo(ChapterConfig.baseChapterCoins(c - 1)));
    }
  });

  test('gec oyun tavani: 1400\'u asmaz', () {
    expect(ChapterConfig.baseChapterCoins(775), 1400);
    expect(ChapterConfig.baseChapterCoins(5000), 1400);
  });

  test('boss x1.5, rahat x0.7, tekrar x0.25', () {
    // 10. bolum boss, 15. bolum rahat, 11. bolum normal
    final base10 = ChapterConfig.baseChapterCoins(10);
    expect(ChapterConfig.chapterCoinsFor(10), (base10 * 1.5).round());
    final base15 = ChapterConfig.baseChapterCoins(15);
    expect(ChapterConfig.chapterCoinsFor(15), (base15 * 0.7).round());
    final base11 = ChapterConfig.baseChapterCoins(11);
    expect(ChapterConfig.chapterCoinsFor(11), base11);
    expect(ChapterConfig.chapterCoinsFor(11, replay: true), (base11 * 0.25).round());
  });

  test('siparis odemeleri toplami tam bolum coin\'ine esit', () {
    for (final ch in [1, 2, 5, 10, 11, 24, 40, 101, 400]) {
      for (final replay in [false, true]) {
        final goal = ChapterConfig.goalFor(ch);
        var sum = 0;
        for (var i = 0; i < goal; i++) {
          final p = ChapterConfig.orderPayoutFor(ch, i, replay: replay);
          expect(p, greaterThanOrEqualTo(0));
          sum += p;
        }
        expect(sum, ChapterConfig.chapterCoinsFor(ch, replay: replay), reason: 'bolum $ch replay=$replay');
      }
    }
  });

  test('coin paketi ve bolge odulu tabani ayni egriyi kullanir', () {
    expect(GameProgress.estChapterCoins(24), ChapterConfig.baseChapterCoins(24));
    expect(GameProgress.estChapterCoins(0), GameProgress.estChapterCoins(1));
  });
}
