import '../services/remote_tuning.dart';
import 'chapter_mods.dart';
import 'package:flutter/material.dart';
import 'food_item.dart';
import 'cafe_item.dart';
import 'magic_item.dart';
import 'pirate_item.dart';
import 'ice_item.dart';
import 'space_item.dart';
import '../localization/app_strings.dart';

enum ChapterKind { normal, easy, boss }

/// ZORLU BOLUM TURU (v123): sadece normal bolumlerde, "at-birlestir-teslim et" ritmini bozar.
/// limitedShots: atis sayisi sinirli. timed: tum bolum icin geri sayim.
enum ChapterVariant { none, limitedShots, timed }

/// TÜM objelerin (fizik, çizim, nişan) boyut çarpanı - tek merkezi ayar.
///
/// Referans videoda (Mystery Town) bir obje, masa genişliğinin yalnızca
/// ~%6-9'u kadar; masanın uzak ucuna yan yana ~12-17 obje sığıyor ve yığın
/// bu yüzden masanın tüm genişliğine YAYILIP uzak duvarın dibinde
/// (masa boyunun ~%25'i kadar derinlikte) toplanıyor. Eski boyutlarda
/// (yarıçap 20..69 dp, çap masa uzak genişliğinin %17..%58'i) aynı masaya
/// 3-5 obje sığıyordu: yığın uzak duvara yaslanmak yerine masanın ortasına
/// (~%50'sine) kadar uzuyordu. 0.62 ile Python simülasyonunda yığın
/// derinliği referansla aynı (~%26) çıkıyor; 0.78 ile ~%33 (v66: bir tık daha büyük; 0.70 ~%30, hâlâ videoya yakın). Objeler çok küçük gelirse
/// 0.70-0.75'e çıkar, tam eski boyut için 1.0 yap.
const double kBallSizeScale = 0.88; // v93: 0.78 -> 0.88 (oyun cok kolay gelince objeler biraz buyutuldu; masa daha cabuk dolar)

/// GameBoard'un hangi temayı kullanacağını tanımlayan soyut arayüz.
/// FoodTiers, CafeTiers, MagicTiers, PirateTiers, IceTiers ve SpaceTiers bu
/// arayüzü sağlayan wrapper'larla sarılır, GameBoard kodu değişmeden tüm
/// temaları çalıştırabilir.
abstract class GameTheme {
  int get maxLevel;
  String get tableImagePath;
  double get imageWidth;   // masa PNG/JPG'nin gerçek pixel genişliği
  // Masa yuzeyinin (oynanabilir alan) gorsel uzerindeki GERCEK sol/sag kenari, px (768x1376 gorsel).
  // y=400 (ust) ve y=1110 (alt) icin; her dunyanin masasi farkli oldugundan temaya ozel olculdu.
  double get tableTopLeftX;
  double get tableBottomLeftX;
  double get tableTopRightX;
  double get tableBottomRightX;
  double get imageHeight;  // masa PNG/JPG'nin gerçek pixel yüksekliği
  String get themeName;    // "Kafe & Pastane" gibi görünen isim (TR sabit - eski cagrilar icin)
  String get themeNameKey; // AppStrings.t() ile cevrilecek anahtar

  TierInfo byLevel(int level);
}

/// Tek bir obje seviyesinin veri paketi - GameBoard bu yapıyla çalışır.
class TierInfo {
  final int level;
  final String name;
  final String emoji;
  final Color color;
  final int coinReward;
  final String imagePath;
  final double radius;

  const TierInfo({
    required this.level,
    required this.name,
    required this.emoji,
    required this.color,
    required this.coinReward,
    required this.imagePath,
    required this.radius,
  });
}

// ──────────────────────────────────────────────────────
// Tema 1: Fast Food Dükkanı
// ──────────────────────────────────────────────────────
class FastFoodTheme implements GameTheme {
  const FastFoodTheme();
  @override int get maxLevel => FoodTiers.maxLevel;
  @override String get tableImagePath => 'assets/images/table_background.jpg';
  @override double get imageWidth => 768;
  @override double get imageHeight => 1376;
  @override double get tableTopLeftX => 175;
  @override double get tableBottomLeftX => 55;
  @override double get tableTopRightX => 612;
  @override double get tableBottomRightX => 730;
  @override String get themeName => 'Fast Food Dükkanı';
  @override String get themeNameKey => 'theme_fastfood';
  @override TierInfo byLevel(int level) {
    final t = FoodTiers.byLevel(level);
    return TierInfo(level: t.level, name: t.name, emoji: t.emoji, color: t.color,
        coinReward: t.coinReward, imagePath: t.imagePath, radius: t.radius * kBallSizeScale);
  }
}

