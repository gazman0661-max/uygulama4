import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/log_service.dart';
import '../services/merge_board_service.dart';
import '../services/time_service.dart';
import 'game_progress.dart';
import 'season.dart';

/// MOD 2 GOREVLERI (merge tahtasi): gunluk (4) / haftalik (5) / aylik (5) + her donemin SANDIGI.
/// Mod 1 gorevlerinden (GameProgress.mission*) BAGIMSIZ sayaclar; Gorevler ekraninda ayni listede, Mod 2 ustte.
///
///  * Ham "birlestir" sayilmaz (Mod 2'de her uretimde birlesme olur): yalniz Lv5+ birlestirmeler,
///    biten bolum/dunya, teslim, harcanan enerji, cark cevirme ve "farkli gun" sayilir.
///  * v187 TASARIM KURALI: haftalik gorevler TEK GUNDE bitmesin diye en az bir "farkli gun" gorevi
///    (w_days) + yuksek enerji hedefi (w_energy) var; aylik icin m_days. Gunluk oynayan haftaligi 5-6 gunde,
///    aylıgi ayin 22-25. gununde bitirir.
///  * Oduller yalniz coin degil: elmas + Mod 2 enerjisi. Her donemin tum gorevleri alininca SANDIK acilir
///    (aylik sandik = buyuk, gorunur odul).
///  * Kayit kendi anahtariyla ('mb_missions_v1'), bulut birlestirmesi on eke ('d_','w_','m_') gore calisir:
///    sandik kimligi ('d_chest' ...) alinmis listesine, "son aktif gun" damgasi ('d_active_stamp') sayaclara yazilir.
///  * Mod 1 ile ayni kural: gorevler [GameProgress.missionsUnlocked] seviyesinde acilir.
enum MbPeriod { daily, weekly, monthly }

enum MbMetric { chapters, orders, bigMerges, energy, maxItems, worlds, activeDays, wheel, ruleChapters, specialChapters, chainItems }

class MbMissionDef {
  final String id;
  final MbPeriod period;
  final MbMetric metric;
  final int target;
  final int coins;
  final int gems;
  final int energy; // Mod 2 enerjisi (⚡)
  const MbMissionDef(this.id, this.period, this.metric, this.target, this.coins, {this.gems = 0, this.energy = 0});
}

/// Bir donemin tum gorevleri alininca acilan sandik.
class MbChestDef {
  final MbPeriod period;
  final int coins;
  final int gems;
  final int energy;
  const MbChestDef(this.period, {this.coins = 0, this.gems = 0, this.energy = 0});
}

class MbMissions {
  MbMissions._();
  static final MbMissions instance = MbMissions._();

  static const String _key = 'mb_missions_v1';

  /// "Son sayilan gun" damgasi (yyyymmdd) - sayaclar haritasinda tutulur ki bulut birlestirmesinde (max) kaybolmasin.
  static const String _activeStamp = 'd_active_stamp';

  /// Lv5 ve ustu birlestirme "buyuk birlestirme" sayilir.
  static const int bigMergeLevel = 5;

  /// Yalniz testler icin: gorev acilis seviyesini yok say.
  static bool debugIgnoreUnlock = false;

