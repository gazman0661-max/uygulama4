import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/models/live_events.dart';
import 'package:fastfood_merge/models/planet_event.dart';
import 'package:fastfood_merge/models/team_race.dart';
import 'package:fastfood_merge/models/team_race_schedule.dart';
import 'package:fastfood_merge/services/remote_tuning.dart';
import 'package:fastfood_merge/services/save_merge.dart';

// 2026-10-26 Pzt (hafta 147, NORMAL), 2026-11-02 Pzt (hafta 148, TAKIM YARISI), 2026-11-09 Pzt (hafta 149, normal).
final DateTime _normalMon = DateTime(2026, 10, 26, 12, 0);
final DateTime _raceStart = DateTime(2026, 11, 2, 10, 0);
final DateTime _raceMon = DateTime(2026, 11, 2, 12, 0); // KAYIT donemi (ilk 24 saat): takim secilir, yaris henuz baslamadi
final DateTime _raceTue = DateTime(2026, 11, 3, 12, 0); // yaris basladi (Sali 10:00'dan sonra); katilma kapali
final DateTime _raceSat = DateTime(2026, 11, 7, 12, 0);
final DateTime _raceEnd = DateTime(2026, 11, 9, 10, 0);

EventDef get _mod2 => LiveEvents.defaultDefs.firstWhere((d) => d.id == 'race_mod2');
EventDef get _mod1 => LiveEvents.defaultDefs.firstWhere((d) => d.id == 'race_mod1');

