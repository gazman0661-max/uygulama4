import 'game_theme.dart' show ChapterConfig, ChapterKind, ChapterVariant;

/// Bolum zorluk seviyesi etiketi (HUD'da ve bolum basinda gosterilir).
enum ChapterTier { easy, medium, hard }

/// BOLUM DEGISTIRICILERI (v152)
///
/// Amac: 9. bolumden sonra her bolum ayni hissettirmesin.
///  1) ZORLUK DALGASI: normal bolumler 8'lik blok icinde  M E M H M H E M  desenine gore
///     orta / kolay / zor olur (rahat ve boss bolumleri kendi turunu korur). Plato yerine dalga.
///  2) TEMA KURALI: her 8'lik dunya blogunun kendine ozgu bir kurali var (3-8. bolumlerde).
///  3) MUTATOR: blok basina bir bolum (4.; boss ise 3.) tek seferlik ozel kural tasir.
///  4) BOSS KISILIGI: her boss farkli bir tehlike getirir (saatci, bombaci, buz cadisi, duvarci).
///  5) TUR (lap): 6 dunya bitince (49. bolum) kurallar bir kademe sertlesir; sonsuza kadar duz gitmez.
///
/// Saf Dart (UI yok). Yalnizca ChapterConfig.kindFor ve sabit kapilari (bomba 11, buz 21, engel 31,
/// joker 41) kullanir; ChapterConfig getter'lari sonucu uygular, kapilar korunur.
class ChapterMods {
  const ChapterMods({
    this.tier = ChapterTier.medium,
    this.ruleEn = '',
    this.timeMul = 1.0,
    this.goalMul = 1.0,
    this.coinMul = 1.0,
    this.bombMul = 1.0,
    this.wildMul = 1.0,
    this.lv3Add = 0.0,
    this.floorDelta = 0,
    this.frozenAdd = 0,
    this.obstacleAdd = 0,
    this.penaltyFreezeAdd = 0,
  });

  final ChapterTier tier;
  /// Ingilizce kural aciklamasi (AppStrings.lt anahtari). Bos = kural yok.
  final String ruleEn;
  final double timeMul; // siparis suresi carpani (<1 = daha kisa)
  final double goalMul; // siparis sayisi carpani (sadece normal bolum)
  final double coinMul; // bolum coin carpani
  final double bombMul;
  final double wildMul;
  final double lv3Add; // siradaki Lv3 top olasiligina ek
  final int floorDelta; // siparis en dusuk seviyesine ek (+ zor, - kolay)
  final int frozenAdd;
  final int obstacleAdd;
  final int penaltyFreezeAdd;

  static const ChapterMods none = ChapterMods();

  /// Ilk 8 bolum (ogretici + ilk dunya) dokunulmaz.
  static const int firstModChapter = 9;
  static const int firstMutatorChapter = 12;

  bool get isNeutral => tier == ChapterTier.medium && ruleEn.isEmpty;

  String get tierEmoji => switch (tier) {
        ChapterTier.easy => '🟢 ',
        ChapterTier.medium => '',
        ChapterTier.hard => '🔥 ',
      };

  /// AppStrings.lt anahtari (Ingilizce).
  String get tierEn => switch (tier) {
        ChapterTier.easy => '🟢 EASY',
        ChapterTier.medium => '⚔️ MEDIUM',
        ChapterTier.hard => '🔥 HARD',
      };

  ChapterMods combine(ChapterMods o) => ChapterMods(
        tier: tier,
        ruleEn: o.ruleEn.isNotEmpty ? o.ruleEn : ruleEn,
        timeMul: timeMul * o.timeMul,
        goalMul: goalMul * o.goalMul,
        coinMul: coinMul * o.coinMul,
        bombMul: bombMul * o.bombMul,
        wildMul: wildMul * o.wildMul,
        lv3Add: lv3Add + o.lv3Add,
        floorDelta: floorDelta + o.floorDelta,
        frozenAdd: frozenAdd + o.frozenAdd,
        obstacleAdd: obstacleAdd + o.obstacleAdd,
        penaltyFreezeAdd: penaltyFreezeAdd + o.penaltyFreezeAdd,
      );

