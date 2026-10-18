import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_progress.dart';

void main() {
  test('yukseltme egrisi azar azar: oran <= 1.5, 15 seviye toplam ~350k', () {
    for (final list in [GameProgress.throwCooldownCost, GameProgress.luckCost]) {
      expect(list.length, GameProgress.maxUpgradeLevel);
      for (var i = 1; i < list.length; i++) {
        expect(list[i], greaterThan(list[i - 1]));
        expect(list[i] / list[i - 1], lessThanOrEqualTo(1.5));
      }
      final total = list.fold<int>(0, (a, b) => a + b);
      expect(total, inInclusiveRange(300000, 400000));
    }
  });

  test('reklamla %25 indirim: jeton verilir, indirimli fiyat odenir, satin alinca jeton biter', () {
    final gp = GameProgress.instance;
    gp.throwCooldownLevel = 9; // taban maliyet 17000
    final base = GameProgress.throwCooldownCost[9];
    expect(gp.canGetAdDiscount('throw', base), true);
    expect(gp.canGetAdDiscount('throw', 9000), false); // 10k altinda indirim yok
    final left = gp.adQuotaRemaining('discount');
    expect(gp.claimAdDiscount('throw', base), true);
    expect(gp.adQuotaRemaining('discount'), left - 1);
    expect(gp.throwCooldownCostNow(), 12750);
    gp.coins = 20000;
    expect(gp.buyThrowCooldownUpgrade(), true);
    expect(gp.coins, 20000 - 12750);
    expect(gp.hasAdDiscount('throw'), false);
    gp.throwCooldownLevel = 0;
  });

  test('estChapterCoins sim ile hizali: 24. bolum ~870, sonrasi yavas artar', () {
    expect(GameProgress.estChapterCoins(24), inInclusiveRange(800, 950));
    expect(GameProgress.estChapterCoins(101), lessThan(1300));
    expect(GameProgress.estChapterCoins(400), greaterThan(GameProgress.estChapterCoins(100)));
  });

  test('hiz + sans seviyesi basina +%1 coin bonusu', () {
    final gp = GameProgress.instance;
    gp.throwCooldownLevel = 5;
    gp.luckLevel = 5;
    expect(gp.upgradeCoinBonus, closeTo(0.10, 1e-9));
    gp.throwCooldownLevel = 0;
    gp.luckLevel = 0;
  });
}
