import '../state/app_state.dart';
import '../services/server_time_service.dart';

/// "Projelerim" ekranında ayırt etmek için proje türü.
/// Her sektör kendi HTML generator fonksiyonunu kullanır (bkz.
/// lib/templates/html/), "Projelerim" listesindeki gösterim/etiket/ikon
/// mantığı için hepsi burada ayrı bir kind olarak tanımlı kalıyor.
enum ProjectKind {
  site, // genel amaçlı / eski kayıtlar için geriye dönük uyumluluk
  qrCode,
  bioLink,
  businessCard,
  kuafor,
  kafe,
  beautySalon,
  clinic,
  fitness,
  carWash,
  realEstate,
  portfolio,
  cleaningCompany,
  movingCompany,
  handyman,
  tailor,
  florist,
  massageSpa,
  petGrooming,
  drivingSchool,
  dentist,
  veterinarian,
  dietitian,
  lawyer,
  photographer,
  makeupArtist,
  musicianDj,
  personalTrainer,
  genericBusiness, // "Genel İşletme" — sektöre özel form yoksa (kırtasiye, bakkal, kuyumcu, optik vb.) buraya düşer; tek VEYA çok sayfa üretebilir (bkz. genel_isletme_form_screen.dart).
  autoRepair,
  bakery,
  electrician,
  kindergarten,
  boutiqueHotel,
  restaurant,
  furnitureDecor,
}

extension ProjectKindLabel on ProjectKind {
  String label(bool isEnglish) {
    if (isEnglish) {
      switch (this) {
        case ProjectKind.site:
          return 'Site';
        case ProjectKind.qrCode:
          return 'QR Code';
        case ProjectKind.bioLink:
          return 'Bio Link';
        case ProjectKind.businessCard:
          return 'Digital Business Card';
        case ProjectKind.kuafor:
          return 'Hair Salon / Barber';
        case ProjectKind.kafe:
          return 'Café / Restaurant';
        case ProjectKind.beautySalon:
          return 'Beauty Salon';
        case ProjectKind.clinic:
          return 'Clinic / Health';
        case ProjectKind.fitness:
          return 'Fitness Studio';
        case ProjectKind.carWash:
          return 'Car Wash / Service';
        case ProjectKind.realEstate:
          return 'Real Estate';
        case ProjectKind.portfolio:
          return 'Portfolio';
        case ProjectKind.cleaningCompany:
          return 'Cleaning Company';
        case ProjectKind.movingCompany:
          return 'Moving Company';
        case ProjectKind.handyman:
          return 'Handyman Services';
        case ProjectKind.tailor:
          return 'Tailor';
        case ProjectKind.florist:
          return 'Florist';
        case ProjectKind.massageSpa:
          return 'Massage / SPA';
        case ProjectKind.petGrooming:
          return 'Pet Groomer / Pet Shop';
        case ProjectKind.drivingSchool:
          return 'Driving School';
        case ProjectKind.dentist:
          return 'Dentist';
        case ProjectKind.veterinarian:
          return 'Veterinarian';
        case ProjectKind.dietitian:
          return 'Dietitian';
        case ProjectKind.lawyer:
          return 'Lawyer / Law Firm';
        case ProjectKind.photographer:
          return 'Photographer';
        case ProjectKind.makeupArtist:
          return 'Makeup Artist';
        case ProjectKind.musicianDj:
          return 'Musician / DJ';
        case ProjectKind.personalTrainer:
          return 'Personal Trainer';
        case ProjectKind.genericBusiness:
          return 'General Business';
        case ProjectKind.autoRepair:
          return 'Auto Repair / Tire Shop';
        case ProjectKind.bakery:
          return 'Bakery / Patisserie';
        case ProjectKind.electrician:
          return 'Electrician';
        case ProjectKind.kindergarten:
          return 'Kindergarten / Daycare';
        case ProjectKind.boutiqueHotel:
          return 'Boutique Hotel / Guesthouse';
        case ProjectKind.restaurant:
          return 'Restaurant';
        case ProjectKind.furnitureDecor:
          return 'Furniture / Decoration';
      }
    }
    switch (this) {
      case ProjectKind.site:
        return 'Site';
      case ProjectKind.qrCode:
        return 'QR Kod';
      case ProjectKind.bioLink:
        return 'Biyo Link';
      case ProjectKind.businessCard:
        return 'Dijital Kartvizit';
      case ProjectKind.kuafor:
        return 'Kuaför / Berber';
      case ProjectKind.kafe:
        return 'Kafe / Restoran';
      case ProjectKind.beautySalon:
        return 'Güzellik Salonu';
      case ProjectKind.clinic:
        return 'Klinik / Sağlık';
      case ProjectKind.fitness:
        return 'Fitness Stüdyosu';
      case ProjectKind.carWash:
        return 'Oto Yıkama / Servis';
      case ProjectKind.realEstate:
        return 'Emlak';
      case ProjectKind.portfolio:
        return 'Portfolyo';
      case ProjectKind.cleaningCompany:
        return 'Temizlik Şirketi';
      case ProjectKind.movingCompany:
        return 'Nakliyat';
      case ProjectKind.handyman:
        return 'Usta Hizmetleri';
      case ProjectKind.tailor:
        return 'Terzi';
      case ProjectKind.florist:
        return 'Çiçekçi';
      case ProjectKind.massageSpa:
        return 'Masaj / SPA';
      case ProjectKind.petGrooming:
        return 'Pet Kuaförü / Pet Shop';
      case ProjectKind.drivingSchool:
        return 'Sürücü Kursu';
      case ProjectKind.dentist:
        return 'Diş Hekimi';
      case ProjectKind.veterinarian:
        return 'Veteriner';
      case ProjectKind.dietitian:
        return 'Diyetisyen';
      case ProjectKind.lawyer:
        return 'Avukat / Hukuk Bürosu';
      case ProjectKind.photographer:
        return 'Fotoğrafçı';
      case ProjectKind.makeupArtist:
        return 'Makyaj Sanatçısı';
      case ProjectKind.musicianDj:
        return 'Müzisyen / DJ';
      case ProjectKind.personalTrainer:
        return 'Kişisel Antrenör';
      case ProjectKind.genericBusiness:
        return 'Genel İşletme';
      case ProjectKind.autoRepair:
        return 'Oto Tamirci / Lastikçi';
      case ProjectKind.bakery:
        return 'Fırın / Pastane';
      case ProjectKind.electrician:
        return 'Elektrikçi';
      case ProjectKind.kindergarten:
        return 'Anaokulu / Kreş';
      case ProjectKind.boutiqueHotel:
        return 'Butik Otel / Pansiyon';
      case ProjectKind.restaurant:
        return 'Restoran / Lokanta';
      case ProjectKind.furnitureDecor:
        return 'Mobilyacı / Dekorasyon';
    }
  }

