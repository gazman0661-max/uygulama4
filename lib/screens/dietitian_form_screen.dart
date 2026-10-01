import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/clinic_html_generator.dart';
import '../widgets/no_contact_warning.dart';
import '../widgets/pill_button.dart';
import '../widgets/lead_form_toggle_field.dart';
import '../widgets/trust_bar_toggle_field.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/layout_style_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';
import '../services/qt_form_data_codec.dart';
import '../widgets/testimonial_consent_checkbox.dart';
import '../localization/app_strings.dart';
import '../widgets/rich_text_field.dart';
import '../widgets/text_styling_field.dart';
import '../localization/locale_controller.dart';
import '../widgets/app_popup.dart';
import '../widgets/google_review_field.dart';
import '../templates/smart_style_defaults.dart';
import '../widgets/video_link_field.dart';
import '../widgets/section_order_field.dart';
import '../templates/html/section_registry.dart';

class DietitianFormScreen extends StatefulWidget {
  const DietitianFormScreen({super.key, this.initialMultiPage = false, this.initialData, this.isEditing = false});

  final bool initialMultiPage;

  final Map<String, dynamic>? initialData;

  final bool isEditing;

  @override
  State<DietitianFormScreen> createState() => _DietitianFormScreenState();
}

class _DietitianFormScreenState extends State<DietitianFormScreen> {
  final _businessNameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _taglineCtrl = RichTextEditingController();
  final _aboutCtrl = RichTextEditingController();
  final _servicesCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _credentialsCtrl = TextEditingController();
  final _faqCtrl = TextEditingController();
  final _testimonialsCtrl = TextEditingController();
  bool _testimonialsConsent = false;
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _googleReviewCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  String _videoOrientation = 'landscape';
  late final SmartStyle _smartStyle = smartStyleFor('dietitian');
  late String _selectedTheme = _smartStyle.themeId;
  Map<String, String>? _customTheme;
  Map<String, String>? _customFontPackage;
  late String _heroLayoutStyle = _smartStyle.heroLayout;
  late String _fontPackageId = _smartStyle.fontPackageId;
  List<String>? _sectionOrder;
  String _typeDensity = 'normal';
  late String _galleryStyle = _smartStyle.galleryStyle;
  bool _generating = false;
  Map<String, dynamic> _textStyling = {};
  bool _includeLeadForm = true;
  bool _showTrustBar = true;
  String _siteLang = 'tr';
  late bool _multiPage = widget.initialMultiPage;

  List<Map<String, String?>> _photo = [];
  List<Map<String, String?>> _logo = [];
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
    _businessNameCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _aboutCtrl.dispose();
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

  Map<String, dynamic> _captureFormData() {
    return {
      'includeLeadForm': _includeLeadForm,
      'showTrustBar': _showTrustBar,
      'businessNameCtrl': _businessNameCtrl.text,
      'titleCtrl': _titleCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'aboutCtrl': _aboutCtrl.text,
      'servicesCtrl': _servicesCtrl.text,
      'bioCtrl': _bioCtrl.text,
      'credentialsCtrl': _credentialsCtrl.text,
      'faqCtrl': _faqCtrl.text,
      'testimonialsCtrl': _testimonialsCtrl.text,
      'testimonialsConsent': _testimonialsConsent,
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
      'logo': _logo,
      'gallery': _gallery,
      'workingHours': _workingHours,
      'sectionOrder': _sectionOrder,
    };
  }

  void _restoreFromInitialData(Map<String, dynamic> d) {
    if (d['textStyling'] is Map) {
      _textStyling = Map<String, dynamic>.from(d['textStyling'] as Map);
    }
    _includeLeadForm = (d['includeLeadForm'] as bool?) ?? _includeLeadForm;
    _showTrustBar = (d['showTrustBar'] as bool?) ?? _showTrustBar;
    _businessNameCtrl.text = (d['businessNameCtrl'] as String?) ?? _businessNameCtrl.text;
    _titleCtrl.text = (d['titleCtrl'] as String?) ?? _titleCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _servicesCtrl.text = (d['servicesCtrl'] as String?) ?? _servicesCtrl.text;
    _bioCtrl.text = (d['bioCtrl'] as String?) ?? _bioCtrl.text;
    _credentialsCtrl.text = (d['credentialsCtrl'] as String?) ?? _credentialsCtrl.text;
    _faqCtrl.text = (d['faqCtrl'] as String?) ?? _faqCtrl.text;
    _testimonialsCtrl.text = (d['testimonialsCtrl'] as String?) ?? _testimonialsCtrl.text;
    _testimonialsConsent = (d['testimonialsConsent'] as bool?) ?? _testimonialsConsent;
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
    if (d['logo'] != null) {
      _logo = qtDecodeNullableStringMapList(d['logo']);
    }
    if (d['gallery'] != null) {
      _gallery = qtDecodeNullableStringMapList(d['gallery']);
    }
    if (d['workingHours'] != null) {
      _workingHours = qtDecodeNullableStringMapList(d['workingHours']);
    }
    if (d['sectionOrder'] != null) {
      _sectionOrder = List<String>.from(d['sectionOrder'] as List);
    }
  }

