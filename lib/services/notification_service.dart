import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Sitora için yerel (cihaz üstü) bildirim servisi.
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

  static const int _monthlyQuotaNotifId = 1001;
  // Kademeli pasif kullanıcı hatırlatmaları için taban id — her kademe
  // (bkz. _inactivityStageDays) bu tabana kendi index'ini ekleyerek alır.
  static const int _inactivityBaseId = 1002000;
  static const List<int> _inactivityStageDays = [3, 7, 14, 30];
  // Proje güncelleme hatırlatmaları için taban id; her proje kendi id'sini
  // projectId.hashCode üzerinden bu tabana ekleyerek alır.
  static const int _updateReminderBaseId = 2000000;
  // "Kendi domainimi bağla" akışında DNS doğrulaması tamamlanmadan
  // ekrandan çıkan kullanıcı için hatırlatma; her proje kendi id'sini
  // projectId.hashCode üzerinden bu tabana ekleyerek alır.
  static const int _domainPendingBaseId = 3000000;
  // Domain bağlama 1 YIL SÜRELİDİR (ürün kararı). Süre dolmadan 30 gün
  // önce bir uyarı, bitiş gününde de bir "süresi doldu" bildirimi kurulur.
  // Her proje kendi id'sini projectId.hashCode üzerinden bu tabanlara
  // ekleyerek alır (bkz. scheduleDomainRenewalReminder).
  static const int _domainRenewalWarnBaseId = 5000000;
  static const int _domainRenewalExpiredBaseId = 6000000;
  // "Sitenizi bugün kim ziyaret etti?" günlük hatırlatması — TEK bir id
  // yeterli çünkü proje bazlı değil, kullanıcının YAYINDAKİ tüm siteleri
  // için genel bir tetikleyici (bkz. scheduleDailyVisitorCheckIn).
  static const int _dailyVisitorCheckInId = 7000000;

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
      // kalanı (indirme, site üretimi vb.) bundan etkilenmemeli.
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

  /// Verilen TAKVİM GÜNÜNÜN yerel öğlenini döner — [_nextNoon]'dan farklı
  /// olarak "bugünden itibaren N gün" değil, SABİT bir [date]'e göre
  /// hesaplar (domain yenileme hatırlatmaları gibi belirli bir bitiş
  /// tarihine bağlı bildirimler için). O tarih zaten geçmişse (ör. uygulama
  /// açılmadığı için hatırlatma hiç kurulamadıysa) null döner — geçmişe
  /// planlama yapılmaz, çağıran taraf bu durumda bildirimi atlar.
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

  // ---------------------------------------------------------------------
  // 1) Aylık kota reset bildirimi — "Bu ayki ücretsiz puanların yenilendi 🎁"
  // ---------------------------------------------------------------------
  /// Her ayın 1'inde yerel öğlende tekrar eden bildirim kurar (FORM puan
  /// havuzu da her ayın 1'inde UTC bazlı sıfırlanıyor, bkz.
  /// AppState._ensureMonthlyPointsReset). Bu bildirim sadece kullanıcıya
  /// "bu ayki kotan hazır" hatırlatmasıdır ve bilinçli olarak gece değil
  /// öğlen gönderilir.
  Future<void> scheduleMonthlyQuotaReset() async {
    try {
      await init();
      final isEn = await _isEnglish();
      final title = isEn
          ? 'Your free monthly points have refreshed 🎁'
          : 'Bu ayki ücretsiz puanların yenilendi 🎁';
      final body = isEn
          ? 'Your form points are full again. Go generate a site!'
          : 'Form puanların yeniden doldu. Hemen bir site üret!';
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
  // 2) Pasif kullanıcı geri çağırma — KADEMELİ seri
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

  // ---------------------------------------------------------------------
  // 4) "Kendi domainimi bağla" — DNS doğrulaması yarım kalmış kullanıcı
  //    "$domain hâlâ bekliyor, DNS kaydını eklemeyi unutma" hatırlatması.
  // ---------------------------------------------------------------------
  /// DomainConnectScreen._connect() başarılı dönüp durum 'pending' olarak
  /// kaldığında (yani kullanıcı CNAME kaydını henüz kendi DNS panelinde
  /// eklemediği/yaymadığı için Cloudflare doğrulaması bitmediğinde)
  /// çağrılır. Kullanıcı ekrandan çıkıp unutabilir; [afterDays] sonra
  /// tek seferlik bir hatırlatma kurar. Domain 'active' olduğunda ya da
  /// kaldırıldığında (bkz. [cancelDomainPendingReminder]) iptal edilir.
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
      // Bu metod DomainConnectScreen._connect() başarılı olduktan SONRA
      // çağrılıyor — domain bağlama isteğinin kendisini asla etkilememeli.
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

  // ---------------------------------------------------------------------
  // 5) "Kendi domainimi bağla" — 1 YIL SÜRE hatırlatması.
  //    Süre dolmadan 30 gün önce bir uyarı + bitiş gününde bir "süresi
  //    doldu, yenile" bildirimi.
  // ---------------------------------------------------------------------
  int _domainRenewalWarnId(String projectId) =>
      _domainRenewalWarnBaseId + (projectId.hashCode & 0x0FFFFFFF);
  int _domainRenewalExpiredId(String projectId) =>
      _domainRenewalExpiredBaseId + (projectId.hashCode & 0x0FFFFFFF);

  /// Domain 'active' durumuna geçtiğinde (bkz. DomainConnectScreen) ya da
  /// kullanıcı "Yenile" butonuna bastığında (bkz. AppState.renewProjectDomain)
  /// çağrılır. [expiresAt], SiteProject.domainExpiresAt'ten gelir (bağlanma/
  /// yenileme anından TAM 365 gün sonrası). Önce eski planlanmış bildirimler
  /// iptal edilir, sonra:
  ///   - bitişten 30 gün önce bir "yakında doluyor" uyarısı,
  ///   - bitiş gününün kendisinde bir "süresi doldu, yenile" bildirimi
  /// yeniden kurulur. Bu tarihlerden biri zaten geçmişse (ör. kullanıcı
  /// süre dolduktan çok sonra tekrar bu ekrana girip yenilerse) o bildirim
  /// atlanır — geçmişe planlama yapılmaz.
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
      // Bu metod domain 'active' olduktan SONRA çağrılıyor — asıl domain
      // bağlama akışını asla etkilememeli.
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

  // ---------------------------------------------------------------------
  // 5) Günlük "sitenizi kim ziyaret etti" hatırlatması
  // ---------------------------------------------------------------------
  /// ÖNEMLİ SINIRLAMA — burayı okumadan bu metodu değiştirme: bu sınıf
  /// tamamen YEREL bildirimler kullanıyor (bkz. dosya başı doküman),
  /// yani içerik PLANLAMA ANINDA sabitlenir — bildirim GERÇEKTEN
  /// gösterileceği an (yarın, öbür gün...) uygulamanın arka planda
  /// çalışıp o günkü gerçek ziyaretçi sayısını sorgulaması YOK. Bu yüzden
  /// bildirim metninde SAHTE bir rakam ("bugün 7 kişi baktı" gibi
  /// uydurma bir sayı) GÖSTERİLMEZ — bu hem yanlış bilgi hem de güven
  /// kırıcı olur. Bunun yerine jenerik ama merak uyandıran bir metinle
  /// kullanıcı uygulamaya geri çağrılır; GERÇEK sayı, kullanıcı
  /// Projelerim ekranını açtığında orada zaten CANLI olarak gösteriliyor
  /// (bkz. HostingService.fetchStatsBatch + projects_screen.dart >
  /// _LiveSitesStrip). Gerçek sayıyı bildirimin İÇİNE koymak istenirse
  /// bunun için ya arka plan görevi (workmanager) ya da Worker'da bir
  /// cron trigger + FCM push mimarisi kurulması gerekir — ikisi de bu
  /// sınıfın "sunucusuz/basit" tasarımının dışında, ayrı bir iştir.
  ///
  /// Her ayın 1'i gibi TEKRAR EDEN bir bildirim: her gün yerel öğlende
  /// (matchDateTimeComponents: time) tetiklenir. AppState.markProjectPublished
  /// içinden çağrılır — yani kullanıcının en az bir YAYINDA sitesi olduğu
  /// an devreye girer; hiç yayını olmayan kullanıcıya gönderilmez (bkz.
  /// çağıran taraf). Tek bir sabit id kullanıldığı için ikinci/üçüncü
  /// site yayınlansa bile bildirim ÇOĞALMAZ, sadece yeniden kurulur.
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

  /// Kullanıcının TÜM siteleri yayından kaldırıldığında (markProjectUnpublished
  /// sonrası artık hiç yayında sitesi kalmadıysa) çağrılmalı — artık
  /// bakacağı bir ziyaretçi sayısı olmadığı için bu hatırlatma anlamsız
  /// hale gelir, spam olmasın diye iptal edilir.
  Future<void> cancelDailyVisitorCheckIn() async {
    try {
      await init();
      await _plugin.cancel(_dailyVisitorCheckInId);
    } catch (e, st) {
      debugPrint('cancelDailyVisitorCheckIn başarısız (yok sayılıyor): $e\\n$st');
    }
  }

  // ---------------------------------------------------------------------
  // 6) "Kutu" (mailbox) ve "Talepler" (lead) — ANLIK bildirimler artık
  // TAMAMEN gerçek FCM push üzerinden geliyor (bkz. [showPushNotification]
  // altında ve push_service.dart). 05.09.2026'da buradaki iki eski
  // "sadece uygulama açıkken Firestore stream'ini dinleyip yerel bildirim
  // göster" metodu (showNewMailboxMessageNotification/showNewLeadNotification,
  // main_shell.dart > _watchForNewMessages tarafından çağrılıyordu)
  // KALDIRILDI — gerçek push kurulduktan sonra bu ikisi AYNI olay için
  // ayrı ayrı birer bildirim gösteriyordu (çift bildirim, kanka bildirdi).

  /// [03.09.2026 eklendi] Gerçek bir FCM push'u (bkz. push_service.dart)
  /// UYGULAMA AÇIKKEN göstermek için — Android, ön plandaki bir uygulamada
  /// gelen FCM bildirimlerini OTOMATİK göstermez (sadece arka planda/kapalı
  /// durumdayken sistem kendisi gösterir), bu yüzden foreground'da elle
  /// tetiklenmesi gerekiyor. Aynı `_details` (sitora_general kanalı) ve
  /// aynı hata-yutma deseni kullanılıyor — bkz. sınıf başı doküman.
  Future<void> showPushNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await init();
      // Aynı push birden fazla kez gelirse (nadir ama FCM'in doğası) farklı
      // bildirimler olarak üst üste yığılmasın diye zaman damgasından id
      // türetiliyor — kritik değil, sadece tepside makul davranış.
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
