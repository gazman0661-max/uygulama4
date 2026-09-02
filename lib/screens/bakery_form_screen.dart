import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/cafe_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';
import '../services/qt_form_data_codec.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// kafe_form_screen.dart kalıbından kopyalandı — AYNI generateCafeHtml
/// (kafe/restoran ile aynı menü+galeri+harita yapısı, ürünler kategori
/// bazlı listeleniyor), sadece schemaType 'Bakery' ve CTA "Sipariş Ver"
/// olarak override edildi (bkz. cafe_html_generator.dart'taki opsiyonel
/// schemaType/ctaText parametreleri). Kafe'den farklı olarak burada
/// çok sayfa seçeneği YOK — fırın/pastane için tek sayfa yeterli kabul
/// edildi.
class BakeryFormScreen extends StatefulWidget {
  const BakeryFormScreen({super.key, this.initialData, this.isEditing = false});

  /// 25.08.2026 eklendi — Düzenle akışı: önceden kaydedilmiş ham form
  /// alanları (bkz. services/qt_form_data_codec.dart).
  final Map<String, dynamic>? initialData;

  /// true ise bu ekran "Düzenle" akışıyla açılmıştır — buton metni ve
  /// puan maliyeti buna göre değişir (bkz. _generate).
  final bool isEditing;

  @override
  State<BakeryFormScreen> createState() => _BakeryFormScreenState();
}

