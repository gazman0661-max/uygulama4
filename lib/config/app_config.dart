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
/// NOT: Artık Cloudflare Worker YOK — tüm AI istekleri doğrudan
/// GeminiService üzerinden, kullanıcının Ayarlar'da girdiği kendi API
/// anahtarıyla Gemini'ye gider (bkz. lib/services/gemini_service.dart).
class AppConfig {
  AppConfig._();

  static const bool aiEditingEnabled = true;
}
