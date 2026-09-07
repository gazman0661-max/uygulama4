import 'shared_html_blocks.dart';

/// kafe_site_template paketi, kuaförle AYNI BusinessSite modelini kullanıyor
/// (services yerine menuCategories dolu geliyor). Bu yüzden ayrı bir model
/// tanımına gerek yok — kuafor_html_generator.dart'taki
/// generateBusinessSiteHtml'i services=[] geçip menuCategories ekleyerek
/// çağırmak da mümkündü, ama menü + QR menü ayrı bir görsel blok olduğu
/// için kafeye özel bir sarmalayıcı yazıldı.
///
/// `lang`: üretilen SİTENİN dili ('tr' | 'en') — uygulama arayüzü dilinden
/// (app_strings.dart) BAĞIMSIZ. Kullanıcının kendi girdiği isim/açıklama/
/// menü metinleri olduğu gibi kalır, sadece "Menü/Menu", "Konum/Location"
/// gibi sabit başlık ve butonlar buna göre değişir (bkz. siteLabels).
String generateCafeHtml({
  required String name,
  required String coverImage,
  String? logoImage,
  required String tagline,
  String? about,
  required List<Map<String, dynamic>> menuCategories, // {title, items:[{name, description, price}]}
  String? menuUrl, // QR menü linki
  required List<Map<String, String?>> gallery,
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink, // 01.09.2026 eklendi
  // 05.09.2026 eklendi — Video bloğu (kanka isteği). bkz. kuafor_html_generator.dart
  // > generateBusinessSiteHtml AYNI parametreler/AYNI davranış.
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  // 07.09.2026 eklendi (kanka isteği) — hero düzeni seçimi (bkz.
  // shared_html_blocks.dart > heroBlockHtml/premiumLayoutStyleIds).
  // 'framed' PREMİUM'dur, kilitleme burada değil LocalGenerationHelper'da
  // yapılır — bu fonksiyon her zaman geleni aynen üretir.
  String heroLayoutStyle = 'centered',
  // Restoran/fırın-pastane gibi kafeyle AYNI menü+galeri+harita yapısını
  // kullanan ama farklı schema.org tipi ve CTA metni isteyen sektörler
  // için eklendi (bkz. restaurant_form_screen.dart, bakery_form_screen.dart).
  // Verilmezse önceki davranış AYNEN korunur (geriye dönük uyumlu).
  String schemaType = 'CafeOrCoffeeShop',
  String? ctaText,
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true, // 05.09.2026 eklendi
}) {
  final body = StringBuffer();
  final accentColor = themeAccent(themeId);
  final labels = siteLabels(lang);
  final resolvedCtaText = ctaText ?? labels['reservation']!;

  body.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    logoImage: logoImage,
    ctaText: resolvedCtaText,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : 'tel:$phone',
    layoutStyle: heroLayoutStyle,
  ));

  if (about != null && about.isNotEmpty) {
    body.writeln('<section class="section about-section"><p>${escapeHtml(about)}</p></section>');
  }

  if (menuCategories.isNotEmpty) {
    body.writeln(menuBlockHtml(title: labels['menu']!, categories: menuCategories));
  }

  if (menuUrl != null) {
    body.writeln('''
<section class="section qr-menu-section" style="text-align:center;">
  <a class="hero-cta" style="background:$accentColor;" href="${escapeHtml(menuUrl)}" target="_blank">${labels['openDigitalMenu']}</a>
</section>''');
  }

  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: labels['gallery']!, images: gallery));
  }

  if (videoUrl != null && videoUrl.trim().isNotEmpty) {
    body.writeln(videoBlockHtml(
      title: videoTitle ?? labels['videoTitle']!,
      videoUrl: videoUrl,
      orientation: videoOrientation,
      lang: lang,
    ));
  }

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang));
  }

  if (testimonials.isNotEmpty) {
    body.writeln(testimonialBlockHtml(testimonials: testimonials, lang: lang));
  }

  if (faqs.isNotEmpty) {
    body.writeln(faqBlockHtml(faqs: faqs, lang: lang));
  }

  if (address.trim().isNotEmpty) {
    body.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  }

  body.writeln(contactBlockHtml(
    title: labels['contact']!,
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
    includeLeadForm: includeLeadForm,
  ));

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: name,
    bodyHtml: body.toString(),
    themeId: themeId,
    metaDescription: (about != null && about.isNotEmpty) ? about : tagline,
    ogImage: coverImage,
    schemaType: schemaType,
    whatsapp: whatsapp,
    phone: phone,
    lang: lang,
  );
}