  String get emoji {
    switch (this) {
      case ProjectKind.site:
        return '🌐';
      case ProjectKind.qrCode:
        return '🔳';
      case ProjectKind.bioLink:
        return '🔗';
      case ProjectKind.businessCard:
        return '🪪';
      case ProjectKind.kuafor:
        return '💈';
      case ProjectKind.kafe:
        return '☕';
      case ProjectKind.beautySalon:
        return '💅';
      case ProjectKind.clinic:
        return '🩺';
      case ProjectKind.fitness:
        return '🏋️';
      case ProjectKind.carWash:
        return '🚗';
      case ProjectKind.realEstate:
        return '🏠';
      case ProjectKind.portfolio:
        return '💼';
      case ProjectKind.cleaningCompany:
        return '🧹';
      case ProjectKind.movingCompany:
        return '🚚';
      case ProjectKind.handyman:
        return '🔧';
      case ProjectKind.tailor:
        return '🧵';
      case ProjectKind.florist:
        return '💐';
      case ProjectKind.massageSpa:
        return '🧖';
      case ProjectKind.petGrooming:
        return '🐾';
      case ProjectKind.drivingSchool:
        return '🚦';
      case ProjectKind.dentist:
        return '🦷';
      case ProjectKind.veterinarian:
        return '🐶';
      case ProjectKind.dietitian:
        return '🥗';
      case ProjectKind.lawyer:
        return '⚖️';
      case ProjectKind.photographer:
        return '📸';
      case ProjectKind.makeupArtist:
        return '💄';
      case ProjectKind.musicianDj:
        return '🎧';
      case ProjectKind.personalTrainer:
        return '🏃';
      case ProjectKind.genericBusiness:
        return '🏪';
      case ProjectKind.autoRepair:
        return '🛞';
      case ProjectKind.bakery:
        return '🥐';
      case ProjectKind.electrician:
        return '⚡';
      case ProjectKind.kindergarten:
        return '🧸';
      case ProjectKind.boutiqueHotel:
        return '🏨';
      case ProjectKind.restaurant:
        return '🍽️';
      case ProjectKind.furnitureDecor:
        return '🛋️';
    }
  }
}

/// Kullanıcının "Projelerim" ekranında gördüğü, kaydedilmiş bir site.
///
/// Formdan (kuafor_form_screen gibi) üretim tamamlandığında AppState
/// tarafından otomatik olarak burada bir kayıt oluşturulur/güncellenir —
/// kullanıcının ayrıca bir "kaydet" adımı atmasına gerek yoktur.
class SiteProject {
  final String id;
  String name;
  SiteMode mode;
  ProjectKind kind;
  String code; // Tek Sayfa (A) modu içeriği
  Map<String, String> files; // Çok Sayfa (B) modu dosyaları
  String? activeFileName;
  final DateTime createdAt;
  DateTime updatedAt;

  // --- Yayın (hosting) durumu ---------------------------------------------
  // Worker/hosting tarafı henüz UI'a bağlanmadı (bkz. HostingService),
  // ama alt yapı burada hazır: bir proje yayınlandığında bu üç alan
  // doldurulur, "Yayınla" butonu eklendiğinde tek yapılacak şey bunları
  // set etmek. Ziyaretçi sayısı (bkz. HostingService.fetchStats) BURADA
  // saklanmaz — her zaman worker'dan canlı okunur, sadece "bu proje
  // yayında mı" bilgisi kalıcı olarak burada tutulur.
  //
  // Worker tarafında siteId olarak PROJENİN KENDİ id'si kullanılır — ayrı
  // bir siteId alanına gerek yok.
  String? publishedSubdomain; // örn. "kuaforum" (worker'ın döndürdüğü, benzersizleştirilmiş slug)
  String? publishedUrl; // örn. "https://.../s/kuaforum/" — tam, tıklanabilir adres
  DateTime? publishedAt;

  /// GÜVENLİK (2026-09-01 eklendi): worker'daki DELETE /api/sites/:id ve
  /// yeniden yayınlama (mevcut siteId ile POST /api/publish) uçlarının
  /// gerçek sahiplik doğrulaması için kullandığı gizli token. `id`nin
  /// aksine bu değer ASLA yayınlanan sitenin HTML'ine gömülmez ve worker
  /// dışına (analytics, loglar) SIZDIRILMAZ — sadece bu cihazda saklanır.
  /// İlk yayında worker tarafından üretilip publish cevabında BİR KEZ
  /// döner (bkz. HostingService.publish). Eski kayıtlarda (bu alan
  /// eklenmeden önce yayınlanmış siteler) null'dur; worker bu durumu
  /// geriye dönük uyumluluk için hâlâ (daha zayıf bir şekilde) kabul eder
  /// — kullanıcı projeyi bir kez daha yayınladığında token otomatik atanır.
  String? ownerToken;

  /// 20.09.2026 eklendi (kanka isteği) — Google Search Console "HTML etiketi"
  /// doğrulama kodu (meta `content` değeri). GERÇEK kaynak worker'daki
  /// `sites.google_site_verification` sütunudur (bkz. widgets/search_console_sheet.dart
  /// ve services/google_verification_service.dart); burada sadece kartta/sheet'te
  /// "bağlı" durumunu göstermek için yerel bir kopya tutulur. Yayından
  /// kaldırınca worker satırı silindiği için burada da temizlenir (copyWith >
  /// unpublish). Kopyalanan (duplicateProject) projede null başlar.
  String? googleVerificationCode;

  /// 15.09.2026 eklendi (kanka isteği) — "Talepler nereye gelsin?" tercihi.
  /// 'box' (varsayılan): sadece uygulama içi Talep Kutusu. 'email': sadece
  /// mailto (bkz. HostingService.publish > leadDelivery dokümanı — Resend
  /// KULLANILMAZ, tamamen ücretsiz/sınırsız istemci taraflı mailto). 'both':
  /// ikisi de. Eski kayıtlarda alan yoktur → fromJson'da 'box'a düşer,
  /// geriye dönük tamamen uyumlu (davranış hiç değişmez).
  String leadDelivery;

  /// [leadDelivery] 'email' veya 'both' iken taleplerin mailto ile
  /// gideceği adres. Hesap e-postasından (AuthService) FARKLI olabilir —
  /// örn. bir freelancer birden fazla müşteri sitesi yönetiyorsa her site
  /// için ayrı bir e-posta girebilir (bkz. publish_sheet.dart).
  String? leadEmail;

  /// Proje şu an yayında mı (publishedUrl doluysa). Kullanıcı siteyi
  /// yayından kaldırırsa bu üç alan temizlenir (bkz. copyWith(unpublish: true)).
  bool get isPublished => publishedUrl != null && publishedUrl!.trim().isNotEmpty;

