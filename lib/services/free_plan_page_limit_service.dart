import '../models/site_project.dart';

/// 06.09.2026 eklendi (kanka isteği) — "Çok sayfa kısıtlaması" işi.
///
/// ÜÇ KADEMELİ POLİTİKA (SİTE BAZLI — bkz. SiteProject.isPremium/
/// isDomainConnected/isMiniPackageActive, HEPSİ zaten proje bazlı, hesap
/// bazlı DEĞİL):
///   1) FREE (ne domain ne mini paket aktif)   -> çok sayfa TAMAMEN
///      KİLİTLİ, sadece tek sayfa üretilebilir.
///   2) MİNİ PAKET aktif                        -> çok sayfa açık ama en
///      fazla [miniPackageMaxExtraPages] EK sayfa (+ 1 ana sayfa = toplam
///      [miniPackageMaxTotalPages]) üretilebilir.
///   3) ÖZEL DOMAIN aktif (ve süresi dolmamış)  -> çok sayfa SINIRSIZ
///      ("serbest").
///
/// Domain her zaman mini paketten ÜSTÜN sayılır: bir sitede İKİSİ BİRDEN
/// aktifse (ör. kullanıcı önce mini paket alıp sonra aynı siteye domain de
/// bağladıysa) sınırsız kazanır — bkz. [maxTotalPagesFor].
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
/// aksi halde free kullanıcı bu sektörü HİÇ kullanamazdı: domain/mini
/// paket SADECE yayınlanmış, VAR OLAN bir projeye satın alınabiliyor
/// (bkz. DomainService/MiniPackageService — ikisi de "site henüz
/// yayınlanmamışsa" hata veriyor), yani bir sitenin İLK üretimi HER ZAMAN
/// free'dir — Emlak'ı tam kilitlemek bu şablonu kalıcı olarak kullanılamaz
/// hale getirirdi. Diğer TÜM sektörlerde (kafe, klinik, diyetisyen,
/// avukat, fotoğrafçı, portfolyo, genel işletme vb.) tek sayfa seçeneği
/// zaten var olduğu için bu istisnaya gerek yok — free'de çok sayfa
/// anahtarı tamamen kilitlenir, kullanıcı önce tek sayfa üretip siteyi
/// yayınlar, sonra bu SİTEYE domain/mini paket alıp "Düzenle"den çok
/// sayfaya geçebilir.
class FreePlanPageLimitService {
  FreePlanPageLimitService._();

  /// Mini paket sahibinin üretebileceği EK (ana sayfa hariç) sayfa sayısı.
  static const int miniPackageMaxExtraPages = 3;

  /// Ana sayfa + yukarıdaki ek sayfa sayısı = mini paketle üretilebilecek
  /// TOPLAM dosya sayısı üst sınırı.
  static const int miniPackageMaxTotalPages = miniPackageMaxExtraPages + 1;

  /// Emlak gibi tek sayfa alternatifi olmayan sektörlerde FREE kademenin
  /// üretebileceği toplam sayfa sayısı (bkz. sınıf dokümanındaki NOT).
  static const int freeAlwaysMultiPageMaxTotalPages = 2;

  /// [project] null ise (henüz hiç kaydedilmemiş / ilk üretim) HER ZAMAN
  /// false döner — domain/mini paket sadece VAR OLAN, yayınlanmış bir
  /// projeye satın alınabildiği için ilk üretim asla premium olamaz (bkz.
  /// sınıf dokümanı).
  static bool _isDomainPremium(SiteProject? project) =>
      project != null && project.isDomainConnected && !project.isDomainExpired;

  static bool _isMiniPackagePremium(SiteProject? project) =>
      project != null && project.isMiniPackageActive;

  /// Bu proje için çok sayfa (SiteMode.multi) üretimi HİÇ mümkün mü?
  /// [alwaysMultiPage] true olan (Emlak gibi) sektörlerde free kademe de
  /// (kısıtlı sayıda) çok sayfa üretebildiği için bu her zaman true döner
  /// — gerçek sınır ayrıca [maxTotalPagesFor] ile uygulanır.
  static bool canUseMultiPage(SiteProject? project, {bool alwaysMultiPage = false}) {
    if (alwaysMultiPage) return true;
    return _isDomainPremium(project) || _isMiniPackagePremium(project);
  }

  /// null = SINIRSIZ (özel domain aktif). Aksi halde üretilebilecek TOPLAM
  /// dosya (sayfa) sayısı üst sınırı — [Map<String,String>.length] (index
  /// dahil TÜM .html dosyaları) buna göre kontrol edilmeli.
  static int? maxTotalPagesFor(SiteProject? project, {bool alwaysMultiPage = false}) {
    if (_isDomainPremium(project)) return null;
    if (_isMiniPackagePremium(project)) return miniPackageMaxTotalPages;
    return alwaysMultiPage ? freeAlwaysMultiPageMaxTotalPages : 1;
  }

  /// [canUseMultiPage] false döndüğünde showPremiumLockedPopup'a doğrudan
  /// geçilebilecek TR/EN kilit mesajı.
  static String lockedMessage(bool isEnglish, {required bool alwaysMultiPage}) {
    if (alwaysMultiPage) {
      return isEnglish
          ? 'This site type needs multiple listing pages. On the free plan you can publish up to $freeAlwaysMultiPageMaxTotalPages pages for this site — connect a custom domain or buy the Mini Package on this project to unlock more.'
          : 'Bu site türü birden fazla ilan sayfası gerektirir. Ücretsiz planda bu site için en fazla $freeAlwaysMultiPageMaxTotalPages sayfa yayınlayabilirsin — daha fazlası için bu projeye özel domain bağla ya da Mini Paket satın al.';
    }
    return isEnglish
        ? 'Multi-page sites are a premium feature. Connect a custom domain to this project for unlimited pages, or buy the Mini Package for up to $miniPackageMaxExtraPages extra pages.'
        : 'Çok sayfalı site premium bir özellik. Bu projeye özel domain bağlarsan sayfa sayısı sınırsız olur; Mini Paket alırsan $miniPackageMaxExtraPages ek sayfaya kadar üretebilirsin.';
  }

  /// [maxTotalPagesFor] sınırı aşıldığında (çok sayfa AÇIK ama üretilen
  /// dosya sayısı izin verilenden fazla) gösterilecek mesaj.
  static String tooManyPagesMessage(bool isEnglish, int maxTotalPages) {
    return isEnglish
        ? 'This project is limited to $maxTotalPages pages on the Mini Package. Remove some pages, or connect a custom domain for unlimited pages.'
        : 'Bu proje Mini Paket ile en fazla $maxTotalPages sayfaya kadar üretilebilir. Birkaç sayfa çıkar, ya da sınırsız sayfa için özel domain bağla.';
  }
}
