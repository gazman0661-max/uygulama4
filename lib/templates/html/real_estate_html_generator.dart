import 'shared_html_blocks.dart';
import 'section_registry.dart';

String generateListingListHtml({
  required String agentName,
  required String agentLogo,
  required String tagline,
  String? about,
  required List<Map<String, String?>> listings,
  String? agentPhone,
  String? agentWhatsapp,
  String? agentGoogleReviewLink,
  String? agentCoverImage,
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  String heroLayoutStyle = 'editorial',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
  final siteShapeStyle = pickVariant(agentName, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final cardData = listings.map((l) => {
        ...l,
        'href': 'listing_${l['id']}.html',
      }).toList();
  final subtext = resolveTheme(themeId, customTheme)['subtext']!;

  final headerHtml = (agentCoverImage != null && agentCoverImage.isNotEmpty)
      ? heroBlockHtml(
          name: agentName,
          tagline: tagline,
          coverImage: agentCoverImage,
          logoImage: agentLogo.isNotEmpty ? agentLogo : null,
          layoutStyle: heroLayoutStyle,
          featuredTestimonial: testimonials.isNotEmpty ? testimonials.first : null,
        ) + (showTrustBar
            ? trustBarBlockHtml(
                testimonialCount: testimonials.length,
                hasGoogleReview: agentGoogleReviewLink != null && agentGoogleReviewLink.trim().isNotEmpty,
                lang: lang,
              )
            : '')
      : '''
<section class="section" style="text-align:center;">
  ${agentLogo.isNotEmpty ? '<img src="${escapeHtml(agentLogo)}" style="width:64px;height:64px;border-radius:50%;object-fit:cover;margin-bottom:12px;">' : ''}
  <h1 style="font-size:24px;font-weight:700;">${escapeHtml(agentName)}</h1>
  <p style="color:$subtext;">${escapeHtml(tagline)}</p>
</section>''';

  final _reviewBtnHero = googleReviewButtonHtml(agentGoogleReviewLink, lang: lang);
  final reviewButtonHtml = _reviewBtnHero.isNotEmpty
      ? '<div style="text-align:center;margin-top:8px;">$_reviewBtnHero</div>'
      : '';

  final sectionBuilders = <String, String? Function()>{
    'testimonials': () => testimonials.isNotEmpty
        ? testimonialBlockHtml(testimonials: testimonials, lang: lang)
        : null,
    'faq': () => faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : null,
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kRealEstateDefaultOrder
      : sectionOrder;
  final navAnchorIds = <String, String>{'testimonials': 'yorumlar', 'faq': 'sss'};
  final navLinks = <Map<String, String>>[
    {'href': 'index.html', 'label': siteLabels(lang)['home']!},
  ];
  final extraSections = StringBuffer();
  for (final sectionId in effectiveOrder) {
    final html = sectionBuilders[sectionId]?.call();
    if (html == null) continue;
    final anchorId = navAnchorIds[sectionId];
    if (anchorId == null) {
      extraSections.writeln(html);
      continue;
    }
    extraSections.writeln(html.replaceFirst('<section class="', '<section id="$anchorId" class="'));
    navLinks.add({
      'href': '#$anchorId',
      'label': sectionId == 'faq' ? siteLabels(lang)['faqTitle']! : siteLabels(lang)['testimonialsTitle']!,
    });
  }

  final aboutHtml = (about != null && about.isNotEmpty)
      ? '<section class="section about-section"><p>${escapeHtml(about)}</p></section>'
      : '';

  final body = '''
$headerHtml
$reviewButtonHtml
$aboutHtml
${propertyCardGridHtml(listings: cardData)}
$extraSections''';

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
    pageTitle: agentName,
    bodyHtml: body,
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: (about != null && about.isNotEmpty) ? about : tagline,
    ogImage: agentLogo,
    schemaType: 'RealEstateAgent',
    whatsapp: agentWhatsapp,
    phone: agentPhone,
    lang: lang,
    navHtml: siteNavHtml(links: navLinks, active: 'index.html', siteName: agentName, logoImage: agentLogo),
  );
}
String generateListingDetailHtml({
  required String title,
  required List<Map<String, String?>> gallery,
  required double price,
  required double m2,
  required String roomLabel,
  int? floor,
  double? aidat,
  required String description,
  required String address,
  required double lat,
  required double lng,
  required String agentName,
  required String agentPhone,
  required String agentWhatsapp,
  String? agentGoogleReviewLink,
  String? videoUrl,
  String videoOrientation = 'landscape',
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  bool includeLeadForm = true,
}) {
  final siteShapeStyle = pickVariant(agentName, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final propertyLabels = lang == 'en'
      ? {'price': 'Price', 'm2': 'm²', 'room': 'Rooms', 'floor': 'Floor', 'dues': 'HOA Fee', 'currency': ''}
      : {'price': 'Fiyat', 'm2': 'm²', 'room': 'Oda', 'floor': 'Kat', 'dues': 'Aidat', 'currency': ' TL'};
  final contactTitle = lang == 'en' ? 'Get in Touch' : 'İletişime Geç';

  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: title, images: gallery));
  }

  if (videoUrl != null && videoUrl.trim().isNotEmpty) {
    body.writeln(videoBlockHtml(
      title: labels['videoTitle']!,
      videoUrl: videoUrl,
      orientation: videoOrientation,
      lang: lang,
    ));
  }

  body.writeln(propertyDetailsBlockHtml(
    details: {
      propertyLabels['price']!: '${price.toStringAsFixed(0)}${propertyLabels['currency']}',
      propertyLabels['m2']!: m2.toStringAsFixed(0),
      propertyLabels['room']!: roomLabel,
      if (floor != null) propertyLabels['floor']!: floor.toString(),
      if (aidat != null) propertyLabels['dues']!: '${aidat.toStringAsFixed(0)}${propertyLabels['currency']}',
    },
    description: description,
  ));

  if (address.trim().isNotEmpty) {
    body.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  }

  body.writeln(contactBlockHtml(title: contactTitle, phone: agentPhone, whatsapp: agentWhatsapp, googleReviewLink: agentGoogleReviewLink, lang: lang, siteName: title, includeLeadForm: includeLeadForm));

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
    pageTitle: title,
    bodyHtml: body.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: description,
    ogImage: gallery.isNotEmpty ? gallery.first['url'] : null,
    schemaType: 'Product',
    whatsapp: agentWhatsapp,
    phone: agentPhone,
    lang: lang,
    navHtml: siteNavHtml(
      links: [
        {'href': 'index.html', 'label': lang == 'en' ? 'All Listings' : 'Tüm İlanlar'},
      ],
      active: 'listing.html',
      siteName: agentName,
    ),
  );
}
Map<String, String> generateRealEstateSite({
  required String agentName,
  required String agentLogo,
  required String tagline,
  String? about,
  required String agentPhone,
  required String agentWhatsapp,
  String? agentGoogleReviewLink,
  required List<Map<String, dynamic>> listings,
  String? agentCoverImage,
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  String heroLayoutStyle = 'editorial',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true,
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
  final files = <String, String>{};
  final currencySuffix = lang == 'en' ? '' : ' TL';

  final listCards = listings.map((l) => {
        'id': l['id'].toString(),
        'title': l['title'].toString(),
        'coverImage': l['coverImage'].toString(),
        'price': '${(l['price'] as num).toStringAsFixed(0)}$currencySuffix',
        'm2': (l['m2'] as num).toStringAsFixed(0),
        'roomLabel': l['roomLabel'].toString(),
        'locationTag': l['locationTag']?.toString() ?? '',
      }).toList();

  files['index.html'] = generateListingListHtml(
    agentName: agentName,
    agentLogo: agentLogo,
    tagline: tagline,
    about: about,
    listings: listCards,
    agentPhone: agentPhone,
    agentWhatsapp: agentWhatsapp,
    agentGoogleReviewLink: agentGoogleReviewLink,
    agentCoverImage: agentCoverImage,
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    fontPackageId: fontPackageId,
    density: density,
    galleryStyle: galleryStyle,
    lang: lang,
    heroLayoutStyle: heroLayoutStyle,
    faqs: faqs,
    testimonials: testimonials,
    showTrustBar: showTrustBar,
    sectionOrder: sectionOrder,
  );

  for (final l in listings) {
    files['listing_${l['id']}.html'] = generateListingDetailHtml(
      title: l['title'].toString(),
      gallery: (l['gallery'] as List? ?? [])
          .map((g) => {'url': (g as Map)['url']?.toString(), 'caption': g['caption']?.toString()})
          .toList()
          .cast<Map<String, String?>>(),
      price: (l['price'] as num).toDouble(),
      m2: (l['m2'] as num).toDouble(),
      roomLabel: l['roomLabel'].toString(),
      floor: l['floor'] as int?,
      aidat: (l['aidat'] as num?)?.toDouble(),
      description: l['description'].toString(),
      address: l['address'].toString(),
      lat: (l['lat'] as num).toDouble(),
      lng: (l['lng'] as num).toDouble(),
      agentName: agentName,
      agentPhone: agentPhone,
      agentWhatsapp: agentWhatsapp,
      agentGoogleReviewLink: agentGoogleReviewLink,
      videoUrl: l['videoUrl']?.toString(),
      videoOrientation: l['videoOrientation']?.toString() ?? 'landscape',
      themeId: themeId,
      customTheme: customTheme,
      customFontPackage: customFontPackage,
      fontPackageId: fontPackageId,
      density: density,
      galleryStyle: galleryStyle,
      lang: lang,
      includeLeadForm: includeLeadForm,
    );
  }

  return files;
}
