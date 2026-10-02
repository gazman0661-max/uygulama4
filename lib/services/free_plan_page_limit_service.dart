import '../constants/billing_constants.dart';
import '../models/site_project.dart';

/// 06.09.2026 eklendi (kanka isteği) — "Çok sayfa kısıtlaması" işi.
///
/// ÜÇ KADEMELİ POLİTİKA (SİTE BAZLI, hesap bazlı DEĞİL). 01.10.2026: eski
/// tek seferlik "Mini Paket" kademesi KALDIRILDI; abonelik kademesi geldi ve
/// SINIRSIZ sayfa kaldırıldı — artık her premium kaynağın bir üst sınırı var
/// (kanka kararı).
///   1) FREE (domain yok, abonelik kotasında değil) -> çok sayfa TAMAMEN
///      KİLİTLİ, sadece tek sayfa üretilebilir.
///   2) ABONELİK kotası (bkz. AppState.subscriptionTierForPageGate) -> pakete
///      göre TOPLAM sayfa sınırı (ana sayfa dahil), bkz.
///      SubscriptionTierInfo.maxPages: Başlangıç 3 / Mini 5 / Freelancer 10 /
///      Freelancer Max 15. Abonelik domain kotasından verilen domain de bu
///      sınıra DAHİLDİR (domain ayrıca bir üst sınır vermez).
///   3) SATIN ALINMIŞ tek seferlik ÖZEL DOMAIN (kProductConnectDomain, aktif
///      ve süresi dolmamış) -> [domainPurchaseMaxPages] (15) sayfa. Sitede
///      hem satın alınmış domain hem abonelik varsa ikisinin BÜYÜĞÜ geçerli.
///
/// NEDEN MERKEZİ: bu kontrol TEK bir noktadan (LocalGenerationHelper.
/// generateMultiPage) uygulanıyor — home_screen'deki "Çok Sayfa" kartları,
/// 12 farklı sektör formundaki tek/çok sayfa anahtarı VE Emlak/Genel
/// İşletme'nin serbest "ek sayfa" listeleri dahil HER ÇOK SAYFA ÜRETİM
/// YOLU aynı noktadan geçtiği için (bkz. FreePlanRestrictionService'teki
/// AYNI merkezi-tek-nokta gerekçesi) tek bir yerde kontrol yeterli — 12+
/// form ekranının her birine ayrı ayrı dokunmaya gerek yok.
///
/// NOT — Emlak (Real Estate) sitesi tek sayfa ALTERNATİFİ OLMAYAN tek
/// sektördür (ilan listesi + ilan detayları zorunlu çok sayfa yapıda,
/// bkz. real_estate_form_screen.dart). Bu yüzden [alwaysMultiPage] true
/// geçildiğinde FREE kademede TAM KİLİT yerine
/// [freeAlwaysMultiPageMaxTotalPages] (1 ana sayfa + 1 ilan) uygulanır —
/// aksi halde free kullanıcı bu sektörü HİÇ kullanamazdı: domain SADECE
/// yayınlanmış, VAR OLAN bir projeye satın alınabiliyor (bkz.
/// DomainService — "site henüz yayınlanmamışsa" hata veriyor), yani bir sitenin İLK üretimi HER ZAMAN
/// free'dir — Emlak'ı tam kilitlemek bu şablonu kalıcı olarak kullanılamaz
/// hale getirirdi. Diğer TÜM sektörlerde (kafe, klinik, diyetisyen,
/// avukat, fotoğrafçı, portfolyo, genel işletme vb.) tek sayfa seçeneği
/// zaten var olduğu için bu istisnaya gerek yok — free'de çok sayfa
/// anahtarı tamamen kilitlenir, kullanıcı önce tek sayfa üretip siteyi
/// yayınlar, sonra bu SİTEYE domain alıp "Düzenle"den çok
/// sayfaya geçebilir.
class FreePlanPageLimitService {
  FreePlanPageLimitService._();

  /// Emlak gibi tek sayfa alternatifi olmayan sektörlerde FREE kademenin
  /// üretebileceği toplam sayfa sayısı (bkz. sınıf dokümanındaki NOT).
  static const int freeAlwaysMultiPageMaxTotalPages = 2;

  /// Tek seferlik SATIN ALINMIŞ özel domain'li sitenin üretebileceği toplam
  /// sayfa sayısı (ana sayfa dahil) — en yüksek abonelik paketiyle (Freelancer
  /// Max) aynı. 01.10.2026'da "sınırsız"dan değiştirildi (kanka kararı).
  static const int domainPurchaseMaxPages = 15;

  /// [project] null ise (henüz hiç kaydedilmemiş / ilk üretim) HER ZAMAN
  /// false döner — domain sadece VAR OLAN, yayınlanmış bir
  /// projeye satın alınabildiği için ilk üretim asla premium olamaz (bkz.
  /// sınıf dokümanı).
  /// 01.10.2026: SADECE tek seferlik SATIN ALINMIŞ domain bu kademeyi verir.
  /// Domain ABONELİĞİN domain kotasından ücretsiz verilmişse
  /// ([SiteProject.domainViaSubscription]) ayrıca bir hak vermez — o site
  /// paketin sayfa sınırına (tier.maxPages) tabidir.
  static bool _isPurchasedDomain(SiteProject? project) =>
      project != null &&
      project.isDomainConnected &&
      !project.isDomainExpired &&
      !project.domainViaSubscription;

