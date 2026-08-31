import 'shared_html_blocks.dart';

/// beauty_salon_template ve fitness_template AYNI "extended" BusinessSite
/// yapısını paylaşıyor (businessName, slogan, packages, team, WorkingDay/
/// LocationInfo/ContactInfo). Aralarındaki tek fark:
///   - Güzellik Salonu: beforeAfterGallery kullanır, schedule kullanmaz
///   - Fitness: schedule kullanır, beforeAfterGallery kullanmaz
/// Bu yüzden tek fonksiyon, ikisini de opsiyonel parametrelerle karşılar.
///
/// Başlık parametreleri null bırakılırsa `lang`'a göre otomatik
/// doldurulur (bkz. siteLabels / shared_html_blocks.dart).
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
  // Sektöre göre değişen başlıklar — null ise lang'a göre otomatik.
  String? servicesTitle,
  String? packagesTitle,
  String? galleryTitle,
  String? teamTitle,
  String? scheduleTitle,
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String schemaType = 'LocalBusiness',
  String lang = 'tr',
}) {
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final resolvedServicesTitle = servicesTitle ?? (lang == 'en' ? 'Our Services' : 'Hizmetlerimiz');
  final resolvedPackagesTitle = packagesTitle ?? (lang == 'en' ? 'Our Packages' : 'Paketlerimiz');
  final resolvedGalleryTitle = galleryTitle ?? labels['gallery']!;
  final resolvedTeamTitle = teamTitle ?? (lang == 'en' ? 'Our Team' : 'Ekibimiz');
  final resolvedScheduleTitle = scheduleTitle ?? (lang == 'en' ? 'Schedule' : 'Program');
  final beforeAfterTitle = lang == 'en' ? 'Before / After' : 'Öncesi / Sonrası';

  body.writeln(heroBlockHtml(
    name: businessName,
    tagline: slogan,
    coverImage: coverImageUrl,
    logoImage: logoUrl,
    ctaText: labels['reservation']!,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : 'tel:$phone',
  ));

  if (services.isNotEmpty) {
    body.writeln(serviceListBlockHtml(title: resolvedServicesTitle, services: services));
  }

  if (packages.isNotEmpty) {
    body.writeln(packageCardsBlockHtml(title: resolvedPackagesTitle, packages: packages));
  }

  if (schedule.isNotEmpty) {
    body.writeln(scheduleTableBlockHtml(title: resolvedScheduleTitle, entries: schedule));
  }

  if (beforeAfterGallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: beforeAfterTitle, images: beforeAfterGallery, beforeAfter: true));
  } else if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: resolvedGalleryTitle, images: gallery));
  }

  if (team.isNotEmpty) {
    body.writeln(teamBlockHtml(title: resolvedTeamTitle, members: team));
  }

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang));
  }

  if (lat != null && lng != null) {
    body.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));
  } else {
    body.writeln('<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>');
  }

  body.writeln(contactBlockHtml(
    title: labels['contact']!,
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
    lang: lang,
  ));

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: businessName,
    bodyHtml: body.toString(),
    themeId: themeId,
    metaDescription: slogan,
    ogImage: coverImageUrl,
    schemaType: schemaType,
    whatsapp: whatsapp,
    phone: phone,
    lang: lang,
  );
}
