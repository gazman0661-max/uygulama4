/// Uygulama genelinde AI özelliklerinin açık/kapalı olduğunu kontrol eden
/// TEK merkezi bayrak.
///
/// Şu an `false` — AI Chat ile sıfırdan site üretme (bkz. home_screen.dart
/// > _MainTab.chat, _buildModeToggle) ve AI ile düzenleme (tam kod:
/// EditScreen > "✨ AI"; bölüm/arka plan: PreviewScreen'in AI'lı sürümü)
/// TAMAMEN kapalı — ilgili ekranlara/butonlara giden hiçbir yol UI'da
/// render edilmiyor, dolayısıyla worker'daki AI uçlarına (WorkerService.
/// generateSiteCode/generateMultiPageSite/editFullCode/editSection/
/// editBackground) hiçbir şekilde istek gitmiyor.
///
/// Form/Hızlı Araçlar akışı (QuickToolsPreviewScreen, local_generation_
/// helper.dart) bu bayraktan HİÇ etkilenmez — o zaten AI kullanmıyor,
/// bu bayrak sadece "AI Chat + AI ile düzenleme" ikilisini kontrol eder.
///
/// İleride Pro özelliği olarak geri açmak istenirse:
///   - En basit hali: `static const bool aiEditingEnabled = true;`
///   - Aboneliğe bağlamak istersen: bunu `static bool aiEditingEnabled(
///     AppState state) => state.isPro;` gibi bir metoda çevirip kullanan
///     yerleri (home_screen.dart, edit_screen.dart, preview_screen.dart)
///     ona göre güncelle.
///
/// NOT: Worker tarafında (cloudflare/worker/src/index.mjs) buna karşılık
/// gelen bir değişiklik YAPILMADI ve gerekmiyor — worker zaten sadece
/// çağrılınca çalışıyor, bu bayrak yalnızca istemci tarafındaki giriş
/// noktalarını açıp kapatıyor.
class AppConfig {
  AppConfig._();

  static const bool aiEditingEnabled = false;

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
}
