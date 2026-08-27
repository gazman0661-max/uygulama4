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
  kProductPublishSlot,
  kProductPoints15,
  kProductPoints30,
  kProductPoints50,
  kProductPoints100,
};
