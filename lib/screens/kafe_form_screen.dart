import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/cafe_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/lead_form_toggle_field.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/layout_style_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';
import '../services/qt_form_data_codec.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/app_popup.dart';
import '../widgets/google_review_field.dart';
import '../widgets/video_link_field.dart'; // 05.09.2026 eklendi
import '../widgets/section_order_field.dart'; // 15.09.2026 eklendi
import '../templates/html/section_registry.dart'; // 15.09.2026 eklendi

/// kuafor_form_screen.dart kalıbından kopyalandı. Generator:
/// cafe_html_generator.dart -> generateCafeHtml.
class KafeFormScreen extends StatefulWidget {
  const KafeFormScreen({super.key, this.initialMultiPage = false, this.initialData, this.isEditing = false});

  /// Ana ekrandaki üst "Tek Sayfa / Çok Sayfa" seçicisinden hangi modla
  /// açıldığını taşır — true ise form, çok sayfalı anahtarı açık başlar.
  final bool initialMultiPage;

  /// 25.08.2026 eklendi — Düzenle akışı: önceden kaydedilmiş ham form
  /// alanları (bkz. services/qt_form_data_codec.dart).
  final Map<String, dynamic>? initialData;

  /// true ise bu ekran "Düzenle" akışıyla açılmıştır — buton metni ve
  /// puan maliyeti buna göre değişir (bkz. _generate).
  final bool isEditing;

  @override
  State<KafeFormScreen> createState() => _KafeFormScreenState();
}

class _KafeFormScreenState extends State<KafeFormScreen> {
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
  final _videoUrlCtrl = TextEditingController(); // 05.09.2026 eklendi (kanka isteği: video bloğu)
  String _videoOrientation = 'landscape'; // 05.09.2026 eklendi
  String _selectedTheme = 'clean_light';
  Map<String, String>? _customTheme; // 17.09.2026 eklendi ('Özel Tema' B seçeneği)
  Map<String, String>? _customFontPackage; // 18.09.2026 eklendi ('Serbest Font Seçimi')
  String _heroLayoutStyle = 'centered';
  String _fontPackageId = 'modern_sade';
  List<String>? _sectionOrder; // 15.09.2026 eklendi — Bölüm Sırala/Gizle (sadece tek sayfa modu)
  String _typeDensity = 'normal';
  String _galleryStyle = 'grid';
  bool _generating = false;
  bool _includeLeadForm = true; // 05.09.2026 eklendi (kanka isteği)
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BA�ĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  // Varsayılan olarak açılışta app diline eşitlenir (initState), kullanıcı
  // isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';
  late bool _multiPage = widget.initialMultiPage; // false: tek sayfa (generateCafeHtml), true: Ana Sayfa+Menü+Galeri (generateCafeSite)

