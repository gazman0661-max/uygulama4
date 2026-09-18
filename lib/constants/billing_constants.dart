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

/// 28.08.2026 eklendi, 16.09.2026'da İKİNCİ bir fiyat/akış revizyonuyla
/// güncellendi (kanka kararı — "watermarklı indir" ucuz seçeneği tamamen
/// KALDIRILDI, bkz. widgets/download_purchase_sheet.dart). İndirme HER
/// ZAMAN ücretli bir kilit. Rozet kaldırma (kProductRemoveWatermark) TEK
/// BAŞINA indirme hakkı VERMEZ — sadece yayınlanan/görüntülenen sitedeki
/// rozeti kaldırır. İNDİRMEK için HER durumda ayrıca bu üründen (ya da
/// aşağıdaki kombo üründen) bir satın alma gerekir:
///   - kProductDownloadWatermarked (799.90): indirme hakkı, SİTE BAZLI,
///     tek seferlik — bir kez satın alınca o proje SINIRSIZ tekrar
///     indirilebilir. 16.09.2026'dan İTİBAREN sadece TEK bir senaryoda
///     sunulur: proje ZATEN rozetsizse (watermarkRemoved=true — kalıcı
///     satın alma/domain/mini paket/abonelik farketmez), kullanıcının
///     göreceği TEK seçenek budur ("İndir" butonu). Proje HÂLÂ rozetliyse
///     bu ürün ARTIK HİÇ SUNULMAZ (ESKİDEN "Watermarklı İndir" adıyla
///     rozet kalarak ucuz indirme seçeneği vardı — kaldırıldı, tek yol
///     aşağıdaki kombo oldu).
///   - kProductRemoveWatermark (199.90, yukarıda): SADECE rozeti kaldırır,
///     indirme hakkı vermez — kullanıcı daha sonra indirmek isterse yine
///     kProductDownloadWatermarked'i (799.90) satın almalıdır (toplamda
///     199.90+799.90=999.90 — aşağıdaki kombo ile AYNI toplam tutar,
///     kombo sadece TEK ödemede/TEK adımda birleştirir, ekstra indirim
///     İÇERMEZ).
///   - kProductDownloadNoWatermark (999.90, aşağıda): rozet HENÜZ
///     kaldırılmamış bir projede sunulan TEK seçenek (kombo) — tek
///     ödemede hem rozeti kalıcı olarak kaldırır HEM DE indirme hakkını
///     verir.
///
/// FİYAT NOTU: gerçek fiyat burada değil, Play Console'daki her ürünün
/// kendi sayfasında tanımlanır — bu yorumdaki rakamlar sadece referans
/// içindir, kodun davranışını etkilemez.
const String kProductDownloadWatermarked = 'sitora_download_watermarked';

/// 28.08.2026 eklendi, 16.09.2026'da fiyatı/rolü güncellendi — "Watermarksız
/// indir" KOMBO ürünü. Proje henüz rozetsiz DEĞİLKEN (watermarkRemoved=false)
/// download_purchase_sheet üzerinde sunulan TEK seçenektir (16.09.2026'dan
/// itibaren — eskiden "Watermarklı İndir" diye ikinci/ucuz bir seçenek daha
/// vardı, kaldırıldı). Satın alınınca AppState hem removeWatermarkForProject
/// hem de unlockDownloadForProject'in yaptığını TEK seferde uygular (bkz.
/// AppState.unlockDownloadWithoutWatermark). SİTE BAZLI, tek seferlik,
/// consumable.
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
///
/// 17.09.2026 GÜNCELLENDİ (kanka kararı — "abonelikte kota dahilindeki
/// domain hem bağlarken hem yenilerken ücretsiz olmalı" fix'i): yukarıdaki
/// "yenileme her zaman ücretli" kuralı SADECE aboneliksiz/kota dışı
/// durumlar için geçerli. domain_connect_screen.dart > _renew artık
/// _connect ile AYNI kontrolü yapıyor: AppState.canConnectDomainViaSubscription
/// true ise (proje zaten domainViaSubscription=true VEYA hesabın boş bir
/// domain kota slotu varsa) ödeme sheet'i HİÇ AÇILMADAN doğrudan yenilenir.
/// Yani "10 domain hakkı olan bir abone 11.'yi parayla alır" kuralı artık
/// hem ilk bağlamada HEM DE her yıllık yenilemede tutarlı şekilde uygulanıyor
/// — abonelik aktif kaldığı ve kota dolmadığı sürece kullanıcı domain için
/// bir daha hiç ödeme sheet'i görmez.
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

