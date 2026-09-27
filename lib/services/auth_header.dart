import 'auth_service.dart';

/// 19.09.2026 eklendi (güvenlik sıkılaştırması) — worker'ın "sıkı mod"unda
/// (wrangler.toml > STRICT_CLIENT_CHECKS) yayın, mini paket / rozet / domain
/// aktivasyonu ve site devri uçları `Authorization: Bearer <Firebase ID Token>`
/// ister. Bu yardımcı, giriş yapılmışsa o başlığı üretir; giriş yoksa (ya da
/// token alınamazsa) BOŞ döner — sıkı modda worker zaten 401 döner, kapalı
/// modda eski davranış sürer. Token her çağrıda tazelenir (Firebase süresi
/// dolmuş token'ı kendisi yeniler).
Future<Map<String, String>> authHeaderIfSignedIn() async {
  try {
    final token = await AuthService.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  } catch (_) {
    return const {};
  }
}
