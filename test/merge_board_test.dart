import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/merge_board.dart';

void main() {
  test('yeni tahta: 7 Lv1 obje, 3 siparis, ilk siparisler Lv2-3', () {
    final b = MbBoard.fresh(math.Random(1));
    expect(b.cells.where((c) => c == 1).length, 7);
    expect(b.orders.length, MbBoard.orderSlots);
    for (final o in b.orders) {
      for (final l in o.levels) {
        expect(l >= 2 && l <= 3, true);
      }
    }
  });

  test('move: tasi, birlestir, yer degistir, max seviye birlesmez', () {
    final b = MbBoard();
    b.cells[0] = 2;
    b.cells[1] = 2;
    b.cells[2] = 3;
    expect(b.move(0, 5), MbMove.moved);
    expect(b.cells[5], 2);
    expect(b.cells[0], 0);
    expect(b.move(5, 1), MbMove.merged);
    expect(b.cells[1], 3);
    expect(b.cells[5], 0);
    expect(b.move(1, 2), MbMove.merged); // 3 + 3 -> 4
    expect(b.cells[2], 4);
    b.cells[3] = 1;
    expect(b.move(3, 2), MbMove.swapped);
    expect(b.cells[2], 1);
    expect(b.cells[3], 4);
    b.cells[10] = MbBoard.maxLevel;
    b.cells[11] = MbBoard.maxLevel;
    expect(b.move(10, 11), MbMove.swapped);
    expect(b.cells[11], MbBoard.maxLevel);
    expect(b.move(7, 7), MbMove.none);
    expect(b.move(20, 21), MbMove.none); // bos hucre
  });

  test('spawn: tahta dolunca -1', () {
    final b = MbBoard();
    final rng = math.Random(3);
    for (var i = 0; i < MbBoard.size; i++) {
      expect(b.spawn(rng) >= 0, true);
    }
    expect(b.isFull, true);
    expect(b.spawn(rng), -1);
  });

  test('siparis teslimi: kalem dolar, bitince odul + yeni siparis', () {
    final rng = math.Random(5);
    final b = MbBoard();
    b.orders.add(MbOrder(id: 1, levels: [2, 3], reward: 99));
    b.refillOrders(rng);
    b.cells[0] = 2;
    b.cells[1] = 3;
    b.cells[2] = 4;
    expect(b.canDeliver(2, 0), false); // Lv4 istenmiyor
    expect(b.deliver(2, 0, rng).ok, false);
    final r1 = b.deliver(0, 0, rng);
    expect(r1.ok, true);
    expect(r1.completed, false);
    expect(b.cells[0], 0);
    final r2 = b.deliver(1, 0, rng);
    expect(r2.completed, true);
    expect(r2.reward, 99);
    expect(b.delivered, 1);
    expect(b.orders.length, MbBoard.orderSlots);
  });

  test('bolum tablosu: 1. bolum Lv2-3, 2. bolum Lv3-4, kural/ozel bolumler', () {
    final c1 = MbChapter.of(1);
    expect([c1.minLevel, c1.maxLevel], [2, 3]);
    expect(c1.rule, MbRule.none);
    final c2 = MbChapter.of(2);
    expect([c2.minLevel, c2.maxLevel], [3, 4]);
    expect(MbChapter.of(3).isRule, true);
    expect(MbChapter.of(5).isSpecial, true);
    expect(MbChapter.of(8).isRule, true);
    expect(MbChapter.of(10).isSpecial, true);
    expect(MbChapter.of(5).rewardPercent, 200);
    expect(MbChapter.of(10).energyPerOrder, MbChapter.feastEnergy);
    expect(MbChapter.feastEnergy, 5);
    expect(MbChapter.of(8).rewardPercent, 150); // sadece yuksek seviye
    expect(MbChapter.of(18).rewardPercent, 125); // tek hedef
  });

  test('yumusak rampa: 4. bolum Lv3-4 agirlikli (Lv5 nadir), normal bolumlerde siparis basina 2 enerji geri', () {
    final c4 = MbChapter.of(4);
    expect([c4.minLevel, c4.maxLevel], [3, 5]);
    expect(c4.rareTop, true);
    // v186: 5. bolum (altin + 2. uretici) yumusak: Lv3-4, hedef 5; Lv5 siparisleri 6. bolumde donuyor.
    expect([MbChapter.of(5).minLevel, MbChapter.of(5).maxLevel], [3, 4]);
    expect(MbChapter.of(5).goal, 5);
    expect([MbChapter.of(6).minLevel, MbChapter.of(6).maxLevel], [3, 5]);
    expect(MbChapter.of(6).goal, 6);
    expect([MbChapter.of(7).minLevel, MbChapter.of(7).maxLevel], [4, 5]);
    expect(MbChapter.baseOrderEnergy, 2);
    expect(c4.energyPerOrder, 2);
    expect(MbChapter.of(1).energyPerOrder, 2);
    expect(MbChapter.of(10).energyPerOrder, MbChapter.feastEnergy);
    // 4. bolumde Lv5 kalem istegi %15 civarinda (kalem basina)
    final rng = math.Random(3);
    var lv5 = 0, total = 0;
    for (var i = 0; i < 400; i++) {
      final b = MbBoard(chapter: 4);
      b.orders.clear();
      b.refillOrders(rng);
      for (final o in b.orders) {
        for (final l in o.levels) {
          total++;
          if (l == 5) lv5++;
        }
      }
    }
    expect(lv5 / total > 0.05 && lv5 / total < 0.30, true, reason: 'Lv5 orani ${lv5 / total}');
  });

  test('uretec: bolumle yukselir (Lv5 cok nadir), kurallı bolumde sade, her dagilim 1000', () {
    for (var ch = 1; ch <= 80; ch++) {
      final c = MbChapter.of(ch);
      expect(c.spawnWeights.length, 5);
      expect(c.spawnWeights.fold<int>(0, (a, b) => a + b), 1000);
    }
    final rng = math.Random(5);
    int maxSeen(int ch) {
      var m = 0;
      for (var i = 0; i < 20000; i++) {
        m = math.max(m, MbChapter.of(ch).rollSpawn(rng));
      }
      return m;
    }

    expect(maxSeen(1), 2);
    expect(maxSeen(2), 3);
    expect(maxSeen(4), 4);
    expect(maxSeen(30), 5);
    expect(MbChapter.of(3).maxSpawnLevel, 2); // kural: duo -> sade
    expect(MbChapter.of(13).maxSpawnLevel, 1); // kural: pure -> sadece Lv1
    // Lv5 cok nadir: en yuksek bantta bile %2'yi gecmez
    var lv5 = 0;
    for (var i = 0; i < 40000; i++) {
      if (MbChapter.of(30).rollSpawn(rng) == 5) lv5++;
    }
    expect(lv5 / 40000 < 0.03, true);
    expect(MbChapter.of(1).xpReward, MbChapter.of(1).goal + 10);
  });

  test('siparisler bolum araligina uyar, maliyet sinirini asmaz, kurallar calisir', () {
    final rng = math.Random(11);
    for (var ch = 1; ch <= 60; ch++) {
      final cfg = MbChapter.of(ch);
      final b = MbBoard(chapter: ch);
      for (var i = 0; i < 60; i++) {
        b.orders.clear();
        b.refillOrders(rng);
        for (final o in b.orders) {
          var cost = 0;
          for (final l in o.levels) {
            expect(l >= cfg.minLevel && l <= cfg.maxLevel, true, reason: 'bolum $ch');
            cost += MbBoard.itemCost(l);
          }
          if (o.levels.length > 1 && o.levels.length > cfg.minItems) {
            expect(cost <= MbBoard.maxOrderCost, true);
          }
          if (cfg.singleOnly) expect(o.levels.length, 1);
          if (cfg.minItems >= 2) expect(o.levels.length >= 2, true);
          expect(o.reward > 0, true);
        }
      }
    }
  });

  test('bolum biter: odul, sonraki bolum, ilerleme sifirlanir', () {
    final rng = math.Random(21);
    final b = MbBoard();
    final goal = b.chapterCfg.goal;
    b.chapterProgress = goal - 1;
    b.orders.clear();
    b.refillOrders(rng);
    expect(b.orders.length, 1); // son siparis kaldi
    final levels = List<int>.of(b.orders[0].levels);
    MbDeliverResult? last;
    for (var i = 0; i < levels.length; i++) {
      b.cells[i] = levels[i];
      last = b.deliver(i, 0, rng);
    }
    expect(last!.completed, true);
    expect(last.chapterCompleted, true);
    expect(last.finishedChapter, 1);
    expect(last.chapterBonus > 0, true);
    expect(last.worldCompleted, false);
    expect(b.chapter, 2);
    expect(b.chapterProgress, 0);
    expect(b.orders.isNotEmpty, true);
  });

  test('tema bolum numarasindan gelir: 8 bolumde bir degisir, 6 temadan sonra basa doner', () {
    expect(MbState.worldOfChapter(1), 0);
    expect(MbState.worldOfChapter(8), 0);
    expect(MbState.worldOfChapter(9), 1);
    expect(MbState.worldOfChapter(48), 5);
    expect(MbState.worldOfChapter(49), 0);
    final rng = math.Random(3);
    final b = MbBoard(chapter: 8);
    b.chapterProgress = b.chapterCfg.goal - 1;
    b.orders.clear();
    b.refillOrders(rng);
    MbDeliverResult? last;
    final levels = List<int>.of(b.orders[0].levels);
    for (var i = 0; i < levels.length; i++) {
      b.cells[i] = levels[i];
      last = b.deliver(i, 0, rng);
    }
    expect(last!.worldCompleted, true);
    expect(MbState(board: b).worldIndex, 1);
  });

  test('enerji: harcama, regenSeconds sonra dolum, tahta doluyken harcanmaz', () {
    final rng = math.Random(2);
    final s = MbState.fresh(rng);
    const t0 = 1000000;
    final step = MbState.regenSeconds * 1000;
    expect(s.trySpawn(rng, t0), MbSpawnResult.ok);
    expect(s.energy, MbState.maxEnergy - 1);
    s.regen(t0 + step - 1000);
    expect(s.energy, MbState.maxEnergy - 1);
    s.regen(t0 + step + 1000);
    expect(s.energy, MbState.maxEnergy);
    expect(s.regenStartMs, 0);

    s.energy = 0;
    s.regenStartMs = t0;
    expect(s.trySpawn(rng, t0 + 1000), MbSpawnResult.noEnergy);

    final full = MbState.fresh(rng);
    for (var i = 0; i < MbBoard.size; i++) {
      full.board.cells[i] = 1;
    }
    final before = full.energy;
    expect(full.trySpawn(rng, t0), MbSpawnResult.full);
    expect(full.energy, before);
  });

  test('kayit: JSON gidis-donus ayni durumu verir, bozuk veri yeni oyun olur', () {
    final rng = math.Random(9);
    final s = MbState.fresh(rng);
    s.board.move(0, 1);
    s.board.chapter = 4;
    s.board.chapterProgress = 2;
    s.energy = 7;
    final back = MbState.fromJson(jsonDecode(jsonEncode(s.toJson())), math.Random(1));
    expect(back.energy, 7);
    expect(back.board.chapter, 4);
    expect(back.board.chapterProgress, 2);
    expect(back.board.cells, s.board.cells);
    expect(back.board.orders.isNotEmpty, true);
    final bad = MbState.fromJson('garbage', math.Random(1));
    expect(bad.board.chapter, 1);
    expect(bad.energy, MbState.maxEnergy);
  });

  test('eski kayit (6 ayri dunya tahtasi): en ileri tahta tek tahta olur', () {
    final rng = math.Random(13);
    final boards = <Map<String, dynamic>>[];
    for (var w = 0; w < 6; w++) {
      final j = MbBoard.fresh(rng).toJson();
      j.remove('ch');
      j.remove('cp');
      j['d'] = w == 2 ? 12 : 0;
      boards.add(j);
    }
    final old = {'v': 1, 'e': 5, 'rs': 0, 'uw': 3, 'cw': 1, 'b': boards};
    final s = MbState.fromJson(jsonDecode(jsonEncode(old)), math.Random(1));
    expect(s.energy, MbState.maxEnergy); // v<3 kayit: bir kerelik tam dolum
    expect(s.board.chapter, 3); // 12 teslim = 5 + 5 + 2
    expect(s.board.chapterProgress, 2);
  });

  test('enerji dengesi (v159): bar 100, reklam +25, ust sinir 200, dolum 90 sn', () {
    expect(MbState.maxEnergy, 100);
    expect(MbState.adEnergy, 25);
    expect(MbState.energyCap, 200);
    expect(MbState.regenSeconds, 90);
    final s = MbState.fresh(math.Random(3));
    s.addEnergy(MbState.adEnergy);
    expect(s.energy, MbState.maxEnergy + MbState.adEnergy);
    for (var i = 0; i < 10; i++) {
      s.addEnergy(MbState.adEnergy);
    }
    expect(s.energy, MbState.energyCap);
    // Bar ustundeyken pasif dolum islemez, harcayinca bar'in altina inince baslar.
    s.regen(5000000);
    expect(s.energy, MbState.energyCap);
  });

  test('eski kayit (v2, bar 20): bir kerelik tam dolum; v3 kaydi dokunulmaz', () {
    final rng = math.Random(4);
    final j = MbState.fresh(rng).toJson();
    j['v'] = 2;
    j['e'] = 3;
    j['rs'] = 12345;
    final up = MbState.fromJson(jsonDecode(jsonEncode(j)), math.Random(1));
    expect(up.energy, MbState.maxEnergy);
    expect(up.regenStartMs, 0);

    j['v'] = MbState.saveVersion;
    final same = MbState.fromJson(jsonDecode(jsonEncode(j)), math.Random(1));
    expect(same.energy, 3);
    expect(same.regenStartMs, 12345);
  });

  test('kayit: ondalikli (double) sayilar da okunur, tahta sifirlanmaz', () {
    final rng = math.Random(6);
    final s = MbState.fresh(rng);
    s.board.chapter = 5;
    final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
    final b = j['b'] as Map<String, dynamic>;
    b['c'] = [for (final x in (b['c'] as List)) (x as num).toDouble()];
    final back = MbState.fromJson(j, math.Random(1));
    expect(back.board.chapter, 5);
    expect(back.board.cells, s.board.cells);
  });

  test('elmasla tam dolum: bar dolu degilse dolar, doluysa/ustundeyse degismez', () {
    expect(MbState.refillGemCost, 100);
    final s = MbState.fresh(math.Random(8));
    const t0 = 2000000;
    s.energy = 0;
    s.regenStartMs = t0;
    expect(s.refillFull(t0 + 1000), true);
    expect(s.energy, MbState.maxEnergy);
    expect(s.regenStartMs, 0);
    expect(s.refillFull(t0 + 2000), false);
    s.addEnergy(MbState.adEnergy); // bar ustu (reklam enerjisi)
    expect(s.refillFull(t0 + 3000), false);
    expect(s.energy, MbState.maxEnergy + MbState.adEnergy);
  });

  test('uretec: sabit hucre, objeler oraya konmaz/suruklenmez, yakin hucrelere dagilir', () {
    final rng = math.Random(5);
    final b = MbBoard.fresh(rng);
    expect(b.genCell, MbBoard.generatorCell);
    b.cells.fillRange(0, b.cells.length, 0);
    final g = b.genCell;
    expect(b.emptyCount, MbBoard.size - 1); // uretec hucresi bos sayilmaz
    for (var i = 0; i < 5; i++) {
      final idx = b.spawn(rng, near: true);
      expect(idx >= 0 && idx != g, true);
      final d = (idx ~/ MbBoard.cols - g ~/ MbBoard.cols).abs() + (idx % MbBoard.cols - g % MbBoard.cols).abs();
      expect(d <= 3, true); // uretecin hemen etrafi
    }
    expect(b.cells[g], 0);
    final from = b.cells.indexWhere((c) => c > 0);
    expect(b.move(from, g), MbMove.none);
    expect(b.cells[from] > 0, true);
    // Tahta tamamen dolunca (uretec haric) spawn -1 doner.
    for (var i = 0; i < MbBoard.size; i++) {
      if (i != g) b.cells[i] = 1;
    }
    expect(b.isFull, true);
    expect(b.spawn(rng, near: true), -1);
  });

  test('uretec: eski kayitta uretec hucresindeki obje en yakin bos hucreye tasinir', () {
    final rng = math.Random(8);
    final j = MbBoard.fresh(rng).toJson();
    final cells = List<int>.filled(MbBoard.size, 0);
    cells[MbBoard.generatorCell] = 3;
    j['c'] = cells;
    final b = MbBoard.fromJson(j, rng);
    expect(b.genCell, MbBoard.generatorCell);
    expect(b.cells[MbBoard.generatorCell], 0);
    expect(b.cells.where((c) => c == 3).length, 1);
  });
}