class _BakeryFormScreenState extends State<BakeryFormScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _menuCtrl = TextEditingController(); // kategori blokları
  final _menuUrlCtrl = TextEditingController();
  final _faqCtrl = TextEditingController(); // "Soru | Cevap" satır satır
  final _testimonialsCtrl = TextEditingController(); // "İsim | Yorum | Puan(1-5, opsiyonel)" satır satır
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _googleReviewCtrl = TextEditingController(); // 01.09.2026 eklendi
  String _selectedTheme = 'clean_light';
  String _fontPackageId = 'modern_sade';
  String _typeDensity = 'normal';
  String _galleryStyle = 'grid';
  bool _generating = false;
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BAĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  String _siteLang = 'tr';

  List<Map<String, String?>> _cover = [];
  List<Map<String, String?>> _gallery = [];
  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial != null) {
      _restoreFromInitialData(initial);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isEditing) return;
      setState(() {
        _siteLang = context.read<LocaleController>().isEnglish ? 'en' : 'tr';
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _aboutCtrl.dispose();
    _menuCtrl.dispose();
    _menuUrlCtrl.dispose();
    _faqCtrl.dispose();
    _testimonialsCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    _googleReviewCtrl.dispose();
    super.dispose();
  }

  /// "Soru | Cevap" satırlarını parse eder — bkz. faqBlockHtml
  /// (templates/html/shared_html_blocks.dart). Boş/eksik satırlar atlanır.
  List<Map<String, String>> _parseFaqs(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.contains('|'))
        .map((line) {
      final parts = line.split('|');
      return {
        'question': parts[0].trim(),
        'answer': parts.sublist(1).join('|').trim(),
      };
    }).where((f) => f['question']!.isNotEmpty && f['answer']!.isNotEmpty).toList();
  }

  /// "İsim | Yorum | Puan(1-5, opsiyonel)" satırlarını parse eder — bkz.
  /// testimonialBlockHtml. Puan verilmezse/yanlış girilirse yıldız satırı
  /// hiç basılmaz (testimonialBlockHtml içinde ele alınıyor).
  List<Map<String, dynamic>> _parseTestimonials(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.contains('|'))
        .map((line) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      return {
        'name': parts.isNotEmpty ? parts[0] : '',
        'text': parts.length > 1 ? parts[1] : '',
        'rating': parts.length > 2 ? parts[2] : '',
      };
    }).where((t) => (t['name'] as String).isNotEmpty && (t['text'] as String).isNotEmpty).toList();
  }

  /// Boş satırla ayrılmış bloklar: ilk satır kategori adı, sonraki satırlar
  /// "Ürün - Açıklama - Fiyat" ya da "Ürün - Fiyat".
  List<Map<String, dynamic>> _parseMenu(String raw) {
    final blocks = raw.trim().split(RegExp(r'\n\s*\n'));
    final categories = <Map<String, dynamic>>[];
    for (final block in blocks) {
      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final title = lines.first;
      final items = lines.skip(1).map((line) {
        final parts = line.split('-').map((p) => p.trim()).toList();
        if (parts.length >= 3) {
          return {'name': parts[0], 'description': parts[1], 'price': parts[2]};
        } else if (parts.length == 2) {
          return {'name': parts[0], 'description': '', 'price': parts[1]};
        }
        return {'name': parts[0], 'description': '', 'price': ''};
      }).toList();
      categories.add({'title': title, 'items': items});
    }
    return categories;
  }

  /// 25.08.2026 eklendi — Düzenle akışı: bu formun HAM alan
  /// değerlerinin JSON-uyumlu bir anlık görüntüsü (bkz.
  /// services/qt_form_data_codec.dart). Üretim/düzenleme başarıyla
  /// bittiğinde AppState.qtFormData'ya yazılır ki sonraki "Düzenle"
  /// bu formu dolu açabilsin.
  Map<String, dynamic> _captureFormData() {
    return {
      'nameCtrl': _nameCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'aboutCtrl': _aboutCtrl.text,
      'menuCtrl': _menuCtrl.text,
      'menuUrlCtrl': _menuUrlCtrl.text,
      'faqCtrl': _faqCtrl.text,
      'testimonialsCtrl': _testimonialsCtrl.text,
      'addressCtrl': _addressCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'whatsappCtrl': _whatsappCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
      'instagramCtrl': _instagramCtrl.text,
      'selectedTheme': _selectedTheme,
      'fontPackageId': _fontPackageId,
      'typeDensity': _typeDensity,
      'galleryStyle': _galleryStyle,
      'siteLang': _siteLang,
      'lat': _lat,
      'lng': _lng,
      'cover': _cover,
      'gallery': _gallery,
      'workingHours': _workingHours,
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _menuCtrl.text = (d['menuCtrl'] as String?) ?? _menuCtrl.text;
    _menuUrlCtrl.text = (d['menuUrlCtrl'] as String?) ?? _menuUrlCtrl.text;
    _faqCtrl.text = (d['faqCtrl'] as String?) ?? _faqCtrl.text;
    _testimonialsCtrl.text = (d['testimonialsCtrl'] as String?) ?? _testimonialsCtrl.text;
    _addressCtrl.text = (d['addressCtrl'] as String?) ?? _addressCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _whatsappCtrl.text = (d['whatsappCtrl'] as String?) ?? _whatsappCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
    _instagramCtrl.text = (d['instagramCtrl'] as String?) ?? _instagramCtrl.text;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
    _fontPackageId = (d['fontPackageId'] as String?) ?? _fontPackageId;
    _typeDensity = (d['typeDensity'] as String?) ?? _typeDensity;
    _galleryStyle = (d['galleryStyle'] as String?) ?? _galleryStyle;
    _siteLang = (d['siteLang'] as String?) ?? _siteLang;
    _lat = (d['lat'] as num?)?.toDouble() ?? _lat;
    _lng = (d['lng'] as num?)?.toDouble() ?? _lng;
    if (d['cover'] != null) {
      _cover = qtDecodeNullableStringMapList(d['cover']);
    }
    if (d['gallery'] != null) {
      _gallery = qtDecodeNullableStringMapList(d['gallery']);
    }
    if (d['workingHours'] != null) {
      _workingHours = qtDecodeNullableStringMapList(d['workingHours']);
    }
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'İşletme adı ve telefon gerekli.'))),
      );
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    final menuCategories = _parseMenu(_menuCtrl.text);
    final coverUrl = _cover.isNotEmpty && (_cover.first['url'] ?? '').isNotEmpty
        ? _cover.first['url']!
        : 'https://placehold.co/1200x800';
    final about = _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim();
    final menuUrl = _menuUrlCtrl.text.trim().isEmpty ? null : _menuUrlCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim();
    final instagram = _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim();
    final googleReviewLink = _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim();
    final siteLang = _siteLang;
    final labelsCta = siteLang == 'en' ? 'Order Now' : 'Sipariş Ver';

    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: _nameCtrl.text.trim(),
      kind: ProjectKind.bakery,
      formData: formData,
      isEditing: widget.isEditing,
      buildHtml: () => generateCafeHtml(
        name: _nameCtrl.text.trim(),
        coverImage: coverUrl,
        tagline: _taglineCtrl.text.trim(),
        about: about,
        menuCategories: menuCategories,
        menuUrl: menuUrl,
        gallery: _gallery,
        workingHours: _workingHours,
        address: _addressCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        phone: _phoneCtrl.text.trim(),
        whatsapp: whatsapp,
        instagram: instagram,
        googleReviewLink: googleReviewLink,
        themeId: _selectedTheme,
        fontPackageId: _fontPackageId,
        density: _typeDensity,
        galleryStyle: _galleryStyle,
        lang: siteLang,
        faqs: _parseFaqs(_faqCtrl.text),
        testimonials: _parseTestimonials(_testimonialsCtrl.text),
        schemaType: 'Bakery',
        ctaText: labelsCta,
      ),
    );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final generating = _generating || context.watch<AppState>().isGenerating;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? '${t(context, 'Fırın / Pastane Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Fırın / Pastane Sitesi'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Site içeriği dili — uygulama diline bağımlı DEĞİL ---
            Text(t(context, 'Site İçeriği Dili'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              t(context, 'Sitenin ziyaretçiye görüneceği dil. Bu uygulamanın kendi arayüz dilinden bağımsızdır.'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'tr', label: Text('Türkçe')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {_siteLang},
              onSelectionChanged: (s) => setState(() => _siteLang = s.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: t(context, 'İşletme adı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: InputDecoration(labelText: t(context, 'Slogan (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aboutCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: t(context, 'Hakkında (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            GalleryPickerField(
              label: t(context, 'Kapak Görseli'),
              maxImages: 1,
              initialImages: _cover,
              onChanged: (v) => _cover = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _menuCtrl,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: t(context, 'Ürünler (kategoriler arasına boş satır bırak)'),
                hintText: t(context, 'Ekmekler\nEkşi Mayalı Somun - 900g - 90 TL\nTam Buğday - 700g - 70 TL\n\nPastalar\nÇikolatalı Pasta - 8 Dilim - 350 TL'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _menuUrlCtrl,
              decoration: InputDecoration(labelText: t(context, 'Dijital/QR ürün listesi linki (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            GalleryPickerField(
              initialImages: _gallery,
              onChanged: (v) => _gallery = v,
              showStyleOption: true,
              initialStyle: _galleryStyle,
              onStyleChanged: (v) => _galleryStyle = v,
            ),
            const SizedBox(height: 20),
            WorkingHoursPickerField(initialHours: _workingHours, onChanged: (v) => _workingHours = v),
            const SizedBox(height: 20),
            TextField(
              controller: _testimonialsCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Müşteri Yorumları (opsiyonel — her satıra bir tane: İsim | Yorum | Puan)'),
                hintText: t(context, 'Ayşe K. | Çok memnun kaldım, teşekkürler! | 5'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _faqCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Sıkça Sorulan Sorular (opsiyonel — her satıra bir tane: Soru | Cevap)'),
                hintText: t(context, 'Rezervasyon gerekli mi? | Hafta sonları önerilir, hafta içi genelde yer var.'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            LocationPickerField(
              initialAddress: _addressCtrl.text,
              initialLat: _lat,
              initialLng: _lng,
              onChanged: (address, lat, lng) {
                _addressCtrl.text = address;
                _lat = lat;
                _lng = lng;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context, 'Telefon'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context, 'WhatsApp (opsiyonel, 90XXXXXXXXXX)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instagramCtrl,
              decoration: InputDecoration(labelText: t(context, 'Instagram kullanıcı adı (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            // 01.09.2026 eklendi
            TextField(
              controller: _googleReviewCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: t(context, 'Google Yorum Linki (opsiyonel)'),
                hintText: 'https://g.page/r/.../review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ThemePickerField(
              initialThemeId: _selectedTheme,
              onChanged: (v) => _selectedTheme = v,
            ),
            const SizedBox(height: 20),
            TypographyPickerField(
              initialFontPackageId: _fontPackageId,
              initialDensity: _typeDensity,
              onFontPackageChanged: (v) => _fontPackageId = v,
              onDensityChanged: (v) => _typeDensity = v,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: t(
                      context,
                      generating
                          ? 'Oluşturuluyor...'
                          : (widget.isEditing ? 'Düzenlemeyi Bitir' : 'Siteyi Oluştur'),
                    ),
                    borderColor: AppTheme.accentBlue,
                    textColor: AppTheme.accentBlue,
                    onTap: generating ? null : _generate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