  // Blok ici desen (1..8): M E M H M H E M
  static const List<ChapterTier> _pattern = [
    ChapterTier.medium,
    ChapterTier.easy,
    ChapterTier.medium,
    ChapterTier.hard,
    ChapterTier.medium,
    ChapterTier.hard,
    ChapterTier.easy,
    ChapterTier.medium,
  ];

  static final Map<int, ChapterMods> _cache = {};

  static ChapterMods forChapter(int ch) {
    if (ch < firstModChapter) return none;
    return _cache.putIfAbsent(ch, () => _build(ch));
  }

  static ChapterMods _build(int ch) {
    final kind = ChapterConfig.kindFor(ch);
    final block = (ch - 1) ~/ ChapterConfig.chaptersPerThemeBlock;
    final pos = (ch - 1) % ChapterConfig.chaptersPerThemeBlock + 1; // 1..8
    final lap = block ~/ 6; // 0: ilk tur, 1: 49. bolumden sonra...
    final theme = block % 6;

    if (kind == ChapterKind.easy) return const ChapterMods(tier: ChapterTier.easy);
    if (kind == ChapterKind.boss) {
      return const ChapterMods(tier: ChapterTier.hard).combine(_boss(ch));
    }

    // v153: zamanli / sinirli atisli bolum zaten ozel zorluk tasir -> ustune zorluk dalgasi
    // (zor etiketi), mutator ve (zamanli ise) sureyi kisaltan tema kurali BINDIRILMEZ.
    final variant = ChapterConfig.variantFor(ch);
    var m = _tierMods(variant == ChapterVariant.none ? _pattern[pos - 1] : ChapterTier.medium, ch, lap);
    if (isMutatorChapter(ch)) {
      m = m.combine(_mutator(ch, block));
    } else if (pos >= 3) {
      final rule = _blockRule(theme, lap);
      final clashes = variant == ChapterVariant.timed && rule.timeMul != 1.0;
      if (!clashes) m = m.combine(rule);
    }
    return m;
  }

  /// Bir bloktaki mutator bolumu (yoksa 0). Aday: blok icinde 4. bolum (boss ise bir onceki);
  /// aday zamanli/sinirli atisli ise siradaki uygun bolume kayar (tek tek: +1, -1, +2).
  static int mutatorChapterOfBlock(int block) {
    final b0 = block * ChapterConfig.chaptersPerThemeBlock + 1;
    var base = b0 + 3;
    if (ChapterConfig.kindFor(base) == ChapterKind.boss) base -= 1;
    for (final ch in [base, base + 1, base - 1, base + 2]) {
      if (ch < b0 || ch > b0 + ChapterConfig.chaptersPerThemeBlock - 1) continue;
      if (ch < firstMutatorChapter) continue;
      if (ChapterConfig.kindFor(ch) != ChapterKind.normal) continue;
      if (ChapterConfig.variantFor(ch) != ChapterVariant.none) continue;
      return ch;
    }
    return 0;
  }

  static bool isMutatorChapter(int ch) {
    if (ch < firstMutatorChapter) return false;
    final block = (ch - 1) ~/ ChapterConfig.chaptersPerThemeBlock;
    return mutatorChapterOfBlock(block) == ch;
  }

  static ChapterMods _tierMods(ChapterTier t, int ch, int lap) {
    final lb = lap > 3 ? 3 : lap;
    switch (t) {
      case ChapterTier.easy:
        return const ChapterMods(
            tier: ChapterTier.easy, floorDelta: -1, timeMul: 1.2, lv3Add: -0.05, coinMul: 0.85);
      case ChapterTier.medium:
        return ChapterMods(tier: ChapterTier.medium, timeMul: 1.0 - 0.04 * lb);
      case ChapterTier.hard:
        return ChapterMods(
          tier: ChapterTier.hard,
          floorDelta: ch >= 11 ? 1 : 0,
          timeMul: 0.9 * (1.0 - 0.04 * lb),
          lv3Add: 0.05 + 0.02 * lb,
          coinMul: 1.15,
        );
    }
  }

