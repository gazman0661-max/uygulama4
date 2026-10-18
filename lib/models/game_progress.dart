import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random, min;

import 'package:shared_preferences/shared_preferences.dart';

import '../services/time_service.dart';
import '../services/progress_mirror.dart';
import 'town.dart';
import 'lucky_wheel.dart';
import 'season.dart';
import 'piggy.dart';
import 'weekly_event.dart';
import 'game_theme.dart' show ChapterConfig, ChapterKind;
import '../services/music_service.dart';
import '../services/analytics_service.dart';

import '../services/log_service.dart';
/// Tek kullanimlik guclendiriciler.
///  - aimGuide: sonraki birkac atista topun nereye carpacagini gosterir
///  - joker: siradaki topun seviyesini oyuncu secer
///  - revive: masa dolunca alt bolgeyi temizleyip devam ettirir
enum BoosterType { aimGuide, joker, revive }

/// Sans carki sonucu: hangi dilim, ne kazanildi.
class WheelResult {
  final int sliceIndex;
  final int coins;
  final int gems;
  final bool energyFilled;
  final BoosterType? booster;
  final bool guaranteed;
  const WheelResult({
    required this.sliceIndex,
    required this.coins,
    required this.gems,
    required this.energyFilled,
    required this.booster,
    required this.guaranteed,
  });
}

/// Uygulama genelinde paylaşilan, tek bir kopyasi olan (singleton)
/// ilerleme durumu: coin bakiyesi, hangi bolumlerin acildigi, dukkandan
/// alinan yukseltmelerin seviyesi, gunluk odul/streak ve gunluk gorevler.
///
/// KALICILIK: shared_preferences uzerinden JSON olarak diske yazilir/
/// okunur. main() acilista load()'u await eder, mutasyon yapan her
/// metot (satin alma, odul/gorev claim'i, enerji harcama/kazanma vb.)
/// sonunda _persist() cagirir. _persist() disk yazimini kisa bir sure
/// (debounce) erteleyip biriktirir, boylece art arda gelen degisiklikler
/// (ornegin ayni karede birden fazla merge) tek bir yazmaya toplanir.
class GameProgress {
  GameProgress._internal();
  static final GameProgress instance = GameProgress._internal();

  static const String _prefsKey = 'game_progress_v1';

  /// Yerel kayit yazilinca cagrilir (main.dart bulut yuklemesini baglar).
  static void Function()? onSaved;

  /// Oyuncu seviye atlayinca cagrilir (main.dart davet servisini baglar).
  static void Function()? onLevelUp;

  // ── Ogretici (tutorial) durumu ──────────────────────────────────────
  // Hepsi TEK SEFERLIK: gorulen adim/ipucu anahtarlari kalici saklanir
  // (bulut birlesiminde birlesim kumesi alinir, asla geri acilmaz).
  //   ch1_steps  : Bolum 1 rehberli 3 adim bitti
  //   ch1        : Bolum 1 tamamlandi (bundan sonra kaybetme serbest)
  //   danger     : tehlike cizgisi ipucu gosterildi
  //   combo      : kombo ipucu gosterildi
  //   first_full : ilk "Masa Doldu" karti gosterildi
  //   feat_*     : ozellik ilk acildiginda menu vurgusu goruldu
  static const List<String> tutKeys = [
    'ch1_steps',
    'ch1',
    'danger',
    'combo',
    'timer',
    'first_full',
    'feat_missions',
    'feat_event',
    'feat_wheel',
    'feat_season',
    'feat_piggy',
    'feat_town',
    'feat_upgrades',
    'feat_invite',
    'feat_album',
    'tour_upgrades',
    'tour_invite',
    'tour_album',
    'tour_town',
    'tour_missions',
    'tour_wheel',
    'tour_event',
    'tour_season',
    'tour_piggy',
  ];
  final Set<String> _tutSeen = <String>{};
  bool tutSeen(String key) => _tutSeen.contains(key);

  /// YENI OYUNCU: Bolum 1 henuz bitmedi. Acilista ana menu yerine dogrudan
  /// harita > Bolge 1 > Bolum 1 yolu parlatilir (ilk dakika rehberi).
  bool get needsFirstRunGuide => !_tutSeen.contains('ch1') && maxUnlockedChapter <= 1;
  void markTutSeen(String key) {
    if (_tutSeen.add(key)) _persist();
  }
  Timer? _saveDebounce;

  /// Kaydedilecek/yuklenecek tum kalici alanlari JSON'a cevirir.
  Map<String, dynamic> toJson() => {
        'coins': coins,
        'maxUnlockedChapter': maxUnlockedChapter,
        'throwCooldownLevel': throwCooldownLevel,
        'luckLevel': luckLevel,
        'extraOrderSlotLevel': extraOrderSlotLevel,
        'lastDailyRewardClaim': lastDailyRewardClaim?.toIso8601String(),
        'dailyStreak': dailyStreak,
        'missionsResetDate': _missionsResetDate?.toIso8601String(),
        'missionDeliverProgress': missionDeliverProgress,
        'missionMergeProgress': missionMergeProgress,
        'missionCoinsProgress': missionCoinsProgress,
        'missionDeliverClaimed': missionDeliverClaimed,
        'missionMergeClaimed': missionMergeClaimed,
        'missionCoinsClaimed': missionCoinsClaimed,
        'weeklyMissionsResetDate': _weeklyMissionsResetDate?.toIso8601String(),
        'missionWeeklyDeliverProgress': missionWeeklyDeliverProgress,
        'missionWeeklyMergeProgress': missionWeeklyMergeProgress,
        'missionWeeklyCoinsProgress': missionWeeklyCoinsProgress,
        'missionWeeklyDeliverClaimed': missionWeeklyDeliverClaimed,
        'missionWeeklyMergeClaimed': missionWeeklyMergeClaimed,
        'missionWeeklyCoinsClaimed': missionWeeklyCoinsClaimed,
        'monthlyMissionsResetDate': _monthlyMissionsResetDate?.toIso8601String(),
        'missionMonthlyDeliverProgress': missionMonthlyDeliverProgress,
        'missionMonthlyMergeProgress': missionMonthlyMergeProgress,
        'missionMonthlyCoinsProgress': missionMonthlyCoinsProgress,
        'missionMonthlyDeliverClaimed': missionMonthlyDeliverClaimed,
        'missionMonthlyMergeClaimed': missionMonthlyMergeClaimed,
        'missionMonthlyCoinsClaimed': missionMonthlyCoinsClaimed,
        'energy': _energy,
        'energyRegenStart': _energyRegenStart?.toIso8601String(),
        'energyAdWatchesUsed': _energyAdWatchesUsed,
        'energyAdCooldownStart': _energyAdCooldownStart?.toIso8601String(),
        'soundEnabled': soundEnabled,
        'musicEnabled': musicEnabled,
        'hapticsEnabled': hapticsEnabled,
        'screenFxEnabled': screenFxEnabled,
        'albumDiscovered': _albumDiscovered.toList(),
        'albumClaimedSets': _albumClaimedSets.toList(),
        'albumCompleteClaimed': _albumCompleteClaimed,
        'gems': gems,
        'boosterAim': boosterCount(BoosterType.aimGuide),
        'boosterJoker': boosterCount(BoosterType.joker),
        'boosterRevive': boosterCount(BoosterType.revive),
        'starterPackBought': starterPackBought,
        'starterOfferStart': _starterOfferStart?.toIso8601String(),
        'adGemsCooldownStart': _adGemsCooldownStart?.toIso8601String(),
        'adGemsUsed': _adGemsUsed,
        'boosterAdDay': _boosterAdDay,
        'boosterAdCount': _boosterAdCount,
        'adQuotaDay': _adQuotaDay,
        'adQuota': Map<String, int>.from(_adQuota),
        'adDiscounts': _adDiscounts.toList(),
        'chapterStars': _chapterStars.map((k, v) => MapEntry(k.toString(), v)),
        'playerLevel': playerLevel,
        'playerXp': playerXp,
        'tutSeen': _tutSeen.toList(),
        'townLevels': List<int>.from(townLevels),
        'townMilestoneIdx': _townMilestoneIdx,
        'townStored': List<double>.from(townStored),
        'townLastMs': List<int>.from(townLastMs),
        'townUpgradeEnd': List<int>.from(townUpgradeEndMs),
        'builders': builderCount,
        'wheelDay': _wheelDay?.toIso8601String(),
        'wheelFreeUsed': _wheelFreeUsed,
        'wheelAdUsed': _wheelAdUsed,
        'wheelStreak': wheelStreak,
        'wheelLastFreeDay': _wheelLastFreeDay?.toIso8601String(),
        'wheelPending': _wheelPending == null
            ? null
            : {
                'i': _wheelPending!.sliceIndex,
                'c': _wheelPending!.coins,
                'g': _wheelPending!.gems,
                'e': _wheelPending!.energyFilled,
                'b': _wheelPending!.booster?.index,
                'q': _wheelPending!.guaranteed,
              },
      };

