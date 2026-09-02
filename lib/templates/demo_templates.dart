import 'package:flutter/widgets.dart';
import '../screens/kuafor_form_screen.dart';
import '../screens/kafe_form_screen.dart';
import '../screens/clinic_form_screen.dart';
import '../screens/auto_repair_form_screen.dart';
import '../screens/bakery_form_screen.dart';
import '../screens/beauty_salon_form_screen.dart';
import '../screens/bio_link_form_screen.dart';
import '../screens/boutique_hotel_form_screen.dart';
import '../screens/business_card_form_screen.dart';
import '../screens/car_wash_form_screen.dart';
import '../screens/cleaning_company_form_screen.dart';
import '../screens/dentist_form_screen.dart';
import '../screens/dietitian_form_screen.dart';
import '../screens/driving_school_form_screen.dart';
import '../screens/electrician_form_screen.dart';
import '../screens/fitness_form_screen.dart';
import '../screens/florist_form_screen.dart';
import '../screens/furniture_decor_form_screen.dart';
import '../screens/generic_business_form_screen.dart';
import '../screens/handyman_form_screen.dart';
import '../screens/kindergarten_form_screen.dart';
import '../screens/lawyer_form_screen.dart';
import '../screens/makeup_artist_form_screen.dart';
import '../screens/massage_spa_form_screen.dart';
import '../screens/moving_company_form_screen.dart';
import '../screens/musician_dj_form_screen.dart';
import '../screens/personal_trainer_form_screen.dart';
import '../screens/pet_grooming_form_screen.dart';
import '../screens/photographer_form_screen.dart';
import '../screens/portfolio_form_screen.dart';
import '../screens/real_estate_form_screen.dart';
import '../screens/restaurant_form_screen.dart';
import '../screens/tailor_form_screen.dart';
import '../screens/veterinarian_form_screen.dart';
import 'html/kuafor_html_generator.dart';
import 'html/cafe_html_generator.dart';
import 'html/clinic_html_generator.dart';
import 'html/extended_business_html_generator.dart';
import 'html/portfolio_html_generator.dart';
import 'html/bio_link_html_generator.dart';
import 'html/business_card_html_generator.dart';
import 'html/real_estate_html_generator.dart';

/// 27.08.2026 eklendi — "Ön izleme" özelliği: kullanıcı forma hiç
/// girmeden, o şablonun SABİT örnek verilerle nasıl göründüğünü görebilir
/// (bkz. screens/template_preview_screen.dart), üstelik tema/tipografi
/// seçeneklerini de canlı deneyebilir (aynı ThemePickerField/
/// TypographyPickerField widget'ları, generateXxxHtml fonksiyonları saf
/// Dart string üretimi olduğu için tamamen yerel/anlık, ağa hiç gitmiyor).
///
/// ŞİMDİLİK sadece 3 şablon var (Kuaför, Kafe/Restoran, Klinik) — sistem
/// oturduktan sonra diğer ~30 forma da aynı desenle eklenebilir. Yeni bir
/// şablon eklemek için: bu dosyaya bir [TemplateDemoConfig] daha ekle,
/// home_screen.dart'taki ilgili karta `demo: demoXxx` geç.
class TemplateDemoConfig {
  const TemplateDemoConfig({
    required this.title,
    required this.buildHtml,
    required this.openForm,
    this.showTypography = true,
  });

  /// Ön izleme ekranının başlığında gösterilir (ör. "Kuaför / Berber —
  /// Ön İzleme").
  final String title;

  /// Sabit örnek verilerle + seçilen tema/font/yoğunlukla tam bir site
  /// HTML'i üretir. Saf fonksiyon — state tutmaz, her çağrıda yeniden
  /// üretir (WebView'a her seçim değişiminde yeniden yüklenir).
  final String Function({
    required String themeId,
    required String fontPackageId,
    required String density,
  }) buildHtml;

  /// "Bu şablonla oluştur" butonuna basılınca açılacak GERÇEK form
  /// ekranını döner — kullanıcının ön izlemede son seçtiği tema/font/
  /// yoğunluk, forma initialData olarak ÖNCEDEN DOLU gelir (isEditing
  /// DEĞİL — sıfırdan yeni bir site, sadece görsel tercihler taşınıyor).
  final Widget Function({
    required String themeId,
    required String fontPackageId,
    required String density,
  }) openForm;

  /// 28.08.2026 eklendi — bio_link ve business_card şablonlarının HTML
  /// üreticisi (generateBioLinkHtml / generateBusinessCardHtml) hiç
  /// fontPackageId/density parametresi ALMIYOR (sadece themeId var, bkz.
  /// ilgili generator dosyaları). Bu iki şablon için ön izlemede
  /// tipografi seçicisini göstermenin bir anlamı yok — seçim yapılsa bile
  /// hiçbir etkisi olmaz, kullanıcıyı yanıltır. Bu yüzden false ise
  /// TypographyPickerField hiç render edilmez (bkz.
  /// template_preview_screen.dart).
  final bool showTypography;
}

/// Örnek görseller — ÖNCE placehold.co (çirkin gri kutu), SONRA
/// picsum.photos (konuyla alakasız/rastgele fotoğraflar — kullanıcı geri
/// bildirimi: "saçma saçma görseller geliyor") denendi, ikisi de iyi
/// sonuç vermedi. Artık HİÇ dışarıya (ağa) gidilmiyor: sektöre uygun bir
/// emoji + marka rengi gradyanından yerel bir SVG üretilip data: URI
/// olarak gömülüyor. Böylece hem tutarlı/kontrollü hem de asla "yanlış"
/// bir fotoğraf gelme riski yok.
String _demoCover(String emoji, {String from = '#6d5efc', String to = '#a78bfa'}) {
  final svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 800">'
      '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0" stop-color="$from"/><stop offset="1" stop-color="$to"/>'
      '</linearGradient></defs>'
      '<rect width="1200" height="800" fill="url(#g)"/>'
      '<text x="600" y="440" font-size="220" text-anchor="middle" dominant-baseline="middle">$emoji</text>'
      '</svg>';
  return 'data:image/svg+xml;utf8,${Uri.encodeComponent(svg)}';
}

List<Map<String, String?>> _demoGallery(String emoji, {String from = '#6d5efc', String to = '#a78bfa'}) =>
    List.generate(3, (_) => {'url': _demoCover(emoji, from: from, to: to), 'caption': null});

