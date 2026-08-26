import '../state/app_state.dart';

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
  bool get isDomainExpired {
    final exp = domainExpiresAt;
    return exp != null && DateTime.now().isAfter(exp);
  }

  /// Süre dolana kaç gün kaldığı (negatifse süresi dolmuş demektir).
  /// connectedAt hiç set edilmediyse (eski kayıt / hiç bağlanmamış) null.
  int? get domainDaysRemaining {
    final exp = domainExpiresAt;
    if (exp == null) return null;
    return exp.difference(DateTime.now()).inDays;
  }

  /// Domain bağlantısı tamamlanmış mı (Cloudflare SSL/hostname doğrulaması bitti).
  bool get isDomainConnected => customDomain != null && domainStatus == 'active';

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
  // tamamlanınca bu alan true'ya çevrilir. Geri dönüşü yok (tek seferlik).
  bool watermarkRemoved;

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
    this.customDomain,
    this.domainStatus,
    this.domainConnectedAt,
    this.watermarkRemoved = false,
    this.publishRightGranted = false,
    this.formData,
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
    // true verilirse publish alanları (subdomain/url/tarih) ne verilmiş
    // olursa olsun temizlenir — "yayından kaldır" akışı için.
    bool unpublish = false,
    String? customDomain,
    String? domainStatus,
    DateTime? domainConnectedAt,
    // true verilirse domain alanları ne verilmiş olursa olsun temizlenir —
    // "domaini kaldır" akışı için (bkz. DomainService.disconnect).
    bool clearDomain = false,
    bool? watermarkRemoved,
    bool? publishRightGranted,
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
      customDomain: clearDomain ? null : (customDomain ?? this.customDomain),
      domainStatus: clearDomain ? null : (domainStatus ?? this.domainStatus),
      domainConnectedAt:
          clearDomain ? null : (domainConnectedAt ?? this.domainConnectedAt),
      watermarkRemoved: watermarkRemoved ?? this.watermarkRemoved,
      publishRightGranted: publishRightGranted ?? this.publishRightGranted,
      formData: identical(formData, _unsetFormData)
          ? this.formData
          : formData as Map<String, dynamic>?,
    );
  }

  /// copyWith'teki formData parametresi için "hiç verilmedi" işaretçisi —
  /// bkz. yukarıdaki açıklama.
  static const Object _unsetFormData = Object();

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
        if (customDomain != null) 'customDomain': customDomain,
        if (domainStatus != null) 'domainStatus': domainStatus,
        if (domainConnectedAt != null)
          'domainConnectedAt': domainConnectedAt!.toIso8601String(),
        'watermarkRemoved': watermarkRemoved,
        'publishRightGranted': publishRightGranted,
        if (formData != null) 'formData': formData,
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
      customDomain: json['customDomain'] as String?,
      domainStatus: json['domainStatus'] as String?,
      // Eski kayıtlarda bu alan hiç yok (1 yıl süre sınırı SONRADAN eklendi):
      // null kalırsa domainExpiresAt/isDomainExpired de null/false döner,
      // yani geriye dönük olarak "süresiz bağlıymış gibi" davranır — bir
      // sonraki reconnect/renew'da tarih set edilir.
      domainConnectedAt: json['domainConnectedAt'] != null
          ? DateTime.tryParse(json['domainConnectedAt'] as String)
          : null,
      // Eski kayıtlarda bu alan hiç yok — yok sayılırsa false (rozetli)
      // kabul edilir, geriye dönük tamamen uyumlu.
      watermarkRemoved: json['watermarkRemoved'] as bool? ?? false,
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
    );
  }

  /// Projelerim listesinde satırın altında gösterilecek kısa özet.
  String summary(bool isEnglish) => mode == SiteMode.multi
      ? (isEnglish ? '${files.length} pages' : '${files.length} sayfa')
      : (isEnglish ? 'Single page' : 'Tek sayfa');
}
