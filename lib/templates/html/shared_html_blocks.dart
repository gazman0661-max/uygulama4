/// Ortak HTML blok üreticileri.
///
/// Her fonksiyon, ilgili Flutter widget paketindeki (kuafor_site_template,
/// beauty_salon_template, vb.) görsel tasarımın HTML/CSS karşılığıdır.
/// Uzak sunucu çağrısı YOKTUR — tamamen yerel string birleştirme.
///
/// Bu dosya business_site_html_generator.dart ve diğer sektör
/// generator'ları tarafından import edilir. Yeni bir sektör eklerken
/// önce burada eksik bir blok var mı bak, varsa reuse et.
library shared_html_blocks;

import '../../config/app_config.dart';

/// Üretilen SİTE İÇERİĞİNDEKİ sabit etiketler (kullanıcının kendi yazdığı
/// isim/açıklama/menü metinleri DEĞİL — "Menü", "Galeri", "Konum" gibi
/// generator'ların kendi bastığı başlık/buton metinleri).
///
/// app_strings.dart'taki çeviri sistemi SADECE uygulama arayüzü içindir ve
/// üretilen HTML'i etkilemez — bu yüzden site içeriğini de çok dilli
/// yapmak için ayrı, küçük bir sözlük burada tutuluyor. Yeni bir key
/// eklerken hem 'tr' hem 'en' bloğuna eklemeyi unutma.
Map<String, String> siteLabels(String lang) {
  if (lang == 'en') {
    return const {
      'home': 'Home',
      'menu': 'Menu',
      'gallery': 'Gallery',
      'location': 'Location',
      'hours': 'Working Hours',
      'contact': 'Contact',
      'about': 'About',
      'closed': 'Closed',
      'directions': 'Get Directions',
      'call': 'Call',
      'reservation': 'Reservation',
      'reservationOrder': 'Reservation / Order',
      'menuHighlights': 'From the Menu',
      'viewFullMenu': 'View Full Menu',
      'openDigitalMenu': '📱 Open Digital Menu',
      'goToMenu': 'View Menu',
      // === Talep formu (bkz. leadFormBlockHtml) — 31.08.2026 eklendi ===
      'sendRequest': 'Send a Request',
      'yourName': 'Your Name',
      'yourPhone': 'Your Phone',
      'yourMessage': 'Your Message',
      'sendButton': 'Send',
      'sending': 'Sending…',
      'requestSent': 'Thank you! Your request has been sent.',
      'requestFailed': "Couldn't send, please try the phone/WhatsApp button above.",
      // === SSS / Yorumlar — 31.08.2026 eklendi ===
      'faqTitle': 'Frequently Asked Questions',
      'testimonialsTitle': 'What Our Customers Say',
      // === Canlı açık/kapalı rozeti + Google Yorum — 01.09.2026 eklendi ===
      'openNowLabel': 'Open Now',
      'closedNowLabel': 'Closed Now',
      'googleReviewButton': '⭐ Rate Us on Google',
    };
  }
  return const {
    'home': 'Ana Sayfa',
    'menu': 'Menü',
    'gallery': 'Galeri',
    'location': 'Konum',
    'hours': 'Çalışma Saatleri',
    'contact': 'İletişim',
    'about': 'Hakkında',
    'closed': 'Kapalı',
    'directions': 'Yol Tarifi Al',
    'call': 'Ara',
    'reservation': 'Rezervasyon',
    'reservationOrder': 'Rezervasyon / Sipariş',
    'menuHighlights': 'Menüden Öne Çıkanlar',
    'viewFullMenu': 'Tüm Menüyü Gör',
    'openDigitalMenu': '📱 Dijital Menüyü Aç',
    'goToMenu': 'Menüyü Gör',
    // === Talep formu (bkz. leadFormBlockHtml) — 31.08.2026 eklendi ===
    'sendRequest': 'Talep Gönder',
    'yourName': 'Adınız',
    'yourPhone': 'Telefonunuz',
    'yourMessage': 'Mesajınız',
    'sendButton': 'Gönder',
    'sending': 'Gönderiliyor…',
    'requestSent': 'Teşekkürler! Talebiniz iletildi.',
    'requestFailed': 'Gönderilemedi, lütfen yukarıdaki telefon/WhatsApp butonunu kullanın.',
    // === SSS / Yorumlar — 31.08.2026 eklendi ===
    'faqTitle': 'Sıkça Sorulan Sorular',
    'testimonialsTitle': 'Müşterilerimiz Ne Diyor',
    // === Canlı açık/kapalı rozeti + Google Yorum — 01.09.2026 eklendi ===
    'openNowLabel': 'Şu An Açık',
    'closedNowLabel': 'Şu An Kapalı',
    'googleReviewButton': '⭐ Bizi Google\'da Değerlendirin',
  };
}

/// generateBusinessSiteHtml (kuafor_html_generator.dart) tek bir genel
/// fonksiyon olup kuaför, oto yıkama, temizlik şirketi, sürücü kursu,
/// çiçekçi, tadilatçı (handyman), masaj/spa, nakliyat, evcil hayvan bakımı
/// ve terzi sektörleri tarafından PAYLAŞILIYOR — her sektör sadece
/// "Hizmetlerimiz" başlığı ve CTA (Randevu Al / Teklif Al vb.) metnini
/// kendine göre override ediyor. Bu sektöre özel metinlerin TR/EN
/// karşılıkları TEK YERDEN buradan gelir; yeni bir sektör eklerken sadece
/// yeni bir key eklemek yeterli.
Map<String, String> businessSectorLabels(String sectorKey, String lang) {
  const table = <String, Map<String, Map<String, String>>>{
    'default': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Randevu Al'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Book Now'},
    },
    'carWash': {
      'tr': {'servicesTitle': 'Yıkama & Bakım Paketleri', 'ctaText': 'Randevu Al'},
      'en': {'servicesTitle': 'Wash & Care Packages', 'ctaText': 'Book Now'},
    },
    'cleaningCompany': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Teklif Al'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Get a Quote'},
    },
    'drivingSchool': {
      'tr': {'servicesTitle': 'Kurslarımız', 'ctaText': 'Kayıt Ol'},
      'en': {'servicesTitle': 'Our Courses', 'ctaText': 'Enroll Now'},
    },
    'florist': {
      'tr': {'servicesTitle': 'Ürünlerimiz', 'ctaText': 'Sipariş Ver'},
      'en': {'servicesTitle': 'Our Products', 'ctaText': 'Order Now'},
    },
    'handyman': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Hemen Ara'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Call Now'},
    },
    'massageSpa': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Randevu Al'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Book Now'},
    },
    'movingCompany': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Teklif Al'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Get a Quote'},
    },
    'petGrooming': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Randevu Al'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Book Now'},
    },
    'tailor': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Randevu Al'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Book Now'},
    },
    'autoRepair': {
      'tr': {'servicesTitle': 'Bakım & Onarım Hizmetlerimiz', 'ctaText': 'Randevu Al'},
      'en': {'servicesTitle': 'Repair & Maintenance Services', 'ctaText': 'Book Now'},
    },
    'electrician': {
      'tr': {'servicesTitle': 'Hizmetlerimiz', 'ctaText': 'Hemen Ara'},
      'en': {'servicesTitle': 'Our Services', 'ctaText': 'Call Now'},
    },
    'kindergarten': {
      'tr': {'servicesTitle': 'Programlarımız', 'ctaText': 'Kayıt Ol'},
      'en': {'servicesTitle': 'Our Programs', 'ctaText': 'Enroll Now'},
    },
    'boutiqueHotel': {
      'tr': {'servicesTitle': 'Odalarımız', 'ctaText': 'Rezervasyon Yap'},
      'en': {'servicesTitle': 'Our Rooms', 'ctaText': 'Book Now'},
    },
    'furnitureStore': {
      'tr': {'servicesTitle': 'Ürün Kategorilerimiz', 'ctaText': 'Teklif Al'},
      'en': {'servicesTitle': 'Our Product Categories', 'ctaText': 'Get a Quote'},
    },
  };
  final entry = table[sectorKey] ?? table['default']!;
  return entry[lang] ?? entry['tr']!;
}

/// Basit HTML escape — kullanıcı girdisi (isim, açıklama vb.) doğrudan
/// HTML'e basılmadan önce MUTLAKA bu fonksiyondan geçmeli.
String escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Hero (üst kapak) bölümü. Tüm sektör şablonlarında ilk bölüm budur.
/// Çok sayfalı sitelerde (kafe: ana sayfa/menü/galeri, klinik: hizmetler/
/// hekimler, portfolyo: anasayfa/proje detay vb.) sayfalar arası basit üst
/// navigasyon. `active` o an render edilen dosya adıyla eşleşen linki
/// vurgular. Tek sayfalı generator'lar bu fonksiyonu hiç çağırmaz.
String siteNavHtml({
  required List<Map<String, String>> links, // {label, href}
  required String active,
}) {
  final items = links.map((l) {
    final isActive = l['href'] == active;
    return '<a class="site-nav-link${isActive ? ' active' : ''}" href="${escapeHtml(l['href']!)}">${escapeHtml(l['label']!)}</a>';
  }).join('\n    ');
  return '''
<nav class="site-nav">
  <div class="site-nav-inner">
    $items
  </div>
</nav>''';
}