// ──────────────────────────────────────────────────────
// Tema 2: Kafe & Pastane
// ──────────────────────────────────────────────────────
class CafeTheme implements GameTheme {
  const CafeTheme();
  @override int get maxLevel => CafeTiers.maxLevel;
  @override String get tableImagePath => CafeTiers.tableImagePath;
  @override double get imageWidth => 768;
  @override double get imageHeight => 1376;
  @override double get tableTopLeftX => 175;
  @override double get tableBottomLeftX => 55;
  @override double get tableTopRightX => 612;
  @override double get tableBottomRightX => 730;
  @override String get themeName => 'Kafe & Pastane';
  @override String get themeNameKey => 'theme_cafe';
  @override TierInfo byLevel(int level) {
    final t = CafeTiers.byLevel(level);
    return TierInfo(level: t.level, name: t.name, emoji: t.emoji, color: t.color,
        coinReward: t.coinReward, imagePath: t.imagePath, radius: t.radius * kBallSizeScale);
  }
}

// ──────────────────────────────────────────────────────
// Tema 3: Büyü & Simya
// ──────────────────────────────────────────────────────
class MagicTheme implements GameTheme {
  const MagicTheme();
  @override int get maxLevel => MagicTiers.maxLevel;
  @override String get tableImagePath => MagicTiers.tableImagePath;
  @override double get imageWidth => 768;
  @override double get imageHeight => 1376;
  @override double get tableTopLeftX => 182;
  @override double get tableBottomLeftX => 62;
  @override double get tableTopRightX => 606;
  @override double get tableBottomRightX => 724;
  @override String get themeName => 'Büyü & Simya';
  @override String get themeNameKey => 'theme_magic';
  @override TierInfo byLevel(int level) {
    final t = MagicTiers.byLevel(level);
    return TierInfo(level: t.level, name: t.name, emoji: t.emoji, color: t.color,
        coinReward: t.coinReward, imagePath: t.imagePath, radius: t.radius * kBallSizeScale);
  }
}

// ──────────────────────────────────────────────────────
// Tema 4: Korsan Hazinesi
// ──────────────────────────────────────────────────────
class PirateTheme implements GameTheme {
  const PirateTheme();
  @override int get maxLevel => PirateTiers.maxLevel;
  @override String get tableImagePath => PirateTiers.tableImagePath;
  @override double get imageWidth => 768;
  @override double get imageHeight => 1376;
  @override double get tableTopLeftX => 182;
  @override double get tableBottomLeftX => 62;
  @override double get tableTopRightX => 606;
  @override double get tableBottomRightX => 724;
  @override String get themeName => 'Korsan Hazinesi';
  @override String get themeNameKey => 'theme_pirate';
  @override TierInfo byLevel(int level) {
    final t = PirateTiers.byLevel(level);
    return TierInfo(level: t.level, name: t.name, emoji: t.emoji, color: t.color,
        coinReward: t.coinReward, imagePath: t.imagePath, radius: t.radius * kBallSizeScale);
  }
}

// ──────────────────────────────────────────────────────
// Tema 5: Buz Krallığı
// ──────────────────────────────────────────────────────
class IceTheme implements GameTheme {
  const IceTheme();
  @override int get maxLevel => IceTiers.maxLevel;
  @override String get tableImagePath => IceTiers.tableImagePath;
  @override double get imageWidth => 768;
  @override double get imageHeight => 1376;
  @override double get tableTopLeftX => 182;
  @override double get tableBottomLeftX => 62;
  @override double get tableTopRightX => 606;
  @override double get tableBottomRightX => 724;
  @override String get themeName => 'Buz Krallığı';
  @override String get themeNameKey => 'theme_ice';
  @override TierInfo byLevel(int level) {
    final t = IceTiers.byLevel(level);
    return TierInfo(level: t.level, name: t.name, emoji: t.emoji, color: t.color,
        coinReward: t.coinReward, imagePath: t.imagePath, radius: t.radius * kBallSizeScale);
  }
}

