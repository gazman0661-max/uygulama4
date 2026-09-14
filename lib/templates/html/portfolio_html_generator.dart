import 'shared_html_blocks.dart';

/// portfolio_template'in HTML karşılığı. makeup_artist/musician_dj/
/// personal_trainer/photographer bu fonksiyonu AYNEN kullanıyor.
String generatePortfolioHtml({
  required String name,
  required String title, // meslek/unvan
  required String photo,
  required String tagline,
  required String aboutText,
  List<String> skills = const [],
  List<Map<String, String?>> works = const [], // {url, caption}
  List<Map<String, String?>> timeline = const [], // {year, title, description}
  required String contactEmail, // 05.09.2026 — artık kullanılmıyor (mailto kaldırıldı, iletişim Talep Kutusu üzerinden), geriye dönük uyumluluk için parametre korundu.
  String? contactGoogleReviewLink, // 01.09.2026 eklendi
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  // 07.09.2026 eklendi (kanka isteği) — hero düzeni seçimi.
  String heroLayoutStyle = 'centered',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true, // 05.09.2026 eklendi
}) {
  // 11.09.2026 eklendi — bkz. shared_html_blocks.dart > shapeStyleOf.
  final siteShapeStyle = pickVariant(name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final body = StringBuffer();
  final worksTitle = lang == 'en' ? 'Portfolio' : 'İş Örnekleri';
  final timelineTitle = lang == 'en' ? 'Experience & Education' : 'Deneyim & Eğitim';
  final contactTitle = siteLabels(lang)['contact']!;

  body.writeln(heroBlockHtml(
    name: name,
    tagline: '$title — $tagline',
    coverImage: photo,
    layoutStyle: heroLayoutStyle,
  ));

  body.writeln('<section class="section about-section">'
      '<p>${escapeHtml(aboutText)}</p>'
      '${skills.isNotEmpty ? '<div style="margin-top:16px;">${skillChipsBlockHtml(skills)}</div>' : ''}'
      '</section>');

  if (works.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: worksTitle, images: works));
  }

  if (timeline.isNotEmpty) {
    body.writeln(timelineBlockHtml(title: timelineTitle, entries: timeline));
  }

  if (testimonials.isNotEmpty) {
    body.writeln(testimonialBlockHtml(testimonials: testimonials, lang: lang));
  }

  if (faqs.isNotEmpty) {
    body.writeln(faqBlockHtml(faqs: faqs, lang: lang));
  }

  body.writeln(contactBlockHtml(title: contactTitle, lang: lang, siteName: name, includeLeadForm: includeLeadForm));
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
    metaDescription: '$title — $tagline',
    ogImage: photo,
    schemaType: 'Person',
    lang: lang,
  );
}

/// --- ÇOK SAYFALI MOD (B) ---
/// generatePortfolioHtml (yukarısı) tek sayfalık modda AYNEN duruyor.
/// Bu fonksiyon, real_estate_html_generator.dart'taki liste+detay kalıbını
/// portfolyoya uyarlar: index.html (ana sayfa: hero+hakkında+beceriler+
/// öne çıkan iş örnekleri+deneyim+iletişim) + her iş örneği için ayrı bir
/// work_<n>.html (büyük görsel+açıklama+iletişim CTA). `works` listesindeki
/// her öğe kendi sayfasına gider — id verilmemişse sırasına göre (work_0,
/// work_1, ...) otomatik numaralanır.
Map<String, String> generatePortfolioSite({
  required String name,
  required String title,
  required String photo,
  required String tagline,
  required String aboutText,
  List<String> skills = const [],
  List<Map<String, String?>> works = const [],
  List<Map<String, String?>> timeline = const [],
  required String contactEmail, // 05.09.2026 — artık kullanılmıyor (mailto kaldırıldı, iletişim Talep Kutusu üzerinden), geriye dönük uyumluluk için parametre korundu.
  String? contactGoogleReviewLink, // 01.09.2026 eklendi
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  // 07.09.2026 eklendi (kanka isteği) — hero düzeni seçimi.
  String heroLayoutStyle = 'centered',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true, // 05.09.2026 eklendi
}) {
  // 11.09.2026 eklendi — bkz. shared_html_blocks.dart > shapeStyleOf.
  final siteShapeStyle = pickVariant(name, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
  final files = <String, String>{};
  final labels = siteLabels(lang);
  final worksTitle = lang == 'en' ? 'Portfolio' : 'İş Örnekleri';
  final timelineTitle = lang == 'en' ? 'Experience & Education' : 'Deneyim & Eğitim';
  final backToPortfolioText = lang == 'en' ? '← Back to Portfolio' : '← Portfolyoya Dön';
  final contactTitle = labels['contact']!;

  // Her işe stabil bir id ver (yoksa index'e göre).
  final worksWithId = <Map<String, String?>>[];
  for (var i = 0; i < works.length; i++) {
    final w = works[i];
    worksWithId.add({...w, '_id': (w['id'] ?? 'work_$i')});
  }

  final navLinks = [
    {'label': labels['home']!, 'href': 'index.html'},
  ];

  // --- index.html ---
  final homeBody = StringBuffer();
  homeBody.writeln(heroBlockHtml(name: name, tagline: '$title — $tagline', coverImage: photo, layoutStyle: heroLayoutStyle));
  homeBody.writeln('<section class="section about-section">'
      '<p>${escapeHtml(aboutText)}</p>'
      '${skills.isNotEmpty ? '<div style="margin-top:16px;">${skillChipsBlockHtml(skills)}</div>' : ''}'
      '</section>');

  if (worksWithId.isNotEmpty) {
    final cardItems = worksWithId
        .map((w) => {
              'title': w['caption'] ?? '',
              'coverImage': w['url'],
              'href': '${w['_id']}.html',
            })
        .toList();
    homeBody.writeln('<section class="section"><h2 class="section-title">${escapeHtml(worksTitle)}</h2></section>');
    homeBody.writeln(simpleCardGridHtml(items: cardItems));
  }

  if (timeline.isNotEmpty) {
    homeBody.writeln(timelineBlockHtml(title: timelineTitle, entries: timeline));
  }

  if (testimonials.isNotEmpty) {
    homeBody.writeln(testimonialBlockHtml(testimonials: testimonials, lang: lang));
  }

  if (faqs.isNotEmpty) {
    homeBody.writeln(faqBlockHtml(faqs: faqs, lang: lang));
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
    metaDescription: '$title — $tagline',
    ogImage: photo,
    schemaType: 'Person',
    navHtml: siteNavHtml(links: navLinks, active: 'index.html'),
    lang: lang,
  );

  // --- work_<n>.html (her iş örneği için) ---
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
      metaDescription: workTitle,
      ogImage: w['url'],
      schemaType: 'CreativeWork',
      navHtml: siteNavHtml(links: navLinks, active: 'index.html'),
      lang: lang,
    );
  }

  return files;
}
