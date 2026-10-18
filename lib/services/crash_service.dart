import 'diag_service.dart';
import 'dart:ui' as ui;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

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
      FlutterError.onError = (d) {
        Diag.instance.log('FLUTTER-HATA', d.exceptionAsString());
        c.recordFlutterFatalError(d);
      };
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        Diag.instance.log('ASYNC-HATA', '$error');
        c.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {}
  }
}
