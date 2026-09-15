import 'dart:convert';
import 'package:http/http.dart' as http;
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
  TransferClaimResult({
    required this.siteId,
    required this.ownerToken,
    required this.projectSnapshot,
  });

  factory TransferClaimResult.fromJson(Map<String, dynamic> json) => TransferClaimResult(
        siteId: json['siteId'] as String,
        ownerToken: json['ownerToken'] as String,
        projectSnapshot: (json['projectSnapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class TransferService {
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
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/transfer/claim'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code.trim(),
          'newOwnerUid': newOwnerUid,
          'newOwnerEmail': newOwnerEmail,
        }),
      );
    } catch (e) {
      throw TransferException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) throw TransferException('Kod geçersiz — kontrol edip tekrar dene.');
    if (res.statusCode == 410) throw TransferException('Bu kodun süresi dolmuş (7 gün geçmiş).');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TransferException('Devir tamamlanamadı (${res.statusCode}).');
    }
    return TransferClaimResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