/// ============================================================================
/// AYLIK ABONELİK PAKETLERİ — 15.09.2026 eklendi (kanka isteği).
/// ============================================================================
/// kProductMiniPackage'ın (yukarıda) SİTE BAZLI, consumable "1 aylık" modelinden
/// FARKLI olarak, bunlar Play Console'da GERÇEK "abonelik" (subscription) ürünü
/// olarak tanımlanmalı — auto-renewing, HESAP BAZLI (site başına değil).
/// Consumable DEĞİLDİR: buyConsumable/consumePurchase akışı bunlara UYGULANMAZ
/// (BillingService'e ayrı bir buySubscription akışı — sonraki adım — gerekiyor).
///
/// ÜÇ PAKET DE AYNI ÖZELLİK GRUBUNU (rozet kaldırma + premium kilit açma)
/// veriyor, TEK FARK site/domain KOTASI. (17.09.2026 GÜNCELLENDİ — kanka
/// kararı: Max paketteki "ücretsiz sınırsız indirme" KALDIRILDI, bkz.
/// kTierFreelancerMax tanımındaki not. Artık üç paket arasındaki TEK fark
/// site/domain kotası; indirme hangi pakette olursa olsun HER ZAMAN site
/// başı ayrı satılan bir kilit — bkz. kProductDownloadNoWatermark.)
/// Play Console'da ÜÇÜ DE AYRI ürün olarak (aynı "subscription group" altında,
/// farklı "base plan" olarak DEĞİL — üç ayrı ayrı subscription ID) tanımlanmalı;
/// böylece Play'in kendi "aboneliği değiştir" (orantılı fiyat farkı) akışı
/// üçü arasında geçişte otomatik çalışır (bkz. önceki oturumdaki karar: paket
/// yükseltme/düşürme Google Play'in kendi abonelik değiştirme akışıyla çözülür).
///
/// KOTA AŞIMI DAVRANIŞI (kanka kararı, 17.09.2026 GÜNCELLENDİ — "artık
/// worker da baksın" isteği): bir hesap daha yüksek kotalı bir paketten
/// düşük kotalıya geçerse VEYA abonelik süresi dolup yenilenmezse VE o an
/// kota dışı kalan siteler varsa, kullanıcı uygulamayı AÇARSA bir uyarı
/// görüp HANGİ site(ler)in yayında kalacağını KENDİSİ seçebilir (bkz.
/// AppState.subscriptionQuotaProjects / quota_overflow_picker_sheet.dart —
/// "Otomatik Seç" butonu / AppState.autoResolveSubscriptionQuotaOverflow: en
/// eski yayınlanan fazlalık siteleri GERÇEKTEN yayından kaldırır).
///
/// ESKİDEN bu, kullanıcı uygulamayı AÇMADAN gerçekleşmiyordu — worker bu
/// durumu hiç kontrol etmiyordu, kullanıcı uygulamayı hiç açmasa fazlalık
/// site(ler) süresiz kota aşımında kalabiliyordu. ARTIK worker tarafında
/// GÜNLÜK olarak (bkz. cloudflare/worker/src/index.mjs >
/// subscriptionQuotaOverflowSweep, AYNI cron'a bağlı) client'taki "Otomatik
/// Seç" ile BİREBİR AYNI mantık uygulanıyor: kullanıcı elle seçim yapmasa
/// BİLE, en fazla bir gün içinde en yeni `siteQuota`/`domainQuota` kadar
/// site/domain kota içinde tutulur, en eski fazlalık OTOMATİK kaldırılır/
/// söktürülür. Kullanıcı uygulamayı o gün içinde açıp kendisi seçim
/// yaparsa (ya da "Otomatik Seç"e basarsa) worker'ın günlük sweep'i
/// beklemeden AYNI sonuç anında elde edilir — ikisi ÇAKIŞMAZ, hangisi önce
/// gerçekleşirse kota o an itibarıyla zaten aşılmamış olur.
///
/// ROZET/KİLİT KURALI (önceki oturumdaki karar): abonelik SADECE kota
/// dahilinde yayınlı olan siteler için rozeti kaldırır/kilitleri açar —
/// hesaptaki TÜM siteler için değil.
/// "Mini Paket" (aylık abonelik) — 1 site yayınlama + 1 siteye özel domain
/// bağlama + premium kilitler + rozet kaldırma (kota dahilindeki site için).
const String kProductSubMini = 'sitora_sub_mini_aylik';

/// "Freelancer Paket" (aylık abonelik) — 5 site yayınlama + 5 siteye özel
/// domain bağlama + Mini'deki tüm diğer özellikler (kota dahilindeki siteler
/// için).
const String kProductSubFreelancer = 'sitora_sub_freelancer_aylik';

/// "Freelancer Max Paket" (aylık abonelik) — 10 site yayınlama + 10 siteye
/// özel domain bağlama + diğer tüm özellikler (kota dahilindeki siteler
/// için). 17.09.2026'dan itibaren ücretsiz indirme İÇERMEZ — bkz.
/// kTierFreelancerMax tanımındaki not.
const String kProductSubFreelancerMax = 'sitora_sub_freelancer_max_aylik';

/// Üç abonelik ürün kimliği — BillingService.init() sırasında diğer
/// (consumable) ürünlerle BİRLİKTE sorgulanır (fiyat/başlık göstermek için
/// queryProductDetails ikisini de tek çağrıda kabul eder), ama SATIN ALMA
/// akışı ayrıdır (subscription, buyConsumable ile satın alınamaz).
const Set<String> kAllSubscriptionProductIds = {
  kProductSubMini,
  kProductSubFreelancer,
  kProductSubFreelancerMax,
};

