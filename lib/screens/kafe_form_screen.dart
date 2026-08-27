import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/cafe_html_generator.dart';
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
  late bool _multiPage = widget.initialMultiPage; // false: tek sayfa (generateCafeHtml), true: Ana Sayfa+Menü+Galeri (generateCafeSite)

  List<Map<String, String?>> _cover = [];
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
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
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
      'nameCtrl': _nameCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'aboutCtrl': _aboutCtrl.text,
      'menuCtrl': _menuCtrl.text,
      'menuUrlCtrl': _menuUrlCtrl.text,
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
      'cover': _cover,
      'gallery': _gallery,
      'workingHours': _workingHours,
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _menuCtrl.text = (d['menuCtrl'] as String?) ?? _menuCtrl.text;
    _menuUrlCtrl.text = (d['menuUrlCtrl'] as String?) ?? _menuUrlCtrl.text;
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
    if (d['cover'] != null) {
      _cover = qtDecodeNullableStringMapList(d['cover']);
    }
    if (d['gallery'] != null) {
      _gallery = qtDecodeNullableStringMapList(d['gallery']);
    }
    if (d['workingHours'] != null) {
      _workingHours = qtDecodeNullableStringMapList(d['workingHours']);
    }
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'İşletme adı ve telefon gerekli.'))),
      );
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    final menuCategories = _parseMenu(_menuCtrl.text);
    final coverUrl = _cover.isNotEmpty && (_cover.first['url'] ?? '').isNotEmpty
        ? _cover.first['url']!
        : 'https://placehold.co/1200x800';
    final about = _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim();
    final menuUrl = _menuUrlCtrl.text.trim().isEmpty ? null : _menuUrlCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim();
    final instagram = _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim();
    // Site içeriğinin dili, uygulamada seçili olan arayüz diliyle AYNI —
    // kullanıcıya ayrıca sormuyoruz. Kullanıcı Ayarlar'dan TR<->EN
    // değiştirdiğinde bir sonraki ürettiği site de otomatik o dilde olur.
    final siteLang = _siteLang;

    final ok = _multiPage
        ? await LocalGenerationHelper.generateMultiPage(
            context: context,
            projectNameHint: _nameCtrl.text.trim(),
            kind: ProjectKind.kafe,
            formData: formData,
            isEditing: widget.isEditing,
            activeFileName: 'index.html',
            buildFiles: () => generateCafeSite(
              name: _nameCtrl.text.trim(),
              coverImage: coverUrl,
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
              themeId: _selectedTheme,
              fontPackageId: _fontPackageId,
              density: _typeDensity,
              galleryStyle: _galleryStyle,
              lang: siteLang,
            ),
          )
        : await LocalGenerationHelper.generateSinglePage(
            context: context,
            projectNameHint: _nameCtrl.text.trim(),
            kind: ProjectKind.kafe,
            formData: formData,
            isEditing: widget.isEditing,
            buildHtml: () => generateCafeHtml(
              name: _nameCtrl.text.trim(),
              coverImage: coverUrl,
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