  // --- "Kendi domainimi bağla" durumu -------------------------------------
  // Worker tarafı: cloudflare/worker/src/index.mjs > handleDomainConnect/
  // handleDomainStatus/handleDomainDisconnect. Flutter tarafı:
  // lib/services/domain_service.dart + lib/screens/domain_connect_screen.dart.
  // "Yayınla" gibi bu da UI'a henüz hiçbir yerden zorunlu bağlanmadı — bir
  // proje isPublished olduğunda Projelerim'deki domain ikonuyla açılabilir.
  String? customDomain; // örn. "ahmetkuafor.com" — null = bağlı değil
  String? domainStatus; // 'pending' | 'active' | 'error' | null

  /// Domain'in EN SON "active" olduğu an — domain bağlama 1 YIL SÜRELİDİR
  /// (ürün kararı), bu yüzden domainStatus 'active' olduğunda referans
  /// alınacak başlangıç tarihi burada saklanır. Aynı domain'e tekrar
  /// bağlanma/yenileme SharedPreferences'a persist edilirken bu alan
  /// güncellenir (bkz. AppState.markProjectDomainStatus / renewProjectDomain).
  /// Bu süre HEM istemci tarafında (uygulama içi hatırlatma + gösterge)
  /// HEM DE worker tarafında GERÇEKTEN uygulanır: worker aynı değeri kendi
  /// D1 kaydında (sites.domain_connected_at) tutar ve süresi dolan bir
  /// custom domain'i serveCustomDomainSite'ta artık servis etmez (bkz.
  /// cloudflare/worker/src/index.mjs). renewProjectDomain worker'a
  /// POST /api/domains/:siteId/renew çağrısı yapar; buradaki alan de o
  /// isteğin worker'dan dönen sonucuyla güncellenir — yerelde tek başına
  /// ileri alınamaz.
  DateTime? domainConnectedAt;

  /// Domain bağlantısının 1 yıllık süresinin dolacağı tarih.
  DateTime? get domainExpiresAt =>
      domainConnectedAt?.add(const Duration(days: 365));

  /// 1 yıllık süre dolmuş mu (sadece connectedAt varsa anlamlı).
  ///
  /// 06.09.2026 DÜZELTİLDİ (kanka bulgusu — kod incelemesi) — ESKİDEN
  /// doğrudan `DateTime.now()` (CİHAZ saati) kullanıyordu: kullanıcı
  /// telefonun saatini geri alırsa bu proje SONSUZA DEK "süresi dolmamış"
  /// görünmeye devam ediyordu — bu da LocalGenerationHelper'daki çok-sayfa
  /// üretim kilidinin (bkz. FreePlanPageLimitService) yerel olarak
  /// atlatılabilmesi anlamına geliyordu. Artık `ServerTimeService.now()`
  /// kullanılıyor (bkz. o dosyanın dokümanı) — worker'la en az bir kez
  /// konuşulduysa (domain/mini-paket/satın-alma doğrulama çağrılarının
  /// HERHANGİ biri) worker'ın Date header'ından hesaplanan gerçek saate
  /// göre karar verilir; hiç konuşulmadıysa (skew=0) davranış eskisiyle
  /// birebir aynıdır — regresyon yok.
  bool get isDomainExpired {
    final exp = domainExpiresAt;
    return exp != null && ServerTimeService.now().isAfter(exp);
  }

  /// Süre dolana kaç gün kaldığı (negatifse süresi dolmuş demektir).
  /// connectedAt hiç set edilmediyse (eski kayıt / hiç bağlanmamış) null.
  int? get domainDaysRemaining {
    final exp = domainExpiresAt;
    if (exp == null) return null;
    return exp.difference(ServerTimeService.now()).inDays;
  }

  /// Domain bağlantısı tamamlanmış mı (Cloudflare SSL/hostname doğrulaması bitti).
  bool get isDomainConnected => customDomain != null && domainStatus == 'active';

  /// 04.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği).
  /// PROJE BAZLI premium durumu: bu proje "Premium (Özel Domain) Planı"na mı
  /// sahip. Ürün kararı: premium = yıllık özel domain bağlama paketi, ve bu
  /// paket SİTEYE özeldir (hesaba değil) — bir kullanıcının 3 sitesi olup
  /// sadece birine domain bağlaması normal. Bu yüzden ayrı bir alan/bayrak
  /// EKLEMİYORUZ, zaten var olan isDomainConnected'ı semantik bir isimle
  /// tekrar sunuyoruz — domain bağlama akışı canlıya alındığında (satın
  /// alma → domainStatus='active') bu proje otomatik premium sayılacak,
  /// başka hiçbir yerde ekstra bir "premium'a çevir" adımına gerek yok.
  ///
  /// 05.09.2026 DÜZELTİLDİ (kanka bulgusu) — ESKİDEN sadece
  /// `isDomainConnected`'a bakıyordu, yani `domainStatus == 'active'` olduğu
  /// sürece 1 yıllık süre dolsa BİLE bu proje sonsuza dek premium sayılmaya
  /// devam ediyordu (Talep Kutusu kilidi, watermark, Projelerim'deki premium
  /// şeridi hep açık kalıyordu) — oysa worker tarafında
  /// serveCustomDomainSite süresi dolan custom domain'i GERÇEKTEN kesiyordu.
  /// `domainStatus` süre dolduğunda kendiliğinden değişmiyor (expiry, D1'de
  /// ayrı hesaplanan bir alan) — o yüzden burada da `isDomainExpired`'ı
  /// devreye sokmak gerekiyor: süresi dolmuş bir domain artık premium
  /// SAYILMAZ, kullanıcı "Bağlantıyı 1 Yıl Uzat"a basıp domainStatus'u
  /// (worker üzerinden) tazeleyene kadar bu proje free plan kısıtlamalarına
  /// geri düşer.
  bool get isPremium =>
      (isDomainConnected && !isDomainExpired) ||
      isMiniPackageActive ||
      isSubscriptionQuotaActive;

  /// 05.09.2026 eklendi (kanka isteği) — "1 Aylık Mini Paket"
  /// (kProductMiniPackage) satın alındığı an. Domain'deki domainConnectedAt
  /// ile AYNI mantık, sadece süresi 365 değil 30 gündür (bkz.
  /// miniPackageExpiresAt) ve ayrı bir üründür — domain bağlamayla hiçbir
  /// ilişkisi yok, bir proje aynı anda ikisine de sahip olabilir (isPremium
  /// ikisinden herhangi biri geçerliyse true döner).
  DateTime? miniPackageActivatedAt;

  /// Mini paketin 1 aylık süresinin dolacağı tarih.
  DateTime? get miniPackageExpiresAt =>
      miniPackageActivatedAt?.add(const Duration(days: 30));