  static const List<MbMissionDef> defs = [
    // ── Gunluk: ~15-25 dk'lik oturumda biter. (Mod 1 toplam: 470 coin)
    MbMissionDef('d_chapters', MbPeriod.daily, MbMetric.chapters, 1, 120),
    MbMissionDef('d_energy', MbPeriod.daily, MbMetric.energy, 50, 0, energy: 20),
    MbMissionDef('d_big', MbPeriod.daily, MbMetric.bigMerges, 4, 100),
    MbMissionDef('d_wheel', MbPeriod.daily, MbMetric.wheel, 1, 60, gems: 1),
    // ── Haftalik: CESITLILIK (bolum sayma yok). Tek gunde BITMEZ: farkli gun + ozel/kurallı bolum bekleme.
    // (Mod 1 toplam: 2400 coin + 15 elmas)
    MbMissionDef('w_rule', MbPeriod.weekly, MbMetric.ruleChapters, 2, 400, gems: 2),
    MbMissionDef('w_special', MbPeriod.weekly, MbMetric.specialChapters, 1, 500, gems: 3, energy: 40),
    MbMissionDef('w_chain', MbPeriod.weekly, MbMetric.chainItems, 15, 300, gems: 2, energy: 60),
    MbMissionDef('w_max', MbPeriod.weekly, MbMetric.maxItems, 1, 500, gems: 2),
    MbMissionDef('w_days', MbPeriod.weekly, MbMetric.activeDays, 5, 300, gems: 5),
    // ── Aylik: BUYUK HEDEFLER. (Mod 1 toplam: 9200 coin + 45 elmas)
    MbMissionDef('m_worlds', MbPeriod.monthly, MbMetric.worlds, 4, 1500, gems: 8),
    MbMissionDef('m_special', MbPeriod.monthly, MbMetric.specialChapters, 6, 1500, gems: 8, energy: 100),
    MbMissionDef('m_orders', MbPeriod.monthly, MbMetric.orders, 300, 1200, gems: 6, energy: 100),
    MbMissionDef('m_max', MbPeriod.monthly, MbMetric.maxItems, 8, 1500, gems: 8),
    MbMissionDef('m_days', MbPeriod.monthly, MbMetric.activeDays, 22, 800, gems: 15),
  ];

  /// Donem sandiklari (tum gorevler alininca). Aylik = buyuk gorunur odul.
  static const List<MbChestDef> chests = [
    MbChestDef(MbPeriod.daily, gems: 2, energy: 30),
    MbChestDef(MbPeriod.weekly, coins: 800, gems: 15, energy: 100),
    MbChestDef(MbPeriod.monthly, coins: 3000, gems: 60, energy: 200),
  ];

  static MbChestDef chestOf(MbPeriod p) => chests.firstWhere((c) => c.period == p);
  static String chestId(MbPeriod p) => '${p.name[0]}_chest'; // d_chest / w_chest / m_chest

  static List<MbMissionDef> defsFor(MbPeriod p) => [for (final d in defs) if (d.period == p) d];

  /// Ceviri anahtari (Ingilizce kalip; {0} = ilerleme, {1} = hedef).
  static String labelKey(MbMetric m) {
    switch (m) {
      case MbMetric.chapters:
        return 'Chapters completed {0}/{1}';
      case MbMetric.orders:
        return 'Orders delivered {0}/{1}';
      case MbMetric.bigMerges:
        return 'Lv5+ merges {0}/{1}';
      case MbMetric.energy:
        return 'Energy spent ⚡ {0}/{1}';
      case MbMetric.maxItems:
        return 'Max-level items made {0}/{1}';
      case MbMetric.worlds:
        return 'Worlds completed {0}/{1}';
      case MbMetric.activeDays:
        return 'Days played {0}/{1}';
      case MbMetric.wheel:
        return 'Wheel spins {0}/{1}';
      case MbMetric.ruleChapters:
        return 'Rule chapters completed {0}/{1}';
      case MbMetric.specialChapters:
        return 'Special chapters completed {0}/{1}';
      case MbMetric.chainItems:
        return 'Deliver items from side producers {0}/{1}';
    }
  }

  // ── Durum ──────────────────────────────────────────────────
  final Map<String, int> _progress = {};
  final Set<String> _claimed = {};
  DateTime? _dayRef;
  DateTime? _weekRef;
  DateTime? _monthRef;
  Timer? _saveTimer;

  int progressOf(String id) => _progress[id] ?? 0;
  bool isClaimed(String id) => _claimed.contains(id);

  bool isReady(MbMissionDef d) => !isClaimed(d.id) && progressOf(d.id) >= d.target;

  /// Ana menu Gorevler ikonundaki kirmizi nokta icin: alinmayi bekleyen Mod 2 gorevi var mi?
  bool get hasClaimable {
    _rollover();
    for (final d in defs) {
      if (isReady(d)) return true;
    }
    for (final p in MbPeriod.values) {
      if (isChestReady(p)) return true;
    }
    return false;
  }

  /// Bu donemde alinmis gorev sayisi (sandik ilerlemesi).
  int claimedCount(MbPeriod p) => defsFor(p).where((d) => isClaimed(d.id)).length;

  bool isChestClaimed(MbPeriod p) => _claimed.contains(chestId(p));

