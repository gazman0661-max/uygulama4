import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_progress.dart';
import 'package:fastfood_merge/models/town.dart';
import 'package:fastfood_merge/services/time_service.dart';

void main() {
  test('kasaba: bina yukseltilirken uretim durur, bitince yeni seviyeyle devam eder', () {
    final gp = GameProgress.instance;
    final nowMs = TimeService.instance.now().millisecondsSinceEpoch;
    const hour = 3600000;

    final savedLevels = List<int>.from(gp.townLevels);
    final savedStored = List<double>.from(gp.townStored);
    final savedLast = List<int>.from(gp.townLastMs);
    final savedEnd = List<int>.from(gp.townUpgradeEndMs);

    for (var i = 0; i < TownCatalog.worldCount; i++) {
      gp.townLevels[i] = 0;
      gp.townStored[i] = 0;
      gp.townLastMs[i] = 0;
      gp.townUpgradeEndMs[i] = 0;
    }
    gp.townLevels[0] = 3;
    gp.townStored[0] = 10;
    gp.townLastMs[0] = nowMs - 2 * hour;

    // Yukseltme YOK: depodaki + 2 saatlik uretim.
    final rate = gp.townCoinsPerHour(0);
    expect(rate, greaterThan(0));
    expect(gp.townPending(0), greaterThan(10));

    // Insaat basladi (1 saat sonra bitecek): uretim durur, sadece depodaki 10 gorunur.
    gp.townStored[0] = 10;
    gp.townUpgradeEndMs[0] = nowMs + hour;
    expect(gp.townIsUpgrading(0), true);
    expect(gp.townPending(0), 10);
    expect(gp.townActiveCoinsPerHour(0), 0);
    expect(gp.townCoinsPerHourTotal, 0);

    // Insaat bitti (yarim saat once): seviye +1, birikim korundu, uretim bitis aninda basladi.
    final end = nowMs - hour ~/ 2;
    gp.townUpgradeEndMs[0] = end;
    expect(gp.tickTownUpgrades(), true);
    expect(gp.townLevels[0], 4);
    expect(gp.townIsUpgrading(0), false);
    expect(gp.townLastMs[0], end);
    expect(gp.townStored[0], 10);
    expect(gp.townPending(0), greaterThanOrEqualTo(10));
    expect(gp.townActiveCoinsPerHour(0), gp.townCoinsPerHour(0));

    for (var i = 0; i < TownCatalog.worldCount; i++) {
      gp.townLevels[i] = savedLevels[i];
      gp.townStored[i] = savedStored[i];
      gp.townLastMs[i] = savedLast[i];
      gp.townUpgradeEndMs[i] = savedEnd[i];
    }
  });
}
