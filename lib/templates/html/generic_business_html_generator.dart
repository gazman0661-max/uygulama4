import 'shared_html_blocks.dart';

/// "Genel İşletme" — sektöre özel bir form yoksa (kırtasiye, bakkal,
/// kuyumcu, optik, züccaciye, oyuncakçı vb.) kullanılan, gerçekten genel
/// amaçlı generator. generateBusinessSiteHtml (kuafor_html_generator.dart)
/// ile AYNI blokları (hero/hizmetler/galeri/çalışma saatleri/harita/
/// iletişim) kullanır — tek sayfa modunda zaten o fonksiyonu birebir
/// çağırmak yeterli, bu dosya sadece ÇOK SAYFA modunu ekliyor: index.html
/// + kullanıcının serbestçe eklediği "ek sayfalar" (örn. Hakkımızda,
/// Şartlar, Kurumsal), hepsi ortak bir üst gezinme çubuğuyla (siteNavHtml,
/// bkz. shared_html_blocks.dart) birbirine bağlı.
///
/// [extraPages] her biri {'slug', 'title', 'content'} anahtarlı bir liste.
/// 'content' düz metindir; boş satırlarla ayrılmış paragraflar otomatik
/// <p> etiketlerine bölünür (bkz. _paragraphsHtml). En az 1 extraPage
/// verilmezse dönen Map sadece 'index.html' içerir (nav da otomatik
/// eklenmez, tek sayfa gibi davranır) — form ekranı yine de bu durumda
/// tek sayfa modunu (generateBusinessSiteHtml) doğrudan çağırmalı, bu
/// fonksiyon SADECE en az 1 ek sayfa olduğunda anlamlıdır.
Map<String, String> generateGenericBusinessSite({
  required String name,
  required String coverImage,
  String? logoImage,
  required String tagline,
  String? about,
  required List<Map<String, String?>> services,
  required List<Map<String, String?>> gallery,
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink, // 01.09.2026 eklendi
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  String schemaType = 'LocalBusiness',
  List<Map<String, String>> extraPages = const [],
}) {
  final labels = siteLabels(lang);
  final sector = businessSectorLabels('default', lang);
  final homeLabel = labels['home']!;
  final navPages = <Map<String, String>>[
    {'href': 'index.html', 'label': homeLabel},
    for (final p in extraPages) {'href': '${p['slug']}.html', 'label': p['title'] ?? ''},
  ];

  final body = StringBuffer();
  body.writeln(siteNavHtml(links: navPages, active: 'index.html'));
  body.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    logoImage: logoImage,
    ctaText: whatsapp != null ? 'WhatsApp' : sector['ctaText']!,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : (phone.isNotEmpty ? 'tel:$phone' : null),
  ));

  if (about != null && about.isNotEmpty) {
    body.writeln('<section class="section about-section"><p>${escapeHtml(about)}</p></section>');
  }
  if (services.isNotEmpty) {
    body.writeln(serviceListBlockHtml(title: sector['servicesTitle']!, services: services));
  }
  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: labels['gallery']!, images: gallery));
  }
  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang));
  }
  body.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  body.writeln(contactBlockHtml(
    title: labels['contact']!,
    phone: phone.isNotEmpty ? phone : null,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
  ));

  final files = <String, String>{
    'index.html': wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      pageTitle: name,
      bodyHtml: body.toString(),
      themeId: themeId,
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
    pageBody.writeln(siteNavHtml(links: navPages, active: '$slug.html'));
    pageBody.writeln('<section class="section">');
    pageBody.writeln('<h1 class="section-title">${escapeHtml(title)}</h1>');
    pageBody.writeln(_paragraphsHtml(content));
    pageBody.writeln('</section>');
    pageBody.writeln(contactBlockHtml(
      title: labels['contact']!,
      phone: phone.isNotEmpty ? phone : null,
      whatsapp: whatsapp,
      instagram: instagram,
      googleReviewLink: googleReviewLink,
      lang: lang,
    ));

    files['$slug.html'] = wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
      pageTitle: '$title — $name',
      bodyHtml: pageBody.toString(),
      themeId: themeId,
      metaDescription: content.length > 160 ? content.substring(0, 157) : content,
      ogImage: coverImage,
      schemaType: schemaType,
      whatsapp: whatsapp,
      phone: phone.isNotEmpty ? phone : null,
      lang: lang,
    );
  }

  return files;
}

/// Düz metni boş satırlara göre paragraflara böler, her birini escape
/// edip ayrı bir `<p>` içine koyar. Kullanıcı serbest metin girdiği için
/// (ör. "Hakkımızda" sayfası) HTML enjeksiyonuna karşı escapeHtml şart.
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

/// Kullanıcının girdiği sayfa başlığından basit, benzersiz bir slug üretir
/// (örn. "Şartlar & Koşullar" -> "sartlar-kosullar"). [existingSlugs]
/// çakışma olursa sonuna -2, -3... eklenir.
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
  if (s == 'index') s = 'sayfa'; // index.html ile çakışmasın
  var candidate = s;
  var i = 2;
  while (existingSlugs.contains(candidate)) {
    candidate = '$s-$i';
    i++;
  }
  return candidate;
}
