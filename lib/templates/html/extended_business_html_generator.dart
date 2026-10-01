import 'shared_html_blocks.dart';
import 'section_registry.dart';

String generateExtendedBusinessSiteHtml({
  required String businessName,
  required String coverImageUrl,
  required String slogan,
  String? logoUrl,
  String? about,
  List<Map<String, String?>> services = const [],
  List<Map<String, dynamic>> packages = const [],
  List<Map<String, String?>> gallery = const [],
  List<Map<String, String?>> beforeAfterGallery = const [],
  List<Map<String, dynamic>> team = const [],
  List<Map<String, String?>> schedule = const [],
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? googleReviewLink,
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  String? email,
  String? instagram,
  String? servicesTitle,
  String? packagesTitle,
  String? galleryTitle,
  String? teamTitle,
  String? scheduleTitle,
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String schemaType = 'LocalBusiness',
  String lang = 'tr',
  String heroLayoutStyle = 'centered',
  bool includeLeadForm = true,
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
  final siteShapeStyle = pickVariant(businessName, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final resolvedServicesTitle = servicesTitle ?? (lang == 'en' ? 'Our Services' : 'Hizmetlerimiz');
  final resolvedPackagesTitle = packagesTitle ?? (lang == 'en' ? 'Our Packages' : 'Paketlerimiz');
  final resolvedGalleryTitle = galleryTitle ?? labels['gallery']!;
  final resolvedTeamTitle = teamTitle ?? (lang == 'en' ? 'Our Team' : 'Ekibimiz');
  final resolvedScheduleTitle = scheduleTitle ?? (lang == 'en' ? 'Schedule' : 'Program');
  final beforeAfterTitle = lang == 'en' ? 'Before / After' : 'Öncesi / Sonrası';

  body.writeln(heroBlockHtml(
    name: businessName,
    tagline: slogan,
    coverImage: coverImageUrl,
    omitWithoutCover: true,
    logoImage: logoUrl,
    ctaText: labels['reservation']!,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : (phone.isNotEmpty ? 'tel:$phone' : null),
    layoutStyle: heroLayoutStyle,
    workingHours: heroHoursFor(workingHours, sectionOrder),
    lang: lang,
  ));
  if (showTrustBar) {
    body.writeln(trustBarBlockHtml(
      serviceCount: services.length,
      galleryCount: gallery.length,
      hasGoogleReview: googleReviewLink != null && googleReviewLink.trim().isNotEmpty,
      lang: lang,
    ));
  }

  final navAnchorIds = <String, String>{
    'services': 'hizmetler',
    'packages': 'paketler',
    'gallery': 'galeri',
    'team': 'ekip',
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
    'packages': () => packages.isNotEmpty
        ? packageCardsBlockHtml(title: resolvedPackagesTitle, packages: packages)
        : null,
    'schedule': () => schedule.isNotEmpty
        ? scheduleTableBlockHtml(title: resolvedScheduleTitle, entries: schedule)
        : null,
    'gallery': () {
      if (beforeAfterGallery.isNotEmpty) {
        return galleryBlockHtml(style: galleryStyle, title: beforeAfterTitle, images: beforeAfterGallery, beforeAfter: true);
      }
      if (gallery.isNotEmpty) {
        return galleryBlockHtml(style: galleryStyle, title: resolvedGalleryTitle, images: gallery);
      }
      return null;
    },
    'team': () => team.isNotEmpty ? teamBlockHtml(title: resolvedTeamTitle, members: team) : null,
    'video': () => (videoUrl != null && videoUrl.trim().isNotEmpty)
        ? videoBlockHtml(title: videoTitle ?? labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
        : null,
    'hours': () => workingHours.isNotEmpty
        ? workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang)
        : null,
    'map': () {
      if (address.trim().isEmpty) return null;
      if (lat != null && lng != null) {
        return mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang);
      }
      return '<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>';
    },
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kExtendedBusinessDefaultOrder
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
      'packages' => resolvedPackagesTitle,
      'gallery' => beforeAfterGallery.isNotEmpty ? beforeAfterTitle : resolvedGalleryTitle,
      'team' => resolvedTeamTitle,
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
    metaDescription: (about != null && about.isNotEmpty) ? about : slogan,
    ogImage: coverImageUrl,
    schemaType: schemaType,
    whatsapp: whatsapp,
    phone: phone,
    lang: lang,
    navHtml: siteNavHtml(links: navLinks, active: '#', siteName: businessName, logoImage: logoUrl),
  );
}