/// Bir abonelik paketinin sabit özellikleri (kota vb.) — UI'da paket
/// karşılaştırma kartları ve worker'daki kota kontrolü (ileride) için TEK
/// kaynak. Sıralama önem taşır: [kSubscriptionTiers] düşükten yükseğe
/// dizilidir (upgrade/downgrade karşılaştırmalarında sıra ile kıyaslanır).
class SubscriptionTierInfo {
  final String productId;
  final String displayNameTr;
  final int siteQuota;
  final int domainQuota;
  final bool freeDownloads;

  const SubscriptionTierInfo({
    required this.productId,
    required this.displayNameTr,
    required this.siteQuota,
    required this.domainQuota,
    required this.freeDownloads,
  });
}

const SubscriptionTierInfo kTierMini = SubscriptionTierInfo(
  productId: kProductSubMini,
  displayNameTr: 'Mini Paket',
  siteQuota: 1,
  domainQuota: 1,
  freeDownloads: false,
);

const SubscriptionTierInfo kTierFreelancer = SubscriptionTierInfo(
  productId: kProductSubFreelancer,
  displayNameTr: 'Freelancer Paket',
  siteQuota: 5,
  domainQuota: 5,
  freeDownloads: false,
);

/// 17.09.2026 GÜNCELLENDİ (kanka kararı) — ESKİDEN freeDownloads: true idi:
/// bu paket kota dahilindeki siteler için ÜCRETSİZ SINIRSIZ indirme hakkı
/// da veriyordu. BU KALDIRILDI: bir kullanıcının tek bir aylık ödemeyle
/// (bu paketin fiyatı, tek seferlik indirme ücretinden — bkz.
/// kProductDownloadNoWatermark — daha ucuz) aboneliğe girip kotadaki TÜM
/// sitelerini ücretsiz indirip sonra aboneliği iptal edebilmesi (indirilen
/// statik HTML dosyaları kalıcı kaldığı için abonelik bitse de geri
/// alınamıyor) tek seferlik indirme ürününü fiilen anlamsızlaştıran bir
/// açıktı. ARTIK indirme, hangi pakete/aboneliğe sahip olunursa olsun HER
/// ZAMAN site başına ayrı satılan bir kilit (bkz. AppState.canDownloadFreely
/// — artık SADECE downloadPurchased'a bakar, activeSubscriptionTier hiç
/// okunmaz). freeDownloads alanı ve tier karşılaştırma UI'ındaki "Ücretsiz
/// indirme" / "İndirme ayrı satılır" ayrımı (bkz.
/// subscription_plans_screen.dart) BİLEREK koddan SÖKÜLMEDİ — artık üç
/// paket için de her zaman "İndirme ayrı satılır" gösterir; böylece
/// ileride paket bazlı bir indirme ayrıcalığı tekrar gerekirse tek satırlık
/// bir değişiklikle geri açılabilir.
const SubscriptionTierInfo kTierFreelancerMax = SubscriptionTierInfo(
  productId: kProductSubFreelancerMax,
  displayNameTr: 'Freelancer Max Paket',
  siteQuota: 10,
  domainQuota: 10,
  freeDownloads: false,
);

/// Düşükten yükseğe sıralı tüm paketler — productId -> bilgi eşlemesi için
/// [kSubscriptionTierByProductId] kullanılır.
const List<SubscriptionTierInfo> kSubscriptionTiers = [
  kTierMini,
  kTierFreelancer,
  kTierFreelancerMax,
];

final Map<String, SubscriptionTierInfo> kSubscriptionTierByProductId = {
  for (final t in kSubscriptionTiers) t.productId: t,
};

/// BillingService.init() sırasında mağazadan tek seferde sorgulanacak
/// TÜM ürün kimlikleri (tek seferlik consumable ürünler + abonelikler).
// 17.09.2026 eklendi (kanka isteği — "tek seferlik mini paketi artık
// satmayacağız" fix'i). kProductMiniPackage BİLEREK bu listeden ÇIKARILDI —
// artık mağazadan sorgulanmıyor/satılmıyor, sadece 3 abonelik paketi +
// ücretsiz katman satılıyor. Sabitin kendisi (aşağıda) ve daha önce bu
// üründen alan hesapların süre/dolma mantığı (AppState.activateMiniPackage,
// premiumDowngradeSweep, hediye kredisi sistemi) kod tabanında BİLEREK
// dokunulmadan bırakıldı — mevcut/geçmiş kayıtların bozulmaması için.
const Set<String> kAllProductIds = {
  kProductRemoveWatermark,
  kProductDownloadWatermarked,
  kProductDownloadNoWatermark,
  kProductPublishSlot,
  kProductConnectDomain,
  kProductSubMini,
  kProductSubFreelancer,
  kProductSubFreelancerMax,
};