  /// Diskten okunan JSON'u mevcut singleton'a uygular. Eksik/bozuk
  /// alanlar sessizce varsayilan degerde birakilir (ilk kurulum ya da
  /// eski bir surum formatiyla karsilasilirsa cokmemesi icin).
  void _applyJson(Map<String, dynamic> json) {
    coins = json['coins'] as int? ?? coins;
    maxUnlockedChapter = json['maxUnlockedChapter'] as int? ?? maxUnlockedChapter;
    throwCooldownLevel = json['throwCooldownLevel'] as int? ?? throwCooldownLevel;
    luckLevel = json['luckLevel'] as int? ?? luckLevel;
    extraOrderSlotLevel = json['extraOrderSlotLevel'] as int? ?? extraOrderSlotLevel;
    lastDailyRewardClaim = _parseDate(json['lastDailyRewardClaim']);
    dailyStreak = json['dailyStreak'] as int? ?? dailyStreak;
    _missionsResetDate = _parseDate(json['missionsResetDate']);
    missionDeliverProgress = json['missionDeliverProgress'] as int? ?? missionDeliverProgress;
    missionMergeProgress = json['missionMergeProgress'] as int? ?? missionMergeProgress;
    missionCoinsProgress = json['missionCoinsProgress'] as int? ?? missionCoinsProgress;
    missionDeliverClaimed = json['missionDeliverClaimed'] as bool? ?? missionDeliverClaimed;
    missionMergeClaimed = json['missionMergeClaimed'] as bool? ?? missionMergeClaimed;
    missionCoinsClaimed = json['missionCoinsClaimed'] as bool? ?? missionCoinsClaimed;
    _weeklyMissionsResetDate = _parseDate(json['weeklyMissionsResetDate']);
    missionWeeklyDeliverProgress = json['missionWeeklyDeliverProgress'] as int? ?? missionWeeklyDeliverProgress;
    missionWeeklyMergeProgress = json['missionWeeklyMergeProgress'] as int? ?? missionWeeklyMergeProgress;
    missionWeeklyCoinsProgress = json['missionWeeklyCoinsProgress'] as int? ?? missionWeeklyCoinsProgress;
    missionWeeklyDeliverClaimed = json['missionWeeklyDeliverClaimed'] as bool? ?? missionWeeklyDeliverClaimed;
    missionWeeklyMergeClaimed = json['missionWeeklyMergeClaimed'] as bool? ?? missionWeeklyMergeClaimed;
    missionWeeklyCoinsClaimed = json['missionWeeklyCoinsClaimed'] as bool? ?? missionWeeklyCoinsClaimed;
    _monthlyMissionsResetDate = _parseDate(json['monthlyMissionsResetDate']);
    missionMonthlyDeliverProgress = json['missionMonthlyDeliverProgress'] as int? ?? missionMonthlyDeliverProgress;
    missionMonthlyMergeProgress = json['missionMonthlyMergeProgress'] as int? ?? missionMonthlyMergeProgress;
    missionMonthlyCoinsProgress = json['missionMonthlyCoinsProgress'] as int? ?? missionMonthlyCoinsProgress;
    missionMonthlyDeliverClaimed = json['missionMonthlyDeliverClaimed'] as bool? ?? missionMonthlyDeliverClaimed;
    missionMonthlyMergeClaimed = json['missionMonthlyMergeClaimed'] as bool? ?? missionMonthlyMergeClaimed;
    missionMonthlyCoinsClaimed = json['missionMonthlyCoinsClaimed'] as bool? ?? missionMonthlyCoinsClaimed;
    _energy = json['energy'] as int? ?? _energy;
    _energyRegenStart = _parseDate(json['energyRegenStart']);
    _energyAdWatchesUsed = json['energyAdWatchesUsed'] as int? ?? _energyAdWatchesUsed;
    _energyAdCooldownStart = _parseDate(json['energyAdCooldownStart']);
    soundEnabled = json['soundEnabled'] as bool? ?? soundEnabled;
    musicEnabled = json['musicEnabled'] as bool? ?? musicEnabled;
    hapticsEnabled = json['hapticsEnabled'] as bool? ?? hapticsEnabled;
    screenFxEnabled = json['screenFxEnabled'] as bool? ?? screenFxEnabled;
    final discovered = json['albumDiscovered'];
    if (discovered is List) {
      _albumDiscovered
        ..clear()
        ..addAll(discovered.whereType<String>());
    }
    final claimedSets = json['albumClaimedSets'];
    if (claimedSets is List) {
      _albumClaimedSets
        ..clear()
        ..addAll(claimedSets.whereType<String>());
    }
    _albumCompleteClaimed = json['albumCompleteClaimed'] as bool? ?? _albumCompleteClaimed;
    gems = json['gems'] as int? ?? gems;
    _boosters[BoosterType.aimGuide] = json['boosterAim'] as int? ?? boosterCount(BoosterType.aimGuide);
    _boosters[BoosterType.joker] = json['boosterJoker'] as int? ?? boosterCount(BoosterType.joker);
    _boosters[BoosterType.revive] = json['boosterRevive'] as int? ?? boosterCount(BoosterType.revive);
    starterPackBought = json['starterPackBought'] as bool? ?? starterPackBought;
    _starterOfferStart = _parseDate(json['starterOfferStart']) ?? _starterOfferStart;
    _adGemsCooldownStart = _parseDate(json['adGemsCooldownStart']);
    _adGemsUsed = json['adGemsUsed'] as int? ?? _adGemsUsed;
    _boosterAdDay = json['boosterAdDay'] as String? ?? _boosterAdDay;
    _adQuotaDay = json['adQuotaDay'] as String? ?? _adQuotaDay;
    final aq = json['adQuota'];
    if (aq is Map) {
      _adQuota
        ..clear()
        ..addAll(aq.map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
    }
    final ad = json['adDiscounts'];
    if (ad is List) {
      _adDiscounts
        ..clear()
        ..addAll(ad.map((e) => e.toString()));
    }
    _boosterAdCount = json['boosterAdCount'] as int? ?? _boosterAdCount;
    final stars = json['chapterStars'];
    if (stars is Map) {
      _chapterStars.clear();
      stars.forEach((k, v) {
        final ch = int.tryParse(k.toString());
        if (ch != null && v is int) _chapterStars[ch] = v.clamp(0, 3).toInt();
      });
    }
    playerLevel = (json['playerLevel'] as int? ?? playerLevel).clamp(1, 9999).toInt();
    playerXp = json['playerXp'] as int? ?? playerXp;
    final tutRaw = json['tutSeen'];
    if (tutRaw is List) {
      _tutSeen
        ..clear()
        ..addAll(tutRaw.whereType<String>());
      // v126 gecisi (bir kez): bu surumden once oynayan, seviye 5+ oyuncular Dukkan/Album turunu
      // gormesin (zaten kullaniyorlar). Davet turu HERKESE bir kez gosterilir (tanitim).
      if (!_tutSeen.contains('tut_mig_126')) {
        _tutSeen.add('tut_mig_126');
        if (playerLevel >= 5) {
          _tutSeen.addAll(const ['feat_upgrades', 'tour_upgrades', 'feat_album', 'tour_album']);
        }
      }
    } else if ((json['maxUnlockedChapter'] as int? ?? 1) > 1) {
      // ESKI KAYIT (ogretici sistemi yokken oynanmis): oyuncuya sifirdan
      // ogretici/vurgu gostermeyelim, hepsi gorulmus sayilir.
      _tutSeen.addAll(tutKeys);
    }
    final tl = json['townLevels'];
    if (tl is List) {
      for (var i = 0; i < townLevels.length && i < tl.length; i++) {
        final v = tl[i];
        if (v is num) townLevels[i] = v.toInt().clamp(0, TownCatalog.maxLevel).toInt();
      }
    }
    _townMilestoneIdx = json['townMilestoneIdx'] as int? ?? _townMilestoneIdx;
    final tsv = json['townStored'];
    if (tsv is List) {
      for (var i = 0; i < townStored.length && i < tsv.length; i++) {
        final v = tsv[i];
        if (v is num) townStored[i] = v.toDouble().clamp(0.0, 1000000.0).toDouble();
      }
    }
    final tlm = json['townLastMs'];
    if (tlm is List) {
      for (var i = 0; i < townLastMs.length && i < tlm.length; i++) {
        final v = tlm[i];
        if (v is num) townLastMs[i] = v.toInt();
      }
    }
    final tue = json['townUpgradeEnd'];
    if (tue is List) {
      for (var i = 0; i < townUpgradeEndMs.length && i < tue.length; i++) {
        final v = tue[i];
        if (v is num) townUpgradeEndMs[i] = v.toInt();
      }
    }
    builderCount = (json['builders'] as int? ?? 1).clamp(1, TownCatalog.maxBuilders).toInt();
    // Eski kayitlar: bina zaten varsa uretim SIMDIDEN baslasin.
    final nowMs = TimeService.instance.now().millisecondsSinceEpoch;
    for (var i = 0; i < townLevels.length; i++) {
      if (townLevels[i] > 0 && townLastMs[i] <= 0) townLastMs[i] = nowMs;
    }
    tickTownUpgrades(); // uygulama kapaliyken biten insaatlar
    _wheelDay = _parseDate(json['wheelDay']);
    _wheelFreeUsed = json['wheelFreeUsed'] as bool? ?? false;
    _wheelAdUsed = json['wheelAdUsed'] as int? ?? 0;
    wheelStreak = json['wheelStreak'] as int? ?? 0;
    _wheelLastFreeDay = _parseDate(json['wheelLastFreeDay']);
    final wp = json['wheelPending'];
    if (wp is Map) {
      final bi = wp['b'] as int?;
      _wheelPending = WheelResult(
        sliceIndex: wp['i'] as int? ?? 0,
        coins: wp['c'] as int? ?? 0,
        gems: wp['g'] as int? ?? 0,
        energyFilled: wp['e'] as bool? ?? false,
        booster: (bi != null && bi >= 0 && bi < BoosterType.values.length) ? BoosterType.values[bi] : null,
        guaranteed: wp['q'] as bool? ?? false,
      );
      claimWheelPrize(); // cark donerken kapanmis - odulu simdi ver
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  /// Uygulama acilirken BIR KEZ cagrilir (main() icinde, runApp'tan once
  /// await edilir). Kayitli bir ilerleme yoksa (ilk kurulum) sessizce
  /// varsayilan degerlerle devam eder.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        // SharedPreferences bos: dosya yedeginde ilerleme var mi? (prefs bozulmus/sifirlanmis olabilir)
        final m = await ProgressMirror.read();
        if (m != null && m.isNotEmpty) {
          AppLog.e('progress', 'load: prefs BOS ama dosya yedegi var (${m.length} bayt) -> yedekten GERI YUKLENIYOR');
          raw = m;
          try {
            await prefs.setString(_prefsKey, m);
          } catch (err) {
            AppLog.w('progress', 'yedek prefs\'e yazilamadi', err);
          }
        }
      }
      if (raw == null || raw.isEmpty) {
        AppLog.w('progress', 'load: KAYIT YOK (ilk kurulum ya da kayit silinmis) anahtar=$_prefsKey');
        return;
      }
      try {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
        AppLog.i('progress', 'load: ${raw.length} bayt okundu');
      } catch (err, st) {
        AppLog.e('progress', 'load: birincil kayit BOZUK, dosya yedegi deneniyor', err, st);
        final m = await ProgressMirror.read();
        if (m != null && m.isNotEmpty && m != raw) {
          _applyJson(jsonDecode(m) as Map<String, dynamic>);
          AppLog.i('progress', 'load: dosya yedeginden ${m.length} bayt okundu');
        } else {
          rethrow;
        }
      }
    } catch (err, st) {
      AppLog.e('progress', 'load BASARISIZ (bozuk kayit ya da erisim hatasi)', err, st);
      // Bozuk/uyumsuz kayit - varsayilanlarla devam et, uygulamayi cokertme.
    }
  }

