import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'analytics_service.dart';

/// ============================================================================
/// SITORA GOOGLE GİRİŞİ — İSKELET
/// ============================================================================
/// Bu servis Firebase Auth + Google Sign-In'i sarmalar. Giriş OPSİYONEL:
/// uygulama giriş yapılmadan da (misafir, cihaz bazlı — bugünkü davranış)
/// tam çalışır. Sadece HOSTING (yayınlama) ve SATIN ALMA akışları giriş
/// gerektirecek şekilde tasarlanacak (bkz. lib/widgets/login_gate.dart —
/// o widget bu servisi kullanarak "giriş gerekiyor" popup'ını gösterir).
///
/// KURULUM TAMAMLANMADAN (google-services.json eklenmeden) bu servisin
/// hiçbir metodu güvenle çağrılamaz — hepsi FirebaseAuth.instance'a
/// dokunuyor, o da Firebase.initializeApp() başarılı olmadıysa hata fırlatır.
/// main.dart bunu try/catch ile karşılıyor ve [AuthService.isAvailable]
/// üzerinden UI'a "Firebase henüz kurulmadı" bilgisini veriyor — bkz. orada.
///
/// SONRAKİ ADIM (bu iskelet kurulduktan sonra): AppState içine
/// currentUser'a göre kota/proje senkronizasyonu bağlanacak
/// (bkz. lib/services/user_data_service.dart — o dosyada güvenli kota
/// taşıma mantığı ZATEN yazılı, sadece AppState'e bağlanması kaldı).
/// ============================================================================
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// main.dart, Firebase.initializeApp() başarılı olursa bunu true yapar.
  /// google-services.json eklenip Firebase Console kurulumu tamamlanana
  /// kadar false kalır — UI bu durumda giriş butonunu gizleyebilir/
  /// "yakında" gösterebilir (bkz. login_gate.dart).
  static bool isAvailable = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  /// Şu an giriş yapmış kullanıcı (yoksa null — misafir modu demektir).
  User? get currentUser {
    if (!isAvailable) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => currentUser != null;

  /// Auth durumu değiştiğinde (giriş/çıkış) tetiklenir. AppState ileride
  /// bunu dinleyip kota/proje senkronizasyonunu tetikleyecek.
  Stream<User?> get authStateChanges {
    if (!isAvailable) return const Stream.empty();
    return FirebaseAuth.instance.authStateChanges();
  }

  /// Google giriş akışını başlatır. Kullanıcı iptal ederse null döner
  /// (hata fırlatmaz) — çağıran taraf bunu sessizce ele almalı.
  Future<User?> signInWithGoogle() async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // kullanıcı iptal etti

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      // Analitik: 'login' — Firebase'in standart olayı, kaynak/tutma
      // raporlarında kullanılır. Kullanıcı akışını asla bloklamaz.
      unawaited(AnalyticsService.logLogin());
      return userCredential.user;
    } catch (e) {
      throw AuthException('Google ile giriş başarısız: $e');
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();
    } catch (_) {
      // çıkışta hata olsa da kullanıcıyı takılı bırakmayalım
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
      'Google girişi henüz aktif değil. Firebase kurulumu tamamlanınca bu özellik otomatik açılacak.';
  @override
  String toString() => message;
}
