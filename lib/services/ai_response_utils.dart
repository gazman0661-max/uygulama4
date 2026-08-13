/// GeminiService (kendi API anahtarı ile DOĞRUDAN Gemini) ve WorkerService
/// (anahtarsız/ücretsiz akış, Worker üzerinden) arasında BİREBİR AYNI
/// promptları ve yanıt ayrıştırma mantığını paylaşmak için ortak
/// sabitler/yardımcılar.
///
/// ÖNEMLİ: worker.js dosyasındaki prompt metinleri ve sentinel/mesaj
/// sabitleri burasıyla TEXTUAL olarak birebir aynı tutulmalı — biri
/// değişirse diğeri de (hem bu dosya hem worker.js) güncellenmeli.
library;

/// AI kod/site üretiminin reddettiği içerik türlerinde fırlatılan hata.
/// Ekranlar bunu yakalayıp kullanıcıya uygun bir uyarı gösterir.
class AiRejectedException implements Exception {
  final String message;
  AiRejectedException(this.message);
  @override
  String toString() => message;
}

class AiPrompts {
  AiPrompts._();

  static const String rejectMsg =
      'Yalnızca web tasarımı, frontend geliştirme, UI/UX ve web sitesi üretimi konularında yardımcı olabiliyorum. 🚀';
  static const String illegalContentMsg =
      '🚫 Bu içerik/istek yasa dışı veya toplum kurallarına aykırı olabileceği için engellendi. Lütfen içeriği değiştirip tekrar deneyiniz.';

  static const String codeScopeSentinel = 'KOD_DISI_ISTEK_REDDEDILDI';
  static const String sectionScopeSentinel =
      'BOLUM_KAPSAMI_DISI_ISTEK_REDDEDILDI';
  static const String bgScopeSentinel = 'ARKAPLAN_KAPSAMI_DISI_ISTEK_REDDEDILDI';
  static const String bgSecuritySentinel = 'ARKAPLAN_GUVENLIK_REDDEDILDI';

  static const String scopeRejectedMsg =
      'Bu istek kapsam dışında, lütfen yalnızca ilgili kısma yönelik somut bir düzenleme talebi yazınız.';

  // B modu (çok sayfa) çıktısında dosyaları ayırmak için kullanılan ayraç.
  static const String fileMarkerPrefix = '===DOSYA:';
  static const String fileMarkerSuffix = '===';