/// [layoutStyle] 'centered' (varsayılan, ortalanmış klasik hero) veya
/// 'editorial' (sola yaslı, asimetrik, üstte vurgu çizgili düzen).
/// CSS karşılıkları wrapPageHtml'deki ortak <style> bloğunda.
String heroBlockHtml({
  required String name,
  required String tagline,
  required String coverImage,
  String? logoImage,
  String ctaText = 'Randevu Al',
  String? ctaHref,
  String layoutStyle = 'centered',
}) {
  final logoHtml = logoImage != null
      ? '<img class="hero-logo" src="${escapeHtml(logoImage)}" alt="logo">'
      : '';
  final ctaHtml = ctaHref != null
      ? '<a class="hero-cta" href="${escapeHtml(ctaHref)}">${escapeHtml(ctaText)}</a>'
      : '';
  final overlayClass = layoutStyle == 'editorial' ? 'hero-overlay editorial' : 'hero-overlay';
  return '''
<section class="hero" style="background-image:url('${escapeHtml(coverImage)}')">
  <div class="$overlayClass reveal">
    $logoHtml
    <h1 class="hero-title">${escapeHtml(name)}</h1>
    <p class="hero-tagline">${escapeHtml(tagline)}</p>
    $ctaHtml
  </div>
</section>''';
}

/// Hizmet listesi bloğu (ad + opsiyonel süre + fiyat).
/// Kuaför, oto yıkama, klinik gibi sektörlerde kullanılır.
String serviceListBlockHtml({
  required String title,
  required List<Map<String, String?>> services, // name, duration, price
}) {
  final rows = services.map((s) {
    final durationHtml = s['duration'] != null
        ? '<span class="service-duration">${escapeHtml(s['duration']!)}</span>'
        : '';
    return '''
    <li class="service-row">
      <span class="service-name">${escapeHtml(s['name'] ?? '')}</span>
      $durationHtml
      <span class="service-price">${escapeHtml(s['price'] ?? '')}</span>
    </li>''';
  }).join('\n');

  return '''
<section class="section services-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <ul class="service-list">
$rows
  </ul>
</section>''';
}

/// Galeri bloğu. [style] 'grid' (varsayılan, ızgara + lightbox) veya
/// 'slideshow' (yatay kaydırmalı carousel, saf CSS scroll-snap — JS
/// kütüphanesi gerekmez) olabilir. Bilinmeyen bir değer 'grid'e düşer.
/// Otomatik oynatma BİLEREK yok — kullanıcı deneyimini rahatsız eder,
/// elle kaydırma yeterli.
String galleryBlockHtml({
  required String title,
  required List<Map<String, String?>> images, // url, caption
  bool beforeAfter = false,
  String style = 'grid',
}) {
  if (style == 'slideshow') {
    return _gallerySlideshowBlockHtml(title: title, images: images);
  }

  final items = images.map((img) {
    final caption = img['caption'] != null
        ? '<span class="gallery-caption">${escapeHtml(img['caption']!)}</span>'
        : '';
    return '''
    <div class="gallery-item" onclick="document.getElementById('${_idFor(img['url'] ?? '')}').classList.add('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="">
      $caption
    </div>
    <div class="gallery-lightbox" id="${_idFor(img['url'] ?? '')}" onclick="this.classList.remove('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="">
    </div>''';
  }).join('\n');

  return '''
<section class="section gallery-section${beforeAfter ? ' before-after' : ''}">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="gallery-grid">
$items
  </div>
</section>''';
}

/// Yatay kaydırılan slayt gösterisi — CSS `scroll-snap-type` ile, JS
/// kütüphanesi olmadan. Altta, kaç görsel olduğunu gösteren noktalar
/// (dot indicator) vardır; noktalara tıklamak ilgili slayta kaydırır.
/// Tıklanan görsel tam ekran lightbox'ta açılır (grid moduyla aynı davranış).
String _gallerySlideshowBlockHtml({
  required String title,
  required List<Map<String, String?>> images,
}) {
  final slides = <String>[];
  final dots = <String>[];
  final lightboxes = <String>[];
  for (var i = 0; i < images.length; i++) {
    final img = images[i];
    final slideId = 'gslide_$i';
    final caption = img['caption'] != null
        ? '<span class="gallery-caption">${escapeHtml(img['caption']!)}</span>'
        : '';
    slides.add('''
    <div class="gallery-slide" id="$slideId" onclick="document.getElementById('${_idFor(img['url'] ?? '')}').classList.add('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="" loading="lazy">
      $caption
    </div>''');
    dots.add(
      '<a href="#$slideId" class="gallery-dot" aria-label="${i + 1}"></a>',
    );
    lightboxes.add('''
    <div class="gallery-lightbox" id="${_idFor(img['url'] ?? '')}" onclick="this.classList.remove('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="">
    </div>''');
  }

  return '''
<section class="section gallery-section gallery-section-slideshow">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="gallery-slideshow">
${slides.join('\n')}
  </div>
  <div class="gallery-dots">
${dots.join('\n')}
  </div>
${lightboxes.join('\n')}
</section>''';
}

String _idFor(String url) => 'gal_${url.hashCode.abs()}';

/// Türkçe gün adı -> JS `Date.getDay()` değeri (0=Pazar...6=Cumartesi).
/// [WorkingHoursPickerField] her zaman bu Türkçe gün adlarını üretir
/// (bkz. lib/widgets/working_hours_picker_field.dart), üretilen sitenin
/// dili ('lang') ne olursa olsun ham veri hep Türkçe gelir — bu yüzden
/// burada da sabit Türkçe anahtar kullanılıyor.
const Map<String, int> _turkishDayToJsWeekday = {
  'Pazar': 0,
  'Pazartesi': 1,
  'Salı': 2,
  'Çarşamba': 3,
  'Perşembe': 4,
  'Cuma': 5,
  'Cumartesi': 6,
};

/// Çalışma saatleri tablosu + (01.09.2026 eklendi) ziyaretçinin KENDİ
/// cihaz saatine göre hesaplanan canlı "Şu An Açık / Kapalı" rozeti.
///
/// Rozet tamamen istemci tarafında (JS) hesaplanır — sunucu/worker
/// tarafında hiçbir değişiklik gerekmez, ekstra ağ isteği atmaz. [hours]
/// içindeki "09:00 - 19:00" gibi aralıklar aynı günün içinde bitiyor
/// varsayılır (gece yarısını geçen vardiyalar — örn. bir bar için
/// "22:00 - 02:00" — şu anda desteklenmiyor; bu durumda rozet o gün için
/// "Kapalı" gösterebilir, tabloda doğru aralık yine de görünür).
String workingHoursBlockHtml({
  required String title,
  required List<Map<String, String?>> hours, // day, range (null = kapalı)
  String lang = 'tr',
  bool showLiveBadge = true,
}) {
  final labels = siteLabels(lang);
  final closedText = labels['closed']!;
  final rows = hours.map((h) {
    final range = h['range'] ?? closedText;
    return '''
    <tr>
      <td>${escapeHtml(h['day'] ?? '')}</td>
      <td>${escapeHtml(range)}</td>
    </tr>''';
  }).join('\n');

  final badgeId = 'hours-status-${title.hashCode.abs()}';
  var badgeHtml = '';
  var badgeScript = '';
  if (showLiveBadge) {
    badgeHtml = '<span id="$badgeId" class="hours-status-badge"></span>';
    final entries = <String>[];
    for (final h in hours) {
      final jsDay = _turkishDayToJsWeekday[h['day']];
      final range = h['range'];
      if (jsDay == null || range == null) continue;
      final parts = range.split('-').map((p) => p.trim()).toList();
      if (parts.length != 2) continue;
      entries.add('"$jsDay":{"start":${_jsStringLiteral(parts[0])},"end":${_jsStringLiteral(parts[1])}}');
    }
    badgeScript = '''
  <script>
  (function(){
    var badge = document.getElementById(${_jsStringLiteral(badgeId)});
    if (!badge) return;
    var hoursMap = {${entries.join(',')}};
    var toMin = function(s){ var p = s.split(':'); return (parseInt(p[0],10)*60) + parseInt(p[1]||'0',10); };
    var now = new Date();
    var today = hoursMap[String(now.getDay())];
    var isOpen = false;
    if (today) {
      var cur = (now.getHours()*60) + now.getMinutes();
      isOpen = cur >= toMin(today.start) && cur < toMin(today.end);
    }
    badge.textContent = isOpen ? ${_jsStringLiteral(labels['openNowLabel'])} : ${_jsStringLiteral(labels['closedNowLabel'])};
    badge.className = 'hours-status-badge ' + (isOpen ? 'is-open' : 'is-closed');
  })();
  </script>''';
  }

  return '''
<section class="section hours-section">
  <h2 class="section-title">${escapeHtml(title)} $badgeHtml</h2>
  <table class="hours-table">
$rows
  </table>
  $badgeScript
</section>''';
}

