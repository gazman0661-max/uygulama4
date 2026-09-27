import 'shared_html_blocks.dart';
import 'section_registry.dart';

/// clinic_template'in HTML karşılığı. extended_business_html_generator ile
/// aynı temel (WorkingDay/LocationInfo/ContactInfo) yapıyı kullanır ama
/// paket/ekip yerine tekil "Uzman Tanıtımı" (PractitionerProfile) bölümü
/// vardır, bu yüzden ayrı fonksiyon olarak tutuldu.
///
/// dentist/dietitian/lawyer/veterinarian bu fonksiyonu AYNEN kullanıyor,
/// sadece kullanıcı verisi (unvan, hizmetler vb.) değişiyor — bu yüzden
/// tüm sabit metinler burada `lang`'a göre siteLabels()'tan geliyor,
/// ayrı bir sectorKey gerekmiyor (kuafor ailesinden farkı bu).
String generateClinicHtml({
  required String businessName,
  required String title, // "Uzman Psikolog" gibi unvan
  required String photoUrl,
  String? logoImage, // 17.09.2026 eklendi
  required String tagline,
  // 27.09.2026 eklendi (kanka isteği) — bu aileye "Hakkında" bloğu eklendi
  // (önceden sadece services + team/practitioner.bio üzerinden
  // anlatılıyordu, diğer 28 sektörden farkı buydu — artık aynı kalıp).
  String? about,
  List<Map<String, String?>> services = const [],
  Map<String, dynamic>? practitioner, // {name, title, photoUrl, bio, credentials:[{label}]}
  // 27.09.2026 eklendi (kanka isteği) — bu aileye galeri eklendi (bkz.
  // section_registry.dart > kClinicDefaultOrder dokümanı). Önceden bu
  // aile hiç galeri kabul etmiyordu, galleryStyle parametresi (aşağıda)
  // ölü kod olarak duruyordu — artık gerçekten kullanılıyor.
  List<Map<String, String?>> gallery = const [],
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink, // 01.09.2026 eklendi
  // 05.09.2026 eklendi — Video bloğu (kanka isteği).
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  String themeId = 'clean_light',
  Map<String, String>? customTheme, // 17.09.2026 eklendi ('Özel Tema' B seçeneği)
  Map<String, String>? customFontPackage, // 18.09.2026 eklendi ('Serbest Font Seçimi')
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  // 07.09.2026 eklendi (kanka isteği) — hero düzeni seçimi.
  String heroLayoutStyle = 'centered',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true, // 05.09.2026 eklendi
  // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle (bkz.
  // kuafor_html_generator.dart dokümanı, aynı kalıp). SADECE bu tek-sayfa
  // fonksiyonu etkiler, generateClinicSite (çok sayfa) kapsam dışı.
  List<String>? sectionOrder,
}) {
  // 11.09.2026 eklendi — bkz. shared_html_blocks.dart > shapeStyleOf.
  final siteShapeStyle = pickVariant(businessName, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final specialtiesTitle = lang == 'en' ? 'Areas of Expertise' : 'Uzmanlık Alanları';

  body.writeln(heroBlockHtml(
    name: businessName,
    tagline: '$title — $tagline',
    coverImage: photoUrl,
    logoImage: logoImage, // 17.09.2026 eklendi
    ctaText: labels['reservation']!,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : 'tel:$phone',
    layoutStyle: heroLayoutStyle,
  ));

  // 27.09.2026 eklendi (kanka isteği — kalite artırma) — bkz.
  // kuafor_html_generator.dart > generateBusinessSiteHtml dokümanı, AYNI
  // kalıp: tek sayfalık klinik/uzman sitelerinde de üstte sabit bir
  // marka+menü şeridi.
  final navAnchorIds = <String, String>{
    'services': 'hizmetler',
    'gallery': 'galeri',
    'faq': 'sss',
  };
  final navLinks = <Map<String, String>>[
    {'href': '#', 'label': labels['home']!},
  ];

  // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle (bkz.
  // kuafor_html_generator.dart dokümanı, aynı kalıp).
  final middleBuilders = <String, String? Function()>{
    // 27.09.2026 eklendi (kanka isteği) — bkz. dosya başındaki 'about' notu.
    'about': () => (about != null && about.isNotEmpty)
        ? '<section class="section about-section"><p>${escapeHtml(about)}</p></section>'
        : null,
    'services': () => services.isNotEmpty
        ? serviceListBlockHtml(title: specialtiesTitle, services: services)
        : null,
    // 27.09.2026 eklendi (kanka isteği) — bkz. dosya başındaki 'gallery'
    // parametresi notu.
    'gallery': () => gallery.isNotEmpty
        ? galleryBlockHtml(style: galleryStyle, title: labels['gallery']!, images: gallery)
        : null,
    'team': () => practitioner != null
        ? practitionerBlockHtml(
            name: practitioner['name']?.toString() ?? businessName,
            title: practitioner['title']?.toString() ?? title,
            photoUrl: practitioner['photoUrl']?.toString() ?? photoUrl,
            bio: practitioner['bio']?.toString() ?? '',
            credentials: (practitioner['credentials'] as List? ?? [])
                .map((c) => {'label': (c as Map)['label']?.toString()})
                .toList()
                .cast<Map<String, String?>>(),
          )
        : null,
    'video': () => (videoUrl != null && videoUrl.trim().isNotEmpty)
        ? videoBlockHtml(title: videoTitle ?? labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
        : null,
    'hours': () => workingHours.isNotEmpty
        ? workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang)
        : null,
    'testimonials': () => testimonials.isNotEmpty
        ? testimonialBlockHtml(testimonials: testimonials, lang: lang)
        : null,
    'faq': () => faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : null,
    'map': () {
      if (address.trim().isEmpty) return null;
      if (lat != null && lng != null) {
        return mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang);
      }
      return '<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>';
    },
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kClinicDefaultOrder
      : sectionOrder;
  for (final sectionId in effectiveOrder) {
    final html = middleBuilders[sectionId]?.call();
    if (html == null) continue;
    final anchorId = navAnchorIds[sectionId];
    if (anchorId == null) {
      body.writeln(html);
      continue;
    }
    body.writeln(html.replaceFirst('<section class="', '<section id="$anchorId" class="'));
    final navLabel = switch (sectionId) {
      'services' => specialtiesTitle,
      'gallery' => labels['gallery']!,
      'faq' => labels['faqTitle']!,
      _ => sectionId,
    };
    navLinks.add({'href': '#$anchorId', 'label': navLabel});
  }
  final contactAnchorId = 'iletisim-${businessName.hashCode.abs()}';
  navLinks.add({'href': '#$contactAnchorId', 'label': labels['contact']!});

  body.writeln(contactBlockHtml(
    title: labels['contact']!,
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
    includeLeadForm: includeLeadForm,
  ).replaceFirst('<section class="', '<section id="$contactAnchorId" class="'));

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
    pageTitle: businessName,
    bodyHtml: body.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: tagline,
    ogImage: photoUrl,
    schemaType: 'MedicalBusiness',
    whatsapp: whatsapp,
    phone: phone,
    lang: lang,
    navHtml: siteNavHtml(links: navLinks, active: '#', siteName: businessName, logoImage: logoImage),
  );
}

