import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'analytics_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _authDomain = 'sitora-a9e27.firebaseapp.com';

  static const String _androidPackageName = 'com.sitora.ai';

  static String get authDomain => _authDomain;

  static ActionCodeSettings get _actionCodeSettings => ActionCodeSettings(
        url: 'https://$_authDomain/',
        handleCodeInApp: true,
        androidPackageName: _androidPackageName,
        androidInstallApp: false,
        androidMinimumVersion: '1',
      );

  static bool isAvailable = false;

  User? get currentUser {
    if (!isAvailable) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => currentUser != null;

  Stream<User?> get authStateChanges {
    if (!isAvailable) return const Stream.empty();
    return FirebaseAuth.instance.authStateChanges();
  }

  Future<User?> signInWithEmail(String email, String password) async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      unawaited(AnalyticsService.logLogin(method: 'password'));
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      throw AuthException('Giriş başarısız: $e');
    }
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      unawaited(AnalyticsService.logSignUpCompleted());
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      throw AuthException('Kayıt başarısız: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: _actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      throw AuthException('E-posta gönderilemedi: $e');
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
    }
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı bir hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda. Giriş yapmayı deneyin.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter kullanın.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı sorunu. Bağlantınızı kontrol edin.';
      default:
        return 'İşlem başarısız: $code';
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthNotConfiguredException implements Exception {
  final String message =
      'Giriş sistemi henüz aktif değil. Firebase kurulumu tamamlanınca bu özellik otomatik açılacak.';
  @override
  String toString() => message;
}
