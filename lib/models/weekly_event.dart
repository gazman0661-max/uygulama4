import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/time_service.dart';
import 'game_progress.dart';
import 'season.dart';

import '../services/log_service.dart';
/// HAFTALIK ETKINLIK: her hafta (Pzt-Paz) donen, 5 kilometre tasli yaris.
/// Tur haftaya gore degisir: siparis / birlestirme / kombo.
/// HAFTA SONU (Cmt 10:00 - Pzt 10:00, 48 saat): etkinlik puani VE sezon puani 2 KAT.
/// v228: hafta Pazartesi 10:00'da degisir (00:00'da degil), hafta sonu penceresi de 10:00'da acilir/kapanir.
/// Kayit: 'events_v1'. Tum sayilar asagida ayarlanabilir.
enum EventKind { orders, merges, combos }

class WeeklyEvent {
  WeeklyEvent._();
  static final WeeklyEvent instance = WeeklyEvent._();

  static const String _key = 'events_v1';
  static const int weekendMultiplier = 2;
  static const int startHour = 10; // hafta/hafta sonu sinir saati (PlanetEvent.startHour ile ayni)

  /// [n]'i [startHour] saat geri alir; hafta numarasi ve hafta sonu bu kaydirilmis takvimle hesaplanir.
  static DateTime _shift(DateTime n) => DateTime(n.year, n.month, n.day, n.hour - startHour, n.minute, n.second);

  static const Map<EventKind, List<int>> milestones = {
    EventKind.orders: [30, 80, 160, 260, 380],
    EventKind.merges: [100, 260, 480, 760, 1100],
    EventKind.combos: [10, 30, 60, 100, 160],
  };

  static const List<SeasonReward> rewards = [
    SeasonReward(coins: 500),
    SeasonReward(gems: 5, booster: BoosterType.aimGuide),
    SeasonReward(coins: 1200, gems: 5),
    SeasonReward(gems: 10, booster: BoosterType.revive, boosterCount: 2),
    SeasonReward(gems: 30, coins: 3000),
  ];

  int _weekId = -1;
  int points = 0;
  final Set<int> _claimed = {};

  static DateTime _now() => TimeService.instance.now();

  static int _weekIdNow() {
    final n = _shift(_now());
    final d = DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2024, 1, 1)).inDays;
    return d ~/ 7; // 2024-01-01 bir Pazartesi (hafta Pzt 10:00'da doner)
  }

  void _roll() {
    final id = _weekIdNow();
    if (id != _weekId) {
      _weekId = id;
      points = 0;
      _claimed.clear();
      save();
    }
  }

  EventKind get kind {
    _roll();
    return EventKind.values[_weekId % EventKind.values.length];
  }

  List<int> get targets => milestones[kind]!;

  bool get isWeekend => _shift(_now()).weekday >= DateTime.saturday; // Cmt 10:00 - Pzt 10:00

  /// Sezon/etkinlik puani carpani (hafta sonu 2, aksi 1).
  int get spMultiplier => isWeekend ? weekendMultiplier : 1;

  Duration get timeLeft {
    final n = _now();
    final s = _shift(n);
    final end = DateTime(s.year, s.month, s.day + (8 - s.weekday), startHour); // siradaki Pzt 10:00
    return end.difference(n);
  }

  void report(EventKind k, int amount) {
    if (amount <= 0 || k != kind || !GameProgress.instance.eventUnlocked) return;
    points += amount * spMultiplier;
    save();
  }

  bool isClaimed(int i) => _claimed.contains(i);
  bool canClaim(int i) {
    _roll();
    return i >= 0 && i < targets.length && points >= targets[i] && !_claimed.contains(i);
  }

  /// Tum kilometre tasi odulleri alindi mi?
  bool get allClaimed {
    _roll();
    return _claimed.length >= targets.length;
  }

  bool get hasClaimable {
    for (var i = 0; i < targets.length; i++) {
      if (canClaim(i)) return true;
    }
    return false;
  }

  /// Siradaki hedef (hepsi bittiyse son hedef).
  int get nextTarget {
    for (final t in targets) {
      if (points < t) return t;
    }
    return targets.last;
  }

  SeasonReward? claim(int i) {
    if (!canClaim(i)) return null;
    _claimed.add(i);
    final r = rewards[i];
    GameProgress.instance.grantReward(
      coins: r.coins,
      gems: r.gems,
      energy: r.energy,
      booster: r.booster,
      boosterAmount: r.boosterCount,
    );
    save();
    return r;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _weekId = j['week'] as int? ?? -1;
        points = j['points'] as int? ?? 0;
        _claimed
          ..clear()
          ..addAll((j['claimed'] as List? ?? const []).whereType<int>());
      }
      AppLog.i('weekly_event.load', 'yuklendi puan=$points');
    } catch (err) { AppLog.w('weekly_event.load', 'yutulan hata', err); }
    _roll();
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({'week': _weekId, 'points': points, 'claimed': _claimed.toList()}),
      );
    } catch (err) { AppLog.w('weekly_event.save', 'yutulan hata', err); }
  }
}
