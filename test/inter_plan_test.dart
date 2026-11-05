import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/services/inter_plan.dart';
import 'package:fastfood_merge/services/remote_tuning.dart';

void main() {
  setUp(() => RemoteTuning.setAll({}));

  test('varyant: cift = A, tek = B', () {
    expect(InterstitialPlan.variantFor(10), 'A');
    expect(InterstitialPlan.variantFor(11), 'B');
  });

  test('Remote Config yoksa A=3, B=2 bolumde bir', () {
    expect(InterstitialPlan.every('inter_every_chapters', 'A'), 3);
    expect(InterstitialPlan.every('inter_every_chapters', 'B'), 2);
    expect(InterstitialPlan.every('mb_inter_every_chapters', 'B'), 2);
  });

  test('Remote Config yayinlanirsa deney kapanir, herkese o deger uygulanir', () {
    RemoteTuning.setAll({'inter_every_chapters': '4'});
    expect(RemoteTuning.has('inter_every_chapters'), true);
    expect(InterstitialPlan.every('inter_every_chapters', 'A'), 4);
    expect(InterstitialPlan.every('inter_every_chapters', 'B'), 4);
    // baska anahtar etkilenmez
    expect(InterstitialPlan.every('mb_inter_every_chapters', 'B'), 2);
  });

  test('uc deger sinirlanir (1..20)', () {
    RemoteTuning.setAll({'inter_every_chapters': '0'});
    expect(InterstitialPlan.every('inter_every_chapters', 'A'), 1);
    RemoteTuning.setAll({'inter_every_chapters': '999'});
    expect(InterstitialPlan.every('inter_every_chapters', 'A'), 20);
  });

  test('due: grace bitmeden reklam yok, sonra sayac every olunca', () {
    expect(InterstitialPlan.due(lifetime: 3, grace: 3, since: 99, every: 2), false);
    expect(InterstitialPlan.due(lifetime: 4, grace: 3, since: 1, every: 2), false);
    expect(InterstitialPlan.due(lifetime: 4, grace: 3, since: 2, every: 2), true);
  });
}