/// Harita bloğu — Google Maps embed iframe (API key gerektirmez).
String mapBlockHtml({
  required String title,
  required String address,
  required double lat,
  required double lng,
  String lang = 'tr',
}) {
  return '''
<section class="section map-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <p class="address-text">${escapeHtml(address)}</p>
  <div class="map-embed">
    <iframe
      width="100%" height="300" style="border:0" loading="lazy"
      src="https://maps.google.com/maps?q=$lat,$lng&z=15&output=embed">
    </iframe>
  </div>
  <a class="directions-link" target="_blank"
     href="https://www.google.com/maps/dir/?api=1&destination=$lat,$lng">
     ${siteLabels(lang)['directions']}
  </a>
</section>''';
}

/// İletişim bloğu — telefon / WhatsApp / Instagram butonları.
/// [includeLeadForm] true ise (varsayılan) bu bloğa ayrıca bir "Talep
/// Gönder" formu eklenir (bkz. [leadFormMarkup]). Form, sitenin
/// YAYINLANMA anında (bkz. services/hosting_service.dart >
/// _injectLeadConfig) sayfaya enjekte edilen `window.__SITORA_LEAD__`
/// konfigürasyonunu okuyup Firestore'a (leads koleksiyonu) yazar —
/// böylece işletme sahibi Sitora uygulaması içinde "Gelen Talepler"
/// ekranından bu talepleri görebilir (bkz. screens/lead_inbox_screen.dart).
/// Site henüz yayınlanmadıysa (önizleme/indirilmiş kopya) config yok
/// demektir — form yine görünür ama Firestore kuralları boş ownerId/siteId
/// içeren yazmayı reddeder, kullanıcıya "gönderilemedi" mesajı + yukarıdaki
/// telefon/WhatsApp butonlarına yönlendirme gösterilir. Mevcut tel:/wa.me
/// butonları HİÇ değişmedi — bu form onların YANINA ekleniyor, yerine değil.
String contactBlockHtml({
  required String title,
  String? phone,
  String? whatsapp,
  String? instagram,
  // 01.09.2026 eklendi — kullanıcının Google İşletme Profili'ndeki
  // "yorum yaz" linki (örn. https://g.page/r/xxxxx/review). Doluysa
  // diğer iletişim butonlarının yanına "⭐ Bizi Google'da Değerlendirin"
  // butonu eklenir; boş/null ise hiçbir şey değişmez (geriye dönük
  // uyumlu — mevcut hiçbir çağrı noktasını bozmaz).
  String? googleReviewLink,
  String lang = 'tr',
  bool includeLeadForm = true,
  String siteName = '',
}) {
  final labels = siteLabels(lang);
  final callText = labels['call']!;
  final buttons = <String>[];
  if (phone != null) {
    buttons.add('<a class="contact-btn phone" href="tel:${escapeHtml(phone)}">📞 $callText</a>');
  }
  if (whatsapp != null) {
    buttons.add('<a class="contact-btn whatsapp" target="_blank" href="https://wa.me/${escapeHtml(whatsapp)}">💬 WhatsApp</a>');
  }
  if (instagram != null) {
    buttons.add('<a class="contact-btn instagram" target="_blank" href="https://instagram.com/${escapeHtml(instagram)}">📷 Instagram</a>');
  }
  if (googleReviewLink != null && googleReviewLink.trim().isNotEmpty) {
    buttons.add('<a class="contact-btn review" target="_blank" href="${escapeHtml(googleReviewLink.trim())}">${escapeHtml(labels['googleReviewButton']!)}</a>');
  }
  final leadForm = includeLeadForm ? leadFormMarkup(lang: lang, siteName: siteName) : '';
  return '''
<section class="section contact-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="contact-buttons">
    ${buttons.join('\n    ')}
  </div>
  $leadForm
</section>''';
}

/// "Gelen Talepler" formunun HTML + JS'i — bkz. [contactBlockHtml] dokümanı.
/// Ayrı bir fonksiyon olarak dışa açık: ileride tek başına (örn. bio_link
/// veya business_card şablonlarında) da kullanılabilsin diye.
String leadFormMarkup({String lang = 'tr', String siteName = ''}) {
  final l = siteLabels(lang);
  return '''
  <form id="sitora-lead-form" class="sitora-lead-form" onsubmit="return false;">
    <input id="sitora-lead-name" type="text" placeholder="${escapeHtml(l['yourName']!)}" required>
    <input id="sitora-lead-phone" type="tel" placeholder="${escapeHtml(l['yourPhone']!)}" required>
    <textarea id="sitora-lead-message" placeholder="${escapeHtml(l['yourMessage']!)}" rows="3"></textarea>
    <button type="submit" id="sitora-lead-submit">${escapeHtml(l['sendButton']!)}</button>
    <p id="sitora-lead-status" class="sitora-lead-status" aria-live="polite"></p>
  </form>
  <script>
  (function(){
    var form = document.getElementById('sitora-lead-form');
    if (!form) return;
    var btn = document.getElementById('sitora-lead-submit');
    var status = document.getElementById('sitora-lead-status');
    var LBL_SEND = ${_jsStringLiteral(l['sendButton'])};
    var LBL_SENDING = ${_jsStringLiteral(l['sending'])};
    var LBL_OK = ${_jsStringLiteral(l['requestSent'])};
    var LBL_FAIL = ${_jsStringLiteral(l['requestFailed'])};
    var SITE_NAME = ${_jsStringLiteral(siteName)};
    // 03.09.2026 değişti — form artık Firestore'a DOĞRUDAN yazmıyor (bu,
    // ziyaretçi uygulamayı görmese/kapatsa bile sitesahibine ANLIK push
    // bildirimi gönderilmesini engelliyordu — sadece uygulama açıkken
    // Firestore stream'i dinlendiği için). Bunun yerine Worker'daki
    // /api/leads ucuna POST ediyor; Worker hem Firestore'a yazıyor HEM DE
    // aynı anda site sahibine GERÇEK bir FCM push bildirimi tetikliyor
    // (bkz. cloudflare/worker/src/index.mjs > handleLeadCreate).
    // 03.09.2026 düzeltildi — mutlak workers.dev URL'i yerine RELATIVE
    // path kullanılıyor (tıpkı /api/hit ve /api/report gibi, bkz.
    // hosting_service.dart > visitorTrackerSnippet). Mutlak URL, "kendi
    // domainimi bağla" ile yayınlanmış sitelerde (örn. ahmetkuafor.com)
    // tarayıcı için CROSS-ORIGIN bir istek anlamına geliyordu ve Worker
    // hiçbir Access-Control-Allow-Origin header'ı döndürmediği için CORS
    // tarafından SESSİZCE engelleniyordu — talep formu böyle sitelerde
    // hiç çalışmıyordu. Relative path, hem /s/slug/ modunda hem bağlı
    // custom domain'de (Cloudflare for SaaS aynı Worker'a yönlendirdiği
    // için) her zaman AYNI origin'e gider, CORS hiç devreye girmez.
    form.addEventListener('submit', function(e){
      e.preventDefault();
      var cfg = window.__SITORA_LEAD__ || {};
      var name = document.getElementById('sitora-lead-name').value.trim();
      var phone = document.getElementById('sitora-lead-phone').value.trim();
      var message = document.getElementById('sitora-lead-message').value.trim();
      if (!name || !phone) return;
      btn.disabled = true;
      status.textContent = LBL_SENDING;
      var body = {
        ownerUid: cfg.ownerUid || '',
        siteId: cfg.siteId || '',
        siteName: cfg.siteName || SITE_NAME || '',
        name: name,
        phone: phone,
        message: message
      };
      fetch('/api/leads', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      }).then(function(res){
        btn.disabled = false;
        if (res.ok) {
          status.textContent = LBL_OK;
          form.reset();
        } else {
          status.textContent = LBL_FAIL;
        }
      }).catch(function(){
        btn.disabled = false;
        status.textContent = LBL_FAIL;
      });
    });
  })();
  </script>''';
}

/// SSS (FAQ) bloğu — native `<details>/<summary>` akordeon (JS gerekmez,
/// her tarayıcı/AI botu tarafından okunabilir) + arama motorları için
/// JSON-LD FAQPage şeması. [faqs] boşsa hiçbir şey render edilmez.
String faqBlockHtml({
  required List<Map<String, String>> faqs, // {question, answer}
  String lang = 'tr',
  String? title,
}) {
  if (faqs.isEmpty) return '';
  final heading = title ?? siteLabels(lang)['faqTitle']!;
  final items = faqs.map((f) {
    final q = f['question'] ?? '';
    final a = f['answer'] ?? '';
    if (q.trim().isEmpty || a.trim().isEmpty) return '';
    return '''
    <details class="faq-item">
      <summary class="faq-question">${escapeHtml(q)}</summary>
      <div class="faq-answer">${escapeHtml(a)}</div>
    </details>''';
  }).where((s) => s.isNotEmpty).join('\n');
  if (items.isEmpty) return '';

  final ldJsonEntities = faqs
      .where((f) => (f['question'] ?? '').trim().isNotEmpty && (f['answer'] ?? '').trim().isNotEmpty)
      .map((f) => '''{
      "@type": "Question",
      "name": ${_jsStringLiteral(f['question'])},
      "acceptedAnswer": { "@type": "Answer", "text": ${_jsStringLiteral(f['answer'])} }
    }''')
      .join(',\n    ');

  return '''
<section class="section faq-section">
  <h2 class="section-title">${escapeHtml(heading)}</h2>
  <div class="faq-list">
$items
  </div>
</section>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    $ldJsonEntities
  ]
}
</script>''';
}

