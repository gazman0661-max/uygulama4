import 'package:http/http.dart' as http;
import 'hosting_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// Rozet (watermark) kalıcı kaldırma — worker senkronizasyonu. 06.09.2026
/// eklendi (kanka isteği, devamı: "freeplana düşünce rozet geri gelsin, ama
/// kalıcı satın almışsa dokunma").
///
/// NEDEN GEREKLİ: AppState.removeWatermarkForProject SADECE yerel +
/// Firestore'a yazıyor. Worker'ın (dolayısıyla R2'de YAYINDA duran sitenin)
/// bir kaldırmanın KALICI mı (gerçek satın alma) yoksa GEÇİCİ mi (domain/mini
/// paket yan etkisi) olduğundan hiç haberi yoktu — bu da premiumDowngradeSweep
/// canlı siteyi ücretsiz katmana indirirken rozeti KALICI satın almış bir
/// kullanıcıya bile geri yapıştırabilirdi. Bu servis, MiniPackageService ile
/// AYNI desenle, kalıcı kaldırmayı worker'daki D1'e de yazar (bkz.
/// cloudflare/worker/src/index.mjs > watermark_removed_permanent).
///
/// BİLEREK "best-effort": bu çağrı başarısız olsa bile (internet yok, site
/// henüz yayınlanmamış -> 404) satın alma akışı ASLA bozulmamalı — kullanıcı
/// parasını zaten ödedi. AppState bu servisi `unawaited` + try/catch içinde
/// çağırır. En kötü ihtimalle bir SONRAKİ sweep'te rozet yanlışlıkla geri
/// enjekte edilebilir (kullanıcı zararına), o yüzden çağrı noktası kritik.
/// ============================================================================
class WatermarkSyncException implements Exception {
  final String message;
  WatermarkSyncException(this.message);
  @override
  String toString() => message;
}

class WatermarkSyncService {
  /// [siteId] zaten yayınlanmış bir projenin id'si olmalı — worker'da kaydı
  /// yoksa 404 döner, bu da [WatermarkSyncException] olarak fırlatılır
  /// (çağıran taraf best-effort olarak yutar).
  static Future<void> markPermanent({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/watermark/$siteId/mark-permanent'),
      );
    } catch (e) {
      throw WatermarkSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      throw WatermarkSyncException('Site henüz yayınlanmamış.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WatermarkSyncException('Kalıcı rozet kaldırma sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }
}
