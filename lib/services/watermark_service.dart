/// Üretilen sitelerin altına "Sitora AI ile üretildi" rozetini eklemekten
/// sorumlu tek/merkezi servis.
///
/// NEDEN MERKEZİ: Site içeriği dört farklı yoldan gelebiliyor (AI Chat tek
/// sayfa, AI Chat çok sayfa, form akışı tek sayfa, form akışı çok sayfa) —
/// bu servis her birine AYNI mantıkla uygulanır (bkz. AppState.
/// updateGeneratedCode / updateGeneratedFiles / updateQtGeneratedCode /
/// updateQtGeneratedFiles), böylece "bir yolu unutup rozetsiz site
/// yayınlama" riski oluşmaz.
///
/// İLERİDE ÖDEME SİSTEMİ BAĞLANINCA: AppState.hasBranding alanı zaten
/// buraya bağlı (bkz. çağrı noktaları) — o alan ücretli/domain bağlı
/// kullanıcılar için false yapıldığında, bu servise hiç dokunmadan rozet
/// otomatik kalkar.
class WatermarkService {
  WatermarkService._();

  /// İçerikte rozetin zaten eklenip eklenmediğini anlamak için kullanılan
  /// gizli işaretleyici. AI düzenlemesi (editFullCode vb.) mevcut kodu
  /// tekrar bu servise gönderdiğinde ÇİFT ROZET eklenmesini engeller.
  static const String _marker = '<!--SITORA_WATERMARK-->';

  /// Rozet metni uygulama diline göre değişir; marker (idempotency
  /// işaretleyicisi) her iki dilde de AYNI kalır — böylece bir dilde
  /// eklenmiş rozet, dil değişse bile ikinci kez eklenmez (üstüne
  /// yazılmaz da; zaten üretilmiş bir siteyi geriye dönük değiştirmiyoruz,
  /// sadece YENİ üretimlerde o anki dil kullanılıyor).
  static const String _badgeTextTr = 'Sitora AI ile üretildi — kullanıcı ürünüdür';
  static const String _badgeTextEn = 'Made with Sitora AI — user-generated content';

  static String _badgeHtml(bool isEnglish) {
    final text = isEnglish ? _badgeTextEn : _badgeTextTr;
    return '''
$_marker
<div style="position:fixed;bottom:10px;right:10px;z-index:999999;font-family:Arial,Helvetica,sans-serif;font-size:11px;line-height:1;background:rgba(17,17,17,0.72);color:#fff;padding:6px 12px;border-radius:999px;pointer-events:none;user-select:none;box-shadow:0 2px 6px rgba(0,0,0,0.25);">$text</div>''';
  }

  /// Tek bir HTML dokümanına rozeti ekler. Zaten varsa DOKUNMAZ (idempotent).
  /// `</body>` bulunursa hemen öncesine, bulunamazsa (bozuk/parçalı HTML
  /// ihtimaline karşı) dokümanın sonuna eklenir.
  ///
  /// [isEnglish] o anki uygulama diline göre (LocaleController.isEnglish)
  /// çağıran taraftan gelir; rozet metni buna göre TR/EN seçilir.
  static String apply(String html, {bool isEnglish = false}) {
    if (html.trim().isEmpty) return html;
    if (html.contains(_marker)) return html;

    final badge = _badgeHtml(isEnglish);
    final bodyCloseIndex = _lastIndexOfIgnoreCase(html, '</body>');
    if (bodyCloseIndex != -1) {
      return html.substring(0, bodyCloseIndex) +
          badge +
          '\n' +
          html.substring(bodyCloseIndex);
    }
    return '$html\n$badge';
  }

  /// Çok sayfa (dosya haritası) çıktısına uygular. Yalnızca `.html` ile
  /// biten dosyalara dokunur — `.css`/`.js` gibi dosyalar aynen geçer.
  static Map<String, String> applyToFiles(Map<String, String> files, {bool isEnglish = false}) {
    return files.map((name, content) {
      if (name.toLowerCase().endsWith('.html')) {
        return MapEntry(name, apply(content, isEnglish: isEnglish));
      }
      return MapEntry(name, content);
    });
  }

  static int _lastIndexOfIgnoreCase(String source, String target) {
    final lower = source.toLowerCase();
    return lower.lastIndexOf(target.toLowerCase());
  }
}
