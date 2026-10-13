/// 20.09.2026 eklendi — Google İşletme Profili Kurulum Sihirbazı'nın SAF
/// (Flutter/AppState'e bağımlı olmayan) yardımcıları. Ayrı dosyada durmalarının
/// tek sebebi test edilebilmeleri (bkz. test/gbp_helpers_test.dart) — arayüz
/// widgets/gbp_setup_wizard.dart'ta.

const Map<String, String> _dayEn = {
  'Pazartesi': 'Monday',
  'Salı': 'Tuesday',
  'Çarşamba': 'Wednesday',
  'Perşembe': 'Thursday',
  'Cuma': 'Friday',
  'Cumartesi': 'Saturday',
  'Pazar': 'Sunday',
};

/// Çalışma saatlerini satır satır düz metne çevirir ("Pazartesi: 09:00 - 19:00").
/// Kapalı günler (range == null) "Kapalı"/"Closed" olur.
String gbpFormatHours(List<Map<String, String?>>? hours, {required bool en}) {
  if (hours == null || hours.isEmpty) return '';
  final lines = <String>[];
  for (final row in hours) {
    final day = row['day'];
    if (day == null || day.trim().isEmpty) continue;
    final range = row['range'];
    final dayLabel = en ? (_dayEn[day] ?? day) : day;
    final value = (range == null || range.trim().isEmpty)
        ? (en ? 'Closed' : 'Kapalı')
        : range.trim();
    lines.add('$dayLabel: $value');
  }
  return lines.join('\n');
}

/// Kullanıcının yapıştırdığı metinden yorum linkini çıkarır: içinde başka
/// yazı varsa ilk http(s) adresini alır, şemasız yapıştırılmışsa https ekler,
/// http'yi https'e yükseltir.
String gbpNormalizeReviewLink(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  final m = RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(s);
  if (m != null) {
    s = m.group(0)!;
  } else if (!s.contains('://')) {
    s = 'https://$s';
  }
  if (s.toLowerCase().startsWith('http://')) {
    s = 'https://${s.substring(7)}';
  }
  return s;
}

/// null = geçerli. 'scheme' = geçerli bir https adresi değil, 'host' = Google'a
/// ait bir adres değil (yanlışlıkla başka bir link yapıştırılmasını engeller).
String? gbpReviewLinkProblem(String normalized) {
  if (normalized.contains(' ')) return 'scheme';
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return 'scheme';
  final h = uri.host.toLowerCase();
  final ok = h == 'g.page' ||
      h == 'g.co' ||
      h == 'goo.gl' ||
      h == 'maps.app.goo.gl' ||
      h == 'google.com' ||
      h.endsWith('.google.com');
  return ok ? null : 'host';
}

/// Link bir "yorum formu" linkine benziyor mu (g.page/r/…/review veya
/// search.google.com/local/writereview?…). Benzemiyorsa (ör. harita linki)
/// yine kaydedilir ama kullanıcı uyarılır.
bool gbpLooksLikeReviewLink(String normalized) {
  final l = normalized.toLowerCase();
  return l.contains('/review') || l.contains('writereview');
}
