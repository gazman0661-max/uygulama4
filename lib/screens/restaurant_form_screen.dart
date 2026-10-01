import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/cafe_html_generator.dart';
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
import '../widgets/confirm_popup.dart';
import '../widgets/google_review_field.dart';
import '../templates/smart_style_defaults.dart';
import '../widgets/video_link_field.dart';
import '../widgets/section_order_field.dart';
import '../templates/html/section_registry.dart';
import '../widgets/menu_legal_info_field.dart';
import 'subscription_plans_screen.dart';

class RestaurantFormScreen extends StatefulWidget {
  const RestaurantFormScreen({super.key, this.initialData, this.isEditing = false});

  final Map<String, dynamic>? initialData;

  final bool isEditing;

  @override
  State<RestaurantFormScreen> createState() => _RestaurantFormScreenState();
}

class _RestaurantFormScreenState extends State<RestaurantFormScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = RichTextEditingController();
  final _aboutCtrl = RichTextEditingController();
  final _menuCtrl = TextEditingController();
  final _menuUrlCtrl = TextEditingController();
  Map<String, dynamic> _menuLegalInfo = {};
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
  late final SmartStyle _smartStyle = smartStyleFor('restaurant');
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

  List<Map<String, String?>> _cover = [];
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

  Map<String, dynamic> _captureFormData() {
    return {
      'includeLeadForm': _includeLeadForm,
      'showTrustBar': _showTrustBar,
      'nameCtrl': _nameCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'aboutCtrl': _aboutCtrl.text,
      'menuCtrl': _menuCtrl.text,
      'menuUrlCtrl': _menuUrlCtrl.text,
      'menuLegalInfo': _menuLegalInfo,
      'faqCtrl': _faqCtrl.text,
      'testimonialsCtrl': _testimonialsCtrl.text,
      'testimonialsConsent': _testimonialsConsent,
      'addressCtrl': _addressCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'whatsappCtrl': _whatsappCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
      'videoUrlCtrl': _videoUrlCtrl.text,
      'videoOrientation': _videoOrientation,
      'instagramCtrl': _instagramCtrl.text,
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
      'cover': _cover,
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
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _menuCtrl.text = (d['menuCtrl'] as String?) ?? _menuCtrl.text;
    _menuUrlCtrl.text = (d['menuUrlCtrl'] as String?) ?? _menuUrlCtrl.text;
    _menuLegalInfo = qtDecodeMenuLegalInfo(d['menuLegalInfo']);
    _faqCtrl.text = (d['faqCtrl'] as String?) ?? _faqCtrl.text;
    _testimonialsCtrl.text = (d['testimonialsCtrl'] as String?) ?? _testimonialsCtrl.text;
    _testimonialsConsent = (d['testimonialsConsent'] as bool?) ?? _testimonialsConsent;
    _addressCtrl.text = (d['addressCtrl'] as String?) ?? _addressCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _whatsappCtrl.text = (d['whatsappCtrl'] as String?) ?? _whatsappCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
    _videoUrlCtrl.text = (d['videoUrlCtrl'] as String?) ?? _videoUrlCtrl.text;
    _videoOrientation = (d['videoOrientation'] as String?) ?? _videoOrientation;
    _instagramCtrl.text = (d['instagramCtrl'] as String?) ?? _instagramCtrl.text;
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
    if (d['cover'] != null) {
      _cover = qtDecodeNullableStringMapList(d['cover']);
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
    if (_nameCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'İşletme adı gerekli.'), icon: '⚠️');
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
    final hasSubscription = context.read<AppState>().hasActiveSubscription;
    final parsedMenu = _parseMenu(_menuCtrl.text);
    final menuWithLegal = qtMergeMenuLegalInfo(parsedMenu, _menuLegalInfo);
    if (!hasSubscription && qtMenuCategoriesHaveLegal(menuWithLegal)) {
      final proceed = await showConfirmPopup(
        context,
        title: 'Yasal bilgiler siteye basılmayacak',
        message:
            'Menüde alerjen/kalori/içerik bilgisi girilmiş ama aktif aboneliğin yok, bu yüzden bu bilgiler yayınlanan sitede GÖRÜNMEYECEK. Yine de devam edilsin mi?',
        confirmLabel: 'Yine de üret',
        cancelLabel: 'Vazgeç',
        confirmColor: AppTheme.accentOrange,
      );
      if (!proceed || !mounted) return;
    }

    setState(() => _generating = true);
    final formData = _captureFormData();
    final menuCategories = hasSubscription ? menuWithLegal : parsedMenu;
    final coverUrl = _cover.isNotEmpty && (_cover.first['url'] ?? '').isNotEmpty
        ? _cover.first['url']!
        : ''  ;
    final logoUrl = _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null;
    final about = _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim();
    final menuUrl = _menuUrlCtrl.text.trim().isEmpty ? null : _menuUrlCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim();
    final instagram = _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim();
    final googleReviewLink = _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim();
    final videoUrl = _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim();
    final videoOrientation = _videoOrientation;
    final siteLang = _siteLang;
    final labelsCta = siteLang == 'en' ? 'Reserve a Table' : 'Rezervasyon Yap';

    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      textStyling: _textStyling,
      selectedThemeId: _selectedTheme,
      selectedFontPackageId: _fontPackageId,
      selectedLayoutStyle: _heroLayoutStyle,
      projectNameHint: _nameCtrl.text.trim(),
      kind: ProjectKind.restaurant,
      formData: formData,
      isEditing: widget.isEditing,
      buildHtml: () => generateCafeHtml(
        name: _nameCtrl.text.trim(),
        coverImage: coverUrl,
        logoImage: logoUrl,
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
        showTrustBar: _showTrustBar,
        sectionOrder: _sectionOrder,
        faqs: _parseFaqs(_faqCtrl.text),
        testimonials: _parseTestimonials(_testimonialsCtrl.text),
        schemaType: 'Restaurant',
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
              ? '${t(context, 'Restoran / Lokanta Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Restoran / Lokanta Sitesi'),
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
              decoration: InputDecoration(labelText: t(context, 'İşletme adı'), border: OutlineInputBorder()),
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
                hintText: t(context, 'Başlangıçlar\nMercimek Çorbası - - 90 TL\nÇoban Salata - - 110 TL\n\nAna Yemekler\nIzgara Köfte - - 280 TL'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _menuUrlCtrl,
              decoration: InputDecoration(labelText: t(context, 'Dijital/QR menü linki (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            MenuLegalInfoField(
              menuController: _menuCtrl,
              parseMenu: _parseMenu,
              initialLegalInfo: _menuLegalInfo,
              locked: !context.watch<AppState>().hasActiveSubscription,
              onUnlockTap: () => showSubscriptionPlansScreen(context),
              onChanged: (v) => _menuLegalInfo = v,
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
              hintText: t(context, 'Rezervasyon gerekli mi? | Hafta sonları önerilir, hafta içi genelde yer var.'),
              border: const OutlineInputBorder(),
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
                name: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                address: _addressCtrl.text.trim(),
                hours: _workingHours,
                categoryTr: 'Restoran',
                categoryEn: 'Restaurant',
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
              sectionIds: kCafeDefaultOrder,
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
            SectionOrderField(
              defaultSectionIds: kCafeDefaultOrder,
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
