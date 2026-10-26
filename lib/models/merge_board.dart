import 'dart:math' as math;

/// MOD 2 - "Merge Tahtasi": klasik, izgara tabanli merge oyunu.
///
/// Bu dosya SAF mantiktir (Flutter/ekran yok) -> test edilebilir.
/// Kayit/coin/enerji baglantisi: lib/services/merge_board_service.dart.
///
/// Oynanis: tahtadaki ureteci (sandik) dokun -> bos hucreye Lv1 (bazen Lv2) obje
/// cikar (1 enerji). Ayni seviyeden iki objeyi birine surukleyip birak -> bir ust
/// seviye. Sipariş kartina uygun seviyede obje birakinca teslim edilir; tum
/// kalemler tamamlaninca coin odulu verilir, yeni siparis gelir.

/// MOD 2 URETICI SISTEMI (v185).
///
/// Her dunya AYRI kalir (arka plan/tema bolum numarasindan gelir) ama dunyanin icinde
/// 2-3 URETICI vardir. Bir uretici = bir esya ZINCIRI (Fast Food, Kafe, Buyu, ...: 6 tema = 6 zincir).
///  * Dunya k: ana zincir k (1. bolumden itibaren) + onceki dunyalarin zincirleri geri gelir
///    (Fast Food dunyasinda tanitim olarak Kafe zinciri). Sira: [chains].
///  * Dunya icinde 2. uretici [unlockChapter][1]. bolumde, 3. uretici [unlockChapter][2]. bolumde acilir.
///  * Siparisler acik uretecilerin zincirlerinden KARISIK kalem ister.
///  * Her zincirin ureticisi 1..5 seviye: yukselince yuksek seviye obje cikma ihtimali artar
///    ve bazi dokunuslar enerji harcamaz. Seviye zincire bagli ve dunyalar arasi KALICIDIR.
///
/// Tahtadaki hucre degeri = slot * 10 + seviye (slot = dunyadaki uretici sirasi, 0 = ana zincir).
/// Eski kayitlarda slot hep 0 oldugu icin kayit uyumludur.
class MbWorlds {
  MbWorlds._();

  /// Dunya -> uretici zincirleri (tema indeksleri). [0] = dunyanin ana zinciri.
  /// Bu tabloyu degistirmek yeterli: ekran ve mantik buradan okur.
  static const List<List<int>> chains = [
    [0, 1], // Fast Food: + Kafe (tanitim)
    [1, 0], // Kafe: + Fast Food
    [2, 1, 0], // Buyu: + Kafe + Fast Food
    [3, 2, 1], // Korsan
    [4, 3, 2], // Buz
    [5, 4, 3], // Uzay
  ];

  /// Dunya icindeki bolum numarasi (1..chaptersPerWorld) -> kac uretici acik: slot s, bu bolumden itibaren acilir.
  // v186: [1, 5, 7] -> 1-4. bolum yalniz ana uretici (yeni dunyanin kendi zinciri), 5. bolumde 2., 7. bolumde 3. uretici.
  static const List<int> unlockChapter = [1, 5, 7];

  /// Uretici hucreleri (slot sirasina gore): ana uretici ortada, 2. sagda, 3. solda.
  static const List<int> producerCells = [26, 27, 25];

  /// Uretici seviye siniri ve yukseltme bedeli (coin): [level] -> level+1.
  static const int maxProducerLevel = 5;
  static const List<int> upgradeCosts = [250, 600, 1200, 2400];

  static List<int> chainsOf(int world) => chains[world % chains.length];

  /// [slot] siradaki ureticinin zinciri (tema indeksi); gecersiz slot ana zincire duser.
  static int chainOf(int world, int slot) {
    final c = chainsOf(world);
    return c[(slot >= 0 && slot < c.length) ? slot : 0];
  }

  static int inWorldChapter(int chapter) => (math.max(1, chapter) - 1) % MbState.chaptersPerWorld + 1;

  /// Bu bolumde acik uretici sayisi (en az 1).
  static int producerCount(int chapter) {
    final world = MbState.worldOfChapter(chapter);
    final n = chainsOf(world).length;
    final ic = inWorldChapter(chapter);
    var count = 0;
    for (var s = 0; s < n && s < unlockChapter.length; s++) {
      if (ic >= unlockChapter[s]) count++;
    }
    return math.max(1, count);
  }

  /// Seviye [level] ureticide, uretilen objenin bir ust seviye cikma ihtimali (yuzde).
  static int bonusPct(int level) => (level.clamp(1, maxProducerLevel).toInt() - 1) * 8;

  /// Seviye [level] ureticide, dokunusun enerji harcamama ihtimali (yuzde).
  static int freeTapPct(int level) => (level.clamp(1, maxProducerLevel).toInt() - 1) * 5;

  /// [level] -> level+1 bedeli; en ust seviyede null.
  static int? upgradeCost(int level) {
    if (level < 1) return upgradeCosts[0];
    if (level >= maxProducerLevel) return null;
    return upgradeCosts[level - 1];
  }
}

