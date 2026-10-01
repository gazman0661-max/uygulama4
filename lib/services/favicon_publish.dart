final RegExp _iconLinkRe = RegExp(
  r'<link rel="icon" type="image/svg\+xml" href="data:image/svg\+xml,([^"]*)">',
);

const String faviconPublishPath = 'favicon.svg';
const String faviconLinkPublished =
    '<link rel="icon" type="image/svg+xml" href="/favicon.svg">';

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
    return out;
  }
  if (!svg.startsWith('<svg')) return out;

  out[faviconPublishPath] = svg;
  for (final k in htmlKeys) {
    out[k] = out[k]!.replaceAll(_iconLinkRe, faviconLinkPublished);
  }
  return out;
}