  // ── TEMA (BLOK) KURALLARI ───────────────────────────────────
  static ChapterMods _blockRule(int theme, int lap) {
    switch (theme) {
      case 0: // Fast Food (yalniz 2. turdan itibaren; ilk tur 1-8 dokunulmaz)
        return const ChapterMods(ruleEn: '🍔 Rush hour: orders expire faster', timeMul: 0.85);
      case 1: // Kafe
        return const ChapterMods(ruleEn: '☕ Fast service: less time per order', timeMul: 0.8);
      case 2: // Buyu & Simya
        return const ChapterMods(ruleEn: '🧪 Potion fumes: more mid-size items', lv3Add: 0.08);
      case 3: // Korsan
        return ChapterMods(ruleEn: '💣 Cannon fire: bombs everywhere', bombMul: 2.0 + 0.25 * lap);
      case 4: // Buz
        return ChapterMods(ruleEn: '🧊 Deep freeze: more frozen items', frozenAdd: 2 + lap);
      default: // Uzay
        return ChapterMods(
            ruleEn: '☄️ Meteor belt: extra obstacles, extra wilds', obstacleAdd: 1 + lap ~/ 2, wildMul: 2.0);
    }
  }

  // ── MUTATOR (blok basina tek bolum) ─────────────────────────
  static ChapterMods _mutator(int ch, int block) {
    final list = <ChapterMods>[
      const ChapterMods(ruleEn: '⚡ Rush: orders expire much faster', timeMul: 0.7, coinMul: 1.15),
      const ChapterMods(
          ruleEn: '🐘 Big orders: fewer, but higher level', goalMul: 0.7, floorDelta: 1, coinMul: 1.1),
      const ChapterMods(ruleEn: '💣 Bomb night: bombs galore', bombMul: 3.0, coinMul: 1.1),
      const ChapterMods(ruleEn: '📦 Overstock: the table clutters up', lv3Add: 0.15, coinMul: 1.1),
      if (ch >= ChapterConfig.frozenStartChapter)
        const ChapterMods(ruleEn: '🧊 Frostbite: extra frozen items', frozenAdd: 2, coinMul: 1.1),
      if (ch >= ChapterConfig.obstacleStartChapter)
        const ChapterMods(ruleEn: '🧱 Barricade: extra obstacles', obstacleAdd: 2, coinMul: 1.1),
      if (ch >= ChapterConfig.wildStartChapter)
        const ChapterMods(ruleEn: '🍩 Wild rain: lots of jokers!', wildMul: 4.0, coinMul: 0.9),
    ];
    return list[(block - 1) % list.length];
  }

  // ── BOSS KISILIKLERI ────────────────────────────────────────
  static ChapterMods _boss(int ch) {
    final list = <ChapterMods>[
      const ChapterMods(ruleEn: '⏱️ Boss: the Clockmaker — orders are tightly timed', timeMul: 0.75),
      if (ch >= ChapterConfig.bombStartChapter)
        const ChapterMods(ruleEn: '💣 Boss: the Bomber — bombs rain down', bombMul: 3.5),
      if (ch >= ChapterConfig.frozenStartChapter)
        const ChapterMods(
            ruleEn: '🧊 Boss: the Ice Witch — freezing everywhere', frozenAdd: 3, penaltyFreezeAdd: 1),
      if (ch >= ChapterConfig.obstacleStartChapter)
        const ChapterMods(ruleEn: '🧱 Boss: the Mason — walls everywhere', obstacleAdd: 3),
    ];
    final idx = (ch ~/ 10 - 1) % list.length;
    return list[idx < 0 ? 0 : idx];
  }
}
