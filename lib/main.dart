import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'services/server_time_service.dart';

void main() {
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await ServerTimeService.init();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      CrashService.record(details.exception, details.stack, context: 'FlutterError', fatal: true);
    };

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    try {
      await Firebase.initializeApp();
      AuthService.isAvailable = true;
      AnalyticsService.isAvailable = true;
      await CrashService.init();
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
        );
      } catch (e) {
        debugPrint('App Check etkinleştirilemedi (Play Integrity kurulu değil olabilir): $e');
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      AuthService.isAvailable = false;
      AnalyticsService.isAvailable = false;
      debugPrint('Firebase henüz kurulmadı, misafir modunda devam ediliyor: $e');
    }

    await AuthLinkService.instance.init();

    await BillingService.instance.init();

    unawaited(() async {
      await NotificationService.instance.init();
      await NotificationService.instance.cancelLegacyMonthlyQuotaNotification();
      await NotificationService.instance.scheduleInactivityReminderSeries();
      await PushService.instance.init();
    }());

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocaleController()),
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
    CrashService.record(error, stackTrace, context: 'ZoneError', fatal: false);
  });
}

class SitoraApp extends StatelessWidget {
  const SitoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      navigatorKey: AuthLinkService.instance.navigatorKey,
      title: 'Sitora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeController.themeMode,
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