  Future<void> _generate() async {
    if (_businessNameCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'Klinik/uzman adı gerekli.'), icon: '⚠️');
      return;
    }
    if (!await confirmNoContactWay(
      context,
      phone: _phoneCtrl.text,
      whatsapp: _whatsappCtrl.text,
      instagram: _instagramCtrl.text,
      googleReviewLink: _googleReviewCtrl.text,
      includeLeadForm: _includeLeadForm,
    )) return;
    if (!mounted) return;
    if (!_testimonialsConsent && _parseTestimonials(_testimonialsCtrl.text).isNotEmpty) {
      showAppPopup(
        context,
        message: t(context, 'Müşteri Yorumları alanına yazı girdin ama altındaki onay kutusunu işaretlemedin. Devam etmek için lütfen kutuyu işaretle.'),
        icon: '⚠️',
      );
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    final about = _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim();
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
            textStyling: _textStyling,
            selectedThemeId: _selectedTheme,
            selectedFontPackageId: _fontPackageId,
            selectedLayoutStyle: _heroLayoutStyle,
            projectNameHint: _businessNameCtrl.text.trim(),
            kind: ProjectKind.dietitian,
            formData: formData,
            isEditing: widget.isEditing,
            activeFileName: 'index.html',
            buildFiles: () => generateClinicSite(
              businessName: _businessNameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photoUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : ''  ,
              logoImage: _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null,
              tagline: _taglineCtrl.text.trim(),
              about: about,
              services: services,
              practitioner: {
                'name': _businessNameCtrl.text.trim(),
                'title': _titleCtrl.text.trim(),
                'photoUrl': _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                    ? _photo.first['url']!
                    : ''  ,
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
              gallery: _gallery,
              lang: siteLang,
              includeLeadForm: _includeLeadForm,
        showTrustBar: _showTrustBar,
              faqs: _parseFaqs(_faqCtrl.text),
              testimonials: _parseTestimonials(_testimonialsCtrl.text),
              sectionOrder: _sectionOrder,
            ),
          )
        : await LocalGenerationHelper.generateSinglePage(
            context: context,
            textStyling: _textStyling,
            selectedThemeId: _selectedTheme,
            selectedFontPackageId: _fontPackageId,
            selectedLayoutStyle: _heroLayoutStyle,
            projectNameHint: _businessNameCtrl.text.trim(),
            kind: ProjectKind.dietitian,
            formData: formData,
            isEditing: widget.isEditing,
            buildHtml: () => generateClinicHtml(
              businessName: _businessNameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photoUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : ''  ,
              logoImage: _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null,
              tagline: _taglineCtrl.text.trim(),
              about: about,
              services: services,
              practitioner: {
                'name': _businessNameCtrl.text.trim(),
                'title': _titleCtrl.text.trim(),
                'photoUrl': _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                    ? _photo.first['url']!
                    : ''  ,
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
              gallery: _gallery,
              lang: siteLang,
              includeLeadForm: _includeLeadForm,
        showTrustBar: _showTrustBar,
              faqs: _parseFaqs(_faqCtrl.text),
              testimonials: _parseTestimonials(_testimonialsCtrl.text),
              sectionOrder: _sectionOrder,
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
              ? '${t(context, 'Diyetisyen Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Diyetisyen Sitesi'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          cacheExtent: 100000,
          padding: const EdgeInsets.all(16),
          children: [
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
              decoration: InputDecoration(labelText: t(context, 'İsim / işletme adı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'Unvan (örn. Uzman Diyetisyen)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            RichTextField(
              controller: _taglineCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'Slogan (opsiyonel)'),
              border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            RichTextField(
              controller: _aboutCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t(context, 'Hakkında (opsiyonel)'),
              border: const OutlineInputBorder(),
              ),
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
            GalleryPickerField(
              label: t(context, 'Galeri (opsiyonel)'),
              initialImages: _gallery,
              onChanged: (v) => _gallery = v,
              showStyleOption: true,
              initialStyle: _galleryStyle,
              onStyleChanged: (v) => _galleryStyle = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _servicesCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t(context, 'Hizmet alanları (her satıra bir tane)'),
                hintText: t(context, 'Kişiye Özel Beslenme Programı\nSporcu Beslenmesi\nOnline Danışmanlık'),
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
            TestimonialConsentCheckbox(
              value: _testimonialsConsent,
              onChanged: (v) => setState(() => _testimonialsConsent = v),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _faqCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Sıkça Sorulan Sorular (opsiyonel — her satıra bir tane: Soru | Cevap)'),
              hintText: t(context, 'Randevu nasıl alabilirim? | Telefon veya WhatsApp üzerinden randevu alabilirsiniz.'),
              border: const OutlineInputBorder(),
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
              decoration: InputDecoration(labelText: t(context, 'Telefon (opsiyonel)'), border: OutlineInputBorder()),
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
            GoogleReviewLinkField(
              controller: _googleReviewCtrl,
              gbp: () => GbpPrefill(
                name: _businessNameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                address: _addressCtrl.text.trim(),
                hours: _workingHours,
                categoryTr: 'Diyetisyen',
                categoryEn: 'Dietitian',
              ),
            ),
            const SizedBox(height: 20),
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
            TextStylingField(
              sectionIds: _multiPage ? kClinicMultiPageHomeDefaultOrder : kClinicDefaultOrder,
              initialValue: _textStyling,
              onChanged: (v) => _textStyling = v,
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
            const SizedBox(height: 12),
            TrustBarToggleField(
              value: _showTrustBar,
              onChanged: (v) => setState(() => _showTrustBar = v),
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
