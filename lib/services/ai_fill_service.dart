import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ============================================================================
/// AI DOLDURMA — WORKER YAPILANDIRMASI
/// ============================================================================
/// 30.08.2026 eklendi, 31.08.2026 Worker adresi eklenip AKTİF edildi.
/// baseUrl boş kaldığı sürece [AiFillService.isConfigured]
/// false döner, çağıran taraf (ai_fill_dialog.dart) bunu görüp kullanıcıya
/// "AI henüz bağlanmadı" der, İSTEK ATMAZ — boş URL'e istek atıp çökme/
/// anlamsız hata riski böylece hiç oluşmaz.
///
/// URL elimize geçince tek yapılacak şey: aşağıdaki baseUrl'i doldurmak.
/// Worker'ın kendisi TEK bir POST endpoint'i sağlamalı: `/api/ai-fill`
/// (bkz. AiFillService.generateFields'taki istek/cevap sözleşmesi).
/// ============================================================================
class AiFillConfig {
  AiFillConfig._();

  /// 31.08.2026 eklendi — deploy edilen Worker adresi (bkz. Cloudflare
  /// dashboard, Worker adı: plain-fire-8261). SONUNDA / YOK, hosting_service
  /// .dart'taki HostingConfig.baseUrl ile AYNI desen.
  static const String baseUrl = 'https://plain-fire-8261.filinta01453.workers.dev';

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}

/// Tek bir AI doldurma isteğinin SONUCU. `fields`, Worker'ın ürettiği
/// serbest metin alanlarını taşır (ör. {'tagline': '...', 'services': '...'})
/// — hangi anahtarların üretileceği SEKTÖRE göre değişebileceği için burada
/// sabit bir şema YOK, çağıran form ekranı hangi anahtarı hangi controller'a
/// yazacağını kendi bilir (bkz. kuafor_form_screen.dart > _openAiFillDialog).
class AiFillResult {
  final Map<String, String> fields;
  const AiFillResult(this.fields);
}

/// ============================================================================
/// AI DOLDURMA — SERVİS
/// ============================================================================
/// SADECE üretici (yaratıcı) metinler için kullanılır — tagline/slogan,
/// hizmet açıklamaları gibi. Adres/telefon/sosyal medya gibi kullanıcının
/// zaten kendi yazdığı ham veriler buraya HİÇ gönderilmez — onlar
/// ai_fill_dialog.dart içinde yerel olarak (AI'ye gitmeden, anında, ücretsiz)
/// ilgili controller'lara yazılır. Bu ayrım bilinçli: hem maliyeti düşürür
/// hem de AI'nin telefon/adres gibi kritik verileri YANLIŞ yazma
/// (halüsinasyon) riskini tamamen ortadan kaldırır.
/// ============================================================================
class AiFillService {
  AiFillService._();

  static bool get isConfigured => AiFillConfig.isConfigured;

  /// [sector] örn. "Kuaför / Berber", [companyName] işletme adı,
  /// [aboutInfo] kullanıcının serbest metinle yazdığı "ürünlerim/
  /// hizmetlerim/işletmem hakkında" bilgisi, [siteLang] 'tr'/'en'.
  ///
  /// TEK bir HTTP isteği atar — sayfadaki kaç metin alanı olursa olsun,
  /// hepsi bu TEK istekle (Worker'ın döndürdüğü JSON'daki birden fazla
  /// anahtarla) doldurulur. Asla alan başına ayrı istek ATILMAZ (bkz.
  /// bu dosyanın üstündeki tasarım kararı — istek limiti/maliyet).
  ///
  /// Başarısız olursa (Worker yapılandırılmamış, ağ hatası, zaman aşımı,
  /// Worker 4xx/5xx) null döner — İSTİSNA FIRLATMAZ. Çağıran taraf null'ı
  /// "AI şu an yardımcı olamadı, formu elle doldurabilirsin" olarak
  /// gösterir; akış hiçbir zaman tıkanmaz.
  static Future<AiFillResult?> generateFields({
    required String sector,
    required String companyName,
    required String aboutInfo,
    String siteLang = 'tr',
  }) async {
    if (!isConfigured) return null;
    try {
      final res = await http
          .post(
            Uri.parse('${AiFillConfig.baseUrl}/api/ai-fill'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sector': sector,
              'companyName': companyName,
              'aboutInfo': aboutInfo,
              'lang': siteLang,
            }),
          )
          // Worker en kötü senaryoda (4 model de sırayla dene/başarısız)
          // 29 saniyeye kadar sürebilir (bkz. Worker kodundaki TIMEOUT
          // NOTU) — burası ondan düşük olursa client, Worker daha cevap
          // vermeden pes eder. 35sn ile 6 saniyelik güvenli pay bırakıyoruz.
          // Bu SADECE gerçek bir çoklu-sağlayıcı arızasında yaşanır — normal
          // durumda ilk model 1-3 saniyede cevap verir, kullanıcı hiç bu
          // kadar beklemez.
          .timeout(const Duration(seconds: 35));

      if (res.statusCode != 200) {
        debugPrint('AiFillService: Worker ${res.statusCode} döndürdü — ${res.body}');
        return null;
      }
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) return null;
      final fields = <String, String>{};
      decoded.forEach((key, value) {
        if (value is String) fields[key.toString()] = value;
      });
      if (fields.isEmpty) return null;
      return AiFillResult(fields);
    } catch (e) {
      debugPrint('AiFillService: istek başarısız — $e');
      return null;
    }
  }
}
