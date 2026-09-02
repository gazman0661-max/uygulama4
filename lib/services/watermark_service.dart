import 'dart:convert';

import '../config/app_config.dart';

/// Üretilen sitelerin altına "Sitora ile üretildi" rozetini eklemekten
/// sorumlu tek/merkezi servis.
///
/// NEDEN MERKEZİ: Site içeriği iki farklı yoldan gelebiliyor (form akışı
/// tek sayfa, form akışı çok sayfa) — bu servis her birine AYNI mantıkla
/// uygulanır (bkz. AppState.updateQtGeneratedCode / updateQtGeneratedFiles),
/// böylece "bir yolu unutup rozetsiz site yayınlama" riski oluşmaz.
///
/// ÖDEME MODELİ: site bazlı, tek seferlik satın alma. Her SiteProject kendi
/// `watermarkRemoved` bayrağını taşır (bkz. AppState.currentHasBranding /
/// qtCurrentHasBranding — çağrı noktaları buradan okur). Bir proje için
/// satın alma tamamlandığında AppState.removeWatermarkForProject hem
/// bayrağı işaretler hem de [strip]/[stripFromFiles] ile o projede ZATEN
/// gömülü olan rozeti geriye dönük temizler; diğer projeler etkilenmez.
class WatermarkService {
  WatermarkService._();

  /// İçerikte rozetin zaten eklenip eklenmediğini anlamak için kullanılan
  /// gizli işaretleyici. Mevcut kodun tekrar bu servise gönderilmesi
  /// durumunda ÇİFT ROZET eklenmesini engeller.
  ///
  /// KASITLI OLARAK OKUNAKLI DEĞİL: Eskiden burada `<!--SITORA_WATERMARK-->`
  /// gibi düz/açıklayıcı bir yorum vardı. Sorun şu: APK decompile edilip bu
  /// string bulununca "Sitora rozeti nasıl kaldırılır" diye otomatik bir
  /// script/tarayıcı eklentisi yazmak çok kolaylaşıyor — tek bir string arat,
  /// sil, bitti. Onun yerine anlamsız/rastgele görünen bir işaretleyici
  /// kullanıyoruz; hâlâ HTML yorumu (idempotency kontrolü ve satın alma
  /// sonrası [strip] için işlevsel olarak aynı şekilde çalışır) ama "sitora"
  /// veya "watermark" kelimelerini İÇERMEZ, bu yüzden ctrl+F / grep ile
  /// tahmin edilerek bulunması zorlaşır.
  static const String _marker = '<!--k9x2-4qz7-vt31-->';

  /// Rozet metni uygulama diline göre değişir; marker (idempotency
  /// işaretleyicisi) her iki dilde de AYNI kalır — böylece bir dilde
  /// eklenmiş rozet, dil değişse bile ikinci kez eklenmez (üstüne
  /// yazılmaz da; zaten üretilmiş bir siteyi geriye dönük değiştirmiyoruz,
  /// sadece YENİ üretimlerde o anki dil kullanılıyor).
  static const String _badgeTextTr = 'Sitora ile üretildi — kullanıcı ürünüdür';
  static const String _badgeTextEn = 'Made with Sitora — user-generated content';