  /// 1 aylık süre dolmuş mu (sadece activatedAt varsa anlamlı).
  /// 06.09.2026 DÜZELTİLDİ — bkz. isDomainExpired'daki AYNI gerekçe/açıklama
  /// (ServerTimeService.now() ile clock-skew düzeltmesi).
  bool get isMiniPackageExpired {
    final exp = miniPackageExpiresAt;
    return exp != null && ServerTimeService.now().isAfter(exp);
  }

  /// Süre dolana kaç gün kaldığı (negatifse süresi dolmuş demektir).
  /// activatedAt hiç set edilmediyse (hiç satın alınmamış) null.
  int? get miniPackageDaysRemaining {
    final exp = miniPackageExpiresAt;
    if (exp == null) return null;
    return exp.difference(ServerTimeService.now()).inDays;
  }

  /// Mini paket şu an aktif mi (satın alınmış VE süresi dolmamış).
  bool get isMiniPackageActive =>
      miniPackageActivatedAt != null && !isMiniPackageExpired;

  /// 15.09.2026 eklendi (kanka isteği) — AYLIK ABONELİK (Mini/Freelancer/
  /// Freelancer Max — bkz. billing_constants.dart) paketlerinden biri bu
  /// projeye bir kota slotu AYIRDIYSA (bkz. AppState.assignProjectToSubscriptionQuota)
  /// o anki abonelik bitiş tarihinin bir KOPYASI buraya yazılır. `miniPackageActivatedAt`ten
  /// FARKI: süre BURADA sabit 30 gün DEĞİL, hesabın o anki gerçek abonelik
  /// bitiş tarihidir (yenilenince AppState.refreshSubscriptionStatus her
  /// kota içindeki projede bunu TAZELER) — kaynak HESAP bazlı olduğu için
  /// bu alan projeye sadece bir ÖNBELLEK (cache): SiteProject'in kendi
  /// başına (AppState'e ihtiyaç duymadan) isPremium hesaplayabilmesi için
  /// var, tek doğruluk kaynağı DEĞİL.
  DateTime? subscriptionQuotaExpiresAt;

  /// Abonelik kota slotu şu an aktif mi (atanmış VE süresi dolmamış).
  /// isMiniPackageExpired ile AYNI clock-skew gerekçesi (ServerTimeService).
  bool get isSubscriptionQuotaActive {
    final exp = subscriptionQuotaExpiresAt;
    return exp != null && ServerTimeService.now().isBefore(exp);
  }

  /// 18.09.2026 eklendi (kanka isteği — "ücretsiz planda yayınlanan
  /// siteler 6 ay güncellenmezse yayından kalkar" uyarısı, bkz.
  /// guide_dialog.dart en üstündeki uyarı kutusu) — [domainExpiresAt] /
  /// [miniPackageExpiresAt] ile BİREBİR AYNI desen: bir referans tarih
  /// (burada [publishedAt]) alınır, üzerine sabit bir süre (burada 180
  /// gün = 6 ay) eklenir. SADECE ücretsiz plandaki (isPremium == false)
  /// yayındaki siteler için ANLAMLIDIR — Projelerim ekranında da sadece o
  /// durumda gösterilir (bkz. projects_screen.dart > _ProjectCard).
  ///
  /// Bu sayaç HER republish'te otomatik SIFIRLANIR: markProjectPublished
  /// her çağrıldığında (ilk yayın VEYA "tekrar yayınla") publishedAt'i
  /// DateTime.now()'a günceller (bkz. AppState.markProjectPublished) — bu
  /// yüzden kılavuzdaki "süresi dolmadan tekrar yayınlayın" davranışı ek
  /// bir koda gerek kalmadan zaten bu satır sayesinde çalışır.
  ///
  /// ÖNEMLİ SINIRLAMA: bu SADECE istemci tarafında bir GÖSTERGE/sayaç
  /// hesaplamasıdır (domainExpiresAt/miniPackageExpiresAt'in AKSİNE).
  /// Sitenin süresi dolduğunda GERÇEKTEN sunucudan kaldırılması
  /// (worker/D1 tarafında zamanlanmış bir görev) bu dosyanın kapsamı
  /// DIŞINDADIR — Flutter istemcisi böyle bir zamanlayıcıyı tek başına
  /// çalıştıramaz; sunucu tarafında (cloudflare/worker) ayrıca kurulması
  /// gerekir.
  DateTime? get freeTierPublishExpiresAt =>
      (isPublished && publishedAt != null)
          ? publishedAt!.add(const Duration(days: 180))
          : null;

  /// 6 aylık süre dolmuş mu (sadece ücretsiz plandaki yayında bir site
  /// için anlamlı — bkz. [freeTierPublishExpiresAt] dokümanı).
  bool get isFreeTierPublishExpired {
    final exp = freeTierPublishExpiresAt;
    return exp != null && ServerTimeService.now().isAfter(exp);
  }

  /// Süre dolana kaç gün kaldığı (negatifse süresi dolmuş demektir).
  /// publishedAt hiç set edilmediyse (yayında değil) null.
  int? get freeTierPublishDaysRemaining {
    final exp = freeTierPublishExpiresAt;
    if (exp == null) return null;
    return exp.difference(ServerTimeService.now()).inDays;
  }

  /// 05.09.2026 eklendi — kProductConnectDomain satın alma akışı kuruldu
  /// (bkz. billing_constants.dart, widgets/domain_purchase_sheet.dart).
  /// Kullanıcı bu proje için domain bağlama ücretini ÖDEDİ ama
  /// DomainService.connect() çağrısı henüz worker'a ULAŞMADI/BAŞARISIZ
  /// OLDU (ağ hatası, timeout vb.) — true olduğu sürece
  /// domain_connect_screen.dart, "Bağla"ya bir daha basıldığında satın
  /// alma sheet'ini TEKRAR GÖSTERMEZ, doğrudan DomainService.connect'i
  /// dener (bkz. AppState.hasPendingDomainConnectPurchase). Bu, ödeme
  /// başarılı olduktan SONRA bağlanma isteği başarısız olursa kullanıcının
  /// İKİNCİ KEZ ÖDEME YAPMASINI önlemek için var — publish akışındaki
  /// extraPublishCredits'in (bkz. AppState.grantPublishRight) çözdüğü AYNI
  /// sorunun SİTE BAZLI, tek satın almalık bir versiyonu. DomainService.connect
  /// worker'a başarıyla ulaştığında (bkz. AppState.markProjectDomainStatus)
  /// bu bayrak false'a döner — "hak" o an tüketilmiş sayılır, bağlantı
  /// sonradan süresi dolup sökülürse (bkz. isDomainExpired/cron sweep)
  /// tekrar bağlamak için YENİDEN satın alınması gerekir.
  bool domainConnectPurchasePending = false;

