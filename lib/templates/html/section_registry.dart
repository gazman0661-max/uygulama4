library section_registry;

const List<String> kBusinessSiteDefaultOrder = [
  'about',
  'services',
  'products',
  'gallery',
  'video',
  'hours',
  'testimonials',
  'faq',
  'map',
];

const List<String> kGenericBusinessDefaultOrder = [
  'about',
  'services',
  'products',
  'gallery',
  'video',
  'hours',
  'map',
];

const List<String> kCafeDefaultOrder = [
  'about',
  'menu',
  'gallery',
  'video',
  'hours',
  'testimonials',
  'faq',
  'map',
];

const List<String> kCafeMultiPageHomeDefaultOrder = [
  'about',
  'menu',
  'hours',
  'video',
  'testimonials',
  'faq',
  'map',
];

const List<String> kClinicDefaultOrder = [
  'about',
  'services',
  'gallery',
  'team',
  'video',
  'hours',
  'testimonials',
  'faq',
  'map',
];

const List<String> kClinicMultiPageHomeDefaultOrder = [
  'about',
  'services',
  'gallery',
  'video',
  'hours',
  'map',
];

const List<String> kPortfolioDefaultOrder = [
  'works',
  'timeline',
  'testimonials',
  'faq',
];

const List<String> kExtendedBusinessDefaultOrder = [
  'about',
  'services',
  'packages',
  'schedule',
  'gallery',
  'team',
  'video',
  'hours',
  'map',
];

const List<String> kRealEstateDefaultOrder = [
  'testimonials',
  'faq',
];

const Map<String, Map<String, String>> kSectionLabels = {
  'about': {'tr': 'Hakkımızda', 'en': 'About'},
  'services': {'tr': 'Hizmetler', 'en': 'Services'},
  'products': {'tr': 'Ürünler', 'en': 'Products'},
  'gallery': {'tr': 'Galeri', 'en': 'Gallery'},
  'video': {'tr': 'Video', 'en': 'Video'},
  'hours': {'tr': 'Çalışma Saatleri', 'en': 'Working Hours'},
  'testimonials': {'tr': 'Yorumlar', 'en': 'Testimonials'},
  'faq': {'tr': 'Sık Sorulan Sorular', 'en': 'FAQ'},
  'map': {'tr': 'Harita / Konum', 'en': 'Map / Location'},
  'menu': {'tr': 'Menü', 'en': 'Menu'},
  'team': {'tr': 'Ekip / Uzman Profili', 'en': 'Team / Practitioner'},
  'works': {'tr': 'İş Örnekleri', 'en': 'Portfolio'},
  'timeline': {'tr': 'Deneyim & Eğitim', 'en': 'Experience & Education'},
  'packages': {'tr': 'Paketler', 'en': 'Packages'},
  'schedule': {'tr': 'Program', 'en': 'Schedule'},
};

String sectionLabel(String id, String lang) =>
    kSectionLabels[id]?[lang == 'en' ? 'en' : 'tr'] ?? id;
