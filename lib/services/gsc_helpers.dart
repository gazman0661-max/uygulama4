/// 20.09.2026 eklendi — Google Search Console doğrulama kodunun SAF (Flutter'a
/// bağımlı olmayan) yardımcıları; test edilebilsin diye ayrı dosyada
/// (bkz. test/gsc_helpers_test.dart). Arayüz: widgets/search_console_sheet.dart.
///
/// Worker'daki whitelist ile AYNI kalıp (bkz. cloudflare/worker/src/index.mjs >
/// GOOGLE_VERIFICATION_CODE_RE). Burada da kontrol edilmesinin sebebi kullanıcıya
/// gidiş-dönüş yapmadan anında geri bildirim verebilmek.
final RegExp _gscCodeRe = RegExp(r'^[A-Za-z0-9_-]{10,150}$');

/// Kullanıcının yapıştırdığı metinden doğrulama kodunu (`content` değeri) çıkarır.
/// Kabul edilen biçimler:
///  - sadece kod:  `abc123_XYZ-...`
///  - tam etiket:  `<meta name="google-site-verification" content="abc123..." />`
///  - sadece content parçası: `content="abc123..."`
/// Geçerli bir kod bulunamazsa `null` döner (boş metin dahil).
String? gscExtractCode(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final m = RegExp('content\\s*=\\s*["\']([^"\']+)["\']', caseSensitive: false)
      .firstMatch(s);
  if (m != null) {
    s = m.group(1)!.trim();
  } else {
    // Tırnak/boşlukla sarılmış çıplak kod ("abc...") yapıştırılmış olabilir.
    s = s.replaceAll(RegExp('^["\'\\s]+|["\'\\s]+\$'), '');
  }
  return _gscCodeRe.hasMatch(s) ? s : null;
}
