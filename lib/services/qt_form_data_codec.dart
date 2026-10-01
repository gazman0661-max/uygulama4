library qt_form_data_codec;

List<Map<String, dynamic>>? qtDecodeMapList(dynamic raw) {
  if (raw is! List) return null;
  return raw
      .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
      .toList();
}

List<Map<String, String?>> qtDecodeNullableStringMapList(dynamic raw) {
  final list = qtDecodeMapList(raw);
  if (list == null) return [];
  return list.map((m) => m.map((k, v) => MapEntry(k, v?.toString()))).toList();
}

List<Map<String, String>> qtDecodeStringMapList(dynamic raw) {
  final list = qtDecodeMapList(raw);
  if (list == null) return [];
  return list.map((m) => m.map((k, v) => MapEntry(k, v?.toString() ?? ''))).toList();
}

Map<String, String>? qtDecodeStringMap(dynamic raw) {
  if (raw is! Map) return null;
  return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}

String qtMenuLegalKey(String catTitle, String itemName, [int occurrence = 0]) {
  final base = '${catTitle.trim().toLowerCase()}|||${itemName.trim().toLowerCase()}';
  return occurrence <= 0 ? base : '$base###${occurrence + 1}';
}

Map<String, dynamic> qtNormalizeMenuLegalEntry(Map raw) {
  final allergens = <String>[];
  final allergensRaw = raw['allergens'];
  if (allergensRaw is List) {
    for (final e in allergensRaw) {
      final s = e.toString();
      if (s.isEmpty) continue;
      if (s == 'Fıstık/Kuruyemiş') {
        for (final x in const ['Yer Fıstığı', 'Kuruyemiş']) {
          if (!allergens.contains(x)) allergens.add(x);
        }
      } else if (!allergens.contains(s)) {
        allergens.add(s);
      }
    }
  }
  var meat = raw['meatType']?.toString() ?? '';
  if (meat == 'Yok / Vejetaryen') meat = 'Vejetaryen';
  final alcohol = raw['alcohol'] == true;
  final pork = raw['pork'] == true;
  return {
    'allergens': allergens,
    'calories': (raw['calories']?.toString() ?? '').trim(),
    'meatType': meat,
    'alcohol': alcohol,
    'pork': pork,
    'altPork': raw['altPork'] == true && !alcohol && !pork,
  };
}

bool qtMenuLegalEntryHasData(Map<String, dynamic>? entry) {
  if (entry == null) return false;
  final allergens = entry['allergens'];
  return (allergens is List && allergens.isNotEmpty) ||
      (entry['calories']?.toString().isNotEmpty ?? false) ||
      (entry['meatType']?.toString().isNotEmpty ?? false) ||
      entry['alcohol'] == true ||
      entry['pork'] == true ||
      entry['altPork'] == true;
}

bool qtMenuCategoriesHaveLegal(List<Map<String, dynamic>> categories) {
  for (final cat in categories) {
    for (final item in (cat['items'] as List)) {
      if (item is Map && item['legal'] != null) return true;
    }
  }
  return false;
}

Map<String, Map<String, dynamic>> qtDecodeMenuLegalInfo(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, Map<String, dynamic>>{};
  raw.forEach((k, v) {
    if (v is! Map) return;
    out[k.toString()] = qtNormalizeMenuLegalEntry(v);
  });
  return out;
}

List<Map<String, dynamic>> qtMergeMenuLegalInfo(
  List<Map<String, dynamic>> categories,
  Map<String, dynamic> legalInfo,
) {
  if (legalInfo.isEmpty) return categories;
  final seen = <String, int>{};
  return categories.map<Map<String, dynamic>>((cat) {
    final catTitle = (cat['title'] as String?) ?? '';
    final items = (cat['items'] as List).map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      final name = (item['name'] as String?) ?? '';
      if (name.trim().isEmpty) return item;
      final base = qtMenuLegalKey(catTitle, name);
      final n = seen[base] ?? 0;
      seen[base] = n + 1;
      final legal = legalInfo[qtMenuLegalKey(catTitle, name, n)];
      if (legal is Map) {
        final entry = qtNormalizeMenuLegalEntry(legal);
        if (qtMenuLegalEntryHasData(entry)) item['legal'] = entry;
      }
      return item;
    }).toList();
    return {...cat, 'items': items};
  }).toList();
}
