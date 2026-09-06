import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hosting_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// "KENDİ DOMAİNİMİ BAĞLA" — Flutter tarafı.
///
/// Akış:
///   1) Kullanıcı yayınlanmış bir projede kendi domainini (örn. ahmetkuafor.com)
///      yazar -> [DomainService.connect] çağrılır.
///   2) Worker, Cloudflare'da bir custom hostname açar ve kullanıcının DNS
///      panelinde eklemesi gereken CNAME kaydını/kayıtlarını döner
///      (bkz. [DomainConnectResult]).
///   3) Uygulama bu kaydı kopyala-yapıştır olarak gösterir, sonra arka planda
///      birkaç saniyede bir [DomainService.status] ile polling yapar.
///   4) Cloudflare doğrulamayı tamamlayıp SSL sertifikasını otomatik
///      çıkarınca durum 'active' olur, ekran otomatik "✅ Bağlandı" gösterir.
///      Kullanıcının hiçbir "tamamladım" butonuna basmasına gerek yoktur.
///
/// Worker tarafı (cloudflare/worker/src/index.mjs > handleDomainConnect/
/// handleDomainStatus/handleDomainDisconnect) CF_API_TOKEN/CF_ZONE_ID
/// yapılandırılana kadar 501 döner — bu servis o durumda
/// [DomainNotConfiguredException] fırlatır, "Yayınla" akışını bozmaz.
/// ============================================================================

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

/// Kullanıcının DNS panelinde eklemesi gereken tek bir kayıt (CNAME/TXT).
class DnsRecordHint {
  final String type;
  final String name;
  final String value;
  DnsRecordHint({required this.type, required this.name, required this.value});

  factory DnsRecordHint.fromJson(Map<String, dynamic> json) => DnsRecordHint(
        type: (json['type'] as String?) ?? 'CNAME',
        name: json['name'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

/// POST /api/domains/connect yanıtı.
class DomainConnectResult {
  final String domain;
  final String status; // 'pending' | 'active' | 'error'
  final bool apexWarning;
  final String? suggestedDomain;
  /// Trafiğin yönlendirileceği ana CNAME kaydı — kullanıcı bunu kendi DNS
  /// panelinde `domain` adı altında, hedefi de bu kaydın value'su olacak
  /// şekilde eklemeli (örn. ahmetkuafor.com -> verify.sitora-hosting.com).
  final DnsRecordHint cnameRecord;
  /// SSL sertifikası doğrulaması için (varsa) ek kayıtlar. Çoğu durumda
  /// yukarıdaki CNAME kaydı tek başına yeterlidir, ama Cloudflare bazen
  /// ek bir doğrulama kaydı isteyebilir.
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

/// GET /api/domains/:siteId/status yanıtı.
class DomainStatusResult {
  final String? domain;
  final String status; // 'pending' | 'active' | 'error' | 'not_connected'
  final String? detail;
  /// Worker'ın domain_connected_at + 365 gün'e göre hesapladığı süre bilgisi
  /// (bkz. worker: handleDomainStatus > domainExpiryInfo). Cloudflare'ın
  /// DNS/SSL durumundan bağımsızdır — 'active' bir domain aynı zamanda
  /// [expired] true olabilir (süresi dolmuş ama Cloudflare hostname'i hâlâ
  /// doğrulanmış durumda). Sunucudan doğrulama amaçlıdır; asıl kesme
  /// worker'ın serveCustomDomainSite'ında gerçekleşir.
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

/// POST /api/domains/:siteId/renew yanıtı.
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
  /// Kullanıcının girdiği [domain]'i [siteId]'ye (zaten yayınlanmış bir
  /// projenin id'si) bağlar. Site daha önce yayınlanmamışsa (yani worker'da
  /// bir kaydı yoksa) worker 404 döner, bu da [DomainException] olarak fırlatılır.
  static Future<DomainConnectResult> connect({
    required String siteId,
    required String domain,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/domains/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'siteId': siteId, 'domain': domain}),
      );
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    // 06.09.2026 eklendi — bkz. server_time_service.dart dokümanı: worker'ın
    // her yanıtındaki `Date` header'ından cihaz saati sapmasını günceller
    // (hata durumlarında da faydalı, o yüzden statusCode kontrolünden ÖNCE).
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 501) throw DomainNotConfiguredException();
    if (res.statusCode == 409) {
      throw DomainException('Bu domain başka bir sitede zaten kullanılıyor.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = _tryDecode(res.body);
      throw DomainException((body?['message'] as String?) ?? 'Domain bağlanamadı (${res.statusCode}).');
    }
    return DomainConnectResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Bağlı domain'in DNS/SSL doğrulama durumunu tazeler. Ekran bunu her
  /// birkaç saniyede bir çağırıp (polling) durum 'active' olunca durur.
  static Future<DomainStatusResult> status({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.get(Uri.parse('${HostingConfig.baseUrl}/api/domains/$siteId/status'));
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res); // bkz. connect()'teki açıklama
    if (res.statusCode == 501) throw DomainNotConfiguredException();
    if (res.statusCode == 404) throw DomainException('Site bulunamadı.');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DomainException('Durum alınamadı (${res.statusCode}).');
    }
    return DomainStatusResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Kullanıcı "Bağlantıyı 1 Yıl Uzat" butonuna bastığında çağrılır. Worker
  /// tarafında domain_connected_at'i bugüne sıfırlar (bkz. handleDomainRenew)
  /// — bu ARTIK sadece istemci tarafında bir sayaç değil, worker'ın
  /// serveCustomDomainSite'ta gerçekten uyguladığı kesmeyi de kaldırır.
  /// Bağlı bir domain yoksa (custom_domain NULL) worker 400 döner, bu da
  /// [DomainException] olarak fırlatılır.
  static Future<DomainRenewResult> renew({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(Uri.parse('${HostingConfig.baseUrl}/api/domains/$siteId/renew'));
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res); // bkz. connect()'teki açıklama
    if (res.statusCode == 404) throw DomainException('Site bulunamadı.');
    if (res.statusCode == 400) {
      final body = _tryDecode(res.body);
      throw DomainException((body?['message'] as String?) ?? 'Bu projeye bağlı bir domain yok.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DomainException('Bağlantı uzatılamadı (${res.statusCode}).');
    }
    return DomainRenewResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Bağlı domain'i tamamen kaldırır (Cloudflare + D1). Site, alt alan
  /// adından (subdomain) erişilebilir olmaya devam eder.
  static Future<void> disconnect({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.delete(Uri.parse('${HostingConfig.baseUrl}/api/domains/$siteId'));
    } catch (e) {
      throw DomainException('İnternet bağlantısı sorunu: $e');
    }
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