// ──────────────────────────────────────────────────────
// Tema 6: Uzay İstasyonu
// ──────────────────────────────────────────────────────
class SpaceTheme implements GameTheme {
  const SpaceTheme();
  @override int get maxLevel => SpaceTiers.maxLevel;
  @override String get tableImagePath => SpaceTiers.tableImagePath;
  @override double get imageWidth => 768;
  @override double get imageHeight => 1376;
  @override double get tableTopLeftX => 200;
  @override double get tableBottomLeftX => 78;
  @override double get tableTopRightX => 576;
  @override double get tableBottomRightX => 703;
  @override String get themeName => 'Uzay İstasyonu';
  @override String get themeNameKey => 'theme_space';
  @override TierInfo byLevel(int level) {
    final t = SpaceTiers.byLevel(level);
    return TierInfo(level: t.level, name: t.name, emoji: t.emoji, color: t.color,
        coinReward: t.coinReward, imagePath: t.imagePath, radius: t.radius * kBallSizeScale);
  }
}

// ──────────────────────────────────────────────────────
// Bolum yapilandirmasi: SINIRSIZ ilerleme.
//
// Sabit bir "son bolum" YOK. Oyuncu ne kadar ilerleyebilirse o kadar
// bolum acilir. Elimizdeki 6 tema, 8'er bolumluk bloklar halinde
// sirayla DONER (1-8 Fast Food, 9-16 Kafe, 17-24 Büyü&Simya, 25-32
// Korsan Hazinesi, 33-40 Buz Krallığı, 41-48 Uzay İstasyonu, 49-56
// tekrar Fast Food, ...) -
// yeni bir tema eklendiginde tek yapilacak sey asagidaki themeFor()
// fonksiyonuna bir dal daha eklemek.
//
// Zorluk egrisi de bloklar arasinda SIFIRLANMIYOR: her tam blok
// (8 bolum) tamamlandiginda taban hedef biraz daha yukseliyor, yani
// oyuncu 50. bolume geldiginde 1. bolumdekinden gercekten daha zor
// bir mucadeleyle karsilasiyor.
// ──────────────────────────────────────────────────────
class ChapterConfig {
  ChapterConfig._();

  static const int chaptersPerThemeBlock = 8;

  /// Bolum numarasina gore hangi temanin oynanacagini dondurur.
  /// Su an elde 6 tema var; bloklar bu alti arasinda sonsuza kadar
  /// donuyor. Yeni tema eklenince buraya % 7, % 8 vb. eklenebilir.
  static GameTheme themeFor(int chapterNumber) {
    final block = (chapterNumber - 1) ~/ chaptersPerThemeBlock;
    switch (block % 6) {
      case 0:
        return const FastFoodTheme();
      case 1:
        return const CafeTheme();
      case 2:
        return const MagicTheme();
      case 3:
        return const PirateTheme();
      case 4:
        return const IceTheme();
      default:
        return const SpaceTheme();
    }
  }

  // ──────────────────────────────────────────────────────
  // SABIT BOLUM COIN'I (v125)
  // Bolumun toplam coin'i artik objelerin seviyesine/birlesme sayisina bagli
  // DEGIL; bolum numarasindan gelen KADEMELI SABIT bir degerdir. Oyuncu bu
  // toplami siparis teslim ettikce esit paylarla alir (son siparis kalani
  // tamamlar, toplam her zaman tam tutar).
  //   Bolum 1-5   : 100 -> 300   (+50 / bolum)
  //   Bolum 6-24  : 400 -> 900   (dogrusal)
  //   Bolum 25+   : 1000 (+ lateCoinGrowthPerChapter / bolum, en fazla lateCoinCap; buyumeyi 0 yaparsan tam sabit)
  // Boss x1.5, rahat bolum x0.7, daha once gecilmis bolumu tekrar oynamak x0.25.
  // Tum ekonomi (yukseltme, kasaba, coin paketi, bolge odulu) bu egriye gore ayarli.
  // ──────────────────────────────────────────────────────
  static const double bossCoinMultiplier = 1.5;
  static const double easyCoinMultiplier = 0.7;
  static const double replayCoinFraction = 0.25;
  static const double lateCoinGrowthPerChapter = 0.5;
  static const double lateCoinCap = 1400; // 775. bolumde tavana ulasir; sonsuz bolumde coin enflasyonu olmasin

