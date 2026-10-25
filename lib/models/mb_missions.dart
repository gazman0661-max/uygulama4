import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/log_service.dart';
import '../services/time_service.dart';
import 'game_progress.dart';
import 'season.dart';

/// MOD 2 GOREVLERI (merge tahtasi): gunluk / haftalik / aylik, her donemde 3 gorev.
/// Mod 1 gorevlerinden (GameProgress.mission*) BAGIMSIZ sayaclar; Gorevler ekraninda ikinci bolum.
///
///  * Ham "birlestir" sayilmaz (Mod 2'de her uretimde birlesme olur, dakikalar icinde biterdi):
///    yalniz Lv5+ birlestirmeler, biten bolum/dunya, teslim ve harcanan enerji sayilir.
///  * Oduller Mod 1'in yaklasik yarisi (coin ~%55, elmas ~%40): iki set birlikte ekonomiyi
///    sisirmesin. Sayilar asagidaki [defs] icinde tek yerde.
///  * Kayit kendi anahtariyla ('mb_missions_v1'), CIHAZA OZEL (bulut birlestirmesine girmez).
///  * Mod 1 ile ayni kural: gorevler [GameProgress.missionsUnlocked] seviyesinde acilir.
enum MbPeriod { daily, weekly, monthly }

enum MbMetric { chapters, orders, bigMerges, energy, maxItems, worlds }

class MbMissionDef {
  final String id;
  final MbPeriod period;
  final MbMetric metric;
  final int target;
  final int coins;
  final int gems;
  const MbMissionDef(this.id, this.period, this.metric, this.target, this.coins, [this.gems = 0]);
}

class MbMissions {
  MbMissions._();
  static final MbMissions instance = MbMissions._();

  static const String _key = 'mb_missions_v1';

  /// Lv5 ve ustu birlestirme "buyuk birlestirme" sayilir.
  static const int bigMergeLevel = 5;

  /// Yalniz testler icin: gorev acilis seviyesini yok say.
  static bool debugIgnoreUnlock = false;

  static const List<MbMissionDef> defs = [
    // Gunluk (Mod 1: 150 / 120 / 200)
    MbMissionDef('d_chapters', MbPeriod.daily, MbMetric.chapters, 1, 80),
    MbMissionDef('d_orders', MbPeriod.daily, MbMetric.orders, 8, 60),
    MbMissionDef('d_big', MbPeriod.daily, MbMetric.bigMerges, 3, 100),
    // Haftalik (Mod 1: 800 / 600 / 1000 + 5 elmas her biri)
    MbMissionDef('w_chapters', MbPeriod.weekly, MbMetric.chapters, 6, 500, 2),
    MbMissionDef('w_energy', MbPeriod.weekly, MbMetric.energy, 120, 400, 2),
    MbMissionDef('w_max', MbPeriod.weekly, MbMetric.maxItems, 1, 600, 2),
    // Aylik (Mod 1: 3000 / 2200 / 4000 + 15 elmas her biri)
    MbMissionDef('m_chapters', MbPeriod.monthly, MbMetric.chapters, 24, 2000, 6),
    MbMissionDef('m_worlds', MbPeriod.monthly, MbMetric.worlds, 1, 1500, 6),
    MbMissionDef('m_orders', MbPeriod.monthly, MbMetric.orders, 150, 1500, 6),
  ];

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
    return false;
  }

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
  }

  // ── Raporlama (MergeBoardService cagirir) ──────────────────
  void report(MbMetric metric, [int amount = 1]) {
    if (amount <= 0) return;
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
    GameProgress.instance.addBonusCoins(d.coins);
    if (d.gems > 0) GameProgress.instance.addGems(d.gems);
    SeasonService.instance.addPoints(SeasonService.spMbMission);
    AppLog.i('mod2', 'MOD2 GOREV odulu alindi: $id +${d.coins} coin +${d.gems} elmas');
    AnalyticsService.instance.log('mb_mission_claim', {'id': id, 'period': d.period.name});
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

  void _saveNow() {
    _saveTimer?.cancel();
    SharedPreferences.getInstance().then((p) => p.setString(_key, jsonEncode(toJson()))).catchError((Object e) {
      AppLog.w('mod2', 'MOD2 gorev kaydi yazilamadi: $e');
      return false;
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
