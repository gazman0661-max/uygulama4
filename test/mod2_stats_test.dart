import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/models/merge_board.dart';
import 'package:fastfood_merge/services/analytics_service.dart';
import 'package:fastfood_merge/services/merge_board_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MbStats JSON gidis-donus: tum sayaclar korunur', () {
    final s = MbStats(7, 123456)
      ..spawns = 40
      ..merges = 22
      ..moves = 5
      ..swaps = 2
      ..items = 9
      ..orders = 6
      ..fullHits = 1
      ..noEnergyHits = 2
      ..adEnergyCount = 3
      ..gemRefills = 1
      ..energyGained = 10;
    final back = MbStats.fromJson(s.toJson())!;
    expect(back.chapter, 7);
    expect(back.startMs, 123456);
    expect(back.spawns, 40);
    expect(back.merges, 22);
    expect(back.orders, 6);
    expect(back.adEnergyCount, 3);
    expect(back.gemRefills, 1);
    expect(back.energyGained, 10);
    expect(back.brief(), contains('uret=40'));
  });

  test('MbStats.fromJson bozuk girdide null doner', () {
    expect(MbStats.fromJson(null), isNull);
    expect(MbStats.fromJson('x'), isNull);
    expect(MbStats.fromJson(<String, dynamic>{})!.spawns, 0);
  });

  test('servis: uret/birlestir/teslim sayaclari ve bolum istatistigi', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = MergeBoardService.instance;
    await svc.load();
    svc.sessionStart();
    expect(svc.sessionStats.spawns, 0);
    final e0 = svc.state.energy;
    final r = svc.spawn();
    expect(r, MbSpawnResult.ok);
    expect(svc.chapterStats.spawns, 1);
    expect(svc.sessionStats.spawns, 1);
    expect(svc.state.energy, e0 - 1);
    expect(svc.boardHist(), isNot('bos'));
    expect(svc.ordersText(), contains('#'));

    // gecersiz hamle sayac artirmaz
    final merges = svc.chapterStats.merges;
    expect(svc.move(0, 0), MbMove.none);
    expect(svc.chapterStats.merges, merges);
    svc.sessionEnd();
  });

  test('analytics ozeti Mod 2 bolumunu icerir ve sayaclari gosterir', () async {
    SharedPreferences.setMockInitialValues({});
    final a = AnalyticsService.instance;
    a.log('mb_chapter_done', {'chapter': 1, 'spawns': 90});
    a.log('mb_energy_empty', {'chapter': 1});
    final sum = a.summary();
    expect(sum, contains('MOD 2'));
    expect(sum, contains('mb_chapter_done: '));
    expect(a.count('mb_chapter_done'), greaterThanOrEqualTo(1));
    // math import kullanimi (rastgele tohum) - testler deterministik kalsin
    expect(math.Random(1).nextInt(10), isNonNegative);
  });
}
