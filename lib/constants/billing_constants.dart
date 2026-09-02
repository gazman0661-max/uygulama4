/// ============================================================================
/// SITORA — MAĞAZA ÜRÜN KİMLİKLERİ (İSKELET)
/// ============================================================================
/// Burada tanımlanan ürün kimlikleri (product id), Play Console'da ve
/// (ileride) App Store Connect'te BİREBİR AYNI STRING'LERLE oluşturulmalı —
/// yoksa BillingService.queryProducts() bunları "bulunamadı" (notFoundIDs)
/// olarak döner ve satın alma butonları fiyat gösteremez.
///
/// ÜÇ FARKLI SATIN ALMA MODELİ, TEK TİP ÜRÜNLE (consumable) ÇÖZÜLÜYOR:
/// Play Billing'de bir "non-consumable" (managed) ürün hesap başına SADECE
/// BİR KERE satın alınabilir ve bir daha asla tekrar satılamaz. Bizim üç
/// akışımızın da (rozet kaldırma, site yayın hakkı, puan paketi) hepsi
/// AYNI ürünün BİRDEN FAZLA kez satın alınabilmesini gerektiriyor (örn.
/// kullanıcı 3 farklı sitede rozet kaldırabilmeli, 2., 3., 4. sitesini
/// yayınlamak için tekrar tekrar ödeme yapabilmeli). Bu yüzden ÜÇÜ DE
/// Play Console'da "consumable" (tüketilebilir) olarak tanımlanmalı —
/// BillingService her satın alma sonrası consumePurchase çağırıp ürünü
/// "tüketir", böylece aynı ürün bir dahaki sefere tekrar satın alınabilir
/// hale gelir. Hangi PROJEYE / hangi PUAN HAVUZUNA uygulanacağı mağazanın
/// bilmediği bir bilgi olduğu için, bu eşleme tamamen İSTEMCİ (Flutter)
/// tarafında AppState üzerinden yapılır (bkz. billing_service.dart'taki
/// akış açıklaması).
library billing_constants;

/// "Sitora ile üretildi" rozetini kaldırma — SİTE BAZLI, tek seferlik.
/// Aynı üründen birden fazla kez satın alınabilir (her seferinde farklı
/// bir proje için) çünkü consumable olarak tanımlanacak.
const String kProductRemoveWatermark = 'sitora_remove_watermark';

/// 28.08.2026 eklendi, 28.08.2026'da fiyat/akış revizyonuyla güncellendi —
/// İndirme artık ücretsiz reklam karşılığı DEĞİL, HER ZAMAN ücretli bir
/// kilit (bkz. widgets/download_purchase_sheet.dart). Rozet kaldırma
/// (kProductRemoveWatermark) TEK BAŞINA indirme hakkı VERMEZ — sadece
/// yayınlanan/görüntülenen sitedeki rozeti kaldırır. İNDİRMEK için HER
/// durumda ayrıca bu üründen (ya da aşağıdaki kombo üründen) bir satın
/// alma gerekir:
///   - kProductDownloadWatermarked (29.90): indirme hakkı, SİTE BAZLI,
///     tek seferlik — bir kez satın alınca o proje SINIRSIZ tekrar
///     indirilebilir. Proje o an rozetsizse (watermarkRemoved=true)
///     indirilen dosya da rozetsiz olur; rozetliyse rozetli iner — yani
///     bu ürünün ÇIKTISI, projenin o anki watermarkRemoved durumuna göre
///     değişir, üründe herhangi bir dallanma YOKTUR.
///   - kProductRemoveWatermark (149.90, yukarıda): SADECE rozeti kaldırır,
///     indirme hakkı vermez — kullanıcı daha sonra indirmek isterse yine
///     kProductDownloadWatermarked'i (29.90) satın almalıdır.
///   - kProductDownloadNoWatermark (169.90, aşağıda): rozet HENÜZ
///     kaldırılmamış bir projede sunulan KOMBO seçenek — tek ödemede hem
///     rozeti kalıcı olarak kaldırır HEM DE indirme hakkını verir (ayrı
///     ayrı 149.90+29.90=179.80 ödemek yerine indirimli tek ürün).
const String kProductDownloadWatermarked = 'sitora_download_watermarked';

/// 28.08.2026 eklendi — "Watermarksız indir" KOMBO ürünü. SADECE proje
/// henüz rozetsiz DEĞİLKEN (watermarkRemoved=false) download_purchase_sheet
/// üzerinde ikinci seçenek olarak gösterilir. Satın alınınca AppState hem
/// removeWatermarkForProject hem de unlockDownloadForProject'in yaptığını
/// TEK seferde uygular (bkz. AppState.unlockDownloadWithoutWatermark).
/// SİTE BAZLI, tek seferlik, consumable.
const String kProductDownloadNoWatermark = 'sitora_download_no_watermark';

/// İlk site yayını ücretsiz; ikinci ve sonraki her yeni site yayını için
/// bu üründen bir adet satın alınması gerekir (bkz. AppState.canPublishProject).
/// İkinci site ile üçüncü/dördüncü/... siteler AYNI FİYATTAN satılır —
/// yani tek bir üründür, kademeli fiyatlandırma YOK.
const String kProductPublishSlot = 'sitora_publish_slot';

/// Puan paketleri — dört sabit paket, consumable. Satın alınan puanlar
/// aylık ücretsiz kotanın (formCredits/aiCredits) ÜZERİNE eklenmez; ayrı,
/// AYIN SONUNDA SIFIRLANMAYAN bir bakiyede tutulur (bkz.
/// AppState.purchasedPoints) ve aylık ücretsiz kota bittiğinde otomatik
/// olarak devreye girer.
const String kProductPoints15 = 'sitora_points_15';
const String kProductPoints30 = 'sitora_points_30';
const String kProductPoints50 = 'sitora_points_50';
const String kProductPoints100 = 'sitora_points_100';

/// Puan paketi ürün kimliğinden paketin puan miktarına hızlı erişim —
/// satın alma tamamlandığında BillingService bu haritayla kaç puan
/// ekleneceğini bulur (mağaza fiyatı bilir ama puan miktarını bilmez,
/// o yüzden bu eşleme istemci tarafında sabit tutulur).
const Map<String, int> kPointsPackageAmounts = {
  kProductPoints15: 15,
  kProductPoints30: 30,
  kProductPoints50: 50,
  kProductPoints100: 100,
};

/// BillingService.init() sırasında mağazadan tek seferde sorgulanacak
/// TÜM ürün kimlikleri.
const Set<String> kAllProductIds = {
  kProductRemoveWatermark,
  kProductDownloadWatermarked,
  kProductDownloadNoWatermark,
  kProductPublishSlot,
  kProductPoints15,
  kProductPoints30,
  kProductPoints50,
  kProductPoints100,
};