  /// Ortak kalite/tasarım kural bloğu (hem TEK SAYFA hem ÇOK SAYFA üretiminde
  /// kullanılır). worker.js'teki MASTER_QUALITY_RULES sabitiyle TEXTUAL
  /// olarak birebir aynı tutulmalı.
  static const String masterQualityRules = '''
SEN AstroFelyx AI adında profesyonel bir AI web tasarım ve frontend geliştirme
asistanısın. Premium seviyede landing page, portfolio, SaaS, agency, ecommerce,
dashboard ve modern site tasarımları yapıyorsun.

RESPONSIVE (MOBİL + MASAÜSTÜ) TEKNİK ZORUNLULUKLAR (ASLA ATLAMA — BU KURALLARA UYULMAMASI
SİTENİN MOBİLDE MASAÜSTÜ GİBİ/BOZUK GÖRÜNMESİNE YOL AÇAR):
- <head> içine MUTLAKA şu satırı ekle, ASLA atlama: <meta name="viewport"
  content="width=device-width, initial-scale=1.0">. Bu etiket eksikse mobil tarayıcı
  sayfayı ~980px genişlikte varsayıp küçültür, sonuç masaüstü görünümünün küçültülmüş,
  yazıları okunmaz hali olur — bu KABUL EDİLEMEZ bir hatadır.
- Başlıklar (h1/h2/h3) için font-size'ı SAF vw biriminde ASLA verme (örn. font-size:8vw
  gibi tek başına vw kullanma) — dar/geniş ekranlarda öngörülemez şekilde çok büyük/çok
  küçük olur ve satır kırılmaları bozulur. Bunun yerine MUTLAKA clamp(min, tercih, max)
  kullan, örn: font-size: clamp(1.8rem, 5vw, 3.5rem);. min ve max değerleri hem 360px hem
  1920px'de metnin okunaklı ve düzgün kırılan halde kalmasını garanti etmeli.
- html ve body elementlerine ASLA sabit piksel width/height verme (örn. width:375px gibi).
  Her zaman width:100%; margin:0; kullan; body'nin taşmasına izin verme (overflow-x:hidden yeterli).
- Sitenin ana dış kapsayıcısına KESİNLİKLE sabit piksel width/height verme. Bunun yerine:
  width:100%; max-width:<mantıklı bir üst sınır, örn. 480px-1200px arası içeriğe göre>; kullan.
  Genişlik/yükseklik oranı korunmalıysa aspect-ratio kullan; sabit px height verme.
- TÜM elemanlar relative birimlerle (%, vw, vh, vmin, clamp(), min(), max()) ölçeklenmeli;
  hiçbir eleman sadece sabit px genişlik/yükseklikle ekranı doldurmaya çalışmamalı.
- MOBİL TARAYICI "100vh" TUZAĞI (KESİNLİKLE ÖNLE): Mobil tarayıcılarda '100vh' adres
  çubuğunun kapladığı alanı da dahil ederek hesaplanır; bu yüzden tam-ekran yükseklik
  istenen HER bölümde MUTLAKA önce 'min-height:100vh;' sonra HEMEN ARDINDAN (fallback
  olarak üzerine yazması için) 'min-height:100dvh;' yaz (iki satır da olmalı). 'height'
  yerine 'min-height' tercih et (içerik taşarsa kesilmesin).
- Masaüstünde içerik ortalanmalı ve gereksiz genişlememeli (max-width ile sınırla), ama
  asla küçük bir kutu halinde etrafı boş kalacak şekilde durmamalı; arka plan (body/section
  background) her zaman tüm viewport'u doldurmalı, sadece iç içerik kapsayıcısı max-width
  ile sınırlanmalı.
- 600px altı ekranlar için MUTLAKA en az bir @media (max-width: 600px) bloğu ekle; bu
  blokta özellikle çok sütunlu (flex/grid) yapıları tek sütuna indir, büyük padding/margin
  değerlerini küçült, buton ve menüleri dokunma-dostu boyuta getir.
- Kodu teslim etmeden önce zihninde HEM 360px HEM 1920px genişlikte sayfanın nasıl
  göründüğünü simüle et; sabit pikselle tanımlanmış ve düzgün ölçeklenmeyen bir eleman
  fark edersen relative birimlere çevir.

TASARIM KALİTESİ: Üretilen siteler sıradan görünemez. Dribbble, Awwwards, Framer, Vercel,
Linear, Stripe, Apple seviyesinde modern görünmeli. Her tasarımda: responsive navbar, hero
section, modern butonlar, düzgün spacing, section yapısı, modern font sistemi, hover
animasyonları, mobile responsive yapı olmalı.

CSS KALİTESİ: modern shadow sistemi, border-radius, gradientler, animasyonlar, transition
sistemi kullan; kötü renk kombinasyonları kullanma.

KOD KALİTESİ: temiz kod yaz, semantic HTML kullan, bozuk kod/eksik tag/çalışmayan JS bırakma.

TASARIM PRENSİPLERİ: whitespace kullan, minimalist ama premium görünüm oluştur, kullanıcı
deneyimine önem ver, okunabilirlik yüksek olsun, section hierarchy düzgün olsun.

KÖTÜ TASARIM YASAK: eski görünüm, 2015 tarzı tasarım, kötü renkler, düzensiz spacing,
aşırı büyük yazılar, amatör görünüm yasak.

MODERN UI BİLEŞENLERİ VE DİNAMİK TEMA:
- SLAYT GÖSTERİSİ: Birden fazla görseli (ürün, galeri vs.) alt alta dizmek yerine
  KESİNLİKLE akıcı (smooth) geçişli, CSS veya Vanilla JS ile çalışan modern bir
  slider/carousel yapısı oluştur.
- DİNAMİK ARKA PLAN ANİMASYONLARI: Sayfaya mutlaka saf CSS ile hareketli arka planlar
  ekle (kullanıcı kalp/yıldız/kar tanesi gibi spesifik bir nesne tarif ederse o nesnenin
  şeklini yansıt; belirtmezse animated mesh gradient, floating glowing blobs vb. kullan).

TEMA SEÇİMİ (KULLANICININ TALEBİNE GÖRE):
- Kullanıcı ferah/aydınlık/açık renk/beyaz/soft isterse: açık tema (light mode), pastel ve
  soft renk geçişli animasyonlar.
- Kullanıcı koyu/neon/karanlık/siberpunk isterse: koyu tema (dark mode), neon parlayan
  animasyonlar.
- Kullanıcı tema belirtmezse: sitenin sektörüne en uygun modern temayı sen seç (varsayılan
  eğilim: dark modern UI, neon gradient detaylar, premium glass efektler, smooth animation,
  modern card system).

GÖRSEL KULLANIM KURALLARI:
- Sitedeki HER görsel (kullanıcı yüklemesi veya placeholder fark etmez; hero, banner, ürün,
  galeri, kart, profil ne olursa olsun) MUTLAKA gerçek bir <img> etiketiyle eklenmelidir.
  Görselleri ASLA sadece CSS background-image ile gösterme; İÇİNE gerçek <img src="..."> koy
  (object-fit:cover kullanabilirsin, sorun değil, ama etiket mutlaka <img> olmalı). Bu kural
  önizlemede kullanıcının görsellere dokunup galeriden anında değiştirebilmesi için ZORUNLUDUR.
- Stok görsel gerekiyorsa loremflickr/unsplash gibi kontrolsüz dış servisler KULLANMA.
  Bunun yerine: https://placehold.co/{genişlik}x{yükseklik}/{arka_plan_hex}/{yazı_hex}?text={bölüm_adı}
  Açık temada soft/kurumsal pastel tonlar (örn. e2e8f0/475569), koyu/neon temada gece ve
  kontrast tonlar (örn. 1e293b/f8fafc) kullan. text parametresi kullanıcının yazdığı dilde
  olmalı (Türkçe yazdıysa Türkçe, İngilizce yazdıysa İngilizce), kelimeler arası boşluk
  yerine '+' kullan. ASLA 'resim.jpg' gibi gerçekte var olmayan sahte linkler yazma.''';

