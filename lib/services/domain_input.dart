const Set<String> _multiLabelPublicSuffixes = {
  'com.tr', 'net.tr', 'org.tr', 'gen.tr', 'biz.tr', 'info.tr', 'web.tr', 'av.tr', 'dr.tr',
  'bel.tr', 'k12.tr', 'edu.tr', 'gov.tr', 'name.tr', 'tv.tr', 'tel.tr', 'bbs.tr', 'pol.tr',
  'kep.tr', 'co.uk', 'org.uk', 'me.uk', 'com.au', 'net.au', 'org.au', 'co.nz', 'co.za',
  'com.br', 'com.mx', 'co.in', 'co.jp', 'com.cn', 'com.sg', 'com.hk',
};

String cleanDomainInput(String raw) {
  var value = raw.trim().toLowerCase();
  value = value.replaceFirst(RegExp(r'^[a-z]+://'), '');
  value = value.replaceFirst(RegExp(r'[/?#].*$'), '');
  value = value.replaceFirst(RegExp(r':\d+$'), '');
  value = value.replaceAll(RegExp(r'\s+'), '');
  value = value.replaceAll(RegExp(r'\.+$'), '');
  return value;
}

bool isApexDomainInput(String domain) {
  final labels = domain.split('.').where((l) => l.isNotEmpty).toList();
  if (labels.length < 2) return false;
  final lastTwo = labels.sublist(labels.length - 2).join('.');
  final baseLabelCount = _multiLabelPublicSuffixes.contains(lastTwo) ? 3 : 2;
  return labels.length == baseLabelCount;
}

String normalizeDomainInput(String raw) {
  final cleaned = cleanDomainInput(raw);
  if (cleaned.isEmpty) return cleaned;
  return isApexDomainInput(cleaned) ? 'www.$cleaned' : cleaned;
}
