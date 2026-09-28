import 'package:http/http.dart' as http;
import 'activation_retry.dart';
import 'auth_header.dart';
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
///
/// 20.09.2026 EK: artık "bir kez dene, düşerse unut" DEĞİL — AppState bu
/// çağrıyı kalıcı bir kuyruğa yazıp [WatermarkSyncException.retry]'a göre
/// otomatik yeniden dener (bkz. activation_retry.dart ve
/// AppState._queueWorkerActivation). Worker tarafı tekrar-güvenli: zaten
/// kalıcı işaretlenmiş bir site için kredi istemeden 200 döner.
/// ============================================================================
class WatermarkSyncException implements Exception {
  final String message;

  /// Bu hata sonrası isteğin tekrar denenip denenmeyeceği (bkz. [SyncRetry]).
  /// Belirtilmezse [SyncRetry.never] — yani eski "denedik, olmadı, bıraktık"
  /// davranışı.
  final SyncRetry retry;

  WatermarkSyncException(this.message, {this.retry = SyncRetry.never});
  @override
  String toString() => message;
}

class WatermarkSyncService {
  /// [siteId] zaten yayınlanmış bir projenin id'si olmalı — worker'da kaydı
  /// yoksa 404 döner, bu da [WatermarkSyncException] olarak fırlatılır
  /// (çağıran taraf best-effort olarak yutar).
  static Future<void> markPermanent({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/watermark/$siteId/mark-permanent'),
        headers: {
          if (ownerToken != null) 'x-owner-token': ownerToken,
          // 19.09.2026: sıkı modda worker doğrulanmış bir rozet kaldırma
          // satın alımı (kredi) arar — bkz. worker > handleWatermarkMarkPermanent.
          ...await authHeaderIfSignedIn(),
        },
        // 20.09.2026: zayıf ağda istek sonsuza dek asılı kalıp yeniden deneme
        // kuyruğunu tıkamasın — zaman aşımı da "ağ sorunu" sayılır (soon).
      ).timeout(const Duration(seconds: 25));
    } catch (e) {
      throw WatermarkSyncException('İnternet bağlantısı sorunu: $e', retry: SyncRetry.soon);
    }
    ServerTimeService.updateFromResponse(res);
    // Yeniden deneme sınıfları için bkz. syncRetryForStatus.
    if (res.statusCode == 404) {
      throw WatermarkSyncException('Site henüz yayınlanmamış.', retry: syncRetryForStatus(404));
    }
    if (res.statusCode == 401) {
      throw WatermarkSyncException('Giriş yapmış olmalısın.', retry: syncRetryForStatus(401));
    }
    if (res.statusCode == 402) {
      throw WatermarkSyncException('Doğrulanmış bir rozet kaldırma satın alımı bulunamadı.', retry: syncRetryForStatus(402));
    }
    if (res.statusCode == 403) {
      throw WatermarkSyncException('Bu site sana ait değil gibi görünüyor.', retry: syncRetryForStatus(403));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WatermarkSyncException(
        'Kalıcı rozet kaldırma sunucuya kaydedilemedi (${res.statusCode}).',
        retry: syncRetryForStatus(res.statusCode),
      );
    }
  }
}
