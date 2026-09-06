import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'hosting_service.dart';
import 'notification_service.dart';

/// ============================================================================
/// SITORA GERÇEK PUSH BİLDİRİM (FCM) — 03.09.2026 eklendi
/// ============================================================================
/// NotificationService (bkz. o dosya) sadece CİHAZDA planlanmış/anlık-
/// uygulama-açıkken bildirimler sağlıyordu — uygulama tamamen kapalıyken
/// (ör. bir müşteri "Talep Gönder" formunu doldurduğunda ya da admin bir
/// hediye/mesaj gönderdiğinde) hiçbir şey tetiklenmiyordu, çünkü tetikleyici
/// Firestore stream'i sadece MainShell yaşarken (yani uygulama açıkken)
/// dinleniyordu (bkz. main_shell.dart > _watchForNewMessages).
///
/// Bu sınıf o boşluğu dolduran ASIL parça — cihazın FCM token'ını alıp
/// Worker'a kaydeder (bkz. cloudflare/worker/src/index.mjs >
/// handleFcmTokenRegister). Worker artık yeni bir talep/mesaj geldiğinde bu
/// token'a GERÇEK bir push gönderiyor; Android bunu uygulama kapalıyken bile
/// sistem bildirim tepsisinde otomatik gösterir. Sadece uygulama AÇIKKEN
/// gelen push'lar otomatik gösterilmez (Android'in kuralı budur) — o yüzden
/// [_onForegroundMessage] bunu NotificationService.showPushNotification ile
/// elle tetikliyor.
///
/// TÜM public metodlar (NotificationService'teki AYNI kuralla) hataları
/// yutar — push kaydı başarısız olsa bile uygulamanın geri kalanı (giriş,
/// site üretimi, yayınlama) asla bundan etkilenmemeli.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<dynamic>? _authSub;
  bool _initialized = false;

  /// [03.09.2026 düzeltildi] Bu cihazda EN SON Worker'a kaydedilen (uid,
  /// token) çifti — çıkış yapıldığında Worker'daki kaydı silebilmek için
  /// tutuluyor. Eskiden çıkışta hiçbir şey yapılmıyordu ve Worker'ın
  /// "geçersiz token'ı otomatik temizlemesine" güveniliyordu — ama bir FCM
  /// token'ı hesaba değil CİHAZ KURULUMUNA bağlıdır: A çıkış yapıp B aynı
  /// cihazda girdiğinde token FCM açısından hâlâ geçerli kalır, bu yüzden
  /// otomatik temizlik hiç tetiklenmez. Sonuç: D1'de hem (A, token) hem
  /// (B, token) satırı birlikte var olur ve A'nın işine gelen bir talep,
  /// artık B'nin elindeki cihaza push olarak gider — hesaplar arası bir
  /// bildirim sızıntısı. Şimdi çıkışta bu çift Worker'dan siliniyor (bkz.
  /// _authSub aşağıda).
  String? _lastRegisteredUid;
  String? _lastRegisteredToken;

  /// main.dart'tan, Firebase.initializeApp() BAŞARILI olduktan sonra bir kez
  /// çağrılır. AuthService.isAvailable false ise (Firebase henüz
  /// kurulmadıysa) hiçbir şey yapmaz — diğer servislerle AYNI desen.
  Future<void> init() async {
    if (_initialized || !AuthService.isAvailable) return;
    _initialized = true;

    try {
      // Android'de bu çağrı POST_NOTIFICATIONS izniyle aynı sistem iznini
      // paylaşır (NotificationService.init() zaten istiyor) — burada TEKRAR
      // istemek zararsız (sistem ikinci kez sormaz) ve iOS'a geçilirse
      // (şu an ios/ klasörü yok) gerekli olacak tek satır bu.
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Uygulama AÇIKKEN gelen push'lar Android tarafından OTOMATİK
      // gösterilmez (sadece arka plan/kapalıyken sistem gösterir) — bu
      // yüzden elle bir yerel bildirime çeviriyoruz (bkz. sınıf başı
      // doküman).
      _foregroundSub =
          FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Token cihaz/OS tarafından herhangi bir an yenilenebilir (yeniden
      // kurulum, önbellek temizliği vb.) — yenilenince Worker'daki kaydı
      // da güncellememiz gerekiyor, yoksa push eski (artık geçersiz)
      // token'a gitmeye devam eder.
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) _registerToken(uid, token);
      });

      // Kullanıcı giriş yaptığında (ya da uygulama zaten girişliyken ilk
      // açıldığında) token'ı hemen kaydet. [03.09.2026 düzeltildi] Çıkış
      // yapıldığında (user == null) artık bu cihazda EN SON kaydedilen
      // (uid, token) çifti Worker'dan da siliniyor — bkz. sınıf başı
      // _lastRegisteredUid/_lastRegisteredToken dokümanı için gerekçe.
      _authSub = AuthService.instance.authStateChanges.listen((user) {
        if (user != null) {
          _registerCurrentToken(user.uid);
        } else {
          _unregisterLastToken();
        }
      });

      final currentUid = AuthService.instance.currentUser?.uid;
      if (currentUid != null) {
        await _registerCurrentToken(currentUid);
      }
    } catch (e) {
      // Sessizce geç — push, uygulamanın YAN özelliği (bkz. sınıf başı
      // doküman), hiçbir kritik akışı kesmemeli.
    }
  }

  Future<void> _registerCurrentToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(uid, token);
    } catch (_) {
      // sessiz geç
    }
  }

  Future<void> _registerToken(String uid, String token) async {
    if (!HostingConfig.isConfigured) return;
    try {
      await http
          .post(
            Uri.parse('${HostingConfig.baseUrl}/api/fcm-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid, 'token': token, 'platform': 'android'}),
          )
          .timeout(const Duration(seconds: 10));
      // Kayıt (başarılı ya da başarısız fark etmez, bkz. aşağıdaki not)
      // sonrası bu çifti hatırla ki çıkışta silinecek doğru (uid, token)
      // elde olsun. İstek ağ hatasıyla başarısız olsa bile burayı
      // güncelliyoruz — Worker'da hiç oluşmamış bir kaydı silmeye
      // çalışmak zararsızdır (DELETE, olmayan satırda no-op'tur), ama
      // gerçekten oluşmuş bir kaydı ATLAMAMAK çok daha önemli.
      _lastRegisteredUid = uid;
      _lastRegisteredToken = token;
    } catch (_) {
      // Ağ hatası: kritik değil, bir sonraki açılışta/token yenilenmesinde
      // tekrar denenecek.
    }
  }

  /// [03.09.2026 eklendi] Çıkış yapıldığında (authStateChanges -> null)
  /// çağrılır — bu cihazda EN SON kaydedilen (uid, token) çiftini
  /// Worker'dan siler ki bir sonraki kullanıcı AYNI cihaza girdiğinde eski
  /// hesabın push'larını almasın (bkz. sınıf başı doküman). Best-effort:
  /// hata olsa da sessizce geçilir, çift her durumda temizlenir ki bir
  /// dahaki çıkışta eski (artık geçersiz) bilgiyle tekrar silme
  /// denenmesin.
  Future<void> _unregisterLastToken() async {
    final uid = _lastRegisteredUid;
    final token = _lastRegisteredToken;
    _lastRegisteredUid = null;
    _lastRegisteredToken = null;
    if (uid == null || token == null || !HostingConfig.isConfigured) return;
    try {
      await http
          .delete(
            Uri.parse('${HostingConfig.baseUrl}/api/fcm-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid, 'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Ağ hatası: kritik değil — token yine de bir sonraki başarısız
      // push denemesinde Worker tarafından (UNREGISTERED/NOT_FOUND
      // görülürse) otomatik temizlenir.
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    NotificationService.instance.showPushNotification(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: message.data['type'] as String?,
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _authSub?.cancel();
  }
}

/// FCM'in gerektirdiği ÜST DÜZEY (top-level) arka plan işleyicisi —
/// main.dart'ta `FirebaseMessaging.onBackgroundMessage(...)` ile kaydedilir.
/// Uygulama arka planda/kapalıyken gelen bir push'un `notification` alanı
/// varsa (bizim TÜM push'larımızda var, bkz. Worker > sendFcmToToken) Android
/// bunu zaten OTOMATİK sistem tepsisinde gösterir — bu fonksiyonun BOŞ
/// olması bilinçli: sadece Flutter'ın ayrı bir isolate'te Firebase'e ihtiyaç
/// duyabilecek gelecekteki veri-mesajları için "hook noktası" olarak duruyor.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Bilerek boş — bkz. yukarıdaki doküman.
}
