import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'hosting_service.dart';

class AccountDeleteResult {
  final bool ok;
  final int deletedSites;
  final bool authDeleted;
  final List<String> warnings;
  final String? errorMessage;

  const AccountDeleteResult({
    required this.ok,
    this.deletedSites = 0,
    this.authDeleted = false,
    this.warnings = const [],
    this.errorMessage,
  });
}

class AccountDeleteService {
  AccountDeleteService._();

  static Future<AccountDeleteResult> deleteMyAccount() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const AccountDeleteResult(ok: false, errorMessage: 'Giriş yapılmamış.');
    }
    if (!HostingConfig.isConfigured) {
      return const AccountDeleteResult(ok: false, errorMessage: 'Sunucu adresi yapılandırılmamış.');
    }

    String idToken;
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        return const AccountDeleteResult(ok: false, errorMessage: 'Kimlik doğrulama token\'ı alınamadı.');
      }
      idToken = token;
    } catch (e) {
      return AccountDeleteResult(ok: false, errorMessage: 'Kimlik doğrulama hatası: $e');
    }

    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/account/delete'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } catch (e) {
      return AccountDeleteResult(ok: false, errorMessage: 'İnternet bağlantısı sorunu: $e');
    }

    if (res.statusCode != 200) {
      return AccountDeleteResult(
        ok: false,
        errorMessage: 'Sunucu hatası (${res.statusCode}). Lütfen tekrar dene.',
      );
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final warnings = (data['warnings'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      final authDeleted = data['authDeleted'] == true;
      await AuthService.instance.signOut();
      return AccountDeleteResult(
        ok: true,
        deletedSites: (data['deletedSites'] as num?)?.toInt() ?? 0,
        authDeleted: authDeleted,
        warnings: warnings,
      );
    } catch (e) {
      return AccountDeleteResult(ok: false, errorMessage: 'Beklenmeyen sunucu yanıtı: $e');
    }
  }
}
