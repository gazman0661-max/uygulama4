import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kReleaseMode, kProfileMode;
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
///
/// ============================================================================
/// DETAYLI TANI (DIAGNOSTICS) SİSTEMİ — NEDEN EKLENDİ
/// ============================================================================
/// "[16] Account reauth failed" / ApiException 10 gibi hatalar aynı görünüp
/// çok farklı kök nedenlerden (SHA-1 uyuşmazlığı, yanlış clientId, Play
/// Services eksik/güncel değil, OAuth consent screen testing modu, Firebase
/// credential exchange'in kendisi vb.) kaynaklanabiliyor. Varsayımlarla
/// ilerlemek yerine, HER hata için:
///   1) TAM olarak hangi adımda patladığı ([_AuthStep])
///   2) Ham exception tipi + code + description + details
///   3) O anki build modu, kullanılan clientId/serverClientId, paket adı
///   4) Kısa stack trace
/// bir arada, ekranda okunabilir/kopyalanabilir şekilde gösteriliyor
/// (bkz. AuthException.diagnosticsReport ve lib/widgets/login_gate.dart'taki
/// detay diyaloğu). Böylece "şu olabilir bu olabilir" tahmini ortadan kalkıp
/// gerçek log elde ediliyor.
/// ============================================================================
enum AuthStep {
  ensureInitialized('GoogleSignIn.initialize()'),
  authenticateAttempt1('GoogleSignIn.authenticate() — 1. deneme'),
  authenticateAttempt2('GoogleSignIn.authenticate() — 2. deneme (reauth-glitch retry)'),
  firebaseCredentialExchange('FirebaseAuth.signInWithCredential() — idToken → Firebase oturumu'),
  unknown('Bilinmeyen adım');

  final String label;
  const AuthStep(this.label);
}

/// Tek bir başarısız girişim hakkında toplanan HAM tanı verisi.
class AuthDiagnostics {
  final AuthStep step;
  final String exceptionType;
  final String? code;
  final String? description;
  final String? details;
  final String rawToString;
  final String stackTraceHead;
  final String buildMode;
  final String androidClientIdUsed;
  final String serverClientIdUsed;
  final String packageName;
  final DateTime timestamp;

  AuthDiagnostics({
    required this.step,
    required this.exceptionType,
    this.code,
    this.description,
    this.details,
    required this.rawToString,
    required this.stackTraceHead,
    required this.buildMode,
    required this.androidClientIdUsed,
    required this.serverClientIdUsed,
    required this.packageName,
  }) : timestamp = DateTime.now();

  /// Ekranda gösterilecek / kopyalanabilir düz metin rapor. Buradaki HER
  /// alan gerçek/ham veridir — hiçbir yorum/varsayım eklenmedi.
  String toReport() {
    final buf = StringBuffer();
    buf.writeln('=== Google Giriş Hata Raporu ===');
    buf.writeln('Zaman: ${timestamp.toIso8601String()}');
    buf.writeln('Adım: ${step.label}');
    buf.writeln('Build modu: $buildMode');
    buf.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buf.writeln('Paket adı: $packageName');
    buf.writeln('Kullanılan Android clientId: $androidClientIdUsed');
    buf.writeln('Kullanılan serverClientId (Web): $serverClientIdUsed');
    buf.writeln('---');
    buf.writeln('Exception tipi: $exceptionType');
    if (code != null) buf.writeln('code: $code');
    if (description != null) buf.writeln('description: $description');
    if (details != null) buf.writeln('details: $details');
    buf.writeln('Ham toString(): $rawToString');
    buf.writeln('---');
    buf.writeln('Stack trace (ilk satırlar):');
    buf.writeln(stackTraceHead);
    buf.writeln('=================================');
    return buf.toString();
  }
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// main.dart, Firebase.initializeApp() başarılı olursa bunu true yapar.
  /// google-services.json eklenip Firebase Console kurulumu tamamlanana
  /// kadar false kalır — UI bu durumda giriş butonunu gizleyebilir/
  /// "yakında" gösterebilir (bkz. login_gate.dart).
  static bool isAvailable = false;

  static const String _packageName = 'com.sitora.ai';

  /// google-services.json içindeki "Web client (auto created by Google
  /// Service)" client_id'si (client_type: 3).
  static const String _webClientId =
      '421106472212-8jskvd9s6memp363ve35cmjbp5rv2uo5.apps.googleusercontent.com';

  /// google-services.json içindeki, Play App Signing SHA-1'ine karşılık
  /// gelen "Android client for com.sitora.ai" client_id'si — RELEASE build
  /// (Play Store'dan inen APK) için kullanılır.
  static const String _androidClientIdRelease =
      '421106472212-pg72pj6761ssjo7l1cg5gs1km6clmc78.apps.googleusercontent.com';

