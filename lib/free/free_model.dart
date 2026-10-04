import 'dart:convert';

/// 02.10.2026 eklendi — "Sıfırdan Site Oluştur" (serbest sürükle-bırak builder).
///
/// Veri modeli:
///   FreeSite  -> ayarlar (tema/font/dil/iletişim) + sayfalar
///   FreePage  -> ad + SEO açıklaması + SIRALI bölümler
///   FreeSection:
///     'canvas'  : serbest ızgara alanı (48 kolon x 8px satır), içinde FreeElement'ler
///     'block'   : hazır bölüm (galeri/video/hizmet/SSS) — extra_page_blocks.dart ile
///                 AYNI blok JSON'u, aynı HTML üreticisi
///     'contact' : iletişim butonları + talep formu (contactBlockHtml)
///
/// Görseller Sitora kuralıyla `data:image/...;base64,...` metni olarak tutulur
/// (UserDataService._stripImages ve PublishImageService bunu zaten tanır).

const int kCols = 48;
const double kRow = 8;
const int kMinCanvasRows = 12;

/// Sayfa başına toplam görsel sınırı (galeri 12 + kapak + logo karşılığı).
const int kMaxImagesPerPage = 14;

/// Yayın sayfa dosyası sınırı (worker: PUBLISH_MAX_FILE_BYTES = 8 MB).
const int kPageFileLimitBytes = 8 * 1024 * 1024;

/// Başlık / yazı boyutları (px) — editör ve HTML AYNI tabloyu kullanır.
const List<int> kTitleSizes = [26, 34, 46];
const List<int> kTextSizes = [14, 16, 20];

/// Kullanıcının seçebileceği yazı boyutu aralıkları (px, 1'er adım).
const int kMinTextPx = 10;
const int kMaxTextPx = 72;
const int kMinTitlePx = 12;
const int kMaxTitlePx = 120;
const int kMinSectionPx = 10;
const int kMaxSectionPx = 40;

enum FType { title, text, button, image, shape, social }

class FreeElement {
  String id;
  FType type;
  int c, r, w, h;
  int? mo; // mobil sıra (null ise c/r'den türetilir)
  String text;
  int color; // yazı rengi ARGB (0 = tema rengi)
  int bg; // dolgu ARGB (0 = tema varsayılanı / yok)
  String link;
  String? img; // data URI
  String platform; // whatsapp|instagram|tiktok|facebook
  int size; // ESKİ kayıtlar için: 0 küçük, 1 normal, 2 büyük ([fs] yoksa bundan türetilir)
  int fs; // yazı boyutu px (0 = [size]'dan türet)
  int align; // 0 sol, 1 orta, 2 sağ

  FreeElement({
    required this.id,
    required this.type,
    this.c = 0,
    this.r = 0,
    this.w = 6,
    this.h = 2,
    this.mo,
    this.text = '',
    this.color = 0,
    this.bg = 0,
    this.link = '#',
    this.img,
    this.platform = 'whatsapp',
    this.size = 1,
    this.fs = 0,
    this.align = 1,
  });

  /// Gerçekte kullanılan yazı boyutu (px) — editör ve HTML AYNI değeri kullanır.
  int get fontPx {
    if (fs > 0) return fs;
    return type == FType.title ? kTitleSizes[size] : kTextSizes[size];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        't': type.name,
        'c': c,
        'r': r,
        'w': w,
        'h': h,
        'mo': mo,
        'text': text,
        'color': color,
        'bg': bg,
        'link': link,
        'img': img,
        'platform': platform,
        'size': size,
        'fs': fs,
        'align': align,
      };

  factory FreeElement.fromJson(Map<String, dynamic> j) => FreeElement(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: FType.values.firstWhere(
          (t) => t.name == j['t'],
          orElse: () => FType.text,
        ),
        c: (j['c'] as num?)?.toInt() ?? 0,
        r: (j['r'] as num?)?.toInt() ?? 0,
        w: (j['w'] as num?)?.toInt() ?? 6,
        h: (j['h'] as num?)?.toInt() ?? 2,
        mo: (j['mo'] as num?)?.toInt(),
        text: j['text']?.toString() ?? '',
        color: (j['color'] as num?)?.toInt() ?? 0,
        bg: (j['bg'] as num?)?.toInt() ?? 0,
        link: j['link']?.toString() ?? '#',
        img: j['img']?.toString(),
        platform: j['platform']?.toString() ?? 'whatsapp',
        size: ((j['size'] as num?)?.toInt() ?? 1).clamp(0, 2).toInt(),
        fs: ((j['fs'] as num?)?.toInt() ?? 0).clamp(0, 400).toInt(),
        align: ((j['align'] as num?)?.toInt() ?? 1).clamp(0, 2).toInt(),
      );

  int get sortKey => mo ?? (r * kCols + c);
}

class FreeSection {
  String id;
  String kind; // canvas | block | contact
  int bg; // bölüm arka planı ARGB (0 = tema)
  int fs; // hazır bölümlerde yazı boyutu px (0 = otomatik/tema)
  int tc; // hazır bölümlerde yazı rengi ARGB (0 = otomatik)
  List<FreeElement> els; // canvas
  Map<String, dynamic> block; // block: extra_page_blocks.dart blok JSON'u

  FreeSection({
    required this.id,
    required this.kind,
    this.bg = 0,
    this.fs = 0,
    this.tc = 0,
    List<FreeElement>? els,
    Map<String, dynamic>? block,
  })  : els = els ?? [],
        block = block ?? {};

