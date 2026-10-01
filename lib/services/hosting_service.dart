import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'analytics_service.dart';
import 'auth_header.dart';
import 'favicon_publish.dart';
import 'image_compress_service.dart';
import 'publish_image_service.dart';
import 'server_time_service.dart';

class HostingConfig {
  static const String baseUrl = 'https://sitora-hosting.sitora2026.workers.dev';

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}

class HostingNotConfiguredException implements Exception {
  final String message =
      'Hosting henüz aktif değil. Worker/D1 tarafı yayına alınınca bu özellik otomatik açılacak.';
  @override
  String toString() => message;
}

class HostingException implements Exception {
  final String message;
  HostingException(this.message);
  @override
  String toString() => message;
}

abstract class PublishLimitException implements Exception {
  const PublishLimitException();
}

class TooManyFilesException extends PublishLimitException {
  final int fileCount;
  final int maxFiles;
  const TooManyFilesException({required this.fileCount, required this.maxFiles});
  @override
  String toString() =>
      'TooManyFilesException(fileCount: $fileCount, maxFiles: $maxFiles)';
}

class FileTooLargeException extends PublishLimitException {
  final String path;
  final double sizeMb;
  final double limitMb;
  const FileTooLargeException({
    required this.path,
    required this.sizeMb,
    required this.limitMb,
  });
  @override
  String toString() =>
      'FileTooLargeException(path: $path, sizeMb: $sizeMb, limitMb: $limitMb)';
}

class SiteTooLargeException extends PublishLimitException {
  final double totalMb;
  final double limitMb;
  const SiteTooLargeException({required this.totalMb, required this.limitMb});
  @override
  String toString() =>
      'SiteTooLargeException(totalMb: $totalMb, limitMb: $limitMb)';
}

class PublishResult {
  final String siteId;
  final String subdomain;
  final String url;
  final String? ownerToken;
  PublishResult({
    required this.siteId,
    required this.subdomain,
    required this.url,
    this.ownerToken,
  });

  factory PublishResult.fromJson(Map<String, dynamic> json) => PublishResult(
        siteId: json['siteId'] as String,
        subdomain: json['subdomain'] as String,
        url: json['url'] as String,
        ownerToken: json['ownerToken'] as String?,
      );
}

class SiteStats {
  final String siteId;
  final int visitCount;
  final int todayVisitCount;
  final int monthlyVisitCount;
  final DateTime? lastVisitAt;
  final DateTime? createdAt;
  SiteStats({
    required this.siteId,
    required this.visitCount,
    this.todayVisitCount = 0,
    this.monthlyVisitCount = 0,
    this.lastVisitAt,
    this.createdAt,
  });

