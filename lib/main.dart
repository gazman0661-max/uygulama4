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

void main() async {
  // Uygulamanın tüm ekranları (sohbet balonları, alt tutamaç/panel
  // çubukları) portre moda göre tasarlandı ve test edildi. Yatay moda
  // hiç kilit yoktu; döndürme sırasında alt sabit çubuklar garip
  // görünebiliyordu.
  // Portreye kilitleyerek TÜM cihaz/ekran boyutlarında (telefon/tablet)
  // aynı, denenmiş düzenin gösterilmesini garanti ediyoruz.
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Bildirimler: uygulama açılışını bloklamasın diye await edilmiyor.
  // Günlük kota bildirimi her gün öğlen tekrar eder; pasif kullanıcı
  // hatırlatması her açılışta 3 gün ileriye ertelenir (kullanıcı sık
  // açtıkça hiç görünmez, uğramazsa 3. günün öğleninde gelir).
  unawaited(() async {
    await NotificationService.instance.init();
    await NotificationService.instance.scheduleDailyQuotaReset();
    await NotificationService.instance.scheduleInactivityReminder(afterDays: 3);
  }());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => LocaleController()),
      ],
      child: const SitoraApp(),
    ),
  );
}

class SitoraApp extends StatelessWidget {
  const SitoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Sitora AI',
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
