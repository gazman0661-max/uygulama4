import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hosting_service.dart';

/// index.html'deki 🚩 "İçeriği Bildir" sisteminin BİREBİR aynısı: aynı
/// Google Apps Script uç noktasına (REPORT_ENDPOINT_URL) aynı JSON şeması
/// ile POST atar. Apps Script tarafındaki `doPost`, gelen reason+details'i
/// bir e-postaya dönüştürüp gönderiyor — o script'e hiç dokunmadık, bu
/// yüzden mevcut mail akışı olduğu gibi çalışmaya devam ediyor.
enum ReportReason { offensive, illegal, hate, bug, other }

extension ReportReasonX on ReportReason {
  /// Apps Script'in beklediği değer (index.html > <option value="...">).
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

/// Bildirimin hangi ekrandan gönderildiği (index.html > _reportContext).
///
/// [hostedSite]: Cloudflare hosting'e yayınlanmış (R2/Worker üzerinde canlı
/// duran) bir sitenin ZİYARETÇİSİ tarafından gönderilir. Bu kaynak
/// Flutter uygulaması içinden DEĞİL, yayınlanan statik HTML'in kendi içine
/// gömülen küçük bir JS widget'ından (bkz. HostingService.reportWidgetSnippet)
/// tetiklenir — o yüzden ReportService.submit()'i doğrudan çağırmaz, aynı
/// uç noktaya kendi fetch()'ini yapar. Burada sadece etiket/label için var.
enum ReportSource { general, preview, hostedSite }

class ReportException implements Exception {
  final String message;
  ReportException(this.message);
  @override
  String toString() => message;
}

class ReportService {
  // index.html > REPORT_ENDPOINT_URL ile birebir aynı uç nokta.
  static const _endpoint =
      'https://script.google.com/macros/s/AKfycbwYCfWn4ZZztD2htFqwIwZiDeaichlb-G5xVTMXAAMbqOGkZA_mn7Tr_dCq8Hljz1x4yA/exec';

  /// [details] zaten kaynak etiketi ([SOHBET]/[ÖN İZLEME]) ve varsa
  /// sohbet bağlamı / tam site kodu ile zenginleştirilmiş olarak gelir
  /// (bkz. report_dialog.dart) — index.html'deki submitReport()'un
  /// yaptığı `fullDetails` birleştirmesiyle aynı mantık çağıran taraftadır.
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
        // index.html'deki gibi text/plain: Apps Script Web App'lerinde
        // CORS preflight (OPTIONS) isteğini tetiklememek için bilinçli
        // olarak application/json yerine bu kullanılıyor.
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
      // Yanıt JSON değilse status koduna güveniyoruz (index.html ile aynı davranış).
    }

    if (!ok) {
      throw ReportException(
          'Bildirim gönderilemedi. İnternetini kontrol edip tekrar dener misin?');
    }

    // Bu şikayet yayınlanmış bir siteyle ilgiliyse (siteId dolu) VE Worker
    // kuruluysa, D1'e de kalıcı olarak yazalım ki /admin panelinde de
    // görünsün — asıl bildirim (yukarıdaki Apps Script/mail) zaten gitti,
    // bu tamamen ek/best-effort bir adım: başarısız olsa kullanıcıya
    // hata gösterilmez, ReportService.submit() yine başarıyla döner.
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
        // sessizce yut — bu ek adım kritik değil
      }
    }
  }
}