  static bool isSentinelHit(String? raw, String sentinel) {
    final t = (raw ?? '').replaceAll(RegExp(r'```[a-zA-Z]*|```'), '').trim();
    return t == sentinel || (t.length < 45 && t.contains(sentinel));
  }

  /// Ham AI yanıtını markdown/açıklama kirliliğinden temizleyip sadece HTML'i çıkarır.
  static String extractCleanHtml(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var t = raw.replaceAll(RegExp(r'```html|```'), '').trim();
    final firstTag = t.indexOf('<');
    final lastTag = t.lastIndexOf('>');
    if (firstTag == -1 || lastTag == -1 || lastTag < firstTag) return '';
    t = t.substring(firstTag, lastTag + 1).trim();
    return _repairTruncatedHtml(t);
  }

  /// AI yanıtı token limitine takılıp yarıda kesilmişse (örn. bir <style>
  /// veya <script> bloğu açık kalmış, </html> hiç gelmemiş), WebView bunu
  /// yüklerken tarayıcı motoru kapanmamış <style>/<script> içeriğini
  /// sonrasındaki TÜM görünür içeriği yutacak şekilde yorumlayabilir — bu da
  /// "site oluştu ama önizleme bembeyaz" görünümüne yol açar. Bu, kesikliği
  /// tespit edip açık kalan etiketleri kapatarak en azından üretilen kısmın
  /// görünür kalmasını garanti eden bir kurtarma adımıdır (veri kaybı yok,
  /// sadece açık etiketler kapatılıyor).
  static String _repairTruncatedHtml(String html) {
    final hasDoctypeOrHtml =
        html.toLowerCase().contains('<html') || html.toLowerCase().contains('<!doctype');
    if (!hasDoctypeOrHtml) return html;
    if (html.toLowerCase().trim().endsWith('</html>')) return html;

    var fixed = html;
    // Açık kalan <style>...  (kapanış yoksa) -> kapat.
    final styleOpens = RegExp(r'<style[^>]*>', caseSensitive: false)
        .allMatches(fixed)
        .length;
    final styleCloses =
        RegExp(r'</style>', caseSensitive: false).allMatches(fixed).length;
    if (styleOpens > styleCloses) {
      fixed = '$fixed\n</style>';
    }
    // Açık kalan <script>... (kapanış yoksa) -> kapat.
    final scriptOpens = RegExp(r'<script[^>]*>', caseSensitive: false)
        .allMatches(fixed)
        .length;
    final scriptCloses =
        RegExp(r'</script>', caseSensitive: false).allMatches(fixed).length;
    if (scriptOpens > scriptCloses) {
      fixed = '$fixed\n</script>';
    }
    // body/html açık ama kapanmamışsa kapat (görünürlüğü garanti eder).
    if (fixed.toLowerCase().contains('<body') &&
        !fixed.toLowerCase().contains('</body>')) {
      fixed = '$fixed\n</body>';
    }
    if (!fixed.toLowerCase().contains('</html>')) {
      fixed = '$fixed\n</html>';
    }
    return fixed;
  }