/// Müşteri yorumları (testimonial) bloğu. [testimonials] boşsa hiçbir şey
/// render edilmez. `rating` verilmezse (veya 0/geçersizse) yıldız satırı
/// hiç basılmaz — üretilmemiş bir puanı göstermek yanıltıcı olur.
String testimonialBlockHtml({
  required List<Map<String, dynamic>> testimonials, // {name, text, rating?}
  String lang = 'tr',
  String? title,
}) {
  if (testimonials.isEmpty) return '';
  final heading = title ?? siteLabels(lang)['testimonialsTitle']!;
  final cards = testimonials.map((t) {
    final name = (t['name'] ?? '').toString();
    final text = (t['text'] ?? '').toString();
    if (name.trim().isEmpty || text.trim().isEmpty) return '';
    final rating = int.tryParse('${t['rating'] ?? ''}') ?? 0;
    final stars = (rating >= 1 && rating <= 5)
        ? '<div class="testimonial-stars">${'★' * rating}${'☆' * (5 - rating)}</div>'
        : '';
    return '''
    <div class="testimonial-card">
      $stars
      <p class="testimonial-text">"${escapeHtml(text)}"</p>
      <p class="testimonial-name">— ${escapeHtml(name)}</p>
    </div>''';
  }).where((s) => s.isNotEmpty).join('\n');
  if (cards.isEmpty) return '';
  return '''
<section class="section testimonial-section">
  <h2 class="section-title">${escapeHtml(heading)}</h2>
  <div class="testimonial-grid">
$cards
  </div>
</section>''';
}

/// dart:convert'e bağımlı kalmamak için minik JSON string encoder — sadece
/// bu dosyanın ürettiği `<script>` bloklarındaki değişkenler için yeterli
/// (kaçış: ters bölü, tırnak, satır sonu, < karakteri script kapanışını
/// bozmasın diye).
String _jsStringLiteral(String? input) {
  final s = input ?? '';
  final buf = StringBuffer('"');
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case '\\':
        buf.write(r'\\');
        break;
      case '"':
        buf.write(r'\"');
        break;
      case '\n':
        buf.write(r'\n');
        break;
      case '\r':
        buf.write(r'\r');
        break;
      case '<':
        buf.write(r'\u003C');
        break;
      default:
        buf.write(ch);
    }
  }
  buf.write('"');
  return buf.toString();
}

/// Menü bloğu (kategori + ürün) — kafe/restoran için.
String menuBlockHtml({
  required String title,
  required List<Map<String, dynamic>> categories, // {title, items:[{name,description,price}]}
}) {
  final catHtml = categories.map((cat) {
    final items = (cat['items'] as List).map((item) {
      final desc = item['description'] != null && (item['description'] as String).isNotEmpty
          ? '<p class="menu-item-desc">${escapeHtml(item['description'])}</p>'
          : '';
      return '''
      <li class="menu-item">
        <div class="menu-item-main">
          <span class="menu-item-name">${escapeHtml(item['name'] ?? '')}</span>
          <span class="menu-item-price">${escapeHtml(item['price'] ?? '')}</span>
        </div>
        $desc
      </li>''';
    }).join('\n');
    return '''
    <div class="menu-category">
      <h3 class="menu-category-title">${escapeHtml(cat['title'] ?? '')}</h3>
      <ul class="menu-item-list">
$items
      </ul>
    </div>''';
  }).join('\n');

  return '''
<section class="section menu-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  $catHtml
</section>''';
}

/// Randevu formu bloğu — statik HTML'de gerçek backend olmadığı için
/// gönderince WhatsApp'a yönlendiren basit bir form (mailto/wa.me).
String randevuBlockHtml({
  required String title,
  required String whatsapp,
}) {
  return '''
<section class="section randevu-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <form class="randevu-form" onsubmit="event.preventDefault();
    const ad=document.getElementById('rv_ad').value;
    const tarih=document.getElementById('rv_tarih').value;
    const not=document.getElementById('rv_not').value;
    const msg=encodeURIComponent('Randevu talebi - Ad: '+ad+' Tarih: '+tarih+' Not: '+not);
    window.open('https://wa.me/${escapeHtml(whatsapp)}?text='+msg,'_blank');">
    <input id="rv_ad" placeholder="Ad Soyad" required>
    <input id="rv_tarih" placeholder="Tercih edilen tarih/saat" required>
    <textarea id="rv_not" placeholder="Not (opsiyonel)"></textarea>
    <button type="submit">Randevu Talebi Gönder</button>
  </form>
</section>''';
}

/// Paket/üyelik kartları — güzellik salonu ve fitness'ta kullanılır.
String packageCardsBlockHtml({
  required String title,
  required List<Map<String, dynamic>> packages, // {title, sessionLabel, price, originalPrice, includedServices:[], note, isFeatured}
}) {
  final cards = packages.map((p) {
    final featured = p['isFeatured'] == true ? ' featured' : '';
    final original = p['originalPrice'] != null
        ? '<span class="pkg-original-price">${escapeHtml(p['originalPrice'].toString())}</span>'
        : '';
    final included = (p['includedServices'] as List? ?? [])
        .map((s) => '<li>${escapeHtml(s.toString())}</li>')
        .join('\n');
    final note = p['note'] != null
        ? '<p class="pkg-note">${escapeHtml(p['note'].toString())}</p>'
        : '';
    return '''
    <div class="pkg-card$featured">
      <h3 class="pkg-title">${escapeHtml(p['title']?.toString() ?? '')}</h3>
      <p class="pkg-session">${escapeHtml(p['sessionLabel']?.toString() ?? '')}</p>
      <div class="pkg-price">$original<span>${escapeHtml(p['price']?.toString() ?? '')}</span></div>
      <ul class="pkg-included">$included</ul>
      $note
    </div>''';
  }).join('\n');

  return '''
<section class="section packages-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="pkg-grid">
$cards
  </div>
</section>''';
}

/// Ekip/eğitmen/uzman tanıtım kartları.
String teamBlockHtml({
  required String title,
  required List<Map<String, dynamic>> members, // {name, specialty, photoUrl, bio, tags:[]}
}) {
  final cards = members.map((m) {
    final tags = (m['tags'] as List? ?? [])
        .map((t) => '<span class="team-tag">${escapeHtml(t.toString())}</span>')
        .join('');
    final bio = m['bio'] != null
        ? '<p class="team-bio">${escapeHtml(m['bio'].toString())}</p>'
        : '';
    return '''
    <div class="team-card">
      <img class="team-photo" src="${escapeHtml(m['photoUrl']?.toString() ?? '')}" alt="">
      <h3 class="team-name">${escapeHtml(m['name']?.toString() ?? '')}</h3>
      <p class="team-specialty">${escapeHtml(m['specialty']?.toString() ?? '')}</p>
      $bio
      <div class="team-tags">$tags</div>
    </div>''';
  }).join('\n');

  return '''
<section class="section team-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="team-grid">
$cards
  </div>
</section>''';
}

/// Doktor/uzman tanıtım bloğu (klinik).
String practitionerBlockHtml({
  required String name,
  required String title,
  required String photoUrl,
  required String bio,
  required List<Map<String, String?>> credentials, // {label}
}) {
  final badges = credentials
      .map((c) => '<span class="cred-badge">${escapeHtml(c['label'] ?? '')}</span>')
      .join('\n');
  return '''
<section class="section practitioner-section">
  <img class="practitioner-photo" src="${escapeHtml(photoUrl)}" alt="">
  <h2 class="practitioner-name">${escapeHtml(name)}</h2>
  <p class="practitioner-title">${escapeHtml(title)}</p>
  <p class="practitioner-bio">${escapeHtml(bio)}</p>
  <div class="cred-badges">$badges</div>
</section>''';
}

/// Program tablosu (gün x saat) — fitness stüdyosu.
String scheduleTableBlockHtml({
  required String title,
  required List<Map<String, String?>> entries, // {day, time, className, trainer}
}) {
  final rows = entries.map((e) {
    final trainer = e['trainer'] != null ? ' — ${escapeHtml(e['trainer']!)}' : '';
    return '''
    <tr>
      <td>${escapeHtml(e['day'] ?? '')}</td>
      <td>${escapeHtml(e['time'] ?? '')}</td>
      <td>${escapeHtml(e['className'] ?? '')}$trainer</td>
    </tr>''';
  }).join('\n');

  return '''
<section class="section schedule-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <table class="schedule-table">
$rows
  </table>
</section>''';
}

