import 'shared_html_blocks.dart';
import 'section_registry.dart';

String generatePortfolioHtml({
  required String name,
  required String title,
  required String photo,
  String? logoImage,
  required String tagline,
  required String aboutText,
  List<String> skills = const [],
  List<Map<String, String?>> works = const [],
  List<Map<String, String?>> timeline = const [],
  required String contactEmail,
  String? contactGoogleReviewLink,
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
  final body = StringBuffer();
  final worksTitle = lang == 'en' ? 'Portfolio' : 'İş Örnekleri';
  final timelineTitle = lang == 'en' ? 'Experience & Education' : 'Deneyim & Eğitim';
  final contactTitle = siteLabels(lang)['contact']!;

  body.writeln(heroBlockHtml(
    name: name,
    tagline: '$title — $tagline',
    coverImage: photo,
    omitWithoutCover: true,
    logoImage: logoImage,
    layoutStyle: heroLayoutStyle,
    featuredTestimonial: testimonials.isNotEmpty ? testimonials.first : null,
  ));

  if (showTrustBar) {
    body.writeln(trustBarBlockHtml(
      galleryCount: works.length,
      testimonialCount: testimonials.length,
      hasGoogleReview: contactGoogleReviewLink != null && contactGoogleReviewLink.trim().isNotEmpty,
      lang: lang,
    ));
  }

  body.writeln('<section class="section about-section">'
      '<p>${escapeHtml(aboutText)}</p>'
      '${skills.isNotEmpty ? '<div style="margin-top:16px;">${skillChipsBlockHtml(skills)}</div>' : ''}'
      '</section>');

  final navAnchorIds = <String, String>{
    'works': 'works',
    'faq': 'sss',
  };
  final navLinks = <Map<String, String>>[
    {'href': '#', 'label': lang == 'en' ? 'Home' : 'Ana Sayfa'},
  ];

  final middleBuilders = <String, String? Function()>{
    'works': () => works.isNotEmpty
        ? galleryBlockHtml(style: galleryStyle, title: worksTitle, images: works)
        : null,
    'timeline': () => timeline.isNotEmpty
        ? timelineBlockHtml(title: timelineTitle, entries: timeline)
        : null,
    'testimonials': () => testimonials.isNotEmpty
        ? testimonialBlockHtml(testimonials: testimonials, lang: lang)
        : null,
    'faq': () => faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : null,
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kPortfolioDefaultOrder
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
      'works' => worksTitle,
      'faq' => siteLabels(lang)['faqTitle']!,
      _ => sectionId,
    };
    navLinks.add({'href': '#$anchorId', 'label': navLabel});
  }
  final contactAnchorId = 'iletisim-${name.hashCode.abs()}';
  navLinks.add({'href': '#$contactAnchorId', 'label': contactTitle});

  body.writeln(contactBlockHtml(title: contactTitle, lang: lang, siteName: name, includeLeadForm: includeLeadForm)
      .replaceFirst('<section class="', '<section id="$contactAnchorId" class="'));
  final _reviewBtn1 = googleReviewButtonHtml(contactGoogleReviewLink, lang: lang);
  if (_reviewBtn1.isNotEmpty) {
    body.writeln('<div style="text-align:center;margin-top:8px;">$_reviewBtn1</div>');
  }

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
    pageTitle: name,
    bodyHtml: body.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: '$title — $tagline',
    ogImage: photo,
    schemaType: 'Person',
    lang: lang,
    navHtml: siteNavHtml(links: navLinks, active: '#', siteName: name, logoImage: logoImage),
  );
}

