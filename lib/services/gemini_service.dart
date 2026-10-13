import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gemini çağrılarında kullanıcıya gösterilecek, sade Türkçe hata.
class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

class GeminiModel {
  final String id; // "gemini-..." ("models/" öneki olmadan)
  final String displayName;
  const GeminiModel(this.id, this.displayName);

  bool get isLite => id.contains('flash-lite');
  bool get isFlash => id.contains('flash') && !isLite;
  bool get isPro => id.contains('pro');
  bool get isPreview => id.contains('preview') || id.contains('exp');

  String get tag => isLite ? 'En hızlı' : (isFlash ? 'Hızlı' : (isPro ? 'Gelişmiş' : 'Diğer'));
  String get description => isLite
      ? 'En hızlı ve en hafif. Kısa siteler için.'
      : isFlash
          ? 'Hızlı ve dengeli. Çoğu site için yeterli.'
          : isPro
              ? 'Daha dikkatli metinler. Daha yavaş, kotası daha az.'
              : 'Gelişmiş kullanıcılar için.';
}

class GeminiService {
  GeminiService(this.apiKey);
  final String apiKey;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  Map<String, String> get _headers => {'Content-Type': 'application/json', 'x-goog-api-key': apiKey};

  AiException _mapError(http.Response r) {
    String reason = '';
    try {
      reason = (jsonDecode(r.body)['error']?['message'] ?? '').toString().toLowerCase();
    } catch (_) {}
    if (r.statusCode == 400 && reason.contains('api key')) return AiException('Anahtar geçersiz. Tekrar kopyalayıp yapıştır.');
    if (r.statusCode == 401 || r.statusCode == 403) return AiException('Bu anahtar kullanılamıyor. Anahtarın yetkilerini kontrol et.');
    if (r.statusCode == 404) return AiException('Bu model artık yok. Ayarlardan başka bir model seç.');
    if (r.statusCode == 429) return AiException('Kotan dolmuş. Biraz bekle ya da Google AI Studio panelinden kotanı kontrol et.');
    if (r.statusCode >= 500) return AiException('Google şu an yanıt vermiyor. Biraz sonra tekrar dene.');
    return AiException('Bir sorun oluştu (${r.statusCode}). Tekrar dene.');
  }

  /// Anahtarı doğrular ve metin üretebilen modelleri getirir.
  Future<List<GeminiModel>> listModels() async {
    final out = <GeminiModel>[];
    String? token;
    try {
      do {
        final uri = Uri.parse('$_base/models?pageSize=100${token != null ? '&pageToken=$token' : ''}');
        final r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
        if (r.statusCode != 200) throw _mapError(r);
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        for (final m in (j['models'] as List? ?? const [])) {
          if (m is! Map) continue;
          final name = (m['name'] ?? '').toString().replaceFirst('models/', '');
          final methods = (m['supportedGenerationMethods'] as List? ?? const []).map((e) => e.toString()).toList();
          if (!name.startsWith('gemini') || !methods.contains('generateContent')) continue;
          const skip = ['embed', 'tts', 'image', 'live', 'audio', 'vision', 'robotics', 'computer-use', 'learnlm'];
          if (skip.any(name.contains)) continue;
          out.add(GeminiModel(name, (m['displayName'] ?? name).toString()));
        }
        token = j['nextPageToken']?.toString();
      } while (token != null && token.isNotEmpty);
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException('Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.');
    }
    if (out.isEmpty) throw AiException('Bu anahtarla kullanılabilir model bulunamadı.');
    return out;
  }

  /// Önerilen model: kararlı (preview olmayan) en yeni Flash.
  static GeminiModel? recommended(List<GeminiModel> list) {
    final flash = list.where((m) => m.isFlash).toList()..sort((a, b) => b.id.compareTo(a.id));
    final stable = flash.where((m) => !m.isPreview);
    if (stable.isNotEmpty) return stable.first;
    return flash.isNotEmpty ? flash.first : (list.isNotEmpty ? list.first : null);
  }

  static bool _isRetryable(int code) => code == 429 || code >= 500;

  Future<http.Response> _post(String model, Map<String, dynamic> body) => http
      .post(Uri.parse('$_base/models/$model:generateContent'), headers: _headers, body: jsonEncode(body))
      .timeout(const Duration(seconds: 90));

  /// [history]: {role: 'user'|'model', text: ...}. İsteğe bağlı 'imageB64' + 'imageMime'
  /// (06.10.2026: domain asistanı ekran görüntüsü için). [json] true ise yanıt JSON olarak istenir.
  Future<String> generate({
    required String model,
    required String system,
    required List<Map<String, String>> history,
    bool json = false,
  }) async {
    final body = {
      'systemInstruction': {'parts': [{'text': system}]},
      'contents': [
        for (final h in history)
          {
            'role': h['role'],
            'parts': [
              if (h['imageB64'] != null)
                {'inlineData': {'mimeType': h['imageMime'] ?? 'image/webp', 'data': h['imageB64']}},
              {'text': h['text']},
            ],
          },
      ],
      if (json) 'generationConfig': {'responseMimeType': 'application/json'},
    };
    try {
      var r = await _post(model, body);
      // Geçici hatalarda (429 / 5xx) bir kez daha dene.
      if (_isRetryable(r.statusCode)) {
        await Future.delayed(Duration(seconds: r.statusCode == 429 ? 4 : 2));
        r = await _post(model, body);
      }
      if (r.statusCode != 200) throw _mapError(r);
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final parts = (j['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?;
      final text = parts?.map((p) => p['text']?.toString() ?? '').join() ?? '';
      if (text.trim().isEmpty) throw AiException('Yapay zekâ boş yanıt verdi. Tekrar dene.');
      return text;
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException('Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.');
    }
  }
}