/// Zaman çizelgesi (deneyim/eğitim) — portfolyo.
String timelineBlockHtml({
  required String title,
  required List<Map<String, String?>> entries, // {year, title, description}
}) {
  final items = entries.map((e) {
    return '''
    <div class="timeline-item">
      <span class="timeline-year">${escapeHtml(e['year'] ?? '')}</span>
      <div class="timeline-body">
        <h3>${escapeHtml(e['title'] ?? '')}</h3>
        <p>${escapeHtml(e['description'] ?? '')}</p>
      </div>
    </div>''';
  }).join('\n');

  return '''
<section class="section timeline-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="timeline">
$items
  </div>
</section>''';
}

/// Yetenek/uzmanlık etiketleri (chip listesi) — portfolyo.
String skillChipsBlockHtml(List<String> skills) {
  final chips = skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join('\n');
  return '<div class="skill-chips">\n$chips\n</div>';
}

/// İletişim formu — gönderince mailto: üzerinden e-postaya yönlendirir.
String contactFormBlockHtml({
  required String title,
  required String email,
  String lang = 'tr',
}) {
  final ph = lang == 'en'
      ? {'name': 'Full Name', 'email': 'Email', 'message': 'Your Message', 'send': 'Send', 'subject': 'Message from website - ', 'replyTo': 'Reply to: '}
      : {'name': 'Ad Soyad', 'email': 'E-posta', 'message': 'Mesajınız', 'send': 'Gönder', 'subject': 'Site üzerinden mesaj - ', 'replyTo': 'Cevap için: '};
  return '''
<section class="section contact-form-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <form class="contact-form" onsubmit="event.preventDefault();
    const ad=document.getElementById('cf_ad').value;
    const eposta=document.getElementById('cf_eposta').value;
    const mesaj=document.getElementById('cf_mesaj').value;
    window.location.href='mailto:${escapeHtml(email)}?subject='+encodeURIComponent('${ph['subject']}'+ad)+'&body='+encodeURIComponent(mesaj+'\\n\\n${ph['replyTo']}'+eposta);">
    <input id="cf_ad" placeholder="${ph['name']}" required>
    <input id="cf_eposta" type="email" placeholder="${ph['email']}" required>
    <textarea id="cf_mesaj" placeholder="${ph['message']}" required></textarea>
    <button type="submit">${ph['send']}</button>
  </form>
</section>''';
}

/// Emlak ilan kartı ızgarası (liste sayfası).
String propertyCardGridHtml({
  required List<Map<String, String?>> listings, // {id, title, coverImage, price, m2, roomLabel, locationTag, href}
}) {
  final cards = listings.map((l) {
    return '''
    <a class="property-card" href="${escapeHtml(l['href'] ?? '#')}">
      <img src="${escapeHtml(l['coverImage'] ?? '')}" alt="">
      <div class="property-card-body">
        <h3>${escapeHtml(l['title'] ?? '')}</h3>
        <p class="property-tags">${escapeHtml(l['roomLabel'] ?? '')} · ${escapeHtml(l['m2'] ?? '')} m² · ${escapeHtml(l['locationTag'] ?? '')}</p>
        <p class="property-price">${escapeHtml(l['price'] ?? '')}</p>
      </div>
    </a>''';
  }).join('\n');

  return '''
<div class="property-grid">
$cards
</div>''';
}

/// Emlak dışında da kullanılabilecek genel "iş/proje kartı" ızgarası —
/// portfolyo (fotoğrafçı, tasarımcı vb.) çok sayfa modunda her iş kendi
/// detay sayfasına gider. Aynı .property-card CSS sınıfını paylaşır,
/// ekstra stil eklemeye gerek kalmaz.
String simpleCardGridHtml({
  required List<Map<String, String?>> items, // {title, coverImage, caption, href}
}) {
  final cards = items.map((it) {
    return '''
    <a class="property-card" href="${escapeHtml(it['href'] ?? '#')}">
      <img src="${escapeHtml(it['coverImage'] ?? '')}" alt="">
      <div class="property-card-body">
        <h3>${escapeHtml(it['title'] ?? '')}</h3>
        ${(it['caption'] != null && it['caption']!.isNotEmpty) ? '<p class="property-tags">${escapeHtml(it['caption']!)}</p>' : ''}
      </div>
    </a>''';
  }).join('\n');

  return '''
<div class="property-grid">
$cards
</div>''';
}

/// Emlak ilan detay bilgi tablosu.
String propertyDetailsBlockHtml({
  required Map<String, String?> details, // {price, m2, roomLabel, floor, aidat}
  required String description,
}) {
  final rows = details.entries.where((e) => e.value != null).map((e) {
    return '<tr><td>${escapeHtml(e.key)}</td><td>${escapeHtml(e.value!)}</td></tr>';
  }).join('\n');

  return '''
<section class="section property-details-section">
  <table class="property-details-table">
$rows
  </table>
  <p class="property-description">${escapeHtml(description)}</p>
</section>''';
}

/// vCard indirme linki (data URI ile — sunucu gerekmez).
String vcardSectionHtml({
  required String name,
  required String title,
  required String? company,
  required String phone,
  required String? email,
  String lang = 'tr',
}) {
  final vcard = 'BEGIN:VCARD\\nVERSION:3.0\\nFN:$name\\nTITLE:$title\\n'
      '${company != null ? 'ORG:$company\\n' : ''}'
      'TEL:$phone\\n'
      '${email != null ? 'EMAIL:$email\\n' : ''}'
      'END:VCARD';
  final addToContactsText = lang == 'en' ? '📇 Add to Contacts' : '📇 Kişiye Ekle';
  return '''
<a class="vcard-btn" download="${escapeHtml(name)}.vcf"
   href="data:text/vcard;charset=utf-8,${Uri.encodeComponent(vcard)}">
   $addToContactsText
</a>''';
}

/// Hazır site temaları — Biyo Link ekranındaki 5 temayla (bkz.
/// bio_link_html_generator.dart) BİREBİR AYNI id'leri kullanır, böylece
/// tüm sektör formlarında (kafe, kuaför, klinik, emlak, portfolyo vb.)
/// tutarlı, tek bir tema seçme deneyimi olur. Önceden her sektör tek bir
/// "vurgu rengi" seçtiriyordu; artık tam bir görsel kimlik (arkaplan +
/// kart yüzeyi + metin tonları + vurgu rengi) seçiliyor.
const Map<String, Map<String, String>> siteThemes = {
  'clean_light': {
    'bg': '#F8F9FA',
    'text': '#212529',
    'subtext': '#6C757D',
    'cardBg': '#FFFFFF',
    'border': '#E9ECEF',
    'chipBg': '#F1F1F1',
    'accent': '#212529',
    'accentText': '#FFFFFF',
  },
  'midnight_dark': {
    'bg': '#0F172A',
    'text': '#FFFFFF',
    'subtext': '#94A3B8',
    'cardBg': '#1E293B',
    'border': '#334155',
    'chipBg': '#1E293B',
    'accent': '#38BDF8',
    'accentText': '#0F172A',
  },
  'sunset_gradient': {
    'bg': 'linear-gradient(135deg,#FF512F,#DD2476)',
    'text': '#FFFFFF',
    'subtext': 'rgba(255,255,255,0.75)',
    'cardBg': 'rgba(255,255,255,0.14)',
    'border': 'rgba(255,255,255,0.3)',
    'chipBg': 'rgba(255,255,255,0.2)',
    'accent': '#FFFFFF',
    'accentText': '#DD2476',
  },
  'neon_cyber': {
    'bg': '#0A0A0C',
    'text': '#00FFCC',
    'subtext': 'rgba(255,255,255,0.7)',
    'cardBg': '#121216',
    'border': '#00FFCC',
    'chipBg': '#121216',
    'accent': '#00FFCC',
    'accentText': '#0A0A0C',
  },
  'soft_pastel': {
    'bg': 'linear-gradient(180deg,#A1C4FD,#C2E9FB)',
    'text': '#2C3E50',
    'subtext': '#5D7285',
    'cardBg': 'rgba(255,255,255,0.55)',
    'border': 'rgba(255,255,255,0.6)',
    'chipBg': 'rgba(255,255,255,0.5)',
    'accent': '#2C3E50',
    'accentText': '#FFFFFF',
  },
};

/// [themeId] tanınmıyorsa güvenli varsayılana ('clean_light') düşer.
Map<String, String> themeOf(String? themeId) =>
    siteThemes[themeId] ?? siteThemes['clean_light']!;

/// Bir temanın tek bir vurgu rengine ihtiyaç duyan, wrapPageHtml DIŞINDA
/// (örn. generator'ın kendi inline stilinde) kullanılan yerler için kısayol.
String themeAccent(String? themeId) => themeOf(themeId)['accent']!;

