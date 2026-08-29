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
