import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'state/app_state.dart';
import 'localization/locale_controller.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/auth_service.dart';
import 'services/auth_link_service.dart';
import 'services/billing_service.dart';
import 'services/crash_service.dart';
import 'services/analytics_service.dart';

void main() {
  // runZonedGuarded: async/zone içinde (örn. bir Future'ın catch'lenmemiş
  // hatası) oluşan ve normalde konsola sessizce düşüp KAYBOLAN hataları
  // yakalar. main() gövdesinin TAMAMI (Firebase init, runApp dahil) bu
  // zone İÇİNDE çalışmalı — yoksa zone dışında oluşan hatalar yine kaçar.
  runZonedGuarded<void>(() async {
    // Uygulamanın tüm ekranları (sohbet balonları, alt tutamaç/panel
    // çubukları) portre moda göre tasarlandı ve test edildi. Yatay moda
    // hiç kilit yoktu; döndürme sırasında alt sabit çubuklar garip
    // görünebiliyordu.
    // Portreye kilitleyerek TÜM cihaz/ekran boyutlarında (telefon/tablet)
    // aynı, denenmiş düzenin gösterilmesini garanti ediyoruz.
    WidgetsFlutterBinding.ensureInitialized();

    // Flutter'ın KENDİ çizim/build hataları (widget build() içinde fırlayan
    // bir exception gibi) normalde kırmızı ekran gösterip konsola yazar ama
    // hiçbir yere KAYDEDİLMEZ. Artık CrashService üzerinden de geçiyor —
    // Crashlytics eklenince oradan da görünür olacak (bkz. crash_service.dart).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // eski davranış (kırmızı ekran) KORUNUR
      CrashService.record(details.exception, details.stack, context: 'FlutterError', fatal: true);
    };

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // --- GOOGLE GİRİŞİ (İSKELET) ---
    // Firebase Console kurulumu (google-services.json) TAMAMLANMADAN bu
    // çağrı hata fırlatır — bilerek try/catch içine alındı ki kurulum
    // bitmeden de uygulama normal (misafir modunda) çalışmaya devam etsin.
    // Kurulum tamamlanınca (bkz. FIREBASE_SETUP.md) burası otomatik başarılı
    // olur ve AuthService.isAvailable true'ya döner — kod tarafında BAŞKA
    // HİÇBİR yer değiştirmeye gerek yok.
    try {
      await Firebase.initializeApp();
      AuthService.isAvailable = true;
      // Analytics'in de aynı Firebase.initializeApp() başarısına bağlı
      // olması gerekiyor — ayrı bir kurulum adımı YOK, google-services.json
      // eklenip yukarısı başarılı olduğu an Analytics de otomatik açılır.
      AnalyticsService.isAvailable = true;
      // 30.08.2026 eklendi — AYNI desen: Crashlytics de ayrı bir kurulum
      // adımı gerektirmez, Firebase.initializeApp() başarılı olduğu an
      // CrashService.init() içindeki kendi try/catch'i devreye girer.
      await CrashService.init();
      // GERÇEK PUSH (FCM) — 03.09.2026 eklendi. Arka plan işleyicisi
      // Firebase.initializeApp() başarılı olur olmaz, runApp'ten ÖNCE
      // kaydedilmeli (firebase_messaging'in kendi kuralı) — bkz.
      // push_service.dart > firebaseMessagingBackgroundHandler.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      AuthService.isAvailable = false;
      AnalyticsService.isAvailable = false;
      debugPrint('Firebase henüz kurulmadı, misafir modunda devam ediliyor: $e');
    }

    // --- APP LINKS: E-POSTA DOĞRULAMA / ŞİFRE SIFIRLAMA LİNKLERİ ---
    // AuthService.isAvailable AŞAĞIDA kontrol ediliyor (bkz.
    // auth_link_service.dart > init) — Firebase kurulmadıysa hiçbir şey
    // yapmaz. await ediliyor ki soğuk başlangıçtaki (uygulama linke
    // tıklanarak açıldıysa) ilk linki kesin yakalasın.
    await AuthLinkService.instance.init();

    // --- UYGULAMA İÇİ SATIN ALMA (İSKELET) ---
    // Firebase.initializeApp() ile AYNI desen: Play Console tarafında
    // ürünler (bkz. billing_constants.dart) henüz tanımlanmadıysa ya da
    // cihazda Play Store yoksa (örn. emülatör), BillingService.init()
    // içindeki kendi try/catch'i BillingService.isAvailable'ı false
    // bırakır — uygulama açılışını asla bloklamaz/çökertmez. Açılışı
    // geciktirmesin diye await edilmeden, bildirimlerle AYNI unawaited
    // bloğuna dahil EDİLMEDİ çünkü satın alma butonlarının (rozet/yayın/
    // puan sheet'leri) ilk karede zaten doğru isAvailable durumunu
    // görmesi için normal await ile burada tamamlanması tercih edildi —
    // init() içindeki asıl ağ çağrısı (queryProductDetails) hızlı
    // başarısız olduğu için (mağaza yoksa) pratikte gözle görülür bir
    // gecikme yaratmaz.
    await BillingService.instance.init();

    // 29.08.2026 kaldırıldı — uygulama reklamsız modele geçti (bkz.
    // AdsService/BannerAdBar/rewarded_ad_popup.dart artık yok). Gelir
    // tamamen indirme/yayınlama/rozet kaldırma satın almalarından
    // geliyor — reklam bağımlılığı tamamen söküldü.

    // Bildirimler: uygulama açılışını bloklamasın diye await edilmiyor.
    // Aylık kota bildirimi her ayın 1'i öğlen tekrar eder; pasif kullanıcı
    // hatırlatması artık KADEMELİ bir seri (3/7/14/30 gün) — her açılışta
    // baştan kurulur (kullanıcı sık açtıkça hiç görünmez, uğramazsa
    // sırasıyla 3, 7, 14 ve 30. günün öğleninde birer hatırlatma gelir).
    unawaited(() async {
      await NotificationService.instance.init();
      await NotificationService.instance.scheduleMonthlyQuotaReset();
      await NotificationService.instance.scheduleInactivityReminderSeries();
      await PushService.instance.init();
    }());

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocaleController()),
          // AppState, üretilen sitelere eklenen rozetin (WatermarkService)
          // doğru dilde (TR/EN) yazılabilmesi için LocaleController'daki
          // aktif dili senkron tutar. LocaleController bu listede AppState'ten
          // ÖNCE tanımlı olmalı ki proxy provider ona erişebilsin.
          ChangeNotifierProxyProvider<LocaleController, AppState>(
            create: (_) => AppState(),
            update: (_, locale, appState) =>
                appState!..syncLanguage(locale.isEnglish),
          ),
        ],
        child: const SitoraApp(),
      ),
    );
  }, (error, stackTrace) {
    // Zone içinde, hiçbir try/catch'e yakalanmadan yukarı sızan HER hata
    // buraya düşer (örn. bir servis metodundaki unawaited bir Future'ın
    // hatası). fatal: false — uygulama çökmedi, sadece bir arka plan
    // işlemi başarısız oldu, ama artık en azından KAYDEDİLİYOR.
    CrashService.record(error, stackTrace, context: 'ZoneError', fatal: false);
  });
}

class SitoraApp extends StatelessWidget {
  const SitoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      // 31.08.2026 eklendi — AuthLinkService, şifre sıfırlama linki
      // geldiğinde ResetPasswordConfirmScreen'i BuildContext olmadan
      // (uygulama herhangi bir ekrandayken) açabilsin diye.
      navigatorKey: AuthLinkService.instance.navigatorKey,
      title: 'Sitora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeController.themeMode,
      // Cihazın sistem yazı tipi boyutu ne olursa olsun arayüz sabit kalsın:
      // tüm telefon/tabletlerde taşma olmadan aynı stabil görünüm.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
