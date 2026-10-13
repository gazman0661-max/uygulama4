import 'dart:async';
import 'package:app_links/app_links.dart';
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
///   - mode=resetPassword → oobCode ile [ResetPasswordConfirmScreen]'i açar
///     (bu ekran olmasa kullanıcı şifresini HİÇBİR ŞEKİLDE sıfırlayamazdı,
///     çünkü link artık tarayıcıya değil buraya düşüyor — bkz.
///     auth_service.dart > sendPasswordResetEmail'deki not).
///   - diğer modlar (verifyEmail, recoverEmail vb.) → yok sayılır. 14.09.2026:
///     e-posta doğrulaması kaldırıldığı için verifyEmail linki artık hiç
///     gönderilmiyor, bu mod pratikte hiç gelmeyecek.
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
      case 'resetPassword':
        await _handleResetPassword(oobCode);
        break;
      default:
        // verifyEmail (artık hiç gönderilmiyor), recoverEmail,
        // revertSecondFactorAddition vb. — kapsam dışı, sessizce yok sayılır.
        break;
    }
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
