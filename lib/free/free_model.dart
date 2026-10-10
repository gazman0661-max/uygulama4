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

/// band    : tam genişlikte arka plan şeridi (her zaman en arkada; öğeler üstünde serbestçe durur)
/// block   : hazır blok (galeri/video/hizmet/SSS) — öğe olarak tuvale konur, [FreeElement.block] JSON'u
/// contact : iletişim butonları + talep formu
enum FType { title, text, button, image, shape, social, band, block, contact }

/// Bölümlerden tuvale geçerken hazır blokların varsayılan yüksekliği (satır, 8px).
/// Bloklar içerikle büyür; masaüstünde kutu yüksekliğini kullanıcı ayarlar.
const Map<String, int> kBlockDefaultRows = {'gallery': 56, 'video': 44, 'services': 40, 'faq': 36, 'map': 48};
const int kContactDefaultRows = 48;

int _autoTextOn(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  final lum = 0.299 * r + 0.587 * g + 0.114 * b;
  return lum > 150 ? 0xFF111111 : 0xFFFFFFFF;
}

class FreeElement {
  String id;
  FType type;
  int c, r, w, h;
  int? mo; // mobil sıra (null ise c/r'den türetilir)

  /// AYRI MOBİL DÜZEN (05.10.2026): sayfada [FreePage.mobileCustom] açıkken telefonda kullanılan
  /// konum/boyut (aynı 48 kolon x 8px ızgara). null ise masaüstü değerleri kullanılır.
  int? mc, mr, mw, mh;
  int mfs; // mobil yazı boyutu px (0 = masaüstüyle aynı)
  String text;
  int color; // yazı rengi ARGB (0 = tema rengi)
  int bg; // dolgu ARGB (0 = tema varsayılanı / yok)
  String link;
  String? img; // data URI
  String platform; // whatsapp|instagram|tiktok|facebook
  int size; // ESKİ kayıtlar için: 0 küçük, 1 normal, 2 büyük ([fs] yoksa bundan türetilir)
  int fs; // yazı boyutu px (0 = [size]'dan türet)
  int align; // 0 sol, 1 orta, 2 sağ
  Map<String, dynamic> block; // yalnız FType.block: extra_page_blocks.dart blok JSON'u

  /// 08.10.2026: BÖLÜM kimliği. Hazır yerleşim / şablon bölümüyle birlikte eklenen tüm öğeler (şerit dahil)
  /// aynı değeri taşır; "Bölümü sil" bunu kullanır. Eski kayıtlarda null (o zaman konumdan türetilir).
  String? grp;