Map<String, String> generatePortfolioSite({
  required String name,
  required String title,
  required String photo,
  String? logoImage,
  required String tagline,
  required String aboutText,
  List<String> skills = const [],
  List<Map<String, String?>> works = const [],
  List<Map<String, String?>> timeline = const [],
  required String contactEmail,
  String? contactGoogleReviewLink,
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
  final labels = siteLabels(lang);
  final worksTitle = lang == 'en' ? 'Portfolio' : 'İş Örnekleri';
  final timelineTitle = lang == 'en' ? 'Experience & Education' : 'Deneyim & Eğitim';
  final backToPortfolioText = lang == 'en' ? '← Back to Portfolio' : '← Portfolyoya Dön';
  final contactTitle = labels['contact']!;

  final worksWithId = <Map<String, String?>>[];
  for (var i = 0; i < works.length; i++) {
    final w = works[i];
    worksWithId.add({...w, '_id': (w['id'] ?? 'work_$i')});
  }

  final navLinks = [
    {'label': labels['home']!, 'href': 'index.html'},
  ];

  final homeBody = StringBuffer();
  homeBody.writeln(heroBlockHtml(name: name, tagline: '$title — $tagline', coverImage: photo, omitWithoutCover: true, logoImage: logoImage, layoutStyle: heroLayoutStyle, featuredTestimonial: testimonials.isNotEmpty ? testimonials.first : null));
  if (showTrustBar) {
    homeBody.writeln(trustBarBlockHtml(
      galleryCount: works.length,
      testimonialCount: testimonials.length,
      hasGoogleReview: contactGoogleReviewLink != null && contactGoogleReviewLink.trim().isNotEmpty,
      lang: lang,
    ));
  }
  homeBody.writeln('<section class="section about-section">'
      '<p>${escapeHtml(aboutText)}</p>'
      '${skills.isNotEmpty ? '<div style="margin-top:16px;">${skillChipsBlockHtml(skills)}</div>' : ''}'
      '</section>');

  final homeMiddleBuilders = <String, String? Function()>{
    'works': () {
      if (worksWithId.isEmpty) return null;
      final cardItems = worksWithId
          .map((w) => {
                'title': w['caption'] ?? '',
                'coverImage': w['url'],
                'href': '${w['_id']}.html',
              })
          .toList();
      return '<section class="section"><h2 class="section-title">${escapeHtml(worksTitle)}</h2></section>'
          '${simpleCardGridHtml(items: cardItems)}';
    },
    'timeline': () => timeline.isNotEmpty ? timelineBlockHtml(title: timelineTitle, entries: timeline) : null,
    'testimonials': () => testimonials.isNotEmpty
        ? testimonialBlockHtml(testimonials: testimonials, lang: lang)
        : null,
    'faq': () => faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : null,
  };
  final homeEffectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kPortfolioDefaultOrder
      : sectionOrder;
  for (final sectionId in homeEffectiveOrder) {
    final html = homeMiddleBuilders[sectionId]?.call();
    if (html != null) homeBody.writeln(html);
  }

  homeBody.writeln(contactBlockHtml(title: contactTitle, lang: lang, siteName: name, includeLeadForm: includeLeadForm));
  final _reviewBtn2 = googleReviewButtonHtml(contactGoogleReviewLink, lang: lang);
  if (_reviewBtn2.isNotEmpty) {
    homeBody.writeln('<div style="text-align:center;margin-top:8px;">$_reviewBtn2</div>');
  }

  files['index.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
    pageTitle: name,
    bodyHtml: homeBody.toString(),
    themeId: themeId,
    customTheme: customTheme,
    customFontPackage: customFontPackage,
    metaDescription: '$title — $tagline',
    ogImage: photo,
    schemaType: 'Person',
    navHtml: siteNavHtml(links: navLinks, active: 'index.html', siteName: name, logoImage: logoImage),
    lang: lang,
  );

  for (final w in worksWithId) {
    final workTitle = (w['caption'] != null && w['caption']!.isNotEmpty) ? w['caption']! : name;
    final workBody = StringBuffer();
    workBody.writeln('''
<section class="section" style="text-align:center; padding-bottom:0;">
  <a href="index.html" style="text-decoration:none; font-weight:600; font-size:14px;">$backToPortfolioText</a>
</section>''');
    workBody.writeln(galleryBlockHtml(
    style: galleryStyle,title: workTitle, images: [w]));
    workBody.writeln(contactBlockHtml(title: contactTitle, lang: lang, siteName: name, includeLeadForm: includeLeadForm));
    final _reviewBtn3 = googleReviewButtonHtml(contactGoogleReviewLink, lang: lang);
    if (_reviewBtn3.isNotEmpty) {
      workBody.writeln('<div style="text-align:center;margin-top:8px;">$_reviewBtn3</div>');
    }

    files['${w['_id']}.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      shapeStyle: siteShapeStyle,
      pageTitle: '$workTitle — $name',
      bodyHtml: workBody.toString(),
      themeId: themeId,
      customTheme: customTheme,
      customFontPackage: customFontPackage,
      metaDescription: workTitle,
      ogImage: w['url'],
      schemaType: 'CreativeWork',
      navHtml: siteNavHtml(links: navLinks, active: 'index.html', siteName: name, logoImage: logoImage),
      lang: lang,
    );
  }

  return files;
}
