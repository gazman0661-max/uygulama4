import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_header.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

class TransferException implements Exception {
  final String message;
  TransferException(this.message);
  @override
  String toString() => message;
}

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

class TransferClaimResult {
  final String siteId;
  final String ownerToken;
  final Map<String, dynamic> projectSnapshot;

  final String domainOutcome;

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

class TransferPreviewResult {
  final DateTime expiresAt;
  final bool subscriptionPremium;

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

enum TransferCodeStatus {
  pending,

  claimed,

  expired,

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
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 403) {
      throw TransferException('Bu projenin sahibi sen değilsin, devredemezsin.');
    }
    if (res.statusCode == 404) throw TransferException('Site bulunamadı — önce yayınlamalısın.');
    if (res.statusCode == 413) {
      throw TransferException('Proje devir için çok büyük. Bazı büyük içerikleri/fotoğrafları azaltıp tekrar dene.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TransferException('Devir kodu üretilemedi (${res.statusCode}).');
    }
    return TransferInitiateResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<TransferClaimResult> claim({
    required String code,
    String? newOwnerUid,
    String? newOwnerEmail,
    bool claimDomainViaOwnSubscription = false,
    bool claimDomainViaPurchase = false,
    bool claimQuotaViaOwnSubscription = false,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/transfer/claim'),
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