  /// Normal bir bolumun taban coin'i (10'a yuvarlanir). Boss/rahat/tekrar carpani HARIC.
  static int baseChapterCoins(int chapterNumber) {
    final c = chapterNumber < 1 ? 1 : chapterNumber;
    double v;
    if (c <= 5) {
      v = 100.0 + (c - 1) * 50.0; // 100, 150, 200, 250, 300
    } else if (c <= 24) {
      v = 400.0 + (c - 6) * (500.0 / 18.0); // 400 ... 900
    } else {
      v = 1000.0 + (c - 25) * lateCoinGrowthPerChapter;
      if (v > lateCoinCap) v = lateCoinCap;
    }
    return (v / 10).round() * 10;
  }

  /// Bolumun toplam coin'i (Kasaba/yukseltme bonusu HARIC). [replay]: bolum daha once gecilmisse.
  static int chapterCoinsFor(int chapterNumber, {bool replay = false}) {
    var v = baseChapterCoins(chapterNumber).toDouble();
    switch (kindFor(chapterNumber)) {
      case ChapterKind.boss:
        v *= bossCoinMultiplier;
        break;
      case ChapterKind.easy:
        v *= easyCoinMultiplier;
        break;
      case ChapterKind.normal:
        break;
    }
    v *= ChapterMods.forChapter(chapterNumber).coinMul; // v152: zor bolum biraz fazla, kolay biraz az
    if (replay) v *= replayCoinFraction;
    return v.round();
  }

  /// Siparis kartinda gosterilen ortalama odul (en az 1).
  static int coinPerOrderFor(int chapterNumber, {bool replay = false}) {
    final goal = goalFor(chapterNumber);
    final v = (chapterCoinsFor(chapterNumber, replay: replay) / (goal < 1 ? 1 : goal)).round();
    return v < 1 ? 1 : v;
  }

  /// [deliveredBefore]: bu teslimattan ONCE teslim edilen siparis sayisi (0 tabanli).
  /// Toplam payi birikimli yuvarlar: butun teslimatlarin toplami tam [chapterCoinsFor].
  static int orderPayoutFor(int chapterNumber, int deliveredBefore, {bool replay = false}) {
    final goal = goalFor(chapterNumber);
    final g = goal < 1 ? 1 : goal;
    final total = chapterCoinsFor(chapterNumber, replay: replay);
    var i = deliveredBefore;
    if (i < 0) i = 0;
    if (i > g - 1) i = g - 1;
    return ((total * (i + 1)) / g).round() - ((total * i) / g).round();
  }

  /// Bolum hedefi (kac siparis teslim edilince bolum biter).
  /// Blok icinde 15'ten 50'ye kadar kademeli artar, her yeni blokta
  /// (yeni tema donguye girdiginde) taban +20 yukselir - boylece
  /// egri hicbir zaman duzlesmiyor/sifirlanmiyor.
  static int goalFor(int chapterNumber) {
    final raw = _rawGoalFor(chapterNumber);
    switch (kindFor(chapterNumber)) {
      case ChapterKind.easy:
        return (raw * 0.7).round().clamp(5, 1000).toInt();
      case ChapterKind.boss:
        return (raw * 0.5).round().clamp(5, 1000).toInt();
      case ChapterKind.normal:
        final gm = ChapterMods.forChapter(chapterNumber).goalMul;
        return gm == 1.0 ? raw : (raw * gm).round().clamp(5, 1000).toInt();
    }
  }

  /// ZORLUK DALGASI: her 5. bolum RAHAT (%70 hedef, kolay siparisler),
  /// her 10. bolum BOSS (yarim hedef ama sadece yuksek seviye siparis,
  /// siparis odulu 2 kat + ilk gecise ekstra odul).
  static ChapterKind kindFor(int chapterNumber) {
    if (chapterNumber >= 5 && chapterNumber % 10 == 0) return ChapterKind.boss;
    if (chapterNumber >= 5 && chapterNumber % 5 == 0) return ChapterKind.easy;
    return ChapterKind.normal;
  }

