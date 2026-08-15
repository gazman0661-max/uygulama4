import 'shared_html_blocks.dart';

/// kafe_site_template paketi, kuaförle AYNI BusinessSite modelini kullanıyor
/// (services yerine menuCategories dolu geliyor). Bu yüzden ayrı bir model
/// tanımına gerek yok — kuafor_html_generator.dart'taki
/// generateBusinessSiteHtml'i services=[] geçip menuCategories ekleyerek
/// çağırmak da mümkündü, ama menü + QR menü ayrı bir görsel blok olduğu
/// için kafeye özel bir sarmalayıcı yazıldı.
String generateCafeHtml({
  required String name,
  required String coverImage,
  String? logoImage,
  required String tagline,
  String? about,
  required List<Map<String, dynamic>> menuCategories, // {title, items:[{name, description, price}]}
  String? menuUrl, // QR menü linki
  required List<Map<String, String?>> gallery,
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String themeId = 'clean_light',
}) {
  final body = StringBuffer();
  final accentColor = themeAccent(themeId);

  body.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    logoImage: logoImage,
    ctaText: 'Rezervasyon',
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : 'tel:$phone',
  ));

  if (about != null && about.isNotEmpty) {
    body.writeln('<section class="section about-section"><p>${escapeHtml(about)}</p></section>');
  }

  if (menuCategories.isNotEmpty) {
    body.writeln(menuBlockHtml(title: 'Menü', categories: menuCategories));
  }

  if (menuUrl != null) {
    body.writeln('''
<section class="section qr-menu-section" style="text-align:center;">
  <a class="hero-cta" style="background:$accentColor;" href="${escapeHtml(menuUrl)}" target="_blank">📱 Dijital Menüyü Aç</a>
</section>''');
  }

  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(title: 'Galeri', images: gallery));
  }

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: 'Çalışma Saatleri', hours: workingHours));
  }

  body.writeln(mapBlockHtml(title: 'Konum', address: address, lat: lat, lng: lng));

  body.writeln(contactBlockHtml(
    title: 'İletişim',
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
  ));

  return wrapPageHtml(
    pageTitle: name,
    bodyHtml: body.toString(),
    themeId: themeId,
    metaDescription: (about != null && about.isNotEmpty) ? about : tagline,
    ogImage: coverImage,
    whatsapp: whatsapp,
    phone: phone,
  );
}
