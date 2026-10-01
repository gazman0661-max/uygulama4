import 'shared_html_blocks.dart';
import 'section_registry.dart';

String generateCafeHtml({
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
  String schemaType = 'CafeOrCoffeeShop',
  String? ctaText,
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true,
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
  final siteShapeStyle = pickVariant(name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final body = StringBuffer();
  final accentColor = resolveTheme(themeId, customTheme)['accent']!;
  final labels = siteLabels(lang);
  final resolvedCtaText = ctaText ?? labels['reservation']!;

  body.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    omitWithoutCover: true,
    logoImage: logoImage,
    ctaText: resolvedCtaText,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : (phone.isNotEmpty ? 'tel:$phone' : null),
    layoutStyle: heroLayoutStyle,
    featuredTestimonial: testimonials.isNotEmpty ? testimonials.first : null,
    workingHours: heroHoursFor(workingHours, sectionOrder),
    lang: lang,
  ));

  if (showTrustBar) {
    body.writeln(trustBarBlockHtml(
      galleryCount: gallery.length,
      testimonialCount: testimonials.length,
      hasGoogleReview: googleReviewLink != null && googleReviewLink.trim().isNotEmpty,
      lang: lang,
    ));
  }

  final navAnchorIds = <String, String>{
    'menu': 'menu',
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
    'menu': () {
      final buf = StringBuffer();
      if (menuCategories.isNotEmpty) {
        buf.writeln(menuBlockHtml(title: labels['menu']!, categories: menuCategories, lang: lang));
      }
      if (menuUrl != null) {
        buf.writeln('''
<section class="section qr-menu-section" style="text-align:center;">
  <a class="hero-cta" style="background:$accentColor;" href="${escapeHtml(menuUrl)}" target="_blank">${labels['openDigitalMenu']}</a>
</section>''');
      }
      return buf.isEmpty ? null : buf.toString();
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
    'testimonials': () => testimonials.isNotEmpty
        ? testimonialBlockHtml(testimonials: testimonials, lang: lang)
        : null,
    'faq': () => faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : null,
    'map': () => address.trim().isNotEmpty
        ? mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang)
        : null,
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kCafeDefaultOrder
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
      'menu' => labels['menu']!,
      'gallery' => labels['gallery']!,
      'faq' => labels['faqTitle']!,
      _ => sectionId,
    };
    navLinks.add({'href': '#$anchorId', 'label': navLabel});
  }
  final contactAnchorId = 'iletisim-${name.hashCode.abs()}';
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
    pageTitle: name,
    bodyHtml: body.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: (about != null && about.isNotEmpty) ? about : tagline,
    ogImage: coverImage,
    schemaType: schemaType,
    whatsapp: whatsapp,
    phone: phone,
    lang: lang,
    navHtml: siteNavHtml(links: navLinks, active: '#', siteName: name, logoImage: logoImage),
  );
}

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
  final siteShapeStyle = pickVariant(name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final files = <String, String>{};
  final accentColor = resolveTheme(themeId, customTheme)['accent']!;
  final labels = siteLabels(lang);

  final navLinks = [
    {'label': labels['home']!, 'href': 'index.html'},
    {'label': labels['menu']!, 'href': 'menu.html'},
    if (gallery.isNotEmpty) {'label': labels['gallery']!, 'href': 'gallery.html'},
  ];

  final homeBody = StringBuffer();
  homeBody.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    omitWithoutCover: true,
    logoImage: logoImage,
    ctaText: labels['goToMenu']!,
    ctaHref: 'menu.html',
    layoutStyle: heroLayoutStyle,
    featuredTestimonial: testimonials.isNotEmpty ? testimonials.first : null,
    workingHours: heroHoursFor(workingHours, sectionOrder),
    lang: lang,
  ));
  if (showTrustBar) {
    homeBody.writeln(trustBarBlockHtml(
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
    'menu': () {
      final buf = StringBuffer();
      if (menuCategories.isNotEmpty) {
        buf.writeln(menuBlockHtml(title: labels['menuHighlights']!, categories: [menuCategories.first], lang: lang));
        buf.writeln('''
<section class="section" style="text-align:center; padding-top:0;">
  <a class="hero-cta" style="background:$accentColor;" href="menu.html">${labels['viewFullMenu']}</a>
</section>''');
      }
      if (menuUrl != null) {
        buf.writeln('''
<section class="section qr-menu-section" style="text-align:center;">
  <a class="hero-cta" style="background:$accentColor;" href="${escapeHtml(menuUrl)}" target="_blank">${labels['openDigitalMenu']}</a>
</section>''');
      }
      return buf.isEmpty ? null : buf.toString();
    },
    'hours': () => workingHours.isNotEmpty
        ? workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang)
        : null,
    'video': () => (videoUrl != null && videoUrl.trim().isNotEmpty)
        ? videoBlockHtml(title: videoTitle ?? labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
        : null,
    'testimonials': () => testimonials.isNotEmpty
        ? testimonialBlockHtml(testimonials: testimonials, lang: lang)
        : null,
    'faq': () => faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : null,
    'map': () => address.trim().isNotEmpty
        ? mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang)
        : null,
  };
  final homeEffectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kCafeMultiPageHomeDefaultOrder
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
    pageTitle: name,
    bodyHtml: homeBody.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: (about != null && about.isNotEmpty) ? about : tagline,
    ogImage: coverImage,
    schemaType: 'CafeOrCoffeeShop',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'index.html', siteName: name, logoImage: logoImage),
    lang: lang,
  );

  final menuBody = StringBuffer();
  menuBody.writeln('<section class="section" style="text-align:center; padding-bottom:0;"><h1 class="section-title" style="margin-bottom:0;">${escapeHtml(name)} — ${labels['menu']}</h1></section>');
  if (menuCategories.isNotEmpty) {
    menuBody.writeln(menuBlockHtml(title: '', categories: menuCategories, lang: lang));
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
    shapeStyle: siteShapeStyle,
    pageTitle: '$name — ${labels['menu']}',
    bodyHtml: menuBody.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: '${labels['menu']} — $name',
    ogImage: coverImage,
    schemaType: 'CafeOrCoffeeShop',
    whatsapp: whatsapp,
    phone: phone,
    navHtml: siteNavHtml(links: navLinks, active: 'menu.html', siteName: name, logoImage: logoImage),
    lang: lang,
  );

  if (gallery.isNotEmpty) {
    final galleryBody = StringBuffer();
    galleryBody.writeln(galleryBlockHtml(
    style: galleryStyle,title: labels['gallery']!, images: gallery));
    galleryBody.writeln(contactBlockHtml(title: labels['contact']!, phone: phone, whatsapp: whatsapp, instagram: instagram, googleReviewLink: googleReviewLink, lang: lang, includeLeadForm: includeLeadForm));

    files['gallery.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      shapeStyle: siteShapeStyle,
      pageTitle: '$name — ${labels['gallery']}',
      bodyHtml: galleryBody.toString(),
      themeId: themeId,
      customTheme: customTheme,
      customFontPackage: customFontPackage,
      metaDescription: '${labels['gallery']} — $name',
      ogImage: coverImage,
      schemaType: 'CafeOrCoffeeShop',
      whatsapp: whatsapp,
      phone: phone,
      navHtml: siteNavHtml(links: navLinks, active: 'gallery.html', siteName: name, logoImage: logoImage),
      lang: lang,
    );
  }

  return files;
}
