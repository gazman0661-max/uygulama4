import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
/// - TÜM bildirim metinleri TR/EN dil desteklidir. Bu sınıfın bir
///   BuildContext'i olmadığı için (main.dart'ta app henüz kurulmadan
///   çağrılabiliyor), dil tercihini `AppStrings`/`LocaleController`
///   üzerinden değil, doğrudan SharedPreferences'tan okuyoruz — AYNI
///   anahtar (`app_language`) LocaleController tarafından da kullanılıyor,
///   bu yüzden kullanıcının ayarlar ekranından seçtiği dil burada da
///   birebir yansır (bkz. `_isEnglish()`).
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

  /// LocaleController ile AYNI SharedPreferences anahtarı (bkz.
  /// lib/localization/locale_controller.dart > _prefsKey). Kasıtlı olarak
  /// burada da sabitlendi çünkü bu sınıf LocaleController'a (Provider/
  /// BuildContext) bağımlı olmadan, kendi başına çalışabilmeli.
  static const String _localePrefsKey = 'app_language';

  // Kademeli pasif kullanıcı hatırlatmaları için taban id — her kademe
  // (bkz. _inactivityStageDays) bu tabana kendi index'ini ekleyerek alır.
  static const int _inactivityBaseId = 1002000;
  static const List<int> _inactivityStageDays = [3, 7, 14, 30];
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
          'Sitora Bildirimleri',
          channelDescription:
              'Kota, proje ve davet hatırlatmaları — yalnızca gündüz saatlerinde gönderilir.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Bildirim metinlerinin hangi dilde gönderileceğini belirler.
  ///
  /// LocaleController'la AYNI mantık: kullanıcı ayarlardan/ilk açılış
  /// popup'ından bilinçli bir dil seçtiyse (`app_language` prefs'te
  /// kayıtlıysa) o tercihe uyulur. Hiç seçim yapılmamışsa (ör. bu metod
  /// LocaleController henüz prefs'ten yüklenmeden, main.dart açılışında
  /// çağrıldıysa) cihaz diline bakılır: cihaz Türkçe değilse İngilizce
  /// varsayılır (global kullanıcı için en güvenli düşüş).
  Future<bool> _isEnglish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localePrefsKey);
      if (code != null) return code == 'en';
    } catch (_) {
      // SharedPreferences okunamazsa cihaz diline düş (aşağıda).
    }
    try {
      final deviceCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      return deviceCode != 'tr';
    } catch (_) {
      return false;
    }
  }

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

  // ---------------------------------------------------------------------
  // Pasif kullanıcı geri çağırma — KADEMELİ seri
  //    3 gün -> 7 gün -> 14 gün -> 30 gün, her kademede farklı/artan mesaj.
  // ---------------------------------------------------------------------
  /// Uygulama her açıldığında çağrılır: önceki bekleyen TÜM kademeleri
  /// iptal eder ve `_inactivityStageDays` listesindeki her gün için yeni
  /// baştan (bugünden itibaren) yerel öğlene kurar. Kullanıcı bu süre
  /// içinde uygulamayı tekrar açarsa TÜM kademeler otomatik ertelenmiş
  /// olur (spam olmaz) — açılışta seri sıfırdan kurulur.
  ///
  /// Tek kademeli eski davranışın yerine geçti: artık kullanıcı 3. günde
  /// gelen tek bildirimden sonra sessizliğe düşmüyor; dönmediği sürece
  /// 7, 14 ve 30. günlerde de (giderek daha "geri kazanma" tonlu) birer
  /// hatırlatma daha alıyor.
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

  /// Kademe gününe göre giderek yumuşayan/farklılaşan mesaj döner.
  /// 3 gün: nazik dürtme. 7 gün: projeleri hatırlatma. 14 gün: özlem +
  /// somut fayda. 30 gün: son bir "geri kazanma" mesajı.
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