  // --- ZORLU BOLUM TURLERI (v123) ---
  // Yalnizca ChapterKind.normal bolumlerde (boss/rahat 5'in katlari zaten ozel). Kapatmak: variantsEnabled=false.
  // Sayilar cihazda denenip ayarlanmali: Firebase'e 'variant_*' olaylari yaziliyor (kalan atis/sure).
  static const bool variantsEnabled = true;
  static const int limitedShotsStartChapter = 14; // ilk gorulme: 14. bolum (sonra her 6 bolumde)
  static const int timedStartChapter = 22; // ilk gorulme: 22. bolum (sonra her 6 bolumde)
  static int get shotsPerOrder => RemoteTuning.i('shots_per_order', 15); // sinirli atis: hedef siparis basina atis hakki
  static int get shotsBase => RemoteTuning.i('shots_base', 15); // + sabit pay (20 siparisli bolum: 188 -> 275 atis)
  static int get continueShots => RemoteTuning.i('continue_shots', 150); // devam edince eklenen atis (reklam/elmas)
  static int get secondsPerOrder => RemoteTuning.i('seconds_per_order', 14); // zamanli: hedef siparis basina saniye
  static int get secondsBase => RemoteTuning.i('seconds_base', 30); // + sabit pay
  static int get continueSeconds => RemoteTuning.i('continue_seconds', 30); // devam edince eklenen sure
  static const double variantBonusFraction = 0.2; // tamamlayinca bolum coin'inin bu kadari ekstra

  static ChapterVariant variantFor(int ch) {
    if (!variantsEnabled || kindFor(ch) != ChapterKind.normal) return ChapterVariant.none;
    if (ch >= limitedShotsStartChapter && ch % 6 == 2) return ChapterVariant.limitedShots;
    if (ch >= timedStartChapter && ch % 6 == 4) return ChapterVariant.timed;
    return ChapterVariant.none;
  }

  static int shotLimitFor(int ch) => goalFor(ch) * shotsPerOrder + shotsBase;
  static int timeLimitFor(int ch) => goalFor(ch) * secondsPerOrder + secondsBase;

  static int _rawGoalFor(int chapterNumber) {
    // v149: 1-2 KART DUZENI. Ilk evre (1..slots_early_until) 2 kartla oynanir, siparis sayisi
    // yumusak artar. Sonrasi TEK kart + az ama buyuk (Lv4-5+) siparis: masa dolsun, heyecan artsin.
    if (chapterNumber > earlySlotsUntil) return chapterNumber < 15 ? 8 : 10;
    final posInBlock = ((chapterNumber - 1) % chaptersPerThemeBlock) + 1; // 1-8
    return const [5, 6, 7, 8, 9, 10, 11, 12][posInBlock - 1];
  }

  /// Ayni anda ekranda duran siparis karti sayisi (Ekstra Slot yukseltmesi bunun USTUNE eklenir).
  static int get earlySlotsUntil => RemoteTuning.i('slots_early_until', 8);
  static int baseOrderSlots(int ch) =>
      ch <= earlySlotsUntil ? RemoteTuning.i('slots_early', 2) : RemoteTuning.i('slots_late', 1);

  /// Teslimat ritmi: iki teslimat arasi en az bu kadar ms; slot bosaldiktan sonra yeni siparisin gelme gecikmesi.
  static int get deliveryGapMs => RemoteTuning.i('delivery_gap_ms', 600);
  static int get orderRefillMs => RemoteTuning.i('order_refill_ms', 700);

  /// BASKI (heyecan) katmani: 9. bolumden itibaren devreye girer - ilk 8 bolum
  /// (ogretici + ilk bolge) DOKUNULMAZ, sade kalir. Su dort sey kademeli artar:
  /// siparis suresi, 3. seviye obje atisi, daralan tehlike cizgisi, gerilim efekti.
  /// [pressureT]: 0.0 (9. bolum) -> 1.0 (30. bolum ve sonrasi, plato).
  /// ZORLUK AYARLARI (v135) - oyuncu "reklam / elmas ile devam" a ihtiyac duysun, sikilmasin diye.
  /// Siparis suresi carpani (1.0 = eski sure). Dusurdukce sure kisalir.
  static double get orderTimeScale => RemoteTuning.i('order_time_scale_pct', 85) / 100.0;