/// Bir siparis: [levels] listesindeki her eleman, 1 obje ister (deger = slot*10 + seviye, bkz. MbWorlds).
class MbOrder {
  final int id;
  final List<int> levels;
  final List<bool> filled;
  final int reward;

  MbOrder({required this.id, required this.levels, required this.reward, List<bool>? filled})
      : filled = filled ?? List<bool>.filled(levels.length, false);

  bool get complete {
    for (final f in filled) {
      if (!f) return false;
    }
    return true;
  }

  /// [level] seviyesindeki objeyi koyabilecegimiz BOS kalem indeksi, yoksa -1.
  int slotFor(int level) {
    for (var i = 0; i < levels.length; i++) {
      if (!filled[i] && levels[i] == level) return i;
    }
    return -1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'l': levels,
        'f': filled,
        'r': reward,
      };

  static MbOrder? fromJson(Object? j) {
    if (j is! Map) return null;
    final l = j['l'];
    final f = j['f'];
    if (l is! List || l.isEmpty) return null;
    final levels = <int>[];
    for (final x in l) {
      final xi = x is num ? x.toInt() : 0;
      if (xi < 1 || !MbBoard.validItem(xi)) return null;
      levels.add(xi);
    }
    final filled = <bool>[];
    for (var i = 0; i < levels.length; i++) {
      filled.add(f is List && i < f.length && f[i] == true);
    }
    return MbOrder(
      id: (j['id'] as num?)?.toInt() ?? 0,
      levels: levels,
      reward: (j['r'] as num?)?.toInt() ?? 1,
      filled: filled,
    );
  }
}

/// Bolum kurali / ozel bolum turu.
enum MbRule { none, duo, high, pure, single, gold, feast }

/// Bir dunyadaki bolumun ayarlari (bolum numarasindan turetilir, kaydedilmez).
///
///  * Zorluk: 1. bolum Lv2-3, 2. bolum Lv3-4, sonra Lv5 (25. bolumden sonra Lv6, 49'dan sonra Lv7).
///  * Uretec: bolum ilerledikce Lv1..Lv5 cikar (Lv5 cok nadir); kurallı bolumlerde sade.
///  * Her 5'lik dongude: 3. bolum KURALLI, 5. bolum OZEL (odullu) bolumdur.
class MbChapter {
  final int number;
  final MbRule rule;
  final int goal; // bolumu bitirmek icin teslim edilecek siparis
  final int minLevel;
  final int maxLevel;
  final int minItems; // siparisteki en az kalem
  final bool singleOnly; // siparis hep tek kalem
  final List<int> spawnWeights; // uretec seviye dagilimi (binde), Lv1..Lv5
  final int rewardPercent; // siparis coin carpani (100 = normal)
  final int completionBonus; // bolum bitince ek coin
  final int energyPerOrder; // siparis basina geri gelen enerji
  final bool rareTop; // true: siparis kalemleri nadiren (%15) en ust seviyeyi ister (yumusak gecis)

  const MbChapter({
    required this.number,
    required this.rule,
    required this.goal,
    required this.minLevel,
    required this.maxLevel,
    required this.minItems,
    required this.singleOnly,
    required this.spawnWeights,
    required this.rewardPercent,
    required this.completionBonus,
    required this.energyPerOrder,
    this.rareTop = false,
  });

  /// Uretecten cikabilecek en yuksek seviye.
  int get maxSpawnLevel {
    var m = 1;
    for (var i = 0; i < spawnWeights.length; i++) {
      if (spawnWeights[i] > 0) m = i + 1;
    }
    return m;
  }

  /// Uretecten cikacak seviyeyi sec (1..5).
  /// [bonusPct]: uretici seviyesinden gelen "bir ust seviye" ihtimali (yuzde). Kurallı bolumlerde
  /// (sade/saf uretec) uygulanmaz; bonus 0 iken rastgele sayi URETILMEZ (eski tohumlu testler ayni kalir).
  int rollSpawn(math.Random rng, {int bonusPct = 0}) {
    var r = rng.nextInt(1000);
    var lvl = 1;
    for (var i = 0; i < spawnWeights.length; i++) {
      r -= spawnWeights[i];
      if (r < 0) {
        lvl = i + 1;
        break;
      }
    }
    if (bonusPct > 0 && !isRule && lvl < spawnWeights.length && rng.nextInt(100) < bonusPct) lvl++;
    return lvl;
  }

  /// Bolum XP'si (bolum bitince; Mod 1'in yaklasik yarisi).
  int get xpReward => goal + 10;

  bool get isRule => rule == MbRule.duo || rule == MbRule.high || rule == MbRule.pure || rule == MbRule.single;
  bool get isSpecial => rule == MbRule.gold || rule == MbRule.feast;

  /// AppStrings.lt anahtari (Ingilizce): rozet basligi. Bos = normal bolum.
  String get titleEn => switch (rule) {
        MbRule.none => '',
        MbRule.duo => '📜 Rule: Double orders',
        MbRule.high => '📜 Rule: High level only',
        MbRule.pure => '📜 Rule: Pure spawn',
        MbRule.single => '📜 Rule: Single target',
        MbRule.gold => '⭐ Special: Golden orders',
        MbRule.feast => '⭐ Special: Feast',
      };

