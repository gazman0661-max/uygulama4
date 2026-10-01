import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/real_estate_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/lead_form_toggle_field.dart';
import '../widgets/trust_bar_toggle_field.dart';
import '../widgets/section_order_field.dart';
import '../templates/html/section_registry.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/layout_style_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
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

class RealEstateFormScreen extends StatefulWidget {
  const RealEstateFormScreen({super.key, this.initialData, this.isEditing = false});

  final Map<String, dynamic>? initialData;

  final bool isEditing;

  @override
  State<RealEstateFormScreen> createState() => _RealEstateFormScreenState();
}

class _RealEstateFormScreenState extends State<RealEstateFormScreen> {
  final _agentNameCtrl = TextEditingController();
  final _agentLogoCtrl = TextEditingController();
  List<Map<String, String?>> _logo = [];
  List<Map<String, String?>> _cover = [];
  final _taglineCtrl = RichTextEditingController();
  final _aboutCtrl = RichTextEditingController();
  final _faqCtrl = TextEditingController();
  final _testimonialsCtrl = TextEditingController();
  bool _testimonialsConsent = false;
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _googleReviewCtrl = TextEditingController();
  late final SmartStyle _smartStyle = smartStyleFor('real_estate');
  late String _selectedTheme = _smartStyle.themeId;
  Map<String, String>? _customTheme;
  Map<String, String>? _customFontPackage;
  String _heroLayoutStyle = 'editorial';
  late String _fontPackageId = _smartStyle.fontPackageId;
  String _typeDensity = 'normal';
  late String _galleryStyle = _smartStyle.galleryStyle;
  bool _generating = false;
  Map<String, dynamic> _textStyling = {};
  bool _includeLeadForm = true;
  bool _showTrustBar = true;
  String _siteLang = 'tr';
  List<String>? _sectionOrder;

  final List<Map<String, dynamic>> _listings = [];

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
    _agentNameCtrl.dispose();
    _agentLogoCtrl.dispose();
    _taglineCtrl.dispose();
    _aboutCtrl.dispose();
    _faqCtrl.dispose();
    _testimonialsCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _googleReviewCtrl.dispose();
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