  /// 05.09.2026 eklendi (kanka kararı — "yenileme de ücretli olacak") —
  /// `domainConnectPurchasePending` ile BİREBİR AYNI gerekçe/desen, sadece
  /// İLK bağlama için değil, "Bağlantıyı 1 Yıl Uzat" (renewProjectDomain)
  /// için: kullanıcı ödemeyi yaptı ama worker'a giden `/renew` isteği henüz
  /// ULAŞMADI/BAŞARISIZ OLDU — true olduğu sürece domain_connect_screen.dart,
  /// "Uzat"a bir daha basıldığında satın alma sheet'ini TEKRAR GÖSTERMEZ,
  /// doğrudan renewProjectDomain'i dener (bkz.
  /// AppState.hasPendingDomainRenewPurchase). renewProjectDomain worker'a
  /// başarıyla ulaştığında bu bayrak false'a döner — hak o an tüketilmiş
  /// sayılır, BİR SONRAKİ yenileme için tekrar satın alınması gerekir.
  bool domainRenewPurchasePending = false;

  // --- "Sitora ile üretildi" rozetini kaldırma durumu ----------------------
  // SİTE BAZLI, tek seferlik satın alma modeli: her SiteProject kendi
  // watermarkRemoved bayrağını taşır — "hesaptaki her site" değil, SADECE bu
  // proje için geçerlidir. true olduğunda:
  //   1) AppState.updateGeneratedCode/updateGeneratedFiles/... bu projeye
  //      yazarken WatermarkService.apply hiç çağrılmaz (yeni üretimlerde
  //      rozet baştan eklenmez),
  //   2) zaten üretilmiş (rozet gömülü) içerikten rozet
  //      WatermarkService.strip/stripFromFiles ile geriye dönük temizlenir
  //      (bkz. AppState.removeWatermarkForProject).
  // Varsayılan false: yeni/eski TÜM projeler rozetli başlar, satın alma
  // tamamlanınca bu alan true'ya çevrilir. Geri dönüşü yok (tek seferlik) —
  // TEK İSTİSNA aşağıdaki `watermarkRemovedByDomain` alanıdır.
  bool watermarkRemoved;

  /// 05.09.2026 eklendi (kanka kararı) — `watermarkRemoved` true olma
  /// SEBEBİNİ ayırt eder: gerçek bir rozet-kaldırma satın alması mı
  /// (kProductRemoveWatermark / kProductDownloadNoWatermark), yoksa SADECE
  /// aktif özel domain paketinin (kProductConnectDomain) YAN ETKİSİ mi
  /// (bkz. AppState.markProjectDomainStatus). Bu ikisi ARTIK aynı şey
  /// DEĞİL: gerçek satın alma kalıcıdır, ama domain paketinin "bedava"
  /// verdiği rozet kaldırma sadece paket AKTİFKEN geçerlidir — domain 1
  /// yıllık süresi dolup ücretsiz katmana düşünce (isDomainExpired) rozet
  /// GERİ GELİR (bkz. AppState.revertExpiredDomainWatermarks). true
  /// SADECE watermarkRemoved=true VE bu kaldırma hiç ayrıca (gerçek parayla)
  /// satın alınmadıysa anlamlıdır; kullanıcı sonradan rozeti ayrıca
  /// satın alırsa (removeWatermarkForProject viaDomain:false ile tekrar
  /// çağrılır) bu alan false'a çevrilip kalıcı hale gelir. Eski kayıtlarda
  /// alan yoktur → fromJson'da false'a düşer (geriye dönük uyumlu: eski
  /// bir domain kaydında rozet kaldırma zaten kalıcı sayılmaya devam eder,
  /// geçmişe dönük kimsenin rozeti aniden geri gelmez).
  bool watermarkRemovedByDomain;

  /// 16.09.2026 eklendi (kanka isteği — "domainQuota kullanılmıyor" fix'i).
  /// true ise: bu sitenin ŞU ANKİ customDomain bağlantısı, kProductConnectDomain
  /// ile tek seferlik SATIN ALINMADI — hesabın aylık aboneliğinin domain
  /// kotasından (bkz. SubscriptionTierInfo.domainQuota) ÜCRETSİZ verildi.
  /// watermarkRemovedByDomain'den BAĞIMSIZ bir alan: rozet zaten ayrıca
  /// subscriptionQuotaExpiresAt/watermarkRemovedBySubscription üzerinden
  /// yönetiliyor (bkz. o alanların dokümanı) — bu bayrak SADECE "bu domain
  /// bağlantısının parasını kim ödedi" sorusuna cevap verir, AppState.
  /// canConnectDomainViaSubscription/assignDomainQuota/unassignDomainQuota
  /// tarafından kullanılır. ÖNEMLİ: paid bir domain'in AKSİNE, "Siteyi
  /// Devret" akışında bu true ise domain GERÇEKTEN SÖKÜLÜR (bkz.
  /// AppState.claimTransferredProject) — çünkü hiç kimse bu domain'i
  /// STANDALONE ödemedi, yeni sahip hiçbir hak devralmıyor.
  bool domainViaSubscription;

  /// 05.09.2026 eklendi (kanka isteği) — `watermarkRemovedByDomain` ile AYNI
  /// mantık, kaynağı domain paketi DEĞİL "1 Aylık Mini Paket"
  /// (kProductMiniPackage) olan rozet kaldırmaları için. true SADECE
  /// watermarkRemoved=true VE bu kaldırma hiç ayrıca (gerçek parayla, kalıcı
  /// olarak) satın alınmadıysa anlamlıdır. Mini paketin 1 aylık süresi
  /// dolunca (isMiniPackageExpired) rozet geri gelir (bkz.
  /// AppState.revertExpiredMiniPackages) — tıpkı domain süresi dolduğunda
  /// olduğu gibi. Kullanıcı rozeti sonradan AYRICA satın alırsa
  /// (removeWatermarkForProject viaDomain:false, viaMiniPackage:false ile
  /// tekrar çağrılır) bu alan false'a çevrilip kalıcı hale gelir.
  bool watermarkRemovedByMiniPackage;

  /// 15.09.2026 eklendi (kanka isteği) — `watermarkRemovedByMiniPackage` ile
  /// BİREBİR AYNI mantık, kaynağı bu kez aylık ABONELİK kota slotu. true
  /// SADECE watermarkRemoved=true VE bu kaldırma hiç ayrıca (gerçek parayla,
  /// kalıcı olarak) satın alınmadıysa anlamlıdır. Slot süresi dolunca/kota
  /// dışı kalınca (bkz. AppState.revertExpiredSubscriptionQuota) rozet geri
  /// gelir.
  bool watermarkRemovedBySubscription;

