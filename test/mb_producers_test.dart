import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/mb_tutorial.dart';
import 'package:fastfood_merge/models/merge_board.dart';

/// v185: Mod 2 coklu uretici sistemi (dunya basina 2-3 uretici, karisik siparis, uretici seviyesi).
MbBoard _board(int chapter, {int progress = 0}) {
  final b = MbBoard(chapter: chapter, chapterProgress: progress);
  b.genCell = MbBoard.generatorCell;
  return b;
}

void main() {
  test('dunya tablosu: her dunyada 2-3 zincir, ilki dunyanin kendi zinciri, tekrar yok', () {
    expect(MbWorlds.chains.length, MbState.worlds);
    for (var w = 0; w < MbState.worlds; w++) {
      final c = MbWorlds.chainsOf(w);
      expect(c.length >= 2 && c.length <= 3, true);
      expect(c.first, w);
      expect(c.toSet().length, c.length);
      for (final x in c) {
        expect(x >= 0 && x < MbState.worlds, true);
      }
    }
  });

  test('uretici kilitleri: dunya icindeki bolume gore 1 -> 2 -> 3', () {
    // Dunya 0 (Fast Food, 2 zincir): 1-4. bolum 1 uretici, 5-8. bolum 2.
    expect([for (var c = 1; c <= 8; c++) MbWorlds.producerCount(c)], [1, 1, 1, 1, 2, 2, 2, 2]);
    // Dunya 2 (Buyu, 3 zincir): bolum 17..24 -> 1,1,1,1,2,2,3,3.
    expect([for (var c = 17; c <= 24; c++) MbWorlds.producerCount(c)], [1, 1, 1, 1, 2, 2, 3, 3]);
  });

  test('hucre kodlamasi: slot*10+seviye; yalniz AYNI zincir ve seviye birlesir', () {
    expect(MbBoard.enc(1, 3), 13);
    expect(MbBoard.lv(13), 3);
    expect(MbBoard.slotOf(13), 1);
    expect(MbBoard.validItem(13), true);
    expect(MbBoard.validItem(9), false); // Lv9 yok
    expect(MbBoard.validItem(30), false); // slot 3 yok
    final b = MbBoard();
    b.cells[0] = 11; // slot 1, Lv1
    b.cells[1] = 1; // slot 0, Lv1
    expect(b.move(0, 1), MbMove.swapped); // farkli zincir birlesmez
    b.cells[2] = 1;
    expect(b.move(0, 2), MbMove.merged); // slot 0 Lv1 + Lv1
    expect(b.cells[2], 2);
    b.cells[3] = 11;
    b.cells[4] = 11;
    expect(b.move(3, 4), MbMove.merged);
    expect(b.cells[4], 12); // slot 1 Lv2
    b.cells[5] = 18; // slot 1, max seviye: birlesmez
    b.cells[6] = 18;
    expect(b.move(5, 6), MbMove.swapped);
  });

  test('siparisler: ilk bolumde sadece ana zincir, acik uretici olunca KARISIK ve acik olmayan zincir istenmez', () {
    final rng = math.Random(3);
    final b1 = _board(1);
    for (var i = 0; i < 100; i++) {
      b1.orders.clear();
      b1.refillOrders(rng);
      for (final o in b1.orders) {
        for (final l in o.levels) {
          expect(MbBoard.slotOf(l), 0);
        }
      }
    }
    final b3 = _board(23); // Buyu dunyasi, 7. bolum: 3 uretici acik
    expect(b3.producerCount, 3);
    final seen = <int>{};
    for (var i = 0; i < 300; i++) {
      b3.orders.clear();
      b3.refillOrders(rng);
      for (final o in b3.orders) {
        for (final l in o.levels) {
          expect(MbBoard.validItem(l), true);
          expect(MbBoard.slotOf(l) < 3, true);
          seen.add(MbBoard.slotOf(l));
        }
      }
    }
    expect(seen, {0, 1, 2});
  });

  test('uretici hucreleri: sabit, objeler konmaz/suruklenmez; acilan uretici hucresindeki obje kenara tasinir', () {
    final b = _board(5); // Fast Food 5. bolum: 2 uretici
    expect(b.genCells, [26, 27]);
    expect(b.genSlotOf(27), 1);
    expect(b.genSlotOf(25), -1); // 3. uretici henuz yok
    b.cells[0] = 2;
    expect(b.move(0, 27), MbMove.none);
    expect(b.move(27, 0), MbMove.none);
    // Eski tahta: 27. hucrede obje duruyor -> uretici acilinca baska yere tasinir.
    final c = _board(5);
    c.cells[27] = 4;
    c.syncProducers();
    expect(c.cells[27], 0);
    expect(c.cells.where((x) => x == 4).length, 1);
    expect(c.emptyCount, MbBoard.size - 2 - 1);
  });

  test('spawn: obje, dokunulan ureticinin zincirinde ve ona yakin cikar', () {
    final rng = math.Random(11);
    final b = _board(5);
    for (var i = 0; i < 6; i++) {
      final idx = b.spawn(rng, near: true, slot: 1);
      expect(idx >= 0, true);
      expect(MbBoard.slotOf(b.cells[idx]), 1);
      final d = (idx ~/ MbBoard.cols - 27 ~/ MbBoard.cols).abs() + (idx % MbBoard.cols - 27 % MbBoard.cols).abs();
      expect(d <= 4, true);
    }
  });

  test('dunya degisince: objeler ve yarim siparisler yeni slot sirasina cevrilir, kayip olmaz', () {
    // Dunya 0 = [Fast Food, Kafe] -> Dunya 1 = [Kafe, Fast Food]
    final b = _board(9); // dunya 1, 1. bolum (yeni dunyaya yeni girildi)
    b.cells[0] = 3; // eski dunyada slot 0 = Fast Food Lv3
    b.cells[1] = 12; // eski dunyada slot 1 = Kafe Lv2
    b.orders.add(MbOrder(id: 1, levels: [13, 4], reward: 10, filled: [false, false]));
    b.remapWorld(0, 1);
    expect(b.cells[0], 13); // Fast Food artik slot 1
    expect(b.cells[1], 2); // Kafe artik ana zincir (slot 0)
    // Siparis: Kafe Lv3 (slot 1 -> 0). Fast Food Lv4 (slot 0 -> 1) ama 2. uretici bu bolumde KILITLI -> ana zincire doner.
    expect(b.orders.first.levels, [3, 4]);
  });

  test('dunya degisince yeni dunyada olmayan zincir ana zincirin ayni seviyesine doner', () {
    // Dunya 2 = [Buyu, Kafe, Fast Food] -> Dunya 3 = [Korsan, Buyu, Kafe]; Fast Food (slot 2) artik yok.
    final b = _board(25);
    b.cells[0] = 25; // slot 2 Lv5
    b.cells[1] = 14; // slot 1 (Kafe) Lv4
    b.remapWorld(2, 3);
    expect(b.cells[0], 5); // ana zincir (Korsan) Lv5
    expect(b.cells[1], 24); // Kafe artik slot 2 (Dunya 3: [Korsan, Buyu, Kafe])
  });

  test('bolum bitince yeni uretici acilir (newProducer), oyuncu dunyanin 5. bolumunde 2. ureticiyi gorur', () {
    final rng = math.Random(5);
    final b = _board(4);
    final goal = MbChapter.of(4).goal;
    b.chapterProgress = goal - 1;
    b.orders.add(MbOrder(id: 1, levels: [2], reward: 5));
    b.cells[10] = 2;
    b.cells[27] = 6; // acilacak uretici hucresinde obje var
    final r = b.deliver(10, 0, rng);
    expect(r.ok && r.completed && r.chapterCompleted, true);
    expect(b.chapter, 5);
    expect(r.newProducer, true);
    expect(b.producerCount, 2);
    expect(b.cells[27], 0);
    expect(b.cells.where((x) => x == 6).length, 1);
    expect(r.worldCompleted, false);
  });

  test('8. bolum bitince dunya degisir: newProducer yok, objeler yeni zincir sirasina doner', () {
    final rng = math.Random(6);
    final b = _board(8);
    b.chapterProgress = MbChapter.of(8).goal - 1;
    b.orders.add(MbOrder(id: 1, levels: [2], reward: 5));
    b.cells[10] = 2;
    b.cells[0] = 4; // Fast Food Lv4 (slot 0)
    final r = b.deliver(10, 0, rng);
    expect(r.worldCompleted, true);
    expect(r.newProducer, false);
    expect(b.chapter, 9);
    expect(b.cells[0], 14); // Fast Food, Kafe dunyasinda slot 1
    expect(b.producerCount, 1); // yeni dunyanin 1. bolumu: yalniz ana uretici
  });

  test('uretici seviyesi: ust seviye ihtimali artar, kurali bolumde (sade uretec) uygulanmaz', () {
    var sum0 = 0, sum5 = 0;
    final cfg = MbChapter.of(12); // kuralsiz? (12 % 5 = 2 -> normal)
    expect(cfg.isRule, false);
    final r0 = math.Random(1), r5 = math.Random(1);
    for (var i = 0; i < 3000; i++) {
      sum0 += cfg.rollSpawn(r0);
      sum5 += cfg.rollSpawn(r5, bonusPct: MbWorlds.bonusPct(5));
    }
    expect(sum5 > sum0, true);
    final rule = MbChapter.of(3); // kurallı bolum: saf/sade uretec
    expect(rule.isRule, true);
    final rr = math.Random(2);
    for (var i = 0; i < 500; i++) {
      expect(rule.rollSpawn(rr, bonusPct: 100) <= 2, true);
    }
    expect(MbWorlds.bonusPct(1), 0);
    expect(MbWorlds.freeTapPct(1), 0);
    expect(MbWorlds.bonusPct(5) > 0 && MbWorlds.freeTapPct(5) > 0, true);
  });

  test('uretici seviyesi: bedava dokunus enerji harcamaz; seviye 1de hic bedava yok', () {
    final rng = math.Random(21);
    final s = MbState(board: _board(1));
    var t = 1000;
    var free1 = 0;
    for (var i = 0; i < 60; i++) {
      s.board.cells.fillRange(0, MbBoard.size, 0);
      final before = s.energy;
      expect(s.trySpawn(rng, t), MbSpawnResult.ok);
      if (s.lastSpawnFree) free1++;
      expect(s.energy, s.lastSpawnFree ? before : before - 1);
      s.energy = MbState.maxEnergy;
      t += 10;
    }
    expect(free1, 0);

    final s5 = MbState(board: _board(1), producerLevels: [5, 1, 1, 1, 1, 1]);
    var free5 = 0;
    for (var i = 0; i < 400; i++) {
      s5.board.cells.fillRange(0, MbBoard.size, 0);
      final before = s5.energy;
      expect(s5.trySpawn(rng, t), MbSpawnResult.ok);
      if (s5.lastSpawnFree) free5++;
      expect(s5.energy, s5.lastSpawnFree ? before : before - 1);
      s5.energy = MbState.maxEnergy;
      t += 10;
    }
    expect(free5 > 30 && free5 < 150, true); // ~%20
    // Enerji 0 iken bedava dokunus da yok.
    s5.energy = 0;
    s5.board.cells.fillRange(0, MbBoard.size, 0);
    expect(s5.trySpawn(rng, t + 100), MbSpawnResult.noEnergy);
  });

  test('yukseltme bedeli ve tavan', () {
    expect(MbWorlds.upgradeCost(1), 250);
    expect(MbWorlds.upgradeCost(4), 2400);
    expect(MbWorlds.upgradeCost(MbWorlds.maxProducerLevel), null);
    final s = MbState(board: _board(1));
    for (var i = 0; i < 10; i++) {
      s.bumpProducer(2);
    }
    expect(s.producerLevel(2), MbWorlds.maxProducerLevel);
    expect(s.bumpProducer(2), false);
    expect(s.producerLevel(0), 1);
  });

  test('kayit: uretici seviyeleri ve slotlu objeler gidis-donus; eski kayit (pl yok) hepsi Lv1', () {
    final rng = math.Random(4);
    final s = MbState.fresh(rng);
    s.bumpProducer(0);
    s.bumpProducer(0);
    s.bumpProducer(1);
    final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
    final back = MbState.fromJson(j, math.Random(1));
    expect(back.producerLevels, [3, 2, 1, 1, 1, 1]);

    final old = Map<String, dynamic>.of(j)..remove('pl');
    final back2 = MbState.fromJson(old, math.Random(1));
    expect(back2.producerLevels, [1, 1, 1, 1, 1, 1]);

    final bad = Map<String, dynamic>.of(j)..['pl'] = [99, -4, 'x', 2];
    final back3 = MbState.fromJson(bad, math.Random(1));
    expect(back3.producerLevels, [MbWorlds.maxProducerLevel, 1, 1, 2, 1, 1]);

    // Slotlu obje (Fast Food 5. bolum) kayittan geri gelir; gecersiz kod (slot 3) yeni tahta olur.
    final b = _board(5);
    b.cells[0] = 13;
    b.cells[1] = 6;
    final jb = jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>;
    final rb = MbBoard.fromJson(jb, math.Random(2));
    expect(rb.cells[0], 13);
    expect(rb.cells[1], 6);
    final badCells = List<int>.from(jb['c'] as List)..[2] = 33;
    final rb2 = MbBoard.fromJson(Map<String, dynamic>.of(jb)..['c'] = badCells, math.Random(2));
    expect(rb2.cells.where((c) => c == 1).length, 7); // fresh()
  });

  test('ogretici: 2. ureticinin zincirinden esya gerekiyorsa o ureticiye dokundurur', () {
    final b = _board(5);
    b.orders.add(MbOrder(id: 1, levels: [12], reward: 6)); // slot 1 Lv2
    b.cells[0] = 11; // slot 1 Lv1 tek tane
    final p = MbTutorial.plan(b)!;
    expect(p.kind, MbTutKind.spawn);
    expect(p.slot, 1);
    // Ayni zincirden iki Lv1 -> birlestir; farkli zincirin Lv1'i sayilmaz.
    b.cells[1] = 1;
    expect(MbTutorial.plan(b)!.kind, MbTutKind.spawn);
    b.cells[2] = 11;
    final m = MbTutorial.plan(b)!;
    expect(m.kind, MbTutKind.merge);
    expect([m.a, m.b]..sort(), [0, 2]);
    expect(m.level, 1);
  });
}