final TemplateDemoConfig demoKuafor = TemplateDemoConfig(
  title: 'Kuaför / Berber',
  buildHtml: ({required themeId, required fontPackageId, required density}) => generateBusinessSiteHtml(
    name: 'Ayşe Kuaför',
    coverImage: _demoCover('✂️', from: '#f97362', to: '#fbbf7d'),
    tagline: 'Şehrin en şık saç ve bakım stüdyosu',
    services: const [
      {'name': 'Saç Kesimi', 'duration': '30 dk', 'price': '250 TL'},
      {'name': 'Saç Boyama', 'duration': '90 dk', 'price': '900 TL'},
      {'name': 'Sakal Tıraşı', 'duration': '20 dk', 'price': '150 TL'},
    ],
    gallery: _demoGallery('✂️', from: '#f97362', to: '#fbbf7d'),
    workingHours: const [
      {'day': 'Pazartesi - Cuma', 'range': '09:00 - 19:00'},
      {'day': 'Cumartesi', 'range': '10:00 - 17:00'},
    ],
    address: 'Bağdat Caddesi No:123, Kadıköy, İstanbul',
    lat: 40.9789,
    lng: 29.0453,
    phone: '05551234567',
    whatsapp: '905551234567',
    instagram: 'aysekuafor',
    themeId: themeId,
    fontPackageId: fontPackageId,
    density: density,
    schemaType: 'HairSalon',
  ),
  openForm: ({required themeId, required fontPackageId, required density}) => KuaforFormScreen(
    initialData: {
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    },
  ),
);

final TemplateDemoConfig demoKafe = TemplateDemoConfig(
  title: 'Kafe / Restoran',
  buildHtml: ({required themeId, required fontPackageId, required density}) => generateCafeHtml(
    name: 'Kahve Durağı',
    coverImage: _demoCover('☕', from: '#a06b3f', to: '#e0a45f'),
    tagline: 'Taze kavrulmuş kahve, ev yapımı tatlılar',
    menuCategories: const [
      {
        'title': 'Sıcak İçecekler',
        'items': [
          {'name': 'Espresso', 'description': 'Tek shot', 'price': '60 TL'},
          {'name': 'Latte', 'description': 'Sütlü, köpüklü', 'price': '90 TL'},
        ],
      },
      {
        'title': 'Tatlılar',
        'items': [
          {'name': 'Cheesecake', 'description': 'Günlük taze', 'price': '150 TL'},
        ],
      },
    ],
    gallery: _demoGallery('☕', from: '#a06b3f', to: '#e0a45f'),
    workingHours: const [
      {'day': 'Her gün', 'range': '08:00 - 23:00'},
    ],
    address: 'İstiklal Caddesi No:45, Beyoğlu, İstanbul',
    lat: 41.0345,
    lng: 28.9779,
    phone: '05559876543',
    whatsapp: '905559876543',
    instagram: 'kahveduragi',
    themeId: themeId,
    fontPackageId: fontPackageId,
    density: density,
    schemaType: 'CafeOrCoffeeShop',
  ),
  openForm: ({required themeId, required fontPackageId, required density}) => KafeFormScreen(
    initialData: {
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    },
  ),
);

final TemplateDemoConfig demoKlinik = TemplateDemoConfig(
  title: 'Klinik / Sağlık',
  buildHtml: ({required themeId, required fontPackageId, required density}) => generateClinicHtml(
    businessName: 'Yeşilköy Diş Kliniği',
    title: 'Diş Hekimi',
    photoUrl: _demoCover('🦷', from: '#3fa0a0', to: '#7fd4c1'),
    tagline: 'Gülüşünüz bizim işimiz',
    services: const [
      {'name': 'Diş Beyazlatma', 'duration': null, 'price': '2.500 TL'},
      {'name': 'İmplant', 'duration': null, 'price': '8.000 TL'},
      {'name': 'Kanal Tedavisi', 'duration': null, 'price': '1.800 TL'},
    ],
    practitioner: {
      'name': 'Dr. Elif Yeşil',
      'title': 'Diş Hekimi',
      'photoUrl': _demoCover('👩‍⚕️', from: '#3fa0a0', to: '#7fd4c1'),
      'bio': '12 yıllık deneyimiyle hasta memnuniyetini önceliğe alır.',
      'credentials': const [
        {'label': 'İstanbul Üniversitesi Diş Hekimliği Fakültesi'},
      ],
    },
    workingHours: const [
      {'day': 'Pazartesi - Cumartesi', 'range': '09:00 - 18:00'},
    ],
    address: 'Yeşilköy Mah. Sağlık Sok. No:7, İstanbul',
    lat: 40.9633,
    lng: 28.8256,
    phone: '05551112233',
    whatsapp: '905551112233',
    themeId: themeId,
    fontPackageId: fontPackageId,
    density: density,
  ),
  openForm: ({required themeId, required fontPackageId, required density}) => ClinicFormScreen(
    initialData: {
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    },
  ),
);

// ===========================================================================
// 28.08.2026 eklendi — kalan ~31 şablon için genel (generic) demo
// üreticiler. Yukarıdaki 3 şablon (Kuaför/Kafe/Klinik) elle yazılmıştı;
// aynı deseni 30+ kez tekrarlamak yerine, her generator ailesi (bkz.
// generate*Html fonksiyonları) için TEK bir yardımcı fonksiyon yazılıp,
// her sektör sadece kendi metin/renk/emoji farklılıklarını geçiyor.
// ===========================================================================

/// generateBusinessSiteHtml kullanan sektörler için (Kuaför ailesi — en
/// büyük grup: oto tamirci, elektrikçi, terzi, çiçekçi, temizlik,
/// nakliyat, tadilatçı, anaokulu, sürücü kursu, masaj/spa, pet kuaförü,
/// genel işletme, oto yıkama, butik otel, mobilyacı vb.)
TemplateDemoConfig _bizDemo({
  required String title,
  required String emoji,
  required String from,
  required String to,
  required String name,
  required String tagline,
  required List<Map<String, String?>> services,
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String schemaType = 'LocalBusiness',
  required Widget Function(Map<String, dynamic> initialData) formBuilder,
}) {
  return TemplateDemoConfig(
    title: title,
    buildHtml: ({required themeId, required fontPackageId, required density}) => generateBusinessSiteHtml(
      name: name,
      coverImage: _demoCover(emoji, from: from, to: to),
      tagline: tagline,
      services: services,
      gallery: _demoGallery(emoji, from: from, to: to),
      workingHours: workingHours,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      whatsapp: whatsapp,
      instagram: instagram,
      themeId: themeId,
      fontPackageId: fontPackageId,
      density: density,
      schemaType: schemaType,
    ),
    openForm: ({required themeId, required fontPackageId, required density}) => formBuilder({
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    }),
  );
}

