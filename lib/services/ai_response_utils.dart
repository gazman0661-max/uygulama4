/// WorkerService'in (worker.js üzerinden gelen AI yanıtlarını yorumlamak
/// için kullandığı) ortak sentinel sabitleri ve yanıt ayrıştırma/temizleme
/// yardımcıları. Asıl AI promptları artık worker.js içinde, sunucu
/// tarafında tutuluyor — burada sadece "worker ne döndürdü, bunu nasıl
/// yorumlayıp temiz koda çeviririz" mantığı var.
///
/// ÖNEMLİ: sentinel/mesaj sabitleri worker.js ile TEXTUAL olarak birebir
/// aynı tutulmalı — biri değişirse diğeri de güncellenmeli.
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
