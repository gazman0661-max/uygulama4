import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Sitora AI için yerel (cihaz üstü) bildirim servisi.
///
/// ÖNEMLİ: Uygulama sunucusuz çalıştığı için (bkz. DownloadService) burada
/// da gerçek bir "push" değil, cihazda planlanmış YEREL bildirimler
/// kullanılıyor. Bu, kullanıcı hosting yapmasa bile çalışır ve maliyeti
/// sıfırdır — sadece OS'in kendi bildirim/alarm altyapısını kullanır.
///
/// Kurallar (ürün kararı):
/// - Tüm bildirimler kullanıcının CİHAZ SAAT DİLİMİNE göre planlanır
///   (tz.local + flutter_timezone ile gerçek IANA zaman dilimi tespiti).
/// - Tüm bildirimler ÖĞLE SAATİNDE (varsayılan 12:00, `notifyHour` ile
///   ayarlanabilir) gönderilir; gece kimseyi rahatsız etmeyiz.
/// - Kota sıfırlama bildirimi her ayın 1'inde UTC bazlı resetlenen kotayı
///   anons eder ama bildirimin KENDİSİ öğlen gider (reset gece olsa bile).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Bildirimlerin gönderileceği saat (24 saat formatı, cihaz yerel saati).
  /// 12 = öğle. Gece rahatsız etmemek için 09:00-21:00 dışına asla izin
  /// vermiyoruz (bkz. _clampToDaytime).
  static const int notifyHour = 12;
  static const int notifyMinute = 0;

  static const int _monthlyQuotaNotifId = 1001;
  static const int _inactivityNotifId = 1002;
  // Proje güncelleme hatırlatmaları için taban id; her proje kendi id'sini
  // projectId.hashCode üzerinden bu tabana ekleyerek alır.
  static const int _updateReminderBaseId = 2000000;

  /// ÖNEMLİ: Bildirimler uygulamanın YAN ÖZELLİĞİ — asla kritik bir akışı
  /// (indirme, kaydetme, dışa aktarma vb.) kesmemeli. Bu yüzden bu sınıftaki
  /// TÜM public metodlar kendi içinde hataları yutar ve asla dışarı
  /// fırlatmaz (bkz. `flutter_local_notifications`'ın bilinen R8/Gson
  /// "Missing type parameter" hatası — eski planlanmış bildirim kaydını
  /// SharedPreferences'tan okurken release derlemede oluşabiliyor).
  /// Çağıran kod (ör. AppState.markProjectExported) bu yüzden bildirim
  /// hatası yüzünden "İndirme başarısız" göstermez.
  Future<void> init() async {
    if (_initialized) return;

    try {
      tzdata.initializeTimeZones();
      try {
        final deviceTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTz.identifier));
      } catch (_) {
        // Zaman dilimi tespit edilemezse UTC'ye düşmek yerine cihazın
        // DateTime.now() ofsetine en yakın bilinen konumu deneriz;
        // olmazsa paket varsayılanı (UTC) kullanılır. Bildirimler yine de
        // "yerel 12:00" mantığıyla planlanacağı için büyük sapma olmaz.
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
      // NOT: Bilinçli olarak exact alarm izni İSTEMİYORUZ. Bildirimlerin
      // dakika hassasiyetinde gitmesi gerekmiyor (öğlen ±birkaç dakika fark
      // etmez); Play Store'un kısıtladığı SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM
      // izinlerini gereksiz yere istemek review riskini artırır. Bunun yerine
      // inexactAllowWhileIdle kullanıyoruz (bkz. androidScheduleMode).

      _initialized = true;
    } catch (e, st) {
      // Bildirim altyapısı kurulamadıysa sessizce vazgeç; uygulamanın geri
      // kalanı (indirme, AI üretimi vb.) bundan etkilenmemeli.
      debugPrint('NotificationService.init() başarısız (yok sayılıyor): $e\n$st');
      // _initialized bilerek true YAPILMIYOR ki bir dahaki çağrıda tekrar
      // denensin (ör. kullanıcı izni sonradan verirse).
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'sitora_general',
          'Sitora AI Bildirimleri',
          channelDescription:
              'Kota, proje ve davet hatırlatmaları — yalnızca gündüz saatlerinde gönderilir.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Verilen tarihten sonraki ilk "yerel öğlen" anını döner.
  /// [daysFromNow] kadar gün ekler; bugünün öğleni geçmişse otomatik
  /// bir sonraki güne kayar (asla geçmişe planlama yapılmaz).
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

  /// Bir sonraki ayın 1'inin yerel öğlenini döner (bugün ayın 1'iyse ve
  /// öğlen henüz geçmediyse bugünü kullanır). Aylık puan reset
  /// bildirimi için kullanılır.
  tz.TZDateTime _nextFirstOfMonthNoon() {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      1,
      notifyHour,
      notifyMinute,
    );
    if (target.isBefore(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      target = tz.TZDateTime(
        tz.local,
        nextYear,
        nextMonth,
        1,
        notifyHour,
        notifyMinute,
      );
    }
    return target;
  }

  // ---------------------------------------------------------------------
  // 1) Aylık kota reset bildirimi — "Bu ayki ücretsiz puanların yenilendi 🎁"
  // ---------------------------------------------------------------------
  /// Her ayın 1'inde yerel öğlende tekrar eden bildirim kurar (FORM ve AI
  /// puan havuzları da her ayın 1'inde UTC bazlı sıfırlanıyor, bkz.
  /// AppState._ensureMonthlyPointsReset). Bu bildirim sadece kullanıcıya
  /// "bu ayki kotan hazır" hatırlatmasıdır ve bilinçli olarak gece değil
  /// öğlen gönderilir.
  Future<void> scheduleMonthlyQuotaReset({
    String title = 'Bu ayki ücretsiz puanların yenilendi 🎁',
    String body = 'Form ve AI puanların yeniden doldu. Hemen bir site üret!',
  }) async {
    try {
      await init();
      await _plugin.zonedSchedule(
        _monthlyQuotaNotifId,
        title,
        body,
        _nextFirstOfMonthNoon(),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('scheduleMonthlyQuotaReset başarısız (yok sayılıyor): $e\n$st');
    }
  }

  // ---------------------------------------------------------------------
  // 2) Pasif kullanıcı geri çağırma — "X gündür uğramadın..."
  // ---------------------------------------------------------------------
  /// Uygulama her açıldığında çağrılır: önceki bekleyen hatırlatmayı iptal
  /// eder ve [afterDays] gün sonrasının öğlenine yeniden kurar. Kullanıcı
  /// bu süre içinde uygulamayı tekrar açarsa bildirim otomatik ertelenmiş
  /// olur (spam olmaz).
  Future<void> scheduleInactivityReminder({int afterDays = 3}) async {
    try {
      await init();
      await _plugin.cancel(_inactivityNotifId);
      await _plugin.zonedSchedule(
        _inactivityNotifId,
        '$afterDays gündür uğramadın 👋',
        'Projelerin seni bekliyor. Kaldığın yerden devam et.',
        _nextNoon(daysFromNow: afterDays),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('scheduleInactivityReminder başarısız (yok sayılıyor): $e\n$st');
    }
  }

  // ---------------------------------------------------------------------
  // 3) Proje bazlı 30 gün sonra "sitenizi güncellemek ister misiniz?"
  // ---------------------------------------------------------------------
  int _updateReminderId(String projectId) =>
      _updateReminderBaseId + (projectId.hashCode & 0x0FFFFFFF);

  Future<void> scheduleProjectUpdateReminder({
    required String projectId,
    required String projectName,
    int afterDays = 30,
  }) async {
    try {
      await init();
      final id = _updateReminderId(projectId);
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        'Sitenizi güncellemek ister misiniz? ✨',
        '"$projectName" projesini son güncellemenin üzerinden $afterDays gün geçti.',
        _nextNoon(daysFromNow: afterDays),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: projectId,
      );
    } catch (e, st) {
      // BU METOD, indirme/dışa aktarma sonrası AppState.markProjectExported
      // tarafından çağrılır. Burada bir hata fırlatılırsa indirme ekranındaki
      // try/catch bunu yakalayıp yanlışlıkla "İndirme başarısız" gösterir —
      // oysa dosya zaten diske kaydedilmiş olur. Bu yüzden burada hatayı
      // KESİNLİKLE yutuyoruz.
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

  Future<void> cancelAll() async {
    try {
      await init();
      await _plugin.cancelAll();
    } catch (e, st) {
      debugPrint('cancelAll başarısız (yok sayılıyor): $e\n$st');
    }
  }
}
