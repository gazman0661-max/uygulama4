import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_progress.dart';
import 'package:fastfood_merge/models/town.dart';

void main() {
  test('kasaba: onceki bina 5. seviyeye gelmeden sonraki bina kilitli', () {
    final gp = GameProgress.instance;
    final need = TownCatalog.unlockPrevLevel;
    expect(gp.townPrevOk(0), true); // ilk bina hep acik
    final saved = List<int>.from(gp.townLevels);
    for (var i = 0; i < gp.townLevels.length; i++) {
      gp.townLevels[i] = 0;
    }
    gp.townLevels[0] = need - 1;
    expect(gp.townPrevOk(1), false);
    gp.townLevels[0] = need;
    expect(gp.townPrevOk(1), true);
    expect(gp.townPrevOk(2), false); // zincir: 2. bina 1. binaya bagli
    gp.townLevels[2] = 1; // zaten kurulmus bina (eski oyuncu) kilitlenmez
    expect(gp.townPrevOk(2), true);
    for (var i = 0; i < saved.length; i++) {
      gp.townLevels[i] = saved[i];
    }
  });
}