/// Kayit doneminde takim secer, sonra saati yaris basladiktan sonraya (Sali 12:00) alir.
bool _joinAndStart(TeamRace tr, int team) {
  TeamRace.clock = () => _raceMon;
  final ok = tr.chooseTeam(team);
  TeamRace.clock = () => _raceTue;
  return ok;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RemoteTuning.setAll({});
    TeamRaceSchedule.enabled = true;
    TeamRace.clock = () => _raceMon;
    TeamRace.unlocked = () => true;
    TeamRace.onSaved = null;
    TeamRace.instance.resetForTest();
  });

  group('Takvim', () {
    test('2 haftada bir: cift hafta = takim yarisi (Pzt 10:00 - ertesi Pzt 10:00)', () {
      expect(TeamRaceSchedule.isRaceWeekAt(_normalMon), isFalse);
      expect(TeamRaceSchedule.isRaceWeekAt(DateTime(2026, 11, 2, 9, 59)), isFalse); // 10:00'dan once hala normal hafta
      expect(TeamRaceSchedule.isRaceWeekAt(_raceStart), isTrue);
      expect(TeamRaceSchedule.isRaceWeekAt(DateTime(2026, 11, 8, 23, 59)), isTrue);
      expect(TeamRaceSchedule.isRaceWeekAt(DateTime(2026, 11, 9, 9, 59)), isTrue);
      expect(TeamRaceSchedule.isRaceWeekAt(_raceEnd), isFalse);
      final w = TeamRaceSchedule.weekIdOf(_raceStart);
      expect(TeamRaceSchedule.endOfWeek(w).difference(TeamRaceSchedule.startOfWeek(w)), const Duration(days: 7));
      expect(TeamRaceSchedule.startOfWeek(w), _raceStart);
    });

    test('Remote: every_weeks=0 kapatir, phase kaydirir', () {
      RemoteTuning.setAll({'team_race_every_weeks': '0'});
      expect(TeamRaceSchedule.isRaceWeekAt(_raceMon), isFalse);
      RemoteTuning.setAll({'team_race_phase': '1'});
      expect(TeamRaceSchedule.isRaceWeekAt(_raceMon), isFalse);
      expect(TeamRaceSchedule.isRaceWeekAt(_normalMon), isTrue);
    });

    test('takim yarisi haftasinda diger etkinlikler YOK, normal haftada var', () {
      expect(_mod2.runIdAt(_normalMon), isNotNull); // Pzt 12:00 normal hafta
      expect(_mod2.runIdAt(_raceMon), isNull);
      expect(_mod1.runIdAt(DateTime(2026, 11, 4, 12)), isNull);
      expect(PlanetEvent.isActiveAt(_raceSat), isFalse); // yaris haftasinin Cumartesisi
      expect(PlanetEvent.isActiveAt(DateTime(2026, 10, 31, 12)), isTrue); // onceki (normal) hafta sonu
      // Normal haftanin hafta sonu etkinligi takim yarisi baslayinca (Pzt 10:00) biter
      expect(PlanetEvent.isActiveAt(DateTime(2026, 11, 2, 9, 59)), isTrue);
      expect(PlanetEvent.isActiveAt(_raceStart), isFalse);
    });

    test('siradaki baslangiclar takim yarisi haftasini atlar', () {
      final run = _mod2.nextRunAfter(DateTime(2026, 10, 30, 11)); // Cuma: sonraki Pzt takim yarisi haftasi
      expect(_mod2.startOfRun(run), DateTime(2026, 11, 9, 10)); // bir sonraki NORMAL hafta
      // Hafta sonu etkinligi: yaris haftasinda sonraki Cumartesi'ye (normal hafta) isaret eder
      expect(PlanetEvent.startOf(_raceMon), DateTime(2026, 11, 14, 10));
      // Yaris bitince (Pzt 10:00) Merge Yarisi ayni anda baslar
      expect(_mod2.runIdAt(_raceEnd), isNotNull);
    });
  });

  group('Takim yarisi', () {
    test('acik: yalniz takim yarisi haftasinda ve etkinlik acilmissa', () {
      expect(TeamRace.instance.isActive, isTrue);
      TeamRace.clock = () => _normalMon;
      expect(TeamRace.instance.isActive, isFalse);
      TeamRace.clock = () => _raceMon;
      TeamRace.unlocked = () => false;
      expect(TeamRace.instance.isActive, isFalse);
    });

    test('takim secmeden oynanamaz; enerji 3 ile baslar; takim secilince oynanir', () {
      final tr = TeamRace.instance;
      expect(tr.energy, 3);
      expect(tr.canPlay, isFalse); // takim yok
      expect(tr.chooseTeam(4), isTrue);
      expect(tr.canPlay, isFalse); // kayit donemi: yaris henuz baslamadi
      TeamRace.clock = () => _raceTue;
      expect(tr.canPlay, isTrue);
      tr.report(5);
      expect(tr.orders, 5);
      expect(tr.chooseTeam(2), isFalse); // siparis sonrasi takim kilitli
      expect(tr.team, 4);
    });

    test('takim secimi KESIN: degistirme / ayrilma yok; gecersiz takim reddedilir', () {
      final tr = TeamRace.instance;
      expect(tr.chooseTeam(-1), isFalse);
      expect(tr.chooseTeam(10), isFalse);
      expect(tr.chooseTeam(1), isTrue);
      expect(tr.chooseTeam(7), isFalse); // siparis vermeden bile degistirilemez
      expect(tr.team, 1);
      expect(tr.chooseTeam(1), isTrue); // ayni takima tekrar katil = sorun yok
    });

    test('takim secilmeden / yaris disinda siparis sayilmaz', () {
      final tr = TeamRace.instance;
      tr.report(3);
      expect(tr.orders, 0);
      tr.chooseTeam(0);
      tr.report(3); // kayit donemi: siparis sayilmaz
      expect(tr.orders, 0);
      TeamRace.clock = () => _normalMon;
      tr.report(3);
      TeamRace.clock = () => _raceTue;
      expect(tr.orders, 0);
    });

    test('enerji: bolum 1 harcar, 45 dk\'da 1 dolar, en fazla 3', () {
      final tr = TeamRace.instance;
      _joinAndStart(tr, 0);
      expect(tr.spendEnergy(), isTrue);
      expect(tr.energy, 2);
      TeamRace.clock = () => _raceTue.add(const Duration(minutes: 44));
      expect(tr.energy, 2);
      TeamRace.clock = () => _raceTue.add(const Duration(minutes: 45));
      expect(tr.energy, 3);
      expect(tr.nextEnergyIn, isNull);
      for (var i = 0; i < 3; i++) {
        expect(tr.spendEnergy(), isTrue);
      }
      expect(tr.spendEnergy(), isFalse); // enerji yok
      expect(tr.canPlay, isFalse);
    });

    test('reklamla dolum: saatte 1 kez', () {
      final tr = TeamRace.instance;
      _joinAndStart(tr, 0);
      expect(tr.canAdRefill, isFalse); // enerji dolu
      tr.spendEnergy();
      tr.spendEnergy();
      expect(tr.energy, 1);
      expect(tr.canAdRefill, isTrue);
      expect(tr.refillAfterAd(), isTrue);
      expect(tr.energy, 3);
      tr.spendEnergy();
      expect(tr.canAdRefill, isFalse); // 1 saat dolmadi
      expect(tr.adCooldownLeft.inMinutes, 59);
      TeamRace.clock = () => _raceTue.add(const Duration(minutes: 30));
      expect(tr.canAdRefill, isFalse);
      TeamRace.clock = () => _raceTue.add(const Duration(minutes: 61));
      expect(tr.canAdRefill, isTrue);
    });

    test('10 takim x 15 kisi; oyuncu takima 15. kisi olarak katilir (14 bot + oyuncu)', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceMon; // kayit donemi: takim burada secilir
      tr.chooseTeam(3);
      TeamRace.clock = () => _raceMon.add(const Duration(days: 3));
      final st = tr.standings();
      expect(st.length, 10);
      expect(st.map((e) => e.team).toSet().length, 10);
      expect([for (var i = 0; i < st.length; i++) st[i].rank], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      for (var i = 1; i < st.length; i++) {
        expect(st[i - 1].score >= st[i].score, isTrue);
      }
      final m = tr.members(3, playerName: 'Sen');
      expect(m.length, 15);
      expect(m.where((e) => e.isPlayer).length, 1);
      expect(m.where((e) => !e.isPlayer).length, 14);
      expect(tr.members(5).length, 15);
      expect(tr.members(5).any((e) => e.isPlayer), isFalse);
      // Tum isimler benzersiz
      final names = <String>{};
      for (var t = 0; t < 10; t++) {
        for (final e in tr.members(t, playerName: 'Sen')) {
          names.add(e.name.toLowerCase());
        }
      }
      expect(names.length, 150);
    });

    test('botlar deterministik, zamanla azalmaz; hafta sonu itibariyla guclu takimlar binlerce siparis', () {
      final tr = TeamRace.instance;
      int total(Duration d) {
        TeamRace.clock = () => _raceStart.add(d);
        return tr.standings().fold<int>(0, (a, e) => a + e.score);
      }
      final a = total(const Duration(days: 1));
      final a2 = total(const Duration(days: 1));
      expect(a2, a); // ayni an = ayni sonuc
      final b = total(const Duration(days: 3));
      final c = total(const Duration(days: 6, hours: 23));
      expect(b >= a, isTrue);
      expect(c >= b, isTrue);
      TeamRace.clock = () => _raceStart.add(const Duration(days: 6, hours: 23));
      final st = tr.standings();
      expect(st.first.score, greaterThan(1500));
      expect(st.first.score, lessThan(9000));
      expect(st.first.score, greaterThan(st.last.score));
    });

    test('esitlikte ve oyuncu katkisiyla takim siralamasi degisir', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart.add(const Duration(days: 3));
      final base = tr.standings();
      final weakest = base.last.team;
      TeamRace.clock = () => _raceMon; // kayit donemi
      tr.chooseTeam(weakest);
      TeamRace.clock = () => _raceStart.add(const Duration(days: 3));
      tr.report(100000); // dev katki: son takim 1. olur
      expect(tr.myRank, 1);
      expect(tr.standings().first.team, weakest);
      expect(tr.standings().first.isMine, isTrue);
    });

    test('yaris bitince ilk 3 takima odul (sart: >= minOrders), tek sefer; bildirim notu', () async {
      final tr = TeamRace.instance;
      final given = <PlanetReward>[];
      TeamRace.deliver = (r, src) => given.add(r);
      TeamRace.clock = () => _raceStart.add(const Duration(days: 6, hours: 23));
      final weakest = tr.standings().last.team;
      TeamRace.clock = () => _raceMon; // kayit donemi
      tr.chooseTeam(weakest);
      TeamRace.clock = () => _raceStart.add(const Duration(days: 6, hours: 23));
      tr.report(100000); // 1. sira garanti
      TeamRace.clock = () => _raceEnd; // yaris bitti
      final note = await tr.takeNote();
      expect(note, isNotNull);
      expect(note!.rank, 1);
      expect(note.qualified, isTrue);
      expect(given.length, 1);
      expect(given.single.coins, TeamRace.rankRewards[0].coins);
      expect(tr.isActive, isFalse);
      expect(tr.team, -1); // durum sifirlandi
      expect(await tr.takeNote(), isNull); // tek sefer
      expect(tr.energy, TeamRace.maxEnergy);
      expect(given.length, 1);
    });

    test('az siparis = odul yok (sira 1 bile olsa); takim secmediyse hic bildirim yok', () async {
      final tr = TeamRace.instance;
      final given = <PlanetReward>[];
      TeamRace.deliver = (r, src) => given.add(r);
      TeamRace.clock = () => _raceStart.add(const Duration(days: 6, hours: 23));
      final top = tr.standings().first.team;
      TeamRace.clock = () => _raceMon; // kayit donemi
      tr.chooseTeam(top);
      TeamRace.clock = () => _raceStart.add(const Duration(days: 6, hours: 23));
      tr.report(3); // minOrders (10) altinda
      TeamRace.clock = () => _raceEnd;
      final note = await tr.takeNote();
      expect(note, isNotNull);
      expect(note!.qualified, isFalse);
      expect(given, isEmpty);

      tr.resetForTest();
      TeamRace.clock = () => _raceStart.add(const Duration(days: 1));
      expect(tr.energy, 3); // yarisi baslat
      TeamRace.clock = () => _raceEnd;
      expect(await tr.takeNote(), isNull);
    });

    test('JSON gidis-donus', () {
      final tr = TeamRace.instance;
      _joinAndStart(tr, 6);
      tr.report(12);
      tr.spendEnergy();
      final j = tr.toJson();
      tr.resetForTest();
      tr.applyJson(j);
      expect(tr.team, 6);
      expect(tr.orders, 12);
      expect(tr.energy, 2);
    });
  });
  group('Katilma suresi (ilk 24 saat)', () {
    test('ilk 24 saatte katilir; sonra katilamaz ama siralamayi gorur', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 2));
      expect(tr.canJoin, isTrue);
      expect(tr.joinClosed, isFalse);
      expect(tr.joinTimeLeft, const Duration(hours: 22));
      expect(tr.hasBadge, isTrue);

      TeamRace.clock = () => _raceStart.add(const Duration(hours: 24, minutes: 1));
      expect(tr.canJoin, isFalse);
      expect(tr.joinClosed, isTrue);
      expect(tr.joinTimeLeft, Duration.zero);
      expect(tr.chooseTeam(3), isFalse);
      expect(tr.hasTeam, isFalse);
      expect(tr.canPlay, isFalse);
      expect(tr.hasBadge, isFalse);
      expect(tr.standings().length, TeamRace.teamCount); // siralamayi yine gorur
      expect(tr.members(0).length, TeamRace.teamSize);
    });

    test('24 saatin tam sinirinda kapanir; Remote ile uzatilir', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 23, minutes: 59));
      expect(tr.canJoin, isTrue);
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 24));
      expect(tr.canJoin, isFalse);
      RemoteTuning.setAll({'team_race_join_hours': '48'});
      expect(tr.canJoin, isTrue);
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 48));
      expect(tr.canJoin, isFalse);
    });

    test('takim secmis oyuncu 24 saat sonra da oynar; siparisi sayilir', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 1));
      expect(tr.chooseTeam(5), isTrue);
      expect(tr.canPlay, isFalse); // kayit donemi: henuz oynayamaz
      expect(tr.hasBadge, isFalse);
      TeamRace.clock = () => _raceStart.add(const Duration(days: 3));
      expect(tr.canJoin, isFalse);
      expect(tr.joinClosed, isFalse); // takimi var
      expect(tr.canPlay, isTrue);
      tr.report(7);
      expect(tr.orders, 7);
      expect(tr.chooseTeam(5), isTrue); // ayni takim sorun degil
      expect(tr.chooseTeam(2), isFalse);
    });

    test('sonraki yarista (2 hafta sonra) yeniden katilabilir', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart.add(const Duration(days: 3));
      expect(tr.chooseTeam(1), isFalse); // gec kaldi
      TeamRace.clock = () => DateTime(2026, 11, 16, 11, 0); // hafta 150 = yeni takim yarisi, ilk saat
      expect(tr.isActive, isTrue);
      expect(tr.canJoin, isTrue);
      expect(tr.chooseTeam(1), isTrue);
    });
  });

  group('Kayit donemi (ilk 24 saat: yaris baslamaz)', () {
    test('Pzt 10:00 - Sali 10:00 kayit; tam 24. saatte yaris herkes icin baslar', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart;
      expect(tr.isActive, isTrue);
      expect(tr.inRegistration, isTrue);
      expect(tr.hasStarted, isFalse);
      expect(tr.startsIn, const Duration(hours: 24));
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 23, minutes: 59));
      expect(tr.hasStarted, isFalse);
      expect(tr.startsIn, const Duration(minutes: 1));
      TeamRace.clock = () => DateTime(2026, 11, 3, 10, 0); // Sali 10:00
      expect(tr.hasStarted, isTrue);
      expect(tr.inRegistration, isFalse);
      expect(tr.startsIn, Duration.zero);
      expect(TeamRace.raceStartOf(TeamRaceSchedule.weekIdOf(_raceStart)), DateTime(2026, 11, 3, 10, 0));
    });

    test('kayit doneminde botlar 0 puanda; yaris baslayinca puan toplar', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 23, minutes: 59));
      expect(tr.standings().every((e) => e.score == 0), isTrue);
      TeamRace.clock = () => DateTime(2026, 11, 3, 10, 0);
      expect(tr.standings().every((e) => e.score == 0), isTrue); // tam baslangic aninda hala 0
      TeamRace.clock = () => DateTime(2026, 11, 3, 22, 0); // baslangictan 12 saat sonra
      expect(tr.standings().fold<int>(0, (a, e) => a + e.score), greaterThan(0));
    });

    test('kayit doneminde oynanamaz ve siparis sayilmaz; baslayinca sayilir', () {
      final tr = TeamRace.instance;
      TeamRace.clock = () => _raceStart.add(const Duration(hours: 5));
      expect(tr.chooseTeam(2), isTrue);
      expect(tr.canPlay, isFalse);
      tr.report(9);
      expect(tr.orders, 0);
      TeamRace.clock = () => DateTime(2026, 11, 3, 10, 1);
      expect(tr.canPlay, isTrue);
      tr.report(9);
      expect(tr.orders, 9);
    });

    test('kayit suresi Remote ile uzar: 48 saatte yaris Carsamba 10:00 baslar', () {
      final tr = TeamRace.instance;
      RemoteTuning.setAll({'team_race_join_hours': '48'});
      TeamRace.clock = () => DateTime(2026, 11, 3, 12, 0);
      expect(tr.hasStarted, isFalse);
      expect(tr.startsIn, const Duration(hours: 22));
      TeamRace.clock = () => DateTime(2026, 11, 4, 10, 0);
      expect(tr.hasStarted, isTrue);
    });

    test('kayit suresi 48 saatle sinirli (Remote 168 yazilsa bile yaris baslar)', () {
      RemoteTuning.setAll({'team_race_join_hours': '168'});
      expect(TeamRace.joinHours, 48);
    });
  });

  group('Bulut kaydi (Play Games birlestirme)', () {
    test('takim yarisi buluta girer', () {
      expect(SaveMerge.keys, contains(SaveMerge.kTeamRace));
      expect(SaveMerge.otherKeys, contains(SaveMerge.kTeamRace));
      expect(SaveMerge.kTeamRace, 'team_race_v1'); // TeamRace'in kendi anahtariyla ayni olmali
    });

    test('ayni yaris: takim secen taraf kazanir (yeniden kurulum takimi sifirlayamaz)', () {
      final l = <String, dynamic>{'r': 148, 't': -1, 'o': 0, 'd': -1, 'e': 3, 'rs': 0, 'ad': 0};
      final c = <String, dynamic>{'r': 148, 't': 4, 'o': 120, 'd': -1, 'e': 1, 'rs': 1000, 'ad': 0};
      final m = SaveMerge.teamRace(null, l, c);
      expect(m['t'], 4);
      expect(m['o'], 120);
      expect(m['e'], 1); // enerji iki cihazda cogalmaz
      expect(m['rs'], 1000);
      final m2 = SaveMerge.teamRace(null, c, l);
      expect(m2['t'], 4);
      expect(m2['o'], 120);
    });

    test('ayni takim: siparis delta ile toplanir', () {
      final b = <String, dynamic>{'r': 148, 't': 2, 'o': 10};
      final l = <String, dynamic>{'r': 148, 't': 2, 'o': 25};
      final c = <String, dynamic>{'r': 148, 't': 2, 'o': 18};
      expect(SaveMerge.teamRace(b, l, c)['o'], 33);
      expect(SaveMerge.teamRace(null, l, c)['o'], 25); // taban yoksa max
    });

    test('iki cihaz farkli takim secti: siparisi cok olan kalir, siparis toplanmaz', () {
      final l = <String, dynamic>{'r': 148, 't': 2, 'o': 40};
      final c = <String, dynamic>{'r': 148, 't': 5, 'o': 10};
      final m = SaveMerge.teamRace(null, l, c);
      expect(m['t'], 2);
      expect(m['o'], 40);
    });

    test('daha yeni yaris kazanir; odul bayragi ve reklam sayaci max', () {
      final l = <String, dynamic>{'r': 148, 't': 3, 'o': 500, 'd': 146, 'ad': 900};
      final c = <String, dynamic>{'r': 150, 't': -1, 'o': 0, 'd': 148, 'ad': 100};
      final m = SaveMerge.teamRace(null, l, c);
      expect(m['r'], 150);
      expect(m['t'], -1);
      expect(m['o'], 0);
      expect(m['d'], 148);
      expect(m['ad'], 900);
    });

    test('rebase: sync sirasinda gelen siparisler kaybolmaz', () {
      final m = <String, dynamic>{'r': 148, 't': 2, 'o': 30, 'd': -1};
      final l1 = <String, dynamic>{'r': 148, 't': 2, 'o': 20, 'd': -1};
      final l2 = <String, dynamic>{'r': 148, 't': 2, 'o': 24, 'd': -1};
      expect(SaveMerge.rebase(SaveMerge.kTeamRace, m, l1, l2)['o'], 34);
    });
  });
}