/// generateCafeHtml kullanan sektörler için (Kafe ailesi — Fırın/Pastane,
/// Restoran/Lokanta).
TemplateDemoConfig _cafeDemo({
  required String title,
  required String emoji,
  required String from,
  required String to,
  required String name,
  required String tagline,
  required List<Map<String, dynamic>> menuCategories,
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String schemaType = 'Restaurant',
  required Widget Function(Map<String, dynamic> initialData) formBuilder,
}) {
  return TemplateDemoConfig(
    title: title,
    buildHtml: ({required themeId, required fontPackageId, required density}) => generateCafeHtml(
      name: name,
      coverImage: _demoCover(emoji, from: from, to: to),
      tagline: tagline,
      menuCategories: menuCategories,
      gallery: _demoGallery(emoji, from: from, to: to),
      workingHours: workingHours,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      whatsapp: whatsapp,
      instagram: instagram,
      themeId: themeId,
      fontPackageId: fontPackageId,
      density: density,
      schemaType: schemaType,
    ),
    openForm: ({required themeId, required fontPackageId, required density}) => formBuilder({
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    }),
  );
}

/// generateClinicHtml kullanan sektörler için (Klinik ailesi — Diş
/// Hekimi, Diyetisyen, Avukat, Veteriner). "practitioner" tekil uzman
/// tanıtımı bölümü — her sektörde tek bir kişi/unvan öne çıkıyor.
TemplateDemoConfig _clinicDemo({
  required String title,
  required String emoji,
  required String from,
  required String to,
  required String businessName,
  required String roleTitle,
  required String tagline,
  required List<Map<String, String?>> services,
  required Map<String, dynamic> practitioner,
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  required Widget Function(Map<String, dynamic> initialData) formBuilder,
}) {
  return TemplateDemoConfig(
    title: title,
    buildHtml: ({required themeId, required fontPackageId, required density}) => generateClinicHtml(
      businessName: businessName,
      title: roleTitle,
      photoUrl: _demoCover(emoji, from: from, to: to),
      tagline: tagline,
      services: services,
      practitioner: practitioner,
      workingHours: workingHours,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      whatsapp: whatsapp,
      themeId: themeId,
      fontPackageId: fontPackageId,
      density: density,
    ),
    openForm: ({required themeId, required fontPackageId, required density}) => formBuilder({
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    }),
  );
}

/// generateExtendedBusinessSiteHtml kullanan sektörler için (Güzellik
/// Salonu — beforeAfterGallery, Fitness — schedule).
TemplateDemoConfig _extendedDemo({
  required String title,
  required String emoji,
  required String from,
  required String to,
  required String businessName,
  required String slogan,
  required List<Map<String, dynamic>> packages,
  List<Map<String, String?>> beforeAfterGallery = const [],
  List<Map<String, String?>> schedule = const [],
  required List<Map<String, String?>> workingHours,
  required String address,
  required double lat,
  required double lng,
  required String phone,
  String? whatsapp,
  String schemaType = 'LocalBusiness',
  required Widget Function(Map<String, dynamic> initialData) formBuilder,
}) {
  return TemplateDemoConfig(
    title: title,
    buildHtml: ({required themeId, required fontPackageId, required density}) => generateExtendedBusinessSiteHtml(
      businessName: businessName,
      coverImageUrl: _demoCover(emoji, from: from, to: to),
      slogan: slogan,
      packages: packages,
      gallery: _demoGallery(emoji, from: from, to: to),
      beforeAfterGallery: beforeAfterGallery,
      schedule: schedule,
      workingHours: workingHours,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      whatsapp: whatsapp,
      themeId: themeId,
      fontPackageId: fontPackageId,
      density: density,
      schemaType: schemaType,
    ),
    openForm: ({required themeId, required fontPackageId, required density}) => formBuilder({
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    }),
  );
}

/// generatePortfolioHtml kullanan sektörler için (Makyaj Sanatçısı,
/// Müzisyen/DJ, Kişisel Antrenör, Fotoğrafçı, genel Portfolyo).
TemplateDemoConfig _portfolioDemo({
  required String title,
  required String emoji,
  required String from,
  required String to,
  required String name,
  required String roleTitle,
  required String tagline,
  required String aboutText,
  List<String> skills = const [],
  required String contactEmail,
  required Widget Function(Map<String, dynamic> initialData) formBuilder,
}) {
  return TemplateDemoConfig(
    title: title,
    buildHtml: ({required themeId, required fontPackageId, required density}) => generatePortfolioHtml(
      name: name,
      title: roleTitle,
      photo: _demoCover(emoji, from: from, to: to),
      tagline: tagline,
      aboutText: aboutText,
      skills: skills,
      works: _demoGallery(emoji, from: from, to: to),
      contactEmail: contactEmail,
      themeId: themeId,
      fontPackageId: fontPackageId,
      density: density,
    ),
    openForm: ({required themeId, required fontPackageId, required density}) => formBuilder({
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    }),
  );
}

// ---------------------------------------------------------------------------
// Kuaför ailesi (generateBusinessSiteHtml) — 15 sektör
// ---------------------------------------------------------------------------

final demoAutoRepair = _bizDemo(
  title: 'Oto Tamirci / Lastikçi',
  emoji: '🔧', from: '#4b5563', to: '#9ca3af',
  name: 'Usta Oto Bakım',
  tagline: 'Güvenilir bakım ve onarım hizmeti',
  services: const [
    {'name': 'Genel Bakım', 'duration': null, 'price': '1.200 TL'},
    {'name': 'Lastik Değişimi', 'duration': null, 'price': '400 TL'},
    {'name': 'Fren Bakımı', 'duration': null, 'price': '800 TL'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '08:00 - 19:00'}],
  address: 'Sanayi Sitesi 4. Blok No:12, Ankara',
  lat: 39.9208, lng: 32.8541,
  phone: '05553334455', whatsapp: '905553334455',
  schemaType: 'AutoRepair',
  formBuilder: (d) => AutoRepairFormScreen(initialData: d),
);

final demoBoutiqueHotel = _bizDemo(
  title: 'Butik Otel / Pansiyon',
  emoji: '🏨', from: '#8b5cf6', to: '#c4b5fd',
  name: 'Deniz Manzara Butik Otel',
  tagline: 'Huzurlu bir kaçamak için doğru adres',
  services: const [
    {'name': 'Standart Oda', 'duration': null, 'price': '1.800 TL / gece'},
    {'name': 'Deniz Manzaralı Oda', 'duration': null, 'price': '2.600 TL / gece'},
    {'name': 'Suit Oda', 'duration': null, 'price': '3.900 TL / gece'},
  ],
  workingHours: const [{'day': 'Her gün', 'range': '7/24 Resepsiyon'}],
  address: 'Sahil Yolu No:8, Ayvalık, Balıkesir',
  lat: 39.3200, lng: 26.6900,
  phone: '05554445566', whatsapp: '905554445566', instagram: 'denizmanzaraotel',
  schemaType: 'LodgingBusiness',
  formBuilder: (d) => BoutiqueHotelFormScreen(initialData: d),
);

