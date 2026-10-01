import 'shared_html_blocks.dart';

String generateBioLinkHtml({
  required String name,
  required String bio,
  required String avatarUrl,
  required List<Map<String, String>> links,
  required List<Map<String, String>> socials,
  String themeId = 'clean_light',
  Map<String, String>? customTheme,
  String fontPackageId = 'modern_sade',
  Map<String, String>? customFontPackage,
  String density = 'normal',
  String lang = 'tr',
}) {
  final theme = _resolveBioLinkTheme(themeId, customTheme);
  final fonts = resolveFontPackage(fontPackageId, customFontPackage);
  final headingWeight = typeDensityOf(density)['headingWeight']!;

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
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="${fonts['googleFontsHref']}">
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:${fonts['body']}; ${theme['background']!} min-height:100vh; }
  html, body { max-width:100%; overflow-x:clip; }
  .bl-card, .bl-card * { min-width:0; overflow-wrap:anywhere; word-break:break-word; }
  .bl-card, .bl-wrap { max-width:100%; }
  .bl-wrap { display:flex; justify-content:center; padding: 40px 16px; }
  .bl-card { max-width: 420px; width:100%; text-align:center; }
  .bl-avatar { width:88px; height:88px; border-radius:50%; object-fit:cover; margin-bottom:16px; }
  .bl-name { font-family:${fonts['heading']}; font-size:20px; font-weight:$headingWeight; color:${theme['text']}; margin-bottom:6px; }
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

Map<String, String> _resolveBioLinkTheme(String? themeId, Map<String, String>? customTheme) {
  if (customTheme == null || customTheme.isEmpty) {
    return _themes[themeId] ?? _themes['clean_light']!;
  }
  final base = _themes['clean_light']!;
  final bg = customTheme['bg'] ?? '#F8F9FA';
  final text = customTheme['text'] ?? base['text']!;
  final accent = customTheme['accent'] ?? '#3D5AFE';
  final cardBg = customTheme['cardBg'] ?? '#FFFFFF';
  return {
    'background': 'background:$bg;',
    'text': text,
    'subtext': customTheme['subtext'] ?? text,
    'btnBg': cardBg,
    'btnText': accent,
    'btnBorder': hexToRgba(text, 0.12),
    'radius': base['radius']!,
  };
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