  /// AppStrings.lt anahtari (Ingilizce): kisa aciklama.
  String get descEn => switch (rule) {
        MbRule.none => '',
        MbRule.duo => 'Every order needs 2 or more items.',
        MbRule.high => 'Orders only ask for the top level of this chapter and pay +50% coins.',
        MbRule.pure => 'The spawner only gives Lv1, but orders are easier.',
        MbRule.single => 'One item per order, all at the top level, +25% coins.',
        MbRule.gold => 'Orders and the chapter bonus pay double coins.',
        MbRule.feast => 'Every delivered order gives +5 ⚡ back.',
      };

  /// Bereket bolumunde teslim edilen her siparisin geri verdigi enerji.
  static const int feastEnergy = 5;

  /// Normal bolumlerde teslim edilen her siparisin geri verdigi enerji (Bereket bolumu 5).
  /// Bolum maliyeti yuksek oldugu icin (4. bolumde ~67 enerji) oyuncu enerjiye bogulmasin.
  static const int baseOrderEnergy = 2;

  static List<int> _bandWeights(int n) {
    if (n <= 1) return const [880, 120, 0, 0, 0];
    if (n <= 3) return const [800, 170, 30, 0, 0];
    if (n <= 6) return const [700, 230, 60, 10, 0];
    if (n <= 12) return const [600, 280, 100, 18, 2];
    if (n <= 24) return const [500, 310, 140, 45, 5];
    return const [420, 320, 170, 75, 15];
  }

  static const List<MbRule> _rules = [MbRule.duo, MbRule.high, MbRule.pure, MbRule.single];
  static const List<MbRule> _specials = [MbRule.gold, MbRule.feast];
  static final Map<int, MbChapter> _cache = {};

  static MbChapter of(int number) {
    final n = number < 1 ? 1 : number;
    return _cache.putIfAbsent(n, () => _build(n));
  }

  static MbChapter _build(int n) {
    final pos = (n - 1) % 5 + 1; // 1..5
    final cycle = (n - 1) ~/ 5;
    var rule = MbRule.none;
    if (pos == 3) rule = _rules[cycle % _rules.length];
    if (pos == 5) rule = _specials[cycle % _specials.length];

    // Siparis seviye ustu: 1. bolum Lv2-3, 2. bolum Lv3-4, sonra Lv5'e kadar; 25. bolumden
    // sonra Lv6, 49'dan sonra Lv7. Kurallı bolumler (uretec sade) en fazla Lv5 ister.
    var hi = n == 1 ? 3 : (n <= 3 ? 4 : (n <= 24 ? 5 : (n <= 48 ? 6 : 7)));
    var lo = math.max(2, hi - 1);
    // Yumusak zorluk rampasi: 4. bolum Lv3-4 agirlikli (Lv5 nadir), 5-6. bolum Lv3-5; 7'den sonra Lv4-5.
    var rareTop = false;
    if (n == 4) {
      lo = 3;
      rareTop = true;
    } else if (n == 5 || n == 6) {
      lo = 3;
    }
    var goal = math.min(6, 4 + (n + 3) ~/ 4);
    // v186: 5. bolumde 2. uretici + altin bolum birlikte geliyor -> oyuncuyu bogmamak icin Lv5 yok, hedef 5.
    if (n == 5) {
      hi = 4;
      lo = 3;
      goal = 5;
    }
    var minItems = 1;
    var single = false;
    var rewardPct = 100;
    var energy = baseOrderEnergy;
    var bonusMul = 1;
    // Uretec dagilimi: kurallı bolumde sade (Lv1 %88 / Lv2 %12), digerlerinde bolumle artar.
    var weights = _bandWeights(n);
    const plain = [880, 120, 0, 0, 0];

    switch (rule) {
      case MbRule.duo:
        hi = math.min(hi, 5);
        lo = math.max(2, hi - 1);
        minItems = 2;
        weights = plain;
        break;
      case MbRule.high:
        hi = math.min(hi, 5);
        lo = hi;
        goal = math.max(3, goal - 2);
        weights = plain;
        rewardPct = 150; // en pahali bolum turu: siparis basina enerji ~2x, odul +%50
        break;
      case MbRule.pure:
        weights = const [1000, 0, 0, 0, 0];
        hi = math.max(3, math.min(hi, 5) - 1);
        lo = math.max(2, hi - 1);
        break;
      case MbRule.single:
        single = true;
        hi = math.min(hi, 5);
        lo = hi;
        goal = math.max(3, goal - 1);
        weights = plain;
        rewardPct = 125;
        break;
      case MbRule.gold:
        rewardPct = 200;
        bonusMul = 2;
        break;
      case MbRule.feast:
        energy = feastEnergy;
        break;
      case MbRule.none:
        break;
    }
    final bonus = math.min(600, 30 * n) * bonusMul;
    return MbChapter(
      number: n,
      rule: rule,
      goal: goal,
      minLevel: lo,
      maxLevel: hi,
      minItems: minItems,
      singleOnly: single,
      spawnWeights: weights,
      rewardPercent: rewardPct,
      completionBonus: bonus,
      energyPerOrder: energy,
      rareTop: rareTop,
    );
  }
}

