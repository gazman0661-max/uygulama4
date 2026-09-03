import 'shared_html_blocks.dart';

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
  required String tagline,
  List<Map<String, String?>> services = const [],
  Map<String, dynamic>? practitioner, // {name, title, photoUrl, bio, credentials:[{label}]}
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink, // 01.09.2026 eklendi
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
}) {
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final specialtiesTitle = lang == 'en' ? 'Areas of Expertise' : 'Uzmanlık Alanları';

  body.writeln(heroBlockHtml(
    name: businessName,
    tagline: '$title — $tagline',
    coverImage: photoUrl,
    ctaText: labels['reservation']!,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : 'tel:$phone',
  ));

  if (services.isNotEmpty) {
    body.writeln(serviceListBlockHtml(title: specialtiesTitle, services: services));
  }

  if (practitioner != null) {
    body.writeln(practitionerBlockHtml(
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

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang));
  }

  if (testimonials.isNotEmpty) {
    body.writeln(testimonialBlockHtml(testimonials: testimonials, lang: lang));
  }

  if (faqs.isNotEmpty) {
    body.writeln(faqBlockHtml(faqs: faqs, lang: lang));
  }

  if (address.trim().isNotEmpty && lat != null && lng != null) {
    body.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  } else if (address.trim().isNotEmpty) {
    body.writeln('<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>');
  }

  body.writeln(contactBlockHtml(
    title: labels['contact']!,
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
  ));

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: businessName,
    bodyHtml: body.toString(),
    themeId: themeId,
    metaDescription: tagline,
    ogImage: photoUrl,
    schemaType: 'MedicalBusiness',
    whatsapp: whatsapp,
    phone: phone,
    lang: lang,
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
  required String tagline,
  List<Map<String, String?>> services = const [],
  Map<String, dynamic>? practitioner,
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink, // 01.09.2026 eklendi
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
}) {
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
    ctaText: labels['reservation']!,
    ctaHref: 'randevu.html',
  ));
  if (services.isNotEmpty) {
    final preview = services.take(4).toList();
    homeBody.writeln(serviceListBlockHtml(title: specialtiesTitle, services: preview));
  }
  if (workingHours.isNotEmpty) {
    homeBody.writeln(workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang));
  }
  if (address.trim().isNotEmpty && lat != null && lng != null) {
    homeBody.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  }
  homeBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang));

  files['index.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: businessName,
    bodyHtml: homeBody.toString(),
    themeId: themeId,
    metaDescription: tagline,
    ogImage: photoUrl,
    schemaType: 'MedicalBusiness',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'index.html'),
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
    svcBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang));

    files['hizmetler.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      pageTitle: '$businessName — $servicesPageLabel',
      bodyHtml: svcBody.toString(),
      themeId: themeId,
      metaDescription: '$servicesPageLabel — $businessName',
      ogImage: photoUrl,
      schemaType: 'MedicalBusiness',
      whatsapp: whatsapp,
      phone: phone,
      navHtml: siteNavHtml(links: navLinks, active: 'hizmetler.html'),
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
  if (whatsapp != null) {
    apptBody.writeln(contactFormBlockHtml(title: labels['contact']!, email: '$whatsapp@wa.contact', lang: lang));
  }
  apptBody.writeln(contactBlockHtml(title: '', phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang));

  files['randevu.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: '$businessName — $appointmentPageLabel',
    bodyHtml: apptBody.toString(),
    themeId: themeId,
    metaDescription: '$appointmentPageLabel — $businessName',
    ogImage: photoUrl,
    schemaType: 'MedicalBusiness',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'randevu.html'),
    lang: lang,
  );

  return files;
}
