import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_response_utils.dart';
import 'ai_settings_service.dart';

/// Sitora artık kendi sunucusu/worker'ı ÜZERİNDEN değil, kullanıcının
/// Ayarlar'dan girdiği KENDİ Gemini API anahtarıyla DOĞRUDAN
/// generativelanguage.googleapis.com'a bağlanır (bkz. ai_settings_service.dart
/// — anahtar/model seçimi cihazda saklanır). Puan/kota sistemi YOK — istekler
/// doğrudan kullanıcının kendi Google hesabının kotasına tabidir.
///
/// Eski WorkerService ile AYNI genel API'yi (generateSiteCode,
/// generateMultiPageSite, editFullCode, editSection, editBackground) ve AYNI
/// yanıt ayrıştırma mantığını (ai_response_utils.dart) korur — sadece
/// prompt'lar artık İSTEMCİ tarafında kuruluyor ve istek doğrudan Gemini'ye
/// gidiyor.
class GeminiRateLimitException implements Exception {
  final String message;
  GeminiRateLimitException(this.message);
  @override
  String toString() => message;
}

class GeminiTimeoutException implements Exception {
  final String message;
  GeminiTimeoutException(this.message);
  @override
  String toString() => message;
}

/// Ayarlar'da henüz API anahtarı/model seçilmemişse fırlatılır.
class GeminiNotConfiguredException implements Exception {
  final String message;
  GeminiNotConfiguredException(this.message);
  @override
  String toString() => message;
}

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  static const Duration _requestTimeout = Duration(seconds: 45);

  /// Ayarlar'daki "Modelleri Çek" butonu tarafından çağrılır: Google'ın o
  /// anki güncel model listesini döner (sadece generateContent destekleyen,
  /// yani site üretimi/düzenleme için kullanılabilir modeller).
  static Future<List<String>> fetchAvailableModels(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiNotConfiguredException('Önce bir Gemini API anahtarı girin.');
    }
    late final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$_baseUrl/models?key=$apiKey'))
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw GeminiTimeoutException(
          'Model listesi alınamadı (zaman aşımı). İnternet bağlantını kontrol et.');
    } catch (e) {
      throw Exception('Model listesi alınırken bağlantı hatası: $e');
    }

    if (response.statusCode != 200) {
      throw Exception(
          'Model listesi alınamadı (${response.statusCode}). API anahtarını kontrol et.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Model listesi için geçersiz yanıt geldi.');
    }

    final models = (data['models'] as List?) ?? const [];
    final names = <String>[];
    for (final m in models) {
      if (m is! Map) continue;
      final methods = (m['supportedGenerationMethods'] as List?) ?? const [];
      if (!methods.contains('generateContent')) continue;
      final name = (m['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      // "models/gemini-2.5-flash" -> "gemini-2.5-flash"
      names.add(name.startsWith('models/') ? name.substring(7) : name);
    }
    names.sort();
    return names;
  }

  static Future<Map<String, dynamic>> _generate({
    required String systemInstruction,
    required String userPrompt,
    List<File> images = const [],
  }) async {
    final apiKey = await AiSettingsService.instance.getApiKey();
    final model = await AiSettingsService.instance.getModel();
    if (apiKey == null || apiKey.isEmpty) {
      throw GeminiNotConfiguredException(
          'Gemini API anahtarı ayarlanmamış. Ayarlar > AI bölümünden ekleyin.');
    }
    if (model == null || model.isEmpty) {
      throw GeminiNotConfiguredException(
          'Bir Gemini modeli seçilmemiş. Ayarlar > AI bölümünden "Modelleri Çek" ile seçin.');
    }

    final parts = <Map<String, dynamic>>[
      {'text': userPrompt},
    ];
    for (final img in images) {
      final bytes = await img.readAsBytes();
      final mime = img.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      parts.add({
        'inline_data': {'mime_type': mime, 'data': base64Encode(bytes)}
      });
    }

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {'role': 'user', 'parts': parts}
      ],
      'generationConfig': {'temperature': 0.7},
    };

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/models/$model:generateContent?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw GeminiTimeoutException(
          'Gemini\'den yanıt alınamadı (zaman aşımı). Lütfen internet bağlantını kontrol edip tekrar dene.');
    } catch (e) {
      throw Exception('Gemini\'ye bağlanılamadı: $e');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Gemini\'den geçersiz yanıt geldi (${response.statusCode}).');
    }

    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        throw GeminiRateLimitException(
            'Gemini API kota/rate-limit sınırına takıldı. Lütfen birkaç dakika sonra tekrar deneyin.');
      }
      final errMsg = (data['error'] is Map)
          ? (data['error']['message'] as String? ?? 'Bilinmeyen hata')
          : 'Bilinmeyen hata';
      throw Exception('Gemini isteği başarısız (${response.statusCode}): $errMsg');
    }
    return data;
  }

  static String _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';
      final buffer = StringBuffer();
      for (final p in parts) {
        if (p is Map && p['text'] is String) buffer.write(p['text']);
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  // ---------------------------------------------------------------------
  // Ortak talimatlar (eski worker.js'in sunucu tarafındaki prompt'larının
  // istemci tarafındaki karşılığı).
  // ---------------------------------------------------------------------
  static String _imageInstruction(int imageCount) {
    if (imageCount <= 0) return '';
    final placeholders =
        List.generate(imageCount, (i) => 'ASTRO_RESIM_${i + 1}').join(', ');
    return '\n\nKullanıcı $imageCount adet görsel yükledi. Görsellerin GERÇEK içeriğini görmüyorsun; '
        'bunların yerine sırasıyla şu placeholder metinleri <img> etiketinin src attribute\'una AYNEN yaz: '
        '$placeholders (örn. <img src="ASTRO_RESIM_1" alt="...">). Placeholder\'ları başka hiçbir yerde kullanma.';
  }

  static const String _offTopicRule =
      'Eğer istek web tasarımı, site/sayfa üretimi veya düzenlemesiyle İLGİSİZSE, '
      'başka HİÇBİR ŞEY yazmadan SADECE şu metni döndür: ${AiPrompts.codeScopeSentinel}\n'
      'Eğer istek yasa dışı, zararlı veya topluluk kurallarına aykırı bir içerik üretmeni istiyorsa, '
      'başka HİÇBİR ŞEY yazmadan SADECE şu metni döndür: ${AiPrompts.rejectMsg}';

  // ---------------------------------------------------------------------
  // 1) ANA SOHBET: sıfırdan / komple TEK sayfa site üretimi.
  // ---------------------------------------------------------------------
  static Future<String> generateSiteCode({
    required String prompt,
    List<File> images = const [],
    String? previousCode,
  }) async {
    final system = 'Sen profesyonel bir web tasarımcısı/frontend geliştiricisin. '
        'Kullanıcının isteğine göre TEK bir dosyada, tamamen kendi kendine yeten '
        '(inline <style> ve <script> içeren, dış dosya bağlantısı olmayan), modern, '
        'mobil uyumlu, Türkçe içerikli TAM bir HTML sayfası üret. Yanıtın SADECE ham HTML '
        'olsun; açıklama, markdown kod bloğu (```), başlık gibi HİÇBİR ek metin ekleme.'
        '${_imageInstruction(images.length)}\n\n$_offTopicRule'
        '${previousCode != null && previousCode.isNotEmpty ? '\n\nMevcut site kodu (isteğe göre baştan/güncellenmiş üret):\n$previousCode' : ''}';

    final data = await _generate(systemInstruction: system, userPrompt: prompt, images: images);
    final raw = _extractText(data);

    if (AiPrompts.isSentinelHit(raw, AiPrompts.codeScopeSentinel)) {
      throw AiRejectedException(AiPrompts.rejectMsg);
    }
    if (raw.contains(AiPrompts.rejectMsg) && !raw.trim().contains('<')) {
      throw AiRejectedException(AiPrompts.illegalContentMsg);
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
  // 1B) ANA SOHBET - B MODU: çok sayfalı site üretimi.
  // ---------------------------------------------------------------------
  static Future<Map<String, String>> generateMultiPageSite({
    required String prompt,
    List<File> images = const [],
    Map<String, String>? previousFiles,
  }) async {
    final system = 'Sen profesyonel bir web tasarımcısı/frontend geliştiricisin. '
        'Kullanıcının isteğine göre BİRDEN FAZLA bağlantılı HTML sayfası üret (gerekirse ortak bir '
        'style.css). MUTLAKA bir "index.html" dosyası olmalı. Her dosyayı şu formatta ayır (başka '
        'HİÇBİR ek açıklama, markdown kod bloğu (```) ekleme):\n'
        '===DOSYA: index.html ===\n<...tam html içeriği...>\n'
        '===DOSYA: urunler.html ===\n<...tam html içeriği...>\n'
        '(gerekirse) ===DOSYA: style.css ===\n<...css içeriği...>\n'
        'Sayfalar arası linkler birbirini doğru dosya adlarıyla göstermeli. Türkçe içerik, mobil uyumlu, modern tasarım.'
        '${_imageInstruction(images.length)}\n\n$_offTopicRule'
        '${previousFiles != null && previousFiles.isNotEmpty ? '\n\nMevcut dosyalar (isteğe göre güncellenmiş üret):\n${jsonEncode(previousFiles)}' : ''}';

    final data = await _generate(systemInstruction: system, userPrompt: prompt, images: images);
    final raw = _extractText(data);

    if (AiPrompts.isSentinelHit(raw, AiPrompts.codeScopeSentinel)) {
      throw AiRejectedException(AiPrompts.rejectMsg);
    }
    final files = AiPrompts.parseMultiFileResponse(raw);
    if (files.isEmpty || !files.containsKey('index.html')) {
      throw Exception('AI beklenen çoklu dosya formatında yanıt vermedi, lütfen tekrar deneyiniz.');
    }
    if (images.isEmpty) return files;

    final substituted = <String, String>{};
    for (final entry in files.entries) {
      substituted[entry.key] = await _substituteImages(entry.value, images);
    }
    return substituted;
  }

  // ---------------------------------------------------------------------
  // 2) DÜZENLE EKRANI: TAM KODU AI ile noktasal düzenleme.
  // ---------------------------------------------------------------------
  static Future<String> editFullCode({
    required String currentCode,
    required String request,
  }) async {
    final system = 'Sen bir HTML/CSS/JS düzenleme asistanısın. Sana mevcut bir HTML sayfasının '
        'TAMAMI ve kullanıcının o sayfa üzerinde yapmak istediği NOKTASAL bir değişiklik isteği '
        'verilecek. Mümkün olduğunca SADECE değişen kısmı şu formatta döndür (başka açıklama ekleme, '
        'markdown kod bloğu kullanma):\n'
        'ESKI_KOD:\n<mevcut koddan BİREBİR/TAM olarak eşleşen, değiştirilecek parça>\n'
        'YENI_KOD:\n<yeni hali>\n'
        'Birden fazla değişiklik varsa bu bloğu tekrarla. ESKI_KOD kısmı mevcut kodda TAM OLARAK BİR '
        'KEZ geçmelidir, yoksa eşleşme başarısız olur. Eğer değişiklik çok büyük/dağınıksa, bunun '
        'yerine TÜM güncellenmiş HTML\'i (ESKI_KOD/YENI_KOD kullanmadan, doğrudan ham HTML olarak) döndür.\n\n$_offTopicRule';
    final userPrompt = 'Mevcut kod:\n$currentCode\n\nDeğişiklik isteği: $request';

    final data = await _generate(systemInstruction: system, userPrompt: userPrompt);
    final raw = _extractText(data);

    if (AiPrompts.isSentinelHit(raw, AiPrompts.codeScopeSentinel)) {
      throw AiRejectedException(AiPrompts.scopeRejectedMsg);
    }
    if (raw.contains(AiPrompts.rejectMsg) && !raw.contains('ESKI_KOD') && !raw.trim().contains('<')) {
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
  // 3) ÖN İZLEME: tek bir bölümü (section) AI ile düzenleme.
  // ---------------------------------------------------------------------
  static Future<String> editSection({
    required String sectionHtml,
    required String request,
  }) async {
    final system = 'Sen bir HTML düzenleme asistanısın. Sana bir web sayfasından TEK BİR BÖLÜMÜN '
        '(section) HTML\'i ve bu bölüm için bir değişiklik isteği verilecek. SADECE o bölümün '
        'GÜNCELLENMİŞ HTML\'ini döndür (sayfanın geri kalanını değil), başka açıklama veya markdown '
        'kod bloğu ekleme.\n\n'
        'Eğer istek bu bölümün kapsamı dışındaysa (örn. tüm siteyle ilgiliyse), başka HİÇBİR ŞEY '
        'yazmadan SADECE şu metni döndür: ${AiPrompts.sectionScopeSentinel}\n'
        'Eğer istek yasa dışı/zararlı bir içerik üretmeni istiyorsa, SADECE şu metni döndür: ${AiPrompts.rejectMsg}';
    final userPrompt = 'Bölüm HTML\'i:\n$sectionHtml\n\nDeğişiklik isteği: $request';

    final data = await _generate(systemInstruction: system, userPrompt: userPrompt);
    final raw = _extractText(data);

    if (AiPrompts.isSentinelHit(raw, AiPrompts.sectionScopeSentinel)) {
      throw AiRejectedException(AiPrompts.scopeRejectedMsg);
    }
    if (raw.contains(AiPrompts.rejectMsg) && !raw.trim().contains('<')) {
      throw AiRejectedException(AiPrompts.illegalContentMsg);
    }
    final cleaned = AiPrompts.extractCleanHtml(raw);
    if (cleaned.isEmpty) {
      throw Exception('AI boş/geçersiz bir yanıt döndürdü.');
    }
    return cleaned;
  }

  // ---------------------------------------------------------------------
  // 4) ÖN İZLEME ÜST "AI" BUTONU: arka plan düzenleme.
  // ---------------------------------------------------------------------
  static Future<String> editBackground({
    required String request,
    String? currentBackgroundCss,
  }) async {
    final system = 'Sen bir CSS asistanısın. Görevin, bir web sayfasının ARKA PLANI için (body '
        'arka planı/dekoratif katman, body::before veya body::after üzerinden) SADECE CSS kuralları '
        'üretmek. Kullanıcının isteğine göre CSS döndür — SADECE ham CSS, başka açıklama veya markdown '
        'kod bloğu ekleme. Arka plan katmanı "position: fixed" ile tüm ekranı kaplamalı ve '
        '"pointer-events: none" olmalı ki sayfa etkileşimini engellemesin.\n\n'
        'Eğer istek arka plan kapsamı dışındaysa (örn. sayfanın metnini/yapısını değiştirmeyi '
        'istiyorsa), başka HİÇBİR ŞEY yazmadan SADECE şu metni döndür: ${AiPrompts.bgScopeSentinel}\n'
        'Eğer istek güvenlik açısından riskli (örn. script enjeksiyonu, dış kaynak yükleme) ise, '
        'SADECE şu metni döndür: ${AiPrompts.bgSecuritySentinel}'
        '${currentBackgroundCss != null && currentBackgroundCss.trim().isNotEmpty ? '\n\nMevcut arka plan CSS\'i:\n$currentBackgroundCss' : ''}';

    final data = await _generate(systemInstruction: system, userPrompt: request);
    final raw = _extractText(data);

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
}
