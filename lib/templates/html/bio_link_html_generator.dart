import 'shared_html_blocks.dart';

/// biolink paketindeki BioLinkProfile/BioLinkTheme'in yerel HTML karşılığı.
/// Widget tarafındaki 5 hazır tema burada CSS değişkeni olarak taşınıyor,
/// böylece tema seçici ekranındaki id'lerle (clean_light, midnight_dark,
/// sunset_gradient, neon_cyber, soft_pastel) birebir eşleşiyor.
String generateBioLinkHtml({
  required String name,
  required String bio,
  required String avatarUrl,
  required List<Map<String, String>> links, // {title, url}
  required List<Map<String, String>> socials, // {platform, url}
  String themeId = 'clean_light',
  String lang = 'tr',
}) {
  final theme = _themes[themeId] ?? _themes['clean_light']!;

  final linkButtons = links.map((l) {
    return '<a class="bl-link" href="${escapeHtml(l['url'] ?? '')}" target="_blank">${escapeHtml(l['title'] ?? '')}</a>';
  }).join('\n');

  final socialIcons = socials.map((s) {
    return '<a class="bl-social" href="${escapeHtml(s['url'] ?? '')}" target="_blank">${escapeHtml(s['platform'] ?? '')}</a>';
  }).join('\n');

  final body = '''
<div class="bl-wrap">
  <div class="bl-card">
    <img class="bl-avatar" src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(name)}">
    <h1 class="bl-name">${escapeHtml(name)}</h1>
    <p class="bl-bio">${escapeHtml(bio.length > 100 ? bio.substring(0, 100) : bio)}</p>
    <div class="bl-links">
$linkButtons
    </div>
    ${socials.isNotEmpty ? '<div class="bl-socials">\n$socialIcons\n    </div>' : ''}
  </div>
</div>''';

  final seoHtml = seoMetaHtml(
    pageTitle: name,
    description: bio,
    ogImage: avatarUrl,
    schemaType: 'ProfilePage',
  );

  return '''
<!DOCTYPE html>
<html lang="$lang">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(name)}</title>
$seoHtml
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:-apple-system, Roboto, sans-serif; ${theme['background']!} min-height:100vh; }
  .bl-wrap { display:flex; justify-content:center; padding: 40px 16px; }
  .bl-card { max-width: 420px; width:100%; text-align:center; }
  .bl-avatar { width:88px; height:88px; border-radius:50%; object-fit:cover; margin-bottom:16px; }
  .bl-name { font-size:20px; font-weight:700; color:${theme['text']}; margin-bottom:6px; }
  .bl-bio { font-size:14px; color:${theme['subtext']}; margin-bottom:24px; }
  .bl-links { display:flex; flex-direction:column; gap:12px; }
  .bl-link { display:block; padding:14px; border-radius:${theme['radius']}; background:${theme['btnBg']}; color:${theme['btnText']}; text-decoration:none; font-weight:600; border:1.5px solid ${theme['btnBorder']}; }
  .bl-socials { display:flex; justify-content:center; gap:16px; margin-top:20px; }
  .bl-social { color:${theme['text']}; text-decoration:none; font-size:13px; }
</style>
</head>
<body>
$body
</body>
</html>''';
}

const Map<String, Map<String, String>> _themes = {
  'clean_light': {
    'background': 'background:#F8F9FA;',
    'text': '#212529', 'subtext': '#6C757D',
    'btnBg': '#FFFFFF', 'btnText': '#212529', 'btnBorder': '#E9ECEF',
    'radius': '30px',
  },
  'midnight_dark': {
    'background': 'background:#0F172A;',
    'text': '#FFFFFF', 'subtext': '#94A3B8',
    'btnBg': '#1E293B', 'btnText': '#FFFFFF', 'btnBorder': '#334155',
    'radius': '12px',
  },
  'sunset_gradient': {
    'background': 'background:linear-gradient(135deg,#FF512F,#DD2476);',
    'text': '#FFFFFF', 'subtext': 'rgba(255,255,255,0.7)',
    'btnBg': '#FFFFFF', 'btnText': '#DD2476', 'btnBorder': 'transparent',
    'radius': '30px',
  },
  'neon_cyber': {
    'background': 'background:#0A0A0C;',
    'text': '#00FFCC', 'subtext': 'rgba(255,255,255,0.7)',
    'btnBg': '#121216', 'btnText': '#00FFCC', 'btnBorder': '#00FFCC',
    'radius': '2px',
  },
  'soft_pastel': {
    'background': 'background:linear-gradient(180deg,#A1C4FD,#C2E9FB);',
    'text': '#2C3E50', 'subtext': '#7F8C8D',
    'btnBg': '#FFFFFF', 'btnText': '#2C3E50', 'btnBorder': 'transparent',
    'radius': '12px',
  },
};
