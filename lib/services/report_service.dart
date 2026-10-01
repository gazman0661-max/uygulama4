import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hosting_service.dart';

enum ReportReason { offensive, illegal, hate, bug, other }

extension ReportReasonX on ReportReason {
  String get apiValue => switch (this) {
        ReportReason.offensive => 'offensive',
        ReportReason.illegal => 'illegal',
        ReportReason.hate => 'hate',
        ReportReason.bug => 'bug',
        ReportReason.other => 'other',
      };

  String get label => switch (this) {
        ReportReason.offensive => 'Rahatsız edici / uygunsuz içerik',
        ReportReason.illegal => 'Yasa dışı içerik',
        ReportReason.hate => 'Nefret söylemi / taciz',
        ReportReason.bug => 'Hatalı / bozuk site',
        ReportReason.other => 'Diğer',
      };
}

enum ReportSource { general, preview, hostedSite }

class ReportException implements Exception {
  final String message;
  ReportException(this.message);
  @override
  String toString() => message;
}

class ReportService {
  static const _endpoint =
      'https://script.google.com/macros/s/AKfycbwYCfWn4ZZztD2htFqwIwZiDeaichlb-G5xVTMXAAMbqOGkZA_mn7Tr_dCq8Hljz1x4yA/exec';

  static Future<void> submit({
    required ReportReason reason,
    required String details,
    required ReportSource source,
    String? siteId,
    String? publishedUrl,
  }) async {
    final payload = {
      'reason': reason.apiValue,
      'details': details,
      'context': switch (source) {
        ReportSource.preview => 'preview',
        ReportSource.general => 'general',
        ReportSource.hostedSite => 'hosted_site',
      },
      if (siteId != null) 'siteId': siteId,
      if (publishedUrl != null) 'publishedUrl': publishedUrl,
      'lang': 'tr',
      'appVersion': 'SitoraAI-Flutter',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    http.Response res;
    try {
      res = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      throw ReportException('İnternet bağlantısı sorunu: $e');
    }

    bool ok = res.statusCode >= 200 && res.statusCode < 300;
    try {
      final json = jsonDecode(res.body);
      if (json is Map && json['status'] is String) {
        ok = json['status'] == 'success';
      }
    } catch (_) {
    }

    if (!ok) {
      throw ReportException(
          'Bildirim gönderilemedi. İnternetini kontrol edip tekrar dener misin?');
    }

    if (siteId != null && HostingConfig.isConfigured) {
      try {
        await http.post(
          Uri.parse('${HostingConfig.baseUrl}/api/report'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'siteId': siteId,
            'reason': reason.apiValue,
            'details': details,
            if (publishedUrl != null) 'publishedUrl': publishedUrl,
          }),
        );
      } catch (_) {
      }
    }
  }
}
