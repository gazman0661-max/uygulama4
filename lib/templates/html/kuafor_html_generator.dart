import 'shared_html_blocks.dart';

/// kuafor_site_template paketindeki BusinessSite modelinin yerel,
/// yerel HTML karşılığı.
///
/// NOT: business_site.dart modelindeki alan adları burada aynen
/// kullanılıyor — ServiceItem, GalleryImage, DayWorkingHours, Weekday.
/// Formdan (kuafor_form_screen gibi bir ekran üreteceksen) gelen veriyi
/// doğrudan bu parametrelere eşle, ayrıca bir dönüşüm katmanı gerekmez.
///
/// AYNI FONKSİYON, aynı BusinessSite şekli kullanan diğer sektörler için
/// de (oto yıkama, temizlik, kurs, çiçekçi, tadilat, masaj/spa, nakliyat,
/// evcil hayvan bakımı, terzi) temel alınıp kopyalanabilir; bu yüzden
/// generateBusinessSiteHtml genel isimle yazıldı.
///
/// `lang`: üretilen SİTENİN dili ('tr' | 'en') — sectorLabels() ve
/// siteLabels() bu değere göre doğru metni döner. servicesTitle/ctaText
/// gibi parametreler null bırakılırsa (verilmezse) sektöre özel varsayılan
/// metin otomatik olarak `lang`'a göre gelir (bkz. businessSectorLabels).
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
  String? googleReviewLink, // 01.09.2026 eklendi
  // 05.09.2026 eklendi — Video bloğu (kanka isteği). [videoUrl] boş/null
  // bırakılırsa (varsayılan) hiçbir şey değişmez — mevcut sitelerde yeni
  // bir bölüm ÇIKMAZ. Doluysa videoBlockHtml çağrılır (bkz. shared_html_blocks.dart
  // dokümanı — dış link embed, worker'a ekstra maliyet yok). [videoOrientation]
  // 'landscape' (yatay) veya 'portrait' (dikey/Shorts) olabilir.
  String? videoUrl,
  String videoOrientation = 'landscape',
  String? videoTitle,
  // Sektöre göre değişen metinler — null bırakılırsa sectorKey +
  // lang'a göre otomatik doldurulur (aşağıdaki businessSectorLabels).
  String? servicesTitle,
  String? galleryTitle,
  String? hoursTitle,
  String? mapTitle,
  String? contactTitle,
  String? ctaText,
  String sectorKey = 'default',
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  bool galleryBeforeAfter = false,
  // schema.org JSON-LD tipi — sektöre göre çağıran ekran uygun değeri
  // geçmeli (örn. kuaför 'HairSalon', oto yıkama 'AutoWash'). Önceden
  // burası hep sabit 'HairSalon' idi; bu, generateBusinessSiteHtml'i
  // kullanan diğer 9 sektörün (oto yıkama, temizlik, kurs, çiçekçi,
  // tadilat, masaj/spa, nakliyat, evcil hayvan bakımı, terzi) HEPSİNİN
  // Google'a yanlış işletme türü bildirmesine sebep oluyordu — düzeltildi.
  String schemaType = 'LocalBusiness',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  // 05.09.2026 eklendi — kanka isteği: talep formu artık formdan
  // (LeadFormToggleField) kontrol edilebiliyor; free plan'da zaten
  // FreePlanRestrictionService.isPremiumGeneration bunu ezip kapatıyor.
  bool includeLeadForm = true,
}) {
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final sector = businessSectorLabels(sectorKey, lang);
  final resolvedServicesTitle = servicesTitle ?? sector['servicesTitle']!;
  final resolvedCtaText = ctaText ?? sector['ctaText']!;
  final resolvedGalleryTitle = galleryTitle ?? labels['gallery']!;
  final resolvedHoursTitle = hoursTitle ?? labels['hours']!;
  final resolvedMapTitle = mapTitle ?? labels['location']!;
  final resolvedContactTitle = contactTitle ?? labels['contact']!;

  body.writeln(heroBlockHtml(
    name: name,
    tagline: tagline,
    coverImage: coverImage,
    logoImage: logoImage,
    ctaText: resolvedCtaText,
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : (phone.isNotEmpty ? 'tel:$phone' : null),
  ));

  if (about != null && about.isNotEmpty) {
    body.writeln('<section class="section about-section"><p>${escapeHtml(about)}</p></section>');
  }

  if (services.isNotEmpty) {
    body.writeln(serviceListBlockHtml(title: resolvedServicesTitle, services: services));
  }

  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: resolvedGalleryTitle, images: gallery, beforeAfter: galleryBeforeAfter));
  }

  if (videoUrl != null && videoUrl.trim().isNotEmpty) {
    body.writeln(videoBlockHtml(
      title: videoTitle ?? labels['videoTitle']!,
      videoUrl: videoUrl,
      orientation: videoOrientation,
      lang: lang,
    ));
  }

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: resolvedHoursTitle, hours: workingHours, lang: lang));
  }

  if (testimonials.isNotEmpty) {
    body.writeln(testimonialBlockHtml(testimonials: testimonials, lang: lang));
  }

  if (faqs.isNotEmpty) {
    body.writeln(faqBlockHtml(faqs: faqs, lang: lang));
  }

  if (address.trim().isNotEmpty) {
    body.writeln(mapBlockHtml(title: resolvedMapTitle, address: address, lat: lat, lng: lng, lang: lang));
  }

  body.writeln(contactBlockHtml(
    title: resolvedContactTitle,
    phone: phone.isNotEmpty ? phone : null,
    whatsapp: whatsapp,
    instagram: instagram,
    googleReviewLink: googleReviewLink,
    lang: lang,
    siteName: name,
    includeLeadForm: includeLeadForm,
  ));

  return wrapPageHtml(
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
  );
}