  // --- Site yayın HAKKI (ücretlendirme) durumu ----------------------------
  // İlk site yayını hesap başına ÜCRETSİZ, ikinci ve sonraki her YENİ site
  // için (aynı fiyattan) satın alma gerekir (bkz. AppState.canPublishProject
  // / AppState.grantPublishRight, lib/services/billing_service.dart >
  // kProductPublishSlot). Bu bayrak, bu PROJE için o hakkın (ücretsiz ya da
  // satın alınarak) zaten kullanılıp kullanılmadığını tutar — true olduktan
  // sonra proje yayından kaldırılıp tekrar yayınlansa (unpublish/republish)
  // veya güncellense BİLE tekrar ödeme istenmez; hak PROJEYE kalıcı olarak
  // bağlanmıştır. Varsayılan false: yeni/eski TÜM projeler bu hakkı henüz
  // kullanmamış kabul edilir.
  bool publishRightGranted;

  // --- "Düzenle" akışı için form alanı verisi -----------------------------
  // 26.08.2026 eklendi. Bir proje ilk kez üretildiğinde/güncellendiğinde
  // (bkz. AppState._touchQtProjectFromCurrent), o formun HAM alan
  // değerlerinin (isim, telefon, galeri, hizmetler vb.) anlık görüntüsü
  // BURAYA da yazılır — sadece geçici AppState.qtFormData slotuna değil.
  // Böylece Projelerim'den (farklı bir oturumda) açılan bir proje için de
  // "Düzenle" formu DOLU açılabilir (bkz. AppState.openQtProject).
  // ProjectKind.site (Builder Pro) ve ProjectKind.qrCode için formu yoktur,
  // bu alan onlarda hep null kalır — zararsızdır.
  Map<String, dynamic>? formData;

  // --- Uygulama içinden düzenlenebilirlik --------------------------------
  // 27.08.2026 eklendi. Normal akışta (kullanıcı kendi formunu doldurup
  // ürettiği HER site) bu alan true'dur ve "Düzenle" butonu (bkz.
  // preview_screen.dart > _openEditForm) normal çalışır.
  //
  // ADMIN PANELİNDEN ENJEKTE EDİLEN siteler için (bkz. worker
  // handleAdminProjectCreate > injectProjectFormHtml) BİLEREK false olarak
  // gelir: bu içerik müşterinin kendi formundan DEĞİL, developer'ın kendi
  // AI/şablon sistemiyle üretilmiştir; formData da genelde yoktur/eksiktir.
  // Müşteri "Düzenle"ye basıp formu doldurursa mevcut (elle hazırlanmış)
  // HTML tamamen silinip forma göre YENİDEN üretilen jenerik bir HTML ile
  // değiştirilir — yani "Düzenle" burada özellik değil, veri kaybı riski
  // taşır. Bu yüzden bu tür projelerde "Düzenle" butonu HİÇ gösterilmez
  // (bkz. AppState.qtCurrentEditableInApp / preview_screen.dart).
  //
  // Eski kayıtlarda alan yoktur → fromJson'da true'ya düşer (geriye dönük
  // tamamen uyumlu, hiçbir mevcut projenin "Düzenle" butonu kaybolmaz).
  bool editableInApp;

  // --- İndirme hakkı (28.08.2026 eklendi, 28.08.2026'da revize edildi) ----
  // İndirme artık ücretsiz değil (bkz. widgets/download_purchase_sheet.dart).
  // Bu alan true olduğunda kullanıcı bu projeyi SINIRSIZ tekrar indirebilir
  // (kProductDownloadWatermarked VEYA kombo kProductDownloadNoWatermark bir
  // kez satın alınmış demektir). Dosyanın rozetli mi rozetsiz mi ineceği
  // AYRI bir bayrağa (watermarkRemoved) bakar — bu ikisi BİRBİRİNDEN
  // BAĞIMSIZDIR: watermarkRemoved=true olması downloadPurchased'ı otomatik
  // true YAPMAZ, kullanıcı indirme hakkını AYRICA satın almalıdır (bkz.
  // AppState.canDownloadFreely). Eski kayıtlarda alan yoktur → fromJson'da
  // false'a düşer (kimse geriye dönük "bedava" hak kazanmaz).
  bool downloadPurchased;

  SiteProject({
    required this.id,
    required this.name,
    required this.mode,
    this.kind = ProjectKind.site,
    required this.code,
    required this.files,
    required this.activeFileName,
    required this.createdAt,
    required this.updatedAt,
    this.publishedSubdomain,
    this.publishedUrl,
    this.publishedAt,
    this.ownerToken,
    this.googleVerificationCode,
    this.leadDelivery = 'box',
    this.leadEmail,
    this.customDomain,
    this.domainStatus,
    this.domainConnectedAt,
    this.domainConnectPurchasePending = false,
    this.domainRenewPurchasePending = false,
    this.miniPackageActivatedAt,
    this.subscriptionQuotaExpiresAt,
    this.watermarkRemoved = false,
    this.watermarkRemovedByDomain = false,
    this.domainViaSubscription = false,
    this.watermarkRemovedByMiniPackage = false,
    this.watermarkRemovedBySubscription = false,
    this.publishRightGranted = false,
    this.formData,
    this.editableInApp = true,
    this.downloadPurchased = false,
  });

