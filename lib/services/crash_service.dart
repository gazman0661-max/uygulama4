import 'package:flutter/foundation.dart';

/// ============================================================================
/// CRASH/HATA YAKALAMA — İSKELET
/// ============================================================================
/// AuthService ile AYNI desende: Firebase Crashlytics paketi henüz
/// pubspec.yaml'a eklenmedi (bkz. FIREBASE_SETUP.md tamamlanınca eklenecek
/// adım). Bu servis şimdilik SADECE local'de (debugPrint ile) loglar —
/// ama main.dart artık TÜM yakalanmamış hataları (hem Flutter widget
/// hataları hem de async/zone hataları) buraya yönlendiriyor. Yani:
///
///   - BUGÜN: "test aşamasında bir kullanıcı bir yerde takılırsa bunu asla
///     bilemezsin" sorunu ORTADAN KALKMADI ama en azından cihazda/log
///     çıktısında (adb logcat, Play Console'un temel crash raporları)
///     görünür hale geldi, sessizce yutulmuyor.
///   - Crashlytics eklenince: [record] içindeki tek satırı
///     `FirebaseCrashlytics.instance.recordError(...)` ile değiştirmen
///     yeterli — main.dart'ta hiçbir şey değişmiyor, çağrı noktaları aynı.
/// ============================================================================
class CrashService {
  CrashService._();

  /// main.dart > runZonedGuarded ve FlutterError.onError buradan çağırır.
  /// [fatal] Flutter'ın kendi çizim/build hatalarında true, yakalanmamış
  /// zone hatalarında false gönderilir — Crashlytics eklenince bu ayrım
  /// `fatal:` parametresine aynen taşınacak.
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
  }
}
