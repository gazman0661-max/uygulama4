import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

  /// google-services.json içindeki "Web client (auto created by Google
  /// Service)" client_id'si (client_type: 3). google_sign_in v7'de Android
  /// tarafında ID token almak için bu ARTIK ZORUNLU — v6'da örtük olarak
  /// google-services.json'dan okunuyordu, v7 (Credential Manager tabanlı)
  /// bunu artık açıkça `serverClientId` olarak istiyor.
  ///
  /// NOT: `google_sign_in: ^6.x` paketi, Android'de eski/DEPRECATED
  /// `com.google.android.gms.auth.api.signin` API'sini kullanıyordu. Google
  /// bu API'yi Play Services Auth SDK'dan kaldırıyor — özellikle YENİ
  /// oluşturulan OAuth client'larda (bkz. Google Cloud Console'daki
  /// "Android client for com.sitora.ai (auto created by Google Service)"
  /// oluşturulma tarihi) bu artık SHA-1/paket adı %100 doğru olsa bile
  /// `PlatformException(sign_in_failed, ... ApiException: 10)` ile
  /// başarısız olabiliyor. Çözüm: v7'ye geçip Credential Manager tabanlı
  /// `authenticate()` akışını kullanmak (bkz. aşağıdaki signInWithGoogle).
  static const String _webClientId =
      '421106472212-8jskvd9s6memp363ve35cmjbp5rv2uo5.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  /// v7'de GoogleSignIn artık singleton; herhangi bir metod çağrılmadan
  /// önce initialize() bir kere await edilmiş olmalı. Lazy + guard ile
  /// birden fazla kez çağrılsa da güvenli.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    debugPrint('[AuthService] initialize() çağrılıyor, serverClientId=$_webClientId');
    try {
      await _googleSignIn.initialize(serverClientId: _webClientId);
      debugPrint('[AuthService] initialize() BAŞARILI');
    } catch (e, st) {
      debugPrint('[AuthService] initialize() HATA: $e');
      debugPrint('[AuthService] stack: $st');
      rethrow;
    }
    _initialized = true;
  }

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
      await _ensureInitialized();

      // v7'de authenticate() zaten kimlik doğrulamasını (identity) yapıp
      // idToken'ı veriyor. Firebase'e giriş için idToken TEK BAŞINA
      // yeterli — Firebase'in kendi resmi örneği de böyle
      // (firebase.google.com/docs/auth/flutter/federated-auth).
      //
      // ÖNEMLİ (önceki sürümdeki gizli hata): burada ayrıca
      // `authorizationClient.authorizeScopes(['email'])` çağrılıyordu.
      // Bu, INTERAKTİF bir ikinci izin ekranı daha açabiliyor/sistem
      // tarafından otomatik kapatılabiliyor; kapandığında
      // GoogleSignInException(canceled) fırlatıyor ve bu da aşağıdaki
      // catch bloğunda "kullanıcı iptal etti" sanılıp sessizce null
      // dönülüyordu. Sonuç: hesap seçiliyor ama giriş sheet'i hiçbir
      // hata göstermeden tekrar açılıyordu. 'email'/'profile' gibi
      // temel bilgiler zaten authenticate() ile geldiği için bu adıma
      // hiç gerek yok — kaldırdık.
      final googleUser = await _googleSignIn.authenticate();
      debugPrint('[AuthService] authenticate() BAŞARILI: ${googleUser.email}');

      final idToken = googleUser.authentication.idToken;
      debugPrint('[AuthService] idToken alındı mı: ${idToken != null} '
          '(uzunluk: ${idToken?.length ?? 0})');

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      debugPrint('[AuthService] FirebaseAuth.signInWithCredential çağrılıyor...');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('[AuthService] signInWithCredential BAŞARILI: '
          '${userCredential.user?.uid}');
      // Analitik: 'login' — Firebase'in standart olayı, kaynak/tutma
      // raporlarında kullanılır. Kullanıcı akışını asla bloklamaz.
      unawaited(AnalyticsService.logLogin());
      return userCredential.user;
    } on GoogleSignInException catch (e) {
      debugPrint('[AuthService] GoogleSignInException yakalandı: '
          'code=${e.code} description=${e.description} details=${e.details}');
      // GEÇİCİ DEBUG MODU: normalde `code == canceled` iken sessizce null
      // dönüp kullanıcıyı hiçbir şey göstermeden sheet'e geri
      // yolluyorduk — bu da "ekran sebepsiz geri dönüyor" hissi
      // yaratıyordu ve gerçek sebebi gizliyordu. Şimdilik HER
      // GoogleSignInException'ı (canceled dahil) ekranda gösteriyoruz ki
      // gerçekten kullanıcı mı iptal etti yoksa sistem mi (Play
      // Services/Credential Manager) sessizce reddetti anlaşılsın. Sorun
      // netleşince `canceled` durumunu tekrar sessiz null'a çevireceğiz.
      throw AuthException(
          'Google Sign-In hatası — code: ${e.code}, description: '
          '${e.description ?? "(yok)"}, details: ${e.details ?? "(yok)"}');
    } catch (e, st) {
      debugPrint('[AuthService] Beklenmeyen hata: $e');
      debugPrint('[AuthService] stack: $st');
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
