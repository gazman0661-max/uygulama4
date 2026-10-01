final RegExp _gscCodeRe = RegExp(r'^[A-Za-z0-9_-]{10,150}$');

String? gscExtractCode(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final m = RegExp('content\\s*=\\s*["\']([^"\']+)["\']', caseSensitive: false)
      .firstMatch(s);
  if (m != null) {
    s = m.group(1)!.trim();
  } else {
    s = s.replaceAll(RegExp('^["\'\\s]+|["\'\\s]+\$'), '');
  }
  return _gscCodeRe.hasMatch(s) ? s : null;
}
