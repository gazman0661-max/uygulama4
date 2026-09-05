import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'crash_service.dart';
import '../screens/reset_password_confirm_screen.dart';

/// ============================================================================
/// APP LINKS — FIREBASE E-POSTA EYLEMİ LİNKLERİNİ YAKALAMA
/// ============================================================================
/// 31.08.2026 eklendi. AndroidManifest.xml'deki autoVerify intent-filter,
/// `https://<authDomain>/__/auth/action?...` biçimindeki TÜM Firebase Auth
/// e-posta eylemi linklerini (doğrulama, şifre sıfırlama) TARAYICI yerine
/// doğrudan bu uygulamaya yönlendirir. Bu servis o linkleri yakalayıp
/// `mode` parametresine göre doğru işlemi yapar:
///
///   - mode=verifyEmail   → oobCode'u UYGULAMA İÇİNDE uygular
///     ([FirebaseAuth.applyActionCode]), kullanıcıyı reload eder ve
///     [emailVerifiedPulse] üzerinden login_gate.dart'a (açıksa) haber verir
///     — kullanıcı hiçbir şey yazmadan/dokunmadan devam eder.
///   - mode=resetPassword → oobCode ile [ResetPasswordConfirmScreen]'i açar
///     (bu ekran olmasa kullanıcı şifresini HİÇBİR ŞEKİLDE sıfırlayamazdı,
///     çünkü link artık tarayıcıya değil buraya düşüyor — bkz.
///     auth_service.dart > sendPasswordResetEmail'deki not).
///   - diğer modlar (recoverEmail vb.) → şimdilik yok sayılır.
///
/// main.dart açılışta [init] çağırır; hem SOĞUK başlangıç (uygulama linke
/// tıklanarak açıldı) hem de uygulama zaten AÇIKKEN gelen linkler
/// (uriLinkStream) kapsanır.
/// ============================================================================
class AuthLinkService {
  AuthLinkService._();
  static final AuthLinkService instance = AuthLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// login_gate.dart bunu dinler: değer her değiştiğinde (true/false fark
  /// etmez, sadece "değişti" sinyali) e-posta doğrulama durumunu tekrar
  /// kontrol eder. Böylece sheet AÇIKKEN link gelirse sheet otomatik kapanır.
  final ValueNotifier<int> emailVerifiedPulse = ValueNotifier<int>(0);

  /// Ekran geçişleri için: main.dart'taki MaterialApp'e bu key veriliyor.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    if (!AuthService.isAvailable) return;
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handle(initialUri));
      }
    } catch (e, st) {
      CrashService.record(e, st, context: 'AuthLinkService.initialLink', fatal: false);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri)),
      onError: (e, st) =>
          CrashService.record(e, st, context: 'AuthLinkService.stream', fatal: false),
    );
  }

  void dispose() {
    _sub?.cancel();
  }

  Future<void> _handle(Uri uri) async {
    // Sadece bizim doğrulama alan adımıza ait linkler ilgilendirir —
    // AuthService.authDomain (sitora-a9e27.firebaseapp.com) ile eşleşmeyen
    // her şey (ör. ileride eklenebilecek başka bir App Link) sessizce geçilir.
    if (uri.host != AuthService.authDomain) return;

    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) return;

    switch (mode) {
      case 'verifyEmail':
        await _handleVerifyEmail(oobCode);
        break;
      case 'resetPassword':
        await _handleResetPassword(oobCode);
        break;
      default:
        // recoverEmail, revertSecondFactorAddition vb. — şimdilik
        // kapsam dışı, sessizce yok sayılır.
        break;
    }
  }

  Future<void> _handleVerifyEmail(String oobCode) async {
    try {
      await FirebaseAuth.instance.checkActionCode(oobCode);
      await FirebaseAuth.instance.applyActionCode(oobCode);
    } on FirebaseAuthException catch (e, st) {
      // Kod süresi dolmuş/kullanılmış olabilir (ör. kullanıcı linke iki kez
      // tıkladı) — sessizce geç, login_gate zaten "Doğruladım, kontrol et"
      // ile normal reload akışına düşer.
      CrashService.record(e, st, context: 'AuthLinkService.verifyEmail', fatal: false);
    }
    // applyActionCode başarılı olsun ya da olmasın, mevcut kullanıcı
    // durumunu tazele ve açık olan login_gate sheet'ine haber ver.
    await AuthService.instance.checkEmailVerified();
    emailVerifiedPulse.value++;
  }

  Future<void> _handleResetPassword(String oobCode) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordConfirmScreen(oobCode: oobCode),
      ),
    );
  }
}
