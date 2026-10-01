import 'shared_html_blocks.dart';
import 'section_registry.dart';
import 'extra_page_blocks.dart';

Map<String, String> generateGenericBusinessSite({
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
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  String schemaType = 'LocalBusiness',
  String heroLayoutStyle = 'centered',
  List<Map<String, String>> extraPages = const [],
  bool includeLeadForm = true,
  bool showTrustBar = true,
  List<String>? sectionOrder,
}) {
  final siteShapeStyle = pickVariant(name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final labels = siteLabels(lang);
  final sector = businessSectorLabels('default', lang);
  final homeLabel = labels['home']!;
  final navPages = <Map<String, String>>[
    {'href': 'index.html', 'label': homeLabel},
    for (final p in extraPages) {'href': '${p['slug']}.html', 'label': p['title'] ?? ''},
  ];

  final body = StringBuffer();
  body.writeln(siteNavHtml(links: navPages, active: 'index.html', siteName: name, logoImage: logoImage));
  body.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    omitWithoutCover: true,
    logoImage: logoImage,
    ctaText: whatsapp != null ? 'WhatsApp' : sector['ctaText']!,
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

  final middleBuilders = <String, String? Function()>{
    'about': () => (about != null && about.isNotEmpty)
        ? '<section class="section about-section"><p>${escapeHtml(about)}</p></section>'
        : null,
    'services': () => services.isNotEmpty
        ? serviceListBlockHtml(title: sector['servicesTitle']!, services: services)
        : null,
    'products': () => products.isNotEmpty
        ? productListBlockHtml(title: labels['products']!, products: products)
        : null,
    'gallery': () => gallery.isNotEmpty
        ? galleryBlockHtml(style: galleryStyle, title: labels['gallery']!, images: gallery)
        : null,
    'video': () => (videoUrl != null && videoUrl.trim().isNotEmpty)
        ? videoBlockHtml(title: videoTitle ?? labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
        : null,
    'hours': () => workingHours.isNotEmpty
        ? workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang)
        : null,
    'map': () => address.trim().isNotEmpty
        ? mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang)
        : null,
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kGenericBusinessDefaultOrder
      : sectionOrder;
  for (final sectionId in effectiveOrder) {
    final html = middleBuilders[sectionId]?.call();
    if (html != null) body.writeln(html);
  }
  body.writeln(contactBlockHtml(
    title: labels['contact']!,
    phone: phone.isNotEmpty ? phone : null,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
    includeLeadForm: includeLeadForm,
  ));

  final files = <String, String>{
    'index.html': wrapPageHtml(
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
    ),
  };

  for (final page in extraPages) {
    final slug = page['slug']!;
    final title = page['title'] ?? '';
    final content = page['content'] ?? '';
    final pageBody = StringBuffer();
    pageBody.writeln(siteNavHtml(links: navPages, active: '$slug.html', siteName: name, logoImage: logoImage));
    final blocks = decodeExtraPageBlocks(page['blocks']);
    pageBody.writeln('<section class="section">');
    pageBody.writeln('<h1 class="section-title">${escapeHtml(title)}</h1>');
    if (blocks.isEmpty) {
      pageBody.writeln(_paragraphsHtml(content));
      pageBody.writeln('</section>');
    } else {
      pageBody.writeln('</section>');
      pageBody.writeln(extraPageBlocksHtml(
        blocks,
        lang: lang,
        phone: phone.isNotEmpty ? phone : null,
        whatsapp: whatsapp,
        googleReviewLink: googleReviewLink,
      ));
    }
    final seoDesc = (page['seoDesc'] ?? '').trim();
    final metaText = seoDesc.isNotEmpty
        ? seoDesc
        : (blocks.isNotEmpty ? extraPageBlocksMetaText(blocks) : content);
    pageBody.writeln(contactBlockHtml(
      title: labels['contact']!,
      phone: phone.isNotEmpty ? phone : null,
      whatsapp: whatsapp,
      instagram: instagram,
      googleReviewLink: googleReviewLink,
      lang: lang,
      includeLeadForm: includeLeadForm,
    ));

    files['$slug.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      shapeStyle: siteShapeStyle,
      pageTitle: '$title — $name',
      bodyHtml: pageBody.toString(),
      themeId: themeId,
      customTheme: customTheme,
      customFontPackage: customFontPackage,
      metaDescription: metaText.length > 160 ? metaText.substring(0, 157) : metaText,
      ogImage: coverImage,
      schemaType: schemaType,
      whatsapp: whatsapp,
      phone: phone.isNotEmpty ? phone : null,
      lang: lang,
    );
  }

  return files;
}

String _paragraphsHtml(String content) {
  final paragraphs = content
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  if (paragraphs.isEmpty) return '';
  return paragraphs
      .map((p) => '<p>${escapeHtml(p).replaceAll('\n', '<br>')}</p>')
      .join('\n');
}

String slugifyPageTitle(String title, Set<String> existingSlugs) {
  const trMap = {
    'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i',
    'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u',
  };
  var s = title;
  trMap.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.isEmpty) s = 'sayfa';
  if (s == 'index') s = 'sayfa';
  var candidate = s;
  var i = 2;
  while (existingSlugs.contains(candidate)) {
    candidate = '$s-$i';
    i++;
  }
  return candidate;
}
