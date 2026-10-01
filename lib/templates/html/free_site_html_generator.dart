import 'shared_html_blocks.dart';
import 'extra_page_blocks.dart';

Map<String, String> generateFreeSite({
  required String name,
  String? logoImage,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink,
  required List<Map<String, dynamic>> homeBlocks,
  List<Map<String, String>> extraPages = const [],
  bool multiPage = false,
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  Map<String, String>? customFontPackage,
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String heroLayoutStyle = 'centered',
  String lang = 'tr',
  bool includeLeadForm = true,
  bool editorMarkers = false,
}) {
  final siteShapeStyle = pickVariant(name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final labels = siteLabels(lang);
  final pages = multiPage ? extraPages : const <Map<String, String>>[];
  final navPages = <Map<String, String>>[
    {'href': 'index.html', 'label': labels['home']!},
    for (final p in pages) {'href': '${p['slug']}.html', 'label': p['title'] ?? ''},
  ];
  final showNav = multiPage && pages.isNotEmpty;
  final themeColors = resolveTheme(themeId, customTheme);
  bool hasContactBlock(List<Map<String, dynamic>> bs) => bs.any((b) => b['type'] == 'contact');

  String contact() => contactBlockHtml(
        title: labels['contact']!,
        phone: phone.isNotEmpty ? phone : null,
        whatsapp: whatsapp,
        instagram: instagram,
        googleReviewLink: googleReviewLink,
        lang: lang,
        includeLeadForm: includeLeadForm,
      );

  final home = StringBuffer();
  if (showNav) {
    home.writeln(siteNavHtml(links: navPages, active: 'index.html', siteName: name, logoImage: logoImage));
  }
  home.writeln(extraPageBlocksHtml(
    homeBlocks,
    lang: lang,
    phone: phone.isNotEmpty ? phone : null,
    whatsapp: whatsapp,
    googleReviewLink: googleReviewLink,
    siteName: name,
    logoImage: logoImage,
    heroLayoutStyle: heroLayoutStyle,
    instagram: instagram,
    includeLeadForm: includeLeadForm,
    theme: themeColors,
    editorMarkers: editorMarkers,
  ));
  if (!hasContactBlock(homeBlocks)) home.writeln(contact());

  String? ogImage;
  for (final b in homeBlocks) {
    if (b['type'] != 'hero') continue;
    final imgs = b['images'];
    if (imgs is List && imgs.isNotEmpty && imgs.first is Map) {
      final url = ((imgs.first as Map)['url'] ?? '').toString();
      if (url.startsWith('https://')) ogImage = url;
    }
    break;
  }
  final homeMeta = extraPageBlocksMetaText(homeBlocks);

  final files = <String, String>{
    'index.html': wrapPageHtml(
      fontPackageId: fontPackageId,
      density: density,
      shapeStyle: siteShapeStyle,
      pageTitle: name,
      bodyHtml: home.toString(),
      themeId: themeId,
      customTheme: customTheme,
      customFontPackage: customFontPackage,
      metaDescription: homeMeta.isEmpty ? name : homeMeta,
      ogImage: ogImage,
      whatsapp: whatsapp,
      phone: phone.isNotEmpty ? phone : null,
      lang: lang,
    ),
  };

  for (final page in pages) {
    final slug = page['slug']!;
    final title = page['title'] ?? '';
    final blocks = decodeExtraPageBlocks(page['blocks'], allowed: kFreeSiteBlockTypes);
    final body = StringBuffer();
    body.writeln(siteNavHtml(links: navPages, active: '$slug.html', siteName: name, logoImage: logoImage));
    body.writeln('<section class="section">');
    body.writeln('<h1 class="section-title">${escapeHtml(title)}</h1>');
    body.writeln('</section>');
    body.writeln(extraPageBlocksHtml(
      blocks,
      lang: lang,
      phone: phone.isNotEmpty ? phone : null,
      whatsapp: whatsapp,
      googleReviewLink: googleReviewLink,
      siteName: name,
      logoImage: logoImage,
      heroLayoutStyle: heroLayoutStyle,
      instagram: instagram,
      includeLeadForm: includeLeadForm,
      theme: themeColors,
      editorMarkers: editorMarkers,
    ));
    if (!hasContactBlock(blocks)) body.writeln(contact());
    final seoDesc = (page['seoDesc'] ?? '').trim();
    final metaText = seoDesc.isNotEmpty ? seoDesc : extraPageBlocksMetaText(blocks);
    files['$slug.html'] = wrapPageHtml(
      fontPackageId: fontPackageId,
      density: density,
      shapeStyle: siteShapeStyle,
      pageTitle: '$title — $name',
      bodyHtml: body.toString(),
      themeId: themeId,
      customTheme: customTheme,
      customFontPackage: customFontPackage,
      metaDescription: metaText.length > 160
          ? metaText.substring(0, 157)
          : (metaText.isEmpty ? '$title — $name' : metaText),
      ogImage: ogImage,
      whatsapp: whatsapp,
      phone: phone.isNotEmpty ? phone : null,
      lang: lang,
    );
  }
  return files;
}
