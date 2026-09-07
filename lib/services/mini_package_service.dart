import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hosting_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// "1 Aylık Mini Paket" — worker senkronizasyonu. 06.09.2026 eklendi (kanka
/// isteği, ekran görüntüsündeki tartışmanın devamı: "boşa masraf çıkmasın").
///
/// NEDEN GEREKLİ: AppState.activateMiniPackage ÖNCEDEN sadece yerel
/// (SharedPreferences) + Firestore'a yazıyordu — worker'ın (dolayısıyla
/// R2'de YAYINDA duran sitenin) mini paketin ne zaman satın alındığından/süresinin
/// dolduğundan HİÇ haberi yoktu. Bu servis, DomainService.renew ile AYNI
/// desenle, o tarihi worker'daki D1'e de yazar — böylece
/// cloudflare/worker/src/index.mjs > premiumDowngradeSweep, süresi dolmuş
/// mini paketleri kullanıcı uygulamayı hiç açmasa bile GÜNDE BİR otomatik
/// tespit edip canlı siteyi ücretsiz katmana indirebilir.
///
/// BİLEREK "best-effort" tasarlandı: bu çağrı BAŞARISIZ olsa bile (internet
/// yok, site henüz hiç yayınlanmamış -> 404, vs.) satın alma/aktivasyon akışı
/// ASLA bozulmamalı — kullanıcı parasını zaten ödedi, rozet/kilit açma yerel
/// olarak devam etmeli. Bu yüzden AppState.activateMiniPackage bu servisi
/// `unawaited` + try/catch içinde çağırır, hatayı yutar. Worker senkron
/// olamazsa en kötü ihtimalle premiumDowngradeSweep o siteyi hiç aday
/// göstermez (mini_package_activated_at NULL kalır) — kullanıcı zararına
/// değil, Sitora'nın (küçük bir maliyet) zararına bir durum, kabul edilebilir.
/// ============================================================================
class MiniPackageException implements Exception {
  final String message;
  MiniPackageException(this.message);
  @override
  String toString() => message;
}

class MiniPackageService {
  /// [siteId] zaten yayınlanmış bir projenin id'si olmalı — worker'da kaydı
  /// yoksa (site hiç yayınlanmamışsa) 404 döner, bu da [MiniPackageException]
  /// olarak fırlatılır (çağıran taraf best-effort olarak yutar, bkz. yukarısı).
  static Future<void> activate({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/mini-package/$siteId/activate'),
      );
    } catch (e) {
      throw MiniPackageException('İnternet bağlantısı sorunu: $e');
    }
    // 06.09.2026 eklendi — bkz. server_time_service.dart: cihaz saati
    // sapmasını worker'ın Date header'ından günceller.
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      throw MiniPackageException('Site henüz yayınlanmamış.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MiniPackageException('Mini paket sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }
}
