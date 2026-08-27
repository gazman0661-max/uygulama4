import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'state/app_state.dart';
import 'localization/locale_controller.dart';
import 'services/notification_service.dart';
import 'services/crash_service.dart';

void main() {
  // runZonedGuarded: async/zone içinde (örn. bir Future'ın catch'lenmemiş
  // hatası) oluşan ve normalde konsola sessizce düşüp KAYBOLAN hataları
  // yakalar. main() gövdesinin TAMAMI bu zone İÇİNDE çalışmalı — yoksa zone
  // dışında oluşan hatalar yine kaçar.
  runZonedGuarded<void>(() async {
    // Uygulamanın tüm ekranları portre moda göre tasarlandı/test edildi.
    // Portreye kilitleyerek TÜM cihaz/ekran boyutlarında aynı, denenmiş
    // düzenin gösterilmesini garanti ediyoruz.
    WidgetsFlutterBinding.ensureInitialized();

    // Flutter'ın KENDİ çizim/build hataları normalde kırmızı ekran gösterip
    // konsola yazar ama hiçbir yere KAYDEDİLMEZ. Artık CrashService
    // üzerinden de geçiyor (bkz. crash_service.dart).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // eski davranış (kırmızı ekran) KORUNUR
      CrashService.record(details.exception, details.stack, context: 'FlutterError', fatal: true);
    };

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Bildirimler: uygulama açılışını bloklamasın diye await edilmiyor.
    // Pasif kullanıcı hatırlatması KADEMELİ bir seri (3/7/14/30 gün) —
    // her açılışta baştan kurulur.
    unawaited(() async {
      await NotificationService.instance.init();
      await NotificationService.instance.scheduleInactivityReminderSeries();
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
    // buraya düşer. fatal: false — uygulama çökmedi, sadece bir arka plan
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
