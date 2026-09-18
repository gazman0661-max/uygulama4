import 'shared_html_blocks.dart';

/// businesscard paketinin HTML karşılığı. QR kod için gömülü bir kütüphane
/// kullanmıyoruz (bağımsız kalması için) — bunun yerine ücretsiz
/// bir QR üretim servisinin img endpoint'i kullanılıyor (api.qrserver.com,
/// key gerektirmez). Uygulama içi qr_generator_screen.dart zaten
/// qr_flutter paketiyle native QR üretiyorsa, o üretilen PNG'yi
/// [qrImageUrl] olarak (data URI ya da yüklenmiş dosya yolu) geçirip
/// bu satırı değiştirebilirsin.
String generateBusinessCardHtml({
  required String name,
  required String title,
  String? company,
  String? tagline,
  required String phone,
  String? email,
  String? address,
  String? website,
  String? avatarUrl,
  required List<Map<String, String>> socials, // {platform, url}
  String? qrImageUrl,
  String themeId = 'clean_light',
  Map<String, String>? customTheme, // 17.09.2026 eklendi ('Özel Tema' B seçeneği)
  // 18.09.2026 eklendi (kanka isteği) — business_card_form_screen.dart
  // artık TypographyPickerField gösteriyor; bkz. shared_html_blocks.dart
  // -> [fontPackageOf]/[resolveFontPackage].
  String fontPackageId = 'modern_sade',
  Map<String, String>? customFontPackage, // 18.09.2026 eklendi ('Serbest Font Seçimi')
  String density = 'normal',
  String lang = 'tr',
}) {
  final theme = resolveTheme(themeId, customTheme);
  final fonts = resolveFontPackage(fontPackageId, customFontPackage);
  final headingWeight = typeDensityOf(density)['headingWeight']!;
  final socialIcons = socials
      .map((s) => '<a class="bl-social" href="${escapeHtml(s['url'] ?? '')}" target="_blank">${escapeHtml(s['platform'] ?? '')}</a>')
      .join('\n');

  final avatarHtml = avatarUrl != null
      ? '<img class="bl-avatar" src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(name)}">'
      : '';

  final contactRows = StringBuffer();
  contactRows.writeln('<a class="card-contact-row" href="tel:${escapeHtml(phone)}">📞 ${escapeHtml(phone)}</a>');
  if (email != null) {
    contactRows.writeln('<a class="card-contact-row" href="mailto:${escapeHtml(email)}">✉️ ${escapeHtml(email)}</a>');
  }
  if (address != null) {
    contactRows.writeln('<a class="card-contact-row" target="_blank" href="https://maps.google.com/?q=${Uri.encodeComponent(address)}">📍 ${escapeHtml(address)}</a>');
  }
  if (website != null) {
    contactRows.writeln('<a class="card-contact-row" target="_blank" href="${escapeHtml(website)}">🌐 ${escapeHtml(website)}</a>');
  }

  final qrHtml = qrImageUrl != null
      ? '<img class="card-qr" src="${escapeHtml(qrImageUrl)}" alt="QR">'
      : '';

  final seoHtml = seoMetaHtml(
    pageTitle: name,
    description: tagline ?? (company != null ? '$title · $company' : title),
    ogImage: avatarUrl,
    schemaType: 'Person',
  );

  final body = '''
<div class="bl-wrap">
  <div class="bl-card card-shadow">
    $avatarHtml
    <h1 class="bl-name">${escapeHtml(name)}</h1>
    <p class="card-title">${escapeHtml(title)}${company != null ? ' · ${escapeHtml(company)}' : ''}</p>
    ${tagline != null ? '<p class="bl-bio">${escapeHtml(tagline)}</p>' : ''}
    <div class="card-contact-list">
      $contactRows
    </div>
    ${socials.isNotEmpty ? '<div class="bl-socials">\n$socialIcons\n    </div>' : ''}
    ${vcardSectionHtml(name: name, title: title, company: company, phone: phone, email: email, lang: lang)}
    $qrHtml
  </div>
</div>''';

  return '''
<!DOCTYPE html>
<html lang="$lang">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(name)}</title>
$seoHtml
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="${fonts['googleFontsHref']}">
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:${fonts['body']}; background:${theme['bg']}; min-height:100vh; }
  .bl-wrap { display:flex; justify-content:center; padding: 40px 16px; }
  .bl-card { max-width: 400px; width:100%; text-align:center; background:${theme['cardBg']}; border-radius:20px; padding:32px 24px; }
  .card-shadow { box-shadow: 0 8px 24px rgba(0,0,0,0.06); }
  .bl-avatar { width:88px; height:88px; border-radius:50%; object-fit:cover; margin-bottom:16px; }
  .bl-name { font-family:${fonts['heading']}; font-size:20px; font-weight:$headingWeight; color:${theme['text']}; margin-bottom:4px; }
  .card-title { font-size:14px; color:${theme['accent']}; font-weight:600; margin-bottom:10px; }
  .bl-bio { font-size:13px; color:${theme['subtext']}; margin-bottom:20px; }
  .card-contact-list { display:flex; flex-direction:column; gap:10px; text-align:left; margin-bottom:16px; }
  .card-contact-row { color:${theme['text']}; text-decoration:none; font-size:14px; padding:10px 14px; background:${theme['chipBg']}; border-radius:10px; }
  .bl-socials { display:flex; justify-content:center; gap:16px; margin: 16px 0; }
  .bl-social { color:${theme['text']}; text-decoration:none; font-size:13px; }
  .vcard-btn { display:inline-block; padding:12px 24px; border-radius:10px; background:${theme['accent']}; color:${theme['accentText']}; text-decoration:none; font-weight:700; margin-top:8px; }
  .card-qr { width:120px; height:120px; margin-top:20px; }
</style>
</head>
<body>
$body
</body>
</html>''';
}
