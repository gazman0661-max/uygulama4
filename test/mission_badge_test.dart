import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/models/game_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tamamlanmis ama alinmamis gorev varsa kirmizi nokta, alinca soner', () {
    final gp = GameProgress.instance;
    // Temiz baslangic.
    gp.missionDeliverProgress = 0;
    gp.missionDeliverClaimed = false;
    gp.missionMergeProgress = 0;
    gp.missionMergeClaimed = false;
    gp.missionCoinsProgress = 0;
    gp.missionCoinsClaimed = false;
    gp.missionWeeklyDeliverProgress = 0;
    gp.missionWeeklyDeliverClaimed = false;
    gp.missionWeeklyMergeProgress = 0;
    gp.missionWeeklyMergeClaimed = false;
    gp.missionWeeklyCoinsProgress = 0;
    gp.missionWeeklyCoinsClaimed = false;
    gp.missionMonthlyDeliverProgress = 0;
    gp.missionMonthlyDeliverClaimed = false;
    gp.missionMonthlyMergeProgress = 0;
    gp.missionMonthlyMergeClaimed = false;
    gp.missionMonthlyCoinsProgress = 0;
    gp.missionMonthlyCoinsClaimed = false;
    expect(gp.hasMissionClaimable, isFalse);

    gp.missionMergeProgress = gp.missionMergeTarget; // gunluk birlesme tamam
    expect(gp.hasMissionClaimable, isTrue);

    gp.missionMergeClaimed = true; // odul alindi
    expect(gp.hasMissionClaimable, isFalse);

    gp.missionMonthlyCoinsProgress = gp.missionMonthlyCoinsTarget; // aylik gorev tamam
    expect(gp.hasMissionClaimable, isTrue);
  });
}
