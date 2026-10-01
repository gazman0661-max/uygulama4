import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/portfolio_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/lead_form_toggle_field.dart';
import '../widgets/trust_bar_toggle_field.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/layout_style_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
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
import '../widgets/section_order_field.dart';
import '../templates/html/section_registry.dart';

class PhotographerFormScreen extends StatefulWidget {
  const PhotographerFormScreen({super.key, this.initialMultiPage = false, this.initialData, this.isEditing = false});

  final bool initialMultiPage;

  final Map<String, dynamic>? initialData;

  final bool isEditing;

  @override
  State<PhotographerFormScreen> createState() => _PhotographerFormScreenState();
}

class _PhotographerFormScreenState extends State<PhotographerFormScreen> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _taglineCtrl = RichTextEditingController();
  final _aboutCtrl = RichTextEditingController();
  final _skillsCtrl = TextEditingController();
  final _timelineCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _googleReviewCtrl = TextEditingController();
  final _faqCtrl = TextEditingController();
  final _testimonialsCtrl = TextEditingController();
  bool _testimonialsConsent = false;
  late final SmartStyle _smartStyle = smartStyleFor('photographer');
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
  List<Map<String, String?>> _works = [];

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
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _aboutCtrl.dispose();
    _skillsCtrl.dispose();
    _timelineCtrl.dispose();
    _emailCtrl.dispose();
    _googleReviewCtrl.dispose();
    _faqCtrl.dispose();
    _testimonialsCtrl.dispose();
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

  List<String> _parseSkills(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<Map<String, String?>> _parseTimeline(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
      final parts = line.split('-').map((p) => p.trim()).toList();
      return {
        'year': parts.isNotEmpty ? parts[0] : '',
        'title': parts.length > 1 ? parts[1] : '',
        'description': parts.length > 2 ? parts[2] : '',
      };
    }).toList();
  }

  Map<String, dynamic> _captureFormData() {
    return {
      'includeLeadForm': _includeLeadForm,
      'showTrustBar': _showTrustBar,
      'nameCtrl': _nameCtrl.text,
      'titleCtrl': _titleCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'aboutCtrl': _aboutCtrl.text,
      'skillsCtrl': _skillsCtrl.text,
      'timelineCtrl': _timelineCtrl.text,
      'emailCtrl': _emailCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
      'faqCtrl': _faqCtrl.text,
      'testimonialsCtrl': _testimonialsCtrl.text,
      'testimonialsConsent': _testimonialsConsent,
      'selectedTheme': _selectedTheme,
      'customTheme': _customTheme,
      'customFontPackage': _customFontPackage,
      'heroLayoutStyle': _heroLayoutStyle,
      'fontPackageId': _fontPackageId,
      'typeDensity': _typeDensity,
      'galleryStyle': _galleryStyle,
      'siteLang': _siteLang,
      'multiPage': _multiPage,
      'photo': _photo,
      'logo': _logo,
      'works': _works,
      'sectionOrder': _sectionOrder,
    };
  }

  void _restoreFromInitialData(Map<String, dynamic> d) {
    if (d['textStyling'] is Map) {
      _textStyling = Map<String, dynamic>.from(d['textStyling'] as Map);
    }
    _includeLeadForm = (d['includeLeadForm'] as bool?) ?? _includeLeadForm;
    _showTrustBar = (d['showTrustBar'] as bool?) ?? _showTrustBar;
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _titleCtrl.text = (d['titleCtrl'] as String?) ?? _titleCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _skillsCtrl.text = (d['skillsCtrl'] as String?) ?? _skillsCtrl.text;
    _timelineCtrl.text = (d['timelineCtrl'] as String?) ?? _timelineCtrl.text;
    _emailCtrl.text = (d['emailCtrl'] as String?) ?? _emailCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
    _faqCtrl.text = (d['faqCtrl'] as String?) ?? _faqCtrl.text;
    _testimonialsCtrl.text = (d['testimonialsCtrl'] as String?) ?? _testimonialsCtrl.text;
    _testimonialsConsent = (d['testimonialsConsent'] as bool?) ?? _testimonialsConsent;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
    _customTheme = qtDecodeStringMap(d['customTheme']) ?? _customTheme;
    _customFontPackage = qtDecodeStringMap(d['customFontPackage']) ?? _customFontPackage;
    _heroLayoutStyle = (d['heroLayoutStyle'] as String?) ?? _heroLayoutStyle;
    _fontPackageId = (d['fontPackageId'] as String?) ?? _fontPackageId;
    _typeDensity = (d['typeDensity'] as String?) ?? _typeDensity;
    _galleryStyle = (d['galleryStyle'] as String?) ?? _galleryStyle;
    _siteLang = (d['siteLang'] as String?) ?? _siteLang;
    _multiPage = (d['multiPage'] as bool?) ?? _multiPage;
    if (d['photo'] != null) {
      _photo = qtDecodeNullableStringMapList(d['photo']);
    }
    if (d['logo'] != null) {
      _logo = qtDecodeNullableStringMapList(d['logo']);
    }
    if (d['works'] != null) {
      _works = qtDecodeNullableStringMapList(d['works']);
    }
    if (d['sectionOrder'] != null) {
      _sectionOrder = List<String>.from(d['sectionOrder'] as List);
    }
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'İsim gerekli.'), icon: '⚠️');
      return;
    }
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

    final skills = _parseSkills(_skillsCtrl.text);
    final timeline = _parseTimeline(_timelineCtrl.text);
    final siteLang = _siteLang;
    final ok = _multiPage
        ? await LocalGenerationHelper.generateMultiPage(
            context: context,
            textStyling: _textStyling,
            selectedThemeId: _selectedTheme,
            selectedFontPackageId: _fontPackageId,
            selectedLayoutStyle: _heroLayoutStyle,
            projectNameHint: '${_nameCtrl.text.trim()} - Portfolyo',
            kind: ProjectKind.photographer,
            formData: formData,
            isEditing: widget.isEditing,
            activeFileName: 'index.html',
            buildFiles: () => generatePortfolioSite(
              name: _nameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photo: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : ''  ,
              logoImage: _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null,
              tagline: _taglineCtrl.text.trim(),
              aboutText: _aboutCtrl.text.trim(),
              skills: skills,
              works: _works,
              timeline: timeline,
              contactEmail: _emailCtrl.text.trim(),
              contactGoogleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
              themeId: _selectedTheme,
              customTheme: _customTheme,
              heroLayoutStyle: _heroLayoutStyle,
              fontPackageId: _fontPackageId,
              customFontPackage: _customFontPackage,
              density: _typeDensity,
              galleryStyle: _galleryStyle,
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
            projectNameHint: '${_nameCtrl.text.trim()} - Portfolyo',
            kind: ProjectKind.photographer,
            formData: formData,
            isEditing: widget.isEditing,
            buildHtml: () => generatePortfolioHtml(
              name: _nameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photo: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : ''  ,
              logoImage: _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null,
              tagline: _taglineCtrl.text.trim(),
              aboutText: _aboutCtrl.text.trim(),
              skills: skills,
              works: _works,
              timeline: timeline,
              contactEmail: _emailCtrl.text.trim(),
              contactGoogleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
              themeId: _selectedTheme,
              customTheme: _customTheme,
              heroLayoutStyle: _heroLayoutStyle,
              fontPackageId: _fontPackageId,
              customFontPackage: _customFontPackage,
              density: _typeDensity,
              galleryStyle: _galleryStyle,
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
              ? '${t(context, 'Fotoğrafçı Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Fotoğrafçı Sitesi'),
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
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: t(context, 'İsim'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'Uzmanlık (örn. Düğün Fotoğrafçısı)'), border: OutlineInputBorder()),
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
            GalleryPickerField(
              label: t(context, 'Profil Fotoğrafı'),
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
            RichTextField(
              controller: _aboutCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Hakkında'),
              border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skillsCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'Yetenekler (virgülle ayır)'),
                hintText: t(context, 'Düğün Çekimi, Dış Mekan, Stüdyo Portre'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timelineCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t(context, 'Deneyim & eğitim (her satıra bir tane: Yıl - Başlık - Açıklama)'),
                hintText: t(context, '2023 - Freelance Fotoğrafçı - İstanbul\n2020 - Fotoğrafçılık Sertifikası - Kurs'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GalleryPickerField(
              label: t(context, 'Fotoğraf Örnekleri'),
              initialImages: _works,
              onChanged: (v) => _works = v,
              showStyleOption: true,
              initialStyle: _galleryStyle,
              onStyleChanged: (v) => _galleryStyle = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: t(context, 'İletişim e-postası (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            GoogleReviewLinkField(
              controller: _googleReviewCtrl,
              gbp: () => GbpPrefill(
                name: _nameCtrl.text.trim(),
                categoryTr: 'Fotoğrafçı',
                categoryEn: 'Photographer',
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _faqCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Sıkça Sorulan Sorular (opsiyonel — her satıra bir tane: Soru | Cevap)'),
              hintText: t(context, 'Nasıl randevu alabilirim? | E-posta veya telefon üzerinden iletişime geçebilirsiniz.'),
              border: const OutlineInputBorder(),
              ),
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
              sectionIds: kPortfolioDefaultOrder,
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
                          t(context, 'Her iş örneği kendi sayfasında (Ana Sayfa + iş detay sayfaları) oluşturulur.'),
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
              defaultSectionIds: kPortfolioDefaultOrder,
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