final demoCarWash = _bizDemo(
  title: 'Oto Yıkama / Servis',
  emoji: '🚿', from: '#0ea5e9', to: '#7dd3fc',
  name: 'Parlak Oto Yıkama',
  tagline: 'Aracınız bize emanet, parlaklığı garantili',
  services: const [
    {'name': 'İç-Dış Yıkama', 'duration': '30 dk', 'price': '350 TL'},
    {'name': 'Detaylı Cila', 'duration': '3 sa', 'price': '1.500 TL'},
    {'name': 'Motor Yıkama', 'duration': '20 dk', 'price': '250 TL'},
  ],
  workingHours: const [{'day': 'Her gün', 'range': '08:00 - 22:00'}],
  address: 'Ankara Caddesi No:56, Bursa',
  lat: 40.1826, lng: 29.0665,
  phone: '05555556677', whatsapp: '905555556677',
  schemaType: 'AutoWash',
  formBuilder: (d) => CarWashFormScreen(initialData: d),
);

final demoCleaningCompany = _bizDemo(
  title: 'Temizlik Şirketi',
  emoji: '🧹', from: '#22c55e', to: '#86efac',
  name: 'Pırıl Temizlik Hizmetleri',
  tagline: 'Ev ve ofisleriniz için profesyonel temizlik',
  services: const [
    {'name': 'Ev Temizliği', 'duration': null, 'price': '600 TL'},
    {'name': 'Ofis Temizliği', 'duration': null, 'price': 'Teklif Alın'},
    {'name': 'İnşaat Sonrası Temizlik', 'duration': null, 'price': 'Teklif Alın'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '08:00 - 18:00'}],
  address: 'Merkez Mah. Temizlik Sok. No:3, İzmir',
  lat: 38.4237, lng: 27.1428,
  phone: '05556667788', whatsapp: '905556667788',
  formBuilder: (d) => CleaningCompanyFormScreen(initialData: d),
);

final demoDrivingSchool = _bizDemo(
  title: 'Sürücü Kursu',
  emoji: '🚗', from: '#f59e0b', to: '#fde68a',
  name: 'Güvenli Sürücü Kursu',
  tagline: 'Direksiyona ilk günden güvenle geçin',
  services: const [
    {'name': 'B Sınıfı Ehliyet', 'duration': null, 'price': '9.500 TL'},
    {'name': 'A2 Sınıfı Ehliyet', 'duration': null, 'price': '7.000 TL'},
    {'name': 'Direksiyon Tazeleme', 'duration': '10 saat', 'price': '2.000 TL'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '09:00 - 19:00'}],
  address: 'Okul Caddesi No:22, Konya',
  lat: 37.8746, lng: 32.4932,
  phone: '05557778899', whatsapp: '905557778899',
  formBuilder: (d) => DrivingSchoolFormScreen(initialData: d),
);

final demoElectrician = _bizDemo(
  title: 'Elektrikçi',
  emoji: '💡', from: '#eab308', to: '#fef08a',
  name: 'Volt Elektrik Tesisat',
  tagline: '7/24 acil elektrik ve tesisat hizmeti',
  services: const [
    {'name': 'Arıza Tespiti', 'duration': null, 'price': '300 TL'},
    {'name': 'Tesisat Yenileme', 'duration': null, 'price': 'Teklif Alın'},
    {'name': 'Aydınlatma Montajı', 'duration': null, 'price': '250 TL'},
  ],
  workingHours: const [{'day': 'Her gün', 'range': '7/24 Acil Servis'}],
  address: 'Sanayi Cad. No:9, Kayseri',
  lat: 38.7312, lng: 35.4787,
  phone: '05558889900', whatsapp: '905558889900',
  formBuilder: (d) => ElectricianFormScreen(initialData: d),
);

final demoFlorist = _bizDemo(
  title: 'Çiçekçi',
  emoji: '💐', from: '#ec4899', to: '#f9a8d4',
  name: 'Çiçek Bahçesi',
  tagline: 'Her anınız için taze çiçekler',
  services: const [
    {'name': 'Buket', 'duration': null, 'price': '350 TL'},
    {'name': 'Orkide', 'duration': null, 'price': '450 TL'},
    {'name': 'Yıldönümü Aranjmanı', 'duration': null, 'price': '750 TL'},
  ],
  workingHours: const [{'day': 'Her gün', 'range': '09:00 - 21:00'}],
  address: 'Çiçekçiler Çarşısı No:5, Eskişehir',
  lat: 39.7767, lng: 30.5206,
  phone: '05559990011', whatsapp: '905559990011', instagram: 'cicekbahcesi',
  schemaType: 'Florist',
  formBuilder: (d) => FloristFormScreen(initialData: d),
);

final demoFurnitureDecor = _bizDemo(
  title: 'Mobilyacı / Dekorasyon',
  emoji: '🛋️', from: '#78716c', to: '#d6d3d1',
  name: 'Ev Hali Mobilya',
  tagline: 'Evinize dokunuşunuzu katın',
  services: const [
    {'name': 'Oturma Grubu', 'duration': null, 'price': '18.000 TL'},
    {'name': 'Yemek Odası Takımı', 'duration': null, 'price': '22.000 TL'},
    {'name': 'İç Mekan Danışmanlığı', 'duration': null, 'price': '1.500 TL'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '10:00 - 20:00'}],
  address: 'Mobilyacılar Sitesi No:14, Kocaeli',
  lat: 40.8533, lng: 29.8815,
  phone: '05551110022', whatsapp: '905551110022', instagram: 'evhalimobilya',
  schemaType: 'FurnitureStore',
  formBuilder: (d) => FurnitureDecorFormScreen(initialData: d),
);

