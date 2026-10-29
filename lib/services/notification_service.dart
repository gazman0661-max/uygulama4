import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../models/live_events.dart';
import '../models/planet_event.dart';
import '../models/season.dart';
import '../models/piggy.dart';
import '../models/town.dart';
import '../models/weekly_event.dart';
import 'time_service.dart';

import 'log_service.dart';
/// Yerel bildirimler (sunucu yok). Uygulama arka plana gidince
/// [scheduleAll] ile ilerideki bildirimler planlanir, oyuna donunce
/// [cancelAll] ile silinir (oyundayken bildirim gelmez).
///
///  1) Enerji doldu        2) Cark + gunluk odul hazir
///  3) Sezon bitiyor       4) Seni ozledik (3 gun sonra)
///  5) Haftalik etkinlik bitiyor   6) Kumbara dolu
///  7) Canli yarislar (Merge/Firlat) + Hafta Sonu etkinligi: "basladi" ve "bitiyor" (puani varsa)
/// Sessiz saatler: 22:00-09:00 arasina denk gelenler 09:00'a kaydirilir.
/// Zamanlar mutlak ani (UTC) hedefler; saat dilimi paketi verisi gerekmez.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _askedKey = 'notif_asked_v1';
  static const String _channelId = 'merge_main';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
      );
      _ready = true;
    } catch (e) {
      AppLog.e('notification_service.InitializationSettings', 'hata', e);
      debugPrint('NotificationService: baslatilamadi: $e');
    }
  }

  /// Izni (Android 13+) yalnizca bir kez, uygun bir anda ister.
  Future<void> requestPermissionOnce() async {
    if (!_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;
      await prefs.setBool(_askedKey, true);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      AppLog.e('notification_service.requestPermissionOnce', 'hata', e);
      debugPrint('NotificationService: izin istenemedi: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (err) { AppLog.w('notification_service.cancelAll', 'yutulan hata', err); }
  }

  DateTime _quiet(DateTime t) {
    if (t.hour >= 22) return DateTime(t.year, t.month, t.day + 1, 9);
    if (t.hour < 9) return DateTime(t.year, t.month, t.day, 9);
    return t;
  }

  Future<void> _schedule(int id, DateTime when, String title, String body) async {
    final now = TimeService.instance.now();
    if (!when.isAfter(now.add(const Duration(seconds: 30)))) return;
    // TimeService.now() cihaz saatine gore ofsetlenmis olabilir; farki
    // gercek saate ceviriyoruz.
    final delay = when.difference(now);
    final at = tz.TZDateTime.now(tz.UTC).add(delay);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Worlds Merge',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            // Oyunun renkli ikonu (res/drawable-nodpi/ic_notif_large.png); kucuk ikon: ic_stat_notify.
            largeIcon: DrawableResourceAndroidBitmap('ic_notif_large'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      AppLog.e('notification_service.NotificationDetails', 'hata', e);
      debugPrint('NotificationService: planlanamadi ($id): $e');
    }
  }

  static const int _liveStartBase = 20; // 20..31: canli etkinlik "basladi"
  static const int _liveEndBase = 40; // 40..51: canli etkinlik "bitiyor"
  static const int _planetStartId = 60;
  static const int _planetEndId = 61;

  String _liveName(EventDef d) {
    final s = AppStrings.instance;
    final t = d.titleFor(s.language.name);
    if (t.isNotEmpty) return t;
    if (d.titleKey.isNotEmpty) return s.lt(d.titleKey);
    return d.id;
  }

  /// "Bitiyor" bildirimi: bitisten 3 saat once; sessiz saate denk gelirse kaydirilir, bitisten sonraya
  /// kaliyorsa atlanir.
  DateTime? _endWarn(DateTime end) {
    final t = _quiet(end.subtract(const Duration(hours: 3)));
    return t.isBefore(end.subtract(const Duration(minutes: 30))) ? t : null;
  }

  /// Her canli etkinlik icin: siradaki kosunun "basladi" bildirimi + acik kosuda (puani varsa) "bitiyor".
  Future<void> _scheduleLiveEvents(AppStrings s, DateTime now) async {
    final le = LiveEvents.instance;
    final defs = le.defs;
    for (var i = 0; i < defs.length && i < 12; i++) {
      final d = defs[i];
      final name = _liveName(d);
      final next = d.nextRunAfter(now);
      if (next >= 0) {
        await _schedule(_liveStartBase + i, _quiet(d.startOfRun(next)), s.lt('{0} is live! 🎉', [name]),
            s.lt('Jump in, reach the goals and win rewards!'));
      }
      final run = d.runIdAt(now);
      if (run != null && le.score(d) > 0) {
        final warn = _endWarn(d.endOfRun(run));
        if (warn != null) {
          await _schedule(_liveEndBase + i, warn, s.lt('{0} ends soon ⏳', [name]),
              s.lt('Last chance! Boost your score and finish your goals.'));
        }
      }
    }
  }

  /// Hafta Sonu etkinligi (Gezegen Birlestir): Cumartesi "basladi", Pazar aksami "bitiyor" (buyuk odul alinmadiysa).
  Future<void> _schedulePlanetEvent(DateTime now) async {
    final s = AppStrings.instance;
    final pe = PlanetEvent.instance;
    final name = s.lt('Weekend Event');
    if (!pe.isActive) {
      await _schedule(_planetStartId, _quiet(now.add(pe.timeLeft)), s.lt('{0} is live! 🎉', [name]),
          s.lt('Jump in, reach the goals and win rewards!'));
    } else if (!pe.grandClaimed) {
      final warn = _endWarn(now.add(pe.timeLeft));
      if (warn != null) {
        await _schedule(_planetEndId, warn, s.lt('{0} ends soon ⏳', [name]),
            s.lt('Last chance! Boost your score and finish your goals.'));
      }
    }
  }

  /// Uygulama arka plana giderken cagrilir.
  Future<void> scheduleAll() async {
    if (!_ready) return;
    await cancelAll();
    final s = AppStrings.instance;
    final gp = GameProgress.instance;
    final now = TimeService.instance.now();

    // 1) Enerji tam dolunca
    final next = gp.timeUntilNextEnergy;
    if (next != null) {
      final missing = GameProgress.maxEnergy - gp.energy - 1;
      final full = next + GameProgress.energyRegenInterval * (missing < 0 ? 0 : missing);
      await _schedule(1, _quiet(now.add(full)), s.t('notif_energy_title'), s.t('notif_energy_body'));
    }

    // 2) Yarin sabah: cark + gunluk odul
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 10);
    await _schedule(2, tomorrow, s.t('notif_daily_title'), s.t(gp.wheelUnlocked ? 'notif_daily_body' : 'notif_daily_body_nowheel'));

    // 3) Sezon bitmeden 2 gun once (tamamlanmadiysa)
    final ss = SeasonService.instance;
    if (gp.seasonUnlocked && ss.tier < SeasonService.tierCount) {
      final end = now.add(ss.timeLeft);
      final warn = DateTime(end.year, end.month, end.day - 2, 19);
      await _schedule(3, warn, s.t('notif_season_title'), s.t('notif_season_body'));
    }

    // 3a) Haftalik etkinlik bitmeden ~5 saat once (Pazar 19:00), oduller tamamlanmadiysa
    final ev = WeeklyEvent.instance;
    if (gp.eventUnlocked && !ev.allClaimed) {
      final end = now.add(ev.timeLeft);
      final warn = end.subtract(const Duration(hours: 5));
      await _schedule(5, warn, s.t('notif_event_title'), s.t('notif_event_body'));
    }

    // 3c) Kumbara doluysa ertesi gun 18:00 hatirlat
    if (gp.piggyUnlocked && PiggyService.instance.isFull) {
      final t = DateTime(now.year, now.month, now.day + 1, 18);
      await _schedule(6, t, s.t('notif_piggy_title'), s.t('notif_piggy_body'));
    }

    // 3b) Kasaba insaati bitince (CoC tarzi) - bina basina ayri bildirim
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      final end = gp.townUpgradeEndMs[w];
      if (end <= 0) continue;
      await _schedule(
        10 + w,
        DateTime.fromMillisecondsSinceEpoch(end),
        AppStrings.instance.lt('Construction complete! 🏗️'),
        AppStrings.instance.lt('{0} upgrade is done. Time to start the next one!', [s.t('town_b$w')]),
      );
    }

    // 3d) Canli yarislar + Hafta Sonu etkinligi: basladi / bitiyor
    if (gp.eventUnlocked) {
      await _scheduleLiveEvents(s, now);
      await _schedulePlanetEvent(now);
    }

    // 4) 3 gun gelmezse
    final back = DateTime(now.year, now.month, now.day + 3, 19);
    await _schedule(4, back, s.t('notif_back_title'), s.t('notif_back_body'));
  }
}