  FreeElement({
    required this.id,
    required this.type,
    this.c = 0,
    this.r = 0,
    this.w = 6,
    this.h = 2,
    this.mo,
    this.mc,
    this.mr,
    this.mw,
    this.mh,
    this.mfs = 0,
    this.text = '',
    this.color = 0,
    this.bg = 0,
    this.link = '#',
    this.img,
    this.platform = 'whatsapp',
    this.size = 1,
    this.fs = 0,
    this.align = 1,
    Map<String, dynamic>? block,
    this.grp,
  }) : block = block ?? {};

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
        if (mr != null) ...{'mc': mc, 'mr': mr, 'mw': mw, 'mh': mh},
        if (mfs > 0) 'mfs': mfs,
        'text': text,
        'color': color,
        'bg': bg,
        'link': link,
        'img': img,
        'platform': platform,
        'size': size,
        'fs': fs,
        'align': align,
        if (block.isNotEmpty) 'block': block,
        if (grp != null) 'grp': grp,
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
        mc: (j['mc'] as num?)?.toInt(),
        mr: (j['mr'] as num?)?.toInt(),
        mw: (j['mw'] as num?)?.toInt(),
        mh: (j['mh'] as num?)?.toInt(),
        mfs: ((j['mfs'] as num?)?.toInt() ?? 0).clamp(0, 400).toInt(),
        text: j['text']?.toString() ?? '',
        color: (j['color'] as num?)?.toInt() ?? 0,
        bg: (j['bg'] as num?)?.toInt() ?? 0,
        link: j['link']?.toString() ?? '#',
        img: j['img']?.toString(),
        platform: j['platform']?.toString() ?? 'whatsapp',
        size: ((j['size'] as num?)?.toInt() ?? 1).clamp(0, 2).toInt(),
        fs: ((j['fs'] as num?)?.toInt() ?? 0).clamp(0, 400).toInt(),
        align: ((j['align'] as num?)?.toInt() ?? 1).clamp(0, 2).toInt(),
        block: j['block'] is Map ? Map<String, dynamic>.from(j['block'] as Map) : null,
        grp: j['grp']?.toString(),
      );

  /// Ayrı mobil düzende geometri: [m] true ve mobil değer varsa o, yoksa masaüstü değeri.
  bool get hasMobileGeo => mr != null && mc != null && mw != null && mh != null;
  int cOn(bool m) => m && hasMobileGeo ? mc! : c;
  int rOn(bool m) => m && hasMobileGeo ? mr! : r;
  int wOn(bool m) => m && hasMobileGeo ? mw! : w;
  int hOn(bool m) => m && hasMobileGeo ? mh! : h;
  int fontPxOn(bool m) => m && mfs > 0 ? mfs : fontPx;

  void setC(bool m, int v) {
    if (m && hasMobileGeo) {
      mc = v;
    } else {
      c = v;
    }
  }

  void setR(bool m, int v) {
    if (m && hasMobileGeo) {
      mr = v;
    } else {
      r = v;
    }
  }

  void setW(bool m, int v) {
    if (m && hasMobileGeo) {
      mw = v;
    } else {
      w = v;
    }
  }

  void setH(bool m, int v) {
    if (m && hasMobileGeo) {
      mh = v;
    } else {
      h = v;
    }
  }

  /// Konuma göre sıra (mobilde varsayılan: yukarıdan aşağı, soldan sağa).
  int get posKey => r * kCols + c;
  int get sortKey => mo ?? posKey;
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

  /// [rows]'un ayrı mobil düzen karşılığı.
  int rowsOn(bool m) {
    if (!m) return rows;
    var mx = 0;
    for (final e in els) {
      final b = e.rOn(true) + e.hOn(true);
      if (b > mx) mx = b;
    }
    final v = mx + 4;
    return v < kMinCanvasRows ? kMinCanvasRows : v;
  }

  /// Mobil sıra (bantlar hariç). Tüm öğelerin elle sırası ([FreeElement.mo]) varsa o,
  /// yoksa konuma göre (yukarıdan aşağı, soldan sağa).
  bool get manualOrder {
    final l = els.where((e) => e.type != FType.band).toList();
    return l.isNotEmpty && l.every((e) => e.mo != null);
  }

  List<FreeElement> get ordered {
    final l = els.where((e) => e.type != FType.band).toList();
    final manual = manualOrder;
    l.sort((a, b) => manual ? a.mo!.compareTo(b.mo!) : a.posKey.compareTo(b.posKey));
    return l;
  }

  /// Öğenin dikey merkezini içeren şeridin (band) rengi; yoksa 0. Birden çok şeritte
  /// listede en sonraki kazanır. Editör ve yayın AYNI kuralı kullanır.
  FreeElement? bandOf(FreeElement e, {bool mobile = false}) {
    if (e.type == FType.band) return null;
    final cy = e.rOn(mobile) + e.hOn(mobile) / 2;
    FreeElement? hit;
    for (final b in els) {
      if (b.type == FType.band && b.bg != 0 && cy >= b.rOn(mobile) && cy < b.rOn(mobile) + b.hOn(mobile)) {
        hit = b;
      }
    }
    return hit;
  }

  int bandBgFor(FreeElement e, {bool mobile = false}) => bandOf(e, mobile: mobile)?.bg ?? 0;

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

  /// Her zaman TEK serbest alan (canvas) bölümü: sayfa tek büyük tuvaldir.
  /// Eski kayıtlardaki çok bölümlü sayfalar yüklenirken [flatten] ile tuvale çevrilir.
  List<FreeSection> sections;

  /// true: telefonda ayrı bir mobil düzen (elle konum/boyut, [FreeElement.mc] vb.) kullanılır;
  /// false: öğeler konuma/elle sıraya göre alt alta dizilir. Mobil geometri false iken de saklanır
  /// (geri dönüp tekrar açınca kaybolmaz).
  bool mobileCustom;

  FreePage(this.name, {this.desc = '', List<FreeSection>? sections, this.mobileCustom = false})
      : sections = sections ?? [] {
    flatten();
  }

  /// Sayfanın tuvali.
  FreeSection get canvas {
    if (sections.length != 1 || !sections.first.isCanvas) flatten();
    return sections.first;
  }

  void setSections(List<FreeSection> list) {
    sections = list;
    flatten();
  }

  /// Bölüm listesini tek tuvale çevirir (idempotent). Bölüm arka planı -> şerit (band) öğesi;
  /// hazır bloklar/iletişim -> tuvalde öğe (tam genişlik, varsayılan yükseklik).
  void flatten() {
    if (sections.length == 1 && sections.first.isCanvas && sections.first.bg == 0) return;
    if (sections.isEmpty) {
      sections = [FreeSection(id: newFreeId(), kind: 'canvas')];
      return;
    }
    final out = <FreeElement>[];
    _mergeInto(out, sections, 0);
    sections = [FreeSection(id: newFreeId(), kind: 'canvas', els: out)];
  }

  /// Verilen bölümleri tuvalin ALTINA ekler (hazır yerleşimler). Yeni öğeler listenin sonuna gelir.
  void appendSections(List<FreeSection> secs) {
    final c = canvas;
    var bottom = 0;
    for (final e in c.els) {
      if (e.type == FType.band) continue;
      if (e.r + e.h > bottom) bottom = e.r + e.h;
    }
    _mergeInto(c.els, secs, c.els.isEmpty ? 0 : bottom + 1);
  }

  static void _mergeInto(List<FreeElement> out, List<FreeSection> secs, int startRow) {
    var row = startRow;
    for (final s in secs) {
      if (s.isCanvas) {
        final h = s.rows;
        final gid = newFreeId(); // bu bölümün tüm öğeleri aynı grp'yi taşır
        if (s.bg != 0) {
          out.add(FreeElement(id: newFreeId(), type: FType.band, c: 0, w: kCols, r: row, h: h, bg: s.bg, grp: gid));
        }
        final autoCol = s.bg != 0 ? _autoTextOn(s.bg) : 0;
        for (final e in s.els) {
          e.r += row;
          e.mo = null;
          e.grp = gid;
          if (autoCol != 0 && e.color == 0 && (e.type == FType.title || e.type == FType.text)) {
            e.color = autoCol;
          }
          out.add(e);
        }
        row += h;
      } else if (s.isBlock) {
        final h = kBlockDefaultRows[s.blockType] ?? 40;
        out.add(FreeElement(
          id: newFreeId(),
          type: FType.block,
          c: 0,
          w: kCols,
          r: row,
          h: h,
          bg: s.bg,
          color: s.tc,
          fs: s.fs,
          block: s.block,
        ));
        row += h;
      } else if (s.isContact) {
        out.add(FreeElement(
          id: newFreeId(),
          type: FType.contact,
          c: 0,
          w: kCols,
          r: row,
          h: kContactDefaultRows,
          bg: s.bg,
          color: s.tc,
          fs: s.fs,
        ));
        row += kContactDefaultRows;
      }
    }
  }

  /// Mobil geometrisi olmayan öğelere mobil konum verir (idempotent).
  /// • Hiçbir öğede yoksa: hepsi otomatik sıraya (konum/elle sıra) göre alt alta, kenarlardan
  ///   2 kolon boşlukla dizilir; şerit, içindeki öğeleri kapsayacak şekilde mobilde yeniden çizilir.
  /// • Bazılarında varsa (sonradan eklenen öğeler): eksik olanlar mobil düzenin ALTINA eklenir.
  void ensureMobileGeometry() {
    final c = canvas;
    final nonBand = c.els.where((e) => e.type != FType.band).toList();
    final missing = c.els.where((e) => !e.hasMobileGeo).toList();
    if (missing.isEmpty) return;
    final fresh = !c.els.any((e) => e.hasMobileGeo);
    final List<FreeElement> order;
    if (fresh) {
      order = c.ordered;
    } else {
      order = missing.where((e) => e.type != FType.band).toList();
      order.sort((a, b) => a.posKey.compareTo(b.posKey));
    }
    var row = 1;
    if (!fresh) {
      for (final e in nonBand) {
        if (!e.hasMobileGeo) continue;
        final b = e.mr! + e.mh!;
        if (b + 1 > row) row = b + 1;
      }
    }
    for (final e in order) {
      e.mc = 2;
      e.mw = kCols - 4;
      e.mr = row;
      e.mh = e.h;
      row += e.h + 2;
    }
    // Şeritler: masaüstünde içinde kalan öğelerin mobil aralığını kapsar; üyesi yoksa sona eklenir.
    for (final b in c.els.where((e) => e.type == FType.band && !e.hasMobileGeo)) {
      int? top, bot;
      for (final e in nonBand) {
        if (c.bandOf(e) != b || !e.hasMobileGeo) continue;
        top = top == null || e.mr! < top ? e.mr! : top;
        final eb = e.mr! + e.mh!;
        bot = bot == null || eb > bot ? eb : bot;
      }
      b.mc = 0;
      b.mw = kCols;
      if (top != null && bot != null) {
        b.mr = top > 0 ? top - 1 : 0;
        b.mh = bot - b.mr! + 1;
      } else {
        b.mr = row;
        b.mh = b.h;
        row += b.h + 2;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'desc': desc,
        if (mobileCustom) 'mcustom': true,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory FreePage.fromJson(Map<String, dynamic> j) => FreePage(
        j['name']?.toString() ?? 'Sayfa',
        desc: j['desc']?.toString() ?? '',
        mobileCustom: j['mcustom'] == true,
        sections: (j['sections'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => FreeSection.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// Sayfadaki toplam görsel sayısı (resim öğeleri + galeri blokları).
  int get imageCount {
    var n = 0;
    for (final e in canvas.els) {
      if (e.type == FType.image && (e.img ?? '').isNotEmpty) {
        n++;
      } else if (e.type == FType.block) {
        final imgs = e.block['images'];
        if (imgs is List) n += imgs.length;
      }
    }
    return n;
  }

  /// Sayfaya gömülen görsellerin yaklaşık bayt boyutu (data URI uzunluğu).
  int get embeddedBytes {
    var n = 0;
    for (final e in canvas.els) {
      if (e.type == FType.image) {
        n += (e.img ?? '').length;
      } else if (e.type == FType.block) {
        final imgs = e.block['images'];
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
