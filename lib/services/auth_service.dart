import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'analytics_service.dart';

/// ============================================================================
/// SITORA E-POSTA GİRİŞİ
/// ============================================================================
/// Bu servis Firebase Auth'u e-posta/şifre yöntemiyle sarmalar. Giriş
/// OPSİYONEL: uygulama giriş yapılmadan da (misafir, cihaz bazlı — bugünkü
/// davranış) tam çalışır. Sadece HOSTING (yayınlama) ve SATIN ALMA akışları
/// giriş gerektirecek şekilde tasarlandı (bkz. lib/widgets/login_gate.dart —
/// o widget bu servisi kullanarak "giriş gerekiyor" popup'ını gösterir).
///
/// NOT: Daha önce Google Sign-In kullanılıyordu; Google kaynaklı OAuth/
/// Play Services sorunları (ApiException: 10 vb.) nedeniyle tamamen
/// kaldırıldı, yerine sade e-posta/şifre akışı kondu.
///
/// KURULUM TAMAMLANMADAN (google-services.json eklenmeden) bu servisin
/// hiçbir metodu güvenle çağrılamaz — hepsi FirebaseAuth.instance'a
/// dokunuyor, o da Firebase.initializeApp() başarılı olmadıysa hata fırlatır.
/// main.dart bunu try/catch ile karşılıyor ve [AuthService.isAvailable]
/// üzerinden UI'a "Firebase henüz kurulmadı" bilgisini veriyor — bkz. orada.
///
/// Firebase Console'da Authentication > Sign-in method altında
/// "Email/Password" sağlayıcısının AÇIK olması gerekir.
/// ============================================================================
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// main.dart, Firebase.initializeApp() başarılı olursa bunu true yapar.
  /// google-services.json eklenip Firebase Console kurulumu tamamlanana
  /// kadar false kalır — UI bu durumda giriş butonunu gizleyebilir/
  /// "yakında" gösterebilir (bkz. login_gate.dart).
  static bool isAvailable = false;

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

  /// E-posta/şifre ile GİRİŞ. Hesap yoksa [AuthException] fırlatır
  /// (kullanıcı arayüzü bu durumda "Kayıt Ol"a yönlendirebilir).
  ///
  /// 30.08.2026 eklendi — e-posta doğrulanmamışsa giriş TAMAMLANMAZ:
  /// hemen signOut edilir ve [EmailNotVerifiedException] fırlatılır.
  /// Doğrulanmamış bir hesapla hiçbir ekrana (dolayısıyla yayınlama/
  /// satın alma akışlarına) erişilemez — sahte e-postayla sınırsız
  /// "ücretsiz yayın hakkı" üretilmesini engellemek için eklendi.
  Future<User?> signInWithEmail(String email, String password) async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      var user = cred.user;
      if (user != null) {
        // reload() şart: emailVerified bilgisi girişteki token'da BAYAT
        // olabilir (kullanıcı linke tıkladıktan hemen sonra giriş
        // yapıyorsa) — taze durumu almadan false'ta takılı kalabilir.
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
      }
      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        throw EmailNotVerifiedException();
      }
      unawaited(AnalyticsService.logLogin());
      return user;
    } on EmailNotVerifiedException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      throw AuthException('Giriş başarısız: $e');
    }
  }

  /// E-posta/şifre ile YENİ HESAP oluşturur.
  ///
  /// 30.08.2026 değiştirildi — artık otomatik giriş YAPMIYOR: hesap
  /// oluşturulur, doğrulama e-postası gönderilir, ardından HEMEN signOut
  /// edilip [EmailVerificationSentException] fırlatılır. Kullanıcı linke
  /// tıklayıp [signInWithEmail] ile tekrar giriş yapana kadar hesap
  /// kullanılamaz durumda kalır (bkz. o metottaki emailVerified kontrolü).
  Future<void> signUpWithEmail(String email, String password) async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      throw EmailVerificationSentException(email.trim());
    } on EmailVerificationSentException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      throw AuthException('Kayıt başarısız: $e');
    }
  }

  /// Doğrulama e-postasını YENİDEN gönderir. Kalıcı bir oturum AÇMADAN
  /// yapılamaz (Firebase Auth doğrulama linkini sadece o an giriş yapmış
  /// kullanıcıya gönderir) — bu yüzden e-posta/şifreyle KISA SÜRELİĞİNE
  /// giriş yapılır, e-posta gönderilir, sonra HEMEN tekrar signOut edilir.
  /// login_gate.dart'taki "Doğrulama e-postasını tekrar gönder" butonu
  /// bunu kullanır.
  Future<void> resendVerificationEmail(String email, String password) async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      throw AuthException('E-posta gönderilemedi: $e');
    }
  }

  /// Şifremi unuttum — Firebase'in hazır e-posta akışını tetikler. Bu
  /// bağlantı da e-postaya gönderilip sadece o kutuya erişimi olan
  /// açabildiği için, kendi başına zaten bir e-posta doğrulaması işlevi
  /// görür (şifreyi sıfırlayabilen kişi o adresin sahibidir).
  Future<void> sendPasswordResetEmail(String email) async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
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
      // çıkışta hata olsa da kullanıcıyı takılı bırakmayalım
    }
  }

  /// Firebase Auth hata kodlarını kullanıcıya gösterilecek Türkçe mesaja
  /// çevirir. Bilinmeyen kodlar için ham kod mesaj olarak döner.
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

/// 30.08.2026 eklendi — kayıt başarıyla oluşturuldu, doğrulama e-postası
/// gönderildi, ama hesap HENÜZ kullanılamaz durumda (signOut edildi).
/// UI bunu hata OLARAK değil, bilgilendirme olarak göstermeli.
class EmailVerificationSentException implements Exception {
  final String email;
  EmailVerificationSentException(this.email);
  final String message =
      'Doğrulama bağlantısı e-postana gönderildi. Linke tıkladıktan sonra giriş yapabilirsin.';
  @override
  String toString() => message;
}

/// 30.08.2026 eklendi — şifre doğru ama e-posta henüz doğrulanmamış,
/// bu yüzden giriş TAMAMLANMADI (signOut edildi).
class EmailNotVerifiedException implements Exception {
  final String message =
      'E-postanı henüz doğrulamadın. Gelen kutunu (ve spam klasörünü) kontrol et.';
  @override
  String toString() => message;
}

class AuthNotConfiguredException implements Exception {
  final String message =
      'Giriş sistemi henüz aktif değil. Firebase kurulumu tamamlanınca bu özellik otomatik açılacak.';
  @override
  String toString() => message;
}
