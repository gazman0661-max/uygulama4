import '../models/site_project.dart';
import '../templates/html/extra_page_blocks.dart' show encodeExtraPageBlocks;
import 'qt_form_data_codec.dart';

bool canConvertToFreeSite(ProjectKind? kind) {
  if (kind == null) return false;
  switch (kind) {
    case ProjectKind.site:
    case ProjectKind.qrCode:
    case ProjectKind.bioLink:
    case ProjectKind.businessCard:
    case ProjectKind.realEstate:
    case ProjectKind.freeSite:
      return false;
    default:
      return true;
  }
}

String _s(Map<String, dynamic> d, List<String> keys) {
  for (final k in keys) {
    final v = d[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

List<Map<String, String?>> _imgs(Map<String, dynamic> d, List<String> keys) {
  for (final k in keys) {
    if (d[k] == null) continue;
    final list = qtDecodeNullableStringMapList(d[k])
        .where((m) => (m['url'] ?? '').isNotEmpty)
        .toList();
    if (list.isNotEmpty) return list;
  }
  return [];
}

List<Map<String, String>> _faqItems(String raw) {
  final out = <Map<String, String>>[];
  for (final line in raw.split('\n')) {
    final l = line.trim();
    if (l.isEmpty || !l.contains('|')) continue;
    final parts = l.split('|');
    final q = parts.first.trim();
    final a = parts.sublist(1).join('|').trim();
    if (q.isNotEmpty && a.isNotEmpty) out.add({'question': q, 'answer': a});
  }
  return out;
}

Map<String, dynamic>? convertSectorToFreeSiteData(
  ProjectKind? kind,
  Map<String, dynamic>? d,
) {
  if (d == null || !canConvertToFreeSite(kind)) return null;

  final name = _s(d, ['nameCtrl', 'businessNameCtrl', 'agentNameCtrl']);
  final tagline = _s(d, ['taglineCtrl']);
  final about = _s(d, ['aboutCtrl', 'bioCtrl']);
  final services = _s(d, ['servicesCtrl']);
  final faq = _faqItems(_s(d, ['faqCtrl']));
  final reviewLines = _s(d, ['testimonialsCtrl']);
  final videoUrl = _s(d, ['videoUrlCtrl']);
  final address = _s(d, ['addressCtrl']);
  final lat = d['lat'];
  final lng = d['lng'];
  final cover = _imgs(d, ['cover', 'photo']);
  final gallery = _imgs(d, ['gallery']);
  final hours = d['workingHours'];
  final hasHours = hours is List && hours.isNotEmpty;

  final blocks = <Map<String, dynamic>>[
    {
      'type': 'hero',
      'heading': '',
      'tagline': tagline,
      'images': cover,
      'action': _s(d, ['whatsappCtrl']).isNotEmpty ? 'whatsapp' : 'call',
      'label': '',
      'url': '',
    },
    if (about.isNotEmpty) {'type': 'text', 'heading': '', 'body': about},
    if (services.isNotEmpty) {'type': 'services', 'heading': '', 'lines': services},
    if (gallery.isNotEmpty)
      {
        'type': 'gallery',
        'heading': '',
        'images': gallery,
        'style': (d['galleryStyle'] as String?) ?? 'grid',
      },
    if (videoUrl.isNotEmpty)
      {
        'type': 'video',
        'heading': '',
        'url': videoUrl,
        'orientation': (d['videoOrientation'] as String?) ?? 'landscape',
      },
    if (hasHours) {'type': 'hours', 'heading': '', 'hours': hours},
    if (reviewLines.isNotEmpty)
      {
        'type': 'reviews',
        'heading': '',
        'lines': reviewLines,
        'consent': (d['testimonialsConsent'] as bool?) ?? false,
      },
    if (faq.isNotEmpty) {'type': 'faq', 'heading': '', 'items': faq},
    if (address.isNotEmpty && lat is num && lng is num)
      {'type': 'map', 'heading': '', 'address': address, 'lat': lat, 'lng': lng},
    {
      'type': 'contact',
      'heading': '',
      'leadForm': (d['includeLeadForm'] as bool?) ?? true,
    },
  ];

  return {
    'includeLeadForm': (d['includeLeadForm'] as bool?) ?? true,
    'nameCtrl': name,
    'phoneCtrl': _s(d, ['phoneCtrl']),
    'whatsappCtrl': _s(d, ['whatsappCtrl']),
    'instagramCtrl': _s(d, ['instagramCtrl']),
    'googleReviewCtrl': _s(d, ['googleReviewCtrl']),
    if (d['selectedTheme'] != null) 'selectedTheme': d['selectedTheme'],
    if (d['customTheme'] != null) 'customTheme': d['customTheme'],
    if (d['customFontPackage'] != null) 'customFontPackage': d['customFontPackage'],
    if (d['heroLayoutStyle'] != null) 'heroLayoutStyle': d['heroLayoutStyle'],
    if (d['fontPackageId'] != null) 'fontPackageId': d['fontPackageId'],
    if (d['typeDensity'] != null) 'typeDensity': d['typeDensity'],
    if (d['siteLang'] != null) 'siteLang': d['siteLang'],
    'multiPage': false,
    if (d['logo'] != null) 'logo': d['logo'],
    'homeBlocks': encodeExtraPageBlocks(blocks),
    'extraPages': <Map<String, String>>[],
  };
}