  SiteProject copyWith({
    String? name,
    SiteMode? mode,
    ProjectKind? kind,
    String? code,
    Map<String, String>? files,
    String? activeFileName,
    DateTime? updatedAt,
    String? publishedSubdomain,
    String? publishedUrl,
    DateTime? publishedAt,
    String? ownerToken,
    String? googleVerificationCode,
    // true: kodu temizler (bağlantıyı kes). null + false: değiştirme.
    bool clearGoogleVerification = false,
    String? leadDelivery,
    // formData'daki AYNI "hiç verilmedi" deseni: null hem "değiştirme" hem
    // "temizle" anlamına gelebileceğinden Object? kullanılıyor — bilinçli
    // olarak `leadEmail: null` geçilirse alan gerçekten temizlenir.
    Object? leadEmail = _unsetLeadEmail,
    // true verilirse publish alanları (subdomain/url/tarih) ne verilmiş
    // olursa olsun temizlenir — "yayından kaldır" akışı için.
    bool unpublish = false,
    String? customDomain,
    String? domainStatus,
    DateTime? domainConnectedAt,
    // true verilirse domain alanları ne verilmiş olursa olsun temizlenir —
    // "domaini kaldır" akışı için (bkz. DomainService.disconnect).
    bool clearDomain = false,
    bool? domainConnectPurchasePending,
    bool? domainRenewPurchasePending,
    // Object? kullanılıyor çünkü null hem "değiştirme" (varsayılan _unset)
    // hem de "mini paketi tamamen kaldır" (bilinçli olarak null geçilirse)
    // anlamına gelebilir — formData'daki AYNI desen (bkz. yukarısı).
    Object? miniPackageActivatedAt = _unsetMiniPackageActivatedAt,
    // AYNI "hiç verilmedi" deseni — bkz. miniPackageActivatedAt açıklaması,
    // birebir aynı gerekçe (abonelik kota slotunu BİLEREK null geçerek
    // temizlemek mümkün olmalı — bkz. AppState.unassignProjectFromSubscriptionQuota).
    Object? subscriptionQuotaExpiresAt = _unsetSubscriptionQuotaExpiresAt,
    bool? watermarkRemoved,
    bool? watermarkRemovedByDomain,
    bool? domainViaSubscription,
    bool? watermarkRemovedByMiniPackage,
    bool? watermarkRemovedBySubscription,
    bool? publishRightGranted,
    bool? editableInApp,
    bool? downloadPurchased,
    // formData'yı BİLEREK Object? ile alıyoruz (String?/Map? gibi diğer
    // alanlardan farklı): null hem "değiştirme" hem "temizle" anlamına
    // gelebileceğinden iki durumu ayırt etmek gerekiyor. Parametre HİÇ
    // verilmezse (varsayılan `_unset`) mevcut değer korunur; bilinçli
    // olarak `formData: null` geçilirse alan gerçekten temizlenir.
    Object? formData = _unsetFormData,
  }) {
    return SiteProject(
      id: id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      kind: kind ?? this.kind,
      code: code ?? this.code,
      files: files ?? this.files,
      activeFileName: activeFileName ?? this.activeFileName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedSubdomain: unpublish ? null : (publishedSubdomain ?? this.publishedSubdomain),
      publishedUrl: unpublish ? null : (publishedUrl ?? this.publishedUrl),
      publishedAt: unpublish ? null : (publishedAt ?? this.publishedAt),
      // Yayından kaldırmada BİLEREK temizlenmiyor: aynı projeyi tekrar
      // yayınlarken worker'a hâlâ AYNI token gönderilip site "sahiplik"
      // devam ettirilmeli (yeniden yayınlama = ownership devam ediyor demek).
      ownerToken: ownerToken ?? this.ownerToken,
      googleVerificationCode: (unpublish || clearGoogleVerification)
          ? null
          : (googleVerificationCode ?? this.googleVerificationCode),
      leadDelivery: leadDelivery ?? this.leadDelivery,
      leadEmail: identical(leadEmail, _unsetLeadEmail)
          ? this.leadEmail
          : leadEmail as String?,
      customDomain: clearDomain ? null : (customDomain ?? this.customDomain),
      domainStatus: clearDomain ? null : (domainStatus ?? this.domainStatus),
      domainConnectedAt:
          clearDomain ? null : (domainConnectedAt ?? this.domainConnectedAt),
      domainConnectPurchasePending:
          domainConnectPurchasePending ?? this.domainConnectPurchasePending,
      domainRenewPurchasePending:
          domainRenewPurchasePending ?? this.domainRenewPurchasePending,
      miniPackageActivatedAt: identical(miniPackageActivatedAt, _unsetMiniPackageActivatedAt)
          ? this.miniPackageActivatedAt
          : miniPackageActivatedAt as DateTime?,
      subscriptionQuotaExpiresAt: identical(
              subscriptionQuotaExpiresAt, _unsetSubscriptionQuotaExpiresAt)
          ? this.subscriptionQuotaExpiresAt
          : subscriptionQuotaExpiresAt as DateTime?,
      watermarkRemoved: watermarkRemoved ?? this.watermarkRemoved,
      watermarkRemovedByDomain:
          watermarkRemovedByDomain ?? this.watermarkRemovedByDomain,
      domainViaSubscription: domainViaSubscription ?? this.domainViaSubscription,
      watermarkRemovedByMiniPackage:
          watermarkRemovedByMiniPackage ?? this.watermarkRemovedByMiniPackage,
      watermarkRemovedBySubscription:
          watermarkRemovedBySubscription ?? this.watermarkRemovedBySubscription,
      publishRightGranted: publishRightGranted ?? this.publishRightGranted,
      editableInApp: editableInApp ?? this.editableInApp,
      downloadPurchased: downloadPurchased ?? this.downloadPurchased,
      formData: identical(formData, _unsetFormData)
          ? this.formData
          : formData as Map<String, dynamic>?,
    );
  }

  /// copyWith'teki formData parametresi için "hiç verilmedi" işaretçisi —
  /// bkz. yukarıdaki açıklama.
  static const Object _unsetFormData = Object();

  /// copyWith'teki miniPackageActivatedAt parametresi için "hiç verilmedi"
  /// işaretçisi — bkz. yukarıdaki açıklama.
  static const Object _unsetMiniPackageActivatedAt = Object();

  /// copyWith'teki subscriptionQuotaExpiresAt parametresi için "hiç
  /// verilmedi" işaretçisi — bkz. yukarıdaki açıklama.
  static const Object _unsetSubscriptionQuotaExpiresAt = Object();