  /// google-services.json içindeki, DEBUG keystore SHA-1'ine karşılık gelen
  /// Android client_id'si — DEBUG build için kullanılır.
  static const String _androidClientIdDebug =
      '421106472212-opp1titvbhmotnpf9v2s4v5j1pn4qmh3.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  /// UI'ın (login_gate.dart) her zaman erişebileceği SON hata tanısı.
  /// signInWithGoogle() null dönerse (gerçek iptal) bu null'a resetlenir.
  static AuthDiagnostics? lastDiagnostics;

  String get _buildMode {
    if (kDebugMode) return 'debug';
    if (kProfileMode) return 'profile';
    if (kReleaseMode) return 'release';
    return 'bilinmiyor';
  }

  String get _currentAndroidClientId =>
      kDebugMode ? _androidClientIdDebug : _androidClientIdRelease;

  AuthDiagnostics _buildDiagnostics({
    required AuthStep step,
    required Object error,
    required StackTrace stackTrace,
  }) {
    String? code;
    String? description;
    String? details;

    if (error is GoogleSignInException) {
      code = error.code.toString();
      description = error.description;
      details = error.details?.toString();
    } else if (error is FirebaseAuthException) {
      code = error.code;
      description = error.message;
      details = error.credential?.toString();
    }

    final stackLines = stackTrace.toString().split('\n');
    final stackHead = stackLines.take(12).join('\n');

    final diag = AuthDiagnostics(
      step: step,
      exceptionType: error.runtimeType.toString(),
      code: code,
      description: description,
      details: details,
      rawToString: error.toString(),
      stackTraceHead: stackHead,
      buildMode: _buildMode,
      androidClientIdUsed: _currentAndroidClientId,
      serverClientIdUsed: _webClientId,
      packageName: _packageName,
    );

    lastDiagnostics = diag;
    debugPrint(diag.toReport());
    return diag;
  }

  /// v7'de GoogleSignIn artık singleton; herhangi bir metod çağrılmadan
  /// önce initialize() bir kere await edilmiş olmalı. Lazy + guard ile
  /// birden fazla kez çağrılsa da güvenli.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final String androidClientId = _currentAndroidClientId;
    debugPrint('[AuthService] initialize() çağrılıyor, '
        'clientId=$androidClientId, serverClientId=$_webClientId '
        '(kDebugMode=$kDebugMode)');
    try {
      await _googleSignIn.initialize(
        clientId: androidClientId,
        serverClientId: _webClientId,
      );
      _initialized = true;
    } catch (e, st) {
      final diag = _buildDiagnostics(
        step: AuthStep.ensureInitialized,
        error: e,
        stackTrace: st,
      );
      throw AuthException(
        'Google giriş sistemi başlatılamadı (initialize() hata verdi).',
        diagnostics: diag,
      );
    }
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

  /// Google giriş akışını başlatır. Kullanıcı GERÇEKTEN hesap seçiciyi
  /// iptal ederse null döner (hata fırlatmaz) — çağıran taraf bunu
  /// sessizce ele almalı. Diğer tüm hatalar (aşağıdaki reauth-glitch
  /// retry'ından sonra bile) AuthException olarak fırlatılır ve UI'da
  /// TAM tanı raporuyla birlikte gösterilir — sessizce yutulmaz, tahmin
  /// yürütülmez.
  Future<User?> signInWithGoogle() async {
    if (!isAvailable) {
      throw AuthNotConfiguredException();
    }
    lastDiagnostics = null;
    try {
      await _ensureInitialized();
      return await _attemptSignIn(AuthStep.authenticateAttempt1);
    } on GoogleSignInException catch (e, st) {
      final diag = _buildDiagnostics(
        step: AuthStep.authenticateAttempt1,
        error: e,
        stackTrace: st,
      );

      // BİLİNEN CREDENTIAL MANAGER SORUNU (flutter/flutter #184918,
      // #174744): authenticate() önce cihazda bu uygulama+hesap için
      // daha önce KAYDEDİLMİŞ bir credential var mı diye SESSİZ bir
      // deneme yapıyor. İlk kurulumda/ilk girişte böyle bir kayıt henüz
      // yok, bu sessiz deneme "[16] Account reauth failed" ile
      // başarısız oluyor ve plugin bunu yanlışlıkla `canceled` olarak
      // işaretliyor — kullanıcı hiçbir şeyi iptal etmemiş olsa bile.
      final isReauthGlitch = e.code == GoogleSignInExceptionCode.canceled &&
          (e.description ?? '').toLowerCase().contains('reauth');

      // Gerçek kullanıcı iptali (reauth glitch DEĞİL) → sessizce null.
      if (e.code == GoogleSignInExceptionCode.canceled && !isReauthGlitch) {
        lastDiagnostics = null;
        return null;
      }

      if (!isReauthGlitch) {
        throw AuthException(
          'Google ile giriş başarısız — code: ${e.code}, description: '
          '${e.description ?? "(yok)"}',
          diagnostics: diag,
        );
      }

      debugPrint('[AuthService] "reauth failed" tespit edildi, 1 kez daha '
          'deneniyor...');
      try {
        return await _attemptSignIn(AuthStep.authenticateAttempt2);
      } on GoogleSignInException catch (e2, st2) {
        final diag2 = _buildDiagnostics(
          step: AuthStep.authenticateAttempt2,
          error: e2,
          stackTrace: st2,
        );
        // 2. deneme de aynı şekilde başarısızsa artık gerçek bir sorun
        // var demektir — SESSİZCE YUTMA, tam tanıyla birlikte göster.
        throw AuthException(
          'Google ile giriş başarısız (2 denemeden sonra) — code: '
          '${e2.code}, description: ${e2.description ?? "(yok)"}',
          diagnostics: diag2,
        );
      } on FirebaseAuthException catch (fe, fst) {
        final diag2 = _buildDiagnostics(
          step: AuthStep.firebaseCredentialExchange,
          error: fe,
          stackTrace: fst,
        );
        throw AuthException(
          'Firebase kimlik doğrulaması başarısız (2. deneme) — code: '
          '${fe.code}',
          diagnostics: diag2,
        );
      }
    } on FirebaseAuthException catch (fe, fst) {
      final diag = _buildDiagnostics(
        step: AuthStep.firebaseCredentialExchange,
        error: fe,
        stackTrace: fst,
      );
      throw AuthException(
        'Firebase kimlik doğrulaması başarısız — code: ${fe.code}',
        diagnostics: diag,
      );
    } catch (e, st) {
      final diag = _buildDiagnostics(
        step: AuthStep.unknown,
        error: e,
        stackTrace: st,
      );
      throw AuthException('Google ile giriş başarısız: $e', diagnostics: diag);
    }
  }

