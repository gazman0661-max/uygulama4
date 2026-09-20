import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_header.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// "SİTEYİ DEVRET" — Flutter tarafı (14.09.2026 eklendi, kanka isteği).
///
/// Freelancer/ajans modeli: bir freelancer, Sitora ile ürettiği/yayınladığı
/// bir siteyi bitirdiğinde müşteriye TAM olarak (site + tüm bilgiler)
/// teslim etmek isteyebilir. Akış:
///
///   1) Freelancer (mevcut sahip) Projelerim'de "Devret"e basar ->
///      [TransferService.initiate] çağrılır -> worker kısa/okunaklı bir kod
///      üretir (bkz. cloudflare/worker/src/index.mjs > handleTransferInitiate).
///   2) Freelancer bu kodu WhatsApp/SMS gibi bir kanaldan müşteriye iletir —
///      Sitora zaten e-posta göndermeyen bir akışa sahip (bkz.
///      DEGISIKLIKLER_14_09_2026_EMAIL_DOGRULAMA_KALDIRILDI.md).
///   3) Müşteri kendi hesabıyla "Kodla Site Devral" ekranından kodu girer ->
///      [TransferService.claim] çağrılır -> worker sahipliği (owner_uid/
///      owner_token) müşteriye geçirir ve proje anlık görüntüsünü
///      (SiteProject.toJson()) geri döner -> AppState.claimTransferredProject
///      bunu müşterinin kendi Projelerim listesine YENİ bir kayıt olarak yazar
///      (SİTENİN id'si AYNI kalır — worker/D1/R2 tarafında hiçbir şey
///      taşınmaz, sadece "kime ait" bilgisi değişir).
///
/// GÜVENLİK NOTU: kod 7 gün geçerlidir ve bir kez kullanılabilir (bkz. worker
/// tarafı). Kodu bilen herkes devri tamamlayabilir — bu BİLEREK böyle: kodu
/// paylaşmak zaten freelancer'ın bilinçli bir teslim eylemi, tıpkı bir
/// aktivasyon kodu paylaşmak gibi.
/// ============================================================================

class TransferException implements Exception {
  final String message;
  TransferException(this.message);
  @override
  String toString() => message;
}

/// [TransferService.initiate] sonucu.
class TransferInitiateResult {
  final String code;
  final DateTime expiresAt;
  TransferInitiateResult({required this.code, required this.expiresAt});

  factory TransferInitiateResult.fromJson(Map<String, dynamic> json) => TransferInitiateResult(
        code: json['code'] as String,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 7)),
      );
}

/// [TransferService.claim] sonucu.
class TransferClaimResult {
  final String siteId;
  final String ownerToken;
  final Map<String, dynamic> projectSnapshot;

  /// 16.09.2026 eklendi (kanka isteği — "domain devirde kaybolmasın" akışı).
  /// bkz. worker > handleTransferClaim dokümanı: 'kept_via_subscription' |
  /// 'kept_via_purchase' | 'stripped' | 'not_applicable' (site zaten
  /// abonelik kotasından bağlı bir domain taşımıyordu). AppState bunu,
  /// TEK doğru kaynak olarak kullanır — istemcinin claim ÇAĞRISINDA neyi
  /// İSTEDİĞİ (claimDomainViaOwnSubscription/claimDomainViaPurchase) ile
  /// worker'ın GERÇEKTE ne yaptığı (race condition/geçersiz durum) farklı
  /// olabilir.
  final String domainOutcome;

  /// 17.09.2026 eklendi (kanka isteği — "devir sırasında abonelik kaynaklı
  /// premium siteler" bug fix'i). bkz. worker > handleTransferClaim
  /// dokümanı: 'kept_via_subscription' | 'stripped' | 'not_applicable'.
  /// AppState bunu, domainOutcome ile AYNI şekilde TEK doğru kaynak olarak
  /// kullanır — istemcinin claim ÇAĞRISINDA neyi İSTEDİĞİ
  /// (claimQuotaViaOwnSubscription) ile worker'ın GERÇEKTE ne yaptığı
  /// (race condition/geçersiz durum) farklı olabilir.
  final String quotaOutcome;

  TransferClaimResult({
    required this.siteId,
    required this.ownerToken,
    required this.projectSnapshot,
    this.domainOutcome = 'not_applicable',
    this.quotaOutcome = 'not_applicable',
  });

