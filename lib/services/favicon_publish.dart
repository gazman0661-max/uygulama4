/// 28.09.2026 eklendi (kanka isteği) — favicon'u yayında gerçek dosya yap.
///
/// Sayfalardaki favicon data URI olarak gömülü (editör/önizleme/ZIP için
/// ideal). Ama Google arama sonuçları favicon'u crawl edilebilir bir URL'den
/// okur; data URI çoğunlukla görünmez. Bu yüzden YAYIN kopyasında:
///  1) index.html'deki (yoksa ilk .html) data URI ikon çözülüp `favicon.svg`
///     dosyası olarak eklenir,
///  2) tüm .html dosyalarındaki data URI ikon bağlantısı `/favicon.svg`
///     ile değiştirilir (site genelinde tek ikon — alt sayfalarda harf
///     değişmez).
/// Saf Dart (Flutter/http bağımlılığı yok) — birim testlenebilir.
final RegExp _iconLinkRe = RegExp(
  r'<link rel="icon" type="image/svg\+xml" href="data:image/svg\+xml,([^"]*)">',
);

const String faviconPublishPath = 'favicon.svg';
const String faviconLinkPublished =
    '<link rel="icon" type="image/svg+xml" href="/favicon.svg">';

/// [files] (yol -> içerik) map'inin yeni bir kopyasını döndürür. Uygun ikon
/// bulunamazsa ya da `favicon.svg` zaten varsa girdiyi olduğu gibi (kopya)
/// döndürür.
Map<String, String> externalizeFavicon(Map<String, String> files) {
  final out = Map<String, String>.from(files);
  if (out.containsKey(faviconPublishPath)) return out;

  final htmlKeys =
      out.keys.where((k) => k.toLowerCase().endsWith('.html')).toList();
  if (htmlKeys.isEmpty) return out;

  final indexKey = out.containsKey('index.html') ? 'index.html' : htmlKeys.first;
  final match = _iconLinkRe.firstMatch(out[indexKey]!);
  if (match == null) return out;

  String svg;
  try {
    svg = Uri.decodeComponent(match.group(1)!);
  } catch (_) {
    return out; // bozuk kodlama: gömülü kalsın, yayın bozulmasın
  }
  if (!svg.startsWith('<svg')) return out;

  out[faviconPublishPath] = svg;
  for (final k in htmlKeys) {
    out[k] = out[k]!.replaceAll(_iconLinkRe, faviconLinkPublished);
  }
  return out;
}
