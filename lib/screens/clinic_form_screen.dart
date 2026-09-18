import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/clinic_html_generator.dart';
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
/// clinic_html_generator.dart -> generateClinicHtml.
///
/// NOT: Bu şablonda galeri bölümü yok (generator'da da yok) — pratisyen
/// fotoğrafı hero + tanıtım bölümünde kullanılıyor.
class ClinicFormScreen extends StatefulWidget {
  const ClinicFormScreen({super.key, this.initialMultiPage = false, this.initialData, this.isEditing = false});

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
  State<ClinicFormScreen> createState() => _ClinicFormScreenState();
}

class _ClinicFormScreenState extends State<ClinicFormScreen> {
  final _businessNameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(); // "Uzman Psikolog" gibi unvan
  final _taglineCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController(); // uzmanlık alanları
  final _bioCtrl = TextEditingController();
  final _credentialsCtrl = TextEditingController(); // her satır bir unvan/sertifika
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
  late bool _multiPage = widget.initialMultiPage; // false: tek sayfa (generateClinicHtml), true: Ana Sayfa+Hizmetler+Randevu (generateClinicSite)

  List<Map<String, String?>> _photo = [];
  List<Map<String, String?>> _logo = []; // Logo (opsiyonel) — 17.09.2026 eklendi
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
    _businessNameCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _servicesCtrl.dispose();
    _bioCtrl.dispose();
    _credentialsCtrl.dispose();
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