enum MbMove { none, moved, swapped, merged }

class MbDeliverResult {
  /// Obje siparise kabul edildi mi.
  final bool ok;

  /// Siparis tamamen bitti mi (odul verildi, yenisi geldi).
  final bool completed;
  final int reward;

  /// Bu teslimle bolum de bitti mi (bolum odulu + yeni bolum).
  final bool chapterCompleted;
  final int chapterBonus;
  final int finishedChapter;

  /// Siparis basina geri gelen enerji (Bereket bolumu).
  final int energyBonus;

  /// Bu teslimle yeni bir uretici acildi mi (v185).
  final bool newProducer;
  const MbDeliverResult(
    this.ok,
    this.completed,
    this.reward, {
    this.chapterCompleted = false,
    this.chapterBonus = 0,
    this.finishedChapter = 0,
    this.energyBonus = 0,
    this.newProducer = false,
  });
  static const rejected = MbDeliverResult(false, false, 0);

  /// Biten bolum, dunyanin son bolumuyse true (tema/arka plan degisir).
  bool get worldCompleted => chapterCompleted && finishedChapter % MbState.chaptersPerWorld == 0;
}

/// Tek bir dunyanin tahtasi + siparisleri.
class MbBoard {
  static const int cols = 6;
  static const int rows = 8;
  static const int size = cols * rows;
  static const int maxLevel = 8;
  static const int orderSlots = 3;

  /// v182: Tahtadaki URETEC nesnesinin sabit hucresi (sandik). Objeler buraya konmaz,
  /// suruklenemez; dokununca ⚡1 harcayip yakin bos hucrelere obje uretir.
  static const int generatorCell = 26; // 5. satir, 3. sutun (tahtanin ortasi) = ana uretici (slot 0)

  /// Hucre degeri = slot*10 + seviye (bkz. MbWorlds). Seviye 1..maxLevel, slot 0..2.
  static const int slotStride = 10;
  static int lv(int v) => v % slotStride;
  static int slotOf(int v) => v ~/ slotStride;
  static int enc(int slot, int level) => slot * slotStride + level;
  static bool validItem(int v) {
    if (v <= 0) return false;
    final l = lv(v);
    return l >= 1 && l <= maxLevel && slotOf(v) < MbWorlds.producerCells.length;
  }

  /// Lv1 objenin coin degeri. Lv n = unitCoins * 2^(n-1) (Lv8 = 384).
  static const int unitCoins = 3;

  /// Bir siparisin toplam "Lv1 esdegeri" bu degeri asmasin (asiri zor siparis olmasin).
  static const int maxOrderCost = 64;

  /// Uretecten Lv2 cikma ihtimali (yuzde).
  static const int lv2ChancePercent = 12;

  /// 0 = bos hucre, 1..8 = obje seviyesi.
  final List<int> cells;
  final List<MbOrder> orders;

  /// Bu dunyada toplam teslim edilen siparis (istatistik).
  int delivered;
  int nextOrderId;

  /// Uretec hucresi (-1 = uretec yok: yalniz birim testlerde / ham tahta). Oyunda
  /// [fresh] ve [fromJson] bunu [generatorCell] yapar; kayda yazilmaz (sabit).
  int genCell = -1;

  /// Bu dunyadaki gecerli bolum (1'den baslar) ve o bolumde teslim edilen siparis.
  int chapter;
  int chapterProgress;

  MbBoard({
    List<int>? cells,
    List<MbOrder>? orders,
    this.delivered = 0,
    this.nextOrderId = 1,
    this.chapter = 1,
    this.chapterProgress = 0,
  })  : cells = cells ?? List<int>.filled(size, 0),
        orders = orders ?? <MbOrder>[];

  MbChapter get chapterCfg => MbChapter.of(chapter);

  /// Yeni oyun: birkac Lv1 obje + ilk siparisler.
  factory MbBoard.fresh(math.Random rng) {
    final b = MbBoard();
    b.genCell = generatorCell;
    for (var i = 0; i < 7; i++) {
      b.spawn(rng, forceLevel: 1);
    }
    b.refillOrders(rng);
    return b;
  }

  static int itemValue(int level) => unitCoins * (1 << (level - 1));

  /// Lv n objenin Lv1 cinsinden maliyeti (2^(n-1)).
  static int itemCost(int level) => 1 << (level - 1);