  /// copyWith'teki leadEmail parametresi için "hiç verilmedi" işaretçisi.
  static const Object _unsetLeadEmail = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode.name,
        'kind': kind.name,
        'code': code,
        'files': files,
        'activeFileName': activeFileName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (publishedSubdomain != null) 'publishedSubdomain': publishedSubdomain,
        if (publishedUrl != null) 'publishedUrl': publishedUrl,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        if (ownerToken != null) 'ownerToken': ownerToken,
        if (googleVerificationCode != null) 'googleVerificationCode': googleVerificationCode,
        if (leadDelivery != 'box') 'leadDelivery': leadDelivery,
        if (leadEmail != null) 'leadEmail': leadEmail,
        if (customDomain != null) 'customDomain': customDomain,
        if (domainStatus != null) 'domainStatus': domainStatus,
        if (domainConnectedAt != null)
          'domainConnectedAt': domainConnectedAt!.toIso8601String(),
        if (domainConnectPurchasePending)
          'domainConnectPurchasePending': domainConnectPurchasePending,
        if (domainRenewPurchasePending)
          'domainRenewPurchasePending': domainRenewPurchasePending,
        if (miniPackageActivatedAt != null)
          'miniPackageActivatedAt': miniPackageActivatedAt!.toIso8601String(),
        if (subscriptionQuotaExpiresAt != null)
          'subscriptionQuotaExpiresAt': subscriptionQuotaExpiresAt!.toIso8601String(),
        'watermarkRemoved': watermarkRemoved,
        if (watermarkRemovedByDomain) 'watermarkRemovedByDomain': watermarkRemovedByDomain,
        if (domainViaSubscription) 'domainViaSubscription': domainViaSubscription,
        if (watermarkRemovedByMiniPackage)
          'watermarkRemovedByMiniPackage': watermarkRemovedByMiniPackage,
        if (watermarkRemovedBySubscription)
          'watermarkRemovedBySubscription': watermarkRemovedBySubscription,
        'publishRightGranted': publishRightGranted,
        if (formData != null) 'formData': formData,
        'editableInApp': editableInApp,
        'downloadPurchased': downloadPurchased,
      };

  factory SiteProject.fromJson(Map<String, dynamic> json) {
    return SiteProject(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Proje',
      mode: SiteMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => SiteMode.single,
      ),
      // Eski kayıtlarda 'kind' alanı yok, ya da eski bir sürümden kalma
      // bir kind olabilir — geriye dönük uyumluluk için bulunamazsa
      // normal 'site' kabul edilir.
      kind: ProjectKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ProjectKind.site,
      ),
      code: (json['code'] as String?) ?? '',
      files: ((json['files'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
      activeFileName: json['activeFileName'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      // Eski kayıtlarda bu üç alan hiç yok — o zaman proje yayınlanmamış
      // kabul edilir (isPublished false döner), geriye dönük tamamen uyumlu.
      publishedSubdomain: json['publishedSubdomain'] as String?,
      publishedUrl: json['publishedUrl'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      // Eski kayıtlarda bu alan hiç yok — null kalır, worker bir sonraki
      // yayınlamada yeni bir token üretip döner (bkz. yukarıdaki alan açıklaması).
      ownerToken: json['ownerToken'] as String?,
      googleVerificationCode: json['googleVerificationCode'] as String?,
      // Eski kayıtlarda bu iki alan hiç yok — 'box' (mevcut/tek davranış)
      // ve null'a düşer, geriye dönük tamamen uyumlu.
      leadDelivery: (json['leadDelivery'] as String?) ?? 'box',
      leadEmail: json['leadEmail'] as String?,
      customDomain: json['customDomain'] as String?,
      domainStatus: json['domainStatus'] as String?,
      // Eski kayıtlarda bu alan hiç yok (1 yıl süre sınırı SONRADAN eklendi):
      // null kalırsa domainExpiresAt/isDomainExpired de null/false döner,
      // yani geriye dönük olarak "süresiz bağlıymış gibi" davranır — bir
      // sonraki reconnect/renew'da tarih set edilir.
      domainConnectedAt: json['domainConnectedAt'] != null
          ? DateTime.tryParse(json['domainConnectedAt'] as String)
          : null,
      // Eski kayıtlarda bu alan hiç yok — false kabul edilir (bekleyen bir
      // ödenmiş-ama-kullanılmamış domain hakkı yok), geriye dönük uyumlu.
      domainConnectPurchasePending:
          json['domainConnectPurchasePending'] as bool? ?? false,
      // Eski kayıtlarda bu alan hiç yok (yenileme ücretlendirmesi SONRADAN
      // eklendi) — false kabul edilir, geriye dönük uyumlu.
      domainRenewPurchasePending:
          json['domainRenewPurchasePending'] as bool? ?? false,
      // Eski kayıtlarda bu alan hiç yok (mini paket SONRADAN eklendi) —
      // null kalır, yani mini paket hiç satın alınmamış kabul edilir
      // (isMiniPackageActive/isPremium bundan etkilenmez).
      miniPackageActivatedAt: json['miniPackageActivatedAt'] != null
          ? DateTime.tryParse(json['miniPackageActivatedAt'] as String)
          : null,
      // Eski kayıtlarda bu alan hiç yok (abonelik SONRADAN eklendi) — null
      // kalır, yani proje hiçbir abonelik kota slotuna atanmamış kabul
      // edilir (isSubscriptionQuotaActive/isPremium bundan etkilenmez).
      subscriptionQuotaExpiresAt: json['subscriptionQuotaExpiresAt'] != null
          ? DateTime.tryParse(json['subscriptionQuotaExpiresAt'] as String)
          : null,
      // Eski kayıtlarda bu alan hiç yok — false (rozetli) kabul edilir,
      // geriye dönük tamamen uyumlu.
      watermarkRemoved: json['watermarkRemoved'] as bool? ?? false,
      // Eski kayıtlarda bu alan hiç yok — false kabul edilir, yani eski bir
      // domain-kaynaklı rozet kaldırma bile bu güncellemeden SONRA kalıcı
      // sayılmaya devam eder (geçmişe dönük kimsenin rozeti geri gelmez;
      // sadece BUNDAN SONRA yeni domain aktivasyonlarıyla verilen rozet
      // kaldırmalar domain süresine bağlı olur).
      watermarkRemovedByDomain: json['watermarkRemovedByDomain'] as bool? ?? false,
      domainViaSubscription: json['domainViaSubscription'] as bool? ?? false,
      // Aynı gerekçe — mini paket kaynaklı rozet kaldırmalar için.
      watermarkRemovedByMiniPackage:
          json['watermarkRemovedByMiniPackage'] as bool? ?? false,
      // Aynı gerekçe — abonelik kota slotu kaynaklı rozet kaldırmalar için.
      watermarkRemovedBySubscription:
          json['watermarkRemovedBySubscription'] as bool? ?? false,
      // Eski kayıtlarda bu alan hiç yok. false (hak henüz kullanılmadı)
      // kabul edilir — bu, bu güncellemeden ÖNCE zaten yayınlanmış siteleri
      // olan kullanıcılar için sorun YARATMAZ çünkü canPublishProject
      // sadece YENİ bir yayınlama denemesinde kontrol edilir; zaten yayında
      // olan bir site bu bayrağa bakılmaksızın yayında kalmaya devam eder.
      publishRightGranted: json['publishRightGranted'] as bool? ?? false,
      // Eski kayıtlarda bu alan hiç yok — null kalırsa "Düzenle" formu boş
      // açılır (eski davranışa döner), yeni kayıtlar için doludur.
      formData: json['formData'] != null
          ? Map<String, dynamic>.from(json['formData'] as Map)
          : null,
      // Eski kayıtlarda bu alan hiç yok — yok sayılırsa true (düzenlenebilir)
      // kabul edilir, geriye dönük tamamen uyumlu: mevcut hiçbir kullanıcı
      // projesinin "Düzenle" butonu bu değişiklikle kaybolmaz. Sadece admin
      // panelinden BUNDAN SONRA enjekte edilen projeler false ile gelir
      // (bkz. worker > handleAdminProjectCreate).
      editableInApp: json['editableInApp'] as bool? ?? true,
      downloadPurchased: json['downloadPurchased'] as bool? ?? false,
    );
  }

  /// Projelerim listesinde satırın altında gösterilecek kısa özet.
  String summary(bool isEnglish) => mode == SiteMode.multi
      ? (isEnglish ? '${files.length} pages' : '${files.length} sayfa')
      : (isEnglish ? 'Single page' : 'Tek sayfa');
}
