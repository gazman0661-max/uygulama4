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

  test('gorev sayilari: gunluk 4, haftalik 5, aylik 5; kimlikler benzersiz', () {
    expect(MbMissions.defsFor(MbPeriod.daily).length, 4);
    expect(MbMissions.defsFor(MbPeriod.weekly).length, 5);
    expect(MbMissions.defsFor(MbPeriod.monthly).length, 5);
    for (final p in MbPeriod.values) {
      for (final d in MbMissions.defsFor(p)) {
        expect(d.id.startsWith('${p.name[0]}_'), isTrue, reason: d.id); // bulut birlestirmesi on eke bakar
      }
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
    for (final k in const ['Daily Chest', 'Weekly Chest', 'Monthly Grand Prize', 'Claim all missions to open it', 'Resets in {0}']) {
      expect(kStoryTr.containsKey(k), isTrue, reason: k);
    }
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
    mb.report(MbMetric.specialChapters, 1);
    expect(mb.progressOf('w_special'), 1); // haftalik ve aylik ayni raporla ilerler
    expect(mb.progressOf('m_special'), 1);
  });

  test('hedefe varmamis gorev alinamaz', () {
    final mb = MbMissions.instance;
    mb.report(MbMetric.energy, 3); // gunluk hedef 50
    expect(mb.claim('d_energy'), isFalse);
    expect(mb.isClaimed('d_energy'), isFalse);
  });

  test('gorev coinleri Mod 1 toplamlarini asmaz (ekonomi sismesin); elmas/enerji ayri', () {
    // Mod 1 sabitleri (game_progress.dart): gunluk 150+120+200, haftalik 800+600+1000, aylik 3000+2200+4000.
    int sum(MbPeriod p) => MbMissions.defsFor(p).fold(0, (a, d) => a + d.coins);
    expect(sum(MbPeriod.daily), lessThanOrEqualTo(470));
    expect(sum(MbPeriod.weekly), lessThanOrEqualTo(2400));
    expect(sum(MbPeriod.monthly), lessThanOrEqualTo(9200));
  });

  test('haftalik gorevler TEK GUNDE bitmez: farkli gun + yuksek enerji hedefi var', () {
    final mb = MbMissions.instance;
    // Bir gunde cok oynayan: her sayaca bol bol ilerleme.
    for (final m in MbMetric.values) {
      mb.report(m, 100000);
    }
    mb.refresh();
    final w = MbMissions.defsFor(MbPeriod.weekly);
    final days = w.firstWhere((d) => d.metric == MbMetric.activeDays);
    expect(days.target, greaterThanOrEqualTo(5));
    expect(mb.progressOf(days.id), 1); // ayni gun tekrar sayilmaz
    expect(mb.isReady(days), isFalse);
    expect(w.every(mb.isReady), isFalse);
    // Aylik "farkli gun" da ayni sekilde.
    final mdays = MbMissions.defsFor(MbPeriod.monthly).firstWhere((d) => d.metric == MbMetric.activeDays);
    expect(mb.progressOf(mdays.id), 1);
    expect(mdays.target, greaterThanOrEqualTo(20));
  });

  test('sandik: tum gorevler alinmadan acilmaz; bir kez acilir', () {
    final mb = MbMissions.instance;
    expect(mb.isChestReady(MbPeriod.daily), isFalse);
    expect(mb.claimChest(MbPeriod.daily), isFalse);
    for (final d in MbMissions.defsFor(MbPeriod.daily)) {
      mb.report(d.metric, d.target);
    }
    final ds = MbMissions.defsFor(MbPeriod.daily);
    for (var i = 0; i < ds.length - 1; i++) {
      expect(mb.claim(ds[i].id), isTrue);
      expect(mb.isChestReady(MbPeriod.daily), isFalse, reason: 'son gorev alinmadi');
    }
    expect(mb.claim(ds.last.id), isTrue);
    expect(mb.claimedCount(MbPeriod.daily), ds.length);
    expect(mb.isChestReady(MbPeriod.daily), isTrue);
    expect(mb.hasClaimable, isTrue); // sandik kirmizi nokta yakar
    expect(mb.claimChest(MbPeriod.daily), isTrue);
    expect(mb.isChestClaimed(MbPeriod.daily), isTrue);
    expect(mb.claimChest(MbPeriod.daily), isFalse);
  });

  test('listeler birbirinin kopyasi degil: haftalik/aylikta bolum sayma gorevi yok, ortak metrik az', () {
    for (final p in [MbPeriod.weekly, MbPeriod.monthly]) {
      expect(MbMissions.defsFor(p).any((d) => d.metric == MbMetric.chapters), isFalse, reason: p.name);
    }
    final w = MbMissions.defsFor(MbPeriod.weekly).map((d) => d.metric).toSet();
    final m = MbMissions.defsFor(MbPeriod.monthly).map((d) => d.metric).toSet();
    final d = MbMissions.defsFor(MbPeriod.daily).map((d) => d.metric).toSet();
    expect(w.intersection(d), isEmpty); // haftalik ile gunluk ayni sey degil
    expect(m.intersection(d), isEmpty);
    expect(w.intersection(m).length, lessThanOrEqualTo(3)); // maxItems, activeDays, specialChapters
  });

  test('her donemin sandigi var, aylik en buyugu', () {
    for (final p in MbPeriod.values) {
      final c = MbMissions.chestOf(p);
      expect(c.gems + c.coins + c.energy, greaterThan(0));
    }
    expect(MbMissions.chestOf(MbPeriod.monthly).gems, greaterThan(MbMissions.chestOf(MbPeriod.weekly).gems));
    expect(MbMissions.chestOf(MbPeriod.weekly).gems, greaterThan(MbMissions.chestOf(MbPeriod.daily).gems));
  });

  test('kayit JSON olarak disa verilebilir', () {
    final mb = MbMissions.instance;
    mb.report(MbMetric.orders, 2);
    final j = mb.toJson();
    expect((j['p'] as Map)['m_orders'], 2);
  });
}