  int get emptyCount {
    var n = 0;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == 0 && !isGen(i)) n++;
    }
    return n;
  }

  /// Acik uretici sayisi (uretec yoksa 0). Bolum numarasindan turetilir, kaydedilmez.
  int get producerCount => genCell < 0 ? 0 : MbWorlds.producerCount(chapter);

  /// Acik ureticilerin hucreleri (slot sirasina gore).
  List<int> get genCells => [for (var s = 0; s < producerCount; s++) MbWorlds.producerCells[s]];

  bool isGen(int i) => genCell >= 0 && i >= 0 && producerCount > 0 && genCells.contains(i);

  /// [i] hucresi hangi ureticinin (slot) hucresi? Uretici degilse -1.
  int genSlotOf(int i) => isGen(i) ? MbWorlds.producerCells.indexOf(i) : -1;

  bool get isFull => emptyCount == 0;

  /// Bos hucreye obje koyar. Dondurur: hucre indeksi, tahta doluysa -1.
  /// [near] true ise (ve uretec varsa) uretece EN YAKIN birkac bos hucreden biri secilir:
  /// objeler uretecin etrafina dagilir (videodaki gibi). Aksi halde tum bos hucreler arasindan rastgele.
  int spawn(math.Random rng, {int? forceLevel, bool near = false, int slot = 0, int bonusPct = 0}) {
    final empty = <int>[];
    for (var i = 0; i < size; i++) {
      if (cells[i] == 0 && !isGen(i)) empty.add(i);
    }
    if (empty.isEmpty) return -1;
    final sl = slot.clamp(0, MbWorlds.producerCells.length - 1).toInt();
    final pc = MbWorlds.producerCells[sl];
    var idx = empty[rng.nextInt(empty.length)];
    if (near && genCell >= 0) {
      final gr = pc ~/ cols;
      final gc = pc % cols;
      double score(int i) {
        final dr = (i ~/ cols - gr).abs();
        final dc = (i % cols - gc).abs();
        // Oklid benzeri mesafe + kucuk rastgelelik: ayni uzaklikta olanlar karissin.
        return math.sqrt((dr * dr + dc * dc).toDouble()) + rng.nextDouble() * 0.9;
      }

      final scored = <MapEntry<int, double>>[for (final i in empty) MapEntry(i, score(i))]
        ..sort((a, b) => a.value.compareTo(b.value));
      final pool = math.min(scored.length, 5);
      idx = scored[rng.nextInt(pool)].key;
    }
    cells[idx] = enc(sl, forceLevel ?? chapterCfg.rollSpawn(rng, bonusPct: bonusPct));
    return idx;
  }

  /// [from] hucresindeki objeyi [to] hucresine birakir.
  ///  * hedef bos  -> tasi
  ///  * ayni seviye (max degil) -> birlestir (hedefte bir ust seviye)
  ///  * farkli -> yer degistir
  MbMove move(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= size || to >= size) return MbMove.none;
    if (isGen(from) || isGen(to)) return MbMove.none; // uretici hucreleri sabit
    final a = cells[from];
    final b = cells[to];
    if (a == 0) return MbMove.none;
    if (b == 0) {
      cells[to] = a;
      cells[from] = 0;
      return MbMove.moved;
    }
    if (a == b && lv(a) < maxLevel) {
      cells[to] = a + 1;
      cells[from] = 0;
      return MbMove.merged;
    }
    cells[to] = a;
    cells[from] = b;
    return MbMove.swapped;
  }

  bool canDeliver(int cellIndex, int orderIndex) {
    if (cellIndex < 0 || cellIndex >= size) return false;
    if (orderIndex < 0 || orderIndex >= orders.length) return false;
    final lvl = cells[cellIndex];
    return lvl > 0 && orders[orderIndex].slotFor(lvl) >= 0;
  }

  /// Hucredeki objeyi siparise teslim eder.
  MbDeliverResult deliver(int cellIndex, int orderIndex, math.Random rng) {
    if (!canDeliver(cellIndex, orderIndex)) return MbDeliverResult.rejected;
    final order = orders[orderIndex];
    final slot = order.slotFor(cells[cellIndex]);
    order.filled[slot] = true;
    cells[cellIndex] = 0;
    if (!order.complete) return const MbDeliverResult(true, false, 0);
    orders.removeAt(orderIndex);
    delivered++;
    chapterProgress++;
    final cfg = chapterCfg;
    var chapterDone = false;
    var bonus = 0;
    var newProducer = false;
    if (chapterProgress >= cfg.goal) {
      chapterDone = true;
      bonus = cfg.completionBonus;
      final countBefore = producerCount;
      final oldWorld = MbState.worldOfChapter(cfg.number);
      chapter++;
      chapterProgress = 0;
      final newWorld = MbState.worldOfChapter(chapter);
      if (genCell >= 0) {
        // Yeni dunya: tahtadaki objeler yeni dunyanin zincir/slot sirasina cevrilir (kayip yok).
        if (newWorld != oldWorld) remapWorld(oldWorld, newWorld);
        syncProducers(); // yeni acilan uretici hucresindeki obje kenara tasinir
        newProducer = newWorld == oldWorld && producerCount > countBefore;
      }
      // Yeni bolumun kurali gecerli olsun: henuz dokunulmamis siparisleri yenile.
      orders.removeWhere((o) => !o.filled.any((f) => f));
    }
    refillOrders(rng);
    return MbDeliverResult(
      true,
      true,
      order.reward,
      chapterCompleted: chapterDone,
      chapterBonus: bonus,
      finishedChapter: cfg.number,
      energyBonus: cfg.energyPerOrder,
      newProducer: newProducer,
    );
  }

  /// Dunya degisince objeleri ve (yarim) siparisleri yeni dunyanin slot sirasina cevirir:
  /// eski zincir yeni dunyada da varsa onun slotuna, yoksa ANA zincirin ayni seviyesine doner
  /// (oyuncu hicbir sey kaybetmez). Henuz acilmamis ureticinin zincirini isteyen yarim siparis de
  /// ana zincire cevrilir: boylece siparis hicbir zaman karsilanamaz kalmaz.
  void remapWorld(int oldWorld, int newWorld) {
    final oldC = MbWorlds.chainsOf(oldWorld);
    final newC = MbWorlds.chainsOf(newWorld);
    int map(int v, {required bool forOrder}) {
      if (v <= 0) return v;
      final s = slotOf(v);
      final chain = oldC[s < oldC.length ? s : 0];
      final i = newC.indexOf(chain);
      var ns = i >= 0 ? i : 0;
      if (forOrder && ns >= producerCount) ns = 0;
      return enc(ns, lv(v));
    }

    for (var i = 0; i < cells.length; i++) {
      cells[i] = map(cells[i], forOrder: false);
    }
    for (final o in orders) {
      for (var k = 0; k < o.levels.length; k++) {
        o.levels[k] = map(o.levels[k], forOrder: true);
      }
    }
  }

  /// Acik olmayan ureticiyi isteyen siparis kalemleri ana zincire doner (kayit/guncelleme guvenligi).
  void _clampOrderSlots() {
    final n = math.max(1, producerCount);
    for (final o in orders) {
      for (var k = 0; k < o.levels.length; k++) {
        if (slotOf(o.levels[k]) >= n) o.levels[k] = enc(0, lv(o.levels[k]));
      }
    }
  }

  void refillOrders(math.Random rng) {
    final needed = chapterCfg.goal - chapterProgress;
    final target = math.min(orderSlots, math.max(1, needed));
    // Bolumun sonunda kalan siparisten fazlasi gosterilmez (dokunulmamis olanlar atilir).
    while (orders.length > target && !orders.last.filled.any((f) => f)) {
      orders.removeLast();
    }
    while (orders.length < target) {
      orders.add(_newOrder(rng));
    }
  }

  MbOrder _newOrder(math.Random rng) {
    final cfg = chapterCfg;
    final hi = cfg.maxLevel;
    final lo = cfg.minLevel;
    var count = 1;
    if (cfg.singleOnly) {
      count = 1;
    } else if (cfg.minItems >= 2) {
      count = 2;
      if (cfg.number >= 6 && rng.nextInt(100) < 25) count++;
    } else {
      if (rng.nextInt(100) < math.min(70, 25 + (cfg.number - 1) * 4)) count++;
      if (cfg.number >= 4 && rng.nextInt(100) < 30) count++;
    }
    // v185: acik uretici sayisi 1'den fazlaysa kalemler zincirler arasinda KARISIK secilir
    // (ana zincir 2 pay, digerleri 1'er pay). Tek ureticide rastgele sayi tuketilmez.
    final slots = math.max(1, producerCount);
    int pickSlot() {
      if (slots <= 1) return 0;
      var r = rng.nextInt(slots + 1);
      if (r < 2) return 0;
      return r - 1;
    }

    final levels = <int>[];
    for (var i = 0; i < count; i++) {
      int l;
      if (cfg.rareTop && hi > lo) {
        l = rng.nextInt(100) < 15 ? hi : lo + rng.nextInt(hi - lo);
      } else {
        l = lo + rng.nextInt(hi - lo + 1);
      }
      levels.add(enc(pickSlot(), l));
    }
    levels.sort();
    int cost() {
      var s = 0;
      for (final l in levels) {
        s += itemCost(lv(l));
      }
      return s;
    }

    final minKeep = cfg.minItems;
    while (levels.length > minKeep && cost() > maxOrderCost) {
      var hiIdx = 0;
      for (var i = 1; i < levels.length; i++) {
        if (lv(levels[i]) >= lv(levels[hiIdx])) hiIdx = i;
      }
      levels.removeAt(hiIdx); // en yuksek seviyeli kalemi at
    }
    var sum = 0;
    for (final l in levels) {
      sum += itemValue(lv(l));
    }
    final base = levels.length > 1 ? sum * 1.2 : sum.toDouble();
    final reward = (base * cfg.rewardPercent / 100).round();
    return MbOrder(id: nextOrderId++, levels: levels, reward: reward);
  }

  Map<String, dynamic> toJson() => {
        'c': cells,
        'o': [for (final o in orders) o.toJson()],
        'd': delivered,
        'n': nextOrderId,
        'ch': chapter,
        'cp': chapterProgress,
      };

  /// Bozuk/eksik kayitta [rng] ile yeni tahta doner.
  static MbBoard fromJson(Object? j, math.Random rng) {
    if (j is! Map) return MbBoard.fresh(rng);
    final c = j['c'];
    if (c is! List || c.length != size) return MbBoard.fresh(rng);
    final cells = <int>[];
    for (final x in c) {
      if (x is! num) return MbBoard.fresh(rng);
      final xi = x.toInt();
      if (xi < 0 || (xi > 0 && !validItem(xi))) return MbBoard.fresh(rng);
      cells.add(xi);
    }
    final orders = <MbOrder>[];
    final o = j['o'];
    if (o is List) {
      for (final x in o) {
        final m = MbOrder.fromJson(x);
        if (m != null) orders.add(m);
      }
    }
    final delivered = (j['d'] as num?)?.toInt() ?? 0;
    final int? savedChapter = (j['ch'] as num?)?.toInt();
    int chapter = savedChapter ?? 1;
    var progress = (j['cp'] as num?)?.toInt() ?? 0;
    if (savedChapter == null || savedChapter < 1) {
      // Eski kayit (bolum yoktu): toplam teslimi bolumlere dagit.
      chapter = 1;
      progress = delivered;
      while (progress >= MbChapter.of(chapter).goal) {
        progress -= MbChapter.of(chapter).goal;
        chapter++;
      }
    }
    final goal = MbChapter.of(chapter).goal;
    if (progress < 0) progress = 0;
    if (progress >= goal) progress = goal - 1;
    final b = MbBoard(
      cells: cells,
      orders: orders,
      delivered: delivered,
      nextOrderId: (j['n'] as num?)?.toInt() ?? 1,
      chapter: chapter,
      chapterProgress: progress,
    );
    b.genCell = generatorCell;
    b.syncProducers();
    b._clampOrderSlots();
    b.refillOrders(rng);
    return b;
  }

  /// Acik uretici hucrelerinde duran obje varsa en yakin bos hucreye tasir
  /// (tahta tamamen doluysa obje, uretici icin feda edilir: nadir).
  void syncProducers() {
    if (genCell < 0) return;
    for (final g in genCells) {
      _relocateFrom(g);
    }
  }

  void _relocateFrom(int g) {
    if (g < 0 || g >= size || cells[g] == 0) return;
    final v = cells[g];
    cells[g] = 0;
    int? best;
    var bestD = 1 << 30;
    for (var i = 0; i < size; i++) {
      if (isGen(i) || cells[i] != 0) continue;
      final d = (i ~/ cols - g ~/ cols).abs() + (i % cols - g % cols).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best != null) cells[best] = v;
  }
}

