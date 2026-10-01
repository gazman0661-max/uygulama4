import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_header.dart';
import 'hosting_service.dart';

class GoogleVerificationException implements Exception {
  final String message;
  GoogleVerificationException(this.message);
  @override
  String toString() => message;
}

class GoogleVerificationService {
  static Future<void> setCode({
    required String siteId,
    required String? code,
    String? ownerToken,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.patch(
        Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/google-verification'),
        headers: {
          'Content-Type': 'application/json',
          if (ownerToken != null) 'x-owner-token': ownerToken,
          ...await authHeaderIfSignedIn(),
        },
        body: jsonEncode({'code': code ?? ''}),
      );
    } catch (e) {
      throw GoogleVerificationException('İnternet bağlantısı sorunu: $e');
    }
    if (res.statusCode == 404) {
      throw GoogleVerificationException('Site bulunamadı — önce siteni yayınlaman gerekiyor.');
    }
    if (res.statusCode == 403) {
      throw GoogleVerificationException('Bu site sana ait değil gibi görünüyor.');
    }
    if (res.statusCode == 402) {
      throw GoogleVerificationException(
          'Bu özellik abonelik veya özel domain paketi gerektirir.');
    }
    if (res.statusCode == 400) {
      final body = _tryDecode(res.body);
      throw GoogleVerificationException(
          (body?['message'] as String?) ?? 'Geçersiz doğrulama kodu.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw GoogleVerificationException('Kaydedilemedi (${res.statusCode}).');
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