  /// Ham AI yanıtını temizleyip sadece saf CSS'i çıkarır.
  static String extractCleanCss(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var t = raw.replaceAll(RegExp(r'```css|```html|```'), '').trim();
    if (!t.contains('{')) return '';
    final bodyIdx = t.toLowerCase().indexOf('body');
    if (bodyIdx > 0) {
      final before = t.substring(0, bodyIdx);
      if (RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ]{4,}').hasMatch(before)) {
        t = t.substring(bodyIdx);
      }
    }
    t = t.trim();
    // Yanıt token limitine takılıp yarıda kesilmiş olabilir (açık '{' sayısı
    // kapalı '}' sayısından fazla). Böyle bir durumda TÜMÜNÜ atmak yerine,
    // son TAMAMLANMIŞ (dengeli) kurala kadar olan kısmı kurtarıp kullanılabilir
    // bir CSS döndürüyoruz — kısmi ama çalışan bir sonuç, hiç sonuç olmamasından
    // iyidir. Sadece sondaki yarım/dengesiz kuralı kırpar, baştaki tamamlanmış
    // kuralları etkilemez.
    final openCount = '{'.allMatches(t).length;
    final closeCount = '}'.allMatches(t).length;
    if (openCount > closeCount) {
      var depth = 0;
      var lastBalancedEnd = -1;
      for (var i = 0; i < t.length; i++) {
        if (t[i] == '{') {
          depth++;
        } else if (t[i] == '}') {
          depth--;
          if (depth == 0) lastBalancedEnd = i;
        }
      }
      if (lastBalancedEnd > 0) {
        t = t.substring(0, lastBalancedEnd + 1).trim();
      } else {
        return '';
      }
    }
    if (!t.contains('{') || !t.contains('}')) return '';
    return t.trim();
  }

  /// AI'nin ESKI_KOD/YENI_KOD blokları halinde döndürdüğü "sadece değişen
  /// kısım" yanıtını ayrıştırıp tam koda uygular. Eşleşme bulunamazsa null.
  static String? applyDiffBlocks(String? raw, String fullCode) {
    if (raw == null || raw.isEmpty) return null;
    final t = raw.replaceAll(RegExp(r'```[a-zA-Z]*\n?|```'), '').trim();
    final re = RegExp(
      r'ESKI_KOD:\s*\n?([\s\S]*?)\nYENI_KOD:\s*\n?([\s\S]*?)(?=\n*ESKI_KOD:|$)',
    );
    var result = fullCode;
    var count = 0;
    for (final match in re.allMatches(t)) {
      final oldPart = (match.group(1) ?? '').replaceAll(RegExp(r'\n+$'), '');
      final newPart = (match.group(2) ?? '').trim();
      if (oldPart.trim().isEmpty) return null;
      final occurrences = result.split(oldPart).length - 1;
      if (occurrences != 1) return null;
      result = result.replaceFirst(oldPart, newPart);
      count++;
    }
    if (count == 0) return null;
    return result;
  }

  /// "===DOSYA: dosya.html ===" bloklarıyla ayrılmış ham AI yanıtını
  /// dosya adı -> içerik haritasına çevirir.
  static Map<String, String> parseMultiFileResponse(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    var t = raw.replaceAll(RegExp(r'```[a-zA-Z]*\n?|```'), '').trim();
    final re = RegExp(
      r'===DOSYA:\s*(.+?)\s*===\s*\n([\s\S]*?)(?=\n===DOSYA:|$)',
    );
    final result = <String, String>{};
    for (final match in re.allMatches(t)) {
      final fileName = (match.group(1) ?? '').trim();
      final content = (match.group(2) ?? '').trim();
      if (fileName.isEmpty || content.isEmpty) continue;
      result[fileName] = content;
    }
    return result;
  }

  /// editBackground güvenlik ağı: AI 'position' kuralına tam uymasa bile
  /// overlay'i her koşulda viewport'a sabitleyen daha yüksek öncelikli kural.
  static String withBgSafetyNet(String cleanedCss) {
    return '$cleanedCss\n'
        'body::before, body::after {\n'
        '  position: fixed !important;\n'
        '  top: 0 !important; left: 0 !important;\n'
        '  width: 100vw !important; height: 100vh !important;\n'
        '  margin: 0 !important; pointer-events: none !important;\n'
        '}';
  }
}
