import 'dart:convert';
import 'package:http/http.dart' as http;
import 'activation_retry.dart';
import 'auth_header.dart';
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
///
/// 20.09.2026 EK: artık "bir kez dene, düşerse unut" DEĞİL — AppState bu
/// çağrıyı kalıcı bir kuyruğa yazıp [MiniPackageException.retry]'a göre
/// otomatik yeniden dener (bkz. activation_retry.dart ve
/// AppState._queueWorkerActivation). Sıkı modda bu, ağ hatasıyla düşen
/// aktivasyonun doğrulanmış kredisini boşta bırakmamak için gerekli.
/// ============================================================================
class MiniPackageException implements Exception {
  final String message;

  /// Bu hata sonrası isteğin tekrar denenip denenmeyeceği (bkz. [SyncRetry]).
  /// Belirtilmezse [SyncRetry.never] — yani eski "denedik, olmadı, bıraktık"
  /// davranışı.
  final SyncRetry retry;

  MiniPackageException(this.message, {this.retry = SyncRetry.never});
  @override
  String toString() => message;
}

class MiniPackageService {
  /// [siteId] zaten yayınlanmış bir projenin id'si olmalı — worker'da kaydı
  /// yoksa (site hiç yayınlanmamışsa) 404 döner, bu da [MiniPackageException]
  /// olarak fırlatılır (çağıran taraf best-effort olarak yutar, bkz. yukarısı).
  static Future<void> activate({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/mini-package/$siteId/activate'),
        headers: {
          if (ownerToken != null) 'x-owner-token': ownerToken,
          // 19.09.2026: sıkı modda worker doğrulanmış bir mini paket satın
          // alımını (kredi) bu hesaba bağlı arar — bkz. worker >
          // handleMiniPackageActivate.
          ...await authHeaderIfSignedIn(),
        },
        // 20.09.2026: zayıf ağda istek sonsuza dek asılı kalıp yeniden deneme
        // kuyruğunu tıkamasın — zaman aşımı da "ağ sorunu" sayılır (soon).
      ).timeout(const Duration(seconds: 25));
    } catch (e) {
      throw MiniPackageException('İnternet bağlantısı sorunu: $e', retry: SyncRetry.soon);
    }
    // 06.09.2026 eklendi — bkz. server_time_service.dart: cihaz saati
    // sapmasını worker'ın Date header'ından günceller.
    ServerTimeService.updateFromResponse(res);
    // Yeniden deneme sınıfları için bkz. syncRetryForStatus: 404 (site henüz
    // yayınlanmamış) ve 401 (giriş yok) yayınlama/giriş sonrası düzelebilir ->
    // later; 402/403 tekrar denemekle düzelmez -> never; 408/429/5xx -> soon.
    if (res.statusCode == 404) {
      throw MiniPackageException('Site henüz yayınlanmamış.', retry: syncRetryForStatus(404));
    }
    if (res.statusCode == 401) {
      throw MiniPackageException('Giriş yapmış olmalısın.', retry: syncRetryForStatus(401));
    }
    if (res.statusCode == 402) {
      throw MiniPackageException('Doğrulanmış bir mini paket satın alımı bulunamadı.', retry: syncRetryForStatus(402));
    }
    if (res.statusCode == 403) {
      throw MiniPackageException('Bu site sana ait değil gibi görünüyor.', retry: syncRetryForStatus(403));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MiniPackageException(
        'Mini paket sunucuya kaydedilemedi (${res.statusCode}).',
        retry: syncRetryForStatus(res.statusCode),
      );
    }
  }
}