  bool isChestReady(MbPeriod p) => !isChestClaimed(p) && claimedCount(p) == defsFor(p).length;

  /// Donemin bitmesine kalan sure (arayuzdeki "yenilenir" yazisi icin).
  Duration timeLeft(MbPeriod p) {
    final now = TimeService.instance.now();
    final DateTime next;
    switch (p) {
      case MbPeriod.daily:
        next = DateTime(now.year, now.month, now.day + 1);
        break;
      case MbPeriod.weekly:
        next = _startOfWeek(now).add(const Duration(days: 7));
        break;
      case MbPeriod.monthly:
        next = DateTime(now.year, now.month + 1, 1);
        break;
    }
    return next.difference(now);
  }

  /// Ekran acilirken / menu cizilirken: donem donumu + "bugun giris yapildi" sayimi.
  void refresh() => _rollover();

  // ── Donem donumu ───────────────────────────────────────────
  static DateTime _startOfWeek(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1)); // Pazartesi
  }

  void _clearPeriod(MbPeriod p) {
    for (final d in defs) {
      if (d.period == p) {
        _progress.remove(d.id);
        _claimed.remove(d.id);
      }
    }
    _claimed.remove(chestId(p));
  }

  /// Gun/hafta/ay degistiyse ilgili donemin ilerlemesini ve alinma durumunu sifirlar.
  void _rollover() {
    final now = TimeService.instance.now();
    final day = DateTime(now.year, now.month, now.day);
    final week = _startOfWeek(now);
    final month = DateTime(now.year, now.month, 1);
    var changed = false;
    if (_dayRef != day) {
      if (_dayRef != null) _clearPeriod(MbPeriod.daily);
      _dayRef = day;
      changed = true;
    }
    if (_weekRef != week) {
      if (_weekRef != null) _clearPeriod(MbPeriod.weekly);
      _weekRef = week;
      changed = true;
    }
    if (_monthRef != month) {
      if (_monthRef != null) _clearPeriod(MbPeriod.monthly);
      _monthRef = month;
      changed = true;
    }
    if (changed) _scheduleSave();
    _touchActiveDay(now);
  }

  /// "Farkli gun" gorevleri: gorevler acikken her takvim gunu icin tek sefer +1 (saat hilesine karsi TimeService).
  void _touchActiveDay(DateTime now) {
    if (!debugIgnoreUnlock && !GameProgress.instance.missionsUnlocked) return;
    final stamp = now.year * 10000 + now.month * 100 + now.day;
    if (progressOf(_activeStamp) >= stamp) return;
    _progress[_activeStamp] = stamp;
    for (final d in defs) {
      if (d.metric == MbMetric.activeDays && !isClaimed(d.id)) {
        _progress[d.id] = progressOf(d.id) + 1;
        if (progressOf(d.id) >= d.target) {
          AnalyticsService.instance.log('mb_mission_done', {'id': d.id, 'period': d.period.name});
        }
      }
    }
    _scheduleSave();
  }

  // ── Raporlama (MergeBoardService cagirir) ──────────────────
  void report(MbMetric metric, [int amount = 1]) {
    if (amount <= 0 || metric == MbMetric.activeDays) return; // "farkli gun" yalniz _touchActiveDay ile artar
    if (!debugIgnoreUnlock && !GameProgress.instance.missionsUnlocked) return;
    _rollover();
    for (final d in defs) {
      if (d.metric == metric && !isClaimed(d.id)) {
        final wasReady = progressOf(d.id) >= d.target;
        _progress[d.id] = progressOf(d.id) + amount;
        if (!wasReady && progressOf(d.id) >= d.target) {
          AppLog.i('mod2', 'MOD2 GOREV tamamlandi: ${d.id} (${progressOf(d.id)}/${d.target})');
          AnalyticsService.instance.log('mb_mission_done', {'id': d.id, 'period': d.period.name});
        }
      }
    }
    _scheduleSave();
  }

  /// Odulu al: coin cuzdana (gorev/sezon sayacina girmez), elmas, sezon puani.
  bool claim(String id) {
    _rollover();
    final d = defs.where((e) => e.id == id).firstOrNull;
    if (d == null || !isReady(d)) {
      AppLog.w('mod2', 'MOD2 GOREV odulu reddedildi: $id');
      return false;
    }
    _claimed.add(id);
    if (d.coins > 0) GameProgress.instance.addBonusCoins(d.coins);
    if (d.gems > 0) GameProgress.instance.addGems(d.gems);
    if (d.energy > 0) MergeBoardService.instance.grantEnergy(d.energy, source: 'gorev');
    SeasonService.instance.addPoints(SeasonService.spMbMissionFor(d.period));
    AppLog.i('mod2', 'MOD2 GOREV odulu alindi: $id +${d.coins} coin +${d.gems} elmas +${d.energy} enerji');
    AnalyticsService.instance.log('mb_mission_claim', {'id': id, 'period': d.period.name});
    _saveNow();
    return true;
  }

  /// Donem sandigini ac: tum gorevler alinmis olmali.
  bool claimChest(MbPeriod p) {
    _rollover();
    if (!isChestReady(p)) {
      AppLog.w('mod2', 'MOD2 SANDIK reddedildi: ${p.name}');
      return false;
    }
    final c = chestOf(p);
    _claimed.add(chestId(p));
    if (c.coins > 0) GameProgress.instance.addBonusCoins(c.coins);
    if (c.gems > 0) GameProgress.instance.addGems(c.gems);
    if (c.energy > 0) MergeBoardService.instance.grantEnergy(c.energy, source: 'sandik');
    SeasonService.instance.addPoints(SeasonService.spMbChestFor(p));
    AppLog.i('mod2', 'MOD2 SANDIK acildi: ${p.name} +${c.coins} coin +${c.gems} elmas +${c.energy} enerji');
    AnalyticsService.instance.log('mb_chest_claim', {'period': p.name});
    _saveNow();
    return true;
  }

  // ── Kayit ──────────────────────────────────────────────────
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) {
          final p = j['p'];
          if (p is Map) {
            _progress
              ..clear()
              ..addAll({
                for (final e in p.entries)
                  if (e.value is num) e.key.toString(): (e.value as num).toInt(),
              });
          }
          final c = j['c'];
          if (c is List) {
            _claimed
              ..clear()
              ..addAll(c.whereType<String>());
          }
          _dayRef = DateTime.tryParse('${j['d']}');
          _weekRef = DateTime.tryParse('${j['w']}');
          _monthRef = DateTime.tryParse('${j['m']}');
        }
      }
    } catch (e) {
      AppLog.w('mod2', 'MOD2 gorev kaydi okunamadi: $e');
    }
    _rollover();
    AppLog.i('mod2', 'MOD2 gorevler yuklendi: ${_progress.length} ilerleme, ${_claimed.length} alinan');
  }

  Map<String, dynamic> toJson() => {
        'p': _progress,
        'c': _claimed.toList(),
        'd': _dayRef?.toIso8601String(),
        'w': _weekRef?.toIso8601String(),
        'm': _monthRef?.toIso8601String(),
      };

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  /// Buluta yuklemeden / birlestirmeden once: bekleyen yazimi hemen diske yazar.
  Future<void> flush() async {
    _saveTimer?.cancel();
    if (_dayRef == null && _progress.isEmpty && _claimed.isEmpty) return; // yazacak bir sey yok
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(toJson()));
    } catch (e) {
      AppLog.w('mod2', 'MOD2 gorev kaydi yazilamadi: $e');
    }
  }

  /// Oyun akisindan gelen gorev kaydi yazilinca Play Games bulut yuklemesini tetikler
  /// (main.dart baglar). flush() BILEREK tetiklemez: bulut esitlemesinin icinden cagrilir.
  static void Function()? onSaved;

  void _saveNow() {
    _saveTimer?.cancel();
    SharedPreferences.getInstance().then((p) => p.setString(_key, jsonEncode(toJson()))).then((_) {
      onSaved?.call();
    }).catchError((Object e) {
      AppLog.w('mod2', 'MOD2 gorev kaydi yazilamadi: $e');
    });
  }

  /// Test: durumu sifirla.
  void resetForTest() {
    _progress.clear();
    _claimed.clear();
    _dayRef = null;
    _weekRef = null;
    _monthRef = null;
    _saveTimer?.cancel();
  }
}
