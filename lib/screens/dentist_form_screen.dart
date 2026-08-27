import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/clinic_html_generator.dart';
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

/// clinic_form_screen.dart kalıbından kopyalandı. Generator: AYNI
/// generateClinicHtml (clinic_html_generator.dart), sadece başlık ve
/// metinler Diş Hekimi Sitesi için özelleştirildi.
class DentistFormScreen extends StatefulWidget {
  const DentistFormScreen({super.key, this.initialMultiPage = false, this.initialData, this.isEditing = false});

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
  State<DentistFormScreen> createState() => _DentistFormScreenState();
}

class _DentistFormScreenState extends State<DentistFormScreen> {
  final _businessNameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(); // "Uzman Psikolog" gibi unvan
  final _taglineCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController(); // uzmanlık alanları
  final _bioCtrl = TextEditingController();
  final _credentialsCtrl = TextEditingController(); // her satır bir unvan/sertifika
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  String _selectedTheme = 'clean_light';
  String _fontPackageId = 'modern_sade';
  String _typeDensity = 'normal';
  String _galleryStyle = 'grid';
  bool _generating = false;
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BA�ĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  // Varsayılan olarak açılışta app diline eşitlenir (initState), kullanıcı
  // isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';
  late bool _multiPage = widget.initialMultiPage; // false: tek sayfa (generateClinicHtml), true: Ana Sayfa+Hizmetler+Randevu (generateClinicSite)

  List<Map<String, String?>> _photo = [];
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
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
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
      'businessNameCtrl': _businessNameCtrl.text,
      'titleCtrl': _titleCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'servicesCtrl': _servicesCtrl.text,
      'bioCtrl': _bioCtrl.text,
      'credentialsCtrl': _credentialsCtrl.text,
      'addressCtrl': _addressCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'whatsappCtrl': _whatsappCtrl.text,
      'instagramCtrl': _instagramCtrl.text,
      'selectedTheme': _selectedTheme,
      'fontPackageId': _fontPackageId,
      'typeDensity': _typeDensity,
      'galleryStyle': _galleryStyle,
      'siteLang': _siteLang,
      'lat': _lat,
      'lng': _lng,
      'multiPage': _multiPage,
      'photo': _photo,
      'workingHours': _workingHours,
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _businessNameCtrl.text = (d['businessNameCtrl'] as String?) ?? _businessNameCtrl.text;
    _titleCtrl.text = (d['titleCtrl'] as String?) ?? _titleCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _servicesCtrl.text = (d['servicesCtrl'] as String?) ?? _servicesCtrl.text;
    _bioCtrl.text = (d['bioCtrl'] as String?) ?? _bioCtrl.text;
    _credentialsCtrl.text = (d['credentialsCtrl'] as String?) ?? _credentialsCtrl.text;
    _addressCtrl.text = (d['addressCtrl'] as String?) ?? _addressCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _whatsappCtrl.text = (d['whatsappCtrl'] as String?) ?? _whatsappCtrl.text;
    _instagramCtrl.text = (d['instagramCtrl'] as String?) ?? _instagramCtrl.text;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
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
    if (d['workingHours'] != null) {
      _workingHours = qtDecodeNullableStringMapList(d['workingHours']);
    }
  }

  Future<void> _generate() async {
    if (_businessNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'Klinik/uzman adı ve telefon gerekli.'))),
      );
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
            projectNameHint: _businessNameCtrl.text.trim(),
            kind: ProjectKind.dentist,
            formData: formData,
            isEditing: widget.isEditing,
            activeFileName: 'index.html',
            buildFiles: () => generateClinicSite(
              businessName: _businessNameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photoUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : 'https://placehold.co/800x800',
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
              themeId: _selectedTheme,
              fontPackageId: _fontPackageId,
              density: _typeDensity,
              galleryStyle: _galleryStyle,
              lang: siteLang,
            ),
          )
        : await LocalGenerationHelper.generateSinglePage(
            context: context,
            projectNameHint: _businessNameCtrl.text.trim(),
            kind: ProjectKind.dentist,
            formData: formData,
            isEditing: widget.isEditing,
            buildHtml: () => generateClinicHtml(
              businessName: _businessNameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photoUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : 'https://placehold.co/800x800',
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
              themeId: _selectedTheme,
              fontPackageId: _fontPackageId,
              density: _typeDensity,
              galleryStyle: _galleryStyle,
              lang: siteLang,
            ),
          );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()));
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
              ? '${t(context, 'Diş Hekimi Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Diş Hekimi Sitesi'),
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
              decoration: InputDecoration(labelText: t(context, 'Klinik / hekim adı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'Unvan (örn. Diş Hekimi)'), border: OutlineInputBorder()),
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
            TextField(
              controller: _servicesCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t(context, 'Uzmanlık alanları (her satıra bir tane)'),
                hintText: t(context, 'İmplant Tedavisi\nDiş Beyazlatma\nOrtodonti'),
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