  bool get isCanvas => kind == 'canvas';
  bool get isBlock => kind == 'block';
  bool get isContact => kind == 'contact';
  String get blockType => block['type']?.toString() ?? '';

  /// Canvas yüksekliği (satır): en alttaki öğe + 4 satır boşluk, en az 12.
  int get rows {
    var m = 0;
    for (final e in els) {
      if (e.r + e.h > m) m = e.r + e.h;
    }
    final v = m + 4;
    return v < kMinCanvasRows ? kMinCanvasRows : v;
  }

  List<FreeElement> get ordered => [...els]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'bg': bg,
        'fs': fs,
        'tc': tc,
        'els': els.map((e) => e.toJson()).toList(),
        'block': block,
      };

  factory FreeSection.fromJson(Map<String, dynamic> j) => FreeSection(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        kind: j['kind']?.toString() ?? 'canvas',
        bg: (j['bg'] as num?)?.toInt() ?? 0,
        fs: ((j['fs'] as num?)?.toInt() ?? 0).clamp(0, 200).toInt(),
        tc: (j['tc'] as num?)?.toInt() ?? 0,
        els: (j['els'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => FreeElement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        block: j['block'] is Map ? Map<String, dynamic>.from(j['block'] as Map) : {},
      );
}

class FreePage {
  String name;
  String desc; // meta description (SEO)
  List<FreeSection> sections;
  FreePage(this.name, {this.desc = '', List<FreeSection>? sections}) : sections = sections ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'desc': desc,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory FreePage.fromJson(Map<String, dynamic> j) => FreePage(
        j['name']?.toString() ?? 'Sayfa',
        desc: j['desc']?.toString() ?? '',
        sections: (j['sections'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => FreeSection.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// Sayfadaki toplam görsel sayısı (öğe görselleri + galeri/tek görsel blokları).
  int get imageCount {
    var n = 0;
    for (final s in sections) {
      if (s.isCanvas) {
        for (final e in s.els) {
          if (e.type == FType.image && (e.img ?? '').isNotEmpty) n++;
        }
      } else if (s.isBlock) {
        final imgs = s.block['images'];
        if (imgs is List) n += imgs.length;
      }
    }
    return n;
  }

  /// Sayfaya gömülen görsellerin yaklaşık bayt boyutu (data URI uzunluğu).
  int get embeddedBytes {
    var n = 0;
    for (final s in sections) {
      if (s.isCanvas) {
        for (final e in s.els) {
          n += (e.img ?? '').length;
        }
      } else if (s.isBlock) {
        final imgs = s.block['images'];
        if (imgs is List) {
          for (final i in imgs) {
            if (i is Map) n += (i['url']?.toString() ?? '').length;
          }
        }
      }
    }
    return n;
  }
}

class FreeSite {
  String name;
  String themeId;
  Map<String, String>? customTheme;
  String fontPackageId;
  Map<String, String>? customFontPackage;
  String density;
  String lang;
  String phone;
  String whatsapp;
  String instagram;
  List<FreePage> pages;

  FreeSite({
    this.name = 'Sitem',
    this.themeId = 'clean_light',
    this.customTheme,
    this.fontPackageId = 'modern_sade',
    this.customFontPackage,
    this.density = 'normal',
    this.lang = 'tr',
    this.phone = '',
    this.whatsapp = '',
    this.instagram = '',
    List<FreePage>? pages,
  }) : pages = pages ?? [FreePage('Ana Sayfa')];

  Map<String, dynamic> toJson() => {
        'name': name,
        'themeId': themeId,
        'customTheme': customTheme,
        'fontPackageId': fontPackageId,
        'customFontPackage': customFontPackage,
        'density': density,
        'lang': lang,
        'phone': phone,
        'whatsapp': whatsapp,
        'instagram': instagram,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory FreeSite.fromJson(Map<String, dynamic> j) {
    Map<String, String>? strMap(dynamic raw) => raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        : null;
    final pages = (j['pages'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => FreePage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return FreeSite(
      name: j['name']?.toString() ?? 'Sitem',
      themeId: j['themeId']?.toString() ?? 'clean_light',
      customTheme: strMap(j['customTheme']),
      fontPackageId: j['fontPackageId']?.toString() ?? 'modern_sade',
      customFontPackage: strMap(j['customFontPackage']),
      density: j['density']?.toString() ?? 'normal',
      lang: j['lang']?.toString() ?? 'tr',
      phone: j['phone']?.toString() ?? '',
      whatsapp: j['whatsapp']?.toString() ?? '',
      instagram: j['instagram']?.toString() ?? '',
      pages: pages.isEmpty ? [FreePage('Ana Sayfa')] : pages,
    );
  }

  /// Düzenle akışı için JSON-uyumlu ham form verisi (bkz. qt_form_data_codec).
  Map<String, dynamic> toFormData() => {'freeSite': jsonDecode(jsonEncode(toJson()))};

  static FreeSite? fromFormData(Map<String, dynamic>? data) {
    final raw = data?['freeSite'];
    if (raw is! Map) return null;
    return FreeSite.fromJson(Map<String, dynamic>.from(raw));
  }
}

/// Basit benzersiz id üretici (öğe/bölüm/sayfa).
int _idSeq = 0;
String newFreeId() => '${DateTime.now().microsecondsSinceEpoch}${_idSeq++}';