  /// Tek bir authenticate() + Firebase credential exchange denemesi.
  /// signInWithGoogle() bunu 1 veya 2 kez çağırabilir (bkz. yukarıdaki
  /// reauth-glitch retry mantığı). GoogleSignInException'ı / FirebaseAuth
  /// hatalarını BİLEREK burada yakalamıyor — çağıran taraf (signInWithGoogle)
  /// hem retry kararını versin hem de HANGİ adımda patladığını ([AuthStep])
  /// doğru etiketleyebilsin diye yukarı fırlatıyor.
  Future<User?> _attemptSignIn(AuthStep attemptStep) async {
    // 1) KİMLİK DOĞRULAMA (Credential Manager / authenticate())
    // v7'de authenticate() zaten kimlik doğrulamasını (identity) yapıp
    // idToken'ı veriyor. Firebase'e giriş için idToken TEK BAŞINA yeterli.
    final googleUser = await _googleSignIn.authenticate();

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      // Bu, authenticate() BAŞARILI görünse bile idToken'ın boş geldiği
      // (serverClientId yanlış/OAuth consent screen sorunlu olduğunda
      // görülen) sessiz bir hata durumu — GoogleSignInException fırlatmaz,
      // bu yüzden AYRICA yakalanması gerekiyor, yoksa "null idToken" hatası
      // Firebase tarafında anlaşılmaz bir şekilde patlar.
      throw AuthException(
        'Google girişi "başarılı" göründü ama idToken boş geldi. Bu genelde '
        'serverClientId (Web client) yanlış/eksik olduğunda veya OAuth '
        'consent screen kurulumunda bir sorun olduğunda görülür.',
        diagnostics: _buildDiagnostics(
          step: attemptStep,
          error: StateError('idToken null — googleUser.authentication.idToken boş döndü '
              '(email: ${googleUser.email})'),
          stackTrace: StackTrace.current,
        ),
      );
    }

    // 2) FIREBASE CREDENTIAL EXCHANGE — bu adımı BİLEREK ayrı try/catch'e
    // alıyoruz ki hata buradan gelirse (adım 1 zaten başarılıyken) UI'da
    // "authenticate() hatası" değil, doğru şekilde "Firebase exchange
    // hatası" olarak etiketlensin.
    late final UserCredential userCredential;
    try {
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (fe, fst) {
      throw AuthException(
        'Google kimlik doğrulaması BAŞARILI oldu ama Firebase oturumu '
        'açılamadı — code: ${fe.code}',
        diagnostics: _buildDiagnostics(
          step: AuthStep.firebaseCredentialExchange,
          error: fe,
          stackTrace: fst,
        ),
      );
    }

    // Analitik: 'login' — Firebase'in standart olayı, kaynak/tutma
    // raporlarında kullanılır. Kullanıcı akışını asla bloklamaz.
    unawaited(AnalyticsService.logLogin());
    return userCredential.user;
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
  final AuthDiagnostics? diagnostics;
  AuthException(this.message, {this.diagnostics});

  /// UI'ın (login_gate.dart) tıklanabilir "Detaylar" ile açacağı tam rapor.
  String get diagnosticsReport =>
      diagnostics?.toReport() ?? '(Bu hata için ek tanı verisi toplanamadı.)';

  @override
  String toString() => message;
}

class AuthNotConfiguredException implements Exception {
  final String message =
      'Google girişi henüz aktif değil. Firebase kurulumu tamamlanınca bu özellik otomatik açılacak.';
  @override
  String toString() => message;
}