/// Küratörlü tipografi paketleri. Kullanıcı font ailesini tek tek seçmez —
/// bu paketlerden birini seçer, böylece sonuç her zaman uyumlu çıkar
/// (renk temalarındaki [siteThemes] ile birebir aynı mantık).
/// [heading] başlıklarda (hero-title, section-title vb.), [body] gövde
/// metninde kullanılır. [googleFontsHref] tek <link> ile hepsini yükler.
/// Geçerli paket id'leri (form tarafındaki seçim listesi bunları kullanmalı):
/// 'editorial' (Fraunces+Inter — dergi/portfolyo hissi),
/// 'modern_sade' (Inter+Inter — nötr, güvenli varsayılan),
/// 'sicak_elyazisi' (Poppins+Nunito — kafe/kuaför/çiçekçi gibi sıcak işler),
/// 'klasik' (Playfair Display+Source Sans 3 — klinik, hukuk, danışmanlık),
/// 'kalin_vurgulu' (Space Grotesk+Inter — spor salonu, teknoloji, genç marka).
const Map<String, Map<String, String>> _fontPackageData = {
  'editorial': {
    'heading': "'Fraunces', Georgia, serif",
    'body': "'Inter', -apple-system, Roboto, sans-serif",
    'googleFontsHref':
        'https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600;9..144,700&family=Inter:wght@400;500;600;700&display=swap',
  },
  'modern_sade': {
    'heading': "'Inter', -apple-system, Roboto, sans-serif",
    'body': "'Inter', -apple-system, Roboto, sans-serif",
    'googleFontsHref': 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap',
  },
  'sicak_elyazisi': {
    'heading': "'Poppins', -apple-system, Roboto, sans-serif",
    'body': "'Nunito', -apple-system, Roboto, sans-serif",
    'googleFontsHref':
        'https://fonts.googleapis.com/css2?family=Poppins:wght@500;600;700&family=Nunito:wght@400;500;600;700&display=swap',
  },
  'klasik': {
    'heading': "'Playfair Display', Georgia, serif",
    'body': "'Source Sans 3', -apple-system, Roboto, sans-serif",
    'googleFontsHref':
        'https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700;800&family=Source+Sans+3:wght@400;500;600;700&display=swap',
  },
  'kalin_vurgulu': {
    'heading': "'Space Grotesk', -apple-system, Roboto, sans-serif",
    'body': "'Inter', -apple-system, Roboto, sans-serif",
    'googleFontsHref':
        'https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600;700&display=swap',
  },
};

/// [id] tanınmıyorsa güvenli varsayılana ('modern_sade') düşer.
Map<String, String> fontPackageOf(String? id) =>
    _fontPackageData[id] ?? _fontPackageData['modern_sade']!;

/// Yoğunluk kademesi — SADECE başlıkları etkiler (hero-title, section-title
/// vb. font-weight + boyut). Gövde metni her zaman normal ağırlıkta kalır;
/// body text'i kalınlaştırmak okunabilirliği bozar, bu yüzden serbest
/// slider yerine 3 kademeli, güvenli bir seçim sunulur.
const Map<String, Map<String, String>> _typeDensityData = {
  'ince': {'headingWeight': '500', 'heroTitleSize': '30px', 'sectionTitleSize': '19px'},
  'normal': {'headingWeight': '700', 'heroTitleSize': '32px', 'sectionTitleSize': '22px'},
  'kalin': {'headingWeight': '800', 'heroTitleSize': '38px', 'sectionTitleSize': '25px'},
};

Map<String, String> typeDensityOf(String? id) =>
    _typeDensityData[id] ?? _typeDensityData['normal']!;

/// Sağ altta sabit (fixed) duran WhatsApp/Ara aksiyon butonu. [whatsapp]
/// varsa öncelik ondadır (daha yüksek dönüşüm), yoksa [phone] ile arama
/// linki gösterilir. İkisi de null ise boş string döner (buton basılmaz).
/// Tüm sektör şablonlarında ortak kullanılsın diye burada, tek yerde.
String floatingContactButtonHtml({String? whatsapp, String? phone}) {
  if ((whatsapp == null || whatsapp.isEmpty) && (phone == null || phone.isEmpty)) {
    return '';
  }
  if (whatsapp != null && whatsapp.isNotEmpty) {
    return '''
<a class="floating-contact-btn wa" target="_blank" rel="noopener"
   href="https://wa.me/${escapeHtml(whatsapp)}" aria-label="WhatsApp">💬</a>''';
  }
  return '''
<a class="floating-contact-btn call" href="tel:${escapeHtml(phone!)}" aria-label="Ara">📞</a>''';
}

/// SEO + sosyal medya paylaşım (Open Graph/Twitter) meta etiketleri +
/// schema.org (JSON-LD) yapılandırılmış veri.
///
/// [description] boşsa description/og:description/twitter:description
/// eklenmez (boş/anlamsız meta yazmamak için) ama title/robots/og:site_name/
/// JSON-LD gibi description'a bağlı olmayan etiketler YİNE DE eklenir —
/// eskiden description yoksa fonksiyon tamamen boş dönüyordu, bu da o
/// sayfaların robots/canonical/JSON-LD gibi temel SEO etiketlerinden tamamen
/// mahrum kalmasına sebep oluyordu.
///
/// [siteUrl] yayınlanan sayfanın TAM adresi (örn. https://x.sitora.app/).
/// Bilinmiyorsa (henüz yayınlanmadıysa) null geçilir — canonical/og:url/
/// JSON-LD "url" alanı o zaman hiç eklenmez, sayfa yine de geçerli kalır.
/// [schemaType] JSON-LD @type — fiziksel bir işletme için 'LocalBusiness'
/// (varsayılan), bir kişi/serbest çalışan sayfası için 'Person', bir
/// link-in-bio profili için 'ProfilePage' gibi değerler verilebilir.
String seoMetaHtml({
  required String pageTitle,
  String? description,
  String? ogImage,
  String? siteUrl,
  String schemaType = 'LocalBusiness',
}) {
  final title = escapeHtml(pageTitle);

  // Null-safety: aşağıda "has___" bool'ları yerine doğrudan null check'e
  // dayanan yerel değişkenler kullanılıyor ki Dart tip analizi String?'i
  // String'e otomatik daraltabilsin (bool bayrağa bakarak daraltamaz).
  final rawDescription = (description != null && description.trim().isNotEmpty) ? description : null;
  final desc = rawDescription != null
      ? escapeHtml(
          rawDescription.length > 160 ? '${rawDescription.substring(0, 157)}...' : rawDescription,
        )
      : null;
  final rawImage = (ogImage != null && ogImage.isNotEmpty) ? ogImage : null;
  final image = rawImage != null ? escapeHtml(rawImage) : null;
  final rawUrl = (siteUrl != null && siteUrl.isNotEmpty) ? siteUrl : null;
  final url = rawUrl != null ? escapeHtml(rawUrl) : null;

  final buffer = StringBuffer();

  // Arama motorlarına indeksleme izni — açıkça belirtmek, bazı tarayıcı/CDN
  // önbelleklerinin varsayılan davranışına bel bağlamaktan daha güvenli.
  buffer.writeln('<meta name="robots" content="index, follow">');

  if (url != null) {
    buffer.writeln('<link rel="canonical" href="$url">');
  }

  if (desc != null) {
    buffer.writeln('<meta name="description" content="$desc">');
  }

  // Open Graph (Facebook/WhatsApp/LinkedIn paylaşım kartları)
  buffer.writeln('<meta property="og:title" content="$title">');
  if (desc != null) buffer.writeln('<meta property="og:description" content="$desc">');
  buffer.writeln('<meta property="og:type" content="website">');
  buffer.writeln('<meta property="og:site_name" content="$title">');
  buffer.writeln('<meta property="og:locale" content="tr_TR">');
  if (url != null) buffer.writeln('<meta property="og:url" content="$url">');
  if (image != null) buffer.writeln('<meta property="og:image" content="$image">');

  // Twitter/X kartı
  buffer.writeln(
    '<meta name="twitter:card" content="${image != null ? 'summary_large_image' : 'summary'}">',
  );
  buffer.writeln('<meta name="twitter:title" content="$title">');
  if (desc != null) buffer.writeln('<meta name="twitter:description" content="$desc">');
  if (image != null) buffer.writeln('<meta name="twitter:image" content="$image">');

  // schema.org yapılandırılmış veri — Google'ın arama sonucunda zengin
  // sonuç (rich result) gösterme ihtimalini artırır. Sadece elde olan
  // alanlar eklenir, olmayanlar için anahtar hiç yazılmaz.
  final jsonLdFields = StringBuffer();
  jsonLdFields.write('"@context":"https://schema.org","@type":"${_jsonEscape(schemaType)}"');
  jsonLdFields.write(',"name":"${_jsonEscape(pageTitle)}"');
  if (rawDescription != null) jsonLdFields.write(',"description":"${_jsonEscape(rawDescription)}"');
  if (rawImage != null) jsonLdFields.write(',"image":"${_jsonEscape(rawImage)}"');
  if (rawUrl != null) jsonLdFields.write(',"url":"${_jsonEscape(rawUrl)}"');
  buffer.writeln('<script type="application/ld+json">{${jsonLdFields.toString()}}</script>');

  return buffer.toString().trimRight();
}

/// JSON-LD `<script>` içine gömülen metinler için minimal kaçış — HTML
/// escape'i (escapeHtml) burada YETERSİZ, çünkü hedef HTML değil JSON.
/// Ayrıca `</script>` enjeksiyonunu da engeller.
String _jsonEscape(String input) {
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('<', '\\u003C')
      .replaceAll('>', '\\u003E');
}

