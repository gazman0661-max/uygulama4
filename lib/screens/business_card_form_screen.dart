import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/business_card_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import 'preview_screen.dart';
import '../services/qt_form_data_codec.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/app_popup.dart';

/// Kısa bir form doldurulur, uzak sunucuya HİÇ gitmeden yerel olarak
/// (business_card_html_generator.dart) tek sayfalık bir "dijital kartvizit"
/// HTML'i üretilir.
class BusinessCardFormScreen extends StatefulWidget {
  const BusinessCardFormScreen({super.key, this.initialData, this.isEditing = false});

  /// 25.08.2026 eklendi — Düzenle akışı: önceden kaydedilmiş ham form
  /// alanları (bkz. services/qt_form_data_codec.dart).
  final Map<String, dynamic>? initialData;

  /// true ise bu ekran "Düzenle" akışıyla açılmıştır — buton metni ve
  /// puan maliyeti buna göre değişir (bkz. _generate).
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
  String _selectedTheme = 'clean_light';
  bool _generating = false;
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BA�ĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  // Varsayılan olarak açılışta app diline eşitlenir (initState), kullanıcı
  // isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';

  List<Map<String, String?>> _photo = [];

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
    _titleCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _linksCtrl.dispose();
    super.dispose();
  }

  /// "Etiket - URL" formatındaki satırları {platform, url} listesine çevirir.
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

  /// 25.08.2026 eklendi — Düzenle akışı: bu formun HAM alan
  /// değerlerinin JSON-uyumlu bir anlık görüntüsü (bkz.
  /// services/qt_form_data_codec.dart). Üretim/düzenleme başarıyla
  /// bittiğinde AppState.qtFormData'ya yazılır ki sonraki "Düzenle"
  /// bu formu dolu açabilsin.
  Map<String, dynamic> _captureFormData() {
    return {
      'nameCtrl': _nameCtrl.text,
      'titleCtrl': _titleCtrl.text,
      'companyCtrl': _companyCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'emailCtrl': _emailCtrl.text,
      'linksCtrl': _linksCtrl.text,
      'selectedTheme': _selectedTheme,
      'siteLang': _siteLang,
      'photo': _photo,
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _titleCtrl.text = (d['titleCtrl'] as String?) ?? _titleCtrl.text;
    _companyCtrl.text = (d['companyCtrl'] as String?) ?? _companyCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _emailCtrl.text = (d['emailCtrl'] as String?) ?? _emailCtrl.text;
    _linksCtrl.text = (d['linksCtrl'] as String?) ?? _linksCtrl.text;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
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
      projectNameHint: '${_nameCtrl.text.trim()} - Kartvizit',
      kind: ProjectKind.businessCard,
      formData: formData,
      isEditing: widget.isEditing,
      buildHtml: () => generateBusinessCardHtml(
        name: _nameCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        company: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        socials: socials,
        avatarUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
            ? _photo.first['url']
            : null,
        themeId: _selectedTheme,
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
                labelText: t(context, 'Telefon'),
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
              onChanged: (v) => _selectedTheme = v,
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
