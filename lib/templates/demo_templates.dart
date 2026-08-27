import 'package:flutter/widgets.dart';
import '../screens/kuafor_form_screen.dart';
import '../screens/kafe_form_screen.dart';
import '../screens/clinic_form_screen.dart';
import 'html/kuafor_html_generator.dart';
import 'html/cafe_html_generator.dart';
import 'html/clinic_html_generator.dart';

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
}

/// Örnek görseller — placehold.co'nun düz gri "yazı kutusu" görünümü ön
/// izlemede ikna edici durmuyordu (bkz. kullanıcı geri bildirimi,
/// 27.08.2026). picsum.photos sabit bir seed ile GERÇEK (rastgele ama o
/// seed için hep AYNI) fotoğraflar veriyor — her şablon kendi seed'iyle
/// farklı, tutarlı bir görsel setine sahip oluyor.
String _demoCover(String seed) => 'https://picsum.photos/seed/$seed/1200/800';
List<Map<String, String?>> _demoGallery(String seed) => List.generate(
      3,
      (i) => {'url': 'https://picsum.photos/seed/$seed-$i/600/400', 'caption': null},
    );

final TemplateDemoConfig demoKuafor = TemplateDemoConfig(
  title: 'Kuaför / Berber',
  buildHtml: ({required themeId, required fontPackageId, required density}) => generateBusinessSiteHtml(
    name: 'Ayşe Kuaför',
    coverImage: _demoCover('kuafor'),
    tagline: 'Şehrin en şık saç ve bakım stüdyosu',
    services: const [
      {'name': 'Saç Kesimi', 'duration': '30 dk', 'price': '250 TL'},
      {'name': 'Saç Boyama', 'duration': '90 dk', 'price': '900 TL'},
      {'name': 'Sakal Tıraşı', 'duration': '20 dk', 'price': '150 TL'},
    ],
    gallery: _demoGallery('kuafor'),
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
    coverImage: _demoCover('kafe'),
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
    gallery: _demoGallery('kafe'),
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
    photoUrl: _demoCover('klinik'),
    tagline: 'Gülüşünüz bizim işimiz',
    services: const [
      {'name': 'Diş Beyazlatma', 'duration': null, 'price': '2.500 TL'},
      {'name': 'İmplant', 'duration': null, 'price': '8.000 TL'},
      {'name': 'Kanal Tedavisi', 'duration': null, 'price': '1.800 TL'},
    ],
    practitioner: {
      'name': 'Dr. Elif Yeşil',
      'title': 'Diş Hekimi',
      'photoUrl': _demoCover('klinik-doktor'),
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
