import 'package:http/http.dart' as http;
import 'auth_header.dart';
import 'auth_service.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

class SubscriptionQuotaSyncException implements Exception {
  final String message;
  SubscriptionQuotaSyncException(this.message);
  @override
  String toString() => message;
}

class SubscriptionQuotaSyncService {
  static Future<String> _idTokenFor(String uid) async {
    final user = AuthService.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw SubscriptionQuotaSyncException('Bu işlem için giriş yapmış olman gerekiyor.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw SubscriptionQuotaSyncException('Kimlik doğrulama bilgisi alınamadı.');
    }
    return token;
  }

  static Future<void> assign({required String siteId, required String uid, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    final idToken = await _idTokenFor(uid);
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-quota'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          if (ownerToken != null) 'x-owner-token': ownerToken,
        },
        body: '{}',
      );
    } catch (e) {
      throw SubscriptionQuotaSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      throw SubscriptionQuotaSyncException('Site henüz yayınlanmamış.');
    }
    if (res.statusCode == 401) {
      throw SubscriptionQuotaSyncException('Kimlik doğrulanamadı, tekrar giriş yapmayı dene.');
    }
    if (res.statusCode == 403) {
      throw SubscriptionQuotaSyncException('Bu site sana ait değil gibi görünüyor.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionQuotaSyncException('Abonelik kotası sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }

  static Future<void> unassign({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.delete(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-quota'),
        headers: {
          if (ownerToken != null) 'x-owner-token': ownerToken,
          ...await authHeaderIfSignedIn(),
        },
      );
    } catch (e) {
      throw SubscriptionQuotaSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      return;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionQuotaSyncException('Abonelik kotası kaldırma sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }

  static Future<void> assignDomain({required String siteId, required String uid, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    final idToken = await _idTokenFor(uid);
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-domain'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          if (ownerToken != null) 'x-owner-token': ownerToken,
        },
        body: '{}',
      );
    } catch (e) {
      throw SubscriptionQuotaSyncException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode == 404) {
      throw SubscriptionQuotaSyncException('Site henüz yayınlanmamış.');
    }
    if (res.statusCode == 401) {
      throw SubscriptionQuotaSyncException('Kimlik doğrulanamadı, tekrar giriş yapmayı dene.');
    }
    if (res.statusCode == 403) {
      throw SubscriptionQuotaSyncException('Bu site sana ait değil gibi görünüyor.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionQuotaSyncException('Abonelik domain kotası sunucuya kaydedilemedi (${res.statusCode}).');
    }
  }

  static Future<void> unassignDomain({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.delete(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/subscription-domain'),
        headers: {
          if (ownerToken != null) 'x-owner-token': ownerToken,
          ...await authHeaderIfSignedIn(),
        },
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