/// Spawn sonucu (MbState.trySpawn).
enum MbSpawnResult { ok, noEnergy, full }

/// Mucevherle enerji paketi satin alma sonucu (MergeBoardService.buyEnergyPack).
enum MbBuyResult { ok, noGems, full }

/// Uretici yukseltme sonucu (MergeBoardService.upgradeProducer).
enum MbUpgradeResult { ok, noCoins, maxed }

/// Tum mod 2 durumu: TEK tahta + TEK bolum ilerlemesi + enerji.
/// Tema (dunya) bolum numarasindan gelir: her [chaptersPerWorld] bolumde bir
/// sonraki tema (Fast Food -> Kafe -> Buyu -> Korsan -> Buz -> Uzay -> basa).
class MbState {
  static const int worlds = 6;
  static const int chaptersPerWorld = 8;
  // v159: benzer merge oyunlarina gore (Merge Mansion/Gossip Harbor: bar 100, 1 ⚡/2 dk;
  // Longleaf Valley: bar 200, 1 ⚡/90 sn; Merge Family: reklam basina 25 ⚡) yeniden olculdu.
  // Bu oyunda siparis basina obje az -> ayni ⚡ ile daha hizli ilerlenir; bu yuzden dolum
  // rakiplerden (1 ⚡/2 dk) hizli degil, onlarla Longleaf (90 sn) arasinda tutuldu: 90 sn.
  static const int maxEnergy = 100;
  static const int energyCap = 200; // reklamla maxEnergy ustune cikabilir
  static const int regenSeconds = 90;
  static const int adEnergy = 25;
  static const int saveVersion = 3; // v3: enerji cubugu 20 -> 100
  static const int refillGemCost = 100; // elmasla tam dolum (reklam +25 ⚡ ayri secenek)
  // v184: "Daha Fazla Enerji?" penceresindeki paket: gemPackCost 💎 -> gemPackEnergy ⚡ (energyCap'e kadar).
  static const int gemPackEnergy = 100;
  static const int gemPackCost = 10;

