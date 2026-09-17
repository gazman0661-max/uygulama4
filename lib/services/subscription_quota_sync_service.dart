import 'package:http/http.dart' as http;
import 'hosting_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// AYLIK ABONELİK KOTA SLOTU — worker senkronizasyonu. 16.09.2026 eklendi
/// (kanka isteği — "gerçek sorun #3" fix'i).
///
/// NEDEN GEREKLİ: MiniPackageService/DomainService ile AYNI kök sorun.
/// AppState.assignProjectToSubscriptionQuota/unassignProjectFromSubscriptionQuota
/// ÖNCEDEN sadece yerel (SharedPreferences/SiteProject) + Firestore'a
/// yazıyordu — worker'ın (dolayısıyla R2'de YAYINDA duran sitenin) hangi
/// sitenin hangi HESABIN aboneliğiyle kota içinde tutulduğundan HİÇ haberi
/// yoktu. Bu yüzden `premiumDowngradeSweep`, domain/mini paketten farklı
/// olarak abonelik-kaynaklı premium'u (fazla sayfa, harita/talep formu,
/// rozet kaldırma) HİÇ göremiyordu — bir kullanıcı aboneliğini iptal edip
/// uygulamayı bir daha hiç açmasa, canlı site sonsuza dek tam maliyetli
/// premium yayında kalmaya devam ederdi (bkz. proje sohbeti "Gerçek sorun
/// #3").
///
/// Bu servis, DomainService/MiniPackageService ile AYNI desenle, "bu site
/// şu an HANGİ hesabın aboneliğiyle kota içinde" bilgisini worker'daki D1'e
/// (`sites.subscription_quota_uid`) yazar — premiumDowngradeSweep bunu
/// `subscriptions.status` ile JOIN edip abonelik artık 'active' DEĞİLSE
/// içeriği otomatik indirir (bkz. cloudflare/worker/src/index.mjs >
/// premiumDowngradeSweep dokümanı).
///
/// BİLEREK "best-effort": bu çağrılar başarısız olsa bile (internet yok,
/// site henüz yayınlanmamış -> 404) kota atama/kaldırma akışı ASLA
/// bozulmamalı — kullanıcı zaten parasını ödüyor/hakkı yerel olarak zaten
/// açıldı. AppState bu servisi `unawaited` + `catchError` içinde çağırır.
/// En kötü ihtimalle worker'daki durum bir süre eski kalır, bir SONRAKİ
/// başarılı çağrıda (örn. bir sonraki assign/unassign ya da yeniden
/// yayınlama) kendiliğinden düzelir.
/// ============================================================================
class SubscriptionQuotaSyncException implements Exception {
  final String message;
  SubscriptionQuotaSyncException(this.message);
  @override
  String toString() => message;
}

class SubscriptionQuotaSyncService {
  /// [siteId] bu HESABIN (uid) aktif abonelik kotasına ANINDA atandığında
  /// çağrılır (bkz. AppState.assignProjectToSubscriptionQuota). Site
  /// worker'da henüz yayınlanmamışsa 404 döner — normal karşılanır (bkz.
  /// MiniPackageService.activate'teki AYNI gerekçe: yayınlanmamış bir
  /// sitede zaten R2'de düşürülecek/korunacak bir şey yok, kullanıcı
  /// ileride yayınladığında assign tekrar çağrılabilir).
  static Future<void> assign({required String siteId, required String uid}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-quota'),
        headers: {'Content-Type': 'application/json'},
        body: '{"uid":"$uid"}',
      );
    } catch (e) {
      throw SubscriptionQuotaSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      throw SubscriptionQuotaSyncException('Site henüz yayınlanmamış.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionQuotaSyncException('Abonelik kotası sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }

  /// [siteId] kota slotundan çıkarıldığında (kullanıcı kendisi çıkardığında
  /// VEYA "Siteyi Devret" ile sahiplik değiştiğinde — bkz.
  /// AppState.claimTransferredProject/unassignProjectFromSubscriptionQuota)
  /// çağrılır. NOT: "Siteyi Devret" akışında worker zaten
  /// handleTransferClaim İÇİNDE bu alanı NULL'a çeker (bkz. o fonksiyonun
  /// dokümanı) — buradaki çağrı sadece istemcinin kendi kayıtlarıyla
  /// tutarlılığı garanti altına alan bir EK/yedek adımdır, atlansa da
  /// worker tarafı zaten doğru olur.
  static Future<void> unassign({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.delete(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-quota'),
      );
    } catch (e) {
      throw SubscriptionQuotaSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      // Site hiç yayınlanmamış ya da zaten atanmamış — no-op sayılır.
      return;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionQuotaSyncException('Abonelik kotası kaldırma sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }

  /// 16.09.2026 eklendi (kanka isteği — "domainQuota kullanılmıyor" fix'i).
  /// [assign]/[unassign] ile BİREBİR AYNI desen, sadece `subscription-domain`
  /// ucuna ve `sites.subscription_domain_uid` koluna yazar (bkz.
  /// AppState.assignDomainQuota/unassignDomainQuota).
  static Future<void> assignDomain({required String siteId, required String uid}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-domain'),
        headers: {'Content-Type': 'application/json'},
        body: '{"uid":"$uid"}',
      );
    } catch (e) {
      throw SubscriptionQuotaSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      throw SubscriptionQuotaSyncException('Site henüz yayınlanmamış.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionQuotaSyncException('Abonelik domain kotası sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }

  static Future<void> unassignDomain({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.delete(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-domain'),
      );
    } catch (e) {
      throw SubscriptionQuotaSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionQuotaSyncException('Abonelik domain kotası kaldırma sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }
}
