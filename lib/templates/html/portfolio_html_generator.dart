import 'shared_html_blocks.dart';

/// portfolio_template'in HTML karşılığı.
String generatePortfolioHtml({
  required String name,
  required String title, // meslek/unvan
  required String photo,
  required String tagline,
  required String aboutText,
  List<String> skills = const [],
  List<Map<String, String?>> works = const [], // {url, caption}
  List<Map<String, String?>> timeline = const [], // {year, title, description}
  required String contactEmail,
  String themeId = 'clean_light',
}) {
  final body = StringBuffer();

  body.writeln(heroBlockHtml(
    name: name,
    tagline: '$title — $tagline',
    coverImage: photo,
  ));

  body.writeln('<section class="section about-section">'
      '<p>${escapeHtml(aboutText)}</p>'
      '${skills.isNotEmpty ? '<div style="margin-top:16px;">${skillChipsBlockHtml(skills)}</div>' : ''}'
      '</section>');

  if (works.isNotEmpty) {
    body.writeln(galleryBlockHtml(title: 'İş Örnekleri', images: works));
  }

  if (timeline.isNotEmpty) {
    body.writeln(timelineBlockHtml(title: 'Deneyim & Eğitim', entries: timeline));
  }

  body.writeln(contactFormBlockHtml(title: 'İletişim', email: contactEmail));

  return wrapPageHtml(
    pageTitle: name,
    bodyHtml: body.toString(),
    themeId: themeId,
    metaDescription: '$title — $tagline',
    ogImage: photo,
  );
}
