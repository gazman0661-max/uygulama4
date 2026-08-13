import '../state/app_state.dart';

/// "Projelerim" ekranında ayırt etmek için proje türü.
/// AI kaldırıldıktan sonra: her sektör kendi HTML generator fonksiyonunu
/// kullanır (bkz. lib/templates/html/), ama "Projelerim" listesindeki
/// gösterim/etiket/ikon mantığı için hepsi burada ayrı bir kind olarak
/// tanımlı kalıyor.
enum ProjectKind {
  site, // genel amaçlı / eski AI ile üretilmiş kayıtlar için geriye dönük uyumluluk
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
}

extension ProjectKindLabel on ProjectKind {
  String get label {
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
  });

  SiteProject copyWith({
    String? name,
    SiteMode? mode,
    ProjectKind? kind,
    String? code,
    Map<String, String>? files,
    String? activeFileName,
    DateTime? updatedAt,
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
    );
  }

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
      // Eski kayıtlarda 'kind' alanı yok, ya da eski AI sürümünden kalma
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
    );
  }

  /// Projelerim listesinde satırın altında gösterilecek kısa özet.
  String get summary => mode == SiteMode.multi ? '${files.length} sayfa' : 'Tek sayfa';
}
