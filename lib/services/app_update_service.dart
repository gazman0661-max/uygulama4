import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'hosting_service.dart';

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
      return UpdateCheckResult.none;
    }
  }

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
    }
    try {
      await launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
    }
  }
}