final demoGenericBusiness = _bizDemo(
  title: 'Genel İşletme',
  emoji: '🏢', from: '#6d5efc', to: '#a78bfa',
  name: 'İşletmem',
  tagline: 'Kaliteli hizmet, güvenilir iletişim',
  services: const [
    {'name': 'Hizmet 1', 'duration': null, 'price': 'Teklif Alın'},
    {'name': 'Hizmet 2', 'duration': null, 'price': 'Teklif Alın'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cuma', 'range': '09:00 - 18:00'}],
  address: 'Merkez Mah. No:1, İstanbul',
  lat: 41.0082, lng: 28.9784,
  phone: '05550001122', whatsapp: '905550001122',
  formBuilder: (d) => GenericBusinessFormScreen(initialData: d),
);

final demoHandyman = _bizDemo(
  title: 'Tadilatçı',
  emoji: '🛠️', from: '#a16207', to: '#fbbf24',
  name: 'Usta Elden Tadilat',
  tagline: 'Küçük tamirden büyük tadilata',
  services: const [
    {'name': 'Boya Badana', 'duration': null, 'price': 'm² başına 60 TL'},
    {'name': 'Tesisat Tamiri', 'duration': null, 'price': '400 TL'},
    {'name': 'Mobilya Montajı', 'duration': null, 'price': '300 TL'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '08:00 - 20:00'}],
  address: 'Zafer Mah. Tadilat Sok. No:6, Antalya',
  lat: 36.8969, lng: 30.7133,
  phone: '05552223344', whatsapp: '905552223344',
  formBuilder: (d) => HandymanFormScreen(initialData: d),
);

final demoKindergarten = _bizDemo(
  title: 'Anaokulu / Kreş',
  emoji: '🧸', from: '#38bdf8', to: '#fbcfe8',
  name: 'Minik Adımlar Anaokulu',
  tagline: 'Çocuğunuzun ilk mutlu adımları burada',
  services: const [
    {'name': 'Tam Gün Kreş', 'duration': null, 'price': 'Aylık 6.500 TL'},
    {'name': 'Yarım Gün Anaokulu', 'duration': null, 'price': 'Aylık 4.000 TL'},
    {'name': 'Etüt Programı', 'duration': null, 'price': 'Aylık 1.500 TL'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cuma', 'range': '07:30 - 18:30'}],
  address: 'Çocuk Bahçesi Sok. No:11, Eskişehir',
  lat: 39.7767, lng: 30.5206,
  phone: '05553335566', whatsapp: '905553335566',
  schemaType: 'ChildCare',
  formBuilder: (d) => KindergartenFormScreen(initialData: d),
);

final demoMassageSpa = _bizDemo(
  title: 'Masaj / Spa',
  emoji: '🧖', from: '#14b8a6', to: '#99f6e4',
  name: 'Huzur Spa & Wellness',
  tagline: 'Bedeninize ve zihninize bir mola',
  services: const [
    {'name': 'İsveç Masajı', 'duration': '60 dk', 'price': '900 TL'},
    {'name': 'Sıcak Taş Masajı', 'duration': '75 dk', 'price': '1.200 TL'},
    {'name': 'Aromaterapi', 'duration': '45 dk', 'price': '750 TL'},
  ],
  workingHours: const [{'day': 'Her gün', 'range': '10:00 - 21:00'}],
  address: 'Yalı Cad. No:19, Muğla',
  lat: 37.2153, lng: 28.3636,
  phone: '05554446677', whatsapp: '905554446677', instagram: 'huzurspa',
  schemaType: 'DaySpa',
  formBuilder: (d) => MassageSpaFormScreen(initialData: d),
);

final demoMovingCompany = _bizDemo(
  title: 'Nakliyat',
  emoji: '🚚', from: '#f97316', to: '#fdba74',
  name: 'Güven Nakliyat',
  tagline: 'Eşyalarınız bizimle güvende',
  services: const [
    {'name': 'Evden Eve Nakliyat', 'duration': null, 'price': 'Teklif Alın'},
    {'name': 'Ofis Taşımacılığı', 'duration': null, 'price': 'Teklif Alın'},
    {'name': 'Eşya Depolama', 'duration': null, 'price': 'Aylık 500 TL'},
  ],
  workingHours: const [{'day': 'Her gün', 'range': '07:00 - 22:00'}],
  address: 'Nakliyeciler Sitesi No:3, Gaziantep',
  lat: 37.0662, lng: 37.3833,
  phone: '05555557788', whatsapp: '905555557788',
  schemaType: 'MovingCompany',
  formBuilder: (d) => MovingCompanyFormScreen(initialData: d),
);

final demoPetGrooming = _bizDemo(
  title: 'Pet Kuaförü',
  emoji: '🐾', from: '#84cc16', to: '#d9f99d',
  name: 'Patili Dostlar Kuaförü',
  tagline: 'Dostunuz için özenli bakım',
  services: const [
    {'name': 'Yıkama & Kurutma', 'duration': '45 dk', 'price': '350 TL'},
    {'name': 'Tam Bakım (Tıraş+Tırnak)', 'duration': '90 dk', 'price': '600 TL'},
    {'name': 'Tırnak Kesimi', 'duration': '15 dk', 'price': '150 TL'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '09:00 - 19:00'}],
  address: 'Hayvan Dostları Sok. No:7, Adana',
  lat: 37.0000, lng: 35.3213,
  phone: '05556668899', whatsapp: '905556668899', instagram: 'patilidostlar',
  schemaType: 'PetGroomer',
  formBuilder: (d) => PetGroomingFormScreen(initialData: d),
);

final demoTailor = _bizDemo(
  title: 'Terzi',
  emoji: '🧵', from: '#7c3aed', to: '#c4b5fd',
  name: 'Zarif Terzi Atölyesi',
  tagline: 'Tam ölçünüze, tam zevkinize',
  services: const [
    {'name': 'Takım Elbise Dikimi', 'duration': null, 'price': '3.500 TL'},
    {'name': 'Kısaltma / Daraltma', 'duration': null, 'price': '150 TL'},
    {'name': 'Gelinlik Tadilatı', 'duration': null, 'price': '800 TL'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '09:00 - 19:00'}],
  address: 'Terziler Çarşısı No:2, Bursa',
  lat: 40.1826, lng: 29.0665,
  phone: '05557779900', whatsapp: '905557779900',
  formBuilder: (d) => TailorFormScreen(initialData: d),
);

// ---------------------------------------------------------------------------
// Kafe ailesi (generateCafeHtml) — Fırın/Pastane, Restoran/Lokanta
// ---------------------------------------------------------------------------

final demoBakery = _cafeDemo(
  title: 'Fırın / Pastane',
  emoji: '🥐', from: '#d97706', to: '#fed7aa',
  name: 'Ekmek Teknesi Fırın',
  tagline: 'Her sabah taze, her lokma özenli',
  menuCategories: const [
    {
      'title': 'Ekmekler',
      'items': [
        {'name': 'Ekşi Maya Ekmek', 'description': 'Günlük taze', 'price': '80 TL'},
        {'name': 'Tam Buğday', 'description': null, 'price': '70 TL'},
      ],
    },
    {
      'title': 'Pastalar',
      'items': [
        {'name': 'Çikolatalı Pasta', 'description': 'Dilim', 'price': '120 TL'},
      ],
    },
  ],
  workingHours: const [{'day': 'Her gün', 'range': '06:00 - 20:00'}],
  address: 'Fırıncılar Sok. No:4, Sakarya',
  lat: 40.7569, lng: 30.3781,
  phone: '05558881122', whatsapp: '905558881122', instagram: 'ekmektekesi',
  schemaType: 'Bakery',
  formBuilder: (d) => BakeryFormScreen(initialData: d),
);

final demoRestaurant = _cafeDemo(
  title: 'Restoran / Lokanta',
  emoji: '🍽️', from: '#b91c1c', to: '#fca5a5',
  name: 'Lezzet Sofrası',
  tagline: 'Ev yapımı tatlar, sıcak bir sofra',
  menuCategories: const [
    {
      'title': 'Ana Yemekler',
      'items': [
        {'name': 'Izgara Köfte', 'description': 'Pilav ve salata ile', 'price': '280 TL'},
        {'name': 'Tavuk Şiş', 'description': null, 'price': '250 TL'},
      ],
    },
    {
      'title': 'Tatlılar',
      'items': [
        {'name': 'Künefe', 'description': null, 'price': '180 TL'},
      ],
    },
  ],
  workingHours: const [{'day': 'Her gün', 'range': '11:00 - 23:00'}],
  address: 'Lezzet Sokağı No:1, Gaziantep',
  lat: 37.0662, lng: 37.3833,
  phone: '05559993344', whatsapp: '905559993344', instagram: 'lezzetsofrasi',
  formBuilder: (d) => RestaurantFormScreen(initialData: d),
);

// ---------------------------------------------------------------------------
// Klinik ailesi (generateClinicHtml) — Diş Hekimi, Diyetisyen, Avukat,
// Veteriner
// ---------------------------------------------------------------------------

final demoDentist = _clinicDemo(
  title: 'Diş Hekimi',
  emoji: '🦷', from: '#0891b2', to: '#a5f3fc',
  businessName: 'Gülüş Diş Polikliniği',
  roleTitle: 'Diş Hekimi',
  tagline: 'Sağlıklı ve güzel bir gülüş için',
  services: const [
    {'name': 'Diş Beyazlatma', 'duration': null, 'price': '2.500 TL'},
    {'name': 'İmplant', 'duration': null, 'price': '8.000 TL'},
    {'name': 'Ortodonti (Tel Tedavisi)', 'duration': null, 'price': 'Teklif Alın'},
  ],
  practitioner: {
    'name': 'Dr. Mert Aydın',
    'title': 'Diş Hekimi',
    'photoUrl': _demoCover('🦷', from: '#0891b2', to: '#a5f3fc'),
    'bio': 'Estetik diş hekimliği alanında 10 yıllık deneyime sahiptir.',
    'credentials': const [
      {'label': 'Ege Üniversitesi Diş Hekimliği Fakültesi'},
    ],
  },
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '09:00 - 18:00'}],
  address: 'Sağlık Cad. No:15, İzmir',
  lat: 38.4237, lng: 27.1428,
  phone: '05551234400', whatsapp: '905551234400',
  formBuilder: (d) => DentistFormScreen(initialData: d),
);

final demoDietitian = _clinicDemo(
  title: 'Diyetisyen',
  emoji: '🥗', from: '#65a30d', to: '#d9f99d',
  businessName: 'Dengeli Yaşam Diyet Danışmanlığı',
  roleTitle: 'Diyetisyen',
  tagline: 'Size özel, sürdürülebilir beslenme planı',
  services: const [
    {'name': 'İlk Değerlendirme', 'duration': '60 dk', 'price': '800 TL'},
    {'name': 'Aylık Takip Paketi', 'duration': null, 'price': '2.500 TL'},
    {'name': 'Online Danışmanlık', 'duration': '30 dk', 'price': '500 TL'},
  ],
  practitioner: {
    'name': 'Dyt. Ceren Kaya',
    'title': 'Diyetisyen',
    'photoUrl': _demoCover('🥗', from: '#65a30d', to: '#d9f99d'),
    'bio': 'Kişiye özel beslenme programlarıyla sağlıklı yaşamı destekler.',
    'credentials': const [
      {'label': 'Hacettepe Üniversitesi Beslenme ve Diyetetik'},
    ],
  },
  workingHours: const [{'day': 'Pazartesi - Cuma', 'range': '10:00 - 18:00'}],
  address: 'Yaşam Cad. No:21, Ankara',
  lat: 39.9208, lng: 32.8541,
  phone: '05552234400', whatsapp: '905552234400',
  formBuilder: (d) => DietitianFormScreen(initialData: d),
);

final demoLawyer = _clinicDemo(
  title: 'Avukat / Hukuk Bürosu',
  emoji: '⚖️', from: '#1e3a8a', to: '#93c5fd',
  businessName: 'Adalet Hukuk Bürosu',
  roleTitle: 'Avukat',
  tagline: 'Haklarınız için güvenilir danışmanlık',
  services: const [
    {'name': 'Aile Hukuku Danışmanlığı', 'duration': null, 'price': 'Teklif Alın'},
    {'name': 'Ticaret Hukuku', 'duration': null, 'price': 'Teklif Alın'},
    {'name': 'İcra & İflas Takibi', 'duration': null, 'price': 'Teklif Alın'},
  ],
  practitioner: {
    'name': 'Av. Selin Demir',
    'title': 'Avukat',
    'photoUrl': _demoCover('⚖️', from: '#1e3a8a', to: '#93c5fd'),
    'bio': '15 yıllık deneyimiyle aile ve ticaret hukuku alanlarında hizmet verir.',
    'credentials': const [
      {'label': 'İstanbul Barosu'},
    ],
  },
  workingHours: const [{'day': 'Pazartesi - Cuma', 'range': '09:00 - 18:00'}],
  address: 'Adliye Cad. No:30, İstanbul',
  lat: 41.0082, lng: 28.9784,
  phone: '05553234400', whatsapp: '905553234400',
  formBuilder: (d) => LawyerFormScreen(initialData: d),
);

final demoVeterinarian = _clinicDemo(
  title: 'Veteriner',
  emoji: '🐶', from: '#0d9488', to: '#5eead4',
  businessName: 'Dost Veteriner Kliniği',
  roleTitle: 'Veteriner Hekim',
  tagline: 'Dostlarınızın sağlığı bizim önceliğimiz',
  services: const [
    {'name': 'Genel Muayene', 'duration': '20 dk', 'price': '400 TL'},
    {'name': 'Aşılama', 'duration': '15 dk', 'price': '250 TL'},
    {'name': 'Kısırlaştırma', 'duration': null, 'price': 'Teklif Alın'},
  ],
  practitioner: {
    'name': 'Vet. Hek. Onur Şahin',
    'title': 'Veteriner Hekim',
    'photoUrl': _demoCover('🐶', from: '#0d9488', to: '#5eead4'),
    'bio': 'Küçük ve büyükbaş hayvan sağlığında 8 yıllık deneyime sahiptir.',
    'credentials': const [
      {'label': 'Ankara Üniversitesi Veteriner Fakültesi'},
    ],
  },
  workingHours: const [{'day': 'Her gün', 'range': '09:00 - 20:00'}],
  address: 'Hayvan Sağlığı Sok. No:8, Antalya',
  lat: 36.8969, lng: 30.7133,
  phone: '05554234400', whatsapp: '905554234400',
  formBuilder: (d) => VeterinarianFormScreen(initialData: d),
);

// ---------------------------------------------------------------------------
// Extended-business ailesi (generateExtendedBusinessSiteHtml) — Güzellik
// Salonu (öncesi/sonrası), Fitness (program)
// ---------------------------------------------------------------------------

final demoBeautySalon = _extendedDemo(
  title: 'Güzellik Salonu',
  emoji: '💅', from: '#db2777', to: '#f9a8d4',
  businessName: 'Bella Güzellik Salonu',
  slogan: 'Kendinizi özel hissedin',
  packages: const [
    {
      'title': 'Cilt Bakım Paketi',
      'sessionLabel': '3 Seans',
      'price': '1.800 TL',
      'originalPrice': '2.400 TL',
      'includedServices': ['Temizlik', 'Peeling', 'Maske'],
      'note': null,
      'isFeatured': true,
    },
    {
      'title': 'Manikür & Pedikür',
      'sessionLabel': null,
      'price': '450 TL',
      'originalPrice': null,
      'includedServices': ['Manikür', 'Pedikür'],
      'note': null,
      'isFeatured': false,
    },
  ],
  beforeAfterGallery: [
    {'url': _demoCover('💅', from: '#db2777', to: '#f9a8d4'), 'caption': 'Öncesi'},
    {'url': _demoCover('✨', from: '#db2777', to: '#f9a8d4'), 'caption': 'Sonrası'},
  ],
  workingHours: const [{'day': 'Pazartesi - Cumartesi', 'range': '09:00 - 20:00'}],
  address: 'Güzellik Cad. No:17, İstanbul',
  lat: 41.0082, lng: 28.9784,
  phone: '05555234400', whatsapp: '905555234400',
  schemaType: 'BeautySalon',
  formBuilder: (d) => BeautySalonFormScreen(initialData: d),
);

final demoFitness = _extendedDemo(
  title: 'Fitness Stüdyosu',
  emoji: '🏋️', from: '#dc2626', to: '#fca5a5',
  businessName: 'Güç Fitness Stüdyosu',
  slogan: 'Hedeflerinize birlikte ulaşalım',
  packages: const [
    {
      'title': 'Aylık Üyelik',
      'sessionLabel': null,
      'price': '1.200 TL',
      'originalPrice': null,
      'includedServices': ['Sınırsız Giriş', 'Grup Dersleri'],
      'note': null,
      'isFeatured': true,
    },
    {
      'title': 'Kişisel Antrenman Paketi',
      'sessionLabel': '10 Seans',
      'price': '3.500 TL',
      'originalPrice': null,
      'includedServices': ['Birebir Antrenörlük'],
      'note': null,
      'isFeatured': false,
    },
  ],
  schedule: const [
    {'day': 'Pazartesi', 'time': '18:00', 'className': 'Fonksiyonel Antrenman', 'trainer': 'Kaan'},
    {'day': 'Çarşamba', 'time': '19:00', 'className': 'Yoga', 'trainer': 'Ece'},
  ],
  workingHours: const [{'day': 'Her gün', 'range': '07:00 - 23:00'}],
  address: 'Spor Cad. No:25, İstanbul',
  lat: 41.0082, lng: 28.9784,
  phone: '05556234400', whatsapp: '905556234400',
  schemaType: 'SportsActivityLocation',
  formBuilder: (d) => FitnessFormScreen(initialData: d),
);

// ---------------------------------------------------------------------------
// Portfolyo ailesi (generatePortfolioHtml) — Makyaj Sanatçısı, Müzisyen/DJ,
// Kişisel Antrenör, Fotoğrafçı, genel Portfolyo
// ---------------------------------------------------------------------------

final demoMakeupArtist = _portfolioDemo(
  title: 'Makyaj Sanatçısı',
  emoji: '💄', from: '#e11d48', to: '#fda4af',
  name: 'Deniz Yıldız',
  roleTitle: 'Makyaj Sanatçısı',
  tagline: 'Her yüze özel bir dokunuş',
  aboutText: 'Gelin makyajından editoryal çekimlere, 7 yıldır her tarzda çalışıyorum.',
  skills: const ['Gelin Makyajı', 'Editoryal', 'Kaş Tasarımı'],
  contactEmail: 'info@denizyildizmakeup.com',
  formBuilder: (d) => MakeupArtistFormScreen(initialData: d),
);

final demoMusicianDj = _portfolioDemo(
  title: 'Müzisyen / DJ',
  emoji: '🎧', from: '#7c3aed', to: '#f472b6',
  name: 'DJ Kerem',
  roleTitle: 'DJ / Prodüktör',
  tagline: 'Etkinliğinizin ritmi bizde',
  aboutText: 'Düğün, konsept parti ve kurumsal etkinliklerde 200+ performans deneyimi.',
  skills: const ['Düğün Organizasyonu', 'Prodüksiyon', 'Ses Sistemi Kurulumu'],
  contactEmail: 'booking@djkerem.com',
  formBuilder: (d) => MusicianDjFormScreen(initialData: d),
);

final demoPersonalTrainer = _portfolioDemo(
  title: 'Kişisel Antrenör',
  emoji: '💪', from: '#ea580c', to: '#fdba74',
  name: 'Burak Kaya',
  roleTitle: 'Kişisel Antrenör',
  tagline: 'Hedeflerinize özel program',
  aboutText: 'Kilo verme ve kas kazanımı programlarında 6 yıllık deneyime sahibim.',
  skills: const ['Kişiye Özel Program', 'Online Koçluk', 'Beslenme Desteği'],
  contactEmail: 'burak@antrenor.com',
  formBuilder: (d) => PersonalTrainerFormScreen(initialData: d),
);

final demoPhotographer = _portfolioDemo(
  title: 'Fotoğrafçı',
  emoji: '📷', from: '#334155', to: '#94a3b8',
  name: 'Elif Arslan',
  roleTitle: 'Fotoğrafçı',
  tagline: 'Anlarınızı ölümsüzleştiriyorum',
  aboutText: 'Düğün, doğum günü ve kurumsal çekimlerde 9 yıllık tecrübe.',
  skills: const ['Düğün Fotoğrafçılığı', 'Portre', 'Drone Çekimi'],
  contactEmail: 'elif@elifarslanfoto.com',
  formBuilder: (d) => PhotographerFormScreen(initialData: d),
);

final demoPortfolio = _portfolioDemo(
  title: 'Portfolyo',
  emoji: '🎨', from: '#6366f1', to: '#a5b4fc',
  name: 'Ada Yılmaz',
  roleTitle: 'Grafik Tasarımcı',
  tagline: 'Fikirlerinizi görsele dönüştürüyorum',
  aboutText: 'Marka kimliği ve dijital tasarım alanında 5 yıllık serbest çalışma deneyimi.',
  skills: const ['Marka Kimliği', 'UI Tasarım', 'İllüstrasyon'],
  contactEmail: 'ada@adayilmaz.design',
  formBuilder: (d) => PortfolioFormScreen(initialData: d),
);

// ---------------------------------------------------------------------------
// Tekil şablonlar (kendi generator'ları var, gruplanamıyor)
// ---------------------------------------------------------------------------

/// generateBioLinkHtml — sadece themeId alıyor, font/density yok (bkz.
/// TemplateDemoConfig.showTypography).
final TemplateDemoConfig demoBioLink = TemplateDemoConfig(
  title: 'Biyo Link Sayfası',
  showTypography: false,
  buildHtml: ({required themeId, required fontPackageId, required density}) => generateBioLinkHtml(
    name: 'Ada Yılmaz',
    bio: 'İçerik üreticisi • Tasarımcı • Kahve tutkunu ☕',
    avatarUrl: _demoCover('👤', from: '#6d5efc', to: '#a78bfa'),
    links: const [
      {'title': 'Portfolyomu İncele', 'url': 'https://example.com'},
      {'title': 'YouTube Kanalım', 'url': 'https://youtube.com'},
      {'title': 'Bana Ulaşın', 'url': 'https://example.com/contact'},
    ],
    socials: const [
      {'platform': 'Instagram', 'url': 'https://instagram.com'},
      {'platform': 'TikTok', 'url': 'https://tiktok.com'},
    ],
    themeId: themeId,
  ),
  openForm: ({required themeId, required fontPackageId, required density}) => BioLinkFormScreen(
    initialData: {'selectedTheme': themeId},
  ),
);

/// generateBusinessCardHtml — sadece themeId alıyor, font/density yok.
final TemplateDemoConfig demoBusinessCard = TemplateDemoConfig(
  title: 'Dijital Kartvizit',
  showTypography: false,
  buildHtml: ({required themeId, required fontPackageId, required density}) => generateBusinessCardHtml(
    name: 'Kaan Öztürk',
    title: 'Kurucu Ortak',
    company: 'Öztürk Danışmanlık',
    tagline: 'İş fikirlerinizi büyütüyoruz',
    phone: '05551239900',
    email: 'kaan@ozturkdanismanlik.com',
    address: 'Levent, İstanbul',
    website: 'https://ozturkdanismanlik.com',
    avatarUrl: _demoCover('👤', from: '#1e293b', to: '#64748b'),
    socials: const [
      {'platform': 'LinkedIn', 'url': 'https://linkedin.com'},
      {'platform': 'Instagram', 'url': 'https://instagram.com'},
    ],
    themeId: themeId,
  ),
  openForm: ({required themeId, required fontPackageId, required density}) => BusinessCardFormScreen(
    initialData: {'selectedTheme': themeId},
  ),
);

/// generateRealEstateSite — Map<String,String> (çok sayfalı: index.html +
/// her ilan için ayrı detay sayfası) döner. Ön izlemede sadece ana ilan
/// listesi sayfasını (index.html) gösteriyoruz — detay sayfasına geçiş bu
/// basit ön izlemenin kapsamı dışında (gerçek formda zaten çalışıyor).
final TemplateDemoConfig demoRealEstate = TemplateDemoConfig(
  title: 'Emlak Sitesi',
  buildHtml: ({required themeId, required fontPackageId, required density}) {
    final files = generateRealEstateSite(
      agentName: 'Yılmaz Gayrimenkul',
      agentLogo: _demoCover('🏠', from: '#1d4ed8', to: '#93c5fd'),
      tagline: 'Hayalinizdeki eve giden yol',
      agentPhone: '05551237700',
      agentWhatsapp: '905551237700',
      agentCoverImage: _demoCover('🏠', from: '#1d4ed8', to: '#93c5fd'),
      listings: [
        {
          'id': '1',
          'title': 'Deniz Manzaralı 3+1 Daire',
          'coverImage': _demoCover('🏠', from: '#1d4ed8', to: '#93c5fd'),
          'price': 4200000,
          'm2': 140,
          'roomLabel': '3+1',
          'locationTag': 'Kadıköy',
          'floor': 4,
          'aidat': 1200,
          'description': 'Deniz manzaralı, güneş gören, yeni yapılı bina.',
          'address': 'Kadıköy, İstanbul',
          'lat': 40.9908,
          'lng': 29.0269,
          'gallery': _demoGallery('🏠', from: '#1d4ed8', to: '#93c5fd'),
        },
        {
          'id': '2',
          'title': 'Bahçeli Müstakil Ev',
          'coverImage': _demoCover('🏡', from: '#1d4ed8', to: '#93c5fd'),
          'price': 6800000,
          'm2': 220,
          'roomLabel': '4+1',
          'locationTag': 'Beykoz',
          'floor': null,
          'aidat': null,
          'description': 'Geniş bahçeli, sakin bir sokakta müstakil ev.',
          'address': 'Beykoz, İstanbul',
          'lat': 41.1258,
          'lng': 29.0938,
          'gallery': _demoGallery('🏡', from: '#1d4ed8', to: '#93c5fd'),
        },
      ],
      themeId: themeId,
      fontPackageId: fontPackageId,
      density: density,
    );
    return files['index.html']!;
  },
  openForm: ({required themeId, required fontPackageId, required density}) => RealEstateFormScreen(
    initialData: {
      'selectedTheme': themeId,
      'fontPackageId': fontPackageId,
      'typeDensity': density,
    },
  ),
);
