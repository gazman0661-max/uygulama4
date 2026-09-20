import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crash_service.dart';

/// ============================================================================
/// SITORA ANALİTİK — İSKELET
/// ============================================================================
/// AuthService/CrashService ile AYNI desende: main.dart, Firebase
/// .initializeApp() BAŞARILI olursa [isAvailable]'ı true yapar (bkz.
/// main.dart — AuthService.isAvailable ile TAM AYNI anda, tam aynı yerden
/// set edilir). Kurulum tamamlanmadan (google-services.json eklenmeden)
/// FirebaseAnalytics.instance çağrıları hata fırlatabileceği için TÜM
/// metodlar try/catch içinde — isAvailable false ise hiçbir şey yapmadan
/// sessizce döner. Analitik ASLA uygulama akışını bloklamaz/çökertmez;
/// bir loglama başarısız olursa sadece CrashService'e düşer (debugPrint).
///
/// FIREBASE KONSOLU'NDA GÖRÜNECEK ÖZEL OLAYLAR (bkz. çağrı noktaları):
///   site_generated — bir site/sayfa başarıyla üretildiğinde
///                    params: {source, mode, kind?}
///                    source: 'quick_form' (biyo link/dijital kartvizit) |
///                    'form' (kuaför, avukat vb. sektöre özel formlar)
///                    Form tabanlı üretimler her zaman YENİ bir sitedir,
///                    o rakamlar net.
///   site_published — bir site yayınlandığında (HostingService.publish
///                    başarılı) — params: {subdomain}
///   purchase       — bir satın alma tamamlandığında — Firebase'in
///                    standart e-ticaret olayı, Analytics > Gelir/Ürün
///                    raporlarında OTOMATİK görünür (hangi ürün kaç kez
///                    satılmış dahil)
///   login          — Google ile giriş başarılı olduğunda — Firebase'in
///                    standart olayı, kaynak/tutma raporlarında kullanılır
///
/// 12.09.2026 eklendi (kanka isteği) — "site oluşturuldu ama 0 yayında"
/// bulgusundan sonra YAYINLAMA HUNİSİNİ adım adım görebilmek için eklenen
/// özel olaylar (bkz. çağrı noktaları):
///   publish_tapped            — kullanıcı "Yayınla" butonuna bastığında,
///                                requireLogin/ödeme kontrolünden ÖNCE
///                                (preview_screen.dart > _publishSite)
///   login_gate_shown          — yayınlama/satın alma akışı login sheet'ini
///                                açtığında — params: {feature}
///                                (login_gate.dart > requireLogin)
///   signup_pending_verification — kayıt isteği gönderildi, doğrulama
///                                maili yollandı (henüz doğrulanmadı)
///                                (login_gate.dart > _submit)
///   email_verified            — e-posta doğrulaması onaylandığında
///                                (login_gate.dart > _checkVerified)
/// Bu 4 olay + zaten var olan site_generated/site_published ile Firebase
/// Console'da huni: publish_tapped → login_gate_shown →
/// signup_pending_verification → email_verified → site_published şeklinde
/// kurulup TAM OLARAK hangi adımda kullanıcı kaybedildiği görülebilir.
///
/// 20.09.2026 eklendi (kanka isteği — "esnaf/freelancer için D1/D7 yerine
/// doğru ölçüler"): aktivasyon, paywall dönüşümü, bildirim kancası ve site
/// ömrü ölçümü için yeni olaylar + segmentasyon için KULLANICI ÖZELLİKLERİ.
///   site_published  → artık `is_first_publish` (1/0) parametresi taşır;
///                     güncellemeler (republish) ilk yayından ayrılabilir.
///   publish_failed  — yayınlama başarısız — params: {reason}
///                     reason: network | http_401 | http_403 | http_429 |
///                     http_<kod>
///   paywall_shown   — bir kilit/satın alma ekranı gösterildi —
///                     params: {trigger}: publish_paywall | download |
///                     domain | remove_watermark | store |
///                     subscription_plans | premium_locked
///   purchase_started / purchase_cancelled / purchase_failed —
///                     params: {product_id} (+ {reason} failed'da).
///                     Sadece TAMAMLANAN satın alma vardı; artık
///                     paywall_shown → purchase_started → purchase
///                     dönüşüm hunisi kurulabilir.
///   notification_permission — bildirim izni sonucu (sadece DEĞİŞİNCE
///                     loglanır) — params: {status}
///   push_opened     — kullanıcı bir FCM bildirimine dokunup uygulamayı
///                     açtı — params: {type: lead|mailbox|
///                     site_inactivity_warning|unknown, cold_start}
///   lead_inbox_opened — Talep Kutusu açıldı — params: {locked} (1 = ücretsiz
///                     planda kilit popup'ı gösterildi)
///   site_unpublished — params: {reason: user|quota}
///   site_deleted    — params: {was_published}
/// KULLANICI ÖZELLİKLERİ (Firebase Console > Özel tanımlar > Kullanıcı
/// özelliği olarak KAYDEDİLMELİ, yoksa raporlarda filtre olarak görünmez):
///   published_sites — yayındaki site sayısı kovası: 0 | 1 | 2_4 | 5_plus
///   created_sites   — oluşturulan site sayısı kovası (aynı kovalar)
///   sub_plan        — free | mini | freelancer | freelancer_max
///   notif_permission — granted | denied | provisional | not_determined
/// Freelancer vekili: created_sites/published_sites = 2_4 veya 5_plus.
///
/// D1/D7/D30 KULLANICI TUTMA (Retention): AYRICA KOD YAZMAYA GEREK YOK —
/// Analytics SDK'sı kurulup otomatik toplanan first_open olayı akmaya
/// başladığında Firebase Console > Retention raporu bunu KENDİLİĞİNDEN
/// hesaplar.
/// ============================================================================
class AnalyticsService {
  AnalyticsService._();