  List<Map<String, String?>> _parseServices(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => {'name': line, 'duration': null, 'price': ''})
        .toList();
  }

  /// 25.08.2026 eklendi — Düzenle akışı: bu formun HAM alan
  /// değerlerinin JSON-uyumlu bir anlık görüntüsü (bkz.
  /// services/qt_form_data_codec.dart). Üretim/düzenleme başarıyla
  /// bittiğinde AppState.qtFormData'ya yazılır ki sonraki "Düzenle"
  /// bu formu dolu açabilsin.
  Map<String, dynamic> _captureFormData() {
    return {
      'includeLeadForm': _includeLeadForm,
      'businessNameCtrl': _businessNameCtrl.text,
      'titleCtrl': _titleCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'servicesCtrl': _servicesCtrl.text,
      'bioCtrl': _bioCtrl.text,
      'credentialsCtrl': _credentialsCtrl.text,
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
      'photo': _photo,
      'logo': _logo, // 17.09.2026 eklendi
      'workingHours': _workingHours,
      'sectionOrder': _sectionOrder, // 15.09.2026 eklendi
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _includeLeadForm = (d['includeLeadForm'] as bool?) ?? _includeLeadForm;
    _businessNameCtrl.text = (d['businessNameCtrl'] as String?) ?? _businessNameCtrl.text;
    _titleCtrl.text = (d['titleCtrl'] as String?) ?? _titleCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _servicesCtrl.text = (d['servicesCtrl'] as String?) ?? _servicesCtrl.text;
    _bioCtrl.text = (d['bioCtrl'] as String?) ?? _bioCtrl.text;
    _credentialsCtrl.text = (d['credentialsCtrl'] as String?) ?? _credentialsCtrl.text;
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
    if (d['photo'] != null) {
      _photo = qtDecodeNullableStringMapList(d['photo']);
    }
    if (d['logo'] != null) { // 17.09.2026 eklendi
      _logo = qtDecodeNullableStringMapList(d['logo']);
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
    if (_businessNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'Klinik/uzman adı ve telefon gerekli.'), icon: '⚠️');
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    final services = _parseServices(_servicesCtrl.text);
    final credentials = _credentialsCtrl.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => {'label': l})
        .toList();

    final siteLang = _siteLang;
    final ok = _multiPage
        ? await LocalGenerationHelper.generateMultiPage(
            context: context,
            selectedThemeId: _selectedTheme,
            selectedFontPackageId: _fontPackageId,
            selectedLayoutStyle: _heroLayoutStyle,
            projectNameHint: _businessNameCtrl.text.trim(),
            kind: ProjectKind.clinic,
            formData: formData,
            isEditing: widget.isEditing,
            activeFileName: 'index.html',
            buildFiles: () => generateClinicSite(
              businessName: _businessNameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photoUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : 'https://placehold.co/800x800',
              logoImage: _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null, // 17.09.2026 eklendi
              tagline: _taglineCtrl.text.trim(),
              services: services,
              practitioner: {
                'name': _businessNameCtrl.text.trim(),
                'title': _titleCtrl.text.trim(),
                'photoUrl': _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                    ? _photo.first['url']!
                    : 'https://placehold.co/800x800',
                'bio': _bioCtrl.text.trim(),
                'credentials': credentials,
              },
              workingHours: _workingHours,
              address: _addressCtrl.text.trim(),
              lat: _lat,
              lng: _lng,
              phone: _phoneCtrl.text.trim(),
              whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
              instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
              googleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
              videoUrl: _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
              videoOrientation: _videoOrientation,
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
            projectNameHint: _businessNameCtrl.text.trim(),
            kind: ProjectKind.clinic,
            formData: formData,
            isEditing: widget.isEditing,
            buildHtml: () => generateClinicHtml(
              businessName: _businessNameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photoUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : 'https://placehold.co/800x800',
              logoImage: _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null, // 17.09.2026 eklendi
              tagline: _taglineCtrl.text.trim(),
              services: services,
              practitioner: {
                'name': _businessNameCtrl.text.trim(),
                'title': _titleCtrl.text.trim(),
                'photoUrl': _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                    ? _photo.first['url']!
                    : 'https://placehold.co/800x800',
                'bio': _bioCtrl.text.trim(),
                'credentials': credentials,
              },
              workingHours: _workingHours,
              address: _addressCtrl.text.trim(),
              lat: _lat,
              lng: _lng,
              phone: _phoneCtrl.text.trim(),
              whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
              instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
              googleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
              videoUrl: _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
              videoOrientation: _videoOrientation,
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
              ? '${t(context, 'Klinik / Sağlık Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Klinik / Sağlık Sitesi'),
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
              controller: _businessNameCtrl,
              decoration: InputDecoration(labelText: t(context, 'Klinik / uzman adı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'Unvan (örn. Uzman Psikolog)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: InputDecoration(labelText: t(context, 'Slogan (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            GalleryPickerField(
              label: t(context, 'Fotoğraf'),
              maxImages: 1,
              initialImages: _photo,
              onChanged: (v) => _photo = v,
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
              controller: _servicesCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t(context, 'Uzmanlık alanları (her satıra bir tane)'),
                hintText: t(context, 'Aile Danışmanlığı\nBireysel Terapi'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: t(context, 'Kısa özgeçmiş / tanıtım'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _credentialsCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t(context, 'Sertifika / unvan rozetleri (her satıra bir tane, opsiyonel)'),
                hintText: t(context, 'PhD - Klinik Psikoloji\nEMDR Sertifikası'),
                border: OutlineInputBorder(),
              ),
            ),
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
                hintText: t(context, 'Randevu nasıl alabilirim? | Telefon veya WhatsApp üzerinden randevu alabilirsiniz.'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            WorkingHoursPickerField(initialHours: _workingHours, onChanged: (v) => _workingHours = v),
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
                          t(context, 'Ana Sayfa, Hizmetler ve Randevu ayrı sayfalar olarak oluşturulur.'),
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
            // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle. Artık
            // ÇOK sayfa modunda da (index.html'in orta blokları) çalışıyor;
            // mod değişince varsayılan id seti farklı olduğu için widget'ı
            // ValueKey(_multiPage) ile sıfırlıyoruz.
            SectionOrderField(
              key: ValueKey(_multiPage),
              defaultSectionIds: _multiPage ? kClinicMultiPageHomeDefaultOrder : kClinicDefaultOrder,
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
