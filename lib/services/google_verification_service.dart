import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hosting_service.dart';

/// ============================================================================
/// GOOGLE SEARCH CONSOLE DOĞRULAMA — 20.09.2026 eklendi (kanka isteği).
///
/// Kullanıcı Google Search Console'da "HTML etiketi" doğrulama yöntemini
/// seçtiğinde aldığı `content` değerini burada worker'a kaydeder (bkz.
/// cloudflare/worker/src/index.mjs > handleSetGoogleVerification). Worker bu
/// kodu R2'ye HİÇ yazmaz — robots.txt/sitemap.xml ile AYNI mantıkla,
/// yayınlanan sitenin HER .html sayfasının <head>'ine HER istekte anlık
/// enjekte eder. Yani kullanıcı kodu girdikten sonra siteyi yeniden
/// yayınlamasına GEREK YOKTUR.
///
/// Abonelik/domain paketi/mini paketten biri aktif değilse (premium
/// olmayan bir sitede) worker 402 döner — bu [GoogleVerificationException]
/// olarak fırlatılır, UI tarafı bunu "önce bir pakete abone ol" mesajıyla
/// gösterebilir.
/// ============================================================================

class GoogleVerificationException implements Exception {
  final String message;
  GoogleVerificationException(this.message);
  @override
  String toString() => message;
}

class GoogleVerificationService {
  /// [code] boş/null gönderilirse doğrulama KALDIRILIR (kullanıcı Search
  /// Console bağlantısını kesmek isteyebilir) — bu işlem premium şartı
  /// ARAMAZ, kaldırmak her zaman serbesttir.
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
