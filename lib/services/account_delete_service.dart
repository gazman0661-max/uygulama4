import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'hosting_service.dart';

/// ============================================================================
/// HESABIMI SİL — 20.09.2026 eklendi (kanka isteği: KVKK/Play Store Data
/// Safety uyumu — kullanıcının kendi verisini silebileceği bir yol yoktu).
/// ============================================================================
/// Gerçek silme işi TAMAMEN worker tarafında (POST /api/account/delete) —
/// bkz. cloudflare/worker/src/index.mjs > handleAccountDelete: yayınlanmış
/// TÜM siteler (R2+D1), fcm_tokens, subscriptions, Firestore'daki proje
/// taslakları + talepler + profil dokümanı VE en son Firebase Auth hesabının
/// kendisi (Identity Toolkit accounts:delete) — hepsi sunucu tarafında,
/// TEK bir çağrıyla silinir. Bu servis sadece o uca kimlik doğrulamalı
/// isteği atar ve sonucu Flutter'a taşır.
///
/// ÖNEMLİ — worker'daki FIREBASE_SERVICE_ACCOUNT_JSON'ın bağlı olduğu servis
/// hesabına Google Cloud IAM'de "Firebase Authentication Admin" rolü
/// verilmiş OLMALI, yoksa 4. adım (Auth hesabını silme) başarısız olur ama
/// diğer adımlar (site/veri silme) yine de tamamlanır — [AccountDeleteResult.
/// authDeleted] bunu ayırt eder, UI buna göre farklı bir mesaj gösterir.
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
      final token = await user.getIdToken(true); // true: taze token — silme gibi hassas bir işlem için önbellekten değil
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
      // Worker Auth hesabını silmeyi başaramadıysa (ör. IAM rolü eksik) bile
      // veri zaten silinmiştir — çıkış yaptırıp misafir moduna düşürüyoruz,
      // kullanıcı tekrar bu hesapla giriş yapabilir ama içi boş bulur.
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
