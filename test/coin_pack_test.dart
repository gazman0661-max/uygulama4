import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_progress.dart';

void main() {
  test('tahmini bolum coin\'i ilerledikce artar, ilk 20 bolumde hizli yukselir', () {
    expect(GameProgress.estChapterCoins(1), lessThan(GameProgress.estChapterCoins(10)));
    expect(GameProgress.estChapterCoins(10), lessThan(GameProgress.estChapterCoins(25)));
    expect(GameProgress.estChapterCoins(0), GameProgress.estChapterCoins(1));
  });

  test('buyer paketler: buyuk paket elmas basina daha fazla coin verir', () {
    final p = GameProgress.coinPacks;
    double rate(CoinPackDef d) => d.days / d.gems;
    for (var i = 1; i < p.length; i++) {
      expect(rate(p[i]), greaterThan(rate(p[i - 1])));
    }
  });
}