  final MbBoard board;
  int energy;

  /// Enerji maksimumun altina ilk dustugu an (ms, epoch). 0 = dolum yok.
  int regenStartMs;

  /// Son spawn edilen hucre (arayuz animasyonu icin, kaydedilmez).
  int lastSpawnIndex = -1;

  /// Son dokunus enerji harcamadi mi (uretici seviyesinden gelen bedava dokunus; kaydedilmez).
  bool lastSpawnFree = false;

  /// Zincir (tema indeksi 0..5) basina uretici seviyesi 1..MbWorlds.maxProducerLevel. KALICI; dunyalar arasi tasinir.
  final List<int> producerLevels;

  MbState({required this.board, this.energy = maxEnergy, this.regenStartMs = 0, List<int>? producerLevels})
      : producerLevels = _fixLevels(producerLevels);

  static List<int> _fixLevels(List<int>? src) {
    final out = List<int>.filled(worlds, 1);
    if (src != null) {
      for (var i = 0; i < worlds && i < src.length; i++) {
        out[i] = src[i].clamp(1, MbWorlds.maxProducerLevel).toInt();
      }
    }
    return out;
  }

  int producerLevel(int chain) => producerLevels[chain.clamp(0, worlds - 1).toInt()];

  /// Bu dunyada [slot] siradaki ureticinin zinciri (tema indeksi).
  int chainOfSlot(int slot) => MbWorlds.chainOf(worldIndex, slot);

