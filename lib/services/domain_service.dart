import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_header.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

class DomainNotConfiguredException implements Exception {
  final String message =
      'Domain bağlama henüz aktif değil. Bu özellik Cloudflare tarafında yapılandırılınca otomatik açılacak.';
  @override
  String toString() => message;
}

class DomainException implements Exception {
  final String message;
  DomainException(this.message);
  @override
  String toString() => message;
}

class DnsRecordHint {
  final String type;
  final String name;
  final String value;
  DnsRecordHint({required this.type, required this.name, required this.value});

  factory DnsRecordHint.fromJson(Map<String, dynamic> json) => DnsRecordHint(
        type: (json['type'] as String?) ?? 'CNAME',
        name: json['name'] as String? ?? '',
        value: (json['value'] as String?) ?? (json['target'] as String?) ?? '',
      );
}

class DomainCheckResult {
  final String? domain;
  final String status;
  final String code;
  final String? expected;
  final List<String> found;

  DomainCheckResult({
    required this.domain,
    required this.status,
    required this.code,
    this.expected,
    this.found = const [],
  });

  bool get isActive => code == 'active' || status == 'active';

  factory DomainCheckResult.fromJson(Map<String, dynamic> json) => DomainCheckResult(
        domain: json['domain'] as String?,
        status: json['status'] as String? ?? 'pending',
        code: json['code'] as String? ?? 'unknown',
        expected: json['expected'] as String?,
        found: ((json['found'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

class DomainConnectResult {
  final String domain;
  final String status;
  final bool apexWarning;
  final String? suggestedDomain;
  final DnsRecordHint cnameRecord;
  final List<DnsRecordHint> sslValidationRecords;

  DomainConnectResult({
    required this.domain,
    required this.status,
    required this.apexWarning,
    required this.suggestedDomain,
    required this.cnameRecord,
    required this.sslValidationRecords,
  });

  factory DomainConnectResult.fromJson(Map<String, dynamic> json) => DomainConnectResult(
        domain: json['domain'] as String,
        status: json['status'] as String? ?? 'pending',
        apexWarning: json['apexWarning'] as bool? ?? false,
        suggestedDomain: json['suggestedDomain'] as String?,
        cnameRecord: DnsRecordHint.fromJson(
          (json['cnameRecord'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        sslValidationRecords: ((json['sslValidationRecords'] as List?) ?? const [])
            .map((e) => DnsRecordHint.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class DomainStatusResult {
  final String? domain;
  final String status;
  final String? detail;
  final bool expired;
  final DateTime? domainConnectedAt;
  final DateTime? domainExpiresAt;

  DomainStatusResult({
    required this.domain,
    required this.status,
    this.detail,
    this.expired = false,
    this.domainConnectedAt,
    this.domainExpiresAt,
  });

  bool get isConnected => status == 'active';
  bool get isError => status == 'error';

  factory DomainStatusResult.fromJson(Map<String, dynamic> json) => DomainStatusResult(
        domain: json['domain'] as String?,
        status: json['status'] as String? ?? 'pending',
        detail: json['detail'] as String?,
        expired: json['expired'] as bool? ?? false,
        domainConnectedAt: json['domainConnectedAt'] != null
            ? DateTime.tryParse(json['domainConnectedAt'] as String)
            : null,
        domainExpiresAt: json['domainExpiresAt'] != null
            ? DateTime.tryParse(json['domainExpiresAt'] as String)
            : null,
      );
}

class DomainRenewResult {
  final String domain;
  final DateTime domainConnectedAt;
  final DateTime? domainExpiresAt;

  DomainRenewResult({
    required this.domain,
    required this.domainConnectedAt,
    required this.domainExpiresAt,
  });

  factory DomainRenewResult.fromJson(Map<String, dynamic> json) => DomainRenewResult(
        domain: json['domain'] as String,
        domainConnectedAt: DateTime.tryParse(json['domainConnectedAt'] as String? ?? '') ?? DateTime.now(),
        domainExpiresAt: json['domainExpiresAt'] != null
            ? DateTime.tryParse(json['domainExpiresAt'] as String)
            : null,
      );
}

class DomainService {
  static Future<DomainConnectResult> connect({
    required String siteId,
    required String domain,
    String? ownerToken,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/domains/connect'),
        headers: {
          'Content-Type': 'application/json',
          if (ownerToken != null) 'x-owner-token': ownerToken,
          ...await authHeaderIfSignedIn(),
        },
        body: jsonEncode({'siteId': siteId, 'domain': domain}),
      );
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 501) throw DomainNotConfiguredException();
    if (res.statusCode == 401) {
      throw DomainException('Devam etmek için giriş yapmış olmalısın.');
    }
    if (res.statusCode == 402) {
      throw DomainException('Doğrulanmış bir domain satın alımı bulunamadı. Ödeme tamamlandıysa birkaç saniye sonra tekrar dene.');
    }
    if (res.statusCode == 403) {
      throw DomainException('Bu site sana ait değil gibi görünüyor.');
    }
    if (res.statusCode == 409) {
      throw DomainException('Bu domain başka bir sitede zaten kullanılıyor.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = _tryDecode(res.body);
      throw DomainException((body?['message'] as String?) ?? 'Domain bağlanamadı (${res.statusCode}).');
    }
    return DomainConnectResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<DomainStatusResult> status({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.get(Uri.parse('${HostingConfig.baseUrl}/api/domains/$siteId/status'));
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 501) throw DomainNotConfiguredException();
    if (res.statusCode == 404) throw DomainException('Site bulunamadı.');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DomainException('Durum alınamadı (${res.statusCode}).');
    }
    return DomainStatusResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<DomainCheckResult> check({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.get(Uri.parse('${HostingConfig.baseUrl}/api/domains/$siteId/check'));
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 501) throw DomainNotConfiguredException();
    if (res.statusCode == 404) throw DomainException('Site bulunamadı.');
    if (res.statusCode == 429) {
      final body = _tryDecode(res.body);
      throw DomainException((body?['message'] as String?) ?? 'Çok sık kontrol ettin, birkaç dakika sonra tekrar dene.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DomainException('Kontrol yapılamadı (${res.statusCode}).');
    }
    return DomainCheckResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<DomainRenewResult> renew({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/domains/$siteId/renew'),
        headers: {
          if (ownerToken != null) 'x-owner-token': ownerToken,
          ...await authHeaderIfSignedIn(),
        },
      );
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) throw DomainException('Site bulunamadı.');
    if (res.statusCode == 401) throw DomainException('Devam etmek için giriş yapmış olmalısın.');
    if (res.statusCode == 402) {
      throw DomainException('Doğrulanmış bir domain satın alımı bulunamadı. Ödeme tamamlandıysa birkaç saniye sonra tekrar dene.');
    }
    if (res.statusCode == 403) throw DomainException('Bu site sana ait değil gibi görünüyor.');
    if (res.statusCode == 400) {
      final body = _tryDecode(res.body);
      throw DomainException((body?['message'] as String?) ?? 'Bu projeye bağlı bir domain yok.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DomainException('Bağlantı uzatılamadı (${res.statusCode}).');
    }
    return DomainRenewResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> disconnect({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.delete(
        Uri.parse('${HostingConfig.baseUrl}/api/domains/$siteId'),
        headers: {
          if (ownerToken != null) 'x-owner-token': ownerToken,
          ...await authHeaderIfSignedIn(),
        },
      );
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    if (res.statusCode == 401) {
      throw DomainException('Devam etmek için giriş yapmış olmalısın.');
    }
    if (res.statusCode == 403) throw DomainException('Bu site sana ait değil gibi görünüyor.');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DomainException('Domain kaldırılamadı (${res.statusCode}).');
    }
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