  /// main.dart, Firebase.initializeApp() başarılı olursa bunu true yapar.
  static bool isAvailable = false;

  static FirebaseAnalytics get _instance => FirebaseAnalytics.instance;

  static Future<void> _safeLog(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!isAvailable) return;
    try {
      await _instance.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.$name');
    }
  }

  /// Bir site/sayfa başarıyla üretildiğinde çağrılır (bkz. dosya başı NOT —
  /// 'ai_chat' kaynağı düzenlemeleri de kapsar).
  static Future<void> logSiteGenerated({
    required String source,
    required String mode,
    String? kind,
  }) {
    return _safeLog('site_generated', parameters: {
      'source': source,
      'mode': mode,
      if (kind != null) 'kind': kind,
    });
  }

  /// Bir site yayınlandığında çağrılır. [isFirstPublish]: bu proje için
  /// worker'a daha önce sahiplik token'ı verilmemişse (ilk yayın) true.
  static Future<void> logSitePublished({
    required String subdomain,
    bool isFirstPublish = false,
  }) {
    return _safeLog('site_published', parameters: {
      'subdomain': subdomain,
      'is_first_publish': isFirstPublish ? 1 : 0,
    });
  }

  /// Bir satın alma başarıyla tamamlandığında (tüketildikten sonra)
  /// çağrılır. Firebase'in tipli logPurchase metodunu kullanır ki
  /// Analytics > Gelir raporlarında ve "ürüne göre satış" listesinde
  /// otomatik/doğru görünsün.
  static Future<void> logPurchase({
    required String productId,
    double? value,
    String? currency,
  }) async {
    if (!isAvailable) return;
    try {
      await _instance.logPurchase(
        currency: currency,
        value: value,
        items: [AnalyticsEventItem(itemId: productId, itemName: productId)],
      );
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.logPurchase');
    }
  }

  /// E-posta/şifre ile giriş başarılı olduğunda çağrılır.
  static Future<void> logLogin({String method = 'password'}) async {
    if (!isAvailable) return;
    try {
      await _instance.logLogin(loginMethod: method);
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.logLogin');
    }
  }

  /// Kullanıcı "Yayınla" butonuna bastığında — requireLogin/ödeme
  /// kontrolünden ÖNCE, huninin en üst adımı olarak çağrılır.
  static Future<void> logPublishTapped() => _safeLog('publish_tapped');

  /// Yayınlama/satın alma akışı login sheet'ini açtığında çağrılır.
  /// [feature] hangi akışın tetiklediğini ayırt eder (ör. "Yayınlama").
  static Future<void> logLoginGateShown({required String feature}) {
    return _safeLog('login_gate_shown', parameters: {'feature': feature});
  }

  /// 14.09.2026 DEĞİŞTİRİLDİ (kanka kararı, e-posta doğrulama kaldırıldı)
  /// — hesap oluşturma anında (artık bekleme adımı olmadan) çağrılır,
  /// huninin son adımı bu.
  static Future<void> logSignUpCompleted() => _safeLog('signup_completed');

  // ── 20.09.2026: aktivasyon / paywall / bildirim / site ömrü olayları ──

  /// Yayınlama başarısız oldu (ağ ya da HTTP hatası).
  static void logPublishFailed({required String reason}) {
    unawaited(_safeLog('publish_failed', parameters: {'reason': reason}));
  }

  /// Bir kilit / satın alma ekranı kullanıcıya gösterildi.
  static void logPaywallShown({required String trigger}) {
    unawaited(_safeLog('paywall_shown', parameters: {'trigger': trigger}));
  }

  static void logPurchaseStarted({required String productId}) {
    unawaited(_safeLog('purchase_started', parameters: {'product_id': productId}));
  }

  static void logPurchaseCancelled({required String productId}) {
    unawaited(_safeLog('purchase_cancelled', parameters: {'product_id': productId}));
  }

  static void logPurchaseFailed({required String productId, required String reason}) {
    unawaited(_safeLog('purchase_failed', parameters: {
      'product_id': productId,
      'reason': reason,
    }));
  }

  static const String _notifPermPrefsKey = 'analytics_notif_permission_v1';

  /// Bildirim izni sonucu. Uygulama her açılışta izni sorguladığı için
  /// SADECE değer değiştiğinde loglanır (yeni kurulum = ilk değer).
  static Future<void> logNotificationPermission(String status) async {
    if (!isAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_notifPermPrefsKey) == status) return;
      await prefs.setString(_notifPermPrefsKey, status);
      await _instance.logEvent(
        name: 'notification_permission',
        parameters: {'status': status},
      );
      await _instance.setUserProperty(name: 'notif_permission', value: status);
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.logNotificationPermission');
    }
  }

  /// Kullanıcı bir FCM bildirimine dokunup uygulamayı açtı.
  static void logPushOpened({required String type, bool coldStart = false}) {
    unawaited(_safeLog('push_opened', parameters: {
      'type': type,
      'cold_start': coldStart ? 1 : 0,
    }));
  }

  /// Talep Kutusu açıldı; [locked] true ise ücretsiz planda kilit
  /// popup'ı gösterildi (premium'a yönlendirme fırsatı).
  static void logLeadInboxOpened({required bool locked}) {
    unawaited(_safeLog('lead_inbox_opened', parameters: {'locked': locked ? 1 : 0}));
  }

  static void logSiteUnpublished({required String reason}) {
    unawaited(_safeLog('site_unpublished', parameters: {'reason': reason}));
  }

  static void logSiteDeleted({required bool wasPublished}) {
    unawaited(_safeLog('site_deleted', parameters: {'was_published': wasPublished ? 1 : 0}));
  }

  // ── Kullanıcı özellikleri (segmentasyon: esnaf vs freelancer) ──

  static String? _lastPublishedBucket;
  static String? _lastCreatedBucket;
  static String? _lastPlan;

  static String _bucket(int n) {
    if (n <= 0) return '0';
    if (n == 1) return '1';
    if (n <= 4) return '2_4';
    return '5_plus';
  }

  /// Site sayısı kovaları ve abonelik planını kullanıcı özelliği olarak
  /// yazar. Değer değişmediyse Firebase'e tekrar gitmez. Analytics henüz
  /// hazır değilse (isAvailable false) hiçbir şey yapmaz ve önbelleğe
  /// almaz — sonraki çağrıda yeniden denenir.
  static Future<void> syncUserProperties({
    required int publishedSites,
    required int createdSites,
    required String plan,
  }) async {
    if (!isAvailable) return;
    try {
      final pub = _bucket(publishedSites);
      final cre = _bucket(createdSites);
      if (pub != _lastPublishedBucket) {
        await _instance.setUserProperty(name: 'published_sites', value: pub);
        _lastPublishedBucket = pub;
      }
      if (cre != _lastCreatedBucket) {
        await _instance.setUserProperty(name: 'created_sites', value: cre);
        _lastCreatedBucket = cre;
      }
      if (plan != _lastPlan) {
        await _instance.setUserProperty(name: 'sub_plan', value: plan);
        _lastPlan = plan;
      }
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.syncUserProperties');
    }
  }
}
