/// Uygulama genelinde bazı özelliklerin açık/kapalı olduğunu kontrol eden
/// merkezi bayraklar.
class AppConfig {
  AppConfig._();

  /// "Kendi domainimi bağla" özelliğinin UI'da AKTİF olup olmadığı.
  ///
  /// 05.09.2026 GÜNCELLENDİ (kanka isteği) — `true` yapıldı: istemci
  /// tarafı artık hazır (satın alma akışı — bkz. billing_constants.dart >
  /// kProductConnectDomain, widgets/domain_purchase_sheet.dart — ve
  /// domain_connect_screen.dart kuruldu). AMA BU BAYRAK TEK BAŞINA
  /// ÖZELLİĞİ ÇALIŞTIRMAZ: worker tarafında CF_API_TOKEN/CF_ZONE_ID henüz
  /// GİRİLMEDİ (bkz. cloudflare/worker/wrangler.toml) — bu secret'lar
  /// tanımlanana kadar worker /api/domains/* uçlarında 501 dönmeye devam
  /// eder, yani kullanıcı ödemeyi yapar ama DomainService.connect worker'a
  /// ulaştığında hata alır (ödeme zaten domainConnectPurchasePending ile
  /// korunduğu için kaybolmaz, secret'lar girilip worker deploy edildikten
  /// SONRA aynı ödeme ile tekrar denenebilir — bkz.
  /// AppState.hasPendingDomainConnectPurchase). Bu yüzden worker
  /// tarafındaki secret kurulumu bitmeden bu bayrağı canlıya (Play
  /// Console'a yüklenecek bir sürümde) taşımamak lazım — HostingConfig.
  /// isConfigured zaten worker hiç deploy edilmediyse "aktif değil"
  /// ekranını gösteriyor ama secret'lar eksik + worker deploy edilmiş bir
  /// ara durumda kullanıcı gerçek bir 501 hatasıyla karşılaşabilir.
  ///
  /// Buton (Projelerim ekranındaki 🌐 ikonu) zaten hep görünürdü — bu
  /// bayrak sadece worker'a hiç istek atılmadan "şu an aktif değil"
  /// ekranını gösterip göstermeyeceğini belirliyordu (bkz.
  /// domain_connect_screen.dart > build).
  static const bool domainConnectEnabled = true;

  /// Sitora'nın Google Play Store sayfası.
  ///
  /// Kullanım yerleri:
  ///  - WatermarkService: yayınlanan sitelerdeki "Sitora ile üretildi"
  ///    rozetine tıklanınca bu sayfa açılır (rozet ziyaretçi -> yeni
  ///    kullanıcı dönüşüm kanalı).
  ///  - ReviewService: gerekirse (in-app review kullanılamadığında)
  ///    doğrudan mağaza sayfasına yönlendirme için fallback.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.sitora.ai';

  /// Firebase proje kimliği (Console URL'indeki `project/<BURASI>`).
  ///
  /// GİZLİ DEĞİL — Firestore REST API'ye anonim (ziyaretçi) yazma için
  /// üretilen HTML'lerin İÇİNE bu ID gömülür (bkz.
  /// templates/html/shared_html_blocks.dart > leadFormScriptSnippet).
  /// Güvenlik API anahtarından değil, Firestore Security Rules'tan gelir
  /// (bkz. FIREBASE_SETUP.md > "leads" koleksiyonu kuralları) — bu yüzden
  /// projeId'nin açık HTML'de görünmesi risk oluşturmaz, Google Maps API
  /// anahtarsız iframe gömme ile aynı güvenlik modeli.
  static const String firebaseProjectId = 'sitora-a9e27';
}