/// Sayfa başlığına ziyaretçinin tarayıcısında JS ile güncel ay/yıl ekler
/// (örn. "Ahmet Usta Tesisatçı - Eylül 2026"). Statik olarak yayınlanan
/// sitenin Google'da her zaman "güncel/taze" görünmesini sağlayan basit
/// ve tamamen ücretsiz bir SEO tazelik sinyali — API/servis maliyeti yok,
/// sadece birkaç satır JS. Google artık sayfaları JS render ederek
/// taradığı için <title> içeriğini tarama anındaki güncel ay/yılla görür,
/// site sahibi siteyi hiç güncellemese bile. Ay isimleri sadece 'tr' ve
/// 'en' için tanımlı; başka bir dil geçilirse 'en' kullanılır.
String freshDateTitleScript({String lang = 'tr'}) {
  const monthsTr =
      "['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık']";
  const monthsEn =
      "['January','February','March','April','May','June','July','August','September','October','November','December']";
  final months = lang == 'tr' ? monthsTr : monthsEn;
  return '''
<script>
(function(){
  try {
    var m = $months;
    var d = new Date();
    var suffix = " - " + m[d.getMonth()] + " " + d.getFullYear();
    if (document.title.indexOf(suffix) === -1) { document.title += suffix; }
  } catch (e) {}
})();
</script>''';
}

