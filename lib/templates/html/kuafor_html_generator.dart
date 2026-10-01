import 'shared_html_blocks.dart';
import 'section_registry.dart';

String generateBusinessSiteHtml({
  required String name,
  required String coverImage,
  String? logoImage,
  required String tagline,
  String? about,
  required List<Map<String, String?>> services,
  List<Map<String, String?>> products = const [],
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
  String? servicesTitle,
  String? productsTitle,
  String? galleryTitle,
  String? hoursTitle,
  String? mapTitle,
  String? contactTitle,
  String? ctaText,
  String sectorKey = 'default',
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  bool galleryBeforeAfter = false,
  String heroLayoutStyle = 'centered',
  String schemaType = 'LocalBusiness',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true,
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
  final siteShapeStyle = pickVariant(name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final sector = businessSectorLabels(sectorKey, lang);
  final resolvedServicesTitle = servicesTitle ?? sector['servicesTitle']!;
  final resolvedProductsTitle = productsTitle ?? labels['products']!;
  final resolvedCtaText = ctaText ?? sector['ctaText']!;
  final resolvedGalleryTitle = galleryTitle ?? labels['gallery']!;
  final resolvedHoursTitle = hoursTitle ?? labels['hours']!;
  final resolvedMapTitle = mapTitle ?? labels['location']!;
  final resolvedContactTitle = contactTitle ?? labels['contact']!;

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
      serviceCount: services.length,
      galleryCount: gallery.length,
      testimonialCount: testimonials.length,
      hasGoogleReview: googleReviewLink != null && googleReviewLink.trim().isNotEmpty,
      lang: lang,
    ));
  }

  final navAnchorIds = <String, String>{
    'services': 'hizmetler',
    'products': 'urunler',
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
        ? serviceListBlockHtml(title: resolvedServicesTitle, services: services)
        : null,
    'products': () => products.isNotEmpty
        ? productListBlockHtml(title: resolvedProductsTitle, products: products)
        : null,
    'gallery': () => gallery.isNotEmpty
        ? galleryBlockHtml(style: galleryStyle, title: resolvedGalleryTitle, images: gallery, beforeAfter: galleryBeforeAfter)
        : null,
    'video': () => (videoUrl != null && videoUrl.trim().isNotEmpty)
        ? videoBlockHtml(title: videoTitle ?? labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
        : null,
    'hours': () => workingHours.isNotEmpty
        ? workingHoursBlockHtml(title: resolvedHoursTitle, hours: workingHours, lang: lang)
        : null,
    'testimonials': () => testimonials.isNotEmpty
        ? testimonialBlockHtml(testimonials: testimonials, lang: lang)
        : null,
    'faq': () => faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : null,
    'map': () => address.trim().isNotEmpty
        ? mapBlockHtml(title: resolvedMapTitle, address: address, lat: lat, lng: lng, lang: lang)
        : null,
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kBusinessSiteDefaultOrder
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
      'services' => resolvedServicesTitle,
      'products' => resolvedProductsTitle,
      'gallery' => resolvedGalleryTitle,
      'faq' => labels['faqTitle']!,
      _ => sectionId,
    };
    navLinks.add({'href': '#$anchorId', 'label': navLabel});
  }
  final contactAnchorId = 'iletisim-${name.hashCode.abs()}';
  navLinks.add({'href': '#$contactAnchorId', 'label': resolvedContactTitle});

  body.writeln(contactBlockHtml(
    title: resolvedContactTitle,
    phone: phone.isNotEmpty ? phone : null,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
    siteName: name,
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
    phone: phone.isNotEmpty ? phone : null,
    lang: lang,
    navHtml: siteNavHtml(links: navLinks, active: '#', siteName: name, logoImage: logoImage),
  );
}
