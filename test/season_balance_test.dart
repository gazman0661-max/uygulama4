import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/mb_missions.dart';
import 'package:fastfood_merge/models/season.dart';

void main() {
  test('sezon yolu: her kademede odul var, son kademe en buyuk', () {
    for (var t = 1; t <= SeasonService.tierCount; t++) {
      final f = SeasonService.freeReward(t);
      final p = SeasonService.premiumReward(t);
      expect(f.coins + f.gems + f.mbEnergy + (f.energy ? 1 : 0) + (f.booster != null ? 1 : 0), greaterThan(0), reason: 'free $t');
      expect(p.coins + p.gems + p.mbEnergy, greaterThan(0), reason: 'premium $t');
      // premium her kademede bedavadan en az ayni degerde (gem+coin/10+enerji).
      int v(SeasonReward r) => r.gems * 10 + r.coins ~/ 10 + r.mbEnergy;
      expect(v(p), greaterThanOrEqualTo(v(f)), reason: 'premium >= free @$t');
    }
    expect(SeasonService.freeReward(30).gems, greaterThan(SeasonService.freeReward(20).gems));
    expect(SeasonService.premiumReward(30).gems, greaterThan(SeasonService.premiumReward(20).gems));
  });

  test('gorev ve sandik SP si doneme gore artar', () {
    for (final f in [SeasonService.spMbMissionFor, SeasonService.spMbChestFor]) {
      expect(f(MbPeriod.daily), lessThan(f(MbPeriod.weekly)));
      expect(f(MbPeriod.weekly), lessThan(f(MbPeriod.monthly)));
    }
  });

  test('her gun oynayan oyuncu sezonu ayin sonuna dogru bitirir (SP butcesi)', () {
    // Gunluk oyuncu: oyun ~51 SP/gun + gunluk gorev (4x5) + gunluk sandik 10.
    const perDay = 51 + 4 * 5 + 10;
    final daily = [for (final p in [MbPeriod.daily]) perDay].first * 30;
    // Haftalik: 5 gorev x25 + sandik 50, ayda ~4 hafta; aylik: 5 gorev x60 + sandik 120.
    const weekly = (5 * 25 + 50) * 4;
    const monthly = 5 * 60 + 120;
    final total = daily + weekly + monthly;
    final need = SeasonService.cumulativeSp(SeasonService.tierCount);
    expect(total, greaterThanOrEqualTo(need)); // tam oynayan bitirir
    expect(total, lessThan(need * 13 ~/ 10)); // ama sezon 3 gunde de bitmez
  });
}
