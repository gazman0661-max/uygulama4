import 'dart:ui' as ui;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'log_service.dart';
/// Firebase Crashlytics: coken/hata raporlari. Firebase baslatildiktan SONRA (Sartlar onayindan sonra)
/// acilir; onaydan once hicbir sey toplanmaz (AndroidManifest'te toplama varsayilan KAPALI).
class CrashService {
  CrashService._();
  static final CrashService instance = CrashService._();

  bool _started = false;

  Future<void> init() async {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      final c = FirebaseCrashlytics.instance;
      await c.setCrashlyticsCollectionEnabled(!kDebugMode);
      // Hata gunlugu (AppLog) isleyicilerini EZME: zincirle.
      final prevFlutter = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails d) {
        prevFlutter?.call(d);
        c.recordFlutterFatalError(d);
      };
      final prevPlatform = ui.PlatformDispatcher.instance.onError;
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        prevPlatform?.call(error, stack);
        c.recordError(error, stack, fatal: true);
        return true;
      };
      AppLog.i('crash', 'Crashlytics acildi');
    } catch (err) { AppLog.w('crash_service.init', 'yutulan hata', err); }
  }
}
