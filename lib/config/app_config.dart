/// Uygulama genelinde bazı özelliklerin açık/kapalı olduğunu kontrol eden
/// merkezi bayraklar.
class AppConfig {
  AppConfig._();

  /// "Kendi domainimi bağla" özelliğinin UI'da AKTİF olup olmadığı.
  ///
  /// Şu an `false` — worker tarafında CF_API_TOKEN/CF_ZONE_ID henüz
  /// girilmedi (bkz. cloudflare/worker/wrangler.toml), yani worker zaten
  /// /api/domains/* uçlarında 501 dönüyor. Bu bayrak, kullanıcı butona
  /// tıkladığı anda (worker'a hiç istek atmadan) "şu an aktif değil"
  /// ekranını göstermek için var — böylece kullanıcı domain'ini yazıp
  /// "Bağla"ya bastıktan SONRA hata almak yerine, en baştan net bir bilgi
  /// görüyor (bkz. domain_connect_screen.dart > build).
  ///
  /// Buton (Projelerim ekranındaki 🌐 ikonu) BİLEREK gizlenmedi — özelliğin
  /// var olduğunu kullanıcıya göstermek, ilgiyi ölçmek ve ileride hiçbir
  /// şey öğrenmesine gerek kalmadan aynı butonu kullanabilmesini sağlamak
  /// için görünür tutuluyor.
  ///
  /// CF_API_TOKEN/CF_ZONE_ID Cloudflare tarafında tanımlanıp özellik gerçekten
  /// açılacağı zaman: bunu `true` yap. Worker tarafında BAŞKA HİÇBİR
  /// değişiklik gerekmiyor — worker zaten hazır, sadece secret'lar eksik.
  static const bool domainConnectEnabled = false;

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
