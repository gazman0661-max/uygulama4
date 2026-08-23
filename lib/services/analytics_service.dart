import 'package:firebase_analytics/firebase_analytics.dart';
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
///                    source: 'ai_chat' (sohbet ekranı) | 'quick_form'
///                    (biyo link/dijital kartvizit) | 'form' (kuaför,
///                    avukat vb. sektöre özel formlar)
///                    NOT: 'ai_chat' kaynağı hem YENİ üretimi hem de aynı
///                    sohbette YAPILAN DÜZENLEMEYİ (previousCode doluysa)
///                    kapsar — Worker tarafı ikisini ayrı uçlara ayırmadığı
///                    için şu an ayrıştırılamıyor. Yani AI Chat kaynaklı
///                    sayı "üretim+düzenleme" toplamıdır, sadece "yeni site"
///                    değil. Form tabanlı üretimler (quick_form/form) her
///                    zaman YENİ bir sitedir, o rakamlar net.
///   site_published — bir site yayınlandığında (HostingService.publish
///                    başarılı) — params: {subdomain}
///   purchase       — bir satın alma tamamlandığında — Firebase'in
///                    standart e-ticaret olayı, Analytics > Gelir/Ürün
///                    raporlarında OTOMATİK görünür (hangi ürün kaç kez
///                    satılmış dahil)
///   login          — Google ile giriş başarılı olduğunda — Firebase'in
///                    standart olayı, kaynak/tutma raporlarında kullanılır
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

  /// Bir site yayınlandığında çağrılır.
  static Future<void> logSitePublished({required String subdomain}) {
    return _safeLog('site_published', parameters: {'subdomain': subdomain});
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

  /// Google ile giriş başarılı olduğunda çağrılır.
  static Future<void> logLogin({String method = 'google'}) async {
    if (!isAvailable) return;
    try {
      await _instance.logLogin(loginMethod: method);
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.logLogin');
    }
  }
}