/// --- ÇOK SAYFALI MOD (B) ---
/// generateClinicHtml (yukarısı) tek sayfalık modda AYNEN duruyor.
/// Bu fonksiyon aynı verilerden 3 ayrı dosya üretir: index.html (ana
/// sayfa: hero+kısa tanıtım+öne çıkan uzmanlık alanları+çalışma saatleri
/// önizleme+harita+iletişim), hizmetler.html (tam uzmanlık alanları
/// listesi + hekim/uzman profili detayı — bio+sertifikalar) ve
/// randevu.html (çalışma saatleri+harita+iletişim formu+telefon/WhatsApp).
/// cafe_html_generator.dart'taki generateCafeSite ile aynı kalıp.
Map<String, String> generateClinicSite({
  required String businessName,
  required String title,
  required String photoUrl,
  String? logoImage, // 17.09.2026 eklendi
  required String tagline,
  // 27.09.2026 eklendi (kanka isteği) — bkz. generateClinicHtml (yukarısı)
  // > 'about' parametresi notu, aynı kalıp.
  String? about,
  List<Map<String, String?>> services = const [],
  Map<String, dynamic>? practitioner,
  // 27.09.2026 eklendi (kanka isteği) — bkz. generateClinicHtml (yukarısı)
  // > 'gallery' parametresi notu, aynı kalıp.
  List<Map<String, String?>> gallery = const [],
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink, // 01.09.2026 eklendi
  // 05.09.2026 eklendi — Video bloğu (kanka isteği).
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  String themeId = 'clean_light',
  Map<String, String>? customTheme, // 17.09.2026 eklendi ('Özel Tema' B seçeneği)
  Map<String, String>? customFontPackage, // 18.09.2026 eklendi ('Serbest Font Seçimi')
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  // 07.09.2026 eklendi (kanka isteği) — hero düzeni seçimi.
  String heroLayoutStyle = 'centered',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true, // 05.09.2026 eklendi
  // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle, SADECE
  // index.html'in orta blokları için (bkz. section_registry.dart >
  // kClinicMultiPageHomeDefaultOrder dokümanı). Sayfa/nav sırası
  // (hizmetler.html, randevu.html) bu özelliğin kapsamı DIŞINDA.
  List<String>? sectionOrder,
}) {
  // 11.09.2026 eklendi — bkz. shared_html_blocks.dart > shapeStyleOf.
  final siteShapeStyle = pickVariant(businessName, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final files = <String, String>{};
  final labels = siteLabels(lang);
  final specialtiesTitle = lang == 'en' ? 'Areas of Expertise' : 'Uzmanlık Alanları';
  final servicesPageLabel = lang == 'en' ? 'Services' : 'Hizmetler';
  final appointmentPageLabel = lang == 'en' ? 'Appointment' : 'Randevu';

  final navLinks = [
    {'label': labels['home']!, 'href': 'index.html'},
    if (services.isNotEmpty || practitioner != null || faqs.isNotEmpty || testimonials.isNotEmpty)
      {'label': servicesPageLabel, 'href': 'hizmetler.html'},
    {'label': appointmentPageLabel, 'href': 'randevu.html'},
  ];

  Map<String, String?> practitionerData(String key, String fallback) =>
      practitioner != null && practitioner[key] != null
          ? {key: practitioner[key].toString()}
          : {key: fallback};

  // --- index.html ---
  final homeBody = StringBuffer();
  homeBody.writeln(heroBlockHtml(
    name: businessName,
    tagline: '$title — $tagline',
    coverImage: photoUrl,
    logoImage: logoImage, // 17.09.2026 eklendi
    ctaText: labels['reservation']!,
    ctaHref: 'randevu.html',
    layoutStyle: heroLayoutStyle,
  ));
  // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle (index.html'in
  // orta blokları). NOT: address var ama lat/lng yoksa (orijinal kodda
  // olduğu gibi) harita gösterilmiyor — çok sayfa modunda adres metni
  // fallback'i YOK (tek sayfa modundan farkı, bilerek korundu).
  final homeMiddleBuilders = <String, String? Function()>{
    // 27.09.2026 eklendi (kanka isteği) — bkz. generateClinicHtml > 'about' notu.
    'about': () => (about != null && about.isNotEmpty)
        ? '<section class="section about-section"><p>${escapeHtml(about)}</p></section>'
        : null,
    'services': () {
      if (services.isEmpty) return null;
      final preview = services.take(4).toList();
      return serviceListBlockHtml(title: specialtiesTitle, services: preview);
    },
    // 27.09.2026 eklendi (kanka isteği) — bkz. generateClinicHtml > 'gallery' notu.
    'gallery': () => gallery.isNotEmpty
        ? galleryBlockHtml(style: galleryStyle, title: labels['gallery']!, images: gallery)
        : null,
    'video': () => (videoUrl != null && videoUrl.trim().isNotEmpty)
        ? videoBlockHtml(title: videoTitle ?? labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
        : null,
    'hours': () => workingHours.isNotEmpty
        ? workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang)
        : null,
    'map': () => (address.trim().isNotEmpty && lat != null && lng != null)
        ? mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang)
        : null,
  };
  final homeEffectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kClinicMultiPageHomeDefaultOrder
      : sectionOrder;
  for (final sectionId in homeEffectiveOrder) {
    final html = homeMiddleBuilders[sectionId]?.call();
    if (html != null) homeBody.writeln(html);
  }
  homeBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang, includeLeadForm: includeLeadForm));

  files['index.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
    pageTitle: businessName,
    bodyHtml: homeBody.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: tagline,
    ogImage: photoUrl,
    schemaType: 'MedicalBusiness',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'index.html', siteName: name, logoImage: logoImage),
    lang: lang,
  );

  // --- hizmetler.html (uzmanlık alanları + hekim profili + SSS/yorumlar) ---
  if (services.isNotEmpty || practitioner != null || faqs.isNotEmpty || testimonials.isNotEmpty) {
    final svcBody = StringBuffer();
    if (services.isNotEmpty) {
      svcBody.writeln(serviceListBlockHtml(title: specialtiesTitle, services: services));
    }
    if (practitioner != null) {
      svcBody.writeln(practitionerBlockHtml(
        name: practitioner['name']?.toString() ?? businessName,
        title: practitioner['title']?.toString() ?? title,
        photoUrl: practitioner['photoUrl']?.toString() ?? photoUrl,
        bio: practitioner['bio']?.toString() ?? '',
        credentials: (practitioner['credentials'] as List? ?? [])
            .map((c) => {'label': (c as Map)['label']?.toString()})
            .toList()
            .cast<Map<String, String?>>(),
      ));
    }
    if (testimonials.isNotEmpty) {
      svcBody.writeln(testimonialBlockHtml(testimonials: testimonials, lang: lang));
    }
    if (faqs.isNotEmpty) {
      svcBody.writeln(faqBlockHtml(faqs: faqs, lang: lang));
    }
    svcBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang, includeLeadForm: includeLeadForm));

    files['hizmetler.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      shapeStyle: siteShapeStyle,
      pageTitle: '$businessName — $servicesPageLabel',
      bodyHtml: svcBody.toString(),
      themeId: themeId,
      customTheme: customTheme,
      customFontPackage: customFontPackage,
      metaDescription: '$servicesPageLabel — $businessName',
      ogImage: photoUrl,
      schemaType: 'MedicalBusiness',
      whatsapp: whatsapp,
      phone: phone,
      navHtml: siteNavHtml(links: navLinks, active: 'hizmetler.html', siteName: name, logoImage: logoImage),
      lang: lang,
    );
  }

  // --- randevu.html (çalışma saatleri + harita + iletişim formu) ---
  final apptBody = StringBuffer();
  apptBody.writeln('<section class="section" style="text-align:center; padding-bottom:0;"><h1 class="section-title" style="margin-bottom:0;">$appointmentPageLabel</h1></section>');
  if (workingHours.isNotEmpty) {
    apptBody.writeln(workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang));
  }
  if (address.trim().isNotEmpty && lat != null && lng != null) {
    apptBody.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  } else if (address.trim().isNotEmpty) {
    apptBody.writeln('<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>');
  }
  // 05.09.2026 değişti (kanka isteği) — önceden burada mailto tabanlı
  // contactFormBlockHtml (sahte bir "$whatsapp@wa.contact" adresine giden,
  // gerçekte hiçbir yere ulaşmayan bir form) HEM DE aşağıdaki contactBlockHtml
  // (zaten kendi içinde Talep Kutusu formunu barındırıyor) art arda
  // basılıyordu. Sahte/bozuk mailto satırı kaldırıldı, tek ve gerçek çalışan
  // form (Talep Kutusu) kaldı.
  apptBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang, siteName: businessName, includeLeadForm: includeLeadForm));

  files['randevu.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
    pageTitle: '$businessName — $appointmentPageLabel',
    bodyHtml: apptBody.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: '$appointmentPageLabel — $businessName',
    ogImage: photoUrl,
    schemaType: 'MedicalBusiness',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'randevu.html', siteName: name, logoImage: logoImage),
    lang: lang,
  );

  return files;
}
