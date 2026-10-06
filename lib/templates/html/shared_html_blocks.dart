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
import '../../services/free_plan_restriction_service.dart';

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
      // 28.09.2026 eklendi (kanka isteği) — ürün satan esnaf için opsiyonel
      // "Ürünler" bölümü (bkz. productListBlockHtml).
      'products': 'Products',
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
      'openDigitalMenu': '<i class="fa-solid fa-mobile-screen-button" style="margin-right:6px"></i> Open Digital Menu',
      'goToMenu': 'View Menu',
      // 19.09.2026 — menü ürünü yasal bilgi rozetleri (bkz. menuBlockHtml)
      'legalAllergen': 'Allergens',
      'legalAlcohol': 'Contains alcohol',
      'legalPork': 'Contains pork',
      'legalAltPork': 'Contains alcohol/pork',
      // === Talep formu (bkz. leadFormBlockHtml) — 31.08.2026 eklendi ===
      'sendRequest': 'Send a Request',
      'yourName': 'Your Name',
      'yourPhone': 'Your Phone (optional)',
      'yourEmail': 'Your Email (optional)',
      'yourMessage': 'Your Message',
      'contactMethodHint': 'Please fill in at least one: phone or email.',
      'sendButton': 'Send',
      'sending': 'Sending…',
      'requestSent': 'Thank you! Your request has been sent.',
      'requestFailed': "Couldn't send, please try the phone/WhatsApp button above.",
      // 15.09.2026 eklendi — bkz. leadFormMarkup > leadDelivery = 'email'/'both'.
      'requestEmailOpened': 'Your email app has opened — please press Send there to finish.',
      // === SSS / Yorumlar — 31.08.2026 eklendi ===
      'faqTitle': 'Frequently Asked Questions',
      'testimonialsTitle': 'What Our Customers Say',
      // === Canlı açık/kapalı rozeti + Google Yorum — 01.09.2026 eklendi ===
      'openNowLabel': 'Open Now',
      'closedNowLabel': 'Closed Now',
      'googleReviewButton': '<i class="fa-solid fa-star" style="margin-right:6px"></i> Rate Us on Google',
      // === Video bloğu — 05.09.2026 eklendi ===
      'videoTitle': 'Video',
    };
  }
  return const {
    'home': 'Ana Sayfa',
    'menu': 'Menü',
    'gallery': 'Galeri',
    // 28.09.2026 eklendi (kanka isteği) — ürün satan esnaf için opsiyonel
    // "Ürünler" bölümü (bkz. productListBlockHtml).
    'products': 'Ürünler',
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
    'openDigitalMenu': '<i class="fa-solid fa-mobile-screen-button" style="margin-right:6px"></i> Dijital Menüyü Aç',
    'goToMenu': 'Menüyü Gör',
    // 19.09.2026 — menü ürünü yasal bilgi rozetleri (bkz. menuBlockHtml)
    'legalAllergen': 'Alerjen',
    'legalAlcohol': 'Alkol içerir',
    'legalPork': 'Domuz içerir',
    'legalAltPork': 'Alkol/Domuz içerir',
    // === Talep formu (bkz. leadFormBlockHtml) — 31.08.2026 eklendi ===
    'sendRequest': 'Talep Gönder',
    'yourName': 'Adınız',
    'yourPhone': 'Telefonunuz (opsiyonel)',
    'yourEmail': 'E-postanız (opsiyonel)',
    'yourMessage': 'Mesajınız',
    'contactMethodHint': 'Lütfen telefon veya e-postadan en az birini doldurun.',
    'sendButton': 'Gönder',
    'sending': 'Gönderiliyor…',
    'requestSent': 'Teşekkürler! Talebiniz iletildi.',
    'requestFailed': 'Gönderilemedi, lütfen yukarıdaki telefon/WhatsApp butonunu kullanın.',
    // 15.09.2026 eklendi — bkz. leadFormMarkup > leadDelivery = 'email'/'both'.
    'requestEmailOpened': 'E-posta uygulamanız açıldı — göndermek için orada Gönder\'e basmayı unutmayın.',
    // === SSS / Yorumlar — 31.08.2026 eklendi ===
    'faqTitle': 'Sıkça Sorulan Sorular',
    'testimonialsTitle': 'Müşterilerimiz Ne Diyor',
    // === Canlı açık/kapalı rozeti + Google Yorum — 01.09.2026 eklendi ===
    'openNowLabel': 'Şu An Açık',
    'closedNowLabel': 'Şu An Kapalı',
    'googleReviewButton': '<i class="fa-solid fa-star" style="margin-right:6px"></i> Bizi Google\'da Değerlendirin',
    // === Video bloğu — 05.09.2026 eklendi ===
    'videoTitle': 'Video',
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
/// 27.09.2026 güncellendi (kanka isteği — "amatör" karşılaştırmasında
/// tespit edilen 4. fark: bizim varsayılan etiketlerimiz referans
/// sitelere göre daha jenerikti). Metinler biraz daha sıcak/duygusal
/// yazıldı ama servicesTitle/ctaText'in NEREDE kullanıldığı (bölüm
/// başlığı / kısa CTA buton metni) DEĞİŞMEDİ — ctaText hâlâ kısa
/// tutuldu (buton genişliğini bozmasın diye), servicesTitle biraz daha
/// zengin bir başlık cümlesi olabildi. Kullanıcı formda kendi metnini
/// girerse bu varsayılanların hiçbiri kullanılmaz (bkz. ilgili form
/// ekranı) — bunlar SADECE alan boş bırakılırsa görünür.
Map<String, String> businessSectorLabels(String sectorKey, String lang) {
  const table = <String, Map<String, Map<String, String>>>{
    'default': {
      'tr': {'servicesTitle': 'Sizin İçin Neler Yapabiliriz', 'ctaText': 'Hemen Randevu Al'},
      'en': {'servicesTitle': 'What We Can Do For You', 'ctaText': 'Book Your Spot'},
    },
    'carWash': {
      'tr': {'servicesTitle': 'Aracınıza Layık Bakım Paketleri', 'ctaText': 'Randevunu Ayırt'},
      'en': {'servicesTitle': 'Care Packages Your Car Deserves', 'ctaText': 'Reserve Your Spot'},
    },
    'cleaningCompany': {
      'tr': {'servicesTitle': 'Evinize Değer Katan Hizmetler', 'ctaText': 'Ücretsiz Teklif Al'},
      'en': {'servicesTitle': 'Services That Add Real Value', 'ctaText': 'Get a Free Quote'},
    },
    'drivingSchool': {
      'tr': {'servicesTitle': 'Direksiyona Güvenle Geçin', 'ctaText': 'Hemen Kayıt Ol'},
      'en': {'servicesTitle': 'Get Behind the Wheel with Confidence', 'ctaText': 'Enroll Today'},
    },
    'florist': {
      'tr': {'servicesTitle': 'Her An İçin Doğru Çiçek', 'ctaText': 'Siparişini Ver'},
      'en': {'servicesTitle': 'The Right Flowers for Every Moment', 'ctaText': 'Order Now'},
    },
    'handyman': {
      'tr': {'servicesTitle': 'İhtiyacınız Olan Her An Yanınızdayız', 'ctaText': 'Hemen Ara'},
      'en': {'servicesTitle': "We're There When You Need a Hand", 'ctaText': 'Call Now'},
    },
    'massageSpa': {
      'tr': {'servicesTitle': 'Kendinize Ayırdığınız Zaman', 'ctaText': 'Randevunu Ayırt'},
      'en': {'servicesTitle': 'Time You Deserve for Yourself', 'ctaText': 'Book Your Session'},
    },
    'movingCompany': {
      'tr': {'servicesTitle': 'Taşınmayı Sizin İçin Kolaylaştırıyoruz', 'ctaText': 'Ücretsiz Teklif Al'},
      'en': {'servicesTitle': 'Making Your Move Easier', 'ctaText': 'Get a Free Quote'},
    },
    'petGrooming': {
      'tr': {'servicesTitle': 'Dostunuz İçin Özenli Bakım', 'ctaText': 'Randevu Ayırt'},
      'en': {'servicesTitle': 'Gentle Care for Your Best Friend', 'ctaText': 'Book an Appointment'},
    },
    'tailor': {
      'tr': {'servicesTitle': 'Size Özel, Tek Tek Elde Dikilir', 'ctaText': 'Randevu Al'},
      'en': {'servicesTitle': 'Tailored to You, Stitch by Stitch', 'ctaText': 'Book an Appointment'},
    },
    'autoRepair': {
      'tr': {'servicesTitle': 'Aracınız Güvenilir Ellerde', 'ctaText': 'Hemen Randevu Al'},
      'en': {'servicesTitle': 'Your Car, in Trusted Hands', 'ctaText': 'Book Now'},
    },
    'electrician': {
      'tr': {'servicesTitle': 'Güvenliğiniz İçin Doğru Elektrik Çözümü', 'ctaText': 'Hemen Ara'},
      'en': {'servicesTitle': 'The Right Electrical Fix, Right Away', 'ctaText': 'Call Now'},
    },
    'kindergarten': {
      'tr': {'servicesTitle': 'Çocuğunuz İçin Sevgi Dolu Bir Başlangıç', 'ctaText': 'Kayıt İçin Ulaşın'},
      'en': {'servicesTitle': 'A Warm Start for Your Child', 'ctaText': 'Enroll Now'},
    },
    'boutiqueHotel': {
      'tr': {'servicesTitle': 'Sizi Bekleyen Özel Odalar', 'ctaText': 'Rezervasyonunu Yap'},
      'en': {'servicesTitle': 'Rooms Waiting Just for You', 'ctaText': 'Book Your Stay'},
    },
    'furnitureStore': {
      'tr': {'servicesTitle': 'Evinize Karakter Katacak Parçalar', 'ctaText': 'Teklif Al'},
      'en': {'servicesTitle': 'Pieces That Add Character to Your Home', 'ctaText': 'Get a Quote'},
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

/// 11.09.2026 eklendi (kanka isteği — "torna" hissini kırma) —
/// DETERMİNİSTİK VARYASYON SİSTEMİ.
///
/// SORUN: Aynı sektör + aynı tema seçilince siteler sadece renk/görsel
/// bazında değil, kart köşeleri/gölge/ritim gibi görsel "mood" açısından da
/// birebir aynı çıkıyordu (kullanıcı şikayeti: "herkes standart tornadan
/// çıkmış gibi").
///
/// ÇÖZÜM: Kullanıcıya YENİ bir seçim/karar YÜKLEMEDEN (bkz. form-doldur
/// felsefesi — galleryStyle/themeId/heroLayoutStyle gibi zaten var olan
/// seçimlere DOKUNULMADI), işletme adından (her formda zorunlu, zaten var
/// olan bir alan) deterministik bir seed üretip birkaç görsel varyant
/// arasında OTOMATİK seçim yapıyoruz. Aynı işletme adıyla tekrar üretim/
/// düzenleme HER ZAMAN aynı varyantı verir (kararlı) — ama farklı işletmeler
/// (aynı sektör + aynı tema olsa bile) farklı varyant alır.
///
/// [seedSource] platformlar arası KARARLI olmalı — Dart'ın yerleşik
/// String.hashCode'u VM/JS arasında farklı değer verebildiği için burada
/// basit ama kararlı bir hash elle yazıldı (bkz. web derlemesi de bu
/// kodu kullanıyor, JS tarafında farklı sonuç ÇIKMAMALI).
int siteVariantSeed(String seedSource) {
  var hash = 0;
  for (final codeUnit in seedSource.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash;
}

/// [seedSource] (örn. işletme adı) ile [featureKey] (örn. 'shape')
/// BİRLİKTE hash'lenir — böylece aynı proje içinde birden fazla özellik
/// (ör. ileride: bölüm sırası) varyasyona girerse hepsi BİRBİRİNDEN
/// BAĞIMSIZ seçim yapar; yoksa hepsi hep birlikte aynı yönde değişip
/// çeşitlilik yerine sabit 3 kombinasyon elde edilirdi.
T pickVariant<T>(String seedSource, String featureKey, List<T> variants) {
  if (variants.isEmpty) {
    throw ArgumentError('pickVariant: variants listesi boş olamaz');
  }
  final seed = siteVariantSeed('$seedSource::$featureKey');
  return variants[seed % variants.length];
}

/// Kart/buton "şekil dili" varyantları. [shapeStyle] üç değerden birini
/// alır: 'keskin' (düz/minimal), 'yumusak' (varsayılan — eski sabit
/// görünüme ÇOK YAKIN; birkaç köşe değeri birleştirilirken ±2-4px fark
/// olabilir, ana CTA butonu (hero-cta) kasıtlı olarak bu sistemin DIŞINDA
/// tutulup sabit pill (30px) bırakıldı ki en görünür eleman hiç değişmesin),
/// 'yuvarlak' (belirgin, sıcak). Değerler CSS custom property olarak
/// enjekte edilir (bkz. wrapPageHtml), böylece tüm .pkg-card/
/// .testimonial-card/.gallery-item/.faq-item/.property-card ve ikincil
/// buton/inputlar TEK noktadan etkilenir.
Map<String, String> shapeStyleOf(String shapeStyle) {
  switch (shapeStyle) {
    case 'keskin':
      return {
        'radiusCard': '6px',
        'radiusBtn': '6px',
        'shadowCard': 'none',
      };
    case 'yuvarlak':
      return {
        'radiusCard': '22px',
        'radiusBtn': '24px',
        'shadowCard': '0 12px 28px rgba(0,0,0,0.10)',
      };
    case 'yumusak':
    default:
      return {
        'radiusCard': '14px',
        'radiusBtn': '10px',
        'shadowCard': '0 4px 14px rgba(0,0,0,0.07)',
      };
  }
}

/// Hero (üst kapak) bölümü. Tüm sektör şablonlarında ilk bölüm budur.
/// Çok sayfalı sitelerde (kafe: ana sayfa/menü/galeri, klinik: hizmetler/
/// hekimler, portfolyo: anasayfa/proje detay vb.) sayfalar arası basit üst
/// navigasyon. `active` o an render edilen dosya adıyla eşleşen linki
/// vurgular. Tek sayfalı generator'lar bu fonksiyonu hiç çağırmaz.
// 27.09.2026 eklendi (kanka isteği — kalite artırma) — [siteName]/[logoImage]
// verilirse header'ın solunda küçük bir marka alanı (logo + isim) gösterilir.
// İkisi de opsiyonel ve null bırakılırsa davranış BİREBİR eskisi gibi kalır
// (sadece linkler), yani mevcut hiçbir çağrı kırılmaz.
String siteNavHtml({
  required List<Map<String, String>> links, // {label, href}
  required String active,
  String? siteName,
  String? logoImage,
}) {
  final items = links.map((l) {
    final isActive = l['href'] == active;
    return '<a class="site-nav-link${isActive ? ' active' : ''}" href="${escapeHtml(l['href']!)}">${escapeHtml(l['label']!)}</a>';
  }).join('\n    ');
  final logoHtml = logoImage != null && logoImage.isNotEmpty
      ? '<img src="${escapeHtml(logoImage)}" alt="${escapeHtml(siteName ?? '')}">'
      : '';
  final brandHtml = (siteName != null && siteName.isNotEmpty)
      ? '<a class="site-nav-brand" href="${escapeHtml(links.isNotEmpty ? links.first['href']! : '#')}">$logoHtml<span>${escapeHtml(siteName)}</span></a>'
      : '';
  return '''
<nav class="site-nav">
  <div class="site-nav-inner">
    $brandHtml
    <button type="button" class="site-nav-toggle" aria-label="Menu" aria-expanded="false" aria-controls="site-nav-links"><span></span><span></span><span></span></button>
    <div class="site-nav-links" id="site-nav-links">
    $items
    </div>
  </div>
</nav>''';
}

/// [layoutStyle] 'centered' (varsayılan, ortalanmış klasik hero),
/// 'editorial' (sola yaslı, asimetrik, üstte vurgu çizgili düzen),
/// 'framed' (06.09.2026 eklendi; 28.09.2026'da ÜCRETSİZ yapıldı, bkz. [premiumLayoutStyleIds]:
/// içe boşluklu, ince çerçeveli, üstte küçük harfli "eyebrow" etiketli
/// lüks/butik hissi veren düzen), 'split' (27.09.2026 eklendi — ÜCRETSİZ:
/// yazı+buton foto ÜSTÜNDE değil, foto ayrı yuvarlak köşeli bir kutuda
/// yanında; okunabilirlik fotodan bağımsız) veya 'diagonal' (27.09.2026
/// eklendi — ÜCRETSİZ: tam ekran foto ama dikey değil ÇAPRAZ/yönlü koyu
/// gradient, yazı sola yaslı — "amatör düz overlay" görünümünü kırar) veya
/// 'social' (28.09.2026 eklendi — ÜCRETSİZ: 'split' ile aynı iskelet, farkı
/// fotonun üstünde [featuredTestimonial]'dan üretilen gerçek bir yorum
/// kartının yüzmesi — bkz. [featuredTestimonial] parametresi).
/// CSS karşılıkları wrapPageHtml'deki ortak <style> bloğunda.
String heroBlockHtml({
  required String name,
  required String tagline,
  required String coverImage,
  String? logoImage,
  String ctaText = 'Randevu Al',
  String? ctaHref,
  String layoutStyle = 'centered',
  // 06.09.2026 eklendi — 'framed'/'diagonal' düzeninde hero'nun üstünde
  // görünen küçük harfli etiket (örn. sektör adı). Diğer düzenlerde
  // yok sayılır ('split' hariç — split de kullanabilir).
  String? eyebrowLabel,
  // 28.09.2026 eklendi (kanka isteği) — 'social' düzeninde foto üstünde
  // yüzen bir "gerçek yorum" kartı gösterilir. {name, text, rating?}
  // bekler; İşletmenin GERÇEK yorumlarından biri (çağıran generator
  // testimonials listesinin ilkini geçer). null/boşsa kart hiç render
  // edilmez — sahte/uydurma istatistik/yorum ASLA basılmaz. Diğer
  // düzenlerde bu parametre yok sayılır.
  Map<String, dynamic>? featuredTestimonial,
  // 28.09.2026 eklendi (kanka isteği) — 'split'/'social' düzeninde canlı
  // açık/kapalı hapı için çalışma saatleri (bkz. [heroStatusPillHtml]).
  // null/boşsa hap basılmaz. Diğer düzenlerde yok sayılır.
  List<Map<String, String?>>? workingHours,
  String lang = 'tr',
}) {
  final statusPillHtml = heroStatusPillHtml(workingHours, lang: lang);
  final logoHtml = logoImage != null
      ? '<img class="hero-logo" src="${escapeHtml(logoImage)}" alt="logo">'
      : '';
  final ctaHtml = ctaHref != null
      ? '<a class="hero-cta" href="${escapeHtml(ctaHref)}">${escapeHtml(ctaText)}</a>'
      : '';
  final eyebrowHtml = (eyebrowLabel != null && eyebrowLabel.trim().isNotEmpty)
      ? '<span class="hero-eyebrow">${escapeHtml(eyebrowLabel)}</span>'
      : '';

  // 27.09.2026 eklendi — 'split' tamamen farklı bir DOM: foto artık
  // .hero'nun background-image'i değil, ayrı bir <img> kutusu. Diğer
  // düzenler (centered/editorial/framed/diagonal) hep aynı yapıyı
  // (tek overlay div'i, foto arka planda) kullanmaya devam ediyor —
  // sadece CSS class'ı değişiyor, aşağıdaki switch'te.
  // 28.09.2026 (kanka isteği): 'split'/'social' hero'da artık logo GÖSTERİLMİYOR
  // — üst menüde (siteNavHtml) logo + isim zaten var, hero'da tekrarı gereksizdi.
  // Diğer düzenlerde (centered/editorial/...) logo eskisi gibi kalıyor.
  if (layoutStyle == 'split') {
    return '''
<section class="hero hero-split">
  <div class="hero-split-grid reveal">
    <div class="hero-split-text">
      $eyebrowHtml
      <h1 class="hero-title">${escapeHtml(name)}</h1>
      <p class="hero-tagline">${escapeHtml(tagline)}</p>
      $ctaHtml
    </div>
    <div class="hero-split-media">
      <img class="hero-split-img" src="${escapeHtml(coverImage)}" alt="${escapeHtml(name)}" loading="lazy">
$statusPillHtml
    </div>
  </div>
</section>''';
  }

  // 28.09.2026 eklendi (kanka isteği) — 'social': split ile aynı iskelet
  // (foto ayrı kutuda, yazı hep düz zemin üstünde okunur) ama foto
  // kutusunun üstünde GERÇEK bir yorumdan üretilen yüzen kart var.
  // [featuredTestimonial] verilmezse kart basılmaz, düzen sessizce
  // 'split' ile aynı görünüme döner (uydurma veri yok).
  if (layoutStyle == 'social') {
    final t = featuredTestimonial;
    final quoteText = (t?['text'] as String?)?.trim();
    String quoteCardHtml = '';
    if (t != null && quoteText != null && quoteText.isNotEmpty) {
      final quoteName = (t['name'] as String?)?.trim();
      final rating = int.tryParse('${t['rating'] ?? ''}') ?? 0;
      final starsHtml = (rating >= 1 && rating <= 5)
          ? '<span class="hero-quote-stars" aria-hidden="true">${List.filled(rating, '★').join()}${List.filled(5 - rating, '☆').join()}</span>'
          : '';
      final personHtml = (quoteName != null && quoteName.isNotEmpty)
          ? '<div class="hero-quote-person"><span class="testimonial-avatar" aria-hidden="true">${escapeHtml(quoteName.substring(0, 1).toUpperCase())}</span><span class="hero-quote-name">${escapeHtml(quoteName)}</span></div>'
          : '';
      quoteCardHtml = '''
      <div class="hero-quote-card">
        $starsHtml
        <p class="hero-quote-text">“${escapeHtml(quoteText)}”</p>
        $personHtml
      </div>''';
    }
    return '''
<section class="hero hero-split hero-social">
  <div class="hero-split-grid reveal">
    <div class="hero-split-text">
      $eyebrowHtml
      <h1 class="hero-title">${escapeHtml(name)}</h1>
      <p class="hero-tagline">${escapeHtml(tagline)}</p>
      $ctaHtml
    </div>
    <div class="hero-split-media">
      <img class="hero-split-img" src="${escapeHtml(coverImage)}" alt="${escapeHtml(name)}" loading="lazy">
$statusPillHtml
$quoteCardHtml
    </div>
  </div>
</section>''';
  }

  final overlayClass = switch (layoutStyle) {
    'editorial' => 'hero-overlay editorial',
    'framed' => 'hero-overlay framed',
    'diagonal' => 'hero-overlay diagonal',
    _ => 'hero-overlay',
  };
  return '''
<section class="hero" style="background-image:url('${escapeHtml(coverImage)}')">
  <div class="$overlayClass reveal">
    $eyebrowHtml
    $logoHtml
    <h1 class="hero-title">${escapeHtml(name)}</h1>
    <p class="hero-tagline">${escapeHtml(tagline)}</p>
    $ctaHtml
  </div>
</section>''';
}

/// 28.09.2026 eklendi (kanka isteği) — hero'nun hemen altında ince, koyu bir
/// "güven şeridi" (bkz. referans siteler: "Profesyonel ürünler · Hijyen &
/// kalite" gibi 4 maddelik şerit). Burada uydurma sayı/istatistik ASLA
/// kullanılmıyor: önce GERÇEK verilerden ([serviceCount]/[galleryCount]/
/// [testimonialCount]/[hasGoogleReview]) üretilen maddeler eklenir, yeterli
/// sayıda gerçek veri yoksa (ör. yeni açılan, hiç servisi/galerisi olmayan
/// bir işletme) sadece o zaman nötr/genel (sayı iddiası TAŞIMAYAN) tamamlayıcı
/// ifadeler eklenir. Renk teması ne olursa olsun okunur kalması için sabit
/// bir renk yerine --sitora-text/--sitora-bg ters çevrilerek kullanılıyor
/// (bkz. .trust-bar CSS'i). Gösterilecek hiçbir madde yoksa boş string döner
/// — TÜM sektör generator'larında hero'nun hemen altına eklenir.
String trustBarBlockHtml({
  int serviceCount = 0,
  int galleryCount = 0,
  int testimonialCount = 0,
  bool hasGoogleReview = false,
  String lang = 'tr',
}) {
  // 06.10.2026 — ŞERİT GERÇEKTEN GÜVEN SİNYALİ TAŞIR: "5+ Fotoğraf" / "3+ Hizmet" gibi içerik
  // sayıları güvenle ilgisizdi ve amatör duruyordu; kaldırıldı ([serviceCount]/[galleryCount]
  // eski çağrılarla uyum için parametre olarak duruyor ama KULLANILMIYOR). Sıra: gerçek Google
  // yorum bağlantısı -> gerçek müşteri yorumu sayısı -> sayı/istatistik iddiası taşımayan nötr ifadeler.
  final items = <String>[];
  if (hasGoogleReview) {
    items.add(lang == 'en' ? 'Google Reviews' : 'Google Yorumları');
  }
  if (testimonialCount > 0) {
    items.add(lang == 'en'
        ? (testimonialCount == 1 ? '1 Customer Review' : '$testimonialCount Customer Reviews')
        : '$testimonialCount Müşteri Yorumu');
  }
  // Şerit en az 3 maddeyle dolu görünsün; eksik kısım nötr ifadelerle tamamlanır.
  final fallback = lang == 'en'
      ? ['Fast Contact', 'Trusted Service', 'Customer Satisfaction']
      : ['Hızlı İletişim', 'Güvenilir Hizmet', 'Müşteri Memnuniyeti'];
  var i = 0;
  while (items.length < 3 && i < fallback.length) {
    items.add(fallback[i]);
    i++;
  }
  if (items.isEmpty) return '';
  final chips = items.take(4).map((s) =>
      '<div class="trust-item"><span class="trust-check" aria-hidden="true">✓</span>${escapeHtml(s)}</div>').join('\n    ');
  return '''
<div class="trust-bar">
  <div class="trust-bar-row">
    $chips
  </div>
</div>''';
}

/// Hizmet listesi bloğu (ad + opsiyonel süre + fiyat).
/// Kuaför, oto yıkama, klinik gibi sektörlerde kullanılır.
/// 27.09.2026 eklendi (kanka isteği) — önceki "satır tipi liste" (.service-row)
/// yerine numaralı/editoryal kart grid'i (.svc-card + .svc-num). Bu fonksiyon
/// TEK bir yerden tüm sektörler için servis/hizmet render'ını üretiyor
/// (kuaför, extended_business, generic_business, clinic hepsi burayı
/// çağırıyor), bu yüzden değişiklik ekstra dosya dokunmadan otomatik olarak
/// TÜM sektörlere yayılıyor. Kart iç boşlukları ve gap değerleri bilinçli
/// olarak 4px'in katları (8/12/16/24/28/32) seçildi — Tailwind'deki gibi
/// tutarlı bir spacing ölçeği garanti etmek için.
/// 28.09.2026 (2. tur) — masaüstü sütun sayısı, son satırda yarım kart
/// kalmasın diye kart sayısına göre seçilir (1-4 -> kendi sayısı, 5-6 -> 3,
/// 7-8 -> 4, 9 -> 3, sonrası 3).
int serviceGridColumns(int count) {
  if (count <= 4) return count < 1 ? 1 : count;
  if (count <= 6) return 3;
  if (count <= 8) return 4;
  return 3;
}

String serviceListBlockHtml({
  required String title,
  required List<Map<String, String?>> services, // name, duration, price
}) {
  final rows = services.asMap().entries.map((entry) {
    final index = entry.key;
    final s = entry.value;
    final num = (index + 1).toString().padLeft(2, '0');
    final durationHtml = s['duration'] != null
        ? '<span class="service-duration">${escapeHtml(s['duration']!)}</span>'
        : '';
    return '''
    <li class="svc-card">
      <span class="svc-num" aria-hidden="true">$num</span>
      <span class="service-name">${escapeHtml(s['name'] ?? '')}</span>
      <span class="svc-meta">
        $durationHtml
        <span class="service-price">${escapeHtml(s['price'] ?? '')}</span>
      </span>
    </li>''';
  }).join('\n');

  final cols = serviceGridColumns(services.length);
  return '''
<section class="section services-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <ul class="service-list" style="--svc-cols:$cols">
$rows
  </ul>
</section>''';
}

/// 28.09.2026 eklendi (kanka isteği) — perakende ürünü olan esnaf (kuaför,
/// çiçekçi, mobilya/dekorasyon, evcil hayvan bakımı, terzi, genel işletme
/// vb.) için OPSİYONEL "Ürünler" bölümü. Referans örnek sitelerdeki
/// "fotoğraf + isim + fiyat" ürün vitrini hissini taklit eder.
///
/// Veri kaynağı BİLEREK ayrı bir picker/model DEĞİL — mevcut galeri
/// resim seçici ile birebir aynı şekil: `List<Map<String, String?>>`
/// {'url', 'caption'}. Kullanıcı ürün fotoğrafını galeriyle aynı bileşenle
/// (GalleryPickerField) yükler, caption alanına "Ürün Adı - Fiyat" yazar;
/// burada caption ilk " - " işaretinden bölünüp isim/fiyat olarak ayrıştırılır
/// (services'teki "Ad - Süre - Fiyat" satır parse mantığıyla aynı ruh).
/// Caption'da " - " yoksa tamamı ürün adı sayılır, fiyat boş kalır — hiçbir
/// zaman veri kaybı/hata olmaz. Liste boşsa (varsayılan/eski projeler)
/// section_registry.dart'taki builder null döner, bölüm hiç render edilmez
/// — geriye dönük uyumlu.
String productListBlockHtml({
  required String title,
  required List<Map<String, String?>> products, // {url, caption: "Ad - Fiyat"}
}) {
  final cards = products.map((p) {
    final url = p['url'] ?? '';
    final caption = (p['caption'] ?? '').trim();
    String name = caption;
    String price = '';
    final sepIndex = caption.indexOf(' - ');
    if (sepIndex != -1) {
      name = caption.substring(0, sepIndex).trim();
      price = caption.substring(sepIndex + 3).trim();
    }
    final imgHtml = url.isNotEmpty
        ? '<img src="$url" alt="${escapeHtml(name)}" loading="lazy">'
        : '';
    final priceHtml = price.isNotEmpty
        ? '<span class="prd-price">${escapeHtml(price)}</span>'
        : '';
    return '''
    <li class="prd-card">
      $imgHtml
      <span class="prd-name">${escapeHtml(name)}</span>
      $priceHtml
    </li>''';
  }).join('\n');

  return '''
<section class="section products-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <ul class="product-list">
$cards
  </ul>
</section>''';
}

/// Galeri bloğu. [style] 'grid' (varsayılan, ızgara + lightbox), 'slideshow'
/// (yatay kaydırmalı carousel, saf CSS scroll-snap), 'crossfade' (yumuşak
/// geçişli tek kare) veya 'marquee' (27.09.2026 eklendi — kanka isteği:
/// referans sitelerdeki gibi sürekli kayan/infinite-scroll görsel şeridi,
/// saf CSS animasyonuyla — JS kütüphanesi gerekmez, bkz.
/// [_galleryMarqueeBlockHtml]) olabilir. Bilinmeyen bir değer 'grid'e düşer.
/// Otomatik oynatma grid/slideshow/crossfade'de BİLEREK yok (kullanıcı
/// deneyimini rahatsız eder) — marquee'de ise otomatik kayma TASARIMIN
/// KENDİSİ (referans sitedeki gibi), o yüzden istisna: hover'da durur ve
/// `prefers-reduced-motion` saygı görür (bkz. fonksiyon içi CSS notu).
String galleryBlockHtml({
  required String title,
  required List<Map<String, String?>> images, // url, caption
  bool beforeAfter = false,
  String style = 'grid',
}) {
  if (style == 'slideshow') {
    return _gallerySlideshowBlockHtml(title: title, images: images);
  }
  if (style == 'crossfade') {
    return _galleryCrossfadeBlockHtml(title: title, images: images);
  }
  if (style == 'marquee') {
    return _galleryMarqueeBlockHtml(title: title, images: images);
  }
  if (style == 'bento') {
    return _galleryBentoBlockHtml(title: title, images: images);
  }

  final items = images.asMap().entries.map((entry) {
    final i = entry.key;
    final img = entry.value;
    final caption = img['caption'] != null
        ? '<span class="gallery-caption">${escapeHtml(img['caption']!)}</span>'
        : '';
    final altText = escapeHtml(img['caption'] ?? '$title - ${i + 1}');
    return '''
    <div class="gallery-item" onclick="document.getElementById('${_idFor(img['url'] ?? '')}').classList.add('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="$altText">
      $caption
    </div>
    <div class="gallery-lightbox" id="${_idFor(img['url'] ?? '')}" onclick="this.classList.remove('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="$altText">
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
    final altText = escapeHtml(img['caption'] ?? '$title - ${i + 1}');
    slides.add('''
    <div class="gallery-slide" id="$slideId" onclick="document.getElementById('${_idFor(img['url'] ?? '')}').classList.add('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="$altText" loading="lazy">
      $caption
    </div>''');
    dots.add(
      '<a href="#$slideId" class="gallery-dot${i == 0 ? ' active' : ''}" aria-label="${i + 1}"></a>',
    );
    lightboxes.add('''
    <div class="gallery-lightbox" id="${_idFor(img['url'] ?? '')}" onclick="this.classList.remove('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="$altText">
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
</section>
<script>
(function(){
  document.querySelectorAll('.gallery-section-slideshow').forEach(function(section){
    var slider = section.querySelector('.gallery-slideshow');
    var slides = Array.prototype.slice.call(section.querySelectorAll('.gallery-slide'));
    var dots = Array.prototype.slice.call(section.querySelectorAll('.gallery-dot'));
    if (!slider || slides.length < 2) return;

    var current = 0, isDown = false, startX = 0, scrollStart = 0, moved = false, autoTimer = null;

    function updateDots(){
      dots.forEach(function(d, i){ d.classList.toggle('active', i === current); });
    }
    function goTo(i){
      current = (i + slides.length) % slides.length;
      var target = slides[current];
      // NOT: scrollIntoView KULLANMA — 'block: nearest' verilse bile bazı
      // tarayıcılar/WebView'ler elemanı görünür kılmak için sayfanın dikey
      // scroll'unu da oynatabiliyor. Kullanıcı sayfayı aşağı kaydırmışken
      // otomatik geçiş tetiklenince sayfa galeriye geri sıçrıyordu. Bunun
      // yerine SADECE slider'ın kendi yatay scrollLeft'ini değiştiriyoruz;
      // bu, sayfanın geri kalanına asla dokunmaz.
      var targetLeft = target.offsetLeft - (slider.clientWidth - target.clientWidth) / 2;
      if (slider.scrollTo) {
        slider.scrollTo({ left: targetLeft, behavior: 'smooth' });
      } else {
        slider.scrollLeft = targetLeft;
      }
      updateDots();
    }
    var isVisible = true;
    function startAuto(){
      stopAuto();
      if (!isVisible) return;
      autoTimer = setInterval(function(){ goTo(current + 1); }, 4000);
    }
    function stopAuto(){
      if (autoTimer) { clearInterval(autoTimer); autoTimer = null; }
    }
    if (window.IntersectionObserver) {
      var io = new IntersectionObserver(function(entries){
        entries.forEach(function(entry){
          isVisible = entry.isIntersecting;
          if (isVisible) startAuto(); else stopAuto();
        });
      }, { threshold: 0.4 });
      io.observe(slider);
    }
    function syncFromScroll(){
      var mid = slider.scrollLeft + slider.clientWidth / 2;
      var closest = 0, closestDist = Infinity;
      slides.forEach(function(s, i){
        var d = Math.abs((s.offsetLeft + s.clientWidth / 2) - mid);
        if (d < closestDist) { closestDist = d; closest = i; }
      });
      current = closest;
      updateDots();
    }

    startAuto();
    slider.addEventListener('mouseenter', stopAuto);
    slider.addEventListener('mouseleave', function(){ if (!isDown) startAuto(); });

    slider.addEventListener('mousedown', function(e){
      isDown = true; moved = false; stopAuto();
      slider.classList.add('dragging');
      startX = e.pageX; scrollStart = slider.scrollLeft;
    });
    window.addEventListener('mouseup', function(){
      if (!isDown) return;
      isDown = false;
      slider.classList.remove('dragging');
      startAuto();
    });
    slider.addEventListener('mousemove', function(e){
      if (!isDown) return;
      var dx = e.pageX - startX;
      if (Math.abs(dx) > 5) moved = true;
      slider.scrollLeft = scrollStart - dx;
    });
    slider.addEventListener('click', function(e){
      if (moved) { e.stopPropagation(); e.preventDefault(); moved = false; }
    }, true);

    var scrollTimeout;
    slider.addEventListener('scroll', function(){
      clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(syncFromScroll, 100);
    });
    slider.addEventListener('touchstart', stopAuto);
    slider.addEventListener('touchend', function(){ setTimeout(startAuto, 300); });

    dots.forEach(function(d, i){
      d.addEventListener('click', function(e){
        e.preventDefault();
        stopAuto();
        goTo(i);
        startAuto();
      });
    });
  });
})();
</script>''';
}

/// 27.09.2026 eklendi (kanka isteği) — üçüncü galeri stili: yumuşak
/// crossfade (opacity, scroll-snap DEĞİL) + fotoğrafın altında başlık/
/// altyazı overlay'i + sağ-sol ok butonları + nokta göstergesi. `grid`/
/// `slideshow`'un aksine otomatik oynatma YOK (kanka isteği: sadece elle
/// gezinme) — kullanıcı deneyimini rahatsız etmesin diye bilinçli tercih.
/// Tıklanan görsel yine tam ekran lightbox'ta açılır (diğer 2 stille aynı
/// davranış).
String _galleryCrossfadeBlockHtml({
  required String title,
  required List<Map<String, String?>> images,
}) {
  final slides = <String>[];
  final dots = <String>[];
  final lightboxes = <String>[];
  for (var i = 0; i < images.length; i++) {
    final img = images[i];
    final url = img['url'] ?? '';
    final caption = img['caption'] != null
        ? '<span class="gallery-caption">${escapeHtml(img['caption']!)}</span>'
        : '';
    final altText = escapeHtml(img['caption'] ?? '$title - ${i + 1}');
    slides.add('''
    <div class="gallery-crossfade-slide${i == 0 ? ' active' : ''}" style="background-image:url('${escapeHtml(url)}')" onclick="document.getElementById('${_idFor(url)}').classList.add('open')" role="img" aria-label="$altText">
      $caption
    </div>''');
    dots.add('<span class="gallery-dot${i == 0 ? ' active' : ''}" data-index="$i"></span>');
    lightboxes.add('''
    <div class="gallery-lightbox" id="${_idFor(url)}" onclick="this.classList.remove('open')">
      <img src="${escapeHtml(url)}" alt="$altText">
    </div>''');
  }
  final arrowsHtml = images.length > 1
      ? '''
    <button type="button" class="gallery-crossfade-arrow prev" aria-label="Önceki görsel">&#8249;</button>
    <button type="button" class="gallery-crossfade-arrow next" aria-label="Sonraki görsel">&#8250;</button>'''
      : '';
  final dotsHtml = images.length > 1
      ? '''
  <div class="gallery-dots">
${dots.join('\n')}
  </div>'''
      : '';

  return '''
<section class="section gallery-section gallery-section-crossfade">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="gallery-crossfade">
    <div class="gallery-crossfade-stage">
${slides.join('\n')}
    </div>
$arrowsHtml
  </div>
$dotsHtml
${lightboxes.join('\n')}
</section>
<script>
(function(){
  document.querySelectorAll('.gallery-section-crossfade').forEach(function(section){
    var slides = Array.prototype.slice.call(section.querySelectorAll('.gallery-crossfade-slide'));
    var dots = Array.prototype.slice.call(section.querySelectorAll('.gallery-dot'));
    if (slides.length < 2) return;
    var current = 0;
    function goTo(i){
      current = (i + slides.length) % slides.length;
      slides.forEach(function(s, idx){ s.classList.toggle('active', idx === current); });
      dots.forEach(function(d, idx){ d.classList.toggle('active', idx === current); });
    }
    var prevBtn = section.querySelector('.gallery-crossfade-arrow.prev');
    var nextBtn = section.querySelector('.gallery-crossfade-arrow.next');
    if (prevBtn) prevBtn.addEventListener('click', function(e){ e.stopPropagation(); goTo(current - 1); });
    if (nextBtn) nextBtn.addEventListener('click', function(e){ e.stopPropagation(); goTo(current + 1); });
    dots.forEach(function(d, idx){
      d.addEventListener('click', function(e){ e.stopPropagation(); goTo(idx); });
    });
  });
})();
</script>''';
}

/// 28.09.2026 eklendi (kanka isteği) — beşinci galeri stili: editoryal
/// "bento" / mozaik ızgara (referans sitelerdeki gibi kartların farklı
/// boy-en oranlarında dizilmesiyle oluşan "tasarlanmış" görünüm). `grid`'in
/// aksine TÜM kartlar eş kare DEĞİL. Diğer stillerle BİREBİR aynı lightbox
/// davranışı kullanılıyor (bkz. [_idFor]).
///
/// Az sayıda görselde (3'ten az) mozaik anlamsız/boş görünür — bu durumda
/// sessizce 'grid' stiline düşer (bkz. _galleryMarqueeBlockHtml).
///
/// 28.09.2026 (2. tur) — ESKİ 6'lı döngüsel span deseni 5 görselde bile
/// boşluk bırakıyordu (kartların satır yükseklikleri birbirini tutmuyordu).
/// Artık görseller 1–5'lik BLOKLARA bölünüyor ve her blok 12 kolon x 6 satırlık
/// alanı boşluksuz (mükemmel döşeme) dolduruyor; bkz. [bentoBlockSizes].
String _galleryBentoBlockHtml({
  required String title,
  required List<Map<String, String?>> images,
}) {
  if (images.length < 3) {
    return galleryBlockHtml(title: title, images: images, style: 'grid');
  }

  const letters = ['a', 'b', 'c', 'd', 'e'];
  final sizes = bentoBlockSizes(images.length);
  final blocks = StringBuffer();
  final lightboxes = StringBuffer();
  var cursor = 0;
  for (var bi = 0; bi < sizes.length; bi++) {
    final n = sizes[bi];
    final flip = bi.isOdd ? ' gb-flip' : '';
    blocks.writeln('<div class="gb-block gb-n$n$flip">');
    for (var k = 0; k < n; k++) {
      final i = cursor + k;
      final img = images[i];
      final url = img['url'] ?? '';
      final caption = img['caption'] != null
          ? '<span class="gallery-caption">${escapeHtml(img['caption']!)}</span>'
          : '';
      final altText = escapeHtml(img['caption'] ?? '$title - ${i + 1}');
      blocks.writeln(
          '  <div class="gallery-bento-item gb-${letters[k]}" onclick="document.getElementById(\'${_idFor(url)}\').classList.add(\'open\')">\n'
          '    <img src="${escapeHtml(url)}" alt="$altText" loading="lazy">\n'
          '    $caption\n'
          '  </div>');
      lightboxes.writeln(
          '<div class="gallery-lightbox" id="${_idFor(url)}" onclick="this.classList.remove(\'open\')">\n'
          '  <img src="${escapeHtml(url)}" alt="$altText">\n'
          '</div>');
    }
    blocks.writeln('</div>');
    cursor += n;
  }

  return '''
<section class="section gallery-section gallery-section-bento">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="gallery-bento-grid">
$blocks  </div>
$lightboxes</section>''';
}

/// [count] görseli 1–5'lik bloklara böler. Hiçbir blok 5'ten büyük değil ve
/// asla tek başına 1 görsellik artık bırakılmaz (count >= 3 için). Örn:
/// 3->[3], 6->[3,3], 7->[3,4], 9->[4,5], 12->[3,4,5].
List<int> bentoBlockSizes(int count) {
  final out = <int>[];
  var rem = count;
  while (rem > 0) {
    int take;
    if (rem <= 5) {
      take = rem;
    } else if (rem == 6) {
      take = 3;
    } else {
      take = out.length.isEven ? 3 : 4;
    }
    out.add(take);
    rem -= take;
  }
  return out;
}

String _idFor(String url) => 'gal_${url.hashCode.abs()}';

/// 27.09.2026 eklendi (kanka isteği) — referans sitelerdeki sürekli kayan
/// (infinite scroll) galeri şeridi. TEK track iki kez art arda basılıp
/// %50 translateX ile sonsuz döngü illüzyonu saf CSS `@keyframes` ile
/// yaratılıyor — JS kütüphanesi/otomatik oynatma kodu YOK. Kullanıcı
/// üstüne gelince (`:hover`) veya dokununca (`:focus-within`, mobil için)
/// kayma durur; `prefers-reduced-motion: reduce` tercih edilmişse animasyon
/// hiç başlamaz (bkz. wrapPageHtml'deki ortak <style> bloğu). Tıklanan
/// görsel, diğer galeri stilleriyle BİREBİR aynı lightbox davranışını
/// kullanır (bkz. [_idFor]).
///
/// Az sayıda görselde (2'den az) kayma anlamsız/boş görünür — bu durumda
/// sessizce 'grid' stiline düşer (geriye dönük güvenli varsayılan).
String _galleryMarqueeBlockHtml({
  required String title,
  required List<Map<String, String?>> images,
}) {
  if (images.length < 2) {
    return galleryBlockHtml(title: title, images: images, style: 'grid');
  }

  String itemHtml(Map<String, String?> img, int i) {
    final url = img['url'] ?? '';
    final caption = img['caption'] != null
        ? '<span class="gallery-caption">${escapeHtml(img['caption']!)}</span>'
        : '';
    final altText = escapeHtml(img['caption'] ?? '$title - ${i + 1}');
    return '''
    <div class="gallery-marquee-item" onclick="document.getElementById('${_idFor(url)}').classList.add('open')">
      <img src="${escapeHtml(url)}" alt="$altText" loading="lazy">
      $caption
    </div>''';
  }

  final items = images.asMap().entries.map((e) => itemHtml(e.value, e.key)).join('\n');
  // Aynı öğeler İKİNCİ kez basılıyor (track %50 kayınca ilk kopyanın
  // bittiği yerde ikinci kopya başlıyor — göz, dikişi fark etmiyor).
  final trackHtml = '$items\n$items';
  final lightboxes = images.asMap().entries.map((e) {
    final img = e.value;
    final url = img['url'] ?? '';
    final altText = escapeHtml(img['caption'] ?? '$title - ${e.key + 1}');
    return '''
    <div class="gallery-lightbox" id="${_idFor(url)}" onclick="this.classList.remove('open')">
      <img src="${escapeHtml(url)}" alt="$altText">
    </div>''';
  }).join('\n');

  return '''
<section class="section gallery-section gallery-section-marquee">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="gallery-marquee-viewport">
    <div class="gallery-marquee-track">
$trackHtml
    </div>
  </div>
$lightboxes
</section>''';
}

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

/// Çalışma saatlerinden JS `hoursMap` girdileri üretir: `"1":{"start":"09:00","end":"19:00"}`.
/// Kapalı günler (range == null) ve ayrıştırılamayan aralıklar atlanır.
List<String> hoursMapEntriesJs(List<Map<String, String?>> hours) {
  final entries = <String>[];
  for (final h in hours) {
    final jsDay = _turkishDayToJsWeekday[h['day']];
    final range = h['range'];
    if (jsDay == null || range == null) continue;
    final parts = range.split('-').map((p) => p.trim()).toList();
    if (parts.length != 2) continue;
    entries.add('"$jsDay":{"start":${_jsStringLiteral(parts[0])},"end":${_jsStringLiteral(parts[1])}}');
  }
  return entries;
}

/// 29.09.2026 — Sitelerin açık/kapalı hesabında kullanılan varsayılan işletme
/// saat dilimi. Uygulamada henüz site başına saat dilimi alanı yok; hedef kitle
/// Türkiye olduğu için varsayılan Europe/Istanbul (UTC+3, yaz saati yok).
/// Ziyaretçi yurt dışından baksa bile durum İŞLETMENİN saatine göre hesaplanır.
/// Kullanıcı seçtiyse satırlardaki 'tz' değeri geçerlidir ([hoursTimeZoneFor]).
const String kDefaultBusinessTimeZone = 'Europe/Istanbul';

/// 29.09.2026 — hero hapı ve çalışma saatleri rozetinin ORTAK JS çekirdeği
/// (iki yerde kopya mantık kalmasın diye). Ne yapar:
///  - `sitoraNowIn(tz)`: verilen IANA saat dilimindeki gün (0=Pazar) ve
///    gün içi dakika. Intl yoksa/saat dilimi geçersizse cihaz saatine düşer.
///  - `sitoraHoursStatus(hoursMap, now)`: {open, end}. Gece yarısını geçen
///    vardiyaları (örn. 22:00 - 02:00) destekler: bitiş < başlangıç ise
///    başlangıçtan gece yarısına kadar VE ertesi günün bitişine kadar açıktır;
///    ertesi sabahki kısım önceki günün kaydından bulunur.
/// JS içinde `$` kullanılmaz (Dart enterpolasyonu) ve raw string'dir.
const String _hoursStatusJsCore = r'''
var sitoraNowIn = function(tz){
  try {
    var parts = new Intl.DateTimeFormat('en-US', {timeZone: tz, weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23'}).formatToParts(new Date());
    var o = {};
    parts.forEach(function(p){ o[p.type] = p.value; });
    var days = {Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6};
    if (days[o.weekday] === undefined) throw new Error('weekday');
    return {day: days[o.weekday], min: (parseInt(o.hour, 10) % 24) * 60 + parseInt(o.minute, 10)};
  } catch (e) {
    var d = new Date();
    return {day: d.getDay(), min: d.getHours() * 60 + d.getMinutes()};
  }
};
var sitoraToMin = function(s){ var p = String(s).split(':'); return (parseInt(p[0], 10) * 60) + parseInt(p[1] || '0', 10); };
var sitoraHoursStatus = function(hoursMap, now){
  var t = hoursMap[String(now.day)];
  if (t) {
    var s = sitoraToMin(t.start), e = sitoraToMin(t.end);
    if (e > s && now.min >= s && now.min < e) return {open: true, end: t.end};
    if (e < s && now.min >= s) return {open: true, end: t.end};
  }
  var prev = hoursMap[String((now.day + 6) % 7)];
  if (prev) {
    var ps = sitoraToMin(prev.start), pe = sitoraToMin(prev.end);
    if (pe < ps && now.min < pe) return {open: true, end: prev.end};
  }
  return {open: false, end: null};
};
''';

/// 29.09.2026 — Çalışma saatleri listesinden işletme saat dilimini okur.
/// Seçici (working_hours_picker_field.dart) her satıra `'tz': 'Europe/London'`
/// gibi bir anahtar ekler; böylece 26 form ekranına dokunmadan kayıt/geri yükleme
/// ve üretim akışıyla birlikte taşınır. Eski kayıtlarda anahtar yoktur → null
/// döner ve çağıran [kDefaultBusinessTimeZone]'a düşer. Geçersiz görünen
/// değerler (IANA biçimi dışı) yok sayılır.
String? hoursTimeZoneFor(List<Map<String, String?>>? hours) {
  if (hours == null) return null;
  final ok = RegExp(r'^[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)+$');
  for (final row in hours) {
    final tz = row['tz']?.trim();
    if (tz != null && tz.isNotEmpty && ok.hasMatch(tz)) return tz;
  }
  return null;
}

/// 28.09.2026 eklendi (kanka isteği) — hero'da (split/social düzeni) foto
/// üstünde canlı "Şu An Açık · Kapanış 19:00" / "Şu An Kapalı" hapı.
/// Saatler girilmemişse ('hours' bölümü gizlenmişse de) hiçbir şey basılmaz —
/// uydurma bilgi yok. Ziyaretçinin cihaz saatine göre JS ile hesaplanır
/// (workingHoursBlockHtml'deki rozetle aynı mantık); JS yoksa hap gizli kalır.
String heroStatusPillHtml(List<Map<String, String?>>? hours,
    {String lang = 'tr', String? timeZone}) {
  if (hours == null || hours.isEmpty) return '';
  final entries = hoursMapEntriesJs(hours);
  if (entries.isEmpty) return '';
  final tz = timeZone ?? hoursTimeZoneFor(hours) ?? kDefaultBusinessTimeZone;
  final labels = siteLabels(lang);
  final closesLabel = lang == 'en' ? 'Closes' : 'Kapanış';
  return '''
      <span class="hero-status-pill" id="hero-status" hidden></span>
      <script>
      (function(){
        var el = document.getElementById('hero-status');
        if (!el) return;
        var hoursMap = {${entries.join(',')}};
        ${_hoursStatusJsCore}
        var st = sitoraHoursStatus(hoursMap, sitoraNowIn(${_jsStringLiteral(tz)}));
        var isOpen = st.open;
        el.textContent = isOpen
          ? ${_jsStringLiteral(labels['openNowLabel'])} + ' \u00b7 ' + ${_jsStringLiteral(closesLabel)} + ' ' + st.end
          : ${_jsStringLiteral(labels['closedNowLabel'])};
        el.className = 'hero-status-pill ' + (isOpen ? 'is-open' : 'is-closed');
        el.hidden = false;
      })();
      </script>''';
}

/// Hero hapına verilecek saatler: kullanıcı 'hours' bölümünü gizlediyse null.
List<Map<String, String?>>? heroHoursFor(
    List<Map<String, String?>> hours, List<String>? sectionOrder) {
  if (hours.isEmpty) return null;
  if (sectionOrder != null && sectionOrder.isNotEmpty && !sectionOrder.contains('hours')) {
    return null;
  }
  return hours;
}

/// Çalışma saatleri tablosu + (01.09.2026 eklendi) ziyaretçinin KENDİ
/// cihaz saatine göre hesaplanan canlı "Şu An Açık / Kapalı" rozeti.
///
/// Rozet tamamen istemci tarafında (JS) hesaplanır — sunucu/worker
/// tarafında hiçbir değişiklik gerekmez, ekstra ağ isteği atmaz. [hours]
/// içindeki "09:00 - 19:00" gibi aralıklar desteklenir. 29.09.2026: gece
/// yarısını geçen vardiyalar ("22:00 - 02:00") artık doğru hesaplanır ve durum
/// ziyaretçinin değil İŞLETMENİN saat dilimine ([timeZone]) göre bulunur
/// (bkz. [_hoursStatusJsCore]).
String workingHoursBlockHtml({
  required String title,
  required List<Map<String, String?>> hours, // day, range (null = kapalı)
  String lang = 'tr',
  bool showLiveBadge = true,
  String? timeZone, // null → satırlardaki 'tz' → kDefaultBusinessTimeZone
}) {
  final tz = timeZone ?? hoursTimeZoneFor(hours) ?? kDefaultBusinessTimeZone;
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
    final entries = hoursMapEntriesJs(hours);
    badgeScript = '''
  <script>
  (function(){
    var badge = document.getElementById(${_jsStringLiteral(badgeId)});
    if (!badge) return;
    var hoursMap = {${entries.join(',')}};
    ${_hoursStatusJsCore}
    var isOpen = sitoraHoursStatus(hoursMap, sitoraNowIn(${_jsStringLiteral(tz)})).open;
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

/// 05.09.2026 eklendi — Video bloğu (kanka isteği: "sitede güzel görünsün,
/// dikey/yatay ikisi de sorunsuz oynasın").
///
/// [mapBlockHtml] ile BİREBİR AYNI felsefe: kullanıcı bir YouTube/Vimeo
/// LİNKİ yapıştırır, biz bunu `<iframe>` olarak gömeriz. Video verisinin
/// TAMAMI YouTube/Vimeo sunucularından ziyaretçiye akar — worker hiçbir
/// byte'ı proxy'lemez, R2'ye video yüklenmez, ekstra worker request/CPU
/// time YOKTUR. Maliyet mevcut Maps embed'iyle birebir aynı (sıfıra yakın).
///
/// [orientation] 'landscape' (yatay, normal 16:9 video) veya 'portrait'
/// (dikey, Shorts/Reels tarzı 9:16 video) olabilir. Bu, kutunun sadece
/// en-boy oranını değil MAKSİMUM GENİŞLİĞİNİ de belirler — aksi halde dikey
/// bir video, yatay video için tasarlanmış geniş kutuda ortasında dev siyah
/// boşluklarla (letterbox) görünürdü. Portrait modda kutu daralıp bir telefon
/// ekranı gibi zarif durur; landscape modda tam genişlik kullanır. İkisi de
/// `.section` (max-width:720px) içinde, sitenin genel tema/renk/köşe
/// yuvarlaklığı diliyle uyumlu — tasarımı bozmaz, aksine bir "medya" bloğu
/// olarak zenginleştirir.
///
/// Link tanınmazsa (desteklenmeyen bir platform/hatalı URL) boş string
/// döner — çağıran taraf bu durumda bloğu hiç yazmamalı (bkz. generator'lardaki
/// çağrı noktaları: `if (videoUrl != null && videoUrl.isNotEmpty) ...`).
String videoBlockHtml({
  required String title,
  required String videoUrl,
  String orientation = 'landscape', // 'landscape' (yatay) | 'portrait' (dikey)
  String lang = 'tr',
}) {
  final embedUrl = videoEmbedUrl(videoUrl);
  if (embedUrl == null) return '';
  final wrapClass = orientation == 'portrait'
      ? 'video-embed-wrap portrait'
      : 'video-embed-wrap landscape';
  return '''
<section class="section video-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="$wrapClass">
    <iframe
      src="${escapeHtml(embedUrl)}"
      title="${escapeHtml(title)}"
      loading="lazy"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      referrerpolicy="strict-origin-when-cross-origin"
      allowfullscreen
      frameborder="0">
    </iframe>
  </div>
</section>''';
}

/// [videoUrl]'ı (YouTube/Vimeo "izleme" linki) `<iframe>` ile gömülebilir
/// bir "embed" linkine çevirir. Desteklenenler:
///  - youtu.be/ID
///  - youtube.com/watch?v=ID
///  - youtube.com/shorts/ID   (dikey Shorts linkleri)
///  - youtube.com/embed/ID    (zaten embed ise dokunmadan döner)
///  - vimeo.com/ID
///  - player.vimeo.com/video/ID (zaten embed ise dokunmadan döner)
/// Tanınmayan bir link için null döner.
String? videoEmbedUrl(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  if (host.contains('youtu.be')) {
    if (segments.isEmpty) return null;
    return 'https://www.youtube.com/embed/${segments.first}';
  }
  if (host.contains('youtube.com')) {
    if (segments.contains('embed')) return url;
    if (segments.contains('shorts')) {
      final idx = segments.indexOf('shorts');
      if (segments.length <= idx + 1) return null;
      return 'https://www.youtube.com/embed/${segments[idx + 1]}';
    }
    final id = uri.queryParameters['v'];
    if (id == null || id.isEmpty) return null;
    return 'https://www.youtube.com/embed/$id';
  }
  if (host.contains('vimeo.com')) {
    if (host.contains('player.vimeo.com')) return url;
    if (segments.isEmpty) return null;
    final id = segments.last;
    if (int.tryParse(id) == null) return null;
    return 'https://player.vimeo.com/video/$id';
  }
  return null;
}

/// 05.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği,
/// madde 4: "Bizi Google'da Değerlendirin" butonu).
///
/// [googleReviewLink] doluysa VE [FreePlanRestrictionService.
/// isPremiumGeneration] true ise (bkz. o servisteki flag dokümanı — TALEP
/// FORMU ile AYNI merkezi kilit noktası) `<a class="contact-btn review">`
/// linkini döner; free plan'da site üretilirken (isPremiumGeneration false)
/// link doluysa BİLE boş string döner — buton hiç yazılmaz. Tek bir yerden
/// (bkz. contactBlockHtml + portfolio/real_estate generator'larındaki
/// çağrı noktaları) çağrılarak "girişte kilitli" (bkz. GoogleReviewLinkField
/// — free kullanıcı zaten bu alana link giremiyor) ile AYNI kuralın çıktı
/// tarafındaki tek güvenlik ağı olması sağlanıyor.
String googleReviewButtonHtml(String? googleReviewLink, {String lang = 'tr'}) {
  if (googleReviewLink == null || googleReviewLink.trim().isEmpty) return '';
  if (!FreePlanRestrictionService.isPremiumGeneration) return '';
  final labels = siteLabels(lang);
  return '<a class="contact-btn review" target="_blank" href="${escapeHtml(googleReviewLink.trim())}">${escapeHtml(labels['googleReviewButton']!)}</a>';
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
///
/// 05.09.2026 eklendi — [includeLeadForm] true olsa BİLE, free plan'da site
/// üretilirken (bkz. FreePlanRestrictionService.isPremiumGeneration) talep
/// formu yine de yazılmaz; bu ikinci (ve asıl) kilit noktasıdır.
/// 23.09.2026 eklendi (kanka isteği) — WhatsApp butonlarında generic 💬
/// emoji yerine tanınabilir bir "ahize + konuşma balonu" WhatsApp ikonu.
/// Tüm sektör şablonlarında ortak kullanılsın diye tek yerden (bu dosya)
/// besleniyor — contactBlockHtml ve floatingContactButtonHtml ikisi de
/// buradan çağırıyor.
const String _whatsappIconSvg =
    '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" style="vertical-align:-4px;margin-right:2px"><path d="M17.6 6.3A8.86 8.86 0 0 0 12.05 4a8.87 8.87 0 0 0-8.9 8.9c0 1.57.41 3.1 1.19 4.45L4 22l4.79-1.26a9 9 0 0 0 4.29 1.09 8.87 8.87 0 0 0 8.9-8.9 8.8 8.8 0 0 0-2.58-5.63zM12.05 20.15a7.4 7.4 0 0 1-3.77-1.03l-.27-.16-2.83.74.76-2.75-.18-.28a7.36 7.36 0 0 1-1.13-3.93 7.4 7.4 0 0 1 7.42-7.4 7.35 7.35 0 0 1 5.24 2.17 7.33 7.33 0 0 1 2.16 5.22 7.4 7.4 0 0 1-7.4 7.42zm4.06-5.56c-.22-.11-1.31-.65-1.51-.72-.2-.07-.35-.11-.5.11-.15.22-.57.72-.7.87-.13.15-.26.16-.48.05-.22-.11-.93-.34-1.77-1.09-.65-.58-1.09-1.3-1.22-1.52-.13-.22-.01-.34.1-.45.1-.1.22-.26.33-.39.11-.13.15-.22.22-.37.07-.15.04-.28-.02-.39-.06-.11-.5-1.21-.69-1.66-.18-.43-.37-.37-.5-.38-.13-.01-.28-.01-.43-.01a.83.83 0 0 0-.6.28c-.2.22-.79.77-.79 1.87s.81 2.17.92 2.32c.11.15 1.6 2.44 3.87 3.42.54.23.96.37 1.29.48.54.17 1.03.15 1.42.09.43-.06 1.31-.54 1.5-1.06.18-.52.18-.96.13-1.06-.05-.1-.2-.16-.42-.27z"/></svg>';

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
    buttons.add('<a class="contact-btn phone" href="tel:${escapeHtml(phone)}"><i class="fa-solid fa-phone" style="margin-right:6px"></i> $callText</a>');
  }
  if (whatsapp != null) {
    buttons.add('<a class="contact-btn whatsapp" target="_blank" href="https://wa.me/${escapeHtml(whatsapp)}">$_whatsappIconSvg WhatsApp</a>');
  }
  if (instagram != null) {
    buttons.add('<a class="contact-btn instagram" target="_blank" href="https://instagram.com/${escapeHtml(instagram)}"><i class="fa-brands fa-instagram" style="margin-right:6px"></i> Instagram</a>');
  }
  final reviewBtn = googleReviewButtonHtml(googleReviewLink, lang: lang);
  if (reviewBtn.isNotEmpty) {
    buttons.add(reviewBtn);
  }
  // 05.09.2026 değişti (kanka isteği) — talep formu artık ÇIKTIDA regex ile
  // temizlenmiyor, ÜRETİM ANINDA hiç yazılmıyor: FreePlanRestrictionService.
  // isPremiumGeneration false ise (free plan'da site üretilirken)
  // leadFormMarkup hiç çağrılmaz. Bkz. o servisteki flag dokümanı ve
  // LocalGenerationHelper (flag'i generation'dan hemen önce/sonra set eden
  // tek nokta).
  final leadForm = (includeLeadForm && FreePlanRestrictionService.isPremiumGeneration)
      ? leadFormMarkup(lang: lang, siteName: siteName)
      : '';
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
///
/// 05.09.2026 değişti (kanka isteği) — telefon artık ZORUNLU değil, e-posta
/// alanı eklendi. Bazı ziyaretçiler telefon numarası paylaşmaya çekiniyor;
/// artık isim + (telefon VEYA e-posta) yeterli. İkisi de boşsa gönderim
/// engellenir (bkz. aşağıdaki JS + worker tarafındaki aynı kural,
/// handleLeadCreate).
String leadFormMarkup({String lang = 'tr', String siteName = ''}) {
  final l = siteLabels(lang);
  return '''
  <form id="sitora-lead-form" class="sitora-lead-form" onsubmit="return false;">
    <input id="sitora-lead-name" type="text" placeholder="${escapeHtml(l['yourName']!)}" required>
    <input id="sitora-lead-phone" type="tel" placeholder="${escapeHtml(l['yourPhone']!)}">
    <input id="sitora-lead-email" type="email" placeholder="${escapeHtml(l['yourEmail']!)}">
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
    var LBL_NEED_CONTACT = ${_jsStringLiteral(l['contactMethodHint'])};
    var LBL_MAIL_OPENED = ${_jsStringLiteral(l['requestEmailOpened'])};
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
    //
    // 15.09.2026 eklendi (kanka isteği) — site sahibi artık "Talepler
    // nereye gelsin?" seçimini yayınlarken yapıyor (bkz. publish_sheet.dart
    // ve hosting_service.dart > _injectLeadConfig): window.__SITORA_LEAD__
    // içine `leadDelivery` ('box' | 'email' | 'both') ve gerekiyorsa
    // `leadEmail` gömülüyor. BİLİNÇLİ OLARAK Resend/başka bir ücretli mail
    // API'si KULLANILMIYOR — worker'a hiç dokunulmuyor. 'email'/'both'
    // modunda tarayıcı `mailto:` linkini AÇAR, e-postayı ZİYARETÇİNİN
    // kendi mail uygulaması/istemcisi üzerinden (kendi "Gönder"ine basarak)
    // yollar. Bu yüzden sınırsız ve tamamen ücretsizdir, ama sunucu tarafı
    // bir onay/garanti VEREMEZ — ziyaretçi mail uygulamasını kapatırsa
    // gönderim gerçekleşmez, bu normal ve beklenen bir sınırlamadır.
    function submitToBox(payload) {
      return fetch('/api/leads', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
    }
    function openMailto(cfg, payload) {
      var toEmail = (cfg.leadEmail || '').trim();
      if (!toEmail) return false;
      var subject = SITE_NAME ? (SITE_NAME + ' — Yeni Talep') : 'Yeni Talep';
      var lines = [];
      lines.push(payload.name);
      if (payload.phone) lines.push(payload.phone);
      if (payload.email) lines.push(payload.email);
      if (payload.message) lines.push('');
      if (payload.message) lines.push(payload.message);
      var body = lines.join('\\n');
      var mailto = 'mailto:' + toEmail + '?subject=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);
      var a = document.createElement('a');
      a.href = mailto;
      a.style.display = 'none';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      return true;
    }
    form.addEventListener('submit', function(e){
      e.preventDefault();
      var cfg = window.__SITORA_LEAD__ || {};
      var name = document.getElementById('sitora-lead-name').value.trim();
      var phone = document.getElementById('sitora-lead-phone').value.trim();
      var email = document.getElementById('sitora-lead-email').value.trim();
      var message = document.getElementById('sitora-lead-message').value.trim();
      if (!name) return;
      if (!phone && !email) {
        status.textContent = LBL_NEED_CONTACT;
        return;
      }
      var payload = {
        ownerUid: cfg.ownerUid || '',
        siteId: cfg.siteId || '',
        siteName: cfg.siteName || SITE_NAME || '',
        name: name,
        phone: phone,
        email: email,
        message: message
      };
      var delivery = cfg.leadDelivery || 'box';

      // 'email' modu: HİÇBİR ağ isteği atılmaz, sadece mailto açılır —
      // worker'a/Firestore'a hiç dokunulmaz.
      if (delivery === 'email') {
        var opened = openMailto(cfg, payload);
        if (opened) {
          status.textContent = LBL_MAIL_OPENED;
          form.reset();
        } else {
          // leadEmail hiç ayarlanmamışsa (beklenmedik durum) sessizce
          // Talep Kutusu'na düşerek talebi yine de kaybetmemek için.
          btn.disabled = true;
          status.textContent = LBL_SENDING;
          submitToBox(payload).then(function(res){
            btn.disabled = false;
            if (res.ok) { status.textContent = LBL_OK; form.reset(); }
            else { status.textContent = LBL_FAIL; }
          }).catch(function(){
            btn.disabled = false;
            status.textContent = LBL_FAIL;
          });
        }
        return;
      }

      // 'both' modu: mailto HEMEN açılır (kullanıcı etkileşimi gerektiği
      // için submit anında tetiklenmeli) + Talep Kutusu'na da (Firestore)
      // yazılır, böylece işletme sahibi uygulama içinden de görür.
      if (delivery === 'both') {
        openMailto(cfg, payload);
      }

      btn.disabled = true;
      status.textContent = LBL_SENDING;
      submitToBox(payload).then(function(res){
        btn.disabled = false;
        if (res.ok) {
          status.textContent = delivery === 'both' ? LBL_MAIL_OPENED : LBL_OK;
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
        ? '<div class="testimonial-stars">' + (List.filled(rating, '<i class="fa-solid fa-star"></i>').join()) + (List.filled(5 - rating, '<i class="fa-regular fa-star"></i>').join()) + '</div>'
        : '';
    // 28.09.2026 eklendi (kanka isteği) — gerçek fotoğraf istenmiyor
    // (yorum formunda foto alanı yok, uydurma stok fotoğraf da basılmaz);
    // bunun yerine isimden CSS-only, marka rengiyle bir "baş harf" avatarı
    // üretiliyor — okuyucu için "gerçek bir insan" hissini güçlendiriyor.
    final initial = escapeHtml(name.trim().substring(0, 1).toUpperCase());
    return '''
    <div class="testimonial-card">
      $stars
      <p class="testimonial-text">"${escapeHtml(text)}"</p>
      <div class="testimonial-person">
        <span class="testimonial-avatar" aria-hidden="true">$initial</span>
        <span class="testimonial-name">${escapeHtml(name)}</span>
      </div>
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

/// Yasal bilgi rozetlerinde kullanılan alerjen/et türü değerleri (formda
/// Türkçe saklanır, bkz. widgets/menu_legal_info_field.dart) — İngilizce
/// sitede çevrilir. Listede olmayan değer olduğu gibi basılır.
const Map<String, String> _legalTermsEn = {
  'Gluten': 'Gluten',
  'Süt': 'Dairy',
  'Yumurta': 'Egg',
  'Yer Fıstığı': 'Peanuts',
  'Kuruyemiş': 'Tree nuts',
  'Soya': 'Soy',
  'Balık': 'Fish',
  'Kabuklu Deniz Ürünleri': 'Crustaceans',
  'Yumuşakçalar': 'Molluscs',
  'Susam': 'Sesame',
  'Kereviz': 'Celery',
  'Hardal': 'Mustard',
  'Acı Bakla': 'Lupin',
  'Sülfit': 'Sulphites',
  'Vejetaryen': 'Vegetarian',
  'Vegan': 'Vegan',
  'Dana': 'Beef',
  'Kuzu': 'Lamb',
  'Tavuk': 'Chicken',
  'Diğer': 'Other',
};

String _legalTerm(String value, String lang) =>
    lang == 'en' ? (_legalTermsEn[value] ?? value) : value;

/// Menü bloğu (kategori + ürün) — kafe/restoran için. [lang]: sitenin dili
/// ('tr' | 'en'), yasal bilgi rozetlerinin dilini belirler.
String menuBlockHtml({
  required String title,
  required List<Map<String, dynamic>> categories, // {title, items:[{name,description,price}]}
  String lang = 'tr',
}) {
  final labels = siteLabels(lang);
  final catHtml = categories.map((cat) {
    final items = (cat['items'] as List).map((item) {
      final desc = item['description'] != null && (item['description'] as String).isNotEmpty
          ? '<p class="menu-item-desc">${escapeHtml(item['description'])}</p>'
          : '';
      // 19.09.2026 eklendi (kanka isteği) — ürün bazlı yasal bilgi rozetleri
      // (alerjen/kalori/et türü/alkol-domuz), bkz. widgets/menu_legal_info_field.dart
      // ve qt_form_data_codec.dart > qtMergeMenuLegalInfo. Abonelik ile kilitli;
      // 'legal' anahtarı sadece abone kullanıcıların ürettiği sitelerde dolu gelir.
      String legalHtml = '';
      final legal = item['legal'];
      if (legal is Map) {
        final badges = <String>[];
        final allergens = legal['allergens'];
        if (allergens is List && allergens.isNotEmpty) {
          final names = allergens.map((a) => _legalTerm(a.toString(), lang)).join(', ');
          badges.add(
              '<span class="menu-item-badge menu-item-badge-allergen"><i class="fa-solid fa-triangle-exclamation" style="margin-right:5px"></i>${escapeHtml(labels['legalAllergen']!)}: ${escapeHtml(names)}</span>');
        }
        // Kalori kullanıcı girdisi — HER ZAMAN escape (formda rakam filtresi
        // var ama eski/elle düzenlenmiş kayıtlara güvenilmez).
        final calories = legal['calories']?.toString() ?? '';
        if (calories.isNotEmpty) {
          badges.add('<span class="menu-item-badge"><i class="fa-solid fa-fire" style="margin-right:5px"></i>${escapeHtml(calories)} kcal</span>');
        }
        final meatType = legal['meatType']?.toString() ?? '';
        if (meatType.isNotEmpty) {
          badges.add('<span class="menu-item-badge">${escapeHtml(_legalTerm(meatType, lang))}</span>');
        }
        if (legal['alcohol'] == true) {
          badges.add('<span class="menu-item-badge menu-item-badge-warn">${escapeHtml(labels['legalAlcohol']!)}</span>');
        }
        if (legal['pork'] == true) {
          badges.add('<span class="menu-item-badge menu-item-badge-warn">${escapeHtml(labels['legalPork']!)}</span>');
        }
        // Eski (tek switch'li) kayıt: alcohol/pork ayrımı yapılmamışsa
        // birleşik rozet basılır (bkz. qtNormalizeMenuLegalEntry).
        if (legal['altPork'] == true && legal['alcohol'] != true && legal['pork'] != true) {
          badges.add('<span class="menu-item-badge menu-item-badge-warn">${escapeHtml(labels['legalAltPork']!)}</span>');
        }
        if (badges.isNotEmpty) {
          legalHtml = '<div class="menu-item-legal">${badges.join('')}</div>';
        }
      }
      return '''
      <li class="menu-item">
        <div class="menu-item-main">
          <span class="menu-item-name">${escapeHtml(item['name'] ?? '')}</span>
          <span class="menu-item-price">${escapeHtml(item['price'] ?? '')}</span>
        </div>
        $desc
        $legalHtml
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
      <img class="team-photo" src="${escapeHtml(m['photoUrl']?.toString() ?? '')}" alt="${escapeHtml(m['name']?.toString() ?? '')}">
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
  <img class="practitioner-photo" src="${escapeHtml(photoUrl)}" alt="${escapeHtml(name)}${title.isNotEmpty ? ' - ' + escapeHtml(title) : ''}">
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
///
/// 05.09.2026 itibarıyla (kanka isteği) HİÇBİR generator tarafından
/// çağrılmıyor — Portfolyo, Emlak ve Klinik'teki tüm kullanımları
/// [contactBlockHtml] (Talep Kutusu formu) ile değiştirildi, çünkü mailto
/// tarayıcının kendi mail istemcisine bağımlı (çoğu telefonda ayarlı
/// olmayabiliyor) ve gönderilen talepler hiçbir yerde birikmiyordu — Talep
/// Kutusu hem "Gelen Talepler" ekranında görünür hem de anlık push
/// bildirimi tetikler. Fonksiyon geriye dönük uyumluluk / olası tekil
/// kullanım ihtimaline karşı silinmedi, şu an ölü kod.
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
      <img src="${escapeHtml(l['coverImage'] ?? '')}" alt="${escapeHtml(l['title'] ?? '')}">
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
      <img src="${escapeHtml(it['coverImage'] ?? '')}" alt="${escapeHtml(it['title'] ?? '')}">
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
  final addToContactsText = lang == 'en' ? '<i class="fa-solid fa-address-card" style="margin-right:6px"></i> Add to Contacts' : '<i class="fa-solid fa-address-card" style="margin-right:6px"></i> Kişiye Ekle';
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
  // 06.09.2026 eklendi (kanka isteği) — "daha profesyonel görünümde,
  // ücretli katmana kilitli" 3 yeni tema. Görsel olarak yukarıdaki 5
  // ücretsiz temadan BİLİNÇLİ olarak ayrışıyorlar (koyu lüks/gold, cam
  // efekti, zümrüt/butik) — free kullanıcı sitesiyle yan yana konunca
  // "bariz daha profesyonel" hissi vermesi amaçlanıyor. Kilitleme burada
  // DEĞİL — bkz. [premiumThemeIds] ve LocalGenerationHelper'daki gate;
  // bu map'e eklenmiş olmaları TEK BAŞINA seçilebilir olmalarına yeter,
  // ThemePickerField'da herkese AÇIK gösterilirler (kanka kararı: şablon
  // tamamen açık görünsün, kilit sadece "Oluştur"a basınca çıksın).
  'obsidian_gold': {
    'bg': '#0B0B0D',
    'text': '#F5F1E8',
    'subtext': '#B8B0A0',
    'cardBg': '#17161A',
    'border': '#2A2820',
    'chipBg': '#1D1B17',
    'accent': '#C9A24B',
    'accentText': '#0B0B0D',
  },
  'glass_frost': {
    'bg': 'linear-gradient(160deg,#EEF3FB,#DCE6F5)',
    'text': '#1B2430',
    'subtext': '#5B6B82',
    'cardBg': 'rgba(255,255,255,0.6)',
    'border': 'rgba(255,255,255,0.8)',
    'chipBg': 'rgba(255,255,255,0.5)',
    'accent': '#3D5AFE',
    'accentText': '#FFFFFF',
  },
  'royal_emerald': {
    'bg': '#0E2A22',
    'text': '#F4F1E9',
    'subtext': '#A9C2B7',
    'cardBg': '#153B30',
    'border': '#28564A',
    'chipBg': '#153B30',
    'accent': '#D8B26B',
    'accentText': '#0E2A22',
  },
};

/// Premium (ücretli katman) renk temaları — bkz. yukarıdaki 06.09.2026
/// notu. [LocalGenerationHelper] "Oluştur"a basılma anında bu kümeye
/// bakıp free kullanıcıyı kilitler; ThemePickerField seçim aşamasında
/// HİÇBİR ŞEYİ engellemez.
const Set<String> premiumThemeIds = {'obsidian_gold', 'glass_frost', 'royal_emerald'};

bool isPremiumTheme(String? themeId) => premiumThemeIds.contains(themeId);

/// Premium hero DÜZEN stilleri — bkz. [heroBlockHtml]'deki 'framed'
/// seçeneği. 'centered' ve 'editorial' her zaman ücretsiz kalır.
// 27.09.2026 eklendi — split/diagonal önce PREMİUM olarak eklenmişti,
// sonra kanka kararı: rakiplerin büyük çoğunluğu (Squarespace, Wix vb.)
// hero/şablon düzenini free katmanda tuttuğu için kilidi kaldırdık.
// 28.09.2026 (kanka kararı): 'framed' da ücretsiz yapıldı — artık premium
// hero düzeni YOK. Set bilerek boş bırakıldı (gate altyapısı yerinde; ileride
// yeni bir premium düzen eklenirse buraya id yazmak yeterli).
const Set<String> premiumLayoutStyleIds = <String>{};

bool isPremiumLayoutStyle(String? layoutStyle) => premiumLayoutStyleIds.contains(layoutStyle);
Map<String, String> themeOf(String? themeId) =>
    siteThemes[themeId] ?? siteThemes['clean_light']!;

/// Bir temanın tek bir vurgu rengine ihtiyaç duyan, wrapPageHtml DIŞINDA
/// (örn. generator'ın kendi inline stilinde) kullanılan yerler için kısayol.
String themeAccent(String? themeId) => themeOf(themeId)['accent']!;

/// 17.09.2026 eklendi (kanka isteği — "Özel Renk" B seçeneği) — kullanıcı
/// hazır [siteThemes] paletlerinden birini seçmek yerine kendi
/// bg/text/cardBg/accent renklerini girebilsin diye eklendi. Bu fonksiyon
/// [customTheme] verilmişse onu (eksik anahtarları 'clean_light'tan
/// tamamlayarak) kullanır, verilmemişse eskisi gibi [themeOf] üzerinden
/// küratörlü paletlere döner — yani mevcut hiçbir çağrı kırılmaz.
///
/// customTheme haritasındaki geçerli anahtarlar: 'bg', 'text', 'subtext',
/// 'cardBg', 'border', 'chipBg', 'accent', 'accentText'. Kullanıcıdan
/// pratikte sadece 'bg', 'text', 'cardBg', 'accent' istenir (form
/// tarafında bkz. ThemePickerField "Özel Tema" modu); 'subtext', 'border',
/// 'chipBg' verilmezse 'text'/'accent'ten otomatik türetilir ve
/// 'accentText' verilmezse [autoContrastTextColor] ile accent'e göre otomatik
/// beyaz/siyah seçilir — kullanıcı kötü bir vurgu rengi seçse bile buton
/// yazısı okunamaz hale gelmesin diye (bkz. dosya başındaki "kontrast
/// riski" notu).
Map<String, String> resolveTheme(String? themeId, Map<String, String>? customTheme) {
  if (customTheme == null || customTheme.isEmpty) return themeOf(themeId);
  final base = siteThemes['clean_light']!;
  final bg = customTheme['bg'] ?? base['bg']!;
  final text = customTheme['text'] ?? base['text']!;
  final accent = customTheme['accent'] ?? base['accent']!;
  final cardBg = customTheme['cardBg'] ?? bg;
  return {
    'bg': bg,
    'text': text,
    'subtext': customTheme['subtext'] ?? text,
    'cardBg': cardBg,
    'border': customTheme['border'] ?? hexToRgba(text, 0.14),
    'chipBg': customTheme['chipBg'] ?? cardBg,
    'accent': accent,
    'accentText': customTheme['accentText'] ?? autoContrastTextColor(accent),
  };
}

/// [hex] bir '#RRGGBB' rengiyse rgba(...) olarak [alpha] saydamlıkla
/// döner; gradient/rgba gibi düz hex OLMAYAN bir değer gelirse (kullanıcı
/// arka plana gradient girmemesi beklenir ama savunma amaçlı) olduğu gibi
/// bırakılır — border/chipBg gibi ikincil alanlar için "yeterince iyi"
/// bir varsayılan üretir, tasarım hassasiyeti gerektirmez.
String hexToRgba(String hex, double alpha) {
  final c = parseHexColor(hex);
  if (c == null) return hex;
  return 'rgba(${c[0]},${c[1]},${c[2]},$alpha)';
}

/// WCAG'ın basitleştirilmiş göreli parlaklık formülüyle [bgHex] üzerinde
/// okunaklı olacak metin rengini ('#111111' ya da '#FFFFFF') seçer.
/// Kullanıcı çok açık bir vurgu rengi seçerse koyu metin, koyu bir vurgu
/// seçerse beyaz metin döner — "özel renk kötü kombinasyon → okunmaz buton
/// yazısı" riskine karşı otomatik güvenlik ağı (bkz. görev notu B maddesi).
String autoContrastTextColor(String hex) {
  final c = parseHexColor(hex);
  if (c == null) return '#FFFFFF';
  // Relative luminance (sRGB gamma yaklaşıklaması olmadan, basit ağırlıklı
  // ortalama — buton metni kontrastı için yeterli hassasiyette).
  final luminance = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255;
  return luminance > 0.6 ? '#111111' : '#FFFFFF';
}

/// '#RGB' veya '#RRGGBB' formatını [r,g,b] (0-255) olarak parse eder;
/// gradient/rgba gibi hex olmayan bir değer gelirse null döner.
List<int>? parseHexColor(String input) {
  var h = input.trim();
  if (!h.startsWith('#')) return null;
  h = h.substring(1);
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length != 6) return null;
  final r = int.tryParse(h.substring(0, 2), radix: 16);
  final g = int.tryParse(h.substring(2, 4), radix: 16);
  final b = int.tryParse(h.substring(4, 6), radix: 16);
  if (r == null || g == null || b == null) return null;
  return [r, g, b];
}

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

/// 18.09.2026 eklendi (kanka isteği — "Serbest Font Seçimi") — küratörlü
/// paketlerin YANI SIRA, kullanıcı artık başlık/gövde için Google
/// Fonts'tan DİLEDİĞİ ismi seçebilir (bkz. TypographyPickerField "Serbest
/// Font Seçimi" çipi — arama kutusu [kCuratedGoogleFontNames] listesi
/// üzerinde çalışır, yani her zaman GEÇERLİ bir Google Fonts ailesi
/// seçilmiş olur). Sentinel id — [siteThemes]'teki 'custom' deseniyle
/// BİREBİR AYNI mantık (bkz. [ThemePickerField.customThemeId]).
const String customFontPackageId = 'custom_font';

/// PREMİUM (ücretli katman) — bkz. dosya başındaki not: "Özel Font — EN
/// RİSKLİ" (heading+body uyumu garanti EDİLEMEZ, kullanıcı kötü bir
/// kombinasyon seçebilir). [premiumThemeIds]/[premiumLayoutStyleIds] ile
/// BİREBİR AYNI desen: bu kümeye bakıp free kullanıcıyı SADECE
/// "Oluştur"a basılma anında kilitleyen [LocalGenerationHelper]'daki
/// gate'e bkz. Seçim aşamasında (TypographyPickerField) HİÇBİR ŞEY
/// engellenmez — kanka kararı: şablon tamamen açık görünsün.
const Set<String> premiumFontPackageIds = {customFontPackageId};

bool isPremiumFontPackage(String? fontPackageId) => premiumFontPackageIds.contains(fontPackageId);

/// Kullanıcının serbest seçtiği bir Google Fonts adını hem CSS
/// font-family değeri hem de css2 API URL'i için güvenli hale getirir.
/// [kCuratedGoogleFontNames] listesinden geldiği için pratikte harf/rakam/
/// boşluk dışında bir karakter gelmez, ama URL/CSS'e giden TEK giriş
/// noktası burası olduğundan savunma amaçlı yine de süzülür (renk
/// alanlarındaki [_isValidHex] kontrolüyle aynı temkinli yaklaşım).
String _sanitizeGoogleFontName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim();
  return cleaned.isEmpty ? 'Inter' : cleaned;
}

String _googleFontsUrlName(String name) => _sanitizeGoogleFontName(name).replaceAll(' ', '+');

/// [resolveTheme] ile BİREBİR AYNI mantık (bkz. o fonksiyonun dokümanı) —
/// [customFontPackage] {'heading':..., 'body':...} verilmişse onu
/// kullanır (biri boşsa diğerinden, o da boşsa 'Inter'den tamamlanır),
/// verilmemişse eskisi gibi [fontPackageOf] üzerinden küratörlü pakete
/// döner. Mevcut hiçbir çağrı kırılmaz. Aynı aile heading+body'de de
/// kullanılıyorsa googleFontsHref'e TEK family eklenir (gereksiz ikinci
/// istek/ağırlık indirilmesin diye).
Map<String, String> resolveFontPackage(String? fontPackageId, Map<String, String>? customFontPackage) {
  if (customFontPackage == null || customFontPackage.isEmpty) {
    return fontPackageOf(fontPackageId);
  }
  final rawHeading = (customFontPackage['heading'] ?? '').trim();
  final rawBody = (customFontPackage['body'] ?? '').trim();
  final heading = rawHeading.isEmpty ? (rawBody.isEmpty ? 'Inter' : rawBody) : rawHeading;
  final body = rawBody.isEmpty ? heading : rawBody;
  final headingUrlName = _googleFontsUrlName(heading);
  final bodyUrlName = _googleFontsUrlName(body);
  final googleFontsHref = headingUrlName == bodyUrlName
      ? 'https://fonts.googleapis.com/css2?family=$headingUrlName:wght@400;500;600;700;800&display=swap'
      : 'https://fonts.googleapis.com/css2?family=$headingUrlName:wght@500;600;700;800&family=$bodyUrlName:wght@400;500;600;700&display=swap';
  return {
    'heading': "'${_sanitizeGoogleFontName(heading)}', -apple-system, Roboto, sans-serif",
    'body': "'${_sanitizeGoogleFontName(body)}', -apple-system, Roboto, sans-serif",
    'googleFontsHref': googleFontsHref,
  };
}

/// Yoğunluk kademesi — SADECE başlıkları etkiler (hero-title, section-title
/// vb. font-weight + boyut). Gövde metni her zaman normal ağırlıkta kalır;
/// body text'i kalınlaştırmak okunabilirliği bozar, bu yüzden serbest
/// slider yerine 3 kademeli, güvenli bir seçim sunulur.
/// 27.09.2026 eklendi (kanka isteği) — boyutlar artık sabit px değil,
/// clamp(min, akışkan-vw, max) ile FLUID: max değer eskisiyle birebir aynı
/// (masaüstünde hiçbir görsel değişiklik yok, geriye dönük uyumlu), min
/// değer mobilde okunabilir bir alt sınır. Önceden bu iki class hiçbir
/// media query'de geçmiyordu, yani tüm ekranlarda birebir aynı px
/// kullanılıyordu; artık ekran genişledikçe yumuşakça büyüyor.
const Map<String, Map<String, String>> _typeDensityData = {
  'ince': {'headingWeight': '500', 'heroTitleSize': 'clamp(28px, 6vw, 42px)', 'sectionTitleSize': 'clamp(22px, 3.8vw, 32px)'},
  'normal': {'headingWeight': '700', 'heroTitleSize': 'clamp(30px, 6.8vw, 54px)', 'sectionTitleSize': 'clamp(24px, 4.4vw, 38px)'},
  'kalin': {'headingWeight': '800', 'heroTitleSize': 'clamp(32px, 7.6vw, 62px)', 'sectionTitleSize': 'clamp(26px, 5vw, 44px)'},
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
   href="https://wa.me/${escapeHtml(whatsapp)}" aria-label="WhatsApp"><svg viewBox="0 0 24 24" width="28" height="28" fill="#fff"><path d="M17.6 6.3A8.86 8.86 0 0 0 12.05 4a8.87 8.87 0 0 0-8.9 8.9c0 1.57.41 3.1 1.19 4.45L4 22l4.79-1.26a9 9 0 0 0 4.29 1.09 8.87 8.87 0 0 0 8.9-8.9 8.8 8.8 0 0 0-2.58-5.63zM12.05 20.15a7.4 7.4 0 0 1-3.77-1.03l-.27-.16-2.83.74.76-2.75-.18-.28a7.36 7.36 0 0 1-1.13-3.93 7.4 7.4 0 0 1 7.42-7.4 7.35 7.35 0 0 1 5.24 2.17 7.33 7.33 0 0 1 2.16 5.22 7.4 7.4 0 0 1-7.4 7.42zm4.06-5.56c-.22-.11-1.31-.65-1.51-.72-.2-.07-.35-.11-.5.11-.15.22-.57.72-.7.87-.13.15-.26.16-.48.05-.22-.11-.93-.34-1.77-1.09-.65-.58-1.09-1.3-1.22-1.52-.13-.22-.01-.34.1-.45.1-.1.22-.26.33-.39.11-.13.15-.22.22-.37.07-.15.04-.28-.02-.39-.06-.11-.5-1.21-.69-1.66-.18-.43-.37-.37-.5-.38-.13-.01-.28-.01-.43-.01a.83.83 0 0 0-.6.28c-.2.22-.79.77-.79 1.87s.81 2.17.92 2.32c.11.15 1.6 2.44 3.87 3.42.54.23.96.37 1.29.48.54.17 1.03.15 1.42.09.43-.06 1.31-.54 1.5-1.06.18-.52.18-.96.13-1.06-.05-.1-.2-.16-.42-.27z"/></svg></a>''';
  }
  return '''
<a class="floating-contact-btn call" href="tel:${escapeHtml(phone!)}" aria-label="Ara"><i class="fa-solid fa-phone"></i></a>''';
}

/// 05.10.2026 eklendi — site dil kodundan Open Graph locale değeri.
/// Uygulama yalnızca 'tr' ve 'en' siteleri üretir. Bilinmeyen bir kod için YANLIŞ bir
/// dil bildirmek yerine boş döner (çağıran og:locale etiketini hiç yazmaz; paylaşım
/// platformları dili sayfadan/varsayılandan çıkarır).
String ogLocaleFor(String lang) {
  switch (lang.toLowerCase()) {
    case 'tr':
      return 'tr_TR';
    case 'en':
      return 'en_US';
    default:
      return '';
  }
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
  // 05.10.2026 eklendi — og:locale artık SİTE DİLİNE göre (eskiden her sayfada
  // sabit "tr_TR" yazılıyordu; İngilizce sitelerde paylaşım kartı yanlış dil
  // bildiriyordu). Bkz. [ogLocaleFor]. Varsayılan 'tr' = eski davranış.
  String lang = 'tr',
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
  final ogLocale = ogLocaleFor(lang);
  if (ogLocale.isNotEmpty) buffer.writeln('<meta property="og:locale" content="$ogLocale">');
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

/// 28.09.2026 eklendi (kanka isteği) — favicon (sekme/arama sonucu ikonu).
/// Şablonlarda hiç favicon yoktu (sekmede boş sayfa simgesi çıkıyordu).
/// Tüm sayfalar [wrapPageHtml]'dan geçtiği için tek yerden çözüldü: temanın
/// vurgu rengiyle yuvarlatılmış kare + işletme adının baş harfi, SVG data URI
/// (ek dosya/istek yok, sayfa boyutuna ~300 bayt). Renk geçerli hex değilse
/// güvenli varsayılana düşer. Logo tabanlı ikon bilinçli olarak yapılmadı
/// (logo büyük data URI olup her sayfaya kopyalanırdı).
/// 28.09.2026 (2. tur) — Türkçe büyük harf: Dart'ın `toUpperCase()` metodu
/// dile duyarlı değil ('i' -> 'I'). 'tr' sitelerde 'i' -> 'İ', 'ı' -> 'I'.
String faviconUpperLetter(String ch, String lang) {
  if (lang == 'tr') {
    if (ch == 'i') return 'İ';
    if (ch == 'ı') return 'I';
  }
  return ch.toUpperCase();
}

/// Favicon SVG'sinin ham metni (data URI'ye sarılmadan). Yayında ayrı bir
/// `/favicon.svg` dosyası olarak da yüklenir (bkz. favicon_publish.dart).
String faviconSvg(String pageTitle, String accent, String accentText,
    {String lang = 'tr'}) {
  final hex = RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');
  final bgColor = hex.hasMatch(accent.trim()) ? accent.trim() : '#3D5AFE';
  final fgColor = hex.hasMatch(accentText.trim()) ? accentText.trim() : '#FFFFFF';
  final m = RegExp(r'[\p{L}\p{N}]', unicode: true).firstMatch(pageTitle);
  final letter = escapeHtml(faviconUpperLetter(m?.group(0) ?? 'S', lang));
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
      '<rect width="64" height="64" rx="14" fill="$bgColor"/>'
      '<text x="32" y="45" font-family="Arial,Helvetica,sans-serif" font-size="38" '
      'font-weight="700" text-anchor="middle" fill="$fgColor">$letter</text></svg>';
}

String faviconLinkHtml(String pageTitle, String accent, String accentText,
    {String lang = 'tr'}) {
  final svg = faviconSvg(pageTitle, accent, accentText, lang: lang);
  return '<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,${Uri.encodeComponent(svg)}">';
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
  // 11.09.2026 eklendi — bkz. [shapeStyleOf] dokümanı. Varsayılan 'yumusak'
  // eski sabit görünüme ÇOK YAKINDIR (birkaç köşe değeri ±2-4px değişebilir,
  // hero-cta kasıtlı olarak sabit bırakıldı) — yani bu parametreyi hiç
  // göndermeyen eski bir çağrı (varsa) BÜYÜK bir görsel kırılma yaşamaz.
  String shapeStyle = 'yumusak',
  // 17.09.2026 eklendi — "Özel Renk" (B seçeneği). Verilirse [themeId]'in
  // hazır paleti yerine bunu kullanır (bkz. [resolveTheme] dokümanı).
  // Verilmezse davranış birebir eskisi gibi kalır (geriye dönük uyumlu).
  Map<String, String>? customTheme,
  // 18.09.2026 eklendi — "Serbest Font Seçimi" (PREMİUM). [customTheme]
  // ile BİREBİR AYNI desen: verilirse [fontPackageId]'nin küratörlü
  // paketi yerine bunu kullanır (bkz. [resolveFontPackage]). Verilmezse
  // davranış birebir eskisi gibi kalır (geriye dönük uyumlu).
  Map<String, String>? customFontPackage,
}) {
  final theme = resolveTheme(themeId, customTheme);
  final shape = shapeStyleOf(shapeStyle);
  final radiusCard = shape['radiusCard']!;
  final radiusBtn = shape['radiusBtn']!;
  final shadowCard = shape['shadowCard']!;
  final bg = theme['bg']!;
  final text = theme['text']!;
  final subtext = theme['subtext']!;
  final cardBg = theme['cardBg']!;
  final border = theme['border']!;
  final chipBg = theme['chipBg']!;
  final accent = theme['accent']!;
  final accentText = theme['accentText']!;
  final fonts = resolveFontPackage(fontPackageId, customFontPackage);
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
    lang: lang,
  );
  final floatingBtnHtml = floatingContactButtonHtml(whatsapp: whatsapp, phone: phone);
  // 27.09.2026 eklendi (kanka isteği) — 'glass_frost' teması kart arka
  // planlarını yarı saydam renk olarak veriyordu ama arkasında GERÇEK bir
  // bulanıklaştırma (backdrop-filter) yoktu, bu yüzden cam hissi
  // vermiyordu. site-nav ve hero-overlay.framed'de zaten kullanılan aynı
  // teknik burada da kart sınıflarına uygulanıyor — SADECE bu tema
  // seçiliyken; diğer temalar hiç etkilenmiyor (geriye dönük uyumlu).
  final glassCardCss = themeId == 'glass_frost'
      ? '''
  .faq-item, .testimonial-card, .pkg-card, .svc-card, .menu-category,
  .property-card, .team-card, .randevu-form, .contact-form, .gallery-slide .gallery-caption,
  .prd-card {
    backdrop-filter: saturate(160%) blur(16px);
    -webkit-backdrop-filter: saturate(160%) blur(16px);
  }
'''
      : '';
  return '''
<!DOCTYPE html>
<html lang="$lang">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(pageTitle)}</title>
${freshDateTitle ? freshDateTitleScript(lang: lang) : ''}
<meta name="theme-color" content="$accent">
${faviconLinkHtml(pageTitle, accent, accentText, lang: lang)}
<meta name="sitora-theme-id" content="$themeId">
$seoHtml
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="$googleFontsHref">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" referrerpolicy="no-referrer">
<style>
  :root {
    --sitora-bg: $bg;
    --sitora-text: $text;
    --sitora-subtext: $subtext;
    --sitora-card-bg: $cardBg;
    --sitora-border: $border;
    --sitora-chip-bg: $chipBg;
    --sitora-accent: $accent;
    --sitora-accent-text: $accentText;
    --sitora-radius-card: $radiusCard;
    --sitora-radius-btn: $radiusBtn;
    --sitora-shadow-card: $shadowCard;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html { scroll-behavior: smooth; -webkit-text-size-adjust: 100%; }
  section[id] { scroll-margin-top: 76px; }
  body { font-family: $bodyFont; color: var(--sitora-text); background: var(--sitora-bg); line-height: 1.5; }
  /* 28.09.2026 eklendi (kanka isteği) — hata düzeltmesi: kullanıcı "Hakkında"
     gibi alanlara boşluksuz çok uzun metin (kakakaka...) yazınca satır
     kırılmıyor, mobilde sayfa yana taşıyordu. overflow-wrap:anywhere hem
     kelimeyi gerektiğinde böler hem de flex/grid içindeki min-content
     hesabına dahil olur (break-word bunu yapmaz). Normal metin aynen
     davranır; sadece sığmayan kelime bölünür. overflow-x:clip ise ne
     olursa olsun yatay kaydırma çıkmasını engelleyen son güvenlik ağı
     (sticky menüyü bozmaz; hidden bozardı). */
  html, body { max-width: 100%; overflow-x: clip; }
  body, p, h1, h2, h3, h4, li, span, a, blockquote, figcaption, label, dt, dd, td, th, summary {
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  /* Flex/grid çocukları içeriğinden küçülebilsin (varsayılan min-width:auto taşma sebebi) */
  .section > *, .hero-overlay > *, .hero-split-text, .svc-card, .service-list > *, .site-nav-brand, .trust-item { min-width: 0; }
  img, video, iframe, svg { max-width: 100%; }
  .trust-item { overflow-wrap: normal; word-break: normal; }
  .site-nav-link { overflow-wrap: normal; word-break: normal; }
  h1, h2, h3, .hero-title, .section-title { font-family: $headingFont; }
  /* 27.09.2026 eklendi (kanka isteği) — metin seçim rengi ve klavyeyle
     gezinirken görünen odak halkası artık markanın kendi rengiyle (temaya
     göre otomatik değişir), tarayıcının çirkin varsayılanı yerine. Mouse ile
     tıklamada halka çıkmaz (:focus-visible), sadece Tab/klavye kullanımında. */
  ::selection { background: var(--sitora-accent); color: var(--sitora-accent-text); }
  a:focus-visible, button:focus-visible, input:focus-visible, textarea:focus-visible, select:focus-visible, [tabindex]:focus-visible {
    outline: 2px solid var(--sitora-accent);
    outline-offset: 3px;
  }
  @media (prefers-reduced-motion: reduce) {
    * { animation-duration: 0.001ms !important; transition-duration: 0.001ms !important; }
  }
  .hero { position: relative; height: 68vh; min-height: 420px; background-size: cover; background-position: center; display:flex; align-items:center; justify-content:center; overflow: hidden; }
  /* 27.09.2026 eklendi (kanka isteği) — düşük/vasat kalite fotoğraflarda
     "premium" hissi korumak için: fotoğrafın kendisini blurlamadan/yazıyı
     etkilemeden, arkada ayrı bir katmanda (background:inherit + filter)
     hafif bir renk/kontrast normalizasyonu + marka rengiyle duotone tonu.
     Bu katman TÜM sektörlerde otomatik devreye giriyor, ekstra görsel/img
     gerekmiyor. */
  .hero::before {
    content:''; position:absolute; inset:0; z-index:0; pointer-events:none;
    background: inherit; background-size: cover; background-position: center;
    filter: saturate(1.08) contrast(1.06) brightness(0.97);
  }
  .hero::after { content:''; position:absolute; inset:0; background: radial-gradient(60% 55% at 50% 25%, var(--sitora-accent) 0%, transparent 70%), linear-gradient(160deg, color-mix(in srgb, var(--sitora-accent) 16%, transparent) 0%, transparent 55%); opacity: 0.16; pointer-events:none; z-index: 1; mix-blend-mode: overlay; }
  /* 27.09.2026 eklendi (kanka isteği — "amatör" hissini kıran küçük premium
     detaylar). Tamamen CSS-only, hiçbir görsel/veri gerektirmiyor; bu
     bloktaki her kural bir kez tanımlanıp wrapPageHtml üzerinden TÜM
     sektörlere otomatik yayılıyor (generator dosyalarına dokunmaya gerek
     yok). 1) Hero'nun arkasında yumuşak, hafif dönen bir "altın halka" glow.
     2) Hero köşesinde, hafif yukarı-aşağı süzülen küçük bir onay rozeti
     (ikon Font Awesome content koduyla, ekstra markup/img gerektirmiyor). */
  .hero-overlay::before {
    content:''; position:absolute; z-index:0; pointer-events:none;
    width: 340px; height: 340px; top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    border-radius: 50%;
    background: radial-gradient(circle, transparent 58%, color-mix(in srgb, var(--sitora-accent) 55%, transparent) 60%, transparent 63%);
    filter: blur(2px);
    opacity: 0.55;
    animation: sitoraGlowSpin 16s linear infinite;
  }
  .hero-overlay.editorial::before { position:absolute; z-index:0; width:52px; height:4px; top:auto; left:32px; bottom: 140px; transform:none; border-radius:2px; background:var(--sitora-accent); filter:none; opacity:1; animation:none; }
  .hero-overlay > * { position: relative; z-index: 1; }
  @keyframes sitoraGlowSpin { from { transform: translate(-50%, -50%) rotate(0deg); } to { transform: translate(-50%, -50%) rotate(360deg); } }
  /* 28.09.2026 eklendi (kanka isteği) — güven şeridi. Renk temasından
     bağımsız okunur kalması için sabit koyu renk yerine metin/arkaplan
     renkleri TERS çevrilerek kullanılıyor (açık temada koyu şerit, koyu
     temada açık şerit — her zaman kontrastlı). */
  .trust-bar { background: var(--sitora-text); color: var(--sitora-bg); padding: 16px 24px; }
  .trust-bar-row { max-width: 1160px; margin: 0 auto; display: flex; flex-wrap: wrap; justify-content: center; gap: 28px; }
  .trust-item { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; opacity: 0.92; white-space: nowrap; }
  .trust-check { color: var(--sitora-accent); font-weight: 700; }
  @media (max-width: 640px) { .trust-bar-row { gap: 18px; justify-content: flex-start; overflow-x: auto; -webkit-overflow-scrolling: touch; scrollbar-width: none; } .trust-bar-row::-webkit-scrollbar { display: none; } }
  @keyframes sitoraFloatBadge { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-8px); } }
  /* 28.09.2026 — hero canlı açık/kapalı hapı (bkz. heroStatusPillHtml). */
  @keyframes sitoraStatusPulse { 0% { box-shadow: 0 0 0 0 rgba(34,197,94,0.55); } 70% { box-shadow: 0 0 0 8px rgba(34,197,94,0); } 100% { box-shadow: 0 0 0 0 rgba(34,197,94,0); } }
  .hero-status-pill { position: absolute; z-index: 3; left: 16px; top: 16px; display: inline-flex; align-items: center; gap: 8px; padding: 7px 14px; border-radius: 999px; font-size: 13px; font-weight: 600; line-height: 1; color: #fff; background: rgba(15,15,18,0.62); border: 1px solid rgba(255,255,255,0.18); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); max-width: calc(100% - 32px); }
  .hero-status-pill[hidden] { display: none; }
  .hero-status-pill::before { content: ''; flex: 0 0 auto; width: 8px; height: 8px; border-radius: 50%; background: #ef4444; }
  .hero-status-pill.is-open::before { background: #22c55e; animation: sitoraStatusPulse 2s ease-out infinite; }
  @media (max-width: 720px) { .hero-status-pill { left: 12px; top: 12px; font-size: 12px; padding: 6px 12px; } }
  .hero-split-media { position:relative; }
  .hero-split-media::before {
    content:''; position:absolute; z-index:0; pointer-events:none;
    width: 140px; height: 140px; top: -24px; right: -24px; border-radius: 50%;
    background: radial-gradient(circle, color-mix(in srgb, var(--sitora-accent) 45%, transparent) 0%, transparent 70%);
    animation: sitoraFloatBadge 4s ease-in-out infinite;
  }
  @media (max-width: 720px) { .hero-overlay::before { width: 240px; height: 240px; } }
  .hero-overlay { position: relative; z-index: 2; background: linear-gradient(180deg, rgba(0,0,0,0.32) 0%, rgba(0,0,0,0.58) 100%); width:100%; height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; padding: 24px; color: white; }
  .hero-overlay.editorial { align-items:flex-start; justify-content:flex-end; text-align:left; padding: 0 32px 48px; }
  .hero-overlay.editorial::before { content:''; display:block; width:52px; height:4px; background:var(--sitora-accent); margin-bottom:18px; border-radius:2px; }
  .hero-overlay.editorial .hero-title { max-width: 620px; }
  .hero-overlay.editorial .hero-tagline { max-width: 480px; }
  .hero-overlay.framed { margin: 22px; border: 1px solid rgba(255,255,255,0.4); border-radius: 20px; background: rgba(0,0,0,0.28); backdrop-filter: blur(2px); }
  /* 27.09.2026 eklendi (kanka isteği) — 'diagonal': düz üst-alt overlay yerine yönlü/çapraz gradient, sola yaslı yazı. */
  .hero-overlay.diagonal { align-items:flex-start; justify-content:center; text-align:left; padding: 0 60px; background: linear-gradient(100deg, rgba(0,0,0,0.86) 0%, rgba(0,0,0,0.55) 42%, rgba(0,0,0,0.18) 75%, rgba(0,0,0,0.08) 100%); }
  .hero-overlay.diagonal .hero-title { max-width: 680px; }
  .hero-overlay.diagonal .hero-tagline { max-width: 480px; }
  @media (max-width: 720px) { .hero-overlay.diagonal { padding: 0 24px; background: linear-gradient(180deg, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0.72) 100%); } }
  /* 27.09.2026 eklendi (kanka isteği) — 'split': foto artık .hero arka planı değil, ayrı kutu; yazı hep düz zemin üstünde okunur. */
  .hero-split { height:auto; min-height:0; display:block; background:none; }
  .hero-split::after { display:none; }
  .hero-split-grid { max-width:1160px; margin:0 auto; padding:72px 24px 32px; display:grid; grid-template-columns:1.05fr 0.95fr; gap:48px; align-items:center; }
  .hero-split-text { text-align:left; }
  .hero-split-text .hero-cta { margin-top: 6px; }
  .hero-split-media { position:relative; }
  /* 28.09.2026 GÜNCELLENDİ (kanka isteği) — sabit yükseklik (380/260px) yerine
     görsel oranı: dikey/kare fotoğraflar daha az kırpılıyor, object-position
     üst kısmı (yüz/ürün) öne alıyor; ince vurgu çerçevesi koyu zeminde de öne çıkarıyor. */
  .hero-split-img { width:100%; aspect-ratio:5/4; height:auto; max-height:480px; object-fit:cover; object-position:50% 30%; border-radius:24px; box-shadow:0 24px 60px rgba(0,0,0,0.22), 0 0 0 1px color-mix(in srgb, var(--sitora-accent) 30%, transparent); display:block; }
  @media (max-width: 860px) { .hero-split-grid { grid-template-columns:1fr; gap:24px; padding:36px 20px 8px; } .hero-split-text { text-align:center; } .hero-split-img { aspect-ratio:4/3; max-height:none; } .hero-split-text .hero-cta { display:block; width:100%; max-width:420px; margin-left:auto; margin-right:auto; text-align:center; } }
  /* 28.09.2026 eklendi (kanka isteği) — 'social' hero: foto kutusunun
     üstünde yüzen gerçek-yorum kartı. Kart taşarsa (mobilde dar alan)
     fotonun altına düz akışa döner. */
  .hero-quote-card { position:absolute; z-index:2; left:-28px; bottom:32px; max-width:270px; background:var(--sitora-card-bg); color:var(--sitora-text); padding:18px 20px; border-radius:var(--sitora-radius-card); box-shadow:0 20px 46px rgba(0,0,0,0.22); }
  .hero-quote-stars { color:#f5a623; letter-spacing:2px; font-size:13px; display:block; margin-bottom:6px; }
  .hero-quote-text { font-size:14px; line-height:1.5; font-style:italic; margin-bottom:8px; }
  .hero-quote-person { display:flex; align-items:center; gap:8px; }
  .hero-quote-name { font-size:12px; font-weight:600; color:var(--sitora-subtext); }
  @media (max-width: 860px) { .hero-quote-card { position:static; max-width:none; margin-top:16px; box-shadow:var(--sitora-shadow-card); } }
  .hero-eyebrow { display:inline-block; font-size: 12px; letter-spacing: 0.18em; text-transform: uppercase; opacity: 0.85; margin-bottom: 14px; padding: 4px 14px; border: 1px solid rgba(255,255,255,0.5); border-radius: 20px; }
  .hero-split-text .hero-eyebrow { color: var(--sitora-accent); border-color: var(--sitora-accent); opacity: 1; }
  .hero-logo { width: 72px; height: 72px; border-radius: 50%; margin-bottom: 12px; object-fit: cover; }
  .hero-title { font-size: $heroTitleSize; font-weight: $headingWeight; margin-bottom: 8px; letter-spacing: -0.01em; }
  .hero-tagline { font-size: 16px; opacity: 0.9; margin-bottom: 20px; }
  .hero-cta { background: var(--sitora-accent); color: var(--sitora-accent-text); padding: 12px 28px; border-radius: 30px; text-decoration: none; font-weight: 600; transition: transform 0.18s ease, box-shadow 0.18s ease; display:inline-block; }
  .hero-cta:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(0,0,0,0.25); }
  .section { max-width: 1160px; margin: 0 auto; padding: 72px 24px; }
  @media (max-width: 640px) { .section { padding: 48px 20px; } }
  .section-title { font-size: $sectionTitleSize; font-weight: $headingWeight; margin-bottom: 20px; color: var(--sitora-text); letter-spacing: -0.01em; position: relative; padding-top: 20px; }
  .section-title::before { content: ''; display: block; width: 42px; height: 3px; border-radius: 3px; background: var(--sitora-accent); position: absolute; top: 0; left: 0; }
  .about-section p, .faq-section .faq-list { max-width: 760px; }
  .about-section p { line-height: 1.7; }
  .section, .reveal { opacity: 0; transform: translateY(16px); transition: opacity 0.6s ease, transform 0.6s ease; }
  .section.in-view, .reveal.in-view { opacity: 1; transform: translateY(0); }
  /* 27.09.2026 eklendi (kanka isteği) — servis listesi artık "satır tipi
     liste" değil, numaralı/editoryal kart grid'i (referans: key-kuafor
     .svc-card / .svc-num incelemesi, bkz. serviceListBlockHtml yorumu).
     Container'a border-top+border-left, her karta border-right+border-bottom
     verilerek ortadaki çizgiler ikilenmeden temiz bir "editoryal grid"
     hissi elde ediliyor. */
  .service-list { list-style: none; display: grid; grid-template-columns: 1fr; gap: 14px; margin-top: 28px; padding: 0; }
  .svc-card { position: relative; display: flex; flex-direction: column; justify-content: flex-end; gap: 10px; min-height: 132px; padding: 24px 22px; background: var(--sitora-card-bg); border: 1px solid var(--sitora-border); border-radius: var(--sitora-radius-card); overflow: hidden; transition: transform 0.25s ease, border-color 0.25s ease, background 0.25s ease; }
  .svc-card::before { content: ''; position: absolute; left: 0; top: 0; width: 100%; height: 3px; background: var(--sitora-accent); opacity: 0.85; transform: scaleX(0.18); transform-origin: left; transition: transform 0.35s ease; }
  .svc-card:hover { transform: translateY(-4px); border-color: var(--sitora-accent); background: var(--sitora-chip-bg); }
  .svc-card:hover::before { transform: scaleX(1); }
  .svc-num { position: absolute; top: 16px; left: 22px; font-size: 13px; font-weight: 800; letter-spacing: 0.1em; color: var(--sitora-accent); }
  .service-name { font-weight: 700; font-size: clamp(17px, 2.2vw, 20px); line-height: 1.25; }
  .svc-meta { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
  .service-duration { color: var(--sitora-subtext); font-size: 13px; }
  .service-price { font-weight: 700; color: var(--sitora-accent); }
  @media (min-width: 640px) { .service-list { grid-template-columns: repeat(2, 1fr); } }
  /* 27.09.2026 eklendi (kanka isteği) — geniş ekranda sabit 2 sütun boşluk
     israf ediyordu; 900px üzeri 3 sütuna geçiyor. */
  @media (min-width: 900px) { .service-list { grid-template-columns: repeat(var(--svc-cols, 3), 1fr); } }
  /* 28.09.2026 eklendi (kanka isteği) — opsiyonel "Ürünler" bölümü
     (bkz. productListBlockHtml). Fotoğraflı ürün vitrini kartı; galeri
     gridiyle aynı auto-fill mantığı, ama isim+fiyat alanı için ekstra
     dolgu/gölge ile "shop kartı" hissi verir. */
  .product-list { list-style: none; display: grid; grid-template-columns: repeat(auto-fill, minmax(180px,1fr)); gap: 18px; margin-top: 24px; padding: 0; }
  .prd-card { display: flex; flex-direction: column; gap: 8px; padding: 14px; border: 1px solid var(--sitora-border); border-radius: var(--sitora-radius-card); background: var(--sitora-card-bg); box-shadow: var(--sitora-shadow-card); transition: transform 0.2s ease; }
  .prd-card:hover { transform: translateY(-3px); }
  .prd-card img { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: calc(var(--sitora-radius-card) - 6px); }
  .prd-name { font-weight: 600; font-size: 15px; }
  .prd-price { font-weight: 700; color: var(--sitora-accent); margin-top: auto; }
  .gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px,1fr)); gap: 14px; }
  .gallery-item { position: relative; aspect-ratio: 1; overflow: hidden; border-radius: var(--sitora-radius-card); box-shadow: var(--sitora-shadow-card); cursor: pointer; }
  .gallery-item img { width:100%; height:100%; object-fit: cover; transition: transform 0.35s ease; }
  .gallery-item:hover img { transform: scale(1.06); }
  /* 27.09.2026 eklendi (kanka isteği) — galeri sadece fotoğrafa endeksli
     kalmasın diye: her kartın üstünde marka rengiyle ince bir duotone
     kaplama + iç çerçeve. Esnafın yüklediği sıradan/telefon fotoğrafı bile
     bu katman sayesinde sitenin genel paletiyle "tasarlanmış" hissediyor. */
  .gallery-item::after {
    content:''; position:absolute; inset:0; pointer-events:none; z-index:1;
    box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--sitora-accent) 35%, transparent);
    background: linear-gradient(155deg, color-mix(in srgb, var(--sitora-accent) 18%, transparent) 0%, transparent 45%);
    mix-blend-mode: overlay;
  }
  .gallery-lightbox { display:none; position: fixed; inset:0; background: rgba(0,0,0,0.9); z-index:999; align-items:center; justify-content:center; }
  .gallery-lightbox.open { display:flex; }
  .gallery-lightbox img { max-width: 92%; max-height: 92%; }
  .gallery-section-slideshow .section-title { margin-bottom: 14px; }
  .gallery-slideshow { display:flex; overflow-x:auto; gap: 12px; scroll-snap-type: x mandatory; -webkit-overflow-scrolling: touch; padding-bottom: 4px; scrollbar-width: none; cursor: grab; user-select: none; }
  .gallery-slideshow.dragging { cursor: grabbing; scroll-snap-type: none; }
  .gallery-slideshow::-webkit-scrollbar { display:none; }
  .gallery-slide { flex: 0 0 82%; scroll-snap-align: center; position: relative; aspect-ratio: 4/3; border-radius: var(--sitora-radius-card); overflow: hidden; cursor: pointer; }
  .gallery-slide img { width:100%; height:100%; object-fit: cover; -webkit-user-drag: none; pointer-events: none; }
  .gallery-slide .gallery-caption { position:absolute; left:0; right:0; bottom:0; padding: 10px 14px; background: linear-gradient(0deg, rgba(0,0,0,0.65), transparent); color:#fff; font-size: 13px; }
  .gallery-dots { display:flex; justify-content:center; gap: 8px; margin-top: 14px; }
  .gallery-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--sitora-border); display:inline-block; transition: width 0.25s ease, background 0.25s ease; }
  .gallery-dot.active { width: 22px; border-radius: 4px; background: var(--sitora-accent); }
  @media (min-width: 640px) { .gallery-slide { flex-basis: 46%; } }
  .gallery-crossfade { position:relative; max-width: 760px; margin: 0 auto; }
  .gallery-crossfade-stage { position:relative; aspect-ratio: 16/9; border-radius: var(--sitora-radius-card); overflow:hidden; box-shadow: var(--sitora-shadow-card); }
  .gallery-crossfade-slide { position:absolute; inset:0; background-size:cover; background-position:center; opacity:0; cursor:pointer; transition: opacity 0.8s ease; }
  .gallery-crossfade-slide.active { opacity:1; }
  .gallery-crossfade-slide .gallery-caption { position:absolute; left:0; right:0; bottom:0; padding:14px 18px; background: linear-gradient(0deg, rgba(0,0,0,0.65), transparent); color:#fff; font-size:14px; }
  .gallery-crossfade-arrow { position:absolute; top:50%; transform:translateY(-50%); width:40px; height:40px; border-radius:50%; border:none; background:rgba(0,0,0,0.35); color:#fff; font-size:20px; line-height:1; cursor:pointer; display:flex; align-items:center; justify-content:center; transition: background 0.2s ease; }
  .gallery-crossfade-arrow:hover { background:rgba(0,0,0,0.55); }
  .gallery-crossfade-arrow.prev { left:12px; }
  .gallery-crossfade-arrow.next { right:12px; }
  @media (max-width:480px) { .gallery-crossfade-arrow { width:32px; height:32px; font-size:16px; } }
  /* 27.09.2026 eklendi (kanka isteği) — 'marquee' galeri stili: sürekli
     kayan/infinite-scroll şerit, saf CSS. Track içeriği (bkz.
     _galleryMarqueeBlockHtml) İKİ KEZ basılıyor; %50 kayınca birinci kopya
     ekrandan çıkmış oluyor ve ikinci kopya tam o noktadan devam ediyormuş
     gibi görünüyor — döngü dikişsiz. Viewport'ta overflow:hidden ile taşan
     kısım gizleniyor. */
  .gallery-marquee-viewport { overflow: hidden; margin: 0 -24px; padding: 0 24px; }
  .gallery-marquee-track { display: flex; gap: 16px; width: max-content; animation: sitoraMarquee 32s linear infinite; }
  .gallery-marquee-viewport:hover .gallery-marquee-track,
  .gallery-marquee-viewport:focus-within .gallery-marquee-track { animation-play-state: paused; }
  .gallery-marquee-item { position: relative; flex: 0 0 auto; width: 240px; height: 170px; border-radius: var(--sitora-radius-card); overflow: hidden; box-shadow: var(--sitora-shadow-card); cursor: pointer; }
  .gallery-marquee-item img { width: 100%; height: 100%; object-fit: cover; display: block; transition: transform 0.35s ease; }
  .gallery-marquee-item:hover img { transform: scale(1.06); }
  .gallery-marquee-item .gallery-caption { position:absolute; left:0; right:0; bottom:0; padding: 8px 12px; background: linear-gradient(0deg, rgba(0,0,0,0.65), transparent); color:#fff; font-size: 12.5px; }
  @media (max-width: 720px) { .gallery-marquee-item { width: 180px; height: 130px; } .gallery-marquee-track { animation-duration: 22s; } }
  @keyframes sitoraMarquee { from { transform: translateX(0); } to { transform: translateX(-50%); } }
  @media (prefers-reduced-motion: reduce) {
    .gallery-marquee-track { animation: none; overflow-x: auto; scroll-snap-type: x proximity; -webkit-overflow-scrolling: touch; }
    .gallery-marquee-item { scroll-snap-align: start; }
    .hero-overlay::before, .hero-split-media::before, .hero-status-pill.is-open::before { animation: none; }
  }
  /* 28.09.2026 eklendi (kanka isteği) — 'bento' galeri stili: 12 kolonlu
     editoryal mozaik grid. 6 kartlık span deseni resim sırasına göre
     döngüsel tekrarlanır (bkz. _galleryBentoBlockHtml). Renk/gölge/köşe
     dilinde diğer galeri stilleriyle (var(--sitora-*)) birebir aynı marka
     paletini kullanır — sadece span düzeni değişiyor. */
  .gallery-bento-grid { display: flex; flex-direction: column; gap: 14px; }
  .gb-block { display: grid; grid-template-columns: repeat(2, 1fr); grid-auto-rows: 120px; gap: 10px; }
  .gallery-bento-item { position: relative; overflow: hidden; border-radius: var(--sitora-radius-card); box-shadow: var(--sitora-shadow-card); cursor: pointer; min-height: 0; }
  .gallery-bento-item img { width:100%; height:100%; object-fit: cover; display:block; transition: transform 0.45s ease; }
  .gallery-bento-item:hover img { transform: scale(1.06); }
  .gallery-bento-item::after {
    content:''; position:absolute; inset:0; pointer-events:none; z-index:1;
    box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--sitora-accent) 35%, transparent);
    background: linear-gradient(155deg, color-mix(in srgb, var(--sitora-accent) 18%, transparent) 0%, transparent 45%);
    mix-blend-mode: overlay;
  }
  .gallery-bento-item .gallery-caption { position:absolute; left:0; right:0; bottom:0; padding: 10px 14px; background: linear-gradient(0deg, rgba(0,0,0,0.65), transparent); color:#fff; font-size: 13px; z-index:2; }
  /* Mobil/tablet: her blokta ilk görsel tam genişlik, kalanlar 2'li; tek
     kalan görsel de tam genişlik (boşluk kalmaz). */
  .gb-block .gb-a { grid-column: span 2; grid-row: span 3; }
  .gb-block .gb-b, .gb-block .gb-c, .gb-block .gb-d, .gb-block .gb-e { grid-row: span 2; }
  .gb-n1 .gb-a { grid-row: span 3; }
  .gb-n2 .gb-b, .gb-n4 .gb-d { grid-column: span 2; }
  /* Masaüstü: 12 kolon x 6 satır, boşluksuz döşeme. */
  @media (min-width: 901px) {
    .gallery-bento-grid { gap: 14px; }
    .gb-block { grid-template-columns: repeat(12, 1fr); grid-template-rows: repeat(6, 64px); grid-auto-rows: auto; gap: 14px; }
    .gb-block .gallery-bento-item { grid-column: auto; grid-row: auto; }
    .gb-n1 .gb-a { grid-column: 1 / 13; grid-row: 1 / 7; }
    .gb-n2 .gb-a { grid-column: 1 / 8;  grid-row: 1 / 7; }
    .gb-n2 .gb-b { grid-column: 8 / 13; grid-row: 1 / 7; }
    .gb-n3 .gb-a { grid-column: 1 / 8;  grid-row: 1 / 7; }
    .gb-n3 .gb-b { grid-column: 8 / 13; grid-row: 1 / 4; }
    .gb-n3 .gb-c { grid-column: 8 / 13; grid-row: 4 / 7; }
    .gb-n3.gb-flip .gb-a { grid-column: 6 / 13; }
    .gb-n3.gb-flip .gb-b, .gb-n3.gb-flip .gb-c { grid-column: 1 / 6; }
    .gb-n4 .gb-a { grid-column: 1 / 7;  grid-row: 1 / 7; }
    .gb-n4 .gb-b { grid-column: 7 / 13; grid-row: 1 / 4; }
    .gb-n4 .gb-c { grid-column: 7 / 10; grid-row: 4 / 7; }
    .gb-n4 .gb-d { grid-column: 10 / 13; grid-row: 4 / 7; }
    .gb-n4.gb-flip .gb-a { grid-column: 7 / 13; }
    .gb-n4.gb-flip .gb-b { grid-column: 1 / 7; }
    .gb-n4.gb-flip .gb-c { grid-column: 1 / 4; }
    .gb-n4.gb-flip .gb-d { grid-column: 4 / 7; }
    .gb-n5 .gb-a { grid-column: 1 / 5;  grid-row: 1 / 7; }
    .gb-n5 .gb-b { grid-column: 5 / 9;  grid-row: 1 / 4; }
    .gb-n5 .gb-c { grid-column: 5 / 9;  grid-row: 4 / 7; }
    .gb-n5 .gb-d { grid-column: 9 / 13; grid-row: 1 / 4; }
    .gb-n5 .gb-e { grid-column: 9 / 13; grid-row: 4 / 7; }
  }
  .hours-table { width:100%; border-collapse: collapse; }
  .hours-table td { padding: 10px 0; border-bottom: 1px solid var(--sitora-border); }
  .hours-table td:last-child { text-align: right; }
  .hours-status-badge { display:inline-block; margin-left: 8px; padding: 3px 11px; border-radius: 999px; font-size: 12px; font-weight: 700; vertical-align: middle; }
  .hours-status-badge.is-open { background: rgba(34,197,94,0.15); color: #16a34a; }
  .hours-status-badge.is-closed { background: rgba(239,68,68,0.15); color: #dc2626; }
  .map-embed { border-radius: var(--sitora-radius-card); overflow: hidden; margin: 16px 0; }
  .directions-link { display:inline-block; color: var(--sitora-accent); font-weight: 600; text-decoration: none; }
  .video-section { text-align: center; }
  .video-embed-wrap { position: relative; width: 100%; margin: 0 auto; border-radius: var(--sitora-radius-card); overflow: hidden; background: #0b0b0b; box-shadow: 0 14px 34px rgba(0,0,0,0.20); }
  .video-embed-wrap iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
  .video-embed-wrap.landscape { max-width: 720px; aspect-ratio: 16 / 9; }
  .video-embed-wrap.portrait { max-width: 340px; aspect-ratio: 9 / 16; }
  @media (max-width: 420px) { .video-embed-wrap.portrait { max-width: 78vw; } }
  .contact-buttons { display:flex; flex-wrap: wrap; gap: 12px; }
  .contact-btn { padding: 12px 20px; border-radius: var(--sitora-radius-btn); text-decoration:none; font-weight:600; color:var(--sitora-accent-text); background:var(--sitora-accent); transition: transform 0.18s ease, box-shadow 0.18s ease; display:inline-block; }
  .contact-btn:hover { transform: translateY(-2px); box-shadow: 0 8px 18px rgba(0,0,0,0.18); }
  .contact-btn.review { background: #fbbf24; color: #1a1a1a; }
  .contact-btn.whatsapp { background: #25D366; color: #fff; }
  .menu-category { margin-bottom: 24px; }
  .menu-category-title { font-size: 18px; font-weight:700; margin-bottom: 10px; color: var(--sitora-accent); }
  .menu-item { padding: 10px 0; border-bottom: 1px solid var(--sitora-border); }
  .menu-item-main { display:flex; justify-content: space-between; font-weight:600; }
  .menu-item-desc { color:var(--sitora-subtext); font-size: 13px; margin-top:4px; }
  .menu-item-legal { display:flex; flex-wrap:wrap; gap:6px; margin-top:6px; }
  .menu-item-badge { display:inline-block; padding: 2px 9px; border-radius: 999px; font-size: 11px; font-weight:600; background: var(--sitora-input-bg, rgba(127,127,127,0.14)); color: var(--sitora-subtext); }
  .menu-item-badge-allergen { background: rgba(251,191,36,0.16); color: #b45309; }
  .menu-item-badge-warn { background: rgba(239,68,68,0.14); color: #dc2626; }
  .randevu-form { display:flex; flex-direction:column; gap: 12px; max-width: 420px; }
  .randevu-form input, .randevu-form textarea { padding: 12px; border-radius: var(--sitora-radius-btn); border: 1px solid var(--sitora-border); background:var(--sitora-card-bg); color:var(--sitora-text); font-size:15px; }
  .randevu-form button { padding: 14px; border:none; border-radius: var(--sitora-radius-btn); background:var(--sitora-accent); color:var(--sitora-accent-text); font-weight:700; cursor:pointer; }
  .sitora-lead-form { display:flex; flex-direction:column; gap: 12px; max-width: 420px; margin-top: 18px; }
  .sitora-lead-form input, .sitora-lead-form textarea { padding: 12px; border-radius: var(--sitora-radius-btn); border: 1px solid var(--sitora-border); background:var(--sitora-card-bg); color:var(--sitora-text); font-size:15px; font-family: inherit; }
  .sitora-lead-form button { padding: 14px; border:none; border-radius: var(--sitora-radius-btn); background:var(--sitora-accent); color:var(--sitora-accent-text); font-weight:700; cursor:pointer; }
  .sitora-lead-form button:disabled { opacity: 0.6; cursor:default; }
  .sitora-lead-status { font-size: 13px; color:var(--sitora-subtext); min-height: 18px; margin: 0; }
  .faq-list { display:flex; flex-direction:column; gap: 10px; }
  .faq-item { border:1px solid var(--sitora-border); background:var(--sitora-card-bg); border-radius:var(--sitora-radius-card); box-shadow: var(--sitora-shadow-card); padding: 4px 16px; }
  .faq-question { position:relative; padding: 12px 34px 12px 0; font-weight:600; cursor:pointer; color:var(--sitora-text); list-style:none; }
  .faq-question::-webkit-details-marker { display:none; }
  .faq-question::after { content:''; position:absolute; right:4px; top:50%; width:9px; height:9px; border-right:2px solid var(--sitora-accent); border-bottom:2px solid var(--sitora-accent); transform: translateY(-65%) rotate(45deg); transition: transform 0.28s ease; }
  .faq-item[open] .faq-question::after { transform: translateY(-35%) rotate(225deg); }
  .faq-answer { padding: 0 0 14px 0; color:var(--sitora-subtext); line-height: 1.55; }
  .testimonial-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(240px,1fr)); gap:16px; }
  .testimonial-card { border:1px solid var(--sitora-border); background:var(--sitora-card-bg); border-radius:var(--sitora-radius-card); box-shadow: var(--sitora-shadow-card); padding:20px; }
  .testimonial-stars { color: #f5a623; letter-spacing: 2px; margin-bottom: 8px; }
  .testimonial-text { color:var(--sitora-text); font-style: italic; line-height: 1.55; margin-bottom: 10px; }
  .testimonial-person { display: flex; align-items: center; gap: 10px; }
  .testimonial-avatar { width: 34px; height: 34px; flex-shrink: 0; border-radius: 50%; background: var(--sitora-accent); color: var(--sitora-accent-text); display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 14px; }
  .testimonial-name { color:var(--sitora-subtext); font-weight:600; font-size: 14px; }
  .pkg-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(220px,1fr)); gap:16px; }
  .pkg-card { border:1px solid var(--sitora-border); background:var(--sitora-card-bg); border-radius:var(--sitora-radius-card); box-shadow: var(--sitora-shadow-card); padding:20px; transition: transform 0.2s ease, box-shadow 0.2s ease; }
  .pkg-card:hover { transform: translateY(-4px); box-shadow: 0 10px 24px rgba(0,0,0,0.10); }
  .pkg-card.featured { border-color:var(--sitora-accent); border-width:2px; }
  .pkg-title { font-size:17px; font-weight:700; margin-bottom:4px; color:var(--sitora-text); }
  .pkg-session { color:var(--sitora-subtext); font-size:13px; margin-bottom:10px; }
  .pkg-price { font-size:20px; font-weight:800; color:var(--sitora-accent); margin-bottom:10px; }
  .pkg-original-price { text-decoration:line-through; color:var(--sitora-subtext); font-size:14px; margin-right:8px; }
  .pkg-included { list-style:none; font-size:13px; color:var(--sitora-subtext); margin-bottom:8px; }
  .pkg-included li { padding:2px 0; }
  .pkg-note { font-size:12px; color:var(--sitora-subtext); }
  .team-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(160px,1fr)); gap:16px; }
  .team-card { text-align:center; }
  .team-photo { width:88px; height:88px; border-radius:50%; object-fit:cover; margin-bottom:10px; }
  .team-name { font-size:15px; font-weight:700; color:var(--sitora-text); }
  .team-specialty { font-size:13px; color:var(--sitora-subtext); margin-bottom:6px; }
  .team-bio { font-size:12px; color:var(--sitora-subtext); margin-bottom:6px; }
  .team-tags { display:flex; flex-wrap:wrap; gap:6px; justify-content:center; }
  .team-tag { font-size:11px; background:var(--sitora-chip-bg); color:var(--sitora-text); padding:3px 8px; border-radius:10px; }
  .practitioner-section { text-align:center; }
  .practitioner-photo { width:110px; height:110px; border-radius:50%; object-fit:cover; margin-bottom:12px; }
  .practitioner-name { font-size:20px; font-weight:700; color:var(--sitora-text); }
  .practitioner-title { color:var(--sitora-accent); font-weight:600; margin-bottom:10px; }
  .practitioner-bio { color:var(--sitora-subtext); margin-bottom:12px; }
  .cred-badges { display:flex; flex-wrap:wrap; gap:8px; justify-content:center; }
  .cred-badge { font-size:12px; background:var(--sitora-chip-bg); color:var(--sitora-text); padding:4px 10px; border-radius:10px; }
  .schedule-table { width:100%; border-collapse:collapse; }
  .schedule-table td { padding:10px; border-bottom:1px solid var(--sitora-border); font-size:14px; color:var(--sitora-text); }
  .timeline { border-left:2px solid var(--sitora-border); padding-left:20px; }
  .timeline-item { margin-bottom:20px; }
  .timeline-year { font-weight:700; color:var(--sitora-accent); font-size:13px; }
  .timeline-body h3 { font-size:15px; margin:4px 0; color:var(--sitora-text); }
  .timeline-body p { font-size:13px; color:var(--sitora-subtext); }
  .skill-chips { display:flex; flex-wrap:wrap; gap:8px; }
  .skill-chip { background:var(--sitora-chip-bg); color:var(--sitora-text); padding:6px 14px; border-radius:14px; font-size:13px; }
  .contact-form { display:flex; flex-direction:column; gap:12px; max-width:420px; }
  .contact-form input, .contact-form textarea { padding:12px; border-radius:var(--sitora-radius-btn); border:1px solid var(--sitora-border); background:var(--sitora-card-bg); color:var(--sitora-text); font-size:15px; }
  .contact-form button { padding:14px; border:none; border-radius:var(--sitora-radius-btn); background:var(--sitora-accent); color:var(--sitora-accent-text); font-weight:700; cursor:pointer; }
  .about-section { color:var(--sitora-text); }
  .address-text { color:var(--sitora-text); }
  .property-grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap:16px; padding: 20px; max-width:960px; margin:0 auto; }
  .property-card { border-radius:var(--sitora-radius-card); box-shadow: var(--sitora-shadow-card); overflow:hidden; border:1px solid var(--sitora-border); background:var(--sitora-card-bg); text-decoration:none; color:inherit; display:block; }
  .property-card img { width:100%; height:140px; object-fit:cover; }
  .property-card-body { padding:12px; }
  .property-card-body h3 { font-size:14px; margin-bottom:4px; color:var(--sitora-text); }
  .property-tags { font-size:12px; color:var(--sitora-subtext); margin-bottom:6px; }
  .property-price { font-weight:700; color:var(--sitora-accent); }
  .property-details-table { width:100%; border-collapse:collapse; margin-bottom:16px; }
  .property-details-table td { padding:8px 0; border-bottom:1px solid var(--sitora-border); color:var(--sitora-text); }
  .property-details-table td:first-child { color:var(--sitora-subtext); }
  .property-description { color:var(--sitora-text); }
  .vcard-btn { display:inline-block; padding:12px 24px; border-radius:var(--sitora-radius-btn); background:var(--sitora-accent); color:var(--sitora-accent-text); text-decoration:none; font-weight:700; margin-top:16px; }
  .floating-contact-btn { position:fixed; right:18px; bottom:18px; width:56px; height:56px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:26px; text-decoration:none; box-shadow:0 6px 18px rgba(0,0,0,0.28); z-index:998; }
  .floating-contact-btn.wa { background:#25D366; }
  .floating-contact-btn.call { background:var(--sitora-accent); }
  @media (max-width:600px) { .floating-contact-btn { right:14px; bottom:14px; width:52px; height:52px; font-size:23px; } }
  .site-nav { position:sticky; top:0; z-index:997; background:var(--sitora-card-bg); border-bottom:1px solid var(--sitora-border); backdrop-filter: saturate(180%) blur(14px); -webkit-backdrop-filter: saturate(180%) blur(14px); }
  /* 28.09.2026 GÜNCELLENDİ (kanka isteği) — üst menü artık kayan (yatay
     scroll) şerit DEĞİL. Sığıyorsa tüm linkler yan yana (masaüstü); sığmıyorsa
     (dar ekran VEYA çok/uzun link) otomatik hamburger menüye (☰) dönüşür.
     Sığıp sığmadığına sayfa sonundaki küçük JS karar verir (.is-collapsed);
     JS çalışmasa bile <=760px'de CSS ile hamburger devreye girer. */
  .site-nav-inner { max-width:1160px; margin:0 auto; display:flex; align-items:center; justify-content:space-between; gap:16px; padding:0 20px; height:68px; }
  .site-nav-brand { display:flex; align-items:center; gap:10px; flex-shrink:0; min-width:0; font-weight:800; font-size:16px; letter-spacing:-0.01em; color:var(--sitora-text); text-decoration:none; }
  .site-nav-brand img { width:34px; height:34px; border-radius:50%; object-fit:cover; flex-shrink:0; }
  .site-nav-brand span { display:block; max-width:min(320px, 45vw); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; overflow-wrap:normal; word-break:normal; }
  .site-nav-links { display:flex; flex-shrink:0; gap:4px; }
  .site-nav-link { flex-shrink:0; padding:10px 12px; color:var(--sitora-subtext); text-decoration:none; font-weight:600; font-size:14px; border-bottom:2px solid transparent; white-space:nowrap; transition: color 0.18s ease; }
  .site-nav-link:hover { color: var(--sitora-text); }
  .site-nav-link.active { color:var(--sitora-accent); border-bottom-color:var(--sitora-accent); }
  .site-nav-toggle { display:none; flex-shrink:0; width:42px; height:42px; padding:0; border:1px solid var(--sitora-border); border-radius:var(--sitora-radius-btn); background:transparent; cursor:pointer; align-items:center; justify-content:center; flex-direction:column; gap:5px; }
  .site-nav-toggle span { display:block; width:20px; height:2px; border-radius:2px; background:var(--sitora-text); transition: transform 0.2s ease, opacity 0.2s ease; }
  .site-nav.open .site-nav-toggle span:nth-child(1) { transform: translateY(7px) rotate(45deg); }
  .site-nav.open .site-nav-toggle span:nth-child(2) { opacity:0; }
  .site-nav.open .site-nav-toggle span:nth-child(3) { transform: translateY(-7px) rotate(-45deg); }
  .site-nav.is-collapsed .site-nav-brand { flex-shrink:1; }
  .site-nav.is-collapsed .site-nav-toggle { display:flex; }
  .site-nav.is-collapsed .site-nav-links { display:none; position:absolute; top:100%; left:0; right:0; flex-direction:column; gap:0; padding:8px 12px 14px; background:var(--sitora-card-bg); border-bottom:1px solid var(--sitora-border); box-shadow:0 18px 30px rgba(0,0,0,0.18); max-height:calc(100vh - 68px); overflow-y:auto; }
  .site-nav.is-collapsed.open .site-nav-links { display:flex; }
  .site-nav.is-collapsed .site-nav-link { padding:14px 12px; font-size:16px; white-space:normal; border-bottom:none; border-left:3px solid transparent; border-radius:6px; }
  .site-nav.is-collapsed .site-nav-link.active { border-left-color:var(--sitora-accent); background:var(--sitora-chip-bg); }
  @media (max-width: 760px) {
    .site-nav-brand { flex-shrink:1; }
    .site-nav-toggle { display:flex; }
    .site-nav-links { display:none; position:absolute; top:100%; left:0; right:0; flex-direction:column; gap:0; padding:8px 12px 14px; background:var(--sitora-card-bg); border-bottom:1px solid var(--sitora-border); box-shadow:0 18px 30px rgba(0,0,0,0.18); max-height:calc(100vh - 68px); overflow-y:auto; }
    .site-nav.open .site-nav-links { display:flex; }
    .site-nav-link { padding:14px 12px; font-size:16px; white-space:normal; border-bottom:none; border-left:3px solid transparent; border-radius:6px; }
    .site-nav-link.active { border-left-color:var(--sitora-accent); background:var(--sitora-chip-bg); }
  }
  .randevu-form button, .sitora-lead-form button, .contact-form button {
    transition: transform 0.18s ease, box-shadow 0.18s ease, opacity 0.18s ease;
  }
  .randevu-form button:hover, .sitora-lead-form button:hover, .contact-form button:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 22px rgba(0,0,0,0.18);
  }
  h1, h2, h3 { letter-spacing: -0.02em; }
$glassCardCss
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
<script>
(function(){
  // 28.09.2026 eklendi (kanka isteği) — üst menü: sığıyorsa yan yana,
  // sığmıyorsa hamburger. Ölçüm pencere boyutu/yazı tipi yüklemesi değişince tekrarlanır.
  var nav = document.querySelector('.site-nav');
  if (!nav) return;
  var inner = nav.querySelector('.site-nav-inner');
  var btn = nav.querySelector('.site-nav-toggle');
  function setOpen(v){
    nav.classList.toggle('open', v);
    if (btn) btn.setAttribute('aria-expanded', v ? 'true' : 'false');
  }
  function measure(){
    setOpen(false);
    nav.classList.remove('is-collapsed');
    if (inner.scrollWidth > inner.clientWidth + 1) nav.classList.add('is-collapsed');
  }
  var raf;
  function schedule(){ cancelAnimationFrame(raf); raf = requestAnimationFrame(measure); }
  measure();
  window.addEventListener('resize', schedule);
  window.addEventListener('load', schedule);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(schedule);
  if (btn) btn.addEventListener('click', function(e){ e.stopPropagation(); setOpen(!nav.classList.contains('open')); });
  nav.querySelectorAll('.site-nav-link').forEach(function(a){ a.addEventListener('click', function(){ setOpen(false); }); });
  document.addEventListener('click', function(e){ if (!nav.contains(e.target)) setOpen(false); });
  document.addEventListener('keydown', function(e){ if (e.key === 'Escape') setOpen(false); });
})();
</script>
</body>
</html>''';
}