  /// Bu proje için çok sayfa (SiteMode.multi) üretimi HİÇ mümkün mü?
  /// [alwaysMultiPage] true olan (Emlak gibi) sektörlerde free kademe de
  /// (kısıtlı sayıda) çok sayfa üretebildiği için bu her zaman true döner
  /// — gerçek sınır ayrıca [maxTotalPagesFor] ile uygulanır.
  static bool canUseMultiPage(
    SiteProject? project, {
    bool alwaysMultiPage = false,
    SubscriptionTierInfo? tier,
  }) {
    if (alwaysMultiPage) return true;
    return _isPurchasedDomain(project) || tier != null;
  }

  /// Üretilebilecek TOPLAM dosya (sayfa) sayısı üst sınırı —
  /// [Map<String,String>.length] (index dahil TÜM .html dosyaları) buna göre
  /// kontrol edilmeli. Artık SINIRSIZ kademe YOK (01.10.2026): satın alınmış
  /// domain [domainPurchaseMaxPages], [tier] verilmişse (bkz.
  /// AppState.subscriptionTierForPageGate) paketin sınırı, ikisi birden
  /// varsa BÜYÜĞÜ; hiçbiri yoksa free (1, Emlak istisnasında 2).
  static int maxTotalPagesFor(
    SiteProject? project, {
    bool alwaysMultiPage = false,
    SubscriptionTierInfo? tier,
  }) {
    var cap = alwaysMultiPage ? freeAlwaysMultiPageMaxTotalPages : 1;
    if (tier != null && tier.maxPages > cap) cap = tier.maxPages;
    if (_isPurchasedDomain(project) && domainPurchaseMaxPages > cap) cap = domainPurchaseMaxPages;
    return cap;
  }

  /// [canUseMultiPage] false döndüğünde showPremiumLockedPopup'a doğrudan
  /// geçilebilecek TR/EN kilit mesajı.
  static String lockedMessage(bool isEnglish, {required bool alwaysMultiPage}) {
    if (alwaysMultiPage) {
      return isEnglish
          ? 'This site type needs multiple listing pages. On the free plan you can publish up to $freeAlwaysMultiPageMaxTotalPages pages for this site — subscribe to a plan or connect a custom domain on this project to unlock more.'
          : 'Bu site türü birden fazla ilan sayfası gerektirir. Ücretsiz planda bu site için en fazla $freeAlwaysMultiPageMaxTotalPages sayfa yayınlayabilirsin — daha fazlası için bir abonelik paketi al ya da bu projeye özel domain bağla.';
    }
    return isEnglish
        ? 'Multi-page sites are a premium feature. Subscribe to a plan (3 to 15 pages, depending on the plan) or connect a custom domain (up to $domainPurchaseMaxPages pages).'
        : 'Çok sayfalı site premium bir özellik. Abonelik paketiyle (pakete göre 3 ile 15 sayfa) ya da bu projeye özel domain bağlayarak ($domainPurchaseMaxPages sayfaya kadar) açılır.';
  }

  /// [maxTotalPagesFor] sınırı aşıldığında (çok sayfa AÇIK ama üretilen
  /// dosya sayısı izin verilenden fazla) gösterilecek mesaj. En üst sınıra
  /// ([domainPurchaseMaxPages]) ulaşılmışsa "yükselt" önerisi yapılmaz;
  /// [tier] verilmişse abonelik paketine göre, değilse ücretsiz plana göre yazılır.
  static String tooManyPagesMessage(bool isEnglish, int maxTotalPages, {SubscriptionTierInfo? tier}) {
    if (maxTotalPages >= domainPurchaseMaxPages) {
      return isEnglish
          ? 'A site can have up to $maxTotalPages pages. Remove some pages and try again.'
          : 'Bir site en fazla $maxTotalPages sayfa olabilir. Birkaç sayfa çıkarıp tekrar dene.';
    }
    if (tier != null) {
      return isEnglish
          ? 'Your plan allows up to $maxTotalPages pages per site. Remove some pages, switch to a higher plan (up to $domainPurchaseMaxPages pages) or connect a custom domain.'
          : 'Paketin site başına en fazla $maxTotalPages sayfaya izin veriyor. Birkaç sayfa çıkar, üst pakete geç (en fazla $domainPurchaseMaxPages sayfa) ya da özel domain bağla.';
    }
    return isEnglish
        ? 'This project is limited to $maxTotalPages pages on the free plan. Remove some pages, subscribe to a plan, or connect a custom domain.'
        : 'Bu proje ücretsiz planda en fazla $maxTotalPages sayfaya kadar üretilebilir. Birkaç sayfa çıkar, abonelik paketi al ya da özel domain bağla.';
  }
}
