import 'dart:convert';
import 'package:http/http.dart' as http;
import 'activation_retry.dart';
import 'auth_header.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

class MiniPackageException implements Exception {
  final String message;

  final SyncRetry retry;

  MiniPackageException(this.message, {this.retry = SyncRetry.never});
  @override
  String toString() => message;
}

class MiniPackageService {
  static Future<void> activate({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/mini-package/$siteId/activate'),
        headers: {
          if (ownerToken != null) 'x-owner-token': ownerToken,
          ...await authHeaderIfSignedIn(),
        },
      ).timeout(const Duration(seconds: 25));
    } catch (e) {
      throw MiniPackageException('İnternet bağlantısı sorunu: $e', retry: SyncRetry.soon);
    }
    ServerTimeService.updateFromResponse(res);
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
