import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/models/planet_event.dart';
import 'package:fastfood_merge/services/planet_physics.dart';
import 'package:fastfood_merge/services/save_merge.dart';

// 2026-10-31 = Cumartesi, 2026-11-01 = Pazar, 2026-11-02 = Pazartesi, 2026-10-28 = Carsamba.
final DateTime _sat = DateTime(2026, 10, 31, 10, 0);
final DateTime _wed = DateTime(2026, 10, 28, 12, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlanetConfig', () {
    test('puan ve kombo bonusu', () {
      expect(PlanetConfig.pointsForTier(1), 3);
      expect(PlanetConfig.pointsForTier(9), 55);
      expect(PlanetConfig.comboBonus(10, 1), 0);
      expect(PlanetConfig.comboBonus(10, 2), 3); // +25% (yuvarlanmis)
      expect(PlanetConfig.comboBonus(10, 99), 10); // en fazla +%100
    });

    test('baslangic kademesi 0..4 arasi', () {
      final rng = math.Random(7);
      for (var i = 0; i < 500; i++) {
        final t = PlanetConfig.randomDropTier(rng);
        expect(t >= 0 && t <= 4, isTrue);
      }
    });
  });

  group('PlanetWorld', () {
    test('ayni kademeler birlesir, skor ve sayac artar', () {
      final w = PlanetWorld();
      w.drop(0, 50);
      w.drop(0, 52);
      w.step(0.016);
      final ev = w.takeEvents();
      expect(ev.length, 1);
      expect(ev.first.tier, 1);
      expect(w.merges, 1);
      expect(w.score, PlanetConfig.pointsForTier(1));
      expect(w.bestTier, 1);
      expect(w.bodies.length, 1);
    });

    test('farkli kademeler birlesmez', () {
      final w = PlanetWorld();
      w.drop(0, 50);
      w.drop(1, 52);
      w.step(0.016);
      expect(w.takeEvents(), isEmpty);
      expect(w.bodies.length, 2);
    });

    test('Sil: bodyAt gezegeni bulur, removeBody kaldirir', () {
      final w = PlanetWorld();
      final b = w.drop(3, 50);
      w.step(0.016);
      expect(w.bodyAt(b.x, b.y), same(b));
      expect(w.bodyAt(5, 140), isNull); // bos yer
      expect(w.removeBody(b), isTrue);
      expect(w.bodies, isEmpty);
      expect(w.removeBody(b), isFalse); // ikinci kez kaldirilamaz
    });

    test('Salla: hiz verir, tehlike sayacini ve yasi sifirlar', () {
      final w = PlanetWorld();
      final b = w.drop(2, 50);
      w.step(0.016);
      w.dangerTimer = 1.0;
      w.shake(math.Random(1));
      expect(w.dangerTimer, 0);
      expect(b.age, 0);
      w.step(0.016);
      expect(b.vy < 0 || b.vx != 0, isTrue); // itildi
    });

    test('zincirleme birlesmede kombo sayaci artar', () {
      final w = PlanetWorld();
      // 4 adet kademe-0: iki cift ayni karede birlesir -> kombo 1 sonra 2.
      w.drop(0, 40);
      w.drop(0, 42);
      w.drop(0, 60);
      w.drop(0, 62);
      w.step(0.016);
      final ev = w.takeEvents();
      expect(ev.length, 2);
      expect(w.maxCombo, 2);
    });
  });

  group('PlanetEvent', () {
    late List<PlanetReward> given;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      given = [];
      PlanetEvent.clock = () => _sat;
      PlanetEvent.deliver = (r, src) => given.add(r);
      PlanetEvent.onSaved = null;
      PlanetEvent.instance.resetForTest();
    });

    test('pencere: Cmt-Paz acik, hafta ici kapali', () {
      expect(PlanetEvent.isActiveAt(_sat), isTrue);
      expect(PlanetEvent.isActiveAt(DateTime(2026, 11, 1, 23, 59)), isTrue);
      expect(PlanetEvent.isActiveAt(DateTime(2026, 11, 2, 0, 0)), isFalse);
      expect(PlanetEvent.isActiveAt(_wed), isFalse);
      expect(PlanetEvent.endOf(_sat), DateTime(2026, 11, 2));
      expect(PlanetEvent.startOf(_wed), DateTime(2026, 10, 31));
    });

    test('enerji: 3 ile baslar, oyun 1 harcar, 45 dk\'da 1 dolar', () {
      final pe = PlanetEvent.instance;
      expect(pe.energy, 3);
      expect(pe.startRun(), isTrue);
      expect(pe.energy, 2);
      expect(pe.nextEnergyIn, isNotNull);
      PlanetEvent.clock = () => _sat.add(const Duration(minutes: 44));
      expect(pe.energy, 2);
      PlanetEvent.clock = () => _sat.add(const Duration(minutes: 45));
      expect(pe.energy, 3);
      expect(pe.nextEnergyIn, isNull);
    });

    test('enerji bitince oyun baslamaz; reklamla dolar ve limit uygulanir', () {
      final pe = PlanetEvent.instance;
      expect(pe.startRun(), isTrue);
      expect(pe.startRun(), isTrue);
      expect(pe.startRun(), isTrue);
      expect(pe.energy, 0);
      expect(pe.startRun(), isFalse);
      expect(pe.canAdRefill, isTrue);
      expect(pe.refillAfterAd(), isTrue);
      expect(pe.energy, 3);
      expect(pe.refillAfterAd(), isFalse); // zaten dolu
      for (var i = 0; i < PlanetEvent.maxAdRefills; i++) {
        pe.startRun();
        pe.startRun();
        pe.startRun();
        pe.refillAfterAd();
      }
      expect(pe.adRefillsLeft, 0);
      pe.startRun();
      expect(pe.canAdRefill, isFalse);
    });

    test('hafta ici oyun baslamaz', () {
      PlanetEvent.clock = () => _wed;
      expect(PlanetEvent.instance.startRun(), isFalse);
    });

    test('gorevler: gezegen kademesi, kombo x6, birlestirme, puan', () {
      final pe = PlanetEvent.instance;
      pe.onMerge(7, 1); // Neptun (kademe 7)
      expect(pe.canClaim(0), isTrue);
      expect(pe.canClaim(1), isFalse);
      pe.onMerge(8, 1);
      pe.onMerge(9, 1);
      expect(pe.canClaim(1), isTrue);
      expect(pe.canClaim(2), isTrue);

      // x6 kombo: yalnizca zincir TAM 6'ya ulastiginda bir kez sayilir.
      for (var c = 1; c <= 8; c++) {
        pe.onMerge(2, c);
      }
      expect(pe.progressOf(3), 1);
      pe.onMerge(2, 6);
      pe.onMerge(2, 6);
      expect(pe.canClaim(3), isTrue);

      pe.onScore(4199);
      expect(pe.canClaim(5), isFalse);
      pe.onScore(4200);
      expect(pe.canClaim(5), isTrue);
      pe.onScore(100); // dusuk skor en iyiyi dusurmez
      expect(pe.bestScore, 4200);
    });

    test('toplam puan gorevi: oyun boyunca artis eklenir, yeni oyunda sayac sifirlanir', () {
      final pe = PlanetEvent.instance;
      final i = PlanetEvent.tasks.indexWhere((t) => t.id == 'total');
      expect(i, PlanetEvent.tasks.length - 1); // SONA eklendi: eski 'cl' indeksleri bozulmaz
      expect(PlanetEvent.tasks[i].target, 350000);
      pe.startRun();
      pe.onScore(100);
      pe.onScore(100); // ayni puan tekrar sayilmaz
      pe.onScore(250);
      expect(pe.totalScore, 250);
      pe.startRun();
      pe.onScore(50); // yeni oyun: 50 eklenir (en iyi 250 kalir)
      expect(pe.totalScore, 300);
      expect(pe.bestScore, 250);
      expect(pe.canClaim(i), isFalse);
      pe.onScore(350000);
      expect(pe.canClaim(i), isTrue);
    });

    test('odul bir kez alinir; hepsi bitince buyuk odul', () {
      final pe = PlanetEvent.instance;
      pe.onMerge(9, 1);
      pe.onMerge(2, 6);
      pe.onMerge(2, 6);
      pe.onMerge(2, 6);
      pe.onScore(5000);
      pe.startRun();
      pe.onScore(PlanetEvent.targetTotalScore);
      for (var i = 0; i < PlanetEvent.targetMerges; i++) {
        pe.onMerge(0, 1);
      }
      expect(pe.allDone, isTrue);
      for (var i = 0; i < PlanetEvent.tasks.length; i++) {
        expect(pe.claim(i), isNotNull);
        expect(pe.claim(i), isNull); // ikinci kez alinamaz
      }
      expect(pe.canClaimGrand, isTrue);
      expect(pe.claimGrand(), isNotNull);
      expect(pe.claimGrand(), isNull);
      expect(given.length, PlanetEvent.tasks.length + 1);
    });

    test('etkinlik bitince alinmamis oduller otomatik verilir ve durum sifirlanir', () {
      final pe = PlanetEvent.instance;
      pe.onMerge(7, 1); // Neptun tamam, alinmadi
      expect(given, isEmpty);
      PlanetEvent.clock = () => DateTime(2026, 11, 2, 9, 0); // Pazartesi: yeni hafta
      expect(pe.hasClaimable, isFalse);
      expect(given.length, 1);
      expect(given.first.coins, PlanetEvent.tasks[0].reward.coins);
      expect(pe.bestTier, 0);
      expect(pe.energy, PlanetEvent.maxEnergy);
    });

    test('JSON gidis-donus', () {
      final pe = PlanetEvent.instance;
      pe.startRun();
      pe.onMerge(8, 6);
      pe.onScore(1234);
      final j = pe.toJson();
      expect(j['ts'], 1234);
      pe.resetForTest();
      pe.applyJson(j);
      expect(pe.bestTier, 8);
      expect(pe.combo6, 1);
      expect(pe.bestScore, 1234);
      expect(pe.totalScore, 1234);
      expect(pe.games, 1);
    });
  });

  group('SaveMerge.planetEvent', () {
    Map<String, dynamic> st({int w = 100, int tm = 0, int g = 0, int bt = 0, int e = 3, List<int> cl = const [], bool gc = false}) =>
        {'w': w, 'tm': tm, 'g': g, 'bt': bt, 'bs': 0, 'c6': 0, 'ar': 0, 'e': e, 'rs': 0, 'cl': cl, 'gc': gc};

    test('ayni hafta: birlestirme delta ile toplanir, alinanlar birlesir, enerji dusuk olan', () {
      final base = st(tm: 100, g: 2);
      final a = st(tm: 160, g: 3, bt: 7, e: 1, cl: [0]); // A: +60 birlestirme, 1 oyun
      final b = st(tm: 130, g: 3, bt: 8, e: 2, cl: [1]); // B: +30 birlestirme, 1 oyun
      final m = SaveMerge.planetEvent(base, a, b);
      expect(m['tm'], 190);
      expect(m['g'], 4);
      expect(m['bt'], 8);
      expect(m['cl'], [0, 1]);
      expect(m['e'], 1); // ayni enerjiyi iki cihazda harcama
    });

    test('toplam puan (ts) delta ile toplanir', () {
      final base = {...st(), 'ts': 1000};
      final a = {...st(), 'ts': 1600}; // A +600
      final b = {...st(), 'ts': 1250}; // B +250
      final m = SaveMerge.planetEvent(base, a, b);
      expect(m['ts'], 1850);
    });

    test('farkli hafta: yeni hafta kazanir', () {
      final m = SaveMerge.planetEvent(null, st(w: 100, tm: 999), st(w: 101, tm: 5));
      expect(m['w'], 101);
      expect(m['tm'], 5);
    });

    test('buyuk odul alindiysa geri acilmaz', () {
      final m = SaveMerge.planetEvent(null, st(gc: true), st(gc: false));
      expect(m['gc'], isTrue);
    });
  });
}
