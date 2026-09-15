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
/// akışımızın da (rozet kaldırma, site yayın hakkı, özel domain bağlama)
/// hepsi AYNI ürünün BİRDEN FAZLA kez satın alınabilmesini
/// gerektiriyor (örn. kullanıcı 3 farklı sitede rozet kaldırabilmeli, 2.,
/// 3., 4. sitesini yayınlamak için tekrar tekrar ödeme yapabilmeli, birden
/// fazla sitesine ayrı ayrı özel domain bağlayabilmeli). Bu yüzden ÜÇÜ DE
/// Play Console'da "consumable" (tüketilebilir) olarak tanımlanmalı —
/// BillingService her satın alma sonrası consumePurchase çağırıp ürünü
/// "tüketir", böylece aynı ürün bir dahaki sefere tekrar satın alınabilir
/// hale gelir. Hangi PROJEYE uygulanacağı mağazanın
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
///   - kProductDownloadWatermarked (199.90): indirme hakkı, SİTE BAZLI,
///     tek seferlik — bir kez satın alınca o proje SINIRSIZ tekrar
///     indirilebilir. Proje o an rozetsizse (watermarkRemoved=true)
///     indirilen dosya da rozetsiz olur; rozetliyse rozetli iner — yani
///     bu ürünün ÇIKTISI, projenin o anki watermarkRemoved durumuna göre
///     değişir, üründe herhangi bir dallanma YOKTUR.
///   - kProductRemoveWatermark (199.90, yukarıda): SADECE rozeti kaldırır,
///     indirme hakkı vermez — kullanıcı daha sonra indirmek isterse yine
///     kProductDownloadWatermarked'i (199.90) satın almalıdır.
///   - kProductDownloadNoWatermark (349.90, aşağıda): rozet HENÜZ
///     kaldırılmamış bir projede sunulan KOMBO seçenek — tek ödemede hem
///     rozeti kalıcı olarak kaldırır HEM DE indirme hakkını verir (ayrı
///     ayrı 199.90+199.90=399.80 ödemek yerine indirimli tek ürün).
///
/// FİYAT NOTU: gerçek fiyat burada değil, Play Console'daki her ürünün
/// kendi sayfasında tanımlanır — bu yorumdaki rakamlar sadece referans
/// içindir, kodun davranışını etkilemez.
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

/// 05.09.2026 eklendi — "Kendi domainimi bağla" özelliği (bkz.
/// screens/domain_connect_screen.dart, widgets/domain_purchase_sheet.dart).
/// SİTE BAZLI, 1 YILLIK, tek seferlik satın alma — consumable olarak
/// tanımlanmalı (diğer tüm ürünlerle AYNI gerekçe: bir kullanıcı birden
/// fazla sitesinde domain bağlayabilmeli, ayrıca bir domain süresi dolup
/// worker'daki `domainCleanupSweep` tarafından TAMAMEN sökülürse — bkz.
/// DEGISIKLIKLER_05_09_2026.md madde 11 — kullanıcı isterse aynı siteye
/// tekrar bağlamak için bu üründen YENİDEN satın almalı).
///
/// Ne zaman harcanır: İLK bağlama anında (domain_connect_screen.dart >
/// _connect, domain hiç bağlı değilken "Bağla"ya basıldığında) VE her
/// "Uzat" (renewProjectDomain) çağrısında (bkz. AŞAĞIDAKİ 05.09.2026
/// GÜNCELLEMESİ) — yani AYNI ürün hem ilk bağlamada hem de her yenilemede
/// tekrar tekrar satın alınır. Bu, zaten diğer tüm ürünlerin consumable
/// olma gerekçesiyle (bkz. dosyanın en üstündeki genel açıklama) birebir
/// tutarlı: "aynı ürün birden fazla kez satın alınabilmeli" kuralı burada
/// hem "farklı siteler" hem de "aynı sitenin farklı yenilemeleri" için
/// geçerli.
///
/// 05.09.2026 GÜNCELLENDİ (kanka kararı) — ESKİDEN burada "Uzat, ikinci bir
/// satın alma GEREKTİRMEZ, ücretsizdir" yazıyordu. Kanka bunun YANLIŞ bir
/// ürün kararı olduğuna karar verdi: yenileme de artık ÜCRETLİ — kullanıcı
/// "Bağlantıyı 1 Yıl Uzat"a her bastığında ÖNCE bu üründen tekrar bir satın
/// alma yapması gerekiyor (bkz. AppState.renewProjectDomain çağrılmadan
/// ÖNCE domain_connect_screen.dart > _renew'in showDomainPurchaseSheet'i
/// açması — _connect'teki ÇİFTE ÖDEME KORUMASI deseninin (bkz.
/// domainConnectPurchasePending) AYNISI burada da domainRenewPurchasePending
/// ile uygulanıyor).
const String kProductConnectDomain = 'sitora_connect_domain';

/// 05.09.2026 eklendi (kanka isteği) — "1 Aylık Mini Paket". SİTE BAZLI,
/// 1 AYLIK, tek seferlik satın alma — diğer tüm ürünlerle AYNI gerekçeyle
/// consumable olarak tanımlanmalı (kullanıcı süre dolunca ya da başka bir
/// sitesi için tekrar satın alabilmeli).
///
/// kProductConnectDomain'in KÜÇÜK/kısa süreli bir versiyonu gibi düşünülebilir:
///   - Rozeti kaldırır (bkz. AppState.removeWatermarkForProject viaMiniPackage:true)
///   - Diğer premium kilitleri açar (Talep Kutusu, tam galeri, harita, talep
///     formu, Google yorum butonu, ziyaretçi sayısı — bkz. SiteProject.isPremium)
/// FARKI: SÜRESİ 1 AY (365 gün değil) VE İNDİRME HAKKINI HİÇ KAPSAMAZ —
/// indirme (kProductDownloadWatermarked / kProductDownloadNoWatermark) her
/// zaman olduğu gibi TAMAMEN AYRI bir satın almadır, bu paket downloadPurchased'a
/// hiç dokunmaz (bkz. AppState.canDownloadFreely, zaten domain paketi de aynı
/// şekilde indirmeyi kapsamıyordu).
///
/// Süresi dolup YENİLENMEZSE (kullanıcı tekrar satın almazsa) hem rozet HEM
/// DE diğer kilitler otomatik geri gelir — domain süresi dolduğunda olduğu
/// GİBİ (bkz. SiteProject.isMiniPackageActive, AppState.revertExpiredMiniPackages).
/// Tekrar satın alınırsa (activateMiniPackage yeniden çağrılır) süre o anki
/// satın alma tarihinden itibaren yeniden 1 ay olarak başlar.
const String kProductMiniPackage = 'sitora_mini_package_1ay';

/// BillingService.init() sırasında mağazadan tek seferde sorgulanacak
/// TÜM ürün kimlikleri.
const Set<String> kAllProductIds = {
  kProductRemoveWatermark,
  kProductDownloadWatermarked,
  kProductDownloadNoWatermark,
  kProductPublishSlot,
  kProductConnectDomain,
  kProductMiniPackage,
};