/// Tüm sayfayı saran ortak CSS + HTML iskeleti.
/// [bodyHtml] yukarıdaki blokların birleştirilmiş hali olmalı.
/// [themeId] siteThemes'teki hazır temalardan biri olmalı (bkz. yukarısı).
/// [metaDescription] Google/WhatsApp paylaşım kartı için kısa açıklama
/// (genelde tagline/about alanından türetilir) — boş bırakılırsa SEO
/// meta bloğu hiç eklenmez.
/// [ogImage] paylaşım kartında görünecek görsel (genelde coverImage/logo).
/// [siteUrl] yayınlanan sayfanın tam adresi — bilinmiyorsa null (canonical/
/// og:url o zaman eklenmez). [schemaType] JSON-LD @type (bkz. seoMetaHtml).
/// [whatsapp]/[phone] verilirse sağ altta sabit bir WhatsApp/Ara butonu
/// eklenir (whatsapp öncelikli); ikisi de boşsa buton hiç eklenmez.
/// [fontPackageId] bkz. [fontPackageOf] — 5 küratörlü tipografi paketinden
/// biri, serbest font seçimi yerine. [density] bkz. [typeDensityOf] —
/// başlık kalınlığı/boyutu için 3 kademeli 'ince'/'normal'/'kalin' seçimi.
/// [freshDateTitle] true ise (varsayılan) sayfa başlığına ziyaretçinin
/// tarayıcısında güncel ay/yıl eklenir (bkz. [freshDateTitleScript]) —
/// ücretsiz bir SEO tazelik sinyali. İstenmezse false geçilebilir.
String wrapPageHtml({
  required String pageTitle,
  required String bodyHtml,
  String themeId = 'clean_light',
  String? metaDescription,
  String? ogImage,
  String? siteUrl,
  String schemaType = 'LocalBusiness',
  String? whatsapp,
  String? phone,
  String? navHtml,
  String lang = 'tr',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  bool freshDateTitle = true,
}) {
  final theme = themeOf(themeId);
  final bg = theme['bg']!;
  final text = theme['text']!;
  final subtext = theme['subtext']!;
  final cardBg = theme['cardBg']!;
  final border = theme['border']!;
  final chipBg = theme['chipBg']!;
  final accent = theme['accent']!;
  final accentText = theme['accentText']!;
  final fonts = fontPackageOf(fontPackageId);
  final headingFont = fonts['heading']!;
  final bodyFont = fonts['body']!;
  final googleFontsHref = fonts['googleFontsHref']!;
  final densityVals = typeDensityOf(density);
  final headingWeight = densityVals['headingWeight']!;
  final heroTitleSize = densityVals['heroTitleSize']!;
  final sectionTitleSize = densityVals['sectionTitleSize']!;
  final seoHtml = seoMetaHtml(
    pageTitle: pageTitle,
    description: metaDescription,
    ogImage: ogImage,
    siteUrl: siteUrl,
    schemaType: schemaType,
  );
  final floatingBtnHtml = floatingContactButtonHtml(whatsapp: whatsapp, phone: phone);
  return '''
<!DOCTYPE html>
<html lang="$lang">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(pageTitle)}</title>
${freshDateTitle ? freshDateTitleScript(lang: lang) : ''}
<meta name="theme-color" content="$accent">
$seoHtml
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="$googleFontsHref">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: $bodyFont; color: $text; background: $bg; line-height: 1.5; }
  h1, h2, h3, .hero-title, .section-title { font-family: $headingFont; }
  @media (prefers-reduced-motion: reduce) {
    * { animation-duration: 0.001ms !important; transition-duration: 0.001ms !important; }
  }
  .hero { position: relative; height: 60vh; min-height: 320px; background-size: cover; background-position: center; display:flex; align-items:center; justify-content:center; }
  .hero-overlay { background: rgba(0,0,0,0.45); width:100%; height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; padding: 24px; color: white; }
  .hero-overlay.editorial { align-items:flex-start; justify-content:flex-end; text-align:left; padding: 0 32px 48px; }
  .hero-overlay.editorial::before { content:''; display:block; width:52px; height:4px; background:$accent; margin-bottom:18px; border-radius:2px; }
  .hero-overlay.editorial .hero-title { max-width: 620px; }
  .hero-overlay.editorial .hero-tagline { max-width: 480px; }
  .hero-logo { width: 72px; height: 72px; border-radius: 50%; margin-bottom: 12px; object-fit: cover; }
  .hero-title { font-size: $heroTitleSize; font-weight: $headingWeight; margin-bottom: 8px; letter-spacing: -0.01em; }
  .hero-tagline { font-size: 16px; opacity: 0.9; margin-bottom: 20px; }
  .hero-cta { background: $accent; color: $accentText; padding: 12px 28px; border-radius: 30px; text-decoration: none; font-weight: 600; transition: transform 0.18s ease, box-shadow 0.18s ease; display:inline-block; }
  .hero-cta:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(0,0,0,0.25); }
  .section { max-width: 720px; margin: 0 auto; padding: 40px 20px; }
  .section-title { font-size: $sectionTitleSize; font-weight: $headingWeight; margin-bottom: 20px; color: $text; }
  .section, .reveal { opacity: 0; transform: translateY(16px); transition: opacity 0.6s ease, transform 0.6s ease; }
  .section.in-view, .reveal.in-view { opacity: 1; transform: translateY(0); }
  .service-list { list-style: none; }
  .service-row { display:flex; align-items:center; gap: 12px; padding: 14px 0; border-bottom: 1px solid $border; }
  .service-name { flex: 1; font-weight: 600; }
  .service-duration { color: $subtext; font-size: 13px; }
  .service-price { font-weight: 700; color: $accent; }
  .gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px,1fr)); gap: 8px; }
  .gallery-item { position: relative; aspect-ratio: 1; overflow: hidden; border-radius: 10px; cursor: pointer; }
  .gallery-item img { width:100%; height:100%; object-fit: cover; transition: transform 0.35s ease; }
  .gallery-item:hover img { transform: scale(1.06); }
  .gallery-lightbox { display:none; position: fixed; inset:0; background: rgba(0,0,0,0.9); z-index:999; align-items:center; justify-content:center; }
  .gallery-lightbox.open { display:flex; }
  .gallery-lightbox img { max-width: 92%; max-height: 92%; }
  .gallery-section-slideshow .section-title { margin-bottom: 14px; }
  .gallery-slideshow { display:flex; overflow-x:auto; gap: 12px; scroll-snap-type: x mandatory; -webkit-overflow-scrolling: touch; padding-bottom: 4px; scrollbar-width: none; }
  .gallery-slideshow::-webkit-scrollbar { display:none; }
  .gallery-slide { flex: 0 0 82%; scroll-snap-align: center; position: relative; aspect-ratio: 4/3; border-radius: 14px; overflow: hidden; cursor: pointer; }
  .gallery-slide img { width:100%; height:100%; object-fit: cover; }
  .gallery-slide .gallery-caption { position:absolute; left:0; right:0; bottom:0; padding: 10px 14px; background: linear-gradient(0deg, rgba(0,0,0,0.65), transparent); color:#fff; font-size: 13px; }
  .gallery-dots { display:flex; justify-content:center; gap: 8px; margin-top: 14px; }
  .gallery-dot { width: 8px; height: 8px; border-radius: 50%; background: $border; display:inline-block; }
  @media (min-width: 640px) { .gallery-slide { flex-basis: 46%; } }
  .hours-table { width:100%; border-collapse: collapse; }
  .hours-table td { padding: 10px 0; border-bottom: 1px solid $border; }
  .hours-table td:last-child { text-align: right; }
  .hours-status-badge { display:inline-block; margin-left: 8px; padding: 3px 11px; border-radius: 999px; font-size: 12px; font-weight: 700; vertical-align: middle; }
  .hours-status-badge.is-open { background: rgba(34,197,94,0.15); color: #16a34a; }
  .hours-status-badge.is-closed { background: rgba(239,68,68,0.15); color: #dc2626; }
  .map-embed { border-radius: 12px; overflow: hidden; margin: 16px 0; }
  .directions-link { display:inline-block; color: $accent; font-weight: 600; text-decoration: none; }
  .contact-buttons { display:flex; flex-wrap: wrap; gap: 12px; }
  .contact-btn { padding: 12px 20px; border-radius: 10px; text-decoration:none; font-weight:600; color:$accentText; background:$accent; transition: transform 0.18s ease, box-shadow 0.18s ease; display:inline-block; }
  .contact-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 18px rgba(0,0,0,0.18); }
  .contact-btn.review { background: #fbbf24; color: #1a1a1a; }
  .menu-category { margin-bottom: 24px; }
  .menu-category-title { font-size: 18px; font-weight:700; margin-bottom: 10px; color: $accent; }
  .menu-item { padding: 10px 0; border-bottom: 1px solid $border; }
  .menu-item-main { display:flex; justify-content: space-between; font-weight:600; }
  .menu-item-desc { color:$subtext; font-size: 13px; margin-top:4px; }
  .randevu-form { display:flex; flex-direction:column; gap: 12px; max-width: 420px; }
  .randevu-form input, .randevu-form textarea { padding: 12px; border-radius: 8px; border: 1px solid $border; background:$cardBg; color:$text; font-size:15px; }
  .randevu-form button { padding: 14px; border:none; border-radius: 8px; background:$accent; color:$accentText; font-weight:700; cursor:pointer; }
  .sitora-lead-form { display:flex; flex-direction:column; gap: 12px; max-width: 420px; margin-top: 18px; }
  .sitora-lead-form input, .sitora-lead-form textarea { padding: 12px; border-radius: 8px; border: 1px solid $border; background:$cardBg; color:$text; font-size:15px; font-family: inherit; }
  .sitora-lead-form button { padding: 14px; border:none; border-radius: 8px; background:$accent; color:$accentText; font-weight:700; cursor:pointer; }
  .sitora-lead-form button:disabled { opacity: 0.6; cursor:default; }
  .sitora-lead-status { font-size: 13px; color:$subtext; min-height: 18px; margin: 0; }
  .faq-list { display:flex; flex-direction:column; gap: 10px; }
  .faq-item { border:1px solid $border; background:$cardBg; border-radius:10px; padding: 4px 16px; }
  .faq-question { padding: 12px 0; font-weight:600; cursor:pointer; color:$text; }
  .faq-answer { padding: 0 0 14px 0; color:$subtext; line-height: 1.55; }
  .testimonial-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(240px,1fr)); gap:16px; }
  .testimonial-card { border:1px solid $border; background:$cardBg; border-radius:14px; padding:20px; }
  .testimonial-stars { color: #f5a623; letter-spacing: 2px; margin-bottom: 8px; }
  .testimonial-text { color:$text; font-style: italic; line-height: 1.55; margin-bottom: 10px; }
  .testimonial-name { color:$subtext; font-weight:600; font-size: 14px; }
  .pkg-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(220px,1fr)); gap:16px; }
  .pkg-card { border:1px solid $border; background:$cardBg; border-radius:14px; padding:20px; transition: transform 0.2s ease, box-shadow 0.2s ease; }
  .pkg-card:hover { transform: translateY(-4px); box-shadow: 0 10px 24px rgba(0,0,0,0.10); }
  .pkg-card.featured { border-color:$accent; border-width:2px; }
  .pkg-title { font-size:17px; font-weight:700; margin-bottom:4px; color:$text; }
  .pkg-session { color:$subtext; font-size:13px; margin-bottom:10px; }
  .pkg-price { font-size:20px; font-weight:800; color:$accent; margin-bottom:10px; }
  .pkg-original-price { text-decoration:line-through; color:$subtext; font-size:14px; margin-right:8px; }
  .pkg-included { list-style:none; font-size:13px; color:$subtext; margin-bottom:8px; }
  .pkg-included li { padding:2px 0; }
  .pkg-note { font-size:12px; color:$subtext; }
  .team-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(160px,1fr)); gap:16px; }
  .team-card { text-align:center; }
  .team-photo { width:88px; height:88px; border-radius:50%; object-fit:cover; margin-bottom:10px; }
  .team-name { font-size:15px; font-weight:700; color:$text; }
  .team-specialty { font-size:13px; color:$subtext; margin-bottom:6px; }
  .team-bio { font-size:12px; color:$subtext; margin-bottom:6px; }
  .team-tags { display:flex; flex-wrap:wrap; gap:6px; justify-content:center; }
  .team-tag { font-size:11px; background:$chipBg; color:$text; padding:3px 8px; border-radius:10px; }
  .practitioner-section { text-align:center; }
  .practitioner-photo { width:110px; height:110px; border-radius:50%; object-fit:cover; margin-bottom:12px; }
  .practitioner-name { font-size:20px; font-weight:700; color:$text; }
  .practitioner-title { color:$accent; font-weight:600; margin-bottom:10px; }
  .practitioner-bio { color:$subtext; margin-bottom:12px; }
  .cred-badges { display:flex; flex-wrap:wrap; gap:8px; justify-content:center; }
  .cred-badge { font-size:12px; background:$chipBg; color:$text; padding:4px 10px; border-radius:10px; }
  .schedule-table { width:100%; border-collapse:collapse; }
  .schedule-table td { padding:10px; border-bottom:1px solid $border; font-size:14px; color:$text; }
  .timeline { border-left:2px solid $border; padding-left:20px; }
  .timeline-item { margin-bottom:20px; }
  .timeline-year { font-weight:700; color:$accent; font-size:13px; }
  .timeline-body h3 { font-size:15px; margin:4px 0; color:$text; }
  .timeline-body p { font-size:13px; color:$subtext; }
  .skill-chips { display:flex; flex-wrap:wrap; gap:8px; }
  .skill-chip { background:$chipBg; color:$text; padding:6px 14px; border-radius:14px; font-size:13px; }
  .contact-form { display:flex; flex-direction:column; gap:12px; max-width:420px; }
  .contact-form input, .contact-form textarea { padding:12px; border-radius:8px; border:1px solid $border; background:$cardBg; color:$text; font-size:15px; }
  .contact-form button { padding:14px; border:none; border-radius:8px; background:$accent; color:$accentText; font-weight:700; cursor:pointer; }
  .about-section { color:$text; }
  .address-text { color:$text; }
  .property-grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap:16px; padding: 20px; max-width:960px; margin:0 auto; }
  .property-card { border-radius:12px; overflow:hidden; border:1px solid $border; background:$cardBg; text-decoration:none; color:inherit; display:block; }
  .property-card img { width:100%; height:140px; object-fit:cover; }
  .property-card-body { padding:12px; }
  .property-card-body h3 { font-size:14px; margin-bottom:4px; color:$text; }
  .property-tags { font-size:12px; color:$subtext; margin-bottom:6px; }
  .property-price { font-weight:700; color:$accent; }
  .property-details-table { width:100%; border-collapse:collapse; margin-bottom:16px; }
  .property-details-table td { padding:8px 0; border-bottom:1px solid $border; color:$text; }
  .property-details-table td:first-child { color:$subtext; }
  .property-description { color:$text; }
  .vcard-btn { display:inline-block; padding:12px 24px; border-radius:10px; background:$accent; color:$accentText; text-decoration:none; font-weight:700; margin-top:16px; }
  .floating-contact-btn { position:fixed; right:18px; bottom:18px; width:56px; height:56px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:26px; text-decoration:none; box-shadow:0 6px 18px rgba(0,0,0,0.28); z-index:998; }
  .floating-contact-btn.wa { background:#25D366; }
  .floating-contact-btn.call { background:$accent; }
  @media (max-width:600px) { .floating-contact-btn { right:14px; bottom:14px; width:52px; height:52px; font-size:23px; } }
  .site-nav { position:sticky; top:0; z-index:997; background:$cardBg; border-bottom:1px solid $border; }
  .site-nav-inner { max-width:720px; margin:0 auto; display:flex; gap:4px; overflow-x:auto; padding:0 12px; }
  .site-nav-link { flex-shrink:0; padding:14px 12px; color:$subtext; text-decoration:none; font-weight:600; font-size:14px; border-bottom:2px solid transparent; }
  .site-nav-link.active { color:$accent; border-bottom-color:$accent; }
</style>
</head>
<body>
${navHtml ?? ''}
$bodyHtml
$floatingBtnHtml
<script>
(function(){
  // Sayfa kaydırıldıkça bölümleri hafifçe belirginleştirir (fade-in-up).
  // Kütüphane gerektirmez; hareket azaltma tercihine CSS tarafında uyulur.
  var targets = document.querySelectorAll('.section, .reveal');
  if (!('IntersectionObserver' in window)) {
    targets.forEach(function(el){ el.classList.add('in-view'); });
    return;
  }
  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if (entry.isIntersecting) {
        entry.target.classList.add('in-view');
        io.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  targets.forEach(function(el){ io.observe(el); });
})();
</script>
</body>
</html>''';
}