  factory SiteStats.fromJson(Map<String, dynamic> json) => SiteStats(
        siteId: json['siteId'] as String,
        visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
        todayVisitCount: (json['todayVisitCount'] as num?)?.toInt() ?? 0,
        monthlyVisitCount: (json['monthlyVisitCount'] as num?)?.toInt() ?? 0,
        lastVisitAt: json['lastVisitAt'] != null
            ? DateTime.tryParse(json['lastVisitAt'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

class HostingService {
  static Future<PublishResult> publish({
    required Map<String, String> files,
    required String desiredSubdomain,
    required String siteId,
    String? ownerEmail,
    String? ownerUid,
    String siteName = '',
    String? ownerToken,
    String? lang,
    String leadDelivery = 'box',
    String? leadEmail,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();

    var processedFiles = Map<String, String>.from(files);

    for (final key in processedFiles.keys.toList()) {
      if (!key.toLowerCase().endsWith('.html')) continue;
      processedFiles[key] =
          await ImageCompressService.optimizeEmbeddedImages(processedFiles[key]!);
    }

    processedFiles = await PublishImageService.externalize(
      files: processedFiles,
      endpoint: Uri.parse('${HostingConfig.baseUrl}/api/publish-image'),
      siteId: siteId,
      ownerToken: ownerToken,
      authHeaders: await authHeaderIfSignedIn(),
    );

    processedFiles = externalizeFavicon(processedFiles);

    final indexKey = processedFiles.containsKey('index.html')
        ? 'index.html'
        : processedFiles.keys.firstWhere(
            (k) => k.toLowerCase().endsWith('.html'),
            orElse: () => '',
          );
    if (indexKey.isNotEmpty) {
      processedFiles[indexKey] = _injectReportWidget(
        html: processedFiles[indexKey]!,
        siteId: siteId,
      );
    }

    for (final key in processedFiles.keys.toList()) {
      if (!key.toLowerCase().endsWith('.html')) continue;
      processedFiles[key] = _injectVisitorTracker(
        html: processedFiles[key]!,
        siteId: siteId,
      );
      if (ownerUid != null && ownerUid.trim().isNotEmpty) {
        processedFiles[key] = _injectLeadConfig(
          html: processedFiles[key]!,
          ownerUid: ownerUid.trim(),
          siteId: siteId,
          siteName: siteName,
          leadDelivery: leadDelivery,
          leadEmail: leadEmail,
        );
      }
    }

    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/publish'),
        headers: {'Content-Type': 'application/json', ...await authHeaderIfSignedIn()},
        body: jsonEncode({
          'siteId': siteId,
          'desiredSubdomain': desiredSubdomain,
          'files': processedFiles,
          if (ownerEmail != null && ownerEmail.trim().isNotEmpty)
            'ownerEmail': ownerEmail.trim(),
          if (ownerToken != null && ownerToken.trim().isNotEmpty)
            'ownerToken': ownerToken.trim(),
          if (lang == 'en' || lang == 'tr') 'lang': lang,
          if (ownerUid != null && ownerUid.trim().isNotEmpty) 'ownerUid': ownerUid.trim(),
        }),
      );
    } catch (e) {
      AnalyticsService.logPublishFailed(reason: 'network');
      throw HostingException('İnternet bağlantısı sorunu: $e');
    }
    ServerTimeService.updateFromResponse(res);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AnalyticsService.logPublishFailed(reason: 'http_${res.statusCode}');
    }
    if (res.statusCode == 401) {
      throw HostingException('Yayınlamak için giriş yapmış olmalısın.');
    }
    if (res.statusCode == 403) {
      throw HostingException(
          'Bu site başka bir cihaz/hesaba ait görünüyor, üzerine yazılamadı.');
    }
    if (res.statusCode == 429) {
      throw HostingException('Çok fazla yayınlama isteği yapıldı, biraz sonra tekrar dene.');
    }
    if (res.statusCode == 413) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = null;
      }
      final errorCode = body?['error'] as String?;
      AnalyticsService.logPublishFailed(reason: errorCode ?? 'site_too_large');

      if (errorCode == 'too_many_files') {
        throw TooManyFilesException(
          fileCount: (body?['fileCount'] as num?)?.toInt() ?? files.length,
          maxFiles: (body?['maxFiles'] as num?)?.toInt() ?? 300,
        );
      }
      if (errorCode == 'file_too_large') {
        final limitBytes = (body?['limitBytes'] as num?)?.toInt() ?? (8 * 1024 * 1024);
        final sizeBytes = (body?['sizeBytes'] as num?)?.toInt() ?? limitBytes;
        throw FileTooLargeException(
          path: (body?['path'] as String?) ?? '',
          sizeMb: sizeBytes / (1024 * 1024),
          limitMb: limitBytes / (1024 * 1024),
        );
      }
      final limitBytes = (body?['limitBytes'] as num?)?.toInt() ?? (40 * 1024 * 1024);
      final totalBytes = (body?['totalBytes'] as num?)?.toInt() ??
          files.values.fold<int>(0, (sum, v) => sum + v.length);
      throw SiteTooLargeException(
        totalMb: totalBytes / (1024 * 1024),
        limitMb: limitBytes / (1024 * 1024),
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('Yayınlama başarısız oldu (${res.statusCode}).');
    }
    final result =
        PublishResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    unawaited(AnalyticsService.logSitePublished(
      subdomain: result.subdomain,
      isFirstPublish: ownerToken == null || ownerToken.trim().isEmpty,
    ));
    return result;
  }

  static Future<SiteStats> fetchStats({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.get(Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/stats'));
    } catch (e) {
      throw HostingException('İnternet bağlantısı sorunu: $e');
    }
    if (res.statusCode == 404) {
      throw HostingException('Bu site için istatistik bulunamadı (henüz yayınlanmamış olabilir).');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('İstatistikler alınamadı (${res.statusCode}).');
    }
    return SiteStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Map<String, SiteStats>> fetchStatsBatch({required List<String> siteIds}) async {
    if (siteIds.isEmpty) return {};
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      final idsParam = Uri.encodeComponent(siteIds.join(','));
      res = await http.get(Uri.parse('${HostingConfig.baseUrl}/api/sites/stats?ids=$idsParam'));
    } catch (e) {
      throw HostingException('İnternet bağlantısı sorunu: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('İstatistikler alınamadı (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (decoded['sites'] as List<dynamic>? ?? []);
    final result = <String, SiteStats>{};
    for (final item in list) {
      final stats = SiteStats.fromJson(item as Map<String, dynamic>);
      result[stats.siteId] = stats;
    }
    return result;
  }

  static Future<void> unpublish({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    final res = await http.delete(
      Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId'),
      headers: {
        if (ownerToken != null && ownerToken.trim().isNotEmpty)
          'x-owner-token': ownerToken.trim(),
        ...await authHeaderIfSignedIn(),
      },
    );
    if (res.statusCode == 403) {
      throw HostingException('Bu siteyi kaldırma yetkiniz yok.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('Yayından kaldırma başarısız oldu (${res.statusCode}).');
    }
  }

  static String _injectReportWidget({required String html, required String siteId}) {
    final isEnglish =
        RegExp(r'<html[^>]*\blang\s*=\s*"en"', caseSensitive: false)
            .hasMatch(html);
    final widget = reportWidgetSnippet(siteId: siteId, isEnglish: isEnglish);
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$widget</body>');
    }
    return '$html\n$widget';
  }

  static String _injectLeadConfig({
    required String html,
    required String ownerUid,
    required String siteId,
    required String siteName,
    String leadDelivery = 'box',
    String? leadEmail,
  }) {
    final snippet = '''
<script>
window.__SITORA_LEAD__ = { ownerUid: ${jsonEncode(ownerUid)}, siteId: ${jsonEncode(siteId)}, siteName: ${jsonEncode(siteName)}, leadDelivery: ${jsonEncode(leadDelivery)}, leadEmail: ${jsonEncode(leadEmail ?? '')} };
</script>
''';
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$snippet</body>');
    }
    return '$html\n$snippet';
  }

  static String injectDownloadOnlyMailtoConfig({
    required String html,
    required String siteName,
    required String contactEmail,
  }) {
    return _injectLeadConfig(
      html: html,
      ownerUid: '',
      siteId: '',
      siteName: siteName,
      leadDelivery: 'email',
      leadEmail: contactEmail,
    );
  }

  static String _injectVisitorTracker({required String html, required String siteId}) {
    final tracker = visitorTrackerSnippet(siteId: siteId);
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$tracker</body>');
    }
    return '$html\n$tracker';
  }

  static String visitorTrackerSnippet({required String siteId}) {
    return '''
<script>
(function(){
  try {
    fetch('/api/hit', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ siteId: ${jsonEncode(siteId)} })
    }).catch(function(){});
  } catch (e) {}
})();
</script>
''';
  }

  static String reportWidgetSnippet(
      {required String siteId, bool isEnglish = false}) {
    const endpoint =
        'https://script.google.com/macros/s/AKfycbwYCfWn4ZZztD2htFqwIwZiDeaichlb-G5xVTMXAAMbqOGkZA_mn7Tr_dCq8Hljz1x4yA/exec';
    final t = isEnglish
        ? const {
            'btn': '🚩 Report this site',
            'title': 'Report this site to Sitora',
            'offensive': 'Offensive / inappropriate content',
            'illegal': 'Illegal content',
            'hate': 'Hate speech / harassment',
            'other': 'Other',
            'placeholder': 'Briefly explain (required)',
            'cancel': 'Cancel',
            'send': 'Send',
            'needDetails': 'Please write a short explanation.',
            'success':
                'Your report was received, thank you. It will be reviewed shortly.',
            'failure':
                "Couldn't send the report — check your connection and try again.",
          }
        : const {
            'btn': '🚩 Siteyi Bildir',
            'title': "Bu siteyi Sitora'ya bildir",
            'offensive': 'Rahatsız edici / uygunsuz içerik',
            'illegal': 'Yasa dışı içerik',
            'hate': 'Nefret söylemi / taciz',
            'other': 'Diğer',
            'placeholder': 'Kısaca açıkla (zorunlu)',
            'cancel': 'İptal',
            'send': 'Gönder',
            'needDetails': 'Lütfen kısa bir açıklama yaz.',
            'success':
                'Bildirimin ulaştı, teşekkürler. En kısa sürede incelenecek.',
            'failure':
                'Bildirim gönderilemedi, internetini kontrol edip tekrar dener misin?',
          };
    return '''
<div id="sitora-report-widget" style="position:fixed;bottom:14px;left:14px;z-index:999999;font-family:sans-serif;">
  <button id="sitora-report-btn" style="background:#B91C1C;color:#fff;border:none;border-radius:999px;padding:8px 14px;font-size:12px;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,.25);opacity:.85;">${t['btn']}</button>
  <div id="sitora-report-modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.6);align-items:center;justify-content:center;">
    <div style="background:#141821;color:#fff;border-radius:14px;padding:18px;max-width:320px;width:90%;">
      <div style="font-weight:bold;margin-bottom:8px;">${t['title']}</div>
      <select id="sitora-report-reason" style="width:100%;padding:8px;margin-bottom:8px;border-radius:8px;">
        <option value="offensive">${t['offensive']}</option>
        <option value="illegal">${t['illegal']}</option>
        <option value="hate">${t['hate']}</option>
        <option value="other">${t['other']}</option>
      </select>
      <textarea id="sitora-report-details" placeholder="${t['placeholder']}" style="width:100%;min-height:60px;padding:8px;border-radius:8px;margin-bottom:8px;"></textarea>
      <div style="display:flex;gap:8px;">
        <button id="sitora-report-cancel" style="flex:1;padding:10px;border-radius:8px;border:1px solid #444;background:transparent;color:#fff;">${t['cancel']}</button>
        <button id="sitora-report-send" style="flex:1;padding:10px;border-radius:8px;border:none;background:#B91C1C;color:#fff;">${t['send']}</button>
      </div>
    </div>
  </div>
</div>
<script>
(function(){
  var siteId = ${jsonEncode(siteId)};
  var endpoint = ${jsonEncode(endpoint)};
  var btn = document.getElementById('sitora-report-btn');
  var modal = document.getElementById('sitora-report-modal');
  var cancel = document.getElementById('sitora-report-cancel');
  var send = document.getElementById('sitora-report-send');
  btn.onclick = function(){ modal.style.display = 'flex'; };
  cancel.onclick = function(){ modal.style.display = 'none'; };
  send.onclick = function(){
    var details = document.getElementById('sitora-report-details').value.trim();
    if (!details) { alert(${jsonEncode(t['needDetails'])}); return; }
    send.disabled = true;
    fetch(endpoint, {
      method: 'POST',
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: JSON.stringify({
        reason: document.getElementById('sitora-report-reason').value,
        details: '[YAYINLANAN SİTE ŞİKAYETİ] siteId=' + siteId + ' url=' + location.href + ' | ' + details,
        context: 'hosted_site',
        siteId: siteId,
        publishedUrl: location.href,
        lang: ${jsonEncode(isEnglish ? 'en' : 'tr')},
        appVersion: 'SitoraAI-HostedSiteWidget',
        timestamp: new Date().toISOString()
      })
    }).then(function(){
      try {
        fetch('/api/report', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({
            siteId: siteId,
            reason: document.getElementById('sitora-report-reason').value,
            details: details,
            publishedUrl: location.href
          })
        }).catch(function(){});
      } catch (e) {}
      alert(${jsonEncode(t['success'])});
      modal.style.display = 'none';
      send.disabled = false;
    }).catch(function(){
      alert(${jsonEncode(t['failure'])});
      send.disabled = false;
    });
  };
})();
</script>
''';
  }
}