  /// Bulut birlestirmesinin sonucunu uygular. Uygulama kismi SENKRON calisir
  /// (arada oyuncu islemi araya giremez); diske yazma sonra. Bulut yuklemesini
  /// TETIKLEMEZ (onSaved cagrilmaz) - aksi halde sonsuz esitleme dongusu olur.
  Future<void> applyRemote(Map<String, dynamic> json) async {
    try {
      _applyJson(json);
    } catch (err) { AppLog.w('game_progress.applyRemote', 'yutulan hata', err); }
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(toJson());
      await prefs.setString(_prefsKey, data);
      await ProgressMirror.write(data);
    } catch (err) { AppLog.w('game_progress.applyRemote', 'yutulan hata', err); }
  }

  /// Su anki durumu hemen (bekletmeden) diske yazar.
  int _saveCount = 0;

  // ---- DEGISIM GUNLUGU: her kayitta onceki kayitla farki loglar (coin, elmas,
  // enerji, bolum, seviye, bina, gorev...). Hangi eylemin neyi degistirdigi
  // zaman damgasiyla log'da gorunur; tek tek mutator'a log eklemek gerekmez.
  Map<String, String>? _lastLogged;

  void _logChanges(String data) {
    try {
      final cur = <String, String>{};
      (jsonDecode(data) as Map<String, dynamic>).forEach((k, v) => cur[k] = jsonEncode(v));
      final prev = _lastLogged;
      _lastLogged = cur;
      if (prev == null) {
        AppLog.i('state', 'baslangic: coin=$coins elmas=$gems enerji=$_energy bolum=$maxUnlockedChapter oyuncuSeviye=$playerLevel xp=$playerXp bina=${townLevels.toList()}');
        return;
      }
      final diffs = <String>[];
      cur.forEach((k, v) {
        final o = prev[k];
        if (o == v) return;
        String t(String? x) => x == null ? '-' : (x.length > 70 ? '${x.substring(0, 70)}...' : x);
        final ov = int.tryParse(o ?? '');
        final nv = int.tryParse(v);
        if (ov != null && nv != null) {
          final d = nv - ov;
          diffs.add('$k: $ov -> $nv (${d >= 0 ? '+' : ''}$d)');
        } else {
          diffs.add('$k: ${t(o)} -> ${t(v)}');
        }
      });
      if (diffs.isNotEmpty) AppLog.i('state', diffs.join(' | '));
    } catch (err) {
      AppLog.w('state', 'degisim gunlugu hatasi', err);
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(toJson());
      final ok = await prefs.setString(_prefsKey, data);
      await ProgressMirror.write(data); // dosya yedegi (prefs sifirlanirsa geri yuklenir)
      _logChanges(data);
      _saveCount++;
      if (!ok) {
        AppLog.e('progress', 'save: setString FALSE dondu (yazilamadi) boyut=${data.length}');
      } else if (_saveCount <= 3 || _saveCount % 25 == 0) {
        AppLog.i('progress', 'save #$_saveCount tamam boyut=${data.length} bolum=$maxUnlockedChapter coin=$coins');
      }
      onSaved?.call(); // bulut yedegi (CloudSaveService) icin tetik
    } catch (err, st) {
      AppLog.e('progress', 'save ISTISNA (diske yazilamadi)', err, st);
      // Diske yazamadik (ornegin depolama dolu) - oyunu durdurmaya deger degil.
    }
  }

  /// Mutasyon yapan metotlarin sonunda cagirilir. Art arda gelen
  /// cagrilari 400ms icinde tek bir save()'e toplar, boylece ayni
  /// karede olusan birden fazla merge/coin degisikligi tek diske
  /// yazma islemine denk gelir.
  void _persist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), save);
  }

  /// Reklamla x2 coin gibi BONUS coin: sadece cuzdana gider. Gorev / sezon /
  /// etkinlik / kumbara ilerlemesine (reportCoinsEarned) ve Kasaba coin
  /// bonusuna (applyCoinBonus) SAYILMAZ, boylece ekonomi dengesi bozulmaz.
  // ── ELMASLA COIN PAKETLERI ─────────────────────────────────────
  // Coin darbogaz oldugu icin elmas coin'e cevrilebilir. Paket buyuklugu
  // OYUNCUNUN ILERLEMESINE gore olceklenir (erken oyunda 100 elmas bir
  // sehir seviyesini bitirmesin, gec oyunda da degersiz kalmasin):
  // miktar = tahmini bolum coin'i x 6 (gunluk ~6 bolum) x paket gunu.
  static const List<CoinPackDef> coinPacks = [
    CoinPackDef('coin_s', 30, 0.3),
    CoinPackDef('coin_m', 100, 1.2),
    CoinPackDef('coin_l', 300, 4.0),
    CoinPackDef('coin_xl', 800, 12.0, best: true),
  ];

  /// Bir (normal) bolumun coin getirisi. v125: artik TAHMIN degil - bolum coin'i kademeli sabit
  /// (ChapterConfig.baseChapterCoins), coin paketi ve bolge odulu dogrudan buna gore hesaplanir.
  static int estChapterCoins(int chapter) => ChapterConfig.baseChapterCoins(chapter);

  /// Paketin su anki coin miktari (50'ye yuvarlanir, en az 100).
  int coinPackAmount(CoinPackDef p) {
    final raw = estChapterCoins(maxUnlockedChapter) * 6 * p.days;
    final amount = (raw / 50).round() * 50;
    return amount < 100 ? 100 : amount;
  }

  /// Elmasi harcar, coin'i verir. Yetersiz elmas -> false. Gorev ilerlemesine SAYILMAZ.
  bool buyCoinPack(CoinPackDef p) {
    final amount = coinPackAmount(p);
    if (!spendGems(p.gems, 'coin_pack')) return false;
    addBonusCoins(amount);
    return true;
  }

  void addBonusCoins(int amount) {
    if (amount <= 0) return;
    coins += amount;
    _persist();
  }

  /// Uygulama arka plana alinirken/kapanirken (AppLifecycleState.paused/
  /// detached) cagrilmali - bekleyen debounce'u iptal edip HEMEN yazar,
  /// boylece son saniyedeki degisiklik kaybolmaz.
  Future<void> flush() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await save();
  }

  /// Oyuncunun toplam coin bakiyesi. Bolumler arasinda TASINIR -
  /// eskiden her bolum basinda 120'ye sifirlaniyordu, artik gercek
  /// bir para birimi gibi davranmasi icin kalici.
  int coins = 150;

  /// Ayarlar: ses efektleri ve titresim. Ana menudeki iki yuvarlak butonla
  /// acilip kapanir, diske yazilir (bkz. services/sfx_service.dart ve
  /// services/haptic_service.dart).
  bool soundEnabled = true; // SES EFEKTLERI
  bool musicEnabled = true; // MUZIK
  bool hapticsEnabled = true;
  bool screenFxEnabled = true; // v123: ekran sarsintisi + yavas cekim (hareket hassasiyeti icin kapatilabilir)

  void setSoundEnabled(bool value) {
    soundEnabled = value;
    _persist();
  }

  void setMusicEnabled(bool value) {
    musicEnabled = value;
    MusicService.instance.sync();
    _persist();
  }

  void setHapticsEnabled(bool value) {
    hapticsEnabled = value;
    _persist();
  }

  void setScreenFxEnabled(bool value) {
    screenFxEnabled = value;
    _persist();
  }

  // ────────────────────────────────────────────────────────────
  // Koleksiyon albumu
  // 6 tema x 8 obje = 48 kart. Bir obje tahtada ilk kez uretilince
  // (atis ya da birlesme) karti acilir. Bir temanin 8 karti da
  // acilinca set odulu alinabilir; 6 set de alinirsa buyuk odul gelir.
  // Odul degerleri sabit: ileride mucevher (gem) eklenince buradaki
  // coin odullerini gem'e cevirmek icin sadece claim metotlarina bak.
  // ────────────────────────────────────────────────────────────
  static const int albumItemsPerTheme = 8;
  static const int albumSetReward = 300;
  static const int albumCompleteReward = 2000;
  static const int albumSetGems = 10;
  static const int albumCompleteGems = 50;

  /// AlbumCatalog.themes ile ayni sirada, GameTheme.themeNameKey degerleri.
  static const List<String> albumThemeKeys = [
    'theme_fastfood',
    'theme_cafe',
    'theme_magic',
    'theme_pirate',
    'theme_ice',
    'theme_space',
  ];

  final Set<String> _albumDiscovered = <String>{};
  final Set<String> _albumClaimedSets = <String>{};
  bool _albumCompleteClaimed = false;

  static String _albumKey(String themeKey, int level) => '$themeKey:$level';

  bool isDiscovered(String themeKey, int level) =>
      _albumDiscovered.contains(_albumKey(themeKey, level));

  int discoveredCount(String themeKey) {
    var n = 0;
    for (var lvl = 1; lvl <= albumItemsPerTheme; lvl++) {
      if (isDiscovered(themeKey, lvl)) n++;
    }
    return n;
  }

  int get totalDiscovered => _albumDiscovered.length;
  int get totalAlbumCards => albumThemeKeys.length * albumItemsPerTheme;

  /// Bir obje ilk kez uretildiginde cagrilir. Kart ilk kez aciliyorsa
  /// true doner (cagiran taraf bildirim gosterebilir).
  bool discoverItem(String themeKey, int level) {
    if (level < 1 || level > albumItemsPerTheme) return false;
    final added = _albumDiscovered.add(_albumKey(themeKey, level));
    if (added) _persist();
    return added;
  }

  bool isSetComplete(String themeKey) => discoveredCount(themeKey) >= albumItemsPerTheme;
  bool isSetClaimed(String themeKey) => _albumClaimedSets.contains(themeKey);

  bool claimAlbumSet(String themeKey) {
    if (!isSetComplete(themeKey) || isSetClaimed(themeKey)) return false;
    _albumClaimedSets.add(themeKey);
    coins += albumSetReward;
    gems += albumSetGems;
    _persist();
    return true;
  }

  bool get albumCompleteReady =>
      _albumClaimedSets.length >= albumThemeKeys.length && !_albumCompleteClaimed;
  bool get albumCompleteClaimed => _albumCompleteClaimed;

  bool claimAlbumComplete() {
    if (!albumCompleteReady) return false;
    _albumCompleteClaimed = true;
    coins += albumCompleteReward;
    gems += albumCompleteGems;
    _persist();
    return true;
  }

  /// Ana menudeki albüm ikonunda kirmizi nokta gostermek icin: alinmayi
  /// bekleyen bir set ya da buyuk odul var mi?
  bool get hasAlbumClaimable {
    if (albumCompleteReady) return true;
    for (final k in albumThemeKeys) {
      if (isSetComplete(k) && !isSetClaimed(k)) return true;
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────
  // Mucevher (hard currency) + tek kullanimlik guclendiriciler
  //
  // Mucevher: mucevher paketleri (IAP - su an TEST modunda, bkz.
  // services/billing_service.dart), baslangic paketi ve kucuk ucretsiz
  // kaynaklardan (ilk kez gecilen bolum, album set odulleri) gelir.
  // Harcama noktalari: enerji doldurma ve 3 guclendirici.
  // Fiyatlar/miktarlar asagidaki sabitlerden ayarlanir.
  // ────────────────────────────────────────────────────────────
  static const int startingGems = 5;
  static const int chapterFirstClearGems = 1;
  static const int energyRefillGemCost = 50; // enerji dolum bedeli (en kucuk elmas paketi 80)

  // Ucretsiz mucevher kaynaklari (ayarlanabilir)
  static const int dailyRewardDay7Gems = 5; // gunluk odul serisinin 7. gunu
  static const int weeklyMissionGems = 5; // her haftalik gorev
  static const int monthlyMissionGems = 15; // her aylik gorev
  static const int chapterMilestoneEvery = 5; // her N. bolumde
  static const int chapterMilestoneGems = 3; // ...ilk gecisinde ek odul
  // Odullu reklamla mucevher: 2 saatlik pencerede 3 reklam. 3. reklam izlenince 2 saatlik sayac baslar,
  // sayac bitince 3 hak yeniden dolar. Her reklam adGemMin..adGemMax arasi rastgele mucevher verir.
  static const int adGemsPerWindow = 3; // pencere basina reklam hakki
  static const Duration adGemsCooldown = Duration(hours: 2); // 3. reklamdan sonraki bekleme
  static const int adGemMin = 1;
  static const int adGemMax = 5;
  // Agirliklar (%): index 0 => 1 mucevher ... index 4 => 5 mucevher. Toplam 100. Ortalama ~1.8 mucevher/reklam.
  static const List<int> adGemWeights = [50, 28, 14, 6, 2];

  static const Map<BoosterType, int> boosterGemCost = {
    BoosterType.aimGuide: 25,
    BoosterType.joker: 45,
    BoosterType.revive: 70,
  };

  int gems = startingGems;

  // Odullu reklamla mucevher: penceredeki kullanilan hak + 3. reklamdan sonra baslayan sayac.
  int _adGemsUsed = 0;

  // Reklam izleyerek guclendirici kazanma: gunde en fazla [boosterAdsPerDay] kez (hepsi ortak).
  static const int boosterAdsPerDay = 3;
  String? _boosterAdDay;
  int _boosterAdCount = 0;

  String _todayKey() {
    final n = TimeService.instance.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Bugun reklamla kazanilabilecek kalan guclendirici sayisi.
  int get boosterAdsRemaining {
    if (_boosterAdDay != _todayKey()) return boosterAdsPerDay;
    return (boosterAdsPerDay - _boosterAdCount).clamp(0, boosterAdsPerDay).toInt();
  }

  /// Reklam basariyla izlendi: 1 guclendirici ver ve gunluk hakki dusur.
  bool claimBoosterAd(BoosterType t) {
    if (boosterAdsRemaining <= 0) return false;
    final today = _todayKey();
    if (_boosterAdDay != today) {
      _boosterAdDay = today;
      _boosterAdCount = 0;
    }
    _boosterAdCount++;
    _boosters[t] = boosterCount(t) + 1;
    _persist();
    return true;
  }
  DateTime? _adGemsCooldownStart;
  final Random _adGemRng = Random();

  void _refreshAdGems() {
    final start = _adGemsCooldownStart;
    if (start == null) {
      // Sayac yokken tum haklar dolmus gorunuyorsa (eski kayit / tutarsizlik) hakki yenile.
      if (_adGemsUsed >= adGemsPerWindow) _adGemsUsed = 0;
      return;
    }
    final now = TimeService.instance.now();
    if (start.isAfter(now)) {
      // Gelecege tasmis kayit (saat geri alinmis) - sayaci simdiden baslat.
      _adGemsCooldownStart = now;
      return;
    }
    if (now.difference(start) >= adGemsCooldown) {
      _adGemsUsed = 0;
      _adGemsCooldownStart = null;
    }
  }

  /// Penceredeki kalan reklam hakki (0-3).
  int get adGemsRemaining {
    _refreshAdGems();
    return (adGemsPerWindow - _adGemsUsed).clamp(0, adGemsPerWindow).toInt();
  }

  /// Haklar bitmisse yeniden dolmaya kalan sure, aksi halde null.
  Duration? get adGemsCooldownRemaining {
    _refreshAdGems();
    final start = _adGemsCooldownStart;
    if (start == null) return null;
    final remaining = adGemsCooldown - TimeService.instance.now().difference(start);
    if (remaining.isNegative) return Duration.zero;
    return remaining > adGemsCooldown ? adGemsCooldown : remaining;
  }

  int _rollAdGems() {
    final total = adGemWeights.fold<int>(0, (a, b) => a + b);
    var r = _adGemRng.nextInt(total);
    for (var i = 0; i < adGemWeights.length; i++) {
      r -= adGemWeights[i];
      if (r < 0) return adGemMin + i;
    }
    return adGemMin;
  }

  /// Reklam BASARIYLA izlendikten sonra cagrilir. Hak varsa mucevher verir ve verilen miktari dondurur,
  /// yoksa 0. 3. reklamda 2 saatlik sayac baslar.
  int claimAdGems() {
    if (adGemsRemaining <= 0) return 0;
    _adGemsUsed++;
    if (_adGemsUsed >= adGemsPerWindow) {
      _adGemsCooldownStart = TimeService.instance.now();
    }
    final amount = _rollAdGems();
    gems += amount;
    _persist();
    return amount;
  }

  // ────────────────────────────────────────────────────────────
  // v118: REKLAMLA HIZLANAN EKONOMI (gunluk hak kotalari)
  //  * 'build'    : insaat -[buildAdMinutes] dk
  //  * 'collect'  : kasaba deposu x2 topla
  //  * 'discount' : [discountMinCost]+ maliyetli yukseltmede %25 indirim jetonu
  // Hak sayaci her gun sifirlanir; indirim jetonu satin alana kadar kalir.
  // ────────────────────────────────────────────────────────────
  static const int buildAdsPerDay = 4;
  static const int buildAdMinutes = 30;
  static const int collectAdsPerDay = 5;
  static const int discountAdsPerDay = 5;
  static const int discountMinCost = 10000;
  static const double adDiscountRate = 0.25;

  String? _adQuotaDay;
  final Map<String, int> _adQuota = {};
  final Set<String> _adDiscounts = {};

  int _quotaMax(String k) => k == 'build' ? buildAdsPerDay : k == 'collect' ? collectAdsPerDay : discountAdsPerDay;

  int adQuotaRemaining(String k) {
    if (_adQuotaDay != _todayKey()) return _quotaMax(k);
    return (_quotaMax(k) - (_adQuota[k] ?? 0)).clamp(0, _quotaMax(k)).toInt();
  }

  void _useAdQuota(String k) {
    final today = _todayKey();
    if (_adQuotaDay != today) {
      _adQuotaDay = today;
      _adQuota.clear();
    }
    _adQuota[k] = (_adQuota[k] ?? 0) + 1;
  }

  /// Indirim jetonu bu kalemde var mi? (kalem: 'throw', 'luck', 'slot', 'town0'..'town5')
  bool hasAdDiscount(String item) => _adDiscounts.contains(item);

  /// Temel maliyet [discountMinCost] ve ustuyse, jeton yoksa ve hak kaldiysa reklamla indirim alinabilir.
  bool canGetAdDiscount(String item, int baseCost) =>
      baseCost >= discountMinCost && !hasAdDiscount(item) && adQuotaRemaining('discount') > 0;

  /// Reklam izlendi: jetonu verir, gunluk hakki dusurur.
  bool claimAdDiscount(String item, int baseCost) {
    if (!canGetAdDiscount(item, baseCost)) return false;
    _useAdQuota('discount');
    _adDiscounts.add(item);
    _persist();
    return true;
  }

  int _discounted(int base, String item) =>
      hasAdDiscount(item) ? ((base * (1 - adDiscountRate)) ~/ 10) * 10 : base;

  int throwCooldownCostNow() =>
      throwCooldownLevel >= maxUpgradeLevel ? 0 : _discounted(throwCooldownCost[throwCooldownLevel], 'throw');
  int luckCostNow() => luckLevel >= maxUpgradeLevel ? 0 : _discounted(luckCost[luckLevel], 'luck');
  int orderSlotCostNow() =>
      extraOrderSlotLevel >= maxOrderSlotLevel ? 0 : _discounted(orderSlotCost[extraOrderSlotLevel], 'slot');

  /// Insaatin kalan suresinden [buildAdMinutes] dk dusurur (reklam izlendikten sonra cagrilir).
  /// Insaat bittiyse tickTownUpgrades seviyeyi atlatir. Hak yoksa / insaat yoksa false.
  bool claimBuildAd(int world) {
    if (!townIsUpgrading(world) || adQuotaRemaining('build') <= 0) return false;
    _useAdQuota('build');
    townUpgradeEndMs[world] -= buildAdMinutes * 60000;
    if (townUpgradeEndMs[world] <= _nowMs) {
      townUpgradeEndMs[world] = _nowMs;
      tickTownUpgrades();
    }
    _persist();
    return true;
  }

  /// Kasaba deposu "x2 topla": reklam izlendikten sonra toplanan miktar kadar BONUS coin verir
  /// (gunluk hak dusurur). Toplama islemini cagiran yapar (collectTown); burada sadece bonus.
  bool claimCollectBonus(int amount) {
    if (amount <= 0 || adQuotaRemaining('collect') <= 0) return false;
    _useAdQuota('collect');
    addBonusCoins(amount);
    return true;
  }

  bool starterPackBought = false;

  // Baslangic paketi SURELI teklif: ilk acilistan itibaren [starterOfferDuration]
  // boyunca gorunur (menu ikonu + magaza), sonra kapanir. Satin alindiysa hic gorunmez.
  static const Duration starterOfferDuration = Duration(hours: 48);
  DateTime? _starterOfferStart;

  /// Teklifin bitmesine kalan sure; satin alindiysa ya da sure dolduysa null.
  Duration? get starterOfferRemaining {
    if (starterPackBought) return null;
    final now = TimeService.instance.now();
    var start = _starterOfferStart;
    if (start == null || start.isAfter(now)) {
      start = now;
      _starterOfferStart = now; // bir sonraki _persist() ile diske yazilir
    }
    final left = starterOfferDuration - now.difference(start);
    return left.isNegative || left == Duration.zero ? null : left;
  }

  // Yeni oyuncu (ve eski kaydi olanlar) her guclendiriciyi denesin diye
  // birkac ucretsiz adetle baslar.
  final Map<BoosterType, int> _boosters = {
    BoosterType.aimGuide: 2,
    BoosterType.joker: 2,
    BoosterType.revive: 1,
  };

  int boosterCount(BoosterType t) => _boosters[t] ?? 0;

  void addGems(int amount) {
    if (amount <= 0) return;
    gems += amount;
    _persist();
  }

  bool spendGems(int amount, [String why = 'other']) {
    if (amount <= 0 || gems < amount) return false;
    gems -= amount;
    AppLog.i('state', 'ELMAS HARCANDI: -$amount neden=$why kalan=$gems');
    _persist();
    AnalyticsService.instance.log('gems_spent', {'why': why, 'amount': amount});
    return true;
  }

  /// Sezon yolu gibi sistemlerin toplu odul vermesi icin tek nokta.
  void grantReward({
    int coins = 0,
    int gems = 0,
    bool energy = false,
    BoosterType? booster,
    int boosterAmount = 1,
  }) {
    if (coins > 0) this.coins += coins;
    if (gems > 0) this.gems += gems;
    if (energy) {
      _regenEnergy();
      _energy = maxEnergy;
      _energyRegenStart = null;
    }
    if (booster != null) {
      _boosters[booster] = this.boosterCount(booster) + boosterAmount;
    }
    _persist();
  }

  /// Eldeki guclendiriciyi tuketir. Yoksa false doner.
  bool useBooster(BoosterType t) {
    final n = boosterCount(t);
    if (n <= 0) return false;
    _boosters[t] = n - 1;
    AppLog.i('state', 'booster KULLANILDI: ${t.name} kalan=${n - 1}');
    _persist();
    return true;
  }

  /// Mucevherle 1 adet guclendirici satin alir.
  bool buyBooster(BoosterType t) {
    if (!spendGems(boosterGemCost[t]!, 'booster_${t.name}')) return false;
    _boosters[t] = boosterCount(t) + 1;
    _persist();
    return true;
  }

  /// Baslangic paketi (tek seferlik): mucevher + her guclendiriciden 3 adet.
  bool grantStarterPack(int packGems) {
    if (starterPackBought) return false;
    starterPackBought = true;
    gems += packGems;
    for (final t in BoosterType.values) {
      _boosters[t] = boosterCount(t) + 3;
    }
    _persist();
    return true;
  }

  /// Enerjiyi mucevherle tam doldurur. Enerji zaten doluysa ya da
  /// mucevher yetmiyorsa false doner (mucevher harcanmaz).
  bool refillEnergyWithGems() {
    _regenEnergy();
    if (_energy >= maxEnergy) return false;
    if (!spendGems(energyRefillGemCost, 'energy')) return false;
    _energy = maxEnergy;
    _energyRegenStart = null;
    _persist();
    return true;
  }

  /// Su ana kadar acilmis en yuksek bolum numarasi. Baslangicta
  /// sadece Bolum 1 oynanabilir. Bir bolum tamamlaninca bu deger
  /// artar. SINIRSIZ ilerleme: ust bir tavan YOK - tema ve zorluk
  /// ChapterConfig tarafindan her bolum numarasi icin uretiliyor,
  /// bu yuzden oyuncu ne kadar ilerlerse o kadar bolum acilabilir.
  int maxUnlockedChapter = 1;

  // ────────────────────────────────────────────────────────────
  // Dukkan yukseltmeleri (coin sink #1)
  // Her yukseltmenin bir "seviyesi" var (0 = hic alinmamis). Seviye
  // arttikca etkisi buyur, maliyeti de artar. Eskiden 3 seviyeydi,
  // oyuncuyu 2-3 bolumde tuketip anlamsizlastiriyordu - simdi 15
  // seviye ile UZUN VADELI bir coin hedefi haline geldi.
  // ────────────────────────────────────────────────────────────
  static const int maxUpgradeLevel = 15;

  int throwCooldownLevel = 0; // "Hizli Atis" - atislar arasi bekleme kisalir
  int luckLevel = 0; // "Sansli Baslangic" - Seviye 2 obje gelme ihtimali artar

  /// 15 seviye icin kademeli artan maliyet egrisi. Ilk birkac seviye
  /// ucuz (hemen elde tutulan ilerleme hissi), sonraki seviyeler
  /// katlanarak pahalilasir (uzun vadeli coin hedefi).
  ///
  /// TABAN: ilk seviye 600 coin - 6 bolumluk bir hedefe oturacak
  /// sekilde hesaplandi (yeni, kucultulmus tier coinReward egrisiyle
  /// ~65-70 coin/bolum varsayimiyla). Eski egrinin ORANLARI (basamak
  /// basamak artis katsayilari) AYNEN korunuyor, sadece tum liste x4
  /// ile olceklendi - boylece basamaklar arasi tutarlilik bozulmadi.
  static const List<int> throwCooldownCost = [
    // v118: AZAR AZAR egri - her seviye bir oncekinin ~x1.45'i (baslangic 600, 15 seviye toplam ~350k).
    // Eski RAMPA A (3.200 -> 10.800 ziplamasi) kaldirildi.
    600, 850, 1250, 1850, 2650, 3850, 5600, 8100, 11700, 17000, 24500, 35500, 52000, 75000, 109000,
  ];
  static const List<int> luckCost = [
    // v118: AZAR AZAR egri - her seviye bir oncekinin ~x1.45'i (baslangic 600, 15 seviye toplam ~350k).
    // Eski RAMPA A (3.200 -> 10.800 ziplamasi) kaldirildi.
    600, 850, 1250, 1850, 2650, 3850, 5600, 8100, 11700, 17000, 24500, 35500, 52000, 75000, 109000,
  ];

  /// Atislar arasi bekleme suresi - her seviye biraz daha kisaltir,
  /// 15. seviyede 250ms'ye iner (taban 700ms, seviye basina -30ms) (eskiden 3. seviyede zaten
  /// 140ms'ye inip tukeniyordu - artik kademe kademe, hep hissedilir
  /// kucuk iyilesmelerle 15 seviyeye yayiliyor).
  Duration get throwCooldown {
    const baseMs = 700; // taban yavas: yukseltme gercekten hissedilsin (eskiden 380)
    const perLevelMs = 30; // 15. seviyede 700 - 450 = 250ms
    final townMs = townPerk(TownPerk.throwSpeed).toInt(); // Buz Sarayi bonusu
    final reducedMs = baseMs - (throwCooldownLevel * perLevelMs) - townMs;
    return Duration(milliseconds: reducedMs.clamp(90, baseMs).toInt());
  }

  /// Firlatilan objenin Seviye 2 olma ihtimali - normalde %25, her
  /// yukseltme seviyesiyle +%2, 15. seviyede %55'e kadar cikar.
  double get level2Chance =>
      (0.25 + luckLevel * 0.02 + townPerk(TownPerk.luck)).clamp(0.25, 0.60).toDouble();

  // ────────────────────────────────────────────────────────────
  // Ekstra Siparis Slotu (coin sink #2)
  // Varsayilan 3 slottan, seviye basina +1 ile 5 slota kadar cikar.
  // ────────────────────────────────────────────────────────────
  static const int maxOrderSlotLevel = 2;
  static const List<int> orderSlotCost = [1800, 5000];
  int extraOrderSlotLevel = 0;
  int get orderSlotCount => 3 + extraOrderSlotLevel;

  bool _tryBuy(int level, List<int> costs, int maxLevel, void Function() apply, {String? item}) {
    if (level >= maxLevel) return false;
    final cost = item == null ? costs[level] : _discounted(costs[level], item);
    if (coins < cost) return false;
    coins -= cost;
    if (item != null) _adDiscounts.remove(item);
    apply();
    _persist();
    return true;
  }

  bool buyThrowCooldownUpgrade() =>
      _tryBuy(throwCooldownLevel, throwCooldownCost, maxUpgradeLevel, () => throwCooldownLevel++, item: 'throw');

  bool buyLuckUpgrade() =>
      _tryBuy(luckLevel, luckCost, maxUpgradeLevel, () => luckLevel++, item: 'luck');

  bool buyOrderSlotUpgrade() =>
      _tryBuy(extraOrderSlotLevel, orderSlotCost, maxOrderSlotLevel, () => extraOrderSlotLevel++, item: 'slot');

  // ────────────────────────────────────────────────────────────
  // KASABA (meta ilerleme) - bkz. models/town.dart
  // 6 bina (dunya basina 1), her biri 0-10 seviye, kalici bonus verir.
  // Yukseltme = coin + o dunyada yildiz sarti. Toplam seviye
  // kilometre taslarinda otomatik odul verir.
  // ────────────────────────────────────────────────────────────
  final List<int> townLevels = List<int>.filled(TownCatalog.worldCount, 0);
  int _townMilestoneIdx = 0;
  double _coinBonusCarry = 0; // kesirli coin bonusu birikimi (kalici degil)

  int get townMilestoneIdx => _townMilestoneIdx;
  int get totalTownLevel => townLevels.fold(0, (a, b) => a + b);
  int townLevel(int world) => townLevels[world];
  bool townIsMax(int world) => townLevels[world] >= TownCatalog.maxLevel;

  /// O dunyadaki bolumlerden toplanan toplam yildiz.
  int worldStars(int world) {
    var n = 0;
    _chapterStars.forEach((ch, st) {
      if (TownCatalog.worldOfChapter(ch) == world) n += st;
    });
    return n;
  }

  /// Indirimsiz (temel) maliyet.
  int townBaseCost(int world) =>
      townIsMax(world) ? 0 : TownCatalog.costFor(world, townLevels[world]);
  int townUpgradeCost(int world) => townIsMax(world) ? 0 : _discounted(townBaseCost(world), 'town$world');
  int townStarsNeeded(int world) =>
      townIsMax(world) ? 0 : TownCatalog.starReq[townLevels[world]];
  bool townStarsOk(int world) => worldStars(world) >= townStarsNeeded(world);

  /// Dunyanin ilk bolumune ulasilmadan o dunyanin binasi kilitli kalir.
  int townUnlockChapter(int world) => world * TownCatalog.chaptersPerWorldBlock + 1;
  bool townChapterReached(int world) => maxUnlockedChapter >= townUnlockChapter(world);

  /// v103: onceki dunyanin binasi [TownCatalog.unlockPrevLevel]. seviyeye gelmeden bu bina
  /// kurulamaz. Zaten kurulmus (seviye>0) binalar eski oyuncular icin kilitlenmez.
  bool townPrevOk(int world) =>
      world <= 0 ||
      TownCatalog.unlockPrevLevel <= 0 ||
      townLevels[world] > 0 ||
      townLevels[world - 1] >= TownCatalog.unlockPrevLevel;

  bool townWorldUnlocked(int world) => townChapterReached(world) && townPrevOk(world);

  // ── Insaat suresi + insaatci (CoC tarzi) ──
  // Yukseltme artik aninda degil: coin odenir, bina SURE boyunca insaat
  // halinde kalir; insaatci sayisi kadar bina ayni anda yukseltilebilir.
  // Sure elmasla hizlandirilabilir (kalan <=5 dk ucretsiz).
  final List<int> townUpgradeEndMs = List<int>.filled(TownCatalog.worldCount, 0); // 0 = insaat yok
  int builderCount = 1;
  final List<TownUpgradeResult> pendingTownResults = []; // biten ama henuz gosterilmeyen (kalici degil)

  int get _nowMs => TimeService.instance.now().millisecondsSinceEpoch;
  bool townIsUpgrading(int world) => townUpgradeEndMs[world] > 0;
  int get townBusyBuilders => townUpgradeEndMs.where((e) => e > 0).length;
  bool get townHasFreeBuilder => townBusyBuilders < builderCount;

  Duration townUpgradeRemaining(int world) {
    final ms = townUpgradeEndMs[world] - _nowMs;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  /// Bir sonraki seviyenin yukseltme suresi (dakika).
  int townUpgradeMinutes(int world) =>
      townIsMax(world) ? 0 : TownCatalog.upgradeMinutes(world, townLevels[world]);

  /// Devam eden insaati hemen bitirmenin elmas bedeli (0 = ucretsiz).
  /// Ilk bina kurulumu (0 -> 1. seviye, ~1 dk) HER ZAMAN ucretsiz; digerlerinde
  /// son 5 dk sabit 1 elmas, sonrasi kalan sureye gore artar.
  int townSkipCost(int world) {
    if (!townIsUpgrading(world)) return 0;
    if (townLevels[world] == 0) return 0;
    return TownCatalog.skipGemCost((townUpgradeRemaining(world).inSeconds / 60).ceil());
  }

  int get nextBuilderGemCost => builderCount >= TownCatalog.maxBuilders ? 0 : TownCatalog.builderGemCost[builderCount];

  bool canUpgradeTown(int world) =>
      townWorldUnlocked(world) &&
      !townIsMax(world) &&
      !townIsUpgrading(world) &&
      townHasFreeBuilder &&
      townStarsOk(world) &&
      coins >= townUpgradeCost(world);

  /// Ana menudeki kirmizi nokta icin: en az bir bina yukseltilebilir mi?
  bool get hasTownUpgradeAvailable {
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      if (canUpgradeTown(w)) return true;
    }
    return false;
  }

  /// Yukseltmeyi BASLATIR (coin odenir, insaat suresi baslar). Basarisizsa false.
  bool startTownUpgrade(int world) {
    if (!canUpgradeTown(world)) return false;
    coins -= townUpgradeCost(world);
    _adDiscounts.remove('town$world');
    townUpgradeEndMs[world] = _nowMs + townUpgradeMinutes(world) * 60000;
    _persist();
    return true;
  }

  /// Suresi dolan insaatlari tamamlar (seviye +1, kilometre tasi odulleri
  /// verilir, sonuc [pendingTownResults]'a eklenir). Degisim olduysa true.
  bool tickTownUpgrades() {
    var changed = false;
    final nowMs = _nowMs;
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      final end = townUpgradeEndMs[w];
      if (end <= 0 || end > nowMs) continue;
      _townSettle(w); // yukseltmeden ONCE eski hizla birikeni kaydet
      townLevels[w]++;
      townUpgradeEndMs[w] = 0;
      final granted = <TownMilestone>[];
      while (_townMilestoneIdx < TownCatalog.milestones.length &&
          totalTownLevel >= TownCatalog.milestones[_townMilestoneIdx].totalLevel) {
        final m = TownCatalog.milestones[_townMilestoneIdx];
        coins += m.coins;
        gems += m.gems;
        granted.add(m);
        _townMilestoneIdx++;
      }
      pendingTownResults.add(TownUpgradeResult(w, townLevels[w], granted));
      changed = true;
    }
    if (changed) _persist();
    return changed;
  }

  /// Devam eden insaati elmasla (veya <=5 dk ise ucretsiz) hemen bitirir.
  bool skipTownUpgrade(int world) {
    if (!townIsUpgrading(world)) return false;
    final cost = townSkipCost(world);
    if (gems < cost) return false;
    gems -= cost;
    townUpgradeEndMs[world] = _nowMs;
    tickTownUpgrades();
    return true;
  }

  /// Yeni insaatci satin alir (elmas).
  bool buyBuilder() {
    if (builderCount >= TownCatalog.maxBuilders) return false;
    final cost = nextBuilderGemCost;
    if (gems < cost) return false;
    gems -= cost;
    builderCount++;
    _persist();
    return true;
  }

  // ── Kaynak uretimi: her bina seviyesine gore pasif coin uretir ──
  // Depoda birikir (kapasite = saatlik uretim x 6 saat), oyuncu Kasaba'da
  // toplar. Zaman TimeService (sunucu saati) ile olculur.
  final List<double> townStored = List<double>.filled(TownCatalog.worldCount, 0);
  final List<int> townLastMs = List<int>.filled(TownCatalog.worldCount, 0);

  /// Uzay Istasyonu bonusu: tum binalarin pasif coin uretimine oransal ekler.
  double get townPassiveBonus => townPerk(TownPerk.passiveBonus);
  int townCoinsPerHour(int world) => TownCatalog.coinsPerHour(world, townLevels[world], bonus: townPassiveBonus);
  int townCapacity(int world) => TownCatalog.capacity(world, townLevels[world], bonus: townPassiveBonus);

  double _townAccrued(int world) {
    final rate = townCoinsPerHour(world);
    if (rate <= 0) return 0;
    final last = townLastMs[world];
    final nowMs = TimeService.instance.now().millisecondsSinceEpoch;
    final hours = last <= 0 ? 0.0 : ((nowMs - last) / 3600000.0).clamp(0.0, 720.0).toDouble();
    return min(townStored[world] + rate * hours, townCapacity(world).toDouble());
  }

  /// Toplanmaya hazir coin (depodaki).
  int townPending(int world) => _townAccrued(world).floor();
  bool townStorageFull(int world) => townCoinsPerHour(world) > 0 && townPending(world) >= townCapacity(world);
  int get townPendingTotal {
    var n = 0;
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      n += townPending(w);
    }
    return n;
  }

  int get townCoinsPerHourTotal {
    var n = 0;
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      n += townCoinsPerHour(w);
    }
    return n;
  }

  bool get hasTownCollectable => townPendingTotal >= 1;

  void _townSettle(int world) {
    townStored[world] = _townAccrued(world);
    townLastMs[world] = TimeService.instance.now().millisecondsSinceEpoch;
  }

  /// Bir binanin deposunu toplar; toplanan coin miktarini doner.
  int collectTown(int world) {
    _townSettle(world);
    final amount = townStored[world].floor();
    if (amount <= 0) return 0;
    townStored[world] -= amount;
    coins += amount;
    _persist();
    return amount;
  }

  /// Belirli bir bonus turunun (ilgili binanin seviyesine gore) degeri.
  double townPerk(TownPerk perk) {
    final w = TownCatalog.perks.indexOf(perk);
    return TownCatalog.perkValue(perk, townLevels[w]);
  }

  static const double upgradeCoinBonusPerLevel = 0.01;
  double get upgradeCoinBonus => (throwCooldownLevel + luckLevel) * upgradeCoinBonusPerLevel;

  /// Coin bonusu (Lezzet Duragi). Kesirli kisim birikip tam coin olunca eklenir.
  int applyCoinBonus(int amount) {
    if (amount <= 0) return amount;
    // v118: Hiz + Sans seviyesi basina +%1 coin (en fazla +%30) - ch48 sonrasi duzlesen geliri yukseltmelere baglar.
    final b = townPerk(TownPerk.coinBonus) + upgradeCoinBonus;
    if (b <= 0) return amount;
    _coinBonusCarry += amount * b;
    final extra = _coinBonusCarry.floor();
    _coinBonusCarry -= extra;
    return amount + extra;
  }

  /// XP bonusu (Sirin Kafe).
  int applyXpBonus(int xp) {
    if (xp <= 0) return xp;
    return xp + (xp * townPerk(TownPerk.xpBonus)).round();
  }

  int _withDailyBonus(int base) => base + (base * townPerk(TownPerk.dailyBonus)).round();

  // ────────────────────────────────────────────────────────────
  // SANS CARKI - bkz. models/lucky_wheel.dart
  // Gunde 1 bedava + 3 reklamli cevirme. 7 gun ust uste bedava
  // cevirene 7. gun nadir odul garanti. Korsan Limani bonusu coin
  // odulune de uygulanir.
  // ────────────────────────────────────────────────────────────
  static const int wheelAdSpinsPerDay = 3;
  static const int wheelStreakTarget = 7;

  DateTime? _wheelDay;
  bool _wheelFreeUsed = false;
  int _wheelAdUsed = 0;
  int wheelStreak = 0;
  DateTime? _wheelLastFreeDay;
  final Random _wheelRng = Random();

  void _resetWheelIfNewDay() {
    final now = TimeService.instance.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_wheelDay == null || _wheelDay != today) {
      _wheelDay = today;
      _wheelFreeUsed = false;
      _wheelAdUsed = 0;
    }
  }

  bool get canSpinWheelFree {
    _resetWheelIfNewDay();
    return !_wheelFreeUsed;
  }

  int get wheelAdSpinsRemaining {
    _resetWheelIfNewDay();
    return (wheelAdSpinsPerDay - _wheelAdUsed).clamp(0, wheelAdSpinsPerDay).toInt();
  }

  /// Ana menudeki kirmizi nokta: bugunku bedava cevirme hazir mi?
  bool get hasWheelReady => canSpinWheelFree;

  /// Ekranda gosterilecek seri (bugun bedava cevirdiyse bugun dahil).
  int get currentWheelStreak {
    _resetWheelIfNewDay();
    final today = _wheelDay!;
    final last = _wheelLastFreeDay;
    if (last == null) return 0;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (last == today) return wheelStreak;
    if (last == yesterday && wheelStreak < wheelStreakTarget) return wheelStreak;
    return 0;
  }

  /// Cevirir ve odulu HEMEN verir. Hak yoksa null. [viaAd]: reklamli
  /// cevirme (ancak bedava hak kullanildiktan sonra ve gunluk kota icinde).
  WheelResult? spinWheel({required bool viaAd}) {
    _resetWheelIfNewDay();
    var guaranteed = false;
    if (viaAd) {
      if (!_wheelFreeUsed || _wheelAdUsed >= wheelAdSpinsPerDay) return null;
      _wheelAdUsed++;
    } else {
      if (_wheelFreeUsed) return null;
      _wheelFreeUsed = true;
      final today = _wheelDay!;
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final last = _wheelLastFreeDay;
      final prev = (last != null && last == yesterday && wheelStreak < wheelStreakTarget) ? wheelStreak : 0;
      wheelStreak = prev + 1;
      _wheelLastFreeDay = today;
      guaranteed = wheelStreak >= wheelStreakTarget;
    }

    SeasonService.instance.addPoints(SeasonService.spWheel);
    final idx = LuckyWheel.pickIndex(_wheelRng, rareOnly: guaranteed);
    final slice = LuckyWheel.slices[idx];
    var coinsGained = 0;
    var gemsGained = 0;
    var energyFilled = false;
    BoosterType? booster;
    // Odul BURADA verilmez: cark donerken bakiye degismesin diye sadece
    // hesaplanir ve "bekleyen odul" olarak diske yazilir. Animasyon bitince
    // claimWheelPrize() uygular. (Uygulama donerken kapanirsa odul kaybolmaz,
    // bir sonraki acilista load() icinde verilir.)
    switch (slice.kind) {
      case WheelKind.coins:
        coinsGained = _withDailyBonus(slice.amount);
        break;
      case WheelKind.gems:
        gemsGained = slice.amount;
        break;
      case WheelKind.energy:
        energyFilled = true;
        break;
      case WheelKind.booster:
        booster = BoosterType.values[_wheelRng.nextInt(BoosterType.values.length)];
        break;
    }
    final result = WheelResult(
      sliceIndex: idx,
      coins: coinsGained,
      gems: gemsGained,
      energyFilled: energyFilled,
      booster: booster,
      guaranteed: guaranteed,
    );
    _wheelPending = result;
    _persist();
    return result;
  }

  WheelResult? _wheelPending;

  /// Cark animasyonu bitince cagrilir: bekleyen odulu bakiyeye ekler.
  void claimWheelPrize() {
    final r = _wheelPending;
    if (r == null) return;
    _wheelPending = null;
    coins += r.coins;
    gems += r.gems;
    if (r.energyFilled) {
      _regenEnergy();
      _energy = maxEnergy;
      _energyRegenStart = null;
    }
    final b = r.booster;
    if (b != null) _boosters[b] = boosterCount(b) + 1;
    _persist();
  }

  /// Bir bolum tamamlaninca cagrilir - bir sonraki bolumun kilidini acar
  /// (henuz oynanabilir olmasa bile, haritada ilerleme olarak gorunur).
  /// Son reportChapterComplete'te verilen bolge bitirme coin'i (0 = yok). Arayuz kutlama icin okur.
  int lastRegionBonusCoins = 0;

  void reportChapterComplete(int chapterNumber) {
    lastRegionBonusCoins = 0; // tekrar oynanan bolumde eski bolge odulu gorunmesin
    SeasonService.instance.addPoints(SeasonService.spChapter); // icinde seviye kontrolu var
    PiggyService.instance.add(PiggyService.rollChapterGems()); // icinde seviye kontrolu var
    if (chapterNumber >= maxUnlockedChapter) {
      maxUnlockedChapter = chapterNumber + 1;
      // BOSS bolumu ilk gecis odulu.
      if (ChapterConfig.kindFor(chapterNumber) == ChapterKind.boss) {
        gems += 3;
        coins += 500;
      }
      // v118: BOLGE BITIRME ODULU - bolgenin 8. bolumu ilk kez gecilince (ekonomiyi duzlestirmeden canlandirir).
      lastRegionBonusCoins = 0;
      if (isLastChapterOfRegion(chapterNumber)) {
        lastRegionBonusCoins = ((estChapterCoins(chapterNumber) * 3) / 50).round() * 50;
        coins += lastRegionBonusCoins;
        gems += 5;
      }
      // Ilk 3 bolumde ekstra hizli ilk odul (yeni oyuncu hemen tatmin olsun).
      if (chapterNumber >= 1 && chapterNumber <= 3) coins += const [150, 250, 400][chapterNumber - 1];
      // ilk kez gecilen bolum: kucuk mucevher odulu. Sadece ilk 20 bolumde
      // (sonrasinda bolumler sik gecildigi icin elmas enflasyonu olmasin).
      gems += (chapterNumber <= 20 ? chapterFirstClearGems : 0);
      if (chapterNumber % chapterMilestoneEvery == 0) gems += chapterMilestoneGems; // her 5. bolumde kilometre tasi odulu
      _persist();
    }
  }

  // ────────────────────────────────────────────────────────────
  // Bolum yildizlari (1-3) + oyuncu seviyesi (XP)
  // Yildiz: masayi ne kadar temiz tuttuguna gore (game_board.dart).
  // XP: her bolum bitiminde gelir; seviye atlayinca kutlama ekrani
  // ve odul (enerji dolumu + coin, her 5. seviyede +mucevher) verilir.
  // ────────────────────────────────────────────────────────────
  final Map<int, int> _chapterStars = {};
  int starsFor(int chapterNumber) => _chapterStars[chapterNumber] ?? 0;
  int get totalStars => _chapterStars.values.fold(0, (a, b) => a + b);

  /// En iyi yildizi saklar. Onceki en iyiden ONCE kac yildiz vardi'yi dondurur.
  int reportChapterStars(int chapterNumber, int stars) {
    final before = starsFor(chapterNumber);
    final s = stars.clamp(1, 3).toInt();
    if (s > before) {
      _chapterStars[chapterNumber] = s;
      _persist();
    }
    return before;
  }

  // XP bolumun BUYUKLUGUNE gore gelir (uzun bolum = daha cok XP):
  //  ilk gecis  = siparis sayisi + xpFirstClearBonus
  //  tekrar     = siparis sayisi / 2 + xpReplayBonus
  //  her yildiz = +xpPerStar
  static const int xpFirstClearBonus = 10;
  static const int xpReplayBonus = 4;
  static const int xpPerStar = 3;
  static int xpForChapter({required int goal, required bool firstClear, required int stars}) =>
      (firstClear ? goal + xpFirstClearBonus : goal ~/ 2 + xpReplayBonus) + stars * xpPerStar;

  int playerLevel = 1;

  /// Ozellik kilitleri (oyuncu seviyesi): acilana kadar menude gizli, ilerleme/puan toplanmaz.
  static const int missionsUnlockLevel = 5; // gunluk/haftalik/aylik gorevler
  static const int eventUnlockLevel = 7; // haftalik etkinlik
  static const int wheelUnlockLevel = 10; // sans carki
  static const int seasonUnlockLevel = 12; // sezon yolu
  static const int piggyUnlockLevel = 12; // kumbara
  // v126: Ogretici (rehberli tur) seviyeleri. Bu ozellikler menude hep gorunur; seviye sadece
  // turun NE ZAMAN cikacagini belirler (siradaki tek tur: Kasaba > Dukkan > Davet > Album > Gorev ...).
  static const int upgradesTourLevel = 2; // Dukkan (Hizli Atis / Sansli Baslangic / Slot)
  static const int inviteTourLevel = 3; // Arkadas daveti (Mesaj Kutusu > Davetler)
  static const int albumTourLevel = 4; // Album (set odulleri)
  bool get upgradesTourReady => playerLevel >= upgradesTourLevel;
  bool get inviteTourReady => playerLevel >= inviteTourLevel;
  bool get albumTourReady => playerLevel >= albumTourLevel;
  bool get missionsUnlocked => playerLevel >= missionsUnlockLevel;
  bool get eventUnlocked => playerLevel >= eventUnlockLevel;
  bool get wheelUnlocked => playerLevel >= wheelUnlockLevel;
  bool get seasonUnlocked => playerLevel >= seasonUnlockLevel;
  bool get piggyUnlocked => playerLevel >= piggyUnlockLevel;
  int playerXp = 0; // MEVCUT seviye icinde biriken XP
  static int xpNeededForLevel(int level) => 80 + (level - 1) * 40;
  static int levelUpCoins(int level) => 100 + level * 50;
  static int levelUpGems(int level) => level % 5 == 0 ? 3 : 0;
  double get levelProgress => (playerXp / xpNeededForLevel(playerLevel)).clamp(0.0, 1.0).toDouble();

  /// XP ekler. Atlanan her seviye icin odulu HEMEN verir ve
  /// [LevelUpReward] listesi dondurur (bos = seviye atlanmadi).
  List<LevelUpReward> addXp(int amount) {
    final rewards = <LevelUpReward>[];
    if (amount <= 0) return rewards;
    playerXp += amount;
    while (playerXp >= xpNeededForLevel(playerLevel)) {
      playerXp -= xpNeededForLevel(playerLevel);
      playerLevel++;
      final c = levelUpCoins(playerLevel);
      final g = levelUpGems(playerLevel);
      coins += c;
      gems += g;
      _energy = maxEnergy;
      _energyRegenStart = null;
      rewards.add(LevelUpReward(level: playerLevel, coins: c, gems: g, energyRefilled: true));
    }
    _persist();
    if (rewards.isNotEmpty) onLevelUp?.call();
    return rewards;
  }

  // ────────────────────────────────────────────────────────────
  // Gunluk odul + streak (retention #1)
  // 7 gunluk bir dongu: her gun biraz daha buyuk odul, 7. gun en
  // buyuk, sonra dongu tekrar 1. gunden baslar. Ust uste GELMEZSE
  // (bir gun atlanirsa) streak sifirlanir - klasik mobil oyun kalibi.
  // ────────────────────────────────────────────────────────────
  static const List<int> dailyRewardCoins = [50, 75, 100, 150, 200, 300, 500];

  DateTime? lastDailyRewardClaim;
  int dailyStreak = 0; // 0-6 arasi, dailyRewardCoins listesindeki index

  bool get canClaimDailyReward {
    final last = lastDailyRewardClaim;
    if (last == null) return true;
    final now = TimeService.instance.now();
    return !(now.year == last.year && now.month == last.month && now.day == last.day);
  }

  /// Iki tarih arasindaki TAKVIM gunu farki (yaz/kis saati kaymasindan etkilenmez).
  static int _dayDiff(DateTime a, DateTime b) =>
      DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

  /// Simdi alinirsa hangi gunun (index) odulu verilecek - claimDailyReward ile AYNI mantik.
  /// (v123: eskiden onizleme bir onceki gunun odulunu gosteriyordu.)
  int get pendingDailyIndex {
    final last = lastDailyRewardClaim;
    if (last == null) return dailyStreak;
    return _dayDiff(TimeService.instance.now(), last) == 1 ? dailyStreak + 1 : 0;
  }

  /// Simdi hak edilecek odul miktari - henuz claim edilmedi, sadece
  /// onizleme icin (buton uzerinde "+150 coin" gibi gostermek icin).
  int get nextDailyRewardAmount => _withDailyBonus(dailyRewardCoins[pendingDailyIndex % dailyRewardCoins.length]);

  /// Serinin 7. gunu (index 6) ek olarak mucevher verir.
  static int dailyGemsForIndex(int streak) =>
      (streak % dailyRewardCoins.length) == dailyRewardCoins.length - 1 ? dailyRewardDay7Gems : 0;
  int get nextDailyRewardGems => dailyGemsForIndex(pendingDailyIndex);

  // --- SERI KORUMA (v123) ---
  // Gunluk odul serisi 1-3 gun kacirilinca bozulur; en az 2 gunluk seri varsa elmasla (ya da 1 gun
  // kacirildiysa reklamla) kurtarilabilir. Kurtarma son alim tarihini "dun"e ceker, seri devam eder.
  static const int streakSaveMaxMissedDays = 3;
  static const int streakSaveGemBase = 20; // 1 gun kacirildiysa
  static const int streakSaveGemPerExtraDay = 10; // her ekstra gun icin

  /// Son odul alimindan bu yana KACIRILAN gun sayisi (dun geldiyse 0).
  int get dailyMissedDays {
    final last = lastDailyRewardClaim;
    if (last == null) return 0;
    final diff = _dayDiff(TimeService.instance.now(), last);
    return diff >= 2 ? diff - 1 : 0;
  }

  bool get canSaveDailyStreak {
    if (!canClaimDailyReward) return false;
    final m = dailyMissedDays;
    return dailyStreak >= 1 && m >= 1 && m <= streakSaveMaxMissedDays;
  }

  /// Reklamla kurtarma sadece TEK gun kacirildiysa.
  bool get canSaveDailyStreakWithAd => canSaveDailyStreak && dailyMissedDays == 1;

  int get dailyStreakSaveCost =>
      streakSaveGemBase + streakSaveGemPerExtraDay * (dailyMissedDays - 1).clamp(0, streakSaveMaxMissedDays - 1).toInt();

  void _linkDailyStreakToYesterday() {
    final now = TimeService.instance.now();
    lastDailyRewardClaim = DateTime(now.year, now.month, now.day - 1, 12);
  }

  /// Elmasla kurtar. Yetmezse / kosul yoksa false (hicbir sey degismez).
  bool saveDailyStreakWithGems() {
    if (!canSaveDailyStreak) return false;
    final cost = dailyStreakSaveCost;
    if (gems < cost) return false;
    _linkDailyStreakToYesterday();
    return spendGems(cost, 'streak_save'); // _persist burada
  }

  /// Reklam izlendikten sonra cagrilir (yalnizca tek gun kacirildiysa).
  bool saveDailyStreakFree() {
    if (!canSaveDailyStreakWithAd) return false;
    _linkDailyStreakToYesterday();
    _persist();
    return true;
  }

  /// Odulu alir, streak'i gunceller, coin ekler. canClaimDailyReward
  /// false ise hicbir sey yapmaz ve 0 doner.
  int claimDailyReward() {
    if (!canClaimDailyReward) return 0;
    final now = TimeService.instance.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = lastDailyRewardClaim;
    if (last != null) {
      final diff = _dayDiff(today, last);
      dailyStreak = (diff == 1) ? dailyStreak + 1 : 0; // ardisik geldiyse devam, aksi halde bastan
    }
    final amount = _withDailyBonus(dailyRewardCoins[dailyStreak % dailyRewardCoins.length]);
    coins += amount;
    gems += dailyGemsForIndex(dailyStreak);
    lastDailyRewardClaim = now;
    SeasonService.instance.addPoints(SeasonService.spDaily);
    _persist();
    return amount;
  }

  // ────────────────────────────────────────────────────────────
  // Gunluk gorevler (retention #2 + coin sink #3)
  // Sabit 3 gorev, her gun ilerlemesi sifirlanir. Basit ama etkili:
  // oyuncuya "bugun icin" somut, kucuk hedefler verir.
  //
  // NOT: Ayni 3 kategori (teslimat/birlestirme/coin) icin HAFTALIK ve
  // AYLIK versiyonlar da asagida ayni desende tanimlandi. Ucu de
  // reportOrderDelivered/reportMerge/reportCoinsEarned cagrildiginda
  // BIRLIKTE ilerler - her periyodun kendi hedefi/odulu/claim durumu
  // var, birbirinden bagimsiz sifirlanir.
  // ────────────────────────────────────────────────────────────
  static const int missionDeliverTarget = 40;
  static const int missionMergeTarget = 120;
  static const int missionCoinsTarget = 900;
  static const int missionDeliverReward = 150;
  static const int missionMergeReward = 120;
  static const int missionCoinsReward = 200;

  DateTime? _missionsResetDate;
  int missionDeliverProgress = 0;
  int missionMergeProgress = 0;
  int missionCoinsProgress = 0;
  bool missionDeliverClaimed = false;
  bool missionMergeClaimed = false;
  bool missionCoinsClaimed = false;

  static const int missionWeeklyDeliverTarget = 200;
  static const int missionWeeklyMergeTarget = 650;
  static const int missionWeeklyCoinsTarget = 5500;
  static const int missionWeeklyDeliverReward = 800;
  static const int missionWeeklyMergeReward = 600;
  static const int missionWeeklyCoinsReward = 1000;

  DateTime? _weeklyMissionsResetDate; // o haftanin Pazartesi'si (saat/dakikasiz)
  int missionWeeklyDeliverProgress = 0;
  int missionWeeklyMergeProgress = 0;
  int missionWeeklyCoinsProgress = 0;
  bool missionWeeklyDeliverClaimed = false;
  bool missionWeeklyMergeClaimed = false;
  bool missionWeeklyCoinsClaimed = false;

  static const int missionMonthlyDeliverTarget = 800;
  static const int missionMonthlyMergeTarget = 2600;
  static const int missionMonthlyCoinsTarget = 22000;
  static const int missionMonthlyDeliverReward = 3000;
  static const int missionMonthlyMergeReward = 2200;
  static const int missionMonthlyCoinsReward = 4000;

  DateTime? _monthlyMissionsResetDate; // o ayin 1'i (saat/dakikasiz)
  int missionMonthlyDeliverProgress = 0;
  int missionMonthlyMergeProgress = 0;
  int missionMonthlyCoinsProgress = 0;
  bool missionMonthlyDeliverClaimed = false;
  bool missionMonthlyMergeClaimed = false;
  bool missionMonthlyCoinsClaimed = false;

  /// Gun degistiyse (son sifirlamadan bu yana takvim gunu ilerlediyse)
  /// tum gorev ilerlemesini/claim durumunu sifirlar. Her rapor/claim
  /// cagrisindan once calisir, boylece gun donumunu kacirmaz.
  void _resetMissionsIfNewDay() {
    final now = TimeService.instance.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_missionsResetDate == null || _missionsResetDate != today) {
      _missionsResetDate = today;
      missionDeliverProgress = 0;
      missionMergeProgress = 0;
      missionCoinsProgress = 0;
      missionDeliverClaimed = false;
      missionMergeClaimed = false;
      missionCoinsClaimed = false;
    }
  }

  /// Verilen tarihin ait oldugu haftanin Pazartesi gununu (saat/dakikasiz)
  /// dondurur - haftalik gorevlerin sabit bir sifirlama noktasi olmasi icin.
  static DateTime _startOfWeek(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1)); // Pazartesi = 1
  }

  /// Hafta degistiyse (son sifirlamadan bu yana Pazartesi ilerlediyse)
  /// tum haftalik gorev ilerlemesini/claim durumunu sifirlar.
  void _resetWeeklyMissionsIfNewWeek() {
    final currentWeekStart = _startOfWeek(TimeService.instance.now());
    if (_weeklyMissionsResetDate == null || _weeklyMissionsResetDate != currentWeekStart) {
      _weeklyMissionsResetDate = currentWeekStart;
      missionWeeklyDeliverProgress = 0;
      missionWeeklyMergeProgress = 0;
      missionWeeklyCoinsProgress = 0;
      missionWeeklyDeliverClaimed = false;
      missionWeeklyMergeClaimed = false;
      missionWeeklyCoinsClaimed = false;
    }
  }

  /// Ay degistiyse (son sifirlamadan bu yana takvim ayi ilerlediyse)
  /// tum aylik gorev ilerlemesini/claim durumunu sifirlar.
  void _resetMonthlyMissionsIfNewMonth() {
    final now = TimeService.instance.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    if (_monthlyMissionsResetDate == null || _monthlyMissionsResetDate != currentMonthStart) {
      _monthlyMissionsResetDate = currentMonthStart;
      missionMonthlyDeliverProgress = 0;
      missionMonthlyMergeProgress = 0;
      missionMonthlyCoinsProgress = 0;
      missionMonthlyDeliverClaimed = false;
      missionMonthlyMergeClaimed = false;
      missionMonthlyCoinsClaimed = false;
    }
  }

  /// Dis dunyaya (UI) gorevleri gostermeden once cagrilmali - gun/hafta/
  /// ay donumunu kontrol edip gerekiyorsa ilgili seti sifirlar.
  void refreshMissions() {
    _resetMissionsIfNewDay();
    _resetWeeklyMissionsIfNewWeek();
    _resetMonthlyMissionsIfNewMonth();
  }

  void reportOrderDelivered() {
    SeasonService.instance.addPoints(SeasonService.spOrder);
    WeeklyEvent.instance.report(EventKind.orders, 1);
    if (!missionsUnlocked) return;
    _resetMissionsIfNewDay();
    _resetWeeklyMissionsIfNewWeek();
    _resetMonthlyMissionsIfNewMonth();
    if (!missionDeliverClaimed) missionDeliverProgress++;
    if (!missionWeeklyDeliverClaimed) missionWeeklyDeliverProgress++;
    if (!missionMonthlyDeliverClaimed) missionMonthlyDeliverProgress++;
    _persist();
  }

  void reportMerge() {
    WeeklyEvent.instance.report(EventKind.merges, 1);
    if (!missionsUnlocked) return;
    _resetMissionsIfNewDay();
    _resetWeeklyMissionsIfNewWeek();
    _resetMonthlyMissionsIfNewMonth();
    if (!missionMergeClaimed) missionMergeProgress++;
    if (!missionWeeklyMergeClaimed) missionWeeklyMergeProgress++;
    if (!missionMonthlyMergeClaimed) missionMonthlyMergeProgress++;
    _persist();
  }

  /// 3+ zincir birlestirme (kombo) gerceklesince cagrilir.
  void reportCombo() {
    WeeklyEvent.instance.report(EventKind.combos, 1);
  }

  void reportCoinsEarned(int amount) {
    if (!missionsUnlocked) return;
    _resetMissionsIfNewDay();
    _resetWeeklyMissionsIfNewWeek();
    _resetMonthlyMissionsIfNewMonth();
    if (!missionCoinsClaimed) missionCoinsProgress += amount;
    if (!missionWeeklyCoinsClaimed) missionWeeklyCoinsProgress += amount;
    if (!missionMonthlyCoinsClaimed) missionMonthlyCoinsProgress += amount;
    _persist();
  }

  bool claimDeliverMission() {
    _resetMissionsIfNewDay();
    if (missionDeliverClaimed || missionDeliverProgress < missionDeliverTarget) return false;
    missionDeliverClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionDeliverReward;
    _persist();
    return true;
  }

  bool claimMergeMission() {
    _resetMissionsIfNewDay();
    if (missionMergeClaimed || missionMergeProgress < missionMergeTarget) return false;
    missionMergeClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionMergeReward;
    _persist();
    return true;
  }

  bool claimCoinsMission() {
    _resetMissionsIfNewDay();
    if (missionCoinsClaimed || missionCoinsProgress < missionCoinsTarget) return false;
    missionCoinsClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionCoinsReward;
    _persist();
    return true;
  }

  bool claimWeeklyDeliverMission() {
    _resetWeeklyMissionsIfNewWeek();
    if (missionWeeklyDeliverClaimed || missionWeeklyDeliverProgress < missionWeeklyDeliverTarget) return false;
    missionWeeklyDeliverClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionWeeklyDeliverReward;
    gems += weeklyMissionGems;
    _persist();
    return true;
  }

  bool claimWeeklyMergeMission() {
    _resetWeeklyMissionsIfNewWeek();
    if (missionWeeklyMergeClaimed || missionWeeklyMergeProgress < missionWeeklyMergeTarget) return false;
    missionWeeklyMergeClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionWeeklyMergeReward;
    gems += weeklyMissionGems;
    _persist();
    return true;
  }

  bool claimWeeklyCoinsMission() {
    _resetWeeklyMissionsIfNewWeek();
    if (missionWeeklyCoinsClaimed || missionWeeklyCoinsProgress < missionWeeklyCoinsTarget) return false;
    missionWeeklyCoinsClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionWeeklyCoinsReward;
    gems += weeklyMissionGems;
    _persist();
    return true;
  }

  bool claimMonthlyDeliverMission() {
    _resetMonthlyMissionsIfNewMonth();
    if (missionMonthlyDeliverClaimed || missionMonthlyDeliverProgress < missionMonthlyDeliverTarget) return false;
    missionMonthlyDeliverClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionMonthlyDeliverReward;
    gems += monthlyMissionGems;
    _persist();
    return true;
  }

  bool claimMonthlyMergeMission() {
    _resetMonthlyMissionsIfNewMonth();
    if (missionMonthlyMergeClaimed || missionMonthlyMergeProgress < missionMonthlyMergeTarget) return false;
    missionMonthlyMergeClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionMonthlyMergeReward;
    gems += monthlyMissionGems;
    _persist();
    return true;
  }

  bool claimMonthlyCoinsMission() {
    _resetMonthlyMissionsIfNewMonth();
    if (missionMonthlyCoinsClaimed || missionMonthlyCoinsProgress < missionMonthlyCoinsTarget) return false;
    missionMonthlyCoinsClaimed = true;
    SeasonService.instance.addPoints(SeasonService.spMission);
    coins += missionMonthlyCoinsReward;
    gems += monthlyMissionGems;
    _persist();
    return true;
  }

  // ────────────────────────────────────────────────────────────
  // Enerji sistemi
  // Maks 5 enerji, her bölüm (kazan/kaybet fark etmez) 1 enerji
  // harcar. Pasif dolum: 10 dakikada 1 enerji. Aktif dolum: ana
  // menüdeki "Enerji Doldur" butonundan tek tek reklam izleyerek -
  // her reklam +1 enerji, 2 saatlik pencerede en fazla 5 reklam
  // (enerji zaten doluysa saymaz). 5. reklamdan sonra 2 saatlik bir
  // kilit başlar, süre dolunca kota sıfırlanır.
  //
  // NOT: Gerçek zamanlı (TimeService = internet saati bazlı) hesaplanıyor, tıpkı
  // günlük ödül/görevler gibi. _energy/_energyRegenStart/
  // _energyAdWatchesUsed/_energyAdCooldownStart artik spendEnergy()/
  // claimEnergyAdReward() sonunda _persist() ile diske yazilip
  // load()'da geri okunuyor - mantığın kendisi değişmedi.
  // ────────────────────────────────────────────────────────────
  static const int maxEnergy = 5;
  static const Duration energyRegenInterval = Duration(minutes: 10);
  static const int maxEnergyAdWatches = 5;
  static const Duration energyAdCooldown = Duration(hours: 2);

  int _energy = maxEnergy;
  // Enerji maksimumun ALTINA ilk düştüğü an - bir sonraki dolum
  // tikinin ne zaman geleceğini buradan hesaplıyoruz. Enerji tekrar
  // tam dolunca null'a döner (dolum sayacı durur).
  DateTime? _energyRegenStart;

  int _energyAdWatchesUsed = 0;
  DateTime? _energyAdCooldownStart;

  /// Gecen sureye gore biriken enerjiyi hesaba katar. Her enerji
  /// okuma/harcama isleminden once cagrilir, boylece oyuncu ne zaman
  /// bakarsa baksin dogru deger gorunur (arka planda "tick" isleyen
  /// bir zamanlayiciya ihtiyac yok).
  void _regenEnergy() {
    if (_energy >= maxEnergy) {
      _energyRegenStart = null;
      return;
    }
    final now = TimeService.instance.now();
    var start = _energyRegenStart;
    if (start == null) {
      _energyRegenStart = now;
      return;
    }
    // Kayitli baslangic "gelecekte" ise (eski cihaz saati ileri alinmisti,
    // simdi internet saatine gecildi) enerji yillarca dolmasin diye
    // baslangici simdiye cek.
    if (start.isAfter(now)) {
      start = now;
      _energyRegenStart = now;
    }
    final elapsedMinutes = now.difference(start).inMinutes;
    final intervalMinutes = energyRegenInterval.inMinutes;
    final gained = elapsedMinutes ~/ intervalMinutes;
    if (gained <= 0) return;
    _energy = (_energy + gained).clamp(0, maxEnergy).toInt();
    if (_energy >= maxEnergy) {
      _energyRegenStart = null;
    } else {
      // Kalan (henuz bir sonraki enerjiye tam donmemis) sureyi
      // korumak icin baslangici sadece TUKETILEN tik kadar ileri al.
      _energyRegenStart = start.add(Duration(minutes: gained * intervalMinutes));
    }
  }

  /// Su anki enerji miktari (pasif dolum otomatik hesaba katilir).
  int get energy {
    _regenEnergy();
    return _energy;
  }

  bool get hasEnergy => energy > 0;

  /// Bir sonraki enerjinin dolmasina ne kadar kaldi. Enerji zaten
  /// doluysa null doner.
  Duration? get timeUntilNextEnergy {
    _regenEnergy();
    if (_energy >= maxEnergy) return null;
    final start = _energyRegenStart;
    if (start == null) return energyRegenInterval;
    final remaining = energyRegenInterval - TimeService.instance.now().difference(start);
    if (remaining.isNegative) return Duration.zero;
    return remaining > energyRegenInterval ? energyRegenInterval : remaining;
  }

  /// Bir bolum bitince (kazan ya da kaybet) cagrilir. Enerji yoksa
  /// false doner (cagiran taraf zaten oncesinde hasEnergy kontrolu
  /// yapmis olmali - bu son bir guvenlik agi).
  bool spendEnergy() {
    _regenEnergy();
    if (_energy <= 0) return false;
    if (_energy == maxEnergy) _energyRegenStart = TimeService.instance.now();
    _energy -= 1;
    _persist();
    return true;
  }

  void _refreshEnergyAdQuota() {
    final start = _energyAdCooldownStart;
    if (start == null) return;
    final now = TimeService.instance.now();
    if (start.isAfter(now)) {
      // Gelecege tasmis kayit (bkz. _regenEnergy) - kilidi simdiden baslat.
      _energyAdCooldownStart = now;
      return;
    }
    if (now.difference(start) >= energyAdCooldown) {
      _energyAdWatchesUsed = 0;
      _energyAdCooldownStart = null;
    }
  }

  /// 2 saatlik penceredeki kalan reklam-izleme hakki (0-5).
  int get energyAdWatchesRemaining {
    _refreshEnergyAdQuota();
    return (maxEnergyAdWatches - _energyAdWatchesUsed).clamp(0, maxEnergyAdWatches).toInt();
  }

  /// Kota tukenmisse 2 saatlik kilidin ne kadarinin kaldigi, aksi
  /// halde null.
  Duration? get energyAdCooldownRemaining {
    _refreshEnergyAdQuota();
    final start = _energyAdCooldownStart;
    if (start == null) return null;
    final remaining = energyAdCooldown - TimeService.instance.now().difference(start);
    if (remaining.isNegative) return Duration.zero;
    return remaining > energyAdCooldown ? energyAdCooldown : remaining;
  }

  /// Ana menudeki "Enerji Doldur" butonu su an tiklanabilir mi -
  /// hem enerji dolu OLMAMALI hem de kotadan hak kalmis olmali.
  bool get canWatchEnergyAd => energy < maxEnergy && energyAdWatchesRemaining > 0;

  /// Reklam basariyla izlendikten SONRA cagrilir (ana menu "Enerji
  /// Doldur" akisi) - +1 enerji verir ve kotadan 1 dusurur. 5.
  /// izlemeden sonra otomatik olarak 2 saatlik kilit baslar.
  bool claimEnergyAdReward() {
    if (!canWatchEnergyAd) return false;
    _energy = (_energy + 1).clamp(0, maxEnergy).toInt();
    if (_energy >= maxEnergy) _energyRegenStart = null;
    _energyAdWatchesUsed += 1;
    if (_energyAdWatchesUsed >= maxEnergyAdWatches) {
      _energyAdCooldownStart = TimeService.instance.now();
    }
    _persist();
    return true;
  }
}

/// Seviye atlama kutlamasinda gosterilen odul ozeti.
class LevelUpReward {
  final int level;
  final int coins;
  final int gems;
  final bool energyRefilled;
  const LevelUpReward({
    required this.level,
    required this.coins,
    required this.gems,
    required this.energyRefilled,
  });
}


/// Elmasla alinan coin paketi tanimi (miktar ilerlemeye gore hesaplanir).
class CoinPackDef {
  final String id;
  final int gems;
  final double days; // kac gunluk tahmini coin geliri
  final bool best;
  const CoinPackDef(this.id, this.gems, this.days, {this.best = false});
}