  /// Siparis suresi dolunca CEZA: masadaki kac objenin DONDURULACAGI (yaninda bir birlesme olunca cozulur).
  /// Eskiden masaya Lv1 top dusuyordu. 25. bolumden itibaren daha fazla.
  static int expiredPenaltyFreeze(int ch) {
    final base = ch >= RemoteTuning.i('penalty_late_chapter', 25)
        ? RemoteTuning.i('penalty_freeze_late', 2)
        : RemoteTuning.i('penalty_freeze', 1);
    return base + ChapterMods.forChapter(ch).penaltyFreezeAdd;
  }

  /// Sirada Lv3 top gelme olasiligi tavani (eskiden 0.20 = 0.05 + 0.15).
  static double get pressureLv3Max => RemoteTuning.i('pressure_lv3_max_pct', 25) / 100.0;

  static const int pressureStartChapter = 9;
  static double pressureT(int chapterNumber) =>
      ((chapterNumber - pressureStartChapter) / 21).clamp(0.0, 1.0).toDouble();

  /// BOSS YUMUSAK BASLANGIC: ilk boss (bolum 10) hafif, 50. bolumde tam siddet.
  /// 0.0 (bolum 10) -> 1.0 (bolum 50 ve sonrasi).
  static double bossT(int chapterNumber) => ((chapterNumber - 10) / 40).clamp(0.0, 1.0).toDouble();

  /// GEC OYUN (41. bolum sonrasi) cok yavas ek zorluk: eskiden her sey duzlesiyordu.
  /// 0.0 (41. bolum) -> 1.0 (101. bolum ve sonrasi, plato). Siparis suresi en fazla
  /// %20 kisalir, kural siparisi orani +%10 artar. Hedef/sure UZAMAZ.
  static double lateT(int chapterNumber) => ((chapterNumber - 41) / 60).clamp(0.0, 1.0).toDouble();

  /// DOLU MASA (v102): bolum bos masayla degil, azar azar dolu masayla baslar.
  /// [prefillStartChapter]'de ilk top gorunur, [prefillFullChapter]'de masa,
  /// tehlike cizgisine kadar olan alanin [maxPrefill] kadari (~yari) dolu baslar.
  /// Rahat (easy) bolumlerde yarisi. Zorluk egrisini korumak icin:
  ///  * tehlike cizgisi daralmasi ayni oranda gevsetilir (GameBoard._dangerLineFraction),
  ///  * hazir toplar siparise TESLIM EDILMEZ (sadece birlestirilince siparis nesnesi olur),
  ///  * kayiptan sonra tekrar denemede doluluk yariya iner, 2. kayipta sifirlanir.
  // --- OZEL OBJELER VE ENGELLER (v122) ---
  // Her mekanik bir bolumde TANITILIR (ilk gorundugu bolumde garanti cikar + bilgi toast'i), sonra siklasir.
  // Hepsini kapatmak icin specialsEnabled=false. Tanitim bolumleri boss/rahat bolumlere denk gelmesin diye 11/21/31/41.
  static const bool specialsEnabled = true;
  static const int bombStartChapter = 11; // Bomba: yerlesince 3 sn nabiz atip patlar, yakin cevredeki her seyi yok eder
  static const int frozenStartChapter = 21; // Buzlu top: yaninda bir birlesme olunca cozulur
  static const int obstacleStartChapter = 31; // Engel: hareketsiz kasa/varil/kristal/buz blogu
  static const int wildStartChapter = 41; // Joker top: dokundugu topla birlesir (o topun seviyesi +1)

  /// Sirada bomba gelme olasiligi (atis basina): %4 -> bolum 51+ icin %8.
  static double bombChance(int ch) {
    if (ch < bombStartChapter) return 0.0;
    final base = 0.04 + 0.04 * ((ch - bombStartChapter) / 40).clamp(0.0, 1.0).toDouble();
    return (base * ChapterMods.forChapter(ch).bombMul).clamp(0.0, 0.30).toDouble();
  }

