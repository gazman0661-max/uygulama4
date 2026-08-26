/// Uygulama genelinde AI özelliklerinin açık/kapalı olduğunu kontrol eden
/// TEK merkezi bayrak.
///
/// Bu proje, orijinal Sitora uygulamasının "AI Sohbet" kısmının bağımsız
/// derlemesidir — dolayısıyla burada `true`: AI Chat ile sıfırdan site
/// üretme ve AI ile düzenleme (EditScreen > "✨ AI"; PreviewScreen'in
/// AI'lı sürümü) her zaman açık. Kapatmak isterseniz `false` yapabilirsiniz,
/// ama o zaman ilgili butonlar (edit_screen.dart, preview_screen.dart)
/// UI'dan gizlenir.
///
/// NOT: Worker tarafında (cloudflare/worker/src/index.mjs) buna karşılık
/// gelen bir değişiklik gerekmiyor — worker zaten sadece çağrılınca
/// çalışıyor, bu bayrak yalnızca istemci tarafındaki giriş noktalarını
/// açıp kapatıyor.
class AppConfig {
  AppConfig._();

  static const bool aiEditingEnabled = true;

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
