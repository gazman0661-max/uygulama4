/// Hızlı Araçlar "Düzenle" akışı için küçük yardımcılar.
///
/// Her form ekranı, üretim yapmadan hemen önce kendi alanlarının (metin
/// kutuları, galeri/kapak fotoğrafları, çalışma saatleri, tema, konum vb.)
/// anlık değerlerini basit bir `Map<String, dynamic>` içine yazar
/// (`_captureFormData`) ve bu map `AppState.qtFormData` üzerinden
/// SharedPreferences'a JSON olarak kaydedilir (bkz. state/app_state.dart).
///
/// Kullanıcı "Düzenle"ye bastığında aynı form ekranı bu map'i
/// `initialData` olarak geri alır ve `_restoreFromInitialData` ile kendi
/// alanlarına geri yazar. Uygulama YENİDEN başlatılmış olabileceğinden
/// (map bu durumda jsonDecode'dan geldiği için iç içe listeler/map'ler
/// `dynamic` tipte gelir) bu yardımcılar hem taze (aynı oturum, tipli)
/// hem de JSON'dan çözülmüş (dynamic) veriyi güvenle kabul eder.
library qt_form_data_codec;

/// [raw] bir liste değilse null döner; listeyse elemanlarını
/// `Map<String, dynamic>` olarak normalize eder.
List<Map<String, dynamic>>? qtDecodeMapList(dynamic raw) {
  if (raw is! List) return null;
  return raw
      .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
      .toList();
}

/// Galeri/kapak/çalışma saatleri gibi `List<Map<String, String?>>` alanlar
/// için. Anahtar yoksa ya da tip uymuyorsa boş liste döner.
List<Map<String, String?>> qtDecodeNullableStringMapList(dynamic raw) {
  final list = qtDecodeMapList(raw);
  if (list == null) return [];
  return list.map((m) => m.map((k, v) => MapEntry(k, v?.toString()))).toList();
}

/// `List<Map<String, String>>` (null OLMAYAN değerli) alanlar için —
/// örn. generic_business_form_screen.dart > _extraPages.
List<Map<String, String>> qtDecodeStringMapList(dynamic raw) {
  final list = qtDecodeMapList(raw);
  if (list == null) return [];
  return list.map((m) => m.map((k, v) => MapEntry(k, v?.toString() ?? ''))).toList();
}

/// 17.09.2026 eklendi ('Özel Tema' B seçeneği) — ThemePickerField'ın
/// `Map<String, String>?` customTheme alanı için. [raw] Map değilse (yok/
/// null/bozuk veri) null döner — yani eski (bu alanı hiç içermeyen)
/// kayıtlı formlar sorunsuz geri yüklenir, sadece "Özel Tema" boş/
/// varsayılan açılır.
Map<String, String>? qtDecodeStringMap(dynamic raw) {
  if (raw is! Map) return null;
  return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}

// 19.09.2026 eklendi (kanka isteği) — kafe/restoran menüsünde ürün başına
// yasal bilgi (alerjen/kalori/et türü/alkol/domuz), bkz.
// widgets/menu_legal_info_field.dart.
//
// ANAHTAR: "kategori|||ürün" (trim + lowercase). Aynı kategori+isimde
// birden fazla ürün varsa 2. ürün "…###2", 3. ürün "…###3" olur (bkz.
// [qtMenuLegalKey]) — böylece aynı isimli ürünler birbirinin bilgisini
// ezmez.
//
// DEĞER: {'allergens': List<String>, 'calories': String, 'meatType':
// String, 'alcohol': bool, 'pork': bool, 'altPork': bool}. 'altPork' ESKİ
// (tek switch'li) kayıtların uyumluluğu için — sadece alcohol/pork
// ikisi de false iken true kalabilir, bkz. [qtNormalizeMenuLegalEntry].
//
// Bu özellik abonelikle kilitli — ama kaydedilmiş bir formda veri varsa
// (abonelik daha sonra bitse bile) veriyi KAYBETMEDEN geri yükleriz;
// üretim anında yalnızca AKTİF abone ise generator'a geçilir (bkz.
// kafe/restaurant_form_screen.dart > _generate).

/// [occurrence] 0-tabanlı: menüde AYNI (kategori, isim) çiftinin kaçıncı
/// tekrarı olduğu. Widget ve [qtMergeMenuLegalInfo] AYNI sırayla sayar.
String qtMenuLegalKey(String catTitle, String itemName, [int occurrence = 0]) {
  final base = '${catTitle.trim().toLowerCase()}|||${itemName.trim().toLowerCase()}';
  return occurrence <= 0 ? base : '$base###${occurrence + 1}';
}

/// Tek bir ürünün yasal bilgisini kanonik şekle getirir. Eski kayıtları da
/// yükseltir:
///  - 'Fıstık/Kuruyemiş' -> 'Yer Fıstığı' + 'Kuruyemiş' (alerjende fazla
///    uyarmak eksik uyarmaktan güvenli; kullanıcı istemezse kaldırır)
///  - 'Yok / Vejetaryen' -> 'Vejetaryen'
///  - tek 'altPork' switch'i: alcohol/pork seçilene kadar 'altPork' olarak
///    korunur (hangisi olduğunu tahmin etmeyiz).
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

/// [entry] içinde siteye basılacak en az bir bilgi var mı.
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

/// [qtMergeMenuLegalInfo] çıktısında en az bir üründe 'legal' var mı —
/// yani şu anki menüyle EŞLEŞEN gerçek veri (isim değiştirilmiş/silinmiş
/// ürünlerin artık görünmeyen kayıtları sayılmaz).
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

/// Menü kategorilerine ([_parseMenu] çıktısı) yasal bilgileri ekler — sadece
/// üretime (HTML) gönderilmeden hemen önce çağrılır. [legalInfo] boşsa ya da
/// bir ürün için veri girilmemişse o ürün hiç dokunulmadan geçer (generator
/// tarafında 'legal' anahtarı yoksa rozet basılmaz).
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
