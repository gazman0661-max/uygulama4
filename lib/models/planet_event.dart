import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/log_service.dart';
import '../services/merge_board_service.dart';
import '../services/time_service.dart';
import 'game_progress.dart';

/// Etkinlik odulu: coin, mucevher ve Mod 2 (Surukle-Birak) enerjisi.
class PlanetReward {
  final int coins;
  final int gems;
  final int energy; // Mod 2 enerjisi
  const PlanetReward({this.coins = 0, this.gems = 0, this.energy = 0});

  bool get isEmpty => coins == 0 && gems == 0 && energy == 0;

  PlanetReward operator +(PlanetReward o) =>
      PlanetReward(coins: coins + o.coins, gems: gems + o.gems, energy: energy + o.energy);
}

/// Bir etkinlik gorevi. [target] sayac hedefi; ilerleme [PlanetEvent.progressOf] ile okunur.
class PlanetTask {
  final String id;
  final int target;
  final PlanetReward reward;
  const PlanetTask(this.id, this.target, this.reward);
}

/// HAFTA SONU ETKINLIGI: "Gezegen Birlestir" (Cumartesi 00:00 - Pazar 23:59, 48 saat).
///
/// - Giris ENERJIYLE: en fazla 3 enerji, her oyun 1 enerji, 45 dk'da 1 enerji dolar.
///   Isteyen bekler; isteyen reklam izler (hepsi dolar) ya da 50 mucevher harcar (hepsi dolar).
/// - Gorevler etkinlik BOYUNCA birikir (oyunlar arasi): Neptun / Uranus / Saturn'e ulas,
///   3 kez x6 kombo, toplam 2500 birlestirme, tek oyunda 4200 puan, etkinlikte TOPLAM 350.000 puan.
/// - Her gorevin odulu "Al" ile alinir; 7 gorevin hepsi bitince buyuk odul.
/// - Etkinlik bitince alinmamis (tamamlanmis) oduller bir sonraki acilista OTOMATIK hesaba eklenir.
/// Kayit: 'planet_event_v1' (bulut kaydina dahil, bkz. SaveMerge.planetEvent).
/// Tum sayilar asagida ayarlanabilir.
class PlanetEvent {
  PlanetEvent._();
  static final PlanetEvent instance = PlanetEvent._();

  static const String _key = 'planet_event_v1';
  static const String _noteKey = 'planet_event_note_v1'; // cihaza ozel, buluta gitmez

  // ------------------------------------------------------------ ayarlar
  static const int maxEnergy = 3;
  static const int regenMinutes = 45;
  static const int gemRefillCost = 50;

  /// Bir etkinlikte reklamla en fazla kac kez dolum yapilabilir (2 gun x 3).
  static const int maxAdRefills = 6;

  static const int targetCombo = 6; // "x6 kombo"
  static const int targetMerges = 2500;
  static const int targetScore = 4200;
  static const int targetTotalScore = 350000; // etkinlik boyunca tum oyunlarin toplam puani

  static const List<PlanetTask> tasks = [
    PlanetTask('neptune', 1, PlanetReward(coins: 800)),
    PlanetTask('uranus', 1, PlanetReward(gems: 10, energy: 20)),
    PlanetTask('saturn', 1, PlanetReward(coins: 2000, gems: 15)),
    PlanetTask('combo', 3, PlanetReward(coins: 1000, energy: 30)),
    PlanetTask('merges', targetMerges, PlanetReward(coins: 1500, gems: 20)),
    PlanetTask('score', targetScore, PlanetReward(coins: 1500, energy: 30)),
    // v216: SONA eklendi (alinan gorev indeksleri 'cl' icinde saklanir; siralama bozulmasin).
    PlanetTask('total', targetTotalScore, PlanetReward(coins: 5000, gems: 40, energy: 50)),
  ];

  /// Hepsi tamamlaninca verilen buyuk odul.
  static const PlanetReward grandReward = PlanetReward(coins: 3000, gems: 50, energy: 60);

  // ------------------------------------------------------- test icin enjeksiyon
  /// "Simdi" kaynagi (testte degistirilir).
  static DateTime Function() clock = () => TimeService.instance.now();

  /// Odul verme (testte degistirilir).
  static void Function(PlanetReward r, String source) deliver = _defaultDeliver;

  /// Kayit sonrasi bulut yuklemesini tetikler (main.dart baglar). save() BILEREK tetiklemez.
  static void Function()? onSaved;

  static void _defaultDeliver(PlanetReward r, String source) {
    if (r.coins > 0 || r.gems > 0) {
      GameProgress.instance.grantReward(coins: r.coins, gems: r.gems);
    }
    if (r.energy > 0) MergeBoardService.instance.grantEnergy(r.energy, source: source);
  }

