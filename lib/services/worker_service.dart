import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_response_utils.dart';

/// Tirakula'nın kendi Cloudflare Worker'ı (server tarafında kendi
/// GEMINI_API_KEY'ini kullanan proxy). SADECE kendi Gemini API anahtarını
/// GİRMEYEN (ücretsiz/günlük puanlı) kullanıcı akışında kullanılır — bkz.
/// AppState.usesFreeQuota / effectiveApiKey.
///
/// worker.js artık uygulamanın KENDİ promptlarını (gemini_service.dart'taki
/// buildFullSitePrompt/buildMultiSitePrompt/buildFullEditPrompt/
/// buildSectionEditPrompt/buildBgEditPrompt ile BİREBİR AYNI metinler)
/// sunucu tarafında kuruyor. Buradan worker'a sadece HANGİ prompt'un
/// hangi verilerle (previous_code, current_code, section_html,
/// current_background_css) kurulacağı gönderiliyor; yanıt yorumlama
/// (sentinel/reddetme kontrolü, diff uygulama, CSS güvenlik ağı vb.)
/// AYNI ai_response_utils.dart mantığıyla İSTEMCİ tarafında (burada)
/// yapılıyor — own-key akışıyla (GeminiService) TAM SİMETRİK.
///
/// İSTEK: POST {
///   prompt: string,               // kullanıcının isteği/talebi (her type'da)
///   type: "full_site" | "multi_site" | "full_edit" | "section_edit" | "bg_edit",
///   previous_code?: string,       // full_site
///   previous_files?: {ad: içerik},// multi_site
///   current_code?: string,        // full_edit
///   section_html?: string,        // section_edit
///   current_background_css?: string, // bg_edit
///   image_count?: int,            // full_site/multi_site — GÖRSEL BINARY'Sİ
///     DEĞİL, sadece kaç görsel yüklendiği. Büyük base64 payload'ların
///     Gemini'nin istek boyutu/limitine takılıp hata vermesini önlemek için
///     worker'a görsel içeriği hiç gönderilmiyor: AI, o sayıya göre
///     "ASTRO_RESIM_1", "ASTRO_RESIM_2"... placeholder'larını <img src="...">
///     içine yerleştiriyor; dönen kodda bu placeholder'lar gerçek görselin
///     base64 data URI'siyle İSTEMCİ TARAFINDA (_substituteImages) değiştirilir.
/// }
/// YANIT (başarı, HTTP 200): {"code": "..."} — worker ```html/```css/```js
///   kirliliğini kendi temizler, geri kalan ayrıştırma istemcide yapılır.
/// YANIT (hata): {"error": "...", "details": "..."}
/// Worker'daki TÜM modeller (gemini-2.5-flash -> 3.5-flash -> 3.1-flash-lite
/// fallback zinciri) Gemini tarafında rate-limit/kota hatasına (HTTP 429)
/// takılırsa fırlatılır. ESKİ worker'da bu durum bazen AI'nin kendi ürettiği
/// alakasız bir cümle olarak kullanıcıya yansıyordu; YENİ worker.js artık
/// Gemini'nin döndürdüğü GERÇEK HTTP durum kodunu ve temiz bir JSON hata
/// mesajını ({"error": "...", "details": "..."}) olduğu gibi geçiriyor —
/// bu yüzden burada HTTP 429'u özel olarak yakalayıp anlamlı bir mesajla
/// (ve UI'da custom popup ile) gösterebiliyoruz.
class WorkerRateLimitException implements Exception {
  final String message;
  WorkerRateLimitException(this.message);
  @override
  String toString() => message;
}

class WorkerService {
  static const String _workerUrl =
      'https://plain-fire-8261.filinta01453.workers.dev/';

