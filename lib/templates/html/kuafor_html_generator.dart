import 'shared_html_blocks.dart';

/// kuafor_site_template paketindeki BusinessSite modelinin AI'sız,
/// yerel HTML karşılığı.
///
/// NOT: business_site.dart modelindeki alan adları burada aynen
/// kullanılıyor — ServiceItem, GalleryImage, DayWorkingHours, Weekday.
/// Formdan (kuafor_form_screen gibi bir ekran üreteceksen) gelen veriyi
/// doğrudan bu parametrelere eşle, ayrıca bir dönüşüm katmanı gerekmez.
///
/// AYNI FONKSİYON, aynı BusinessSite şekli kullanan diğer sektörler için
/// de (oto yıkama, klinik — sadece başlıklar/ikonlar değişir) temel alınıp
/// kopyalanabilir; bu yüzden generateBusinessSiteHtml genel isimle yazıldı.
String generateBusinessSiteHtml({
  required String name,
  required String coverImage,
  String? logoImage,
  required String tagline,
  String? about,
  required List<Map<String, String?>> services, // {name, duration, price}
  required List<Map<String, String?>> gallery, // {url, caption}
  required List<Map<String, String?>> workingHours, // {day, range}
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  // Sektöre göre değişen metinler — kuaför/oto/klinik aynı fonksiyonu
  // farklı başlıklarla çağırabilir.
  String servicesTitle = 'Hizmetlerimiz',
  String galleryTitle = 'Galeri',
  String hoursTitle = 'Çalışma Saatleri',
  String mapTitle = 'Konum',
  String contactTitle = 'İletişim',
  String ctaText = 'Randevu Al',
  String themeId = 'clean_light',
  bool galleryBeforeAfter = false,
}) {
  final body = StringBuffer();

  body.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    logoImage: logoImage,
    ctaText: ctaText,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : (phone.isNotEmpty ? 'tel:$phone' : null),
  ));

  if (about != null && about.isNotEmpty) {
    body.writeln('<section class="section about-section"><p>${escapeHtml(about)}</p></section>');
  }

  if (services.isNotEmpty) {
    body.writeln(serviceListBlockHtml(title: servicesTitle, services: services));
  }

  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(title: galleryTitle, images: gallery, beforeAfter: galleryBeforeAfter));
  }

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: hoursTitle, hours: workingHours));
  }

  body.writeln(mapBlockHtml(title: mapTitle, address: address, lat: lat, lng: lng));

  body.writeln(contactBlockHtml(
    title: contactTitle,
    phone: phone.isNotEmpty ? phone : null,
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
    phone: phone.isNotEmpty ? phone : null,
  );
}
