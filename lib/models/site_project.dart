import '../state/app_state.dart';
import '../services/server_time_service.dart';

enum ProjectKind {
  site,
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
  genericBusiness,
  autoRepair,
  bakery,
  electrician,
  kindergarten,
  boutiqueHotel,
  restaurant,
  furnitureDecor,
  freeSite,
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
        case ProjectKind.freeSite:
          return 'Free Site';
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
      case ProjectKind.freeSite:
        return 'Serbest Site';
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
      case ProjectKind.freeSite:
        return '🧩';
    }
  }
}

class SiteProject {
  final String id;
  String name;
  SiteMode mode;
  ProjectKind kind;
  String code;
  Map<String, String> files;
  String? activeFileName;
  final DateTime createdAt;
  DateTime updatedAt;

  String? publishedSubdomain;
  String? publishedUrl;
  DateTime? publishedAt;

  String? ownerToken;

  String? googleVerificationCode;

  String leadDelivery;

  String? leadEmail;

  bool get isPublished => publishedUrl != null && publishedUrl!.trim().isNotEmpty;

  String? customDomain;
  String? domainStatus;

  DateTime? domainConnectedAt;

  DateTime? get domainExpiresAt =>
      domainConnectedAt?.add(const Duration(days: 365));

  bool get isDomainExpired {
    final exp = domainExpiresAt;
    return exp != null && ServerTimeService.now().isAfter(exp);
  }

  int? get domainDaysRemaining {
    final exp = domainExpiresAt;
    if (exp == null) return null;
    return exp.difference(ServerTimeService.now()).inDays;
  }

  bool get isDomainConnected => customDomain != null && domainStatus == 'active';

  bool get isPremium =>
      (isDomainConnected && !isDomainExpired) ||
      isMiniPackageActive ||
      isSubscriptionQuotaActive;

  DateTime? miniPackageActivatedAt;

  DateTime? get miniPackageExpiresAt =>
      miniPackageActivatedAt?.add(const Duration(days: 30));

  bool get isMiniPackageExpired {
    final exp = miniPackageExpiresAt;
    return exp != null && ServerTimeService.now().isAfter(exp);
  }

  int? get miniPackageDaysRemaining {
    final exp = miniPackageExpiresAt;
    if (exp == null) return null;
    return exp.difference(ServerTimeService.now()).inDays;
  }

  bool get isMiniPackageActive =>
      miniPackageActivatedAt != null && !isMiniPackageExpired;

  DateTime? subscriptionQuotaExpiresAt;

  bool get isSubscriptionQuotaActive {
    final exp = subscriptionQuotaExpiresAt;
    return exp != null && ServerTimeService.now().isBefore(exp);
  }

  DateTime? get freeTierPublishExpiresAt =>
      (isPublished && publishedAt != null)
          ? publishedAt!.add(const Duration(days: 180))
          : null;

  bool get isFreeTierPublishExpired {
    final exp = freeTierPublishExpiresAt;
    return exp != null && ServerTimeService.now().isAfter(exp);
  }

  int? get freeTierPublishDaysRemaining {
    final exp = freeTierPublishExpiresAt;
    if (exp == null) return null;
    return exp.difference(ServerTimeService.now()).inDays;
  }

  bool domainConnectPurchasePending = false;

  bool domainRenewPurchasePending = false;

  bool watermarkRemoved;

  bool watermarkRemovedByDomain;

  bool domainViaSubscription;

  bool watermarkRemovedByMiniPackage;

  bool watermarkRemovedBySubscription;

  bool publishRightGranted;

  Map<String, dynamic>? formData;

  bool editableInApp;

  bool downloadPurchased;

  bool downloadWatermarkFree;

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
    this.downloadWatermarkFree = false,
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
    bool clearGoogleVerification = false,
    String? leadDelivery,
    Object? leadEmail = _unsetLeadEmail,
    bool unpublish = false,
    String? customDomain,
    String? domainStatus,
    DateTime? domainConnectedAt,
    bool clearDomain = false,
    bool? domainConnectPurchasePending,
    bool? domainRenewPurchasePending,
    Object? miniPackageActivatedAt = _unsetMiniPackageActivatedAt,
    Object? subscriptionQuotaExpiresAt = _unsetSubscriptionQuotaExpiresAt,
    bool? watermarkRemoved,
    bool? watermarkRemovedByDomain,
    bool? domainViaSubscription,
    bool? watermarkRemovedByMiniPackage,
    bool? watermarkRemovedBySubscription,
    bool? publishRightGranted,
    bool? editableInApp,
    bool? downloadPurchased,
    bool? downloadWatermarkFree,
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
      downloadWatermarkFree: downloadWatermarkFree ?? this.downloadWatermarkFree,
      formData: identical(formData, _unsetFormData)
          ? this.formData
          : formData as Map<String, dynamic>?,
    );
  }

  static const Object _unsetFormData = Object();

  static const Object _unsetMiniPackageActivatedAt = Object();

  static const Object _unsetSubscriptionQuotaExpiresAt = Object();

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
        'downloadWatermarkFree': downloadWatermarkFree,
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
      publishedSubdomain: json['publishedSubdomain'] as String?,
      publishedUrl: json['publishedUrl'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      ownerToken: json['ownerToken'] as String?,
      googleVerificationCode: json['googleVerificationCode'] as String?,
      leadDelivery: (json['leadDelivery'] as String?) ?? 'box',
      leadEmail: json['leadEmail'] as String?,
      customDomain: json['customDomain'] as String?,
      domainStatus: json['domainStatus'] as String?,
      domainConnectedAt: json['domainConnectedAt'] != null
          ? DateTime.tryParse(json['domainConnectedAt'] as String)
          : null,
      domainConnectPurchasePending:
          json['domainConnectPurchasePending'] as bool? ?? false,
      domainRenewPurchasePending:
          json['domainRenewPurchasePending'] as bool? ?? false,
      miniPackageActivatedAt: json['miniPackageActivatedAt'] != null
          ? DateTime.tryParse(json['miniPackageActivatedAt'] as String)
          : null,
      subscriptionQuotaExpiresAt: json['subscriptionQuotaExpiresAt'] != null
          ? DateTime.tryParse(json['subscriptionQuotaExpiresAt'] as String)
          : null,
      watermarkRemoved: json['watermarkRemoved'] as bool? ?? false,
      watermarkRemovedByDomain: json['watermarkRemovedByDomain'] as bool? ?? false,
      domainViaSubscription: json['domainViaSubscription'] as bool? ?? false,
      watermarkRemovedByMiniPackage:
          json['watermarkRemovedByMiniPackage'] as bool? ?? false,
      watermarkRemovedBySubscription:
          json['watermarkRemovedBySubscription'] as bool? ?? false,
      publishRightGranted: json['publishRightGranted'] as bool? ?? false,
      formData: json['formData'] != null
          ? Map<String, dynamic>.from(json['formData'] as Map)
          : null,
      editableInApp: json['editableInApp'] as bool? ?? true,
      downloadPurchased: json['downloadPurchased'] as bool? ?? false,
      downloadWatermarkFree: json['downloadWatermarkFree'] as bool? ?? false,
    );
  }

  String summary(bool isEnglish) => mode == SiteMode.multi
      ? (isEnglish ? '${files.length} pages' : '${files.length} sayfa')
      : (isEnglish ? 'Single page' : 'Tek sayfa');
}