  factory TransferClaimResult.fromJson(Map<String, dynamic> json) => TransferClaimResult(
        siteId: json['siteId'] as String,
        ownerToken: json['ownerToken'] as String,
        projectSnapshot: (json['projectSnapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
        domainOutcome: json['domainOutcome'] as String? ?? 'not_applicable',
        quotaOutcome: json['quotaOutcome'] as String? ?? 'not_applicable',
      );
}

/// [TransferService.preview] sonucu — 16.09.2026 eklendi (kanka isteği —
/// "gerçek sorun #3" fix'i). bkz. worker > handleTransferPreview dokümanı.
class TransferPreviewResult {
  final DateTime expiresAt;
  final bool subscriptionPremium;

  /// 16.09.2026 eklendi (kanka isteği — "domain devirde kaybolmasın" akışı).
  /// true ise bu sitenin domaini eski sahibin abonelik kotasından
  /// ÜCRETSİZ bağlanmış — claim ANINDA yeni sahip kendi aboneliğinden bir
  /// slot vermezse veya yıllık domain ücretini ödemezse SÖKÜLÜR (bkz.
  /// worker > handleTransferClaim). _claimTransferCode bunu preview
  /// sonrasında, claim'den ÖNCE kullanıcıya sormak için kullanır.
  final bool domainAtRisk;

  TransferPreviewResult({
    required this.expiresAt,
    required this.subscriptionPremium,
    this.domainAtRisk = false,
  });

  factory TransferPreviewResult.fromJson(Map<String, dynamic> json) => TransferPreviewResult(
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 7)),
        subscriptionPremium: json['subscriptionPremium'] as bool? ?? false,
        domainAtRisk: json['domainAtRisk'] as bool? ?? false,
      );
}

/// [TransferService.status] sonucu — 16.09.2026 eklendi (kanka isteği:
/// "otomatik kota serbest bırakma" fix'i, bkz. worker > handleTransferStatus
/// dokümanı ve AppState.checkPendingTransferClaims).
enum TransferCodeStatus {
  /// Kod hâlâ bekliyor — henüz kullanılmadı, süresi de dolmadı.
  pending,

  /// Kod kullanılmış — site artık başka bir hesapta. Çağıran taraf
  /// (AppState.checkPendingTransferClaims) bu durumda projeyi kendi
  /// deleteProject'iyle yerel listeden düşürüp kotayı serbest bırakır.
  claimed,

  /// Süre (7 gün) dolmuş ama hiç kullanılmadı.
  expired,

  /// Worker bu kodu bulamadı (ağ hatası, ya da aynı site için sonradan
  /// YENİ bir devir başlatılmış olabilir — pending_transfer_code kolonu
  /// tek bir devri tutar). BİLEREK 'claimed' DEĞİL — çağıran taraf bunu
  /// "emin olamadım" sayıp projeyi OLDUĞU GİBİ bırakmalı, asla körü körüne
  /// silmemeli.
  unknown,
}

class TransferCodeStatusResult {
  final TransferCodeStatus status;
  TransferCodeStatusResult(this.status);

  factory TransferCodeStatusResult.fromJson(Map<String, dynamic> json) {
    switch (json['status'] as String?) {
      case 'pending':
        return TransferCodeStatusResult(TransferCodeStatus.pending);
      case 'claimed':
        return TransferCodeStatusResult(TransferCodeStatus.claimed);
      case 'expired':
        return TransferCodeStatusResult(TransferCodeStatus.expired);
      default:
        return TransferCodeStatusResult(TransferCodeStatus.unknown);
    }
  }
}

class TransferService {
  /// Yeni sahip (müşteri) tarafında, [claim] ÇAĞRILMADAN ÖNCE kullanılır —
  /// KODU TÜKETMEZ (worker tarafında sadece GET/okuma, bkz. handleTransferPreview).
  /// Amaç: devraldığında abonelik kaynaklı premium kaybı riski olup olmadığını
  /// (subscriptionPremium) devir TAMAMLANMADAN ÖNCE öğrenip kullanıcıya
  /// önleyici bir "paket seç" seçeneği sunabilmek (bkz. projects_screen.dart >
  /// _claimTransferCode). 404/410 (geçersiz/süresi dolmuş kod) durumunda bile
  /// asıl [claim] çağrısının kendi hata mesajını göstermesi için burada
  /// SESSİZCE null döner — preview'ın başarısız olması devir denemesini
  /// engellemez, sadece önleyici uyarı gösterilemez.
  static Future<TransferPreviewResult?> preview({required String code}) async {
    if (!HostingConfig.isConfigured) return null;
    try {
      final res = await http.get(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/transfer/preview?code=${Uri.encodeComponent(code.trim())}'),
      );
      ServerTimeService.updateFromResponse(res);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return TransferPreviewResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }


  /// Mevcut sahip tarafında, KOD ÜRETİLDİKTEN SONRA kullanılır — 16.09.2026
  /// eklendi (kanka isteği: "otomatik kota serbest bırakma" fix'i, bkz.
  /// worker > handleTransferStatus dokümanı). KODU TÜKETMEZ (SADECE okur,
  /// [preview] ile AYNI güven modeli) — AppState.checkPendingTransferClaims
  /// tarafından, uygulama açılışında/"↻ Yenile"de, cihazda kayıtlı her
  /// bekleyen devir kodu için tekrar tekrar güvenle çağrılabilir. Ağ hatası
  /// ya da beklenmeyen bir yanıtta SESSİZCE [TransferCodeStatus.unknown]
  /// döner — çağıran taraf bunu "emin olamadım" sayar, hiçbir şeyi silmez.
  static Future<TransferCodeStatusResult> status({required String code}) async {
    if (!HostingConfig.isConfigured) return TransferCodeStatusResult(TransferCodeStatus.unknown);
    try {
      final res = await http.get(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/transfer/status?code=${Uri.encodeComponent(code.trim())}'),
      );
      ServerTimeService.updateFromResponse(res);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return TransferCodeStatusResult(TransferCodeStatus.unknown);
      }
      return TransferCodeStatusResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return TransferCodeStatusResult(TransferCodeStatus.unknown);
    }
  }

