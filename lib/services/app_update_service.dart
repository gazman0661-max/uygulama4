import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'hosting_service.dart';

/// ============================================================================
/// ZORUNLU/OPSİYONEL GÜNCELLEME POPUP'I — 18.09.2026 eklendi (kanka isteği)
/// ============================================================================
/// SORUN: Play Store'da otomatik güncelleme kapalı kullanıcılar, worker
/// tarafında GERİYE DÖNÜK UYUMSUZ bir değişiklik (ör. 18.09.2026 güvenlik
/// yaması — artık bazı uçlar owner_token/Authorization header'ı istiyor)
/// yapıldığında eski sürümde takılı kalıp bazı özelliklerin (domain
/// yenileme, mini paket, push bildirimleri...) sessizce bozulduğunu
/// GÖRMEDEN yaşayabilirdi.
///
/// ÇÖZÜM: Uygulama her açılışta worker'daki GET /api/app-version ucunu
/// sorar (bkz. cloudflare/worker/src/index.mjs > handleAppVersionInfo).
/// Bu uç admin panelinden (worker YENİDEN DEPLOY edilmeden) güncellenebilen
/// tek satırlık bir yapılandırma döner:
///   - minBuildNumber: cihazın build number'ı (PackageInfo.buildNumber)
///     bunun ALTINDAYSA [UpdateCheckResult.mandatory] true döner —
///     SplashScreen bu durumda MainShell'e HİÇ geçmez, sadece "Güncelle"
///     butonu olan tam ekran bir uyarı gösterir.
///   - latestBuildNumber: bunun ALTINDA ama minBuildNumber'ın ÜSTÜNDEYSE
///     [UpdateCheckResult.optional] true döner — kapatılabilir bir
///     bildirim gösterilir, uygulama normal kullanılabilir.
///
/// BİLEREK "fail open": worker'a ulaşılamazsa (internet yok, worker
/// geçici kapalı) [UpdateCheckResult.none] döner — bir güncelleme
/// kontrolü ASLA uygulamanın açılmasını engelleyecek bir hataya
/// dönüşmemeli (mandatory SADECE worker açıkça öyle dediğinde olur).
/// ============================================================================
enum UpdateSeverity { none, optional, mandatory }

class UpdateCheckResult {
  final UpdateSeverity severity;
  final String message;
  final String playStoreUrl;
  const UpdateCheckResult({
    required this.severity,
    required this.message,
    required this.playStoreUrl,
  });

  static const UpdateCheckResult none = UpdateCheckResult(
    severity: UpdateSeverity.none,
    message: '',
    playStoreUrl: '',
  );
}

class AppUpdateService {
  AppUpdateService._();

  /// [isEnglish] sadece hangi mesaj metninin gösterileceğini belirler —
  /// karar (mandatory/optional/none) DAİMA sürüm numarasına göre verilir.
  static Future<UpdateCheckResult> check({required bool isEnglish}) async {
    if (!HostingConfig.isConfigured) return UpdateCheckResult.none;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final res = await http
          .get(Uri.parse('${HostingConfig.baseUrl}/api/app-version'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return UpdateCheckResult.none;
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final minBuild = (data['minBuildNumber'] as num?)?.toInt() ?? 0;
      final latestBuild = (data['latestBuildNumber'] as num?)?.toInt() ?? 0;
      final playStoreUrl = (data['playStoreUrl'] as String?) ??
          'https://play.google.com/store/apps/details?id=com.sitora.ai';
      final messageTr = (data['updateMessageTr'] as String?) ??
          'Uygulamanın yeni bir sürümü var. Devam etmek için lütfen güncelle.';
      final messageEn = (data['updateMessageEn'] as String?) ??
          'A new version of the app is available. Please update to continue.';
      final message = isEnglish ? messageEn : messageTr;

      if (minBuild > 0 && currentBuild < minBuild) {
        return UpdateCheckResult(
          severity: UpdateSeverity.mandatory,
          message: message,
          playStoreUrl: playStoreUrl,
        );
      }
      if (latestBuild > 0 && currentBuild < latestBuild) {
        return UpdateCheckResult(
          severity: UpdateSeverity.optional,
          message: message,
          playStoreUrl: playStoreUrl,
        );
      }
      return UpdateCheckResult.none;
    } catch (_) {
      // Ağ hatası/format hatası: GÜVENLİ TARAF — hiçbir şeyi engelleme.
      return UpdateCheckResult.none;
    }
  }

  /// [home_screen.dart > _openPlayStore] ile AYNI desen: önce Play Store
  /// UYGULAMASINI market:// şemasıyla doğrudan açmayı dener (tarayıcıya hiç
  /// uğramadan), başarısız olursa (Play Store kurulu değil, emülatör vb.)
  /// normal https linkine düşer.
  static Future<void> openStore(String playStoreUrl) async {
    try {
      final uri = Uri.parse(playStoreUrl);
      final packageId = uri.queryParameters['id'];
      if (packageId != null) {
        final marketUri = Uri.parse('market://details?id=$packageId');
        final launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (_) {
      // market:// desteklenmiyor — aşağıdaki web linkine düşülür.
    }
    try {
      await launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Hiçbir şekilde açılamadı (ör. internet yok) — kullanıcı zorunlu
      // güncelleme ekranındaki butona tekrar basabilir, sessizce geçilir.
    }
  }
}
