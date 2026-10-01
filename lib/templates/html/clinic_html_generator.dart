import 'shared_html_blocks.dart';
import 'section_registry.dart';

String generateClinicHtml({
  required String businessName,
  required String title,
  required String photoUrl,
  String? logoImage,
  required String tagline,
  String? about,
  List<Map<String, String?>> services = const [],
  Map<String, dynamic>? practitioner,
  List<Map<String, String?>> gallery = const [],
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink,
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  String heroLayoutStyle = 'centered',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true,
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
  final siteShapeStyle = pickVariant(businessName, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final specialtiesTitle = lang == 'en' ? 'Areas of Expertise' : 'Uzmanlık Alanları';

  body.writeln(heroBlockHtml(
    name: businessName,
    tagline: '$title — $tagline',
    coverImage: photoUrl,
    omitWithoutCover: true,
    logoImage: logoImage,
    ctaText: labels['reservation']!,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : (phone.isNotEmpty ? 'tel:$phone' : null),
    layoutStyle: heroLayoutStyle,
    featuredTestimonial: testimonials.isNotEmpty ? testimonials.first : null,
    workingHours: heroHoursFor(workingHours, sectionOrder),
    lang: lang,
  ));

  if (showTrustBar) {
    body.writeln(trustBarBlockHtml(
      serviceCount: services.length,
      galleryCount: gallery.length,
      testimonialCount: testimonials.length,
      hasGoogleReview: googleReviewLink != null && googleReviewLink.trim().isNotEmpty,
      lang: lang,
    ));
  }

  final navAnchorIds = <String, String>{
    'services': 'hizmetler',
    'gallery': 'galeri',
    'faq': 'sss',
  };
  final navLinks = <Map<String, String>>[
    {'href': '#', 'label': labels['home']!},
  ];

  final middleBuilders = <String, String? Function()>{
    'about': () => (about != null && about.isNotEmpty)
        ? '<section class="section about-section"><p>${escapeHtml(about)}</p></section>'
        : null,
    'services': () => services.isNotEmpty
        ? serviceListBlockHtml(title: specialtiesTitle, services: services)
        : null,
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

Map<String, String> generateClinicSite({
  required String businessName,
  required String title,
  required String photoUrl,
  String? logoImage,
  required String tagline,
  String? about,
  List<Map<String, String?>> services = const [],
  Map<String, dynamic>? practitioner,
  List<Map<String, String?>> gallery = const [],
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink,
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  String heroLayoutStyle = 'centered',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true,
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
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

  final homeBody = StringBuffer();
  homeBody.writeln(heroBlockHtml(
    name: businessName,
    tagline: '$title — $tagline',
    coverImage: photoUrl,
    omitWithoutCover: true,
    logoImage: logoImage,
    ctaText: labels['reservation']!,
    ctaHref: 'randevu.html',
    layoutStyle: heroLayoutStyle,
    featuredTestimonial: testimonials.isNotEmpty ? testimonials.first : null,
    workingHours: heroHoursFor(workingHours, sectionOrder),
    lang: lang,
  ));
  if (showTrustBar) {
    homeBody.writeln(trustBarBlockHtml(
      serviceCount: services.length,
      galleryCount: gallery.length,
      testimonialCount: testimonials.length,
      hasGoogleReview: googleReviewLink != null && googleReviewLink.trim().isNotEmpty,
      lang: lang,
    ));
  }
  final homeMiddleBuilders = <String, String? Function()>{
    'about': () => (about != null && about.isNotEmpty)
        ? '<section class="section about-section"><p>${escapeHtml(about)}</p></section>'
        : null,
    'services': () {
      if (services.isEmpty) return null;
      final preview = services.take(4).toList();
      return serviceListBlockHtml(title: specialtiesTitle, services: preview);
    },
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
    navHtml: siteNavHtml(links: navLinks, active: 'index.html', siteName: businessName, logoImage: logoImage),
    lang: lang,
  );

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
      navHtml: siteNavHtml(links: navLinks, active: 'hizmetler.html', siteName: businessName, logoImage: logoImage),
      lang: lang,
    );
  }

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
    navHtml: siteNavHtml(links: navLinks, active: 'randevu.html', siteName: businessName, logoImage: logoImage),
    lang: lang,
  );

  return files;
}