  /// Zincirin ureticisini bir seviye yukseltir (coin dusmek servisin isi). Tavandaysa false.
  bool bumpProducer(int chain) {
    final c = chain.clamp(0, worlds - 1).toInt();
    if (producerLevels[c] >= MbWorlds.maxProducerLevel) return false;
    producerLevels[c]++;
    return true;
  }

  factory MbState.fresh(math.Random rng) => MbState(board: MbBoard.fresh(rng));

  /// Bolum numarasinin ait oldugu tema/dunya indeksi (0..5).
  static int worldOfChapter(int chapter) => ((math.max(1, chapter) - 1) ~/ chaptersPerWorld) % worlds;

  int get worldIndex => worldOfChapter(board.chapter);

  void regen(int nowMs) {
    if (energy >= maxEnergy) {
      regenStartMs = 0;
      return;
    }
    if (regenStartMs == 0 || regenStartMs > nowMs) {
      regenStartMs = nowMs;
      return;
    }
    final gained = (nowMs - regenStartMs) ~/ (regenSeconds * 1000);
    if (gained <= 0) return;
    energy = math.min(maxEnergy, energy + gained);
    regenStartMs = energy >= maxEnergy ? 0 : regenStartMs + gained * regenSeconds * 1000;
  }

  /// Bir sonraki enerjiye kalan saniye (enerji doluysa 0).
  int secondsToNext(int nowMs) {
    regen(nowMs);
    if (energy >= maxEnergy) return 0;
    final left = regenSeconds - ((nowMs - regenStartMs) ~/ 1000);
    return left.clamp(0, regenSeconds).toInt();
  }

  bool _spendEnergy(int nowMs) {
    regen(nowMs);
    if (energy <= 0) return false;
    if (energy == maxEnergy) regenStartMs = nowMs;
    energy--;
    return true;
  }

  void addEnergy(int n) {
    energy = math.min(energyCap, energy + n);
  }

  /// Elmasla tam dolum: bar dolu/ustundeyse false (hicbir sey degismez).
  bool refillFull(int nowMs) {
    regen(nowMs);
    if (energy >= maxEnergy) return false;
    energy = maxEnergy;
    regenStartMs = 0;
    return true;
  }

  /// Ureteci dokunus: tahta doluysa enerji HARCAMAZ.
  MbSpawnResult trySpawn(math.Random rng, int nowMs, {int slot = 0}) {
    if (board.isFull) return MbSpawnResult.full;
    final level = producerLevel(chainOfSlot(slot));
    final freePct = MbWorlds.freeTapPct(level);
    regen(nowMs);
    // Uretici seviyesi: bazi dokunuslar enerji harcamaz (enerji varken; sifirsa yine "enerji yok").
    final free = freePct > 0 && energy > 0 && rng.nextInt(100) < freePct;
    if (!free && !_spendEnergy(nowMs)) return MbSpawnResult.noEnergy;
    lastSpawnFree = free;
    lastSpawnIndex = board.spawn(rng, near: true, slot: slot, bonusPct: MbWorlds.bonusPct(level));
    return MbSpawnResult.ok;
  }

  Map<String, dynamic> toJson() => {
        'v': saveVersion,
        'e': energy,
        'rs': regenStartMs,
        'b': board.toJson(),
        'pl': producerLevels,
      };

  static MbState fromJson(Object? j, math.Random rng) {
    if (j is! Map) return MbState.fresh(rng);
    final raw = j['b'];
    MbBoard board;
    if (raw is List) {
      // ESKI KAYIT (6 ayri dunya tahtasi): en ileri olan tahtayi tek tahta olarak al.
      MbBoard? best;
      for (final r in raw) {
        final b = MbBoard.fromJson(r, rng);
        if (best == null ||
            b.chapter > best.chapter ||
            (b.chapter == best.chapter && b.chapterProgress > best.chapterProgress) ||
            (b.chapter == best.chapter && b.chapterProgress == best.chapterProgress && b.delivered > best.delivered)) {
          best = b;
        }
      }
      board = best ?? MbBoard.fresh(rng);
    } else {
      board = MbBoard.fromJson(raw, rng);
    }
    final ver = (j['v'] as num?)?.toInt() ?? 1;
    var energy = ((j['e'] as num?)?.toInt() ?? maxEnergy).clamp(0, energyCap).toInt();
    var regenStart = (j['rs'] as num?)?.toInt() ?? 0;
    if (ver < saveVersion) {
      // Eski kayit (cubuk 20'ydi): yeni cubuk icin bir kerelik tam dolum.
      energy = math.max(energy, maxEnergy);
      regenStart = 0;
    }
    final pl = j['pl'];
    return MbState(
      board: board,
      energy: energy,
      regenStartMs: regenStart,
      producerLevels: pl is List ? [for (final x in pl) x is num ? x.toInt() : 1] : null,
    );
  }
}
