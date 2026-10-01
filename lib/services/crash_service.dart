import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'auth_service.dart';

class CrashService {
  CrashService._();

  static bool isAvailable = false;

  static Future<void> init() async {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      }
      isAvailable = true;
    } catch (e) {
      isAvailable = false;
      debugPrint('Crashlytics henüz kurulmadı: $e');
    }
  }

  static void record(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    bool fatal = false,
  }) {
    debugPrint(
      '🔴 ${fatal ? '[FATAL] ' : ''}${context != null ? '[$context] ' : ''}'
      '$error\n$stackTrace',
    );
    if (isAvailable) {
      unawaited(FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: context,
        fatal: fatal,
      ));
    }
  }
}
