import 'free_model.dart';

/// Hazır sayfa şablonları: bir sayfanın bölüm listesini üretir.
/// Görsel içermez (kullanıcı kendi fotoğraflarını ekler) — boyut/limit riski yok.
class FreeTemplateInfo {
  final String id;
  final String emoji;
  final String title; // TR
  final String subtitle; // TR
  const FreeTemplateInfo(this.id, this.emoji, this.title, this.subtitle);
}

const List<FreeTemplateInfo> kFreeTemplates = [
  FreeTemplateInfo('tanitim', '🏪', 'İşletme tanıtımı', 'Başlık, hizmet listesi, galeri ve iletişim'),
  FreeTemplateInfo('landing', '🚀', 'Tek sayfa tanıtım', 'Büyük başlık, 3 avantaj kutusu, SSS ve iletişim'),
  FreeTemplateInfo('portfoy', '🎨', 'Portfolyo', 'Kısa tanıtım, galeri (bento) ve iletişim'),
];

/// Varsayılan yer tutucu metinler SİTE diline göre (yayına gidebilecek içerik).
/// Arayüz metinleri ise `t()` / AppStrings ile uygulama dilini izler.
class FreeTexts {
  final bool en;
  const FreeTexts(this.en);
  factory FreeTexts.of(String siteLang) => FreeTexts(siteLang == 'en');

  String get siteName => en ? 'My Site' : 'Sitem';
  String get homeName => en ? 'Home' : 'Ana Sayfa';
  String get heroTitle => en ? 'Write your headline' : 'Başlığını yaz';
  String get heroText => en ? 'Add a short intro text.' : 'Kısa bir tanıtım yazısı ekle.';
  String get callButton => en ? 'Call Now' : 'Hemen Ara';
  String get title => en ? 'Heading' : 'Başlık';
  String get text => en ? 'Write your text here.' : 'Yazını buraya yaz.';
  String get button => en ? 'Button' : 'Buton';
}

FreeElement _e(
  FType type, {
  required int c,
  required int r,
  required int w,
  required int h,
  String text = '',
  int size = 1,
  int align = 1,
  int bg = 0,
}) =>
    FreeElement(id: newFreeId(), type: type, c: c, r: r, w: w, h: h, text: text, size: size, align: align, bg: bg);

FreeSection _canvas(List<FreeElement> els, {int bg = 0}) =>
    FreeSection(id: newFreeId(), kind: 'canvas', els: els, bg: bg);

FreeSection _block(Map<String, dynamic> b) => FreeSection(id: newFreeId(), kind: 'block', block: b);

FreeSection _contact() => FreeSection(id: newFreeId(), kind: 'contact');

List<FreeSection> buildFreeTemplate(String id, {String lang = 'tr'}) {
  final en = lang == 'en';
  switch (id) {
    case 'landing':
      return [
        _canvas([
          _e(FType.title, c: 4, r: 3, w: 40, h: 8, text: en ? 'A strong headline' : 'Güçlü bir başlık', size: 2),
          _e(FType.text, c: 8, r: 12, w: 32, h: 6, text: en ? 'Explain what you do in one sentence.' : 'Ne yaptığını tek cümlede anlat.'),
          _e(FType.button, c: 16, r: 20, w: 16, h: 5, text: en ? 'Call Now' : 'Hemen Ara'),
        ]),
        _canvas([
          _e(FType.shape, c: 2, r: 2, w: 14, h: 14),
          _e(FType.title, c: 3, r: 4, w: 12, h: 4, text: en ? 'Fast' : 'Hızlı', size: 0),
          _e(FType.text, c: 3, r: 9, w: 12, h: 6, text: en ? 'Short description' : 'Kısa açıklama', size: 0),
          _e(FType.shape, c: 17, r: 2, w: 14, h: 14),
          _e(FType.title, c: 18, r: 4, w: 12, h: 4, text: en ? 'Reliable' : 'Güvenilir', size: 0),
          _e(FType.text, c: 18, r: 9, w: 12, h: 6, text: en ? 'Short description' : 'Kısa açıklama', size: 0),
          _e(FType.shape, c: 32, r: 2, w: 14, h: 14),
          _e(FType.title, c: 33, r: 4, w: 12, h: 4, text: en ? 'Fair price' : 'Uygun fiyat', size: 0),
          _e(FType.text, c: 33, r: 9, w: 12, h: 6, text: en ? 'Short description' : 'Kısa açıklama', size: 0),
        ]),
        _block({
          'type': 'faq',
          'items': [
            {
              'question': en ? 'How can I contact you?' : 'Nasıl iletişime geçebilirim?',
              'answer': en ? 'You can reach us from the contact section below.' : 'Aşağıdaki iletişim bölümünden bize ulaşabilirsin.',
            },
          ],
        }),
        _contact(),
      ];
    case 'portfoy':
      return [
        _canvas([
          _e(FType.title, c: 4, r: 2, w: 40, h: 6, text: en ? 'Your Name' : 'Adın Soyadın', size: 2),
          _e(FType.text, c: 8, r: 9, w: 32, h: 6, text: en ? 'Briefly describe what you do.' : 'Ne iş yaptığını kısaca anlat.'),
        ]),
        _block({'type': 'gallery', 'style': 'bento', 'heading': en ? 'My Work' : 'Çalışmalarım', 'images': []}),
        _contact(),
      ];
    case 'tanitim':
    default:
      return [
        _canvas([
          _e(FType.title, c: 4, r: 2, w: 40, h: 6, text: en ? 'Business Name' : 'İşletme Adı', size: 2),
          _e(FType.text, c: 6, r: 9, w: 36, h: 6, text: en ? 'Add a short intro text.' : 'Kısa bir tanıtım yazısı ekle.'),
          _e(FType.button, c: 16, r: 17, w: 16, h: 5, text: en ? 'Call Now' : 'Hemen Ara'),
        ]),
        _block({
          'type': 'services',
          'heading': en ? 'Services & Prices' : 'Hizmetler ve Fiyatlar',
          'lines': en ? 'Service 1 - 30 min - 25 USD\nService 2 - 40 USD' : 'Hizmet 1 - 30 dk - 250 TL\nHizmet 2 - 400 TL',
        }),
        _block({'type': 'gallery', 'style': 'grid', 'images': []}),
        _contact(),
      ];
  }
}
