/// 15.09.2026 eklendi (kanka isteği) — "Bölüm Sırala/Gizle" özelliği.
///
/// Sorun: her generator (bkz. kuafor_html_generator.dart,
/// cafe_html_generator.dart, clinic_html_generator.dart,
/// portfolio_html_generator.dart, extended_business_html_generator.dart,
/// generic_business_html_generator.dart) ORTA blokları (Galeri, SSS,
/// Harita, Çalışma Saatleri vb.) sabit bir sırada, if-zinciriyle
/// yazıyordu. Artık her generator, `List<String>? sectionOrder`
/// parametresi alıyor ve orta blokları o listeye göre diziyor —
/// listede olmayan bir id o sitede hiç render edilmez (gizlenir).
///
/// SINIR (KASITLI): Hero (en üst) ve İletişim/Talep Formu (en alt) bu
/// listelerde YOK — sabit kalıyor. Kullanıcı yanlışlıkla iletişim
/// bölümünü ortaya taşıyıp ya da gizleyip sitesini "müşteri bana nasıl
/// ulaşacak" durumuna düşüremesin diye. Aynı şekilde kafe/klinik/emlak/
/// genel işletmenin ÇOK SAYFA modu (generateCafeSite, generateClinicSite,
/// generateRealEstateSite, generateGenericBusinessSite'ın extraPages'i)
/// bu özelliğin KAPSAMI DIŞINDA — o modda sayfalar arası sabit bir gezinme
/// yapısı var (menu.html, randevu.html gibi), bölüm sıralamak yerine
/// "hangi sayfa" sorusu devreye giriyor; ayrı bir iş.
///
/// Yeni bir generator'a bu özelliği eklerken:
/// 1) O generator'ın mevcut body.writeln sırasını buraya bir
///    "...DefaultOrder" sabiti olarak kopyala (hero/contact HARİÇ).
/// 2) Yeni id'lerin tr/en etiketini kSectionLabels'a ekle.
/// 3) Generator fonksiyonuna `List<String>? sectionOrder` parametresi
///    ekle, if-zincirini bir `Map<String, String? Function()>` + for
///    döngüsüne çevir (canlı örnek: kuafor_html_generator.dart).
library section_registry;

/// generateBusinessSiteHtml (kuafor_html_generator.dart) — kuaför, oto
/// yıkama, temizlik şirketi, sürücü kursu, çiçekçi, mobilya/dekorasyon,
/// tadilatçı (handyman), anaokulu, masaj/spa, nakliyat şirketi, evcil
/// hayvan bakımı, terzi, elektrikçi, butik otel + "Genel İşletme"nin tek
/// sayfa modu (~16 sektör) tarafından kullanılır.
const List<String> kBusinessSiteDefaultOrder = [
  'about',
  'services',
  'gallery',
  'video',
  'hours',
  'testimonials',
  'faq',
  'map',
];

/// generateGenericBusinessSite (generic_business_html_generator.dart) —
/// "Genel İşletme" formunun index.html'i (ek sayfalar bu listeden
/// BAĞIMSIZ, ayrıca eklenir).
const List<String> kGenericBusinessDefaultOrder = [
  'about',
  'services',
  'gallery',
  'video',
  'hours',
  'map',
];

/// generateCafeHtml (cafe_html_generator.dart, TEK sayfa modu) — kafe,
/// restoran, fırın/pastane. 'menu' hem menü kartlarını hem (varsa) QR
/// menü butonunu birlikte temsil eder — ikisi görsel olarak bitişik
/// olduğu için ayrı id'ye bölünmedi.
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

/// 15.09.2026 eklendi (kanka isteği) — generateCafeSite (ÇOK sayfa modu,
/// SADECE index.html'in orta blokları). Galeri burada YOK (o, ayrı bir
/// gallery.html sayfası — sayfa/nav sırası bu özelliğin kapsamı DIŞINDA,
/// bkz. DEGISIKLIKLER_15_09_2026_COK_SAYFA_ANA_SAYFA.md).
const List<String> kCafeMultiPageHomeDefaultOrder = [
  'about',
  'menu',
  'hours',
  'video',
  'testimonials',
  'faq',
  'map',
];

/// generateClinicHtml (clinic_html_generator.dart, TEK sayfa modu) —
/// klinik, diş hekimi, veteriner, diyetisyen, avukat (~5 sektör).
/// NOT: bu ailede 'about'/'gallery' parametresi YOK (services + team
/// profili üzerinden anlatılıyor) — kBusinessSiteDefaultOrder'dan farklı.
const List<String> kClinicDefaultOrder = [
  'services',
  'team',
  'video',
  'hours',
  'testimonials',
  'faq',
  'map',
];

/// 15.09.2026 eklendi (kanka isteği) — generateClinicSite (ÇOK sayfa modu,
/// SADECE index.html'in orta blokları). 'team'/'testimonials'/'faq' burada
/// YOK (onlar hizmetler.html'de) — kClinicDefaultOrder'dan farklı.
const List<String> kClinicMultiPageHomeDefaultOrder = [
  'services',
  'video',
  'hours',
  'map',
];

/// generatePortfolioHtml (portfolio_html_generator.dart, TEK sayfa modu)
/// — fotoğrafçı, makyaj sanatçısı, müzisyen/DJ, kişisel antrenör,
/// portfolyo (~5 sektör). NOT: 'about' burada hero'nun hemen altında
/// SABİT (beceri çipleriyle birleşik yazılıyor) — hero/contact gibi
/// reorder listesinde YOK. 15.09.2026: generatePortfolioSite'ın (ÇOK
/// sayfa modu) index.html'i de AYNI id/sıra setini kullanıyor — orada da
/// 'about' hero'nun altında sabit, works/timeline/testimonials/faq aynı
/// şekilde sıralanabilir; bu yüzden ayrı bir "MultiPage" sabitine gerek
/// yok, bu liste ikisinde de geçerli.
const List<String> kPortfolioDefaultOrder = [
  'works',
  'timeline',
  'testimonials',
  'faq',
];

/// generateExtendedBusinessSiteHtml (extended_business_html_generator.dart)
/// — güzellik salonu, fitness (~2 sektör). 'gallery' id'si duruma göre
/// öncesi/sonrası VEYA normal galeriyi temsil eder (ikisi aynı anda
/// gösterilmiyor, orijinal kodda da öyleydi).
const List<String> kExtendedBusinessDefaultOrder = [
  'services',
  'packages',
  'schedule',
  'gallery',
  'team',
  'video',
  'hours',
  'map',
];

/// Bölüm id -> {tr, en} etiket. Sadece SectionOrderField (form UI)
/// içinde gösterilir; sitedeki gerçek başlık metinleri (ör. "Hizmetlerimiz"
/// vs "Uzmanlık Alanları") yine ilgili generator'ın kendi mantığından
/// gelir, buradan ETKİLENMEZ.
const Map<String, Map<String, String>> kSectionLabels = {
  'about': {'tr': 'Hakkımızda', 'en': 'About'},
  'services': {'tr': 'Hizmetler', 'en': 'Services'},
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
