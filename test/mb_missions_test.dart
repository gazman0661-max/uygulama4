import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/localization/story_strings.dart';
import 'package:fastfood_merge/models/mb_missions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MbMissions.debugIgnoreUnlock = true;
    MbMissions.instance.resetForTest();
  });

  test('her donemde 3 gorev, kimlikler benzersiz', () {
    for (final p in MbPeriod.values) {
      expect(MbMissions.defsFor(p).length, 3, reason: p.name);
    }
    final ids = MbMissions.defs.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('her gorev metni TR cevirisinde ve basliklar var', () {
    for (final m in MbMetric.values) {
      expect(kStoryTr.containsKey(MbMissions.labelKey(m)), isTrue, reason: m.name);
    }
    expect(kStoryTr.containsKey('Throw missions'), isTrue);
    expect(kStoryTr.containsKey('Merge missions'), isTrue);
  });

  test('ilerleme birikir, hedefe varinca alinabilir, alinmis gorev tekrar ilerlemez', () {
    final mb = MbMissions.instance;
    expect(mb.hasClaimable, isFalse);
    mb.report(MbMetric.chapters, 1); // gunluk hedef 1
    expect(mb.progressOf('d_chapters'), 1);
    expect(mb.isReady(MbMissions.defs.firstWhere((d) => d.id == 'd_chapters')), isTrue);
    expect(mb.hasClaimable, isTrue);
    expect(mb.claim('d_chapters'), isTrue);
    expect(mb.isClaimed('d_chapters'), isTrue);
    expect(mb.claim('d_chapters'), isFalse); // ikinci kez alinamaz
    expect(mb.hasClaimable, isFalse);
    mb.report(MbMetric.chapters, 1);
    expect(mb.progressOf('d_chapters'), 1); // alinmis gorev ilerlemez
    expect(mb.progressOf('w_chapters'), 2); // haftalik/aylik ayni raporla ilerler
  });

  test('hedefe varmamis gorev alinamaz', () {
    final mb = MbMissions.instance;
    mb.report(MbMetric.orders, 3); // gunluk hedef 8
    expect(mb.claim('d_orders'), isFalse);
    expect(mb.isClaimed('d_orders'), isFalse);
  });

  test('oduller Mod 1 degerlerinin altinda (ekonomi sismesin)', () {
    // Mod 1 sabitleri (game_progress.dart): gunluk 150+120+200, haftalik 800+600+1000, aylik 3000+2200+4000.
    int sum(MbPeriod p) => MbMissions.defsFor(p).fold(0, (a, d) => a + d.coins);
    expect(sum(MbPeriod.daily), lessThanOrEqualTo(470 * 6 ~/ 10));
    expect(sum(MbPeriod.weekly), lessThanOrEqualTo(2400 * 7 ~/ 10));
    expect(sum(MbPeriod.monthly), lessThanOrEqualTo(9200 * 7 ~/ 10));
  });

  test('kayit JSON olarak disa verilebilir', () {
    final mb = MbMissions.instance;
    mb.report(MbMetric.orders, 2);
    final j = mb.toJson();
    expect((j['p'] as Map)['d_orders'], 2);
  });
}