  static Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      throw Exception('Sunucuya bağlanılamadı: $e');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Sunucudan geçersiz yanıt geldi (${response.statusCode}).');
    }

    if (response.statusCode != 200) {
      // worker.js artık "error" alanında SABİT bir kod döner (RATE_LIMIT /
      // SERVER_ERROR) — AI'nin ürettiği rastgele bir cümle değil. HTTP 429'u
      // da ek güvence olarak kontrol ediyoruz (Cloudflare/ağ katmanı da 429
      // döndürebilir).
      final code = data['error'] as String?;
      if (response.statusCode == 429 || code == 'RATE_LIMIT') {
        throw WorkerRateLimitException(
            'Sunucumuz şu anda çok yoğun (Gemini rate limit). Lütfen birkaç '
            'dakika sonra tekrar deneyin, ya da ⚙️ Ayarlar\'dan kendi Gemini '
            'API anahtarınızı girerek beklemeden devam edin.');
      }
      throw Exception('Sunucu isteği başarısız oldu (${response.statusCode}).');
    }
    return data;
  }

  /// AI'nin döndürdüğü "ASTRO_RESIM_N" placeholder'larını (worker'ın
  /// buildUserImageBlock talimatıyla ürettiği) kullanıcının GERÇEKTEN
  /// yüklediği N'inci görselin base64 data URI'siyle değiştirir. Görsel
  /// worker'a hiç gönderilmediği için bu değişim tamamen istemcide olur.
  static Future<String> _substituteImages(String code, List<File> images) async {
    var result = code;
    for (var i = 0; i < images.length; i++) {
      final placeholder = 'ASTRO_RESIM_${i + 1}';
      if (!result.contains(placeholder)) continue;
      final bytes = await images[i].readAsBytes();
      final mime = images[i].path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
      result = result.replaceAll(placeholder, dataUri);
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // 1) ANA SOHBET: sıfırdan / komple TEK sayfa site üretimi ("full_site").
  // ---------------------------------------------------------------------
  static Future<String> generateSiteCode({
    required String prompt,
    List<File> images = const [],
    String? previousCode,
  }) async {
    final data = await _post({
      'prompt': prompt,
      'type': 'full_site',
      if (previousCode != null && previousCode.isNotEmpty)
        'previous_code': previousCode,
      if (images.isNotEmpty) 'image_count': images.length,
    });
    final raw = data['code'] as String?;

    if (AiPrompts.isSentinelHit(raw, AiPrompts.codeScopeSentinel)) {
      throw AiRejectedException(AiPrompts.rejectMsg);
    }
    var cleaned = AiPrompts.extractCleanHtml(raw);
    if (cleaned.isEmpty) {
      throw Exception('AI boş/geçersiz bir yanıt döndürdü.');
    }
    if (images.isNotEmpty) {
      cleaned = await _substituteImages(cleaned, images);
    }
    return cleaned;
  }

  // ---------------------------------------------------------------------
  // 1B) ANA SOHBET - B MODU: çok sayfalı site üretimi ("multi_site").
  // ---------------------------------------------------------------------
  static Future<Map<String, String>> generateMultiPageSite({
    required String prompt,
    List<File> images = const [],
    Map<String, String>? previousFiles,
  }) async {
    final data = await _post({
      'prompt': prompt,
      'type': 'multi_site',
      if (previousFiles != null && previousFiles.isNotEmpty)
        'previous_files': previousFiles,
      if (images.isNotEmpty) 'image_count': images.length,
    });
    final raw = data['code'] as String?;

    if (AiPrompts.isSentinelHit(raw, AiPrompts.codeScopeSentinel)) {
      throw AiRejectedException(AiPrompts.rejectMsg);
    }
    final files = AiPrompts.parseMultiFileResponse(raw);
    if (files.isEmpty || !files.containsKey('index.html')) {
      throw Exception('AI beklenen çoklu dosya formatında yanıt vermedi, lütfen tekrar deneyiniz.');
    }
    if (images.isEmpty) return files;

    // Görsel placeholder'ları (ASTRO_RESIM_N) HANGİ dosyaya düştüyse
    // (index.html, urunler.html vb.) orada da değişmesi gerekir.
    final substituted = <String, String>{};
    for (final entry in files.entries) {
      substituted[entry.key] = await _substituteImages(entry.value, images);
    }
    return substituted;
  }

  // ---------------------------------------------------------------------
  // 2) DÜZENLE EKRANI: TAM KODU AI ile noktasal düzenleme ("full_edit").
  // ---------------------------------------------------------------------
  static Future<String> editFullCode({
    required String currentCode,
    required String request,
  }) async {
    final data = await _post({
      'prompt': request,
      'type': 'full_edit',
      'current_code': currentCode,
    });
    final raw = data['code'] as String?;

    if (AiPrompts.isSentinelHit(raw, AiPrompts.codeScopeSentinel)) {
      throw AiRejectedException(AiPrompts.scopeRejectedMsg);
    }
    if ((raw ?? '').contains(AiPrompts.rejectMsg)) {
      throw AiRejectedException(AiPrompts.illegalContentMsg);
    }

    final diffApplied = AiPrompts.applyDiffBlocks(raw, currentCode);
    if (diffApplied != null && diffApplied.isNotEmpty) {
      return diffApplied;
    }
    final fullFallback = AiPrompts.extractCleanHtml(raw);
    if (fullFallback.isNotEmpty) {
      return fullFallback;
    }
    throw Exception('AI değişikliği uygulanamadı, lütfen tekrar deneyiniz.');
  }

  // ---------------------------------------------------------------------
  // 3) ÖN İZLEME: tek bir bölümü (section) AI ile düzenleme ("section_edit").
  // ---------------------------------------------------------------------
  static Future<String> editSection({
    required String sectionHtml,
    required String request,
  }) async {
    final data = await _post({
      'prompt': request,
      'type': 'section_edit',
      'section_html': sectionHtml,
    });
    final raw = data['code'] as String?;

    if (AiPrompts.isSentinelHit(raw, AiPrompts.sectionScopeSentinel)) {
      throw AiRejectedException(AiPrompts.scopeRejectedMsg);
    }
    if ((raw ?? '').contains(AiPrompts.rejectMsg)) {
      throw AiRejectedException(AiPrompts.illegalContentMsg);
    }
    final cleaned = AiPrompts.extractCleanHtml(raw);
    if (cleaned.isEmpty) {
      throw Exception('AI boş/geçersiz bir yanıt döndürdü.');
    }
    return cleaned;
  }

  // ---------------------------------------------------------------------
  // 4) ÖN İZLEME ÜST "AI" BUTONU: arka plan düzenleme ("bg_edit").
  // DİKKAT: own-key akışıyla BİREBİR aynı — sadece CSS parçası gider/döner,
  // sitenin tamamı DEĞİL (worker.js'in ESKİ bg_edit davranışından farklı).
  // ---------------------------------------------------------------------
  static Future<String> editBackground({
    required String request,
    String? currentBackgroundCss,
  }) async {
    final data = await _post({
      'prompt': request,
      'type': 'bg_edit',
      if (currentBackgroundCss != null && currentBackgroundCss.trim().isNotEmpty)
        'current_background_css': currentBackgroundCss,
    });
    final raw = data['code'] as String?;

    if (AiPrompts.isSentinelHit(raw, AiPrompts.bgScopeSentinel)) {
      throw AiRejectedException(AiPrompts.scopeRejectedMsg);
    }
    if (AiPrompts.isSentinelHit(raw, AiPrompts.bgSecuritySentinel)) {
      throw AiRejectedException(AiPrompts.illegalContentMsg);
    }
    final cleaned = AiPrompts.extractCleanCss(raw);
    if (cleaned.isEmpty) {
      throw Exception('AI boş/geçersiz bir yanıt döndürdü.');
    }
    return AiPrompts.withBgSafetyNet(cleaned);
  }
}
