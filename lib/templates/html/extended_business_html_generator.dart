import 'shared_html_blocks.dart';
import 'section_registry.dart';

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
  String? googleReviewLink, // 01.09.2026 eklendi
  // 05.09.2026 eklendi — Video bloğu (kanka isteği).
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
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
  // 07.09.2026 eklendi (kanka isteği) — hero düzeni seçimi.
  String heroLayoutStyle = 'centered',
  bool includeLeadForm = true, // 05.09.2026 eklendi
  // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle (bkz.
  // kuafor_html_generator.dart dokümanı, aynı kalıp).
  List<String>? sectionOrder,
}) {
  // 11.09.2026 eklendi — bkz. shared_html_blocks.dart > shapeStyleOf.
  final siteShapeStyle = pickVariant(businessName, 'shape', ['keskin', 'yumusak', 'yuvarlak']);
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
    layoutStyle: heroLayoutStyle,
  ));

  // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle (bkz.
  // kuafor_html_generator.dart dokümanı, aynı kalıp). 'gallery' id'si
  // öncesi/sonrası VEYA normal galeriyi temsil eder (ikisi aynı anda
  // gösterilmez, orijinal kodda da öyleydi).
  final middleBuilders = <String, String? Function()>{
    'services': () => services.isNotEmpty
        ? serviceListBlockHtml(title: resolvedServicesTitle, services: services)
        : null,
    'packages': () => packages.isNotEmpty
        ? packageCardsBlockHtml(title: resolvedPackagesTitle, packages: packages)
        : null,
    'schedule': () => schedule.isNotEmpty
        ? scheduleTableBlockHtml(title: resolvedScheduleTitle, entries: schedule)
        : null,
    'gallery': () {
      if (beforeAfterGallery.isNotEmpty) {
        return galleryBlockHtml(style: galleryStyle, title: beforeAfterTitle, images: beforeAfterGallery, beforeAfter: true);
      }
      if (gallery.isNotEmpty) {
        return galleryBlockHtml(style: galleryStyle, title: resolvedGalleryTitle, images: gallery);
      }
      return null;
    },
    'team': () => team.isNotEmpty ? teamBlockHtml(title: resolvedTeamTitle, members: team) : null,
    'video': () => (videoUrl != null && videoUrl.trim().isNotEmpty)
        ? videoBlockHtml(title: videoTitle ?? labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
        : null,
    'hours': () => workingHours.isNotEmpty
        ? workingHoursBlockHtml(title: labels['hours']!, hours: workingHours, lang: lang)
        : null,
    'map': () {
      if (address.trim().isEmpty) return null;
      if (lat != null && lng != null) {
        return mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang);
      }
      return '<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>';
    },
  };
  final effectiveOrder = (sectionOrder == null || sectionOrder.isEmpty)
      ? kExtendedBusinessDefaultOrder
      : sectionOrder;
  for (final sectionId in effectiveOrder) {
    final html = middleBuilders[sectionId]?.call();
    if (html != null) body.writeln(html);
  }

  body.writeln(contactBlockHtml(
    title: labels['contact']!,
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
    includeLeadForm: includeLeadForm,
  ));

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    shapeStyle: siteShapeStyle,
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