  // ------------------------------------------------------------ durum
  int _weekId = -1;
  int bestTier = 0;
  int totalMerges = 0;
  int bestScore = 0;
  int totalScore = 0; // etkinlik boyunca TUM oyunlarin toplam puani (v216)
  int _runScoreSeen = 0; // bu oyunda toplama eklenmis puan (kalici degil)
  int combo6 = 0;
  int games = 0;
  int adRefills = 0;
  int _energy = maxEnergy;
  int _regenStartMs = 0;
  final Set<int> _claimed = {};
  bool grandClaimed = false;
  Timer? _debounce;

  // ------------------------------------------------------------ zaman
  static DateTime _now() => clock();

  /// Pazartesi baslangicli hafta numarasi (2024-01-01 bir Pazartesi).
  static int weekIdOf(DateTime n) =>
      DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2024, 1, 1)).inDays ~/ 7;

  /// Etkinlik acik mi (Cumartesi-Pazar)?
  static bool isActiveAt(DateTime n) => n.weekday >= DateTime.saturday;

  bool get isActive => isActiveAt(_now());

  /// Bu haftanin Cumartesi 00:00'i (hafta sonundaysa gecen/su anki Cumartesi).
  static DateTime startOf(DateTime n) => DateTime(n.year, n.month, n.day + (DateTime.saturday - n.weekday));

  /// Etkinligin bitisi: Pazartesi 00:00.
  static DateTime endOf(DateTime n) => DateTime(n.year, n.month, n.day + (8 - n.weekday));

  /// Acikken: bitisine kalan; kapaliyken: baslamasina kalan.
  Duration get timeLeft {
    final n = _now();
    return isActiveAt(n) ? endOf(n).difference(n) : startOf(n).difference(n);
  }

  // ------------------------------------------------------------ hafta degisimi
  void _roll() {
    final id = weekIdOf(_now());
    if (id == _weekId) return;
    if (_weekId >= 0) _autoDeliverOld();
    _weekId = id;
    bestTier = 0;
    totalMerges = 0;
    bestScore = 0;
    totalScore = 0;
    _runScoreSeen = 0;
    combo6 = 0;
    games = 0;
    adRefills = 0;
    _energy = maxEnergy;
    _regenStartMs = 0;
    _claimed.clear();
    grandClaimed = false;
    AppLog.i('planet', 'yeni hafta=$id: etkinlik durumu sifirlandi');
    save();
  }

  /// Biten etkinligin tamamlanmis ama alinmamis odullerini hesaba ekler.
  void _autoDeliverOld() {
    var total = const PlanetReward();
    for (var i = 0; i < tasks.length; i++) {
      if (_done(i) && !_claimed.contains(i)) total = total + tasks[i].reward;
    }
    if (_allDone && !grandClaimed) total = total + grandReward;
    if (total.isEmpty) return;
    try {
      deliver(total, 'planet_auto');
      AppLog.i('planet', 'OTOMATIK TESLIM (etkinlik bitti): coin=${total.coins} elmas=${total.gems} enerji=${total.energy}');
      AnalyticsService.instance.log('pe_auto_deliver', {'coins': total.coins, 'gems': total.gems, 'energy': total.energy});
      _saveNote(total);
    } catch (err) {
      AppLog.w('planet._autoDeliverOld', 'yutulan hata', err);
    }
  }

  Future<void> _saveNote(PlanetReward r) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_noteKey, jsonEncode({'c': r.coins, 'g': r.gems, 'e': r.energy}));
    } catch (err) {
      AppLog.w('planet._saveNote', 'yutulan hata', err);
    }
  }

  /// Menuye donuste "Etkinlik odulleri hesabina eklendi" bildirimi icin (tek seferlik).
  Future<PlanetReward?> takeDeliveryNote() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_noteKey);
      if (raw == null || raw.isEmpty) return null;
      await p.remove(_noteKey);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return PlanetReward(
        coins: (j['c'] as num?)?.toInt() ?? 0,
        gems: (j['g'] as num?)?.toInt() ?? 0,
        energy: (j['e'] as num?)?.toInt() ?? 0,
      );
    } catch (err) {
      AppLog.w('planet.takeDeliveryNote', 'yutulan hata', err);
      return null;
    }
  }

  // ------------------------------------------------------------ enerji
  int _nowMs() => _now().millisecondsSinceEpoch;

  /// Yenilenmeyi isler ve guncel enerjiyi dondurur. Yenilenme yalnizca etkinlik acikken ilerler.
  int get energy {
    _roll();
    _regen();
    return _energy;
  }

  void _regen() {
    if (_energy >= maxEnergy) {
      _energy = maxEnergy;
      _regenStartMs = 0;
      return;
    }
    final now = _now();
    // Etkinlik kapaliyken yenilenme yok (hafta degisince enerji zaten tam dolu baslar).
    if (!isActiveAt(now)) return;
    if (_regenStartMs == 0) return; // sayac henuz baslamadi (enerji harcaninca baslar)
    const stepMs = regenMinutes * 60 * 1000;
    final gained = (now.millisecondsSinceEpoch - _regenStartMs) ~/ stepMs;
    if (gained <= 0) return;
    _energy = math.min(maxEnergy, _energy + gained);
    _regenStartMs = _energy >= maxEnergy ? 0 : _regenStartMs + gained * stepMs;
  }

  /// Siradaki enerjiye kalan sure (enerji doluysa null).
  Duration? get nextEnergyIn {
    if (energy >= maxEnergy || _regenStartMs == 0) return null;
    const stepMs = regenMinutes * 60 * 1000;
    final left = _regenStartMs + stepMs - _nowMs();
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  bool get canPlay => isActive && energy >= 1;

  /// Yeni bir oyun baslatir: 1 enerji harcar. Etkinlik kapaliysa ya da enerji yoksa false.
  bool startRun() {
    _roll();
    _regen();
    if (!isActive || _energy < 1) {
      AppLog.w('planet', 'startRun reddedildi: aktif=$isActive enerji=$_energy');
      return false;
    }
    _energy--;
    if (_regenStartMs == 0) _regenStartMs = _nowMs();
    games++;
    _runScoreSeen = 0; // yeni oyun: puan sayaci bastan
    AppLog.i('planet', 'OYUN BASLADI #$games enerji=$_energy');
    AnalyticsService.instance.log('pe_run_start', {'games': games, 'energy': _energy});
    _persist();
    return true;
  }

  /// Mucevherle tum enerjiyi doldurur (50 mucevher). Yeterli mucevher yoksa / enerji doluysa false.
  bool refillWithGems() {
    if (!isActive || energy >= maxEnergy) return false;
    if (!GameProgress.instance.spendGems(gemRefillCost, 'planet_energy')) {
      AppLog.w('planet', 'ELMAS DOLUM REDDEDILDI: elmas yetmiyor (${GameProgress.instance.gems}/$gemRefillCost)');
      return false;
    }
    _fill();
    AppLog.i('planet', 'ELMASLA DOLUM: -$gemRefillCost elmas');
    AnalyticsService.instance.log('pe_refill_gems', {'cost': gemRefillCost});
    return true;
  }

  int get adRefillsLeft => math.max(0, maxAdRefills - adRefills);

  bool get canAdRefill => isActive && energy < maxEnergy && adRefills < maxAdRefills;

  /// Odullu reklam izlendikten SONRA cagrilir: tum enerjiyi doldurur.
  bool refillAfterAd() {
    if (!canAdRefill) return false;
    adRefills++;
    _fill();
    AppLog.i('planet', 'REKLAMLA DOLUM ($adRefills/$maxAdRefills)');
    AnalyticsService.instance.log('pe_refill_ad', {'n': adRefills});
    return true;
  }

  void _fill() {
    _energy = maxEnergy;
    _regenStartMs = 0;
    _persist();
  }

  // ------------------------------------------------------------ oyun ilerlemesi
  /// Her birlesmede cagrilir. [newTier] olusan kademe (-1: en ust iki gezegen yok oldu),
  /// [combo] zincirdeki sira.
  void onMerge(int newTier, int combo) {
    _roll();
    totalMerges++;
    if (newTier > bestTier) bestTier = newTier;
    if (combo == targetCombo) combo6++; // zincir 6'ya ulastiginda BIR kez sayilir
    _persist();
  }

  /// Oyun puani degistikce cagrilir (tek oyundaki en iyi puan).
  /// Ayrica oyundaki puan artisi TOPLAM puana eklenir (oyun basina yalnizca yeni artis).
  void onScore(int runScore) {
    _roll();
    var changed = false;
    if (runScore > _runScoreSeen) {
      totalScore += runScore - _runScoreSeen;
      _runScoreSeen = runScore;
      changed = true;
    }
    if (runScore > bestScore) {
      bestScore = runScore;
      changed = true;
    }
    if (changed) _persist();
  }

  // ------------------------------------------------------------ gorevler
  int progressOf(int i) {
    _roll();
    return _rawProgress(i);
  }

  /// _roll() ICINDEN de guvenle cagrilir (hafta degismeden onceki degerleri okur).
  int _rawProgress(int i) {
    switch (tasks[i].id) {
      case 'neptune':
        return bestTier >= 7 ? 1 : 0;
      case 'uranus':
        return bestTier >= 8 ? 1 : 0;
      case 'saturn':
        return bestTier >= 9 ? 1 : 0;
      case 'combo':
        return combo6;
      case 'merges':
        return totalMerges;
      case 'score':
        return bestScore;
      case 'total':
        return totalScore;
    }
    return 0;
  }

  bool _done(int i) => _rawProgress(i) >= tasks[i].target;

  bool get _allDone {
    for (var i = 0; i < tasks.length; i++) {
      if (!_done(i)) return false;
    }
    return true;
  }

  bool isDone(int i) {
    _roll();
    return _done(i);
  }

  bool isClaimed(int i) {
    _roll();
    return _claimed.contains(i);
  }

  bool canClaim(int i) {
    _roll();
    return i >= 0 && i < tasks.length && _done(i) && !_claimed.contains(i);
  }

  bool get allDone {
    _roll();
    return _allDone;
  }

  bool get canClaimGrand {
    _roll();
    return _allDone && !grandClaimed;
  }

  bool get hasClaimable {
    _roll();
    for (var i = 0; i < tasks.length; i++) {
      if (canClaim(i)) return true;
    }
    return canClaimGrand;
  }

  /// Menudeki ikonda gosterilecek rozet: etkinlik acik ve (alinacak odul var ya da enerji var).
  bool get hasBadge => isActive && (hasClaimable || energy >= 1);

  PlanetReward? claim(int i) {
    if (!canClaim(i)) return null;
    _claimed.add(i);
    final r = tasks[i].reward;
    deliver(r, 'planet_task');
    AppLog.i('planet', 'GOREV ODULU: ${tasks[i].id} coin=${r.coins} elmas=${r.gems} enerji=${r.energy}');
    AnalyticsService.instance.log('pe_claim', {'task': tasks[i].id});
    save();
    onSaved?.call();
    return r;
  }

  PlanetReward? claimGrand() {
    if (!canClaimGrand) return null;
    grandClaimed = true;
    deliver(grandReward, 'planet_grand');
    AppLog.i('planet', 'BUYUK ODUL alindi');
    AnalyticsService.instance.log('pe_claim', {'task': 'grand'});
    save();
    onSaved?.call();
    return grandReward;
  }

  // ------------------------------------------------------------ kalicilik
  Map<String, dynamic> toJson() => {
        'w': _weekId,
        'bt': bestTier,
        'tm': totalMerges,
        'bs': bestScore,
        'ts': totalScore,
        'c6': combo6,
        'g': games,
        'ar': adRefills,
        'e': _energy,
        'rs': _regenStartMs,
        'cl': _claimed.toList()..sort(),
        'gc': grandClaimed,
      };

  void applyJson(Map<String, dynamic> j) {
    int n(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    _weekId = n('w', -1);
    bestTier = n('bt', 0);
    totalMerges = n('tm', 0);
    bestScore = n('bs', 0);
    totalScore = n('ts', 0);
    combo6 = n('c6', 0);
    games = n('g', 0);
    adRefills = n('ar', 0);
    _energy = n('e', maxEnergy).clamp(0, maxEnergy).toInt();
    _regenStartMs = n('rs', 0);
    _claimed
      ..clear()
      ..addAll((j['cl'] as List? ?? const []).whereType<num>().map((e) => e.toInt()));
    grandClaimed = j['gc'] == true;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        applyJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      AppLog.i('planet.load', 'yuklendi hafta=$_weekId birlestirme=$totalMerges enSkor=$bestScore enKademe=$bestTier enerji=$_energy');
    } catch (err) {
      AppLog.w('planet.load', 'yutulan hata', err);
    }
    _roll();
  }

  /// Bulut esitlemesinin icinden de cagrilir: bu yuzden onSaved TETIKLEMEZ.
  Future<void> save() async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (err) {
      AppLog.w('planet.save', 'yutulan hata', err);
    }
  }

  /// Oyun akisindan gelen degisiklikler: kisa gecikmeyle yazar ve buluta yuklemeyi tetikler.
  void _persist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      await save();
      onSaved?.call();
    });
  }

  /// Ekrandan cikarken bekleyen yazimi hemen yap.
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      await save();
      onSaved?.call();
    }
  }

  /// Test: durumu sifirla.
  void resetForTest() {
    _debounce?.cancel();
    _weekId = -1;
    bestTier = 0;
    totalMerges = 0;
    bestScore = 0;
    totalScore = 0;
    _runScoreSeen = 0;
    combo6 = 0;
    games = 0;
    adRefills = 0;
    _energy = maxEnergy;
    _regenStartMs = 0;
    _claimed.clear();
    grandClaimed = false;
  }
}