  /// Siparislerde istenebilecek EN DUSUK seviye (v130). Kucuk topu hemen teslim etmek masayi bosaltip
  /// zorlugu sifirliyordu: 3+ bolumde Lv1, 8+ Lv1-2, 15+ Lv1-3, 25+ Lv1-4 sipariste cikmaz. Rahat bolumde 1 seviye gevsek.
  static int orderMinLevel(int ch, ChapterKind kind) {
    var f = ch >= RemoteTuning.i('order_floor_ch5', 19)
        ? 5
        : ch >= RemoteTuning.i('order_floor_ch4', 13)
            ? 4
            : ch >= RemoteTuning.i('order_floor_ch3', 9)
                ? 3
                : ch >= RemoteTuning.i('order_floor_ch2', 3)
                    ? 2
                    : 1;
    if (kind == ChapterKind.easy && f > 1) f -= 1;
    f += ChapterMods.forChapter(ch).floorDelta; // v152: kolay -1 / zor +1
    if (f < 1) f = 1;
    if (f > 6) f = 6;
    return f;
  }

  /// Sirada joker top gelme olasiligi (atis basina).
  static double wildChance(int ch) =>
      ch < wildStartChapter ? 0.0 : (0.035 * ChapterMods.forChapter(ch).wildMul).clamp(0.0, 0.20).toDouble();

  /// Bolum basinda masadaki hazir toplardan kac tanesi buzlu baslar (1..4).
  static int frozenCount(int ch) => ch < frozenStartChapter
      ? 0
      : ((1 + (ch - frozenStartChapter) ~/ 12).clamp(1, 4).toInt() + ChapterMods.forChapter(ch).frozenAdd).clamp(1, 6).toInt();

  /// Bolum basinda masaya konan engel sayisi (1..3).
  static int obstacleCount(int ch) => ch < obstacleStartChapter
      ? 0
      : ((1 + (ch - obstacleStartChapter) ~/ 12).clamp(1, 3).toInt() + ChapterMods.forChapter(ch).obstacleAdd).clamp(1, 5).toInt();

  static const bool prefillEnabled = true;
  static const int prefillStartChapter = 3;
  static const int prefillFullChapter = 92;
  static const double maxPrefill = 0.50;

  /// Bolum basinda tehlike cizgisine kadar olan alanin kacta kaci dolu baslar (0..maxPrefill).
  static double prefillFraction(int chapterNumber) {
    if (!prefillEnabled || chapterNumber < prefillStartChapter) return 0.0;
    final t = ((chapterNumber - prefillStartChapter + 1) / (prefillFullChapter - prefillStartChapter + 1))
        .clamp(0.0, 1.0)
        .toDouble();
    final f = maxPrefill * t;
    return kindFor(chapterNumber) == ChapterKind.easy ? f * 0.5 : f;
  }

  /// 0..1: dolu masanin tehlike cizgisi daralmasini ne kadar gevsettigi.
  static double prefillEase(int chapterNumber) =>
      (prefillFraction(chapterNumber) / maxPrefill).clamp(0.0, 1.0).toDouble();

  /// 0.0 (en kolay) - 1.0 (en zor, plato) arasi normalize edilmis zorluk.
  /// GameBoard bunu siparis agirliklarini yuksek seviyelere kaydirmak
  /// icin kullanir. 40. bolum civarinda platoya oturur (sonsuza kadar
  /// gittikce imkansizlasmasin diye).
  static double difficultyT(int chapterNumber) {
    final t = ((chapterNumber - 1) / 40).clamp(0.0, 1.0).toDouble();
    return kindFor(chapterNumber) == ChapterKind.easy ? t * 0.4 : t;
  }

  // ──────────────────────────────────────────────────────
  // GOREV HEDEFLERI ICIN BOLUM BASI ORTALAMALAR (v151)
  // Gorev hedefleri sabit sayi degil: gorev donemi (gun/hafta/ay) basladiginda
  // oyuncunun bolumune gore "N bolumluk is" olarak hesaplanir. Boylece 5. bolumde
  // de 80. bolumde de gunluk gorev yaklasik ayni sureyi ister.
  // Birlesme sayisi bir TAHMINDIR (siparis agirliklari _generateOrder ile ayni mantik).
  // ──────────────────────────────────────────────────────
  static int _estOrderMinLevel(int ch, ChapterKind kind) => orderMinLevel(ch, kind);

