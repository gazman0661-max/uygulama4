import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/business_card_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import 'preview_screen.dart';
import '../services/qt_form_data_codec.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/app_popup.dart';
import '../templates/smart_style_defaults.dart';

class BusinessCardFormScreen extends StatefulWidget {
  const BusinessCardFormScreen({super.key, this.initialData, this.isEditing = false});

  final Map<String, dynamic>? initialData;

  final bool isEditing;

  @override
  State<BusinessCardFormScreen> createState() => _BusinessCardFormScreenState();
}

class _BusinessCardFormScreenState extends State<BusinessCardFormScreen> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _linksCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  late final SmartStyle _smartStyle = smartStyleFor('business_card');
  late String _selectedTheme = _smartStyle.themeId;
  Map<String, String>? _customTheme;
  late String _fontPackageId = _smartStyle.fontPackageId;
  Map<String, String>? _customFontPackage;
  String _typeDensity = 'normal';
  bool _generating = false;
  String _siteLang = 'tr';

  List<Map<String, String?>> _photo = [];

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
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _linksCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> _parseLinks(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.contains('-'))
        .map((line) {
      final idx = line.indexOf('-');
      return {
        'platform': line.substring(0, idx).trim(),
        'url': line.substring(idx + 1).trim(),
      };
    }).toList();
  }

  Map<String, dynamic> _captureFormData() {
    return {
      'nameCtrl': _nameCtrl.text,
      'titleCtrl': _titleCtrl.text,
      'companyCtrl': _companyCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'emailCtrl': _emailCtrl.text,
      'linksCtrl': _linksCtrl.text,
      'aboutCtrl': _aboutCtrl.text,
      'selectedTheme': _selectedTheme,
      'customTheme': _customTheme,
      'fontPackageId': _fontPackageId,
      'customFontPackage': _customFontPackage,
      'typeDensity': _typeDensity,
      'siteLang': _siteLang,
      'photo': _photo,
    };
  }

  void _restoreFromInitialData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _titleCtrl.text = (d['titleCtrl'] as String?) ?? _titleCtrl.text;
    _companyCtrl.text = (d['companyCtrl'] as String?) ?? _companyCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _emailCtrl.text = (d['emailCtrl'] as String?) ?? _emailCtrl.text;
    _linksCtrl.text = (d['linksCtrl'] as String?) ?? _linksCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
    _customTheme = qtDecodeStringMap(d['customTheme']) ?? _customTheme;
    _fontPackageId = (d['fontPackageId'] as String?) ?? _fontPackageId;
    _customFontPackage = qtDecodeStringMap(d['customFontPackage']) ?? _customFontPackage;
    _typeDensity = (d['typeDensity'] as String?) ?? _typeDensity;
    _siteLang = (d['siteLang'] as String?) ?? _siteLang;
    if (d['photo'] != null) {
      _photo = qtDecodeNullableStringMapList(d['photo']);
    }
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'İsim gerekli.'), icon: '⚠️');
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    final socials = _parseLinks(_linksCtrl.text);
    final siteLang = _siteLang;
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      selectedThemeId: _selectedTheme,
      selectedFontPackageId: _fontPackageId,
      projectNameHint: '${_nameCtrl.text.trim()} - Kartvizit',
      kind: ProjectKind.businessCard,
      formData: formData,
      isEditing: widget.isEditing,
      buildHtml: () => generateBusinessCardHtml(
        name: _nameCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        company: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        tagline: _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        socials: socials,
        avatarUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
            ? _photo.first['url']
            : null,
        themeId: _selectedTheme,
        customTheme: _customTheme,
        fontPackageId: _fontPackageId,
        customFontPackage: _customFontPackage,
        density: _typeDensity,
        lang: siteLang,
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
              ? '${t(context, 'Dijital Kartvizit')} • ${t(context, 'Düzenle')}'
              : t(context, 'Dijital Kartvizit'),
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
              decoration: InputDecoration(
                labelText: t(context, 'Ad Soyad'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'Unvan / meslek'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'Şirket (opsiyonel)'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t(context, 'Telefon (opsiyonel)'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: t(context, 'E-posta (opsiyonel)'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linksCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t(context, 'Sosyal / web linkleri (opsiyonel, her satıra bir tane: Platform - URL)'),
                hintText: t(context, 'LinkedIn - https://linkedin.com/in/...\nWeb sitesi - https://...'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aboutCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t(context, 'Hakkında (opsiyonel)'),
              border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GalleryPickerField(
              label: t(context, 'Profil Fotoğrafı (opsiyonel)'),
              maxImages: 1,
              initialImages: _photo,
              onChanged: (v) => _photo = v,
            ),
            const SizedBox(height: 20),
            ThemePickerField(
              initialThemeId: _selectedTheme,
              initialCustomTheme: _customTheme,
              onChanged: (v) => _selectedTheme = v,
              onCustomThemeChanged: (v) => _customTheme = v,
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
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: t(
                      context,
                      generating
                          ? 'Oluşturuluyor...'
                          : (widget.isEditing ? 'Düzenlemeyi Bitir' : 'Kartviziti Oluştur'),
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
