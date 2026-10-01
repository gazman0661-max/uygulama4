import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int notifyHour = 12;
  static const int notifyMinute = 0;

  static const String _localePrefsKey = 'app_language';

  static const int _inactivityBaseId = 1002000;
  static const List<int> _inactivityStageDays = [3, 7, 14, 30];
  static const int _updateReminderBaseId = 2000000;
  static const int _domainPendingBaseId = 3000000;
  static const int _domainRenewalWarnBaseId = 5000000;
  static const int _domainRenewalExpiredBaseId = 6000000;
  static const int _dailyVisitorCheckInId = 7000000;
  static const int _miniPackageWarnBaseId = 10000000;
  static const int _miniPackageExpiredBaseId = 11000000;

  Future<void> init() async {
    if (_initialized) return;

    try {
      tzdata.initializeTimeZones();
      try {
        final deviceTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTz.identifier));
      } catch (_) {
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (e, st) {
      debugPrint('NotificationService.init() başarısız (yok sayılıyor): $e\n$st');
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'sitora_general',
          'Sitora Bildirimleri',
          channelDescription:
              'Kota, proje ve davet hatırlatmaları — yalnızca gündüz saatlerinde gönderilir.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<bool> _isEnglish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localePrefsKey);
      if (code != null) return code == 'en';
    } catch (_) {
    }
    try {
      final deviceCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      return deviceCode != 'tr';
    } catch (_) {
      return false;
    }
  }

  tz.TZDateTime _nextNoon({int daysFromNow = 0}) {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      notifyHour,
      notifyMinute,
    ).add(Duration(days: daysFromNow));

    if (daysFromNow == 0 && target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  tz.TZDateTime? _noonOnDate(DateTime date) {
    final now = tz.TZDateTime.now(tz.local);
    final target = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      notifyHour,
      notifyMinute,
    );
    if (target.isBefore(now)) return null;
    return target;
  }

  Future<void> cancelLegacyMonthlyQuotaNotification() async {
    try {
      await init();
      await _plugin.cancel(1001);
    } catch (e, st) {
      debugPrint('cancelLegacyMonthlyQuotaNotification başarısız (yok sayılıyor): $e\n$st');
    }
  }

  Future<void> scheduleInactivityReminderSeries() async {
    try {
      await init();
      final isEn = await _isEnglish();
      for (var i = 0; i < _inactivityStageDays.length; i++) {
        await _plugin.cancel(_inactivityBaseId + i);
      }
      for (var i = 0; i < _inactivityStageDays.length; i++) {
        final days = _inactivityStageDays[i];
        final content = _inactivityStageContent(days: days, isEn: isEn);
        await _plugin.zonedSchedule(
          _inactivityBaseId + i,
          content.title,
          content.body,
          _nextNoon(daysFromNow: days),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e, st) {
      debugPrint(
          'scheduleInactivityReminderSeries başarısız (yok sayılıyor): $e\n$st');
    }
  }

  ({String title, String body}) _inactivityStageContent({
    required int days,
    required bool isEn,
  }) {
    switch (days) {
      case 3:
        return (
          title: isEn ? "$days days since your last visit 👋" : '$days gündür uğramadın 👋',
          body: isEn
              ? 'Your projects are waiting. Pick up right where you left off.'
              : 'Projelerin seni bekliyor. Kaldığın yerden devam et.',
        );
      case 7:
        return (
          title: isEn ? 'Your sites are still saved ✨' : 'Sitelerin hâlâ duruyor ✨',
          body: isEn
              ? "It's been a week — your projects and free points are ready whenever you are."
              : 'Bir hafta oldu — projelerin ve ücretsiz puanların ne zaman istersen hazır.',
        );
      case 14:
        return (
          title: isEn ? 'We miss you at Sitora 💭' : 'Seni özledik 💭',
          body: isEn
              ? "Two weeks away — want to publish a new site or update an old one? It only takes a couple of minutes."
              : '2 haftadır yoksun — yeni bir site yayınlamaya ya da eskisini güncellemeye ne dersin? Sadece birkaç dakika sürüyor.',
        );
      case 30:
      default:
        return (
          title: isEn ? 'One last hello from Sitora 👋' : 'Sitora\'dan son bir merhaba 👋',
          body: isEn
              ? "It's been a month. Your projects are still saved and your free points are waiting — come take a look."
              : 'Bir ay oldu. Projelerin hâlâ duruyor, ücretsiz puanların seni bekliyor — bir göz atmaya ne dersin?',
        );
    }
  }

  int _updateReminderId(String projectId) =>
      _updateReminderBaseId + (projectId.hashCode & 0x0FFFFFFF);

  Future<void> scheduleProjectUpdateReminder({
    required String projectId,
    required String projectName,
    int afterDays = 30,
  }) async {
    try {
      await init();
      final isEn = await _isEnglish();
      final id = _updateReminderId(projectId);
      await _plugin.cancel(id);
      final title = isEn
          ? 'Want to update your site? ✨'
          : 'Sitenizi güncellemek ister misiniz? ✨';
      final body = isEn
          ? 'It\'s been $afterDays days since you last updated "$projectName".'
          : '"$projectName" projesini son güncellemenin üzerinden $afterDays gün geçti.';
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextNoon(daysFromNow: afterDays),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: projectId,
      );
    } catch (e, st) {
      debugPrint('scheduleProjectUpdateReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  Future<void> cancelProjectUpdateReminder(String projectId) async {
    try {
      await init();
      await _plugin.cancel(_updateReminderId(projectId));
    } catch (e, st) {
      debugPrint('cancelProjectUpdateReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  int _domainPendingId(String projectId) =>
      _domainPendingBaseId + (projectId.hashCode & 0x0FFFFFFF);

  Future<void> scheduleDomainPendingReminder({
    required String projectId,
    required String domain,
    int afterDays = 2,
  }) async {
    try {
      await init();
      final isEn = await _isEnglish();
      final id = _domainPendingId(projectId);
      await _plugin.cancel(id);
      final title = isEn ? 'Your domain is still pending ⏳' : 'Domainin hâlâ bekliyor ⏳';
      final body = isEn
          ? 'The DNS record for "$domain" hasn\'t been verified yet. Add the CNAME record in your domain provider\'s panel to finish connecting it.'
          : '"$domain" için DNS kaydı henüz doğrulanmadı. Bağlantıyı tamamlamak için domain sağlayıcının panelinde CNAME kaydını eklemeyi unutma.';
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextNoon(daysFromNow: afterDays),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: projectId,
      );
    } catch (e, st) {
      debugPrint('scheduleDomainPendingReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  Future<void> cancelDomainPendingReminder(String projectId) async {
    try {
      await init();
      await _plugin.cancel(_domainPendingId(projectId));
    } catch (e, st) {
      debugPrint('cancelDomainPendingReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  int _domainRenewalWarnId(String projectId) =>
      _domainRenewalWarnBaseId + (projectId.hashCode & 0x0FFFFFFF);
  int _domainRenewalExpiredId(String projectId) =>
      _domainRenewalExpiredBaseId + (projectId.hashCode & 0x0FFFFFFF);

  Future<void> scheduleDomainRenewalReminder({
    required String projectId,
    required String domain,
    required DateTime expiresAt,
  }) async {
    try {
      await init();
      final isEn = await _isEnglish();
      final warnId = _domainRenewalWarnId(projectId);
      final expiredId = _domainRenewalExpiredId(projectId);
      await _plugin.cancel(warnId);
      await _plugin.cancel(expiredId);

      final warnTz = _noonOnDate(expiresAt.subtract(const Duration(days: 30)));
      if (warnTz != null) {
        final title = isEn
            ? 'Your domain connection renews soon ⏳'
            : 'Domain bağlantının süresi yakında doluyor ⏳';
        final body = isEn
            ? '"$domain" is connected for 1 year and its 30-day renewal window has started. Open the app to extend it.'
            : '"$domain" 1 yıllığına bağlıydı ve süresinin dolmasına 30 gün kaldı. Bağlantının kesilmemesi için uygulamadan uzat.';
        await _plugin.zonedSchedule(
          warnId,
          title,
          body,
          warnTz,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: projectId,
        );
      }

      final expiredTz = _noonOnDate(expiresAt);
      if (expiredTz != null) {
        final title = isEn ? 'Your domain connection has expired' : 'Domain bağlantının süresi doldu';
        final body = isEn
            ? '"$domain" reached its 1-year limit. Renew it in the app so your site keeps working at this address.'
            : '"$domain" 1 yıllık bağlantı süresini doldurdu. Sitenin bu adreste çalışmaya devam etmesi için uygulamadan yenile.';
        await _plugin.zonedSchedule(
          expiredId,
          title,
          body,
          expiredTz,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: projectId,
        );
      }
    } catch (e, st) {
      debugPrint('scheduleDomainRenewalReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  Future<void> cancelDomainRenewalReminder(String projectId) async {
    try {
      await init();
      await _plugin.cancel(_domainRenewalWarnId(projectId));
      await _plugin.cancel(_domainRenewalExpiredId(projectId));
    } catch (e, st) {
      debugPrint('cancelDomainRenewalReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  int _miniPackageWarnId(String projectId) =>
      _miniPackageWarnBaseId + (projectId.hashCode & 0x0FFFFFFF);
  int _miniPackageExpiredId(String projectId) =>
      _miniPackageExpiredBaseId + (projectId.hashCode & 0x0FFFFFFF);

  Future<void> scheduleMiniPackageExpiryReminder({
    required String projectId,
    required DateTime expiresAt,
  }) async {
    try {
      await init();
      final isEn = await _isEnglish();
      final warnId = _miniPackageWarnId(projectId);
      final expiredId = _miniPackageExpiredId(projectId);
      await _plugin.cancel(warnId);
      await _plugin.cancel(expiredId);

      final warnTz = _noonOnDate(expiresAt.subtract(const Duration(days: 7)));
      if (warnTz != null) {
        final title = isEn
            ? 'Your Mini Package expires soon ⏳'
            : 'Mini Paketinin süresi yakında doluyor ⏳';
        final body = isEn
            ? 'Your 1-month Mini Package expires in 7 days. Renew it in the app to keep the badge off and your extra pages live.'
            : 'Mini Paketinin süresinin dolmasına 7 gün kaldı. Rozetin kaldırılmış ve ek sayfaların yayında kalması için uygulamadan yenile.';
        await _plugin.zonedSchedule(
          warnId,
          title,
          body,
          warnTz,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: projectId,
        );
      }

      final expiredTz = _noonOnDate(expiresAt);
      if (expiredTz != null) {
        final title = isEn ? 'Your Mini Package has expired' : 'Mini Paketinin süresi doldu';
        final body = isEn
            ? 'Your 1-month Mini Package ended. Renew it in the app to remove the badge and unlock extra pages again.'
            : '1 aylık Mini Paketin süresi doldu. Rozeti tekrar kaldırmak ve ek sayfaları yeniden açmak için uygulamadan yenile.';
        await _plugin.zonedSchedule(
          expiredId,
          title,
          body,
          expiredTz,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: projectId,
        );
      }
    } catch (e, st) {
      debugPrint('scheduleMiniPackageExpiryReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  Future<void> cancelMiniPackageExpiryReminder(String projectId) async {
    try {
      await init();
      await _plugin.cancel(_miniPackageWarnId(projectId));
      await _plugin.cancel(_miniPackageExpiredId(projectId));
    } catch (e, st) {
      debugPrint('cancelMiniPackageExpiryReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  Future<void> scheduleDailyVisitorCheckIn() async {
    try {
      await init();
      final isEn = await _isEnglish();
      final title = isEn ? 'How many people visited your site? 👀' : 'Sitenizi kaç kişi ziyaret etti? 👀';
      final body = isEn
          ? "Tap to see today's visitor count for your published sites."
          : 'Yayındaki sitelerinizin bugünkü ziyaretçi sayısını görmek için dokunun.';
      await _plugin.zonedSchedule(
        _dailyVisitorCheckInId,
        title,
        body,
        _nextNoon(),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('scheduleDailyVisitorCheckIn başarısız (yok sayılıyor): $e\\n$st');
    }
  }

  Future<void> cancelDailyVisitorCheckIn() async {
    try {
      await init();
      await _plugin.cancel(_dailyVisitorCheckInId);
    } catch (e, st) {
      debugPrint('cancelDailyVisitorCheckIn başarısız (yok sayılıyor): $e\\n$st');
    }
  }

  Future<void> showPushNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await init();
      final id = 4000000 + (DateTime.now().millisecondsSinceEpoch & 0x0FFFFFF);
      await _plugin.show(id, title, body, _details, payload: payload);
    } catch (e, st) {
      debugPrint('showPushNotification başarısız (yok sayılıyor): $e\n$st');
    }
  }

  Future<void> cancelAll() async {
    try {
      await init();
      await _plugin.cancelAll();
    } catch (e, st) {
      debugPrint('cancelAll başarısız (yok sayılıyor): $e\n$st');
    }
  }
}