  List<Map<String, String?>> _cover = [];
  List<Map<String, String?>> _logo = []; // Logo (opsiyonel) — 17.09.2026 eklendi
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
    // Açılışta uygulamanın o anki diliyle eşitle — kullanıcı isterse
    // aşağıdaki seçiciden değiştirebilir.
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
    _videoUrlCtrl.dispose();
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
      'includeLeadForm': _includeLeadForm,
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
      'instagramCtrl': _instagramCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
      'videoUrlCtrl': _videoUrlCtrl.text,
      'videoOrientation': _videoOrientation,
      'selectedTheme': _selectedTheme,
      'customTheme': _customTheme,
      'customFontPackage': _customFontPackage,
      'heroLayoutStyle': _heroLayoutStyle,
      'fontPackageId': _fontPackageId,
      'typeDensity': _typeDensity,
      'galleryStyle': _galleryStyle,
      'siteLang': _siteLang,
      'lat': _lat,
      'lng': _lng,
      'multiPage': _multiPage,
      'cover': _cover,
      'logo': _logo, // 17.09.2026 eklendi
      'gallery': _gallery,
      'workingHours': _workingHours,
      'sectionOrder': _sectionOrder, // 15.09.2026 eklendi
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _includeLeadForm = (d['includeLeadForm'] as bool?) ?? _includeLeadForm;
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
    _instagramCtrl.text = (d['instagramCtrl'] as String?) ?? _instagramCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
    _videoUrlCtrl.text = (d['videoUrlCtrl'] as String?) ?? _videoUrlCtrl.text;
    _videoOrientation = (d['videoOrientation'] as String?) ?? _videoOrientation;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
    _customTheme = qtDecodeStringMap(d['customTheme']) ?? _customTheme;
    _customFontPackage = qtDecodeStringMap(d['customFontPackage']) ?? _customFontPackage;
    _heroLayoutStyle = (d['heroLayoutStyle'] as String?) ?? _heroLayoutStyle;
    _fontPackageId = (d['fontPackageId'] as String?) ?? _fontPackageId;
    _typeDensity = (d['typeDensity'] as String?) ?? _typeDensity;
    _galleryStyle = (d['galleryStyle'] as String?) ?? _galleryStyle;
    _siteLang = (d['siteLang'] as String?) ?? _siteLang;
    _lat = (d['lat'] as num?)?.toDouble() ?? _lat;
    _lng = (d['lng'] as num?)?.toDouble() ?? _lng;
    _multiPage = (d['multiPage'] as bool?) ?? _multiPage;
    if (d['cover'] != null) {
      _cover = qtDecodeNullableStringMapList(d['cover']);
    }
    if (d['logo'] != null) { // 17.09.2026 eklendi
      _logo = qtDecodeNullableStringMapList(d['logo']);
    }
    if (d['gallery'] != null) {
      _gallery = qtDecodeNullableStringMapList(d['gallery']);
    }
    if (d['workingHours'] != null) {
      _workingHours = qtDecodeNullableStringMapList(d['workingHours']);
    }
    // 15.09.2026 eklendi — Bölüm Sırala/Gizle
    if (d['sectionOrder'] != null) {
      _sectionOrder = List<String>.from(d['sectionOrder'] as List);
    }
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'İşletme adı ve telefon gerekli.'), icon: '⚠️');
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    final menuCategories = _parseMenu(_menuCtrl.text);
    final coverUrl = _cover.isNotEmpty && (_cover.first['url'] ?? '').isNotEmpty
        ? _cover.first['url']!
        : 'https://placehold.co/1200x800';
    final logoUrl = _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null; // 17.09.2026 eklendi
    final about = _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim();
    final menuUrl = _menuUrlCtrl.text.trim().isEmpty ? null : _menuUrlCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim();
    final instagram = _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim();
    final googleReviewLink = _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim();
    final videoUrl = _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim();
    final videoOrientation = _videoOrientation;
    // Site içeriğinin dili, uygulamada seçili olan arayüz diliyle AYNI —
    // kullanıcıya ayrıca sormuyoruz. Kullanıcı Ayarlar'dan TR<->EN
    // değiştirdiğinde bir sonraki ürettiği site de otomatik o dilde olur.
    final siteLang = _siteLang;

    final ok = _multiPage
        ? await LocalGenerationHelper.generateMultiPage(
            context: context,
            selectedThemeId: _selectedTheme,
            selectedFontPackageId: _fontPackageId,
            selectedLayoutStyle: _heroLayoutStyle,
            projectNameHint: _nameCtrl.text.trim(),
            kind: ProjectKind.kafe,
            formData: formData,
            isEditing: widget.isEditing,
            activeFileName: 'index.html',
            buildFiles: () => generateCafeSite(
              name: _nameCtrl.text.trim(),
              coverImage: coverUrl,
              logoImage: logoUrl, // 17.09.2026 eklendi
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
              videoUrl: videoUrl,
              videoOrientation: videoOrientation,
              themeId: _selectedTheme,
              customTheme: _customTheme,
              heroLayoutStyle: _heroLayoutStyle,
              fontPackageId: _fontPackageId,
              customFontPackage: _customFontPackage,
              density: _typeDensity,
              galleryStyle: _galleryStyle,
              lang: siteLang,
              includeLeadForm: _includeLeadForm,
              faqs: _parseFaqs(_faqCtrl.text),
              testimonials: _parseTestimonials(_testimonialsCtrl.text),
              sectionOrder: _sectionOrder, // 15.09.2026 eklendi
            ),
          )
        : await LocalGenerationHelper.generateSinglePage(
            context: context,
            selectedThemeId: _selectedTheme,
            selectedFontPackageId: _fontPackageId,
            selectedLayoutStyle: _heroLayoutStyle,
            projectNameHint: _nameCtrl.text.trim(),
            kind: ProjectKind.kafe,
            formData: formData,
            isEditing: widget.isEditing,
            buildHtml: () => generateCafeHtml(
              name: _nameCtrl.text.trim(),
              coverImage: coverUrl,
              logoImage: logoUrl, // 17.09.2026 eklendi
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
              videoUrl: videoUrl,
              videoOrientation: videoOrientation,
              themeId: _selectedTheme,
              customTheme: _customTheme,
              heroLayoutStyle: _heroLayoutStyle,
              fontPackageId: _fontPackageId,
              customFontPackage: _customFontPackage,
              density: _typeDensity,
              galleryStyle: _galleryStyle,
              lang: siteLang,
              includeLeadForm: _includeLeadForm,
              faqs: _parseFaqs(_faqCtrl.text),
              testimonials: _parseTestimonials(_testimonialsCtrl.text),
              sectionOrder: _sectionOrder, // 15.09.2026 eklendi
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
              ? '${t(context, 'Kafe / Restoran Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Kafe / Restoran Sitesi'),
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
            GalleryPickerField(
              label: t(context, 'Logo (opsiyonel)'),
              maxImages: 1,
              initialImages: _logo,
              onChanged: (v) => _logo = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _menuCtrl,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: t(context, 'Menü (kategoriler arasına boş satır bırak)'),
                hintText: t(context, 'Kahveler\nEspresso - - 60 TL\nLatte - Sütlü - 75 TL\n\nTatlılar\nCheesecake - Ev yapımı - 90 TL'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _menuUrlCtrl,
              decoration: InputDecoration(labelText: t(context, 'Dijital/QR menü linki (opsiyonel)'), border: OutlineInputBorder()),
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
            // 05.09.2026 değişti (kanka isteği, madde 4) — free plan'da kilitli
            GoogleReviewLinkField(controller: _googleReviewCtrl),
            const SizedBox(height: 20),
            // 05.09.2026 eklendi (kanka isteği) — video bloğu, dış link embed
            VideoLinkField(
              urlController: _videoUrlCtrl,
              orientation: _videoOrientation,
              onOrientationChanged: (v) => setState(() => _videoOrientation = v),
            ),
            const SizedBox(height: 20),
            ThemePickerField(
              initialThemeId: _selectedTheme,
              initialCustomTheme: _customTheme,
              onChanged: (v) => _selectedTheme = v,
              onCustomThemeChanged: (v) => _customTheme = v,
            ),
            const SizedBox(height: 20),
            LayoutStylePickerField(
              initialLayoutStyle: _heroLayoutStyle,
              onChanged: (v) => _heroLayoutStyle = v,
            ),
            const SizedBox(height: 20),
            TypographyPickerField(
              initialFontPackageId: _fontPackageId,
              initialCustomFontPackage: _customFontPackage,
              initialDensity: _typeDensity,
              onFontPackageChanged: (v) => _fontPackageId = v,
              onCustomFontPackageChanged: (v) => _customFontPackage = v,
              onDensityChanged: (v) => _typeDensity = v,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'Çok Sayfalı Site'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t(context, 'Ana Sayfa, Menü ve Galeri ayrı sayfalar olarak oluşturulur.'),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _multiPage,
                    onChanged: (v) => setState(() => _multiPage = v),
                    activeColor: AppTheme.accentBlue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle.
            // Artık ÇOK sayfa modunda da (index.html'in orta blokları)
            // çalışıyor; mod değişince varsayılan id seti farklı olduğu
            // için widget'ı ValueKey(_multiPage) ile sıfırlıyoruz.
            SectionOrderField(
              key: ValueKey(_multiPage),
              defaultSectionIds: _multiPage ? kCafeMultiPageHomeDefaultOrder : kCafeDefaultOrder,
              initialOrder: _sectionOrder,
              onChanged: (v) => _sectionOrder = v,
            ),
            const SizedBox(height: 20),
            LeadFormToggleField(
              value: _includeLeadForm,
              onChanged: (v) => setState(() => _includeLeadForm = v),
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
