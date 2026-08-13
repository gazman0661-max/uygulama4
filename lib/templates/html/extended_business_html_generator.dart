import 'shared_html_blocks.dart';

/// beauty_salon_template ve fitness_template AYNI "extended" BusinessSite
/// yapısını paylaşıyor (businessName, slogan, packages, team, WorkingDay/
/// LocationInfo/ContactInfo). Aralarındaki tek fark:
///   - Güzellik Salonu: beforeAfterGallery kullanır, schedule kullanmaz
///   - Fitness: schedule kullanır, beforeAfterGallery kullanmaz
/// Bu yüzden tek fonksiyon, ikisini de opsiyonel parametrelerle karşılar.
String generateExtendedBusinessSiteHtml({
  required String businessName,
  required String coverImageUrl,
  required String slogan,
  String? logoUrl,
  List<Map<String, String?>> services = const [],
  List<Map<String, dynamic>> packages = const [], // {title, sessionLabel, price, originalPrice, includedServices, note, isFeatured}
  List<Map<String, String?>> gallery = const [],
  List<Map<String, String?>> beforeAfterGallery = const [],
  List<Map<String, dynamic>> team = const [], // {name, specialty, photoUrl, bio, tags}
  List<Map<String, String?>> schedule = const [], // {day, time, className, trainer} — fitness
  required List<Map<String, String?>> workingHours, // {day, range}
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? email,
  String? instagram,
  // Sektöre göre değişen başlıklar
  String servicesTitle = 'Hizmetlerimiz',
  String packagesTitle = 'Paketlerimiz',
  String galleryTitle = 'Galeri',
  String teamTitle = 'Ekibimiz',
  String scheduleTitle = 'Program',
  String accentColor = '#212529',
}) {
  final body = StringBuffer();

  body.writeln(heroBlockHtml(
    name: businessName,
    tagline: slogan,
    coverImage: coverImageUrl,
    logoImage: logoUrl,
    ctaText: 'Randevu Al',
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : 'tel:$phone',
  ));

  if (services.isNotEmpty) {
    body.writeln(serviceListBlockHtml(title: servicesTitle, services: services));
  }

  if (packages.isNotEmpty) {
    body.writeln(packageCardsBlockHtml(title: packagesTitle, packages: packages));
  }

  if (schedule.isNotEmpty) {
    body.writeln(scheduleTableBlockHtml(title: scheduleTitle, entries: schedule));
  }

  if (beforeAfterGallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(title: 'Öncesi / Sonrası', images: beforeAfterGallery, beforeAfter: true));
  } else if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(title: galleryTitle, images: gallery));
  }

  if (team.isNotEmpty) {
    body.writeln(teamBlockHtml(title: teamTitle, members: team));
  }

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: 'Çalışma Saatleri', hours: workingHours));
  }

  if (lat != null && lng != null) {
    body.writeln(mapBlockHtml(title: 'Konum', address: address, lat: lat, lng: lng));
  } else {
    body.writeln('<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>');
  }

  body.writeln(contactBlockHtml(
    title: 'İletişim',
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
  ));

  return wrapPageHtml(pageTitle: businessName, bodyHtml: body.toString(), accentColor: accentColor);
}