  Future<void> _openListingEditor({Map<String, dynamic>? existing, int? index}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ListingEditorSheet(existing: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _listings[index] = result;
      } else {
        _listings.add(result);
      }
    });
  }

  Map<String, dynamic> _captureFormData() {
    return {
      'includeLeadForm': _includeLeadForm,
      'showTrustBar': _showTrustBar,
      'agentNameCtrl': _agentNameCtrl.text,
      'agentLogoCtrl': _agentLogoCtrl.text,
      'logo': _logo,
      'cover': _cover,
      'taglineCtrl': _taglineCtrl.text,
      'aboutCtrl': _aboutCtrl.text,
      'faqCtrl': _faqCtrl.text,
      'testimonialsCtrl': _testimonialsCtrl.text,
      'testimonialsConsent': _testimonialsConsent,
      'phoneCtrl': _phoneCtrl.text,
      'whatsappCtrl': _whatsappCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
      'selectedTheme': _selectedTheme,
      'customTheme': _customTheme,
      'customFontPackage': _customFontPackage,
      'heroLayoutStyle': _heroLayoutStyle,
      'fontPackageId': _fontPackageId,
      'typeDensity': _typeDensity,
      'galleryStyle': _galleryStyle,
      'siteLang': _siteLang,
      'listings': _listings,
      'sectionOrder': _sectionOrder,
    };
  }

  void _restoreFromInitialData(Map<String, dynamic> d) {
    if (d['textStyling'] is Map) {
      _textStyling = Map<String, dynamic>.from(d['textStyling'] as Map);
    }
    _includeLeadForm = (d['includeLeadForm'] as bool?) ?? _includeLeadForm;
    _showTrustBar = (d['showTrustBar'] as bool?) ?? _showTrustBar;
    _agentNameCtrl.text = (d['agentNameCtrl'] as String?) ?? _agentNameCtrl.text;
    _agentLogoCtrl.text = (d['agentLogoCtrl'] as String?) ?? _agentLogoCtrl.text;
    if (d['logo'] != null) _logo = qtDecodeNullableStringMapList(d['logo']);
    if (d['cover'] != null) _cover = qtDecodeNullableStringMapList(d['cover']);
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _faqCtrl.text = (d['faqCtrl'] as String?) ?? _faqCtrl.text;
    _testimonialsCtrl.text = (d['testimonialsCtrl'] as String?) ?? _testimonialsCtrl.text;
    _testimonialsConsent = (d['testimonialsConsent'] as bool?) ?? _testimonialsConsent;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _whatsappCtrl.text = (d['whatsappCtrl'] as String?) ?? _whatsappCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
    _customTheme = qtDecodeStringMap(d['customTheme']) ?? _customTheme;
    _customFontPackage = qtDecodeStringMap(d['customFontPackage']) ?? _customFontPackage;
    _heroLayoutStyle = (d['heroLayoutStyle'] as String?) ?? _heroLayoutStyle;
    _fontPackageId = (d['fontPackageId'] as String?) ?? _fontPackageId;
    _typeDensity = (d['typeDensity'] as String?) ?? _typeDensity;
    _galleryStyle = (d['galleryStyle'] as String?) ?? _galleryStyle;
    _siteLang = (d['siteLang'] as String?) ?? _siteLang;
    final restored_listings = qtDecodeMapList(d['listings']);
    if (restored_listings != null) {
      _listings
        ..clear()
        ..addAll(restored_listings);
    }
    if (d['sectionOrder'] != null) {
      _sectionOrder = List<String>.from(d['sectionOrder'] as List);
    }
  }

  String get _logoUrl {
    final u = _logo.isNotEmpty ? (_logo.first['url'] ?? '') : '';
    return u.isNotEmpty ? u : _agentLogoCtrl.text.trim();
  }

  String? get _coverUrl {
    final u = _cover.isNotEmpty ? (_cover.first['url'] ?? '') : '';
    return u.isNotEmpty ? u : null;
  }

  Future<void> _generate() async {
    if (_agentNameCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'Emlakçı/ofis adı gerekli.'), icon: '⚠️');
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
    if (_listings.isEmpty) {
      showAppPopup(context, message: t(context, 'En az 1 ilan eklemelisin.'), icon: '⚠️');
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();
    final about = _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim();

    final siteLang = _siteLang;
    final ok = await LocalGenerationHelper.generateMultiPage(
      context: context,
      textStyling: _textStyling,
      selectedThemeId: _selectedTheme,
      selectedFontPackageId: _fontPackageId,
      selectedLayoutStyle: _heroLayoutStyle,
      projectNameHint: _agentNameCtrl.text.trim(),
      kind: ProjectKind.realEstate,
      formData: formData,
      isEditing: widget.isEditing,
      activeFileName: 'index.html',
      alwaysMultiPage: true,
      buildFiles: () => generateRealEstateSite(
        agentName: _agentNameCtrl.text.trim(),
        agentLogo: _logoUrl,
        agentCoverImage: _coverUrl,
        tagline: _taglineCtrl.text.trim(),
        about: about,
        agentPhone: _phoneCtrl.text.trim(),
        agentWhatsapp: _whatsappCtrl.text.trim(),
        agentGoogleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
        listings: _listings,
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
              ? '${t(context, 'Emlak Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Emlak Sitesi'),
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
              controller: _agentNameCtrl,
              decoration: InputDecoration(labelText: t(context, 'Emlakçı / ofis adı'), border: OutlineInputBorder()),
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
              label: t(context, 'Kapak Fotoğrafı (opsiyonel)'),
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
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context, 'Telefon (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context, 'WhatsApp (90XXXXXXXXXX)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            GoogleReviewLinkField(
              controller: _googleReviewCtrl,
              gbp: () => GbpPrefill(
                name: _agentNameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                categoryTr: 'Emlak ofisi',
                categoryEn: 'Real estate agency',
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
              sectionIds: kRealEstateDefaultOrder,
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
            TextField(
              controller: _testimonialsCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Müşteri Yorumları (opsiyonel — her satıra bir tane: İsim | Yorum | Puan)'),
                hintText: t(context, 'Ayşe K. | Süreç boyunca çok ilgiliydi, teşekkürler! | 5'),
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
              hintText: t(context, 'Kredi kullanabilir miyim? | Evet, anlaşmalı bankalarımız üzerinden destek sağlıyoruz.'),
              border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SectionOrderField(
              defaultSectionIds: kRealEstateDefaultOrder,
              initialOrder: _sectionOrder,
              onChanged: (v) => _sectionOrder = v,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '${isEnglish(context) ? 'Listings' : 'İlanlar'} (${_listings.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openListingEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(t(context, 'İlan Ekle')),
                ),
              ],
            ),
            for (var i = 0; i < _listings.length; i++)
              Card(
                child: ListTile(
                  title: Text(_listings[i]['title']?.toString() ?? ''),
                  subtitle: Text(
                    '${_listings[i]['price']} TL · ${_listings[i]['m2']} m² · ${_listings[i]['roomLabel']}',
                  ),
                  onTap: () => _openListingEditor(existing: _listings[i], index: i),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _listings.removeAt(i)),
                  ),
                ),
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

class _ListingEditorSheet extends StatefulWidget {
  const _ListingEditorSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_ListingEditorSheet> createState() => _ListingEditorSheetState();
}

class _ListingEditorSheetState extends State<_ListingEditorSheet> {
  late final _titleCtrl = TextEditingController(text: widget.existing?['title']?.toString() ?? '');
  late final _priceCtrl = TextEditingController(text: widget.existing?['price']?.toString() ?? '');
  late final _m2Ctrl = TextEditingController(text: widget.existing?['m2']?.toString() ?? '');
  late final _roomCtrl = TextEditingController(text: widget.existing?['roomLabel']?.toString() ?? '');
  late final _floorCtrl = TextEditingController(text: widget.existing?['floor']?.toString() ?? '');
  late final _aidatCtrl = TextEditingController(text: widget.existing?['aidat']?.toString() ?? '');
  late final _locationTagCtrl = TextEditingController(text: widget.existing?['locationTag']?.toString() ?? '');
  late final _descriptionCtrl = TextEditingController(text: widget.existing?['description']?.toString() ?? '');
  late final _addressCtrl = TextEditingController(text: widget.existing?['address']?.toString() ?? '');

  late List<Map<String, String?>> _gallery =
      (widget.existing?['gallery'] as List?)?.cast<Map<String, String?>>() ?? [];
  late String _galleryStyle = widget.existing?['galleryStyle']?.toString() ?? 'grid';
  late double _lat = (widget.existing?['lat'] as num?)?.toDouble() ?? 41.0082;
  late double _lng = (widget.existing?['lng'] as num?)?.toDouble() ?? 28.9784;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _m2Ctrl.dispose();
    _roomCtrl.dispose();
    _floorCtrl.dispose();
    _aidatCtrl.dispose();
    _locationTagCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'İlan başlığı ve fiyat gerekli.'), icon: '⚠️');
      return;
    }
    final id = widget.existing?['id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final coverImage = _gallery.isNotEmpty ? _gallery.first['url'] ?? '' : 'https://placehold.co/800x600';
    Navigator.pop(context, {
      'id': id,
      'title': _titleCtrl.text.trim(),
      'coverImage': coverImage,
      'price': double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0,
      'm2': double.tryParse(_m2Ctrl.text.replaceAll(',', '.')) ?? 0,
      'roomLabel': _roomCtrl.text.trim(),
      'floor': int.tryParse(_floorCtrl.text.trim()),
      'aidat': double.tryParse(_aidatCtrl.text.replaceAll(',', '.')),
      'locationTag': _locationTagCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'lat': _lat,
      'lng': _lng,
      'gallery': _gallery,
      'galleryStyle': _galleryStyle,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, widget.existing == null ? 'Yeni İlan' : 'İlanı Düzenle'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'İlan başlığı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'Fiyat (TL)'), border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _m2Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'm²'), border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _roomCtrl,
                  decoration: InputDecoration(labelText: t(context, 'Oda (örn. 3+1)'), border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _floorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'Kat (opsiyonel)'), border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _aidatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'Aidat (opsiyonel)'), border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _locationTagCtrl,
                  decoration: InputDecoration(labelText: t(context, 'Semt/ilçe etiketi'), border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: t(context, 'Açıklama'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            GalleryPickerField(
              label: t(context, 'İlan Galerisi'),
              initialImages: _gallery,
              onChanged: (v) => _gallery = v,
              showStyleOption: true,
              initialStyle: _galleryStyle,
              onStyleChanged: (v) => _galleryStyle = v,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: t(context, 'Kaydet'),
                    borderColor: AppTheme.accentBlue,
                    textColor: AppTheme.accentBlue,
                    onTap: _save,
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