  /// Rozet artık statik bir `<div>` olarak HTML'e GÖMÜLMÜYOR — bunun yerine
  /// sayfa yüklenince DOM'a kod ile ekleyen küçük bir `<script>` bloğu
  /// yazılıyor. İKİ SEBEP:
  ///
  /// 1) Statik `<div>Sitora ile üretildi</div>` bir metin editöründe
  ///    view-source açıp görsel olarak bulunup elle silinebiliyordu — hiç
  ///    teknik bilgi gerektirmiyordu. JS ile enjekte edilince kaldırmak için
  ///    kullanıcının script bloğunu bulup silmesi (ya da JS'i devre dışı
  ///    bırakması) gerekiyor, bariyer teknik bilgi ister.
  /// 2) Rozet METNİ ("Sitora ile üretildi") artık ham HTML içinde düz metin
  ///    olarak da GEÇMİYOR — base64 ile kodlanıp script içinde atob() ile
  ///    çözülüyor. Yani ham dosyada ctrl+F ile "Sitora" aratan biri de
  ///    metni bulamaz; rozet sadece TARAYICIDA render edilince görünür
  ///    (ki zaten amaç bu — kullanıcının görmesi, dosyayı karıştıranın
  ///    kolayca silmesi değil).
  ///
  /// NOT: Bu "kırılmaz" bir koruma değil — JS'i devre dışı bırakan ya da
  /// script'i bulup silen teknik bir kullanıcıyı durduramaz. Amaç, ortalama
  /// kullanıcının 2 saniyede view-source'tan silmesini imkansızlaştırmak.
  ///
  /// 31.08.2026 eklendi — rozet artık TIKLANABİLİR: ziyaretçi rozete
  /// dokununca [AppConfig.playStoreUrl] (Sitora'nın Play Store sayfası)
  /// yeni sekmede açılır. Bu, yayınlanan her sitenin (potansiyel olarak
  /// binlerce ziyaretçiye ulaşan) kendisini organik bir kullanıcı edinim
  /// kanalına çevirmesini sağlar. Rozet metni ile aynı base64+atob
  /// gizleme deseni URL için de uygulanır — ham HTML'de "play.google.com"
  /// düz metin olarak GEÇMEZ, sadece script çalışınca çözülür.
  static String _badgeScript(bool isEnglish) {
    final text = isEnglish ? _badgeTextEn : _badgeTextTr;
    final encoded = base64Encode(utf8.encode(text));
    final encodedUrl = base64Encode(utf8.encode(AppConfig.playStoreUrl));
    // NOT (19.08.2026 düzeltmesi): Daha önce metin sadece `atob(encoded)`
    // ile çözülüyordu. atob() base64'ü BYTE-BYTE (Latin-1) bir string'e
    // çevirir, UTF-8 çok baytlı karakterleri (ü, ı, ş, ö, ç, — gibi) DOĞRU
    // ÇÖZMEZ. Sonuç: "üretildi" yerine "Ã¼retildi" gibi bozuk (mojibake)
    // metin görünüyordu. Düzeltme: atob()'un ham bayt string'ini
    // Uint8Array'e çevirip TextDecoder('utf-8') ile gerçek UTF-8 olarak
    // çözüyoruz — Türkçe karakterler artık doğru render edilir.
    return '''
$_marker
<script>(function(){try{var bin=atob("$encoded");var bytes=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++){bytes[i]=bin.charCodeAt(i);}var t=new TextDecoder("utf-8").decode(bytes);var url=atob("$encodedUrl");var a=document.createElement("a");a.href=url;a.target="_blank";a.rel="noopener noreferrer";a.textContent=t;a.style.cssText="position:fixed;bottom:10px;right:10px;z-index:999999;font-family:Arial,Helvetica,sans-serif;font-size:11px;line-height:1;background:rgba(17,17,17,.72);color:#fff;padding:6px 12px;border-radius:999px;text-decoration:none;cursor:pointer;user-select:none;box-shadow:0 2px 6px rgba(0,0,0,.25)";(document.body||document.documentElement).appendChild(a);}catch(e){}})();</script>''';
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

    final badge = _badgeScript(isEnglish);
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

  /// Rozeti DAHA ÖNCE üretilmiş bir HTML'den geriye dönük olarak temizler.
  ///
  /// NEDEN GEREKLİ: [apply] üretim ANINDA çağrılır ve rozeti doğrudan HTML
  /// string'inin içine gömer — ayrı bir katman/overlay değildir. Bir kullanıcı
  /// "rozeti kaldır"ı SONRADAN satın aldığında (bkz. AppState.
  /// removeWatermarkForProject), o projenin `code`/`files` alanlarında zaten
  /// gömülü olan rozeti bu fonksiyon çıkarır. [_marker] ile başlayıp bir
  /// sonraki `</script>` ile biten bloğu (aradaki satır sonu dahil) siler —
  /// [_badgeScript] tarafından üretilen yapıyla birebir eşleşir. Marker
  /// bulunamazsa (rozet hiç eklenmemişse) içerik AYNEN döner.
  static String strip(String html) {
    if (!html.contains(_marker)) return html;
    final markerIndex = html.indexOf(_marker);
    final closeScriptIndex = html.indexOf('</script>', markerIndex);
    if (closeScriptIndex == -1) return html;
    final blockEnd = closeScriptIndex + '</script>'.length;
    // apply() rozetten hemen sonra tek bir '\n' ekliyor; varsa onu da al.
    final trailingNewline =
        html.startsWith('\n', blockEnd) ? blockEnd + 1 : blockEnd;
    return html.substring(0, markerIndex) + html.substring(trailingNewline);
  }

  /// [strip]'in çok sayfa (dosya haritası) karşılığı — yalnızca `.html`
  /// dosyalarına dokunur.
  static Map<String, String> stripFromFiles(Map<String, String> files) {
    return files.map((name, content) {
      if (name.toLowerCase().endsWith('.html')) {
        return MapEntry(name, strip(content));
      }
      return MapEntry(name, content);
    });
  }
}