/// --- ÇOK SAYFALI MOD (B) ---
/// generateCafeHtml (yukarısı) tek sayfalık modda AYNEN duruyor ve
/// değiştirilmedi. Bu fonksiyon aynı verilerden 3 ayrı dosya üretir:
/// index.html (ana sayfa: hero+hakkında+öne çıkan menü+çalışma saatleri+
/// harita+iletişim), menu.html (tam menü) ve gallery.html (tam galeri).
/// real_estate_html_generator.dart'taki generateRealEstateSite ile aynı
/// kalıp: Map<String,String> döner, LocalGenerationHelper.generateMultiPage
/// ile doğrudan appState'e yazılabilir.
Map<String, String> generateCafeSite({
  required String name,
  required String coverImage,
  String? logoImage,
  required String tagline,
  String? about,
  required List<Map<String, dynamic>> menuCategories,
  String? menuUrl,
  required List<Map<String, String?>> gallery,
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink, // 01.09.2026 eklendi
  // 05.09.2026 eklendi — Video bloğu (kanka isteği).
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true, // 05.09.2026 eklendi
}) {
  final files = <String, String>{};
  final accentColor = themeAccent(themeId);
  final labels = siteLabels(lang);

  final navLinks = [
    {'label': labels['home']!, 'href': 'index.html'},
    {'label': labels['menu']!, 'href': 'menu.html'},
    if (gallery.isNotEmpty) {'label': labels['gallery']!, 'href': 'gallery.html'},
  ];

  // --- index.html ---
  final homeBody = StringBuffer();
  homeBody.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    logoImage: logoImage,
    ctaText: labels['goToMenu']!,
    ctaHref: 'menu.html',
    layoutStyle: heroLayoutStyle,
  ));
  if (about != null && about.isNotEmpty) {
    homeBody.writeln('<section class="section about-section"><p>${escapeHtml(about)}</p></section>');
  }
  if (menuCategories.isNotEmpty) {
    // Ana sayfada sadece ilk kategori "öne çıkan" olarak gösterilir, tam
    // menü menu.html'de.
    homeBody.writeln(menuBlockHtml(title: labels['menuHighlights']!, categories: [menuCategories.first]));
    homeBody.writeln('''
<section class="section" style="text-align:center; padding-top:0;">
  <a class="hero-cta" style="background:$accentColor;" href="menu.html">${labels['viewFullMenu']}</a>
</section>''');
  }
  if (menuUrl != null) {
    homeBody.writeln('''
<section class="section qr-menu-section" style="text-align:center;">
  <a class="hero-cta" style="background:$accentColor;" href="${escapeHtml(menuUrl)}" target="_blank">${labels['openDigitalMenu']}</a>
</section>''');
  }
  if (workingHours.isNotEmpty) {
    homeBody.writeln(workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang));
  }
  if (videoUrl != null && videoUrl.trim().isNotEmpty) {
    homeBody.writeln(videoBlockHtml(
      title: videoTitle ?? labels['videoTitle']!,
      videoUrl: videoUrl,
      orientation: videoOrientation,
      lang: lang,
    ));
  }
  if (testimonials.isNotEmpty) {
    homeBody.writeln(testimonialBlockHtml(testimonials: testimonials, lang: lang));
  }
  if (faqs.isNotEmpty) {
    homeBody.writeln(faqBlockHtml(faqs: faqs, lang: lang));
  }
  if (address.trim().isNotEmpty) {
    homeBody.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  }
  homeBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang, includeLeadForm: includeLeadForm));

  files['index.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: name,
    bodyHtml: homeBody.toString(),
    themeId: themeId,
    metaDescription: (about != null && about.isNotEmpty) ? about : tagline,
    ogImage: coverImage,
    schemaType: 'CafeOrCoffeeShop',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'index.html'),
    lang: lang,
  );

  // --- menu.html ---
  final menuBody = StringBuffer();
  menuBody.writeln('<section class="section" style="text-align:center; padding-bottom:0;"><h1 class="section-title" style="margin-bottom:0;">${escapeHtml(name)} — ${labels['menu']}</h1></section>');
  if (menuCategories.isNotEmpty) {
    menuBody.writeln(menuBlockHtml(title: '', categories: menuCategories));
  }
  if (menuUrl != null) {
    menuBody.writeln('''
<section class="section qr-menu-section" style="text-align:center; padding-top:0;">
  <a class="hero-cta" style="background:$accentColor;" href="${escapeHtml(menuUrl)}" target="_blank">${labels['openDigitalMenu']}</a>
</section>''');
  }
  menuBody.writeln(contactBlockHtml(title: labels['reservationOrder']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang, includeLeadForm: includeLeadForm));

  files['menu.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: '$name — ${labels['menu']}',
    bodyHtml: menuBody.toString(),
    themeId: themeId,
    metaDescription: '${labels['menu']} — $name',
    ogImage: coverImage,
    schemaType: 'CafeOrCoffeeShop',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'menu.html'),
    lang: lang,
  );

  // --- gallery.html (varsa) ---
  if (gallery.isNotEmpty) {
    final galleryBody = StringBuffer();
    galleryBody.writeln(galleryBlockHtml(
    style: galleryStyle,title: labels['gallery']!, images: gallery));
    galleryBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang, includeLeadForm: includeLeadForm));

    files['gallery.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      pageTitle: '$name — ${labels['gallery']}',
      bodyHtml: galleryBody.toString(),
      themeId: themeId,
      metaDescription: '${labels['gallery']} — $name',
      ogImage: coverImage,
      schemaType: 'CafeOrCoffeeShop',
      whatsapp: whatsapp,
      phone: phone,
      navHtml: siteNavHtml(links: navLinks, active: 'gallery.html'),
      lang: lang,
    );
  }

  return files;
}
