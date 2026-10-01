import '../templates/html/rich_text_markup.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../services/qt_form_data_codec.dart';
import '../state/app_state.dart';
import '../templates/html/extra_page_blocks.dart';
import '../templates/html/free_site_html_generator.dart';
import '../templates/smart_style_defaults.dart';
import '../theme/app_theme.dart';
import '../widgets/app_popup.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/google_review_field.dart';
import '../widgets/layout_style_picker_field.dart';
import '../widgets/lead_form_toggle_field.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import 'extra_page_editor_screen.dart';
import 'html_draft_preview_screen.dart';
import 'preview_screen.dart';

class FreeSiteFormScreen extends StatefulWidget {
  const FreeSiteFormScreen({super.key, this.initialMultiPage = false, this.initialData, this.isEditing = false});

  final bool initialMultiPage;

  final Map<String, dynamic>? initialData;
  final bool isEditing;

  @override
  State<FreeSiteFormScreen> createState() => _FreeSiteFormScreenState();
}

class _FreeSiteFormScreenState extends State<FreeSiteFormScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _googleReviewCtrl = TextEditingController();

  late final SmartStyle _smartStyle = smartStyleFor('generic_business');
  late String _selectedTheme = _smartStyle.themeId;
  Map<String, String>? _customTheme;
  Map<String, String>? _customFontPackage;
  late String _heroLayoutStyle = _smartStyle.heroLayout;
  late String _fontPackageId = _smartStyle.fontPackageId;
  String _typeDensity = 'normal';
  String _siteLang = 'tr';
  late bool _multiPage = widget.initialMultiPage;
  bool _generating = false;
  bool _includeLeadForm = true;

  List<Map<String, String?>> _logo = [];
  List<Map<String, dynamic>> _homeBlocks = [];
  final List<Map<String, String>> _extraPages = [];

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
        _siteLang = (widget.initialData?['siteLang'] as String?) ??
            (context.read<LocaleController>().isEnglish ? 'en' : 'tr');
      });
      if (widget.initialData == null && _homeBlocks.isEmpty) _editHome();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    _googleReviewCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _captureFormData() {
    return {
      'includeLeadForm': _includeLeadForm,
      'nameCtrl': _nameCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'whatsappCtrl': _whatsappCtrl.text,
      'instagramCtrl': _instagramCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
      'selectedTheme': _selectedTheme,
      'customTheme': _customTheme,
      'customFontPackage': _customFontPackage,
      'heroLayoutStyle': _heroLayoutStyle,
      'fontPackageId': _fontPackageId,
      'typeDensity': _typeDensity,
      'siteLang': _siteLang,
      'multiPage': _multiPage,
      'logo': _logo,
      'homeBlocks': encodeExtraPageBlocks(_homeBlocks),
      'extraPages': _extraPages,
    };
  }

  void _restoreFromInitialData(Map<String, dynamic> d) {
    _includeLeadForm = (d['includeLeadForm'] as bool?) ?? _includeLeadForm;
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _whatsappCtrl.text = (d['whatsappCtrl'] as String?) ?? _whatsappCtrl.text;
    _instagramCtrl.text = (d['instagramCtrl'] as String?) ?? _instagramCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
    _customTheme = qtDecodeStringMap(d['customTheme']) ?? _customTheme;
    _customFontPackage = qtDecodeStringMap(d['customFontPackage']) ?? _customFontPackage;
    _heroLayoutStyle = (d['heroLayoutStyle'] as String?) ?? _heroLayoutStyle;
    _fontPackageId = (d['fontPackageId'] as String?) ?? _fontPackageId;
    _typeDensity = (d['typeDensity'] as String?) ?? _typeDensity;
    _siteLang = (d['siteLang'] as String?) ?? _siteLang;
    _multiPage = (d['multiPage'] as bool?) ?? _multiPage;
    if (d['logo'] != null) {
      _logo = qtDecodeNullableStringMapList(d['logo']);
    }
    if (d['homeBlocks'] is String) {
      _homeBlocks = decodeExtraPageBlocks(d['homeBlocks'] as String, allowed: kFreeSiteHomeBlockTypes);
    }
    if (d['extraPages'] != null) {
      _extraPages
        ..clear()
        ..addAll(qtDecodeStringMapList(d['extraPages']));
    }
  }

  String? get _logoUrl =>
      _logo.isNotEmpty && (_logo.first['url'] ?? '').isNotEmpty ? _logo.first['url'] : null;

  Map<String, String> _buildFiles({
    List<Map<String, dynamic>>? homeBlocks,
    List<Map<String, String>>? extraPages,
    bool? multiPage,
    bool forPreview = false,
    bool editorMode = false,
  }) {
    final rawName = _nameCtrl.text.trim();
    final name = (forPreview && rawName.isEmpty) ? t(context, 'Site Adı') : rawName;
    final built = generateFreeSite(
      name: name,
      logoImage: _logoUrl,
      phone: _phoneCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
      instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
      googleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
      homeBlocks: homeBlocks ?? _homeBlocks,
      extraPages: extraPages ?? _extraPages,
      multiPage: multiPage ?? _multiPage,
      themeId: _selectedTheme,
      customTheme: _customTheme,
      customFontPackage: _customFontPackage,
      fontPackageId: _fontPackageId,
      density: _typeDensity,
      heroLayoutStyle: _heroLayoutStyle,
      lang: _siteLang,
      includeLeadForm: _includeLeadForm,
      editorMarkers: editorMode,
    );
    if (!forPreview) return built;
    return built.map((k, v) => MapEntry(k, richMarkupToHtml(v)));
  }

  Future<void> _editHome() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExtraPageEditorScreen(
          existing: {'blocks': encodeExtraPageBlocks(_homeBlocks)},
          existingSlugs: const {},
          allowedBlockTypes: kFreeSiteHomeBlockTypes,
          isHome: true,
          previewBuilder: (title, slug, blocks) =>
              _buildFiles(homeBlocks: blocks, forPreview: true, editorMode: true)['index.html']!,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _homeBlocks = decodeExtraPageBlocks(result['blocks'], allowed: kFreeSiteHomeBlockTypes);
    });
  }

  Future<void> _addOrEditPage({Map<String, String>? existing, int? index}) async {
    final existingSlugs = _extraPages
        .asMap()
        .entries
        .where((e) => e.key != index)
        .map((e) => e.value['slug']!)
        .toSet();
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExtraPageEditorScreen(
          existing: existing,
          existingSlugs: existingSlugs,
          allowedBlockTypes: kFreeSiteBlockTypes,
          previewBuilder: (title, slug, blocks) {
            final draft = <String, String>{
              'slug': slug,
              'title': title,
              'content': '',
              'blocks': encodeExtraPageBlocks(blocks),
              'seoDesc': '',
            };
            final pages = [..._extraPages];
            if (index != null && index < pages.length) {
              pages[index] = draft;
            } else {
              pages.add(draft);
            }
            return _buildFiles(extraPages: pages, multiPage: true, forPreview: true, editorMode: true)['$slug.html']!;
          },
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _extraPages[index] = result;
      } else {
        _extraPages.add(result);
      }
    });
  }

  String _pageSubtitle(Map<String, String> page) {
    final n = decodeExtraPageBlocks(page['blocks'], allowed: kFreeSiteBlockTypes).length;
    final file = '${page['slug']}.html';
    if (n == 0) return file;
    return '$file · $n ${t(context, 'blok')}';
  }

  void _previewHome() {
    if (_homeBlocks.isEmpty) {
      showAppPopup(context, message: t(context, 'Önce ana sayfaya en az 1 blok ekle.'), icon: 'ℹ️');
      return;
    }
    String html;
    try {
      html = _buildFiles(forPreview: true)['index.html']!;
    } catch (_) {
      showAppPopup(context, message: t(context, 'Önizleme hazırlanamadı.'), icon: '⚠️');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HtmlDraftPreviewScreen(html: html)));
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'Site adı gerekli.'), icon: '⚠️');
      return;
    }
    if (_homeBlocks.isEmpty) {
      showAppPopup(context, message: t(context, 'Ana sayfaya en az 1 blok eklemelisin.'), icon: '⚠️');
      return;
    }
    if (_multiPage && _extraPages.isEmpty) {
      showAppPopup(context, message: t(context, 'Çok sayfa modunda en az 1 ek sayfa eklemelisin.'), icon: '⚠️');
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    bool ok;
    if (_multiPage) {
      ok = await LocalGenerationHelper.generateMultiPage(
        context: context,
        selectedThemeId: _selectedTheme,
        selectedFontPackageId: _fontPackageId,
        selectedLayoutStyle: _heroLayoutStyle,
        projectNameHint: _nameCtrl.text.trim(),
        kind: ProjectKind.freeSite,
        formData: formData,
        isEditing: widget.isEditing,
        activeFileName: 'index.html',
        buildFiles: () => _buildFiles(),
      );
    } else {
      ok = await LocalGenerationHelper.generateSinglePage(
        context: context,
        selectedThemeId: _selectedTheme,
        selectedFontPackageId: _fontPackageId,
        selectedLayoutStyle: _heroLayoutStyle,
        projectNameHint: _nameCtrl.text.trim(),
        kind: ProjectKind.freeSite,
        formData: formData,
        isEditing: widget.isEditing,
        buildHtml: () => _buildFiles()['index.html']!,
      );
    }

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
    final homeCount = _homeBlocks.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? '${t(context, 'Serbest Site')} • ${t(context, 'Düzenle')}'
              : t(context, 'Serbest Site'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          cacheExtent: 100000,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t(context, 'Sektör seçmeden, sayfanı bloklarla kendin kur: kapak, yazı, görsel, galeri, video, çalışma saatleri, harita, yorumlar, iletişim, fiyat listesi, SSS ve buton.'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Text(t(context, 'Site Yapısı'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(t(context, 'Tek Sayfa'))),
                ButtonSegment(value: true, label: Text(t(context, 'Çok Sayfa'))),
              ],
              selected: {_multiPage},
              onSelectionChanged: (s) => setState(() => _multiPage = s.first),
            ),
            const SizedBox(height: 4),
            Text(
              _multiPage
                  ? t(context, 'Ana sayfa ve istediğin kadar ek sayfa; hepsi bloklardan kurulur ve ortak bir menüyle bağlanır.')
                  : t(context, 'Tüm içerik tek bir sayfada, kaydırarak gezilir.'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),
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
              decoration: InputDecoration(labelText: t(context, 'Site adı'), border: const OutlineInputBorder()),
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
              decoration: InputDecoration(labelText: t(context, 'Telefon (opsiyonel)'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context, 'WhatsApp (opsiyonel, 90XXXXXXXXXX)'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instagramCtrl,
              decoration: InputDecoration(labelText: t(context, 'Instagram kullanıcı adı (opsiyonel)'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            GoogleReviewLinkField(
              controller: _googleReviewCtrl,
              gbp: () => GbpPrefill(name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim()),
            ),
            const SizedBox(height: 24),

            Text(t(context, 'Ana Sayfa'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Text('🏠', style: TextStyle(fontSize: 22)),
                title: Text(t(context, 'Ana Sayfa')),
                subtitle: Text(homeCount == 0
                    ? t(context, 'Henüz blok yok — dokunup blok ekle')
                    : '$homeCount ${t(context, 'blok')}'),
                trailing: IconButton(
                  tooltip: t(context, 'Önizle'),
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: _previewHome,
                ),
                onTap: _editHome,
              ),
            ),

            if (_multiPage) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '${t(context, 'Ek Sayfalar')} (${_extraPages.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addOrEditPage(),
                    icon: const Icon(Icons.add),
                    label: Text(t(context, 'Sayfa Ekle')),
                  ),
                ],
              ),
              for (var i = 0; i < _extraPages.length; i++)
                Card(
                  child: ListTile(
                    title: Text(_extraPages[i]['title'] ?? ''),
                    subtitle: Text(_pageSubtitle(_extraPages[i])),
                    onTap: () => _addOrEditPage(existing: _extraPages[i], index: i),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _extraPages.removeAt(i)),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),
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
