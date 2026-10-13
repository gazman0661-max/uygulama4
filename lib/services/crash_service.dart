import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'auth_service.dart';

/// ============================================================================
/// CRASH/HATA YAKALAMA
/// ============================================================================
/// 30.08.2026 güncellendi — artık gerçekten Firebase Crashlytics'e yazıyor.
/// AuthService/AnalyticsService ile AYNI desende: Firebase henüz
/// kurulmadıysa (main.dart > Firebase.initializeApp() başarısız olduysa)
/// [isAvailable] false kalır ve [record] sessizce sadece debugPrint'e
/// düşer — çağıran taraflarda (main.dart'taki mevcut çağrılar) HİÇBİR ŞEY
/// değişmesi gerekmez.
/// ============================================================================
class CrashService {
  CrashService._();

  static bool isAvailable = false;

  /// main.dart > Firebase.initializeApp() başarılı olduktan SONRA çağrılır.
  /// Debug modda (yerel geliştirme derlemelerinde) toplama kapalı tutulur,
  /// böylece test/hata ayıklama sırasındaki çökmeler Crashlytics
  /// istatistiklerini kirletmez — release (Play Store) derlemede açıktır.
  static Future<void> init() async {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      // Hangi kullanıcıda oluştuğunu görmek için (opsiyonel, PII olmayan
      // bir kimlik — e-posta değil, Firebase Auth uid).
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

  /// main.dart > runZonedGuarded ve FlutterError.onError buradan çağırır.
  /// [fatal] Flutter'ın kendi çizim/build hatalarında true, yakalanmamış
  /// zone hatalarında false gönderilir.
  static void record(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    bool fatal = false,
  }) {
    // NOT: kasıtlı olarak try/catch YOK — bu zaten en son güvenlik ağı,
    // burada bir hata olursa loglama sessizce başarısız olsun, uygulamanın
    // geri kalanını asla etkilemesin.
    debugPrint(
      '🔴 ${fatal ? '[FATAL] ' : ''}${context != null ? '[$context] ' : ''}'
      '$error\n$stackTrace',
    );
    if (isAvailable) {
      // unawaited: Crashlytics'in kendi yazma işlemi hata yakalama akışını
      // ASLA bloklamamalı/geciktirmemeli.
      unawaited(FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: context,
        fatal: fatal,
      ));
    }
  }
}