  /// Bir bolumde beklenen birlesme sayisi (siparis seviyesi + atis degeri modeli).
  static double estMergesForChapter(int ch) {
    final kind = kindFor(ch);
    final t = difficultyT(ch);
    final bt = bossT(ch);
    final w7 = (ch >= 20 && kind != ChapterKind.easy) ? (kind == ChapterKind.boss ? 8.0 : 2.0 + 2.0 * t) : 0.0;
    final w8 = (kind == ChapterKind.boss && ch >= 30) ? 4.0 : 0.0;
    final List<double> w = kind == ChapterKind.boss
        ? [0, 0, 40 - 32 * bt, 35, 20 + 15 * bt, 5 + 17 * bt, w7, w8]
        : [30 - 20 * t, 25 - 10 * t, 20 + 2 * t, 13 + 10 * t, 8 + 14 * t, 4 + 16 * t, w7, w8];
    final floor = _estOrderMinLevel(ch, kind);
    for (int i = 0; i < floor - 1 && i < w.length; i++) {
      w[i] = 0;
    }
    final total = w.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return 0;
    // Atis degeri: Lv1 (%90) / Lv2 (%10), baski bolumlerinde ara sira Lv3 (=4 birim).
    final p3Base = (ch >= pressureStartChapter && kind != ChapterKind.easy)
        ? (0.05 + (pressureLv3Max - 0.05) * ((ch - pressureStartChapter) / 11).clamp(0.0, 1.0).toDouble())
        : 0.0;
    final p3 = (p3Base + ChapterMods.forChapter(ch).lv3Add).clamp(0.0, 0.45).toDouble();
    final v = (1 - p3) * (0.9 * 1 + 0.1 * 2) + p3 * 4;
    double merges(int level) {
      final m = (1 << (level - 1)) / v - 1; // Lv L = 2^(L-1) birim
      return m < 0 ? 0 : m;
    }

    var exp = 0.0;
    for (int i = 0; i < w.length; i++) {
      exp += (w[i] / total) * merges(i + 1);
    }
    if (kind != ChapterKind.boss && ch >= 6) {
      final rc = 0.12 + 0.18 * t + 0.10 * lateT(ch);
      final fl = floor > 3 ? floor : 3;
      final rule = (merges(fl) + merges(fl + 1) + merges(fl + 2)) / 3;
      exp = (1 - rc) * exp + rc * rule;
    }
    return goalFor(ch) * exp;
  }

  /// [startChapter]'dan baslayan 10 bolumun ortalamasi: [teslimat, birlesme, coin] / bolum.
  static List<double> missionPerChapter(int startChapter) {
    final s = startChapter < 3 ? 3 : startChapter;
    double d = 0, m = 0, c = 0;
    const n = 10;
    for (int i = 0; i < n; i++) {
      final ch = s + i;
      d += goalFor(ch);
      m += estMergesForChapter(ch);
      c += chapterCoinsFor(ch);
    }
    return [d / n, m / n, c / n];
  }

  /// Yuvarlak, okunur hedef sayisi (45, 700, 5100, 30000 gibi).
  static int niceTarget(double v) {
    if (v < 100) return ((v / 5).round() * 5).clamp(5, 100).toInt();
    if (v < 1000) return (v / 10).round() * 10;
    if (v < 10000) return (v / 100).round() * 100;
    return (v / 500).round() * 500;
  }

  /// v152: bolum degistiricileri (zorluk dalgasi, tema kurali, mutator, boss kisiligi).
  static ChapterMods modsFor(int ch) => ChapterMods.forChapter(ch);

  // Donem uzunluklari (bolum cinsinden) - RC ile ayarlanir.
  static int get missionDailyChapters => RemoteTuning.i('mission_daily_ch', 5);
  static int get missionWeeklyChapters => RemoteTuning.i('mission_weekly_ch', 28);
  static int get missionMonthlyChapters => RemoteTuning.i('mission_monthly_ch', 110);
}