  /// Mevcut sahip tarafında çağrılır — [projectSnapshot] doğrudan
  /// `SiteProject.toJson()` çıktısı olmalı (bkz. AppState.initiateProjectTransfer).
  static Future<TransferInitiateResult> initiate({
    required String siteId,
    required String? ownerToken,
    required Map<String, dynamic> projectSnapshot,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/transfer/initiate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ownerToken': ownerToken, 'projectSnapshot': projectSnapshot}),
      );
    } catch (e) {
      throw TransferException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res); // bkz. domain_service.dart'taki aynı açıklama
    if (res.statusCode == 403) {
      throw TransferException('Bu projenin sahibi sen değilsin, devredemezsin.');
    }
    if (res.statusCode == 404) throw TransferException('Site bulunamadı — önce yayınlamalısın.');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TransferException('Devir kodu üretilemedi (${res.statusCode}).');
    }
    return TransferInitiateResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Yeni sahip (müşteri) tarafında çağrılır — [newOwnerUid]/[newOwnerEmail]
  /// müşterinin KENDİ Firebase Auth bilgileridir (bkz. AppState.claimTransferredProject).
  static Future<TransferClaimResult> claim({
    required String code,
    String? newOwnerUid,
    String? newOwnerEmail,
    // 16.09.2026 eklendi (kanka isteği — "domain devirde kaybolmasın"
    // akışı). İkisi de false ise davranış ESKİSİ GİBİDİR (domain, abonelik
    // kaynaklıysa sökülür) — bkz. worker > handleTransferClaim dokümanı.
    bool claimDomainViaOwnSubscription = false,
    bool claimDomainViaPurchase = false,
    // 17.09.2026 eklendi (kanka isteği — "devir sırasında abonelik kaynaklı
    // premium siteler" bug fix'i). False ise davranış ESKİSİ GİBİDİR
    // (abonelik kaynaklı site kotası sökülür) — bkz. worker >
    // handleTransferClaim dokümanı.
    bool claimQuotaViaOwnSubscription = false,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/transfer/claim'),
        // 19.09.2026: worker sıkı modda yeni sahibin uid'ini body'den değil bu
        // Firebase ID token'ından okur (newOwnerUid yalnızca eski/kapalı mod
        // uyumluluğu için hâlâ gönderiliyor).
        headers: {'Content-Type': 'application/json', ...await authHeaderIfSignedIn()},
        body: jsonEncode({
          'code': code.trim(),
          'newOwnerUid': newOwnerUid,
          'newOwnerEmail': newOwnerEmail,
          'claimDomainViaOwnSubscription': claimDomainViaOwnSubscription,
          'claimDomainViaPurchase': claimDomainViaPurchase,
          'claimQuotaViaOwnSubscription': claimQuotaViaOwnSubscription,
        }),
      );
    } catch (e) {
      throw TransferException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 401) throw TransferException('Siteyi devralmak için giriş yapmış olmalısın.');
    if (res.statusCode == 429) throw TransferException('Çok fazla hatalı kod denemesi yapıldı, biraz sonra tekrar dene.');
    if (res.statusCode == 404) throw TransferException('Kod geçersiz — kontrol edip tekrar dene.');
    if (res.statusCode == 410) {
      // 16.09.2026 eklendi (kanka isteği — "otomatik kota serbest bırakma"
      // fix'i) — worker artık aynı 410 durumunu İKİ farklı gerekçeyle
      // dönebiliyor (bkz. handleTransferClaim): 'already_claimed' (kod zaten
      // BAŞKA biri tarafından kullanılmış) ile 'code_expired' (7 gün geçmiş,
      // hiç kullanılmamış) — kullanıcıya doğru mesajı göstermek için body'deki
      // error alanına bakılır; ayrıştırılamazsa ESKİ (süre dolmuş) mesajı
      // güvenli varsayılan olarak kalır.
      var alreadyClaimed = false;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        alreadyClaimed = body['error'] == 'already_claimed';
      } catch (_) {
        alreadyClaimed = false;
      }
      throw TransferException(alreadyClaimed
          ? 'Bu kod zaten kullanılmış — site başka bir hesaba devredilmiş.'
          : 'Bu kodun süresi dolmuş (7 gün geçmiş).');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TransferException('Devir tamamlanamadı (${res.statusCode}).');
    }
    return TransferClaimResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
