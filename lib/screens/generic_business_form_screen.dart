import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/kuafor_html_generator.dart';
import '../templates/html/generic_business_html_generator.dart';
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
import '../widgets/app_popup.dart';

/// "Genel İşletme" — sektöre özel bir form yoksa (kırtasiye, bakkal,
/// kuyumcu, optik, züccaciye vb.) kullanılacak, hem TEK hem ÇOK sayfa
/// üretebilen tek ekran.
///
/// kuafor_form_screen.dart kalıbını temel alır (aynı alanlar: hizmetler,
/// galeri, çalışma saatleri, konum, iletişim, tema) ama İKİ FARKLILIK var:
///  1) Üstte bir "Tek Sayfa / Çok Sayfa" segment seçici — Çok Sayfa
///     seçilirse kullanıcı serbest başlık+içerikli "Ek Sayfalar"
///     (Hakkımızda, Kurumsal, SSS vb.) ekleyebilir; bunlar
///     generic_business_html_generator.dart > generateGenericBusinessSite
///     ile index.html'e bağlı, ortak üst menülü ayrı .html dosyaları olur.
///  2) SİTE İÇERİĞİ DİLİ artık uygulama arayüz diline (LocaleController)
///     otomatik bağlı DEĞİL — kullanıcı burada bağımsız olarak TR/EN
///     seçebiliyor (diğer sektör formlarında bu hep app diline bağlıydı;
///     burada bilinçli olarak ayrıştırıldı, bkz. _siteLang).
class GenericBusinessFormScreen extends StatefulWidget {
  const GenericBusinessFormScreen({super.key, this.initialData, this.isEditing = false});

  /// 25.08.2026 eklendi — Düzenle akışı: önceden kaydedilmiş ham form
  /// alanları (bkz. services/qt_form_data_codec.dart).
  final Map<String, dynamic>? initialData;

  /// true ise bu ekran "Düzenle" akışıyla açılmıştır — buton metni ve
  /// puan maliyeti buna göre değişir (bkz. _generate).
  final bool isEditing;

  @override
  State<GenericBusinessFormScreen> createState() => _GenericBusinessFormScreenState();
}

class _GenericBusinessFormScreenState extends State<GenericBusinessFormScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _googleReviewCtrl = TextEditingController(); // 01.09.2026 eklendi

  String _selectedTheme = 'clean_light';
  String _fontPackageId = 'modern_sade';
  String _typeDensity = 'normal';
  String _galleryStyle = 'grid';
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BAĞIMSIZ, kullanıcı
  // seçiyor. Varsayılan olarak açılışta app diline eşitleniyor (initState),
  // ama kullanıcı isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';
  bool _multiPage = false;
  bool _generating = false;

  List<Map<String, String?>> _cover = [];
  List<Map<String, String?>> _gallery = [];
  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  // Çok Sayfa modunda kullanıcının eklediği ek sayfalar: {slug, title, content}
  final List<Map<String, String>> _extraPages = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial != null) {
      _restoreFromInitialData(initial);
    }
    // Açılışta uygulamanın o anki diliyle eşitle — kullanıcı isterse
    // aşağıdaki seçiciden değiştirebilir (bkz. sınıf yorumu).
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
    _servicesCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    _googleReviewCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String?>> _parseServices(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
      final parts = line.split('-').map((p) => p.trim()).toList();
      if (parts.length >= 3) {
        return {'name': parts[0], 'duration': parts[1], 'price': parts[2]};
      } else if (parts.length == 2) {
        return {'name': parts[0], 'duration': null, 'price': parts[1]};
      }
      return {'name': parts[0], 'duration': null, 'price': ''};
    }).toList();
  }

  Future<void> _addOrEditPage({Map<String, String>? existing, int? index}) async {
    final existingSlugs = _extraPages
        .asMap()
        .entries
        .where((e) => e.key != index)
        .map((e) => e.value['slug']!)
        .toSet();
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExtraPageEditorSheet(existing: existing, existingSlugs: existingSlugs),
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
      'servicesCtrl': _servicesCtrl.text,
      'addressCtrl': _addressCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'whatsappCtrl': _whatsappCtrl.text,
      'instagramCtrl': _instagramCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
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
      'extraPages': _extraPages,
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['nameCtrl'] as String?) ?? _nameCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _aboutCtrl.text = (d['aboutCtrl'] as String?) ?? _aboutCtrl.text;
    _servicesCtrl.text = (d['servicesCtrl'] as String?) ?? _servicesCtrl.text;
    _addressCtrl.text = (d['addressCtrl'] as String?) ?? _addressCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _whatsappCtrl.text = (d['whatsappCtrl'] as String?) ?? _whatsappCtrl.text;
    _instagramCtrl.text = (d['instagramCtrl'] as String?) ?? _instagramCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
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
    if (d['extraPages'] != null) {
      _extraPages
        ..clear()
        ..addAll(qtDecodeStringMapList(d['extraPages']));
    }
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'İşletme adı ve telefon gerekli.'), icon: '⚠️');
      return;
    }
    if (_multiPage && _extraPages.isEmpty) {
      showAppPopup(context, message: t(context, 'Çok sayfa modunda en az 1 ek sayfa eklemelisin.'), icon: '⚠️');
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    final services = _parseServices(_servicesCtrl.text);
    final coverUrl = _cover.isNotEmpty && (_cover.first['url'] ?? '').isNotEmpty
        ? _cover.first['url']!
        : 'https://placehold.co/1200x800';

    bool ok;
    if (_multiPage) {
      ok = await LocalGenerationHelper.generateMultiPage(
        context: context,
        projectNameHint: _nameCtrl.text.trim(),
        kind: ProjectKind.genericBusiness,
        formData: formData,
        isEditing: widget.isEditing,
        activeFileName: 'index.html',
        buildFiles: () => generateGenericBusinessSite(
          name: _nameCtrl.text.trim(),
          coverImage: coverUrl,
          tagline: _taglineCtrl.text.trim(),
          about: _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim(),
          services: services,
          gallery: _gallery,
          workingHours: _workingHours,
          address: _addressCtrl.text.trim(),
          lat: _lat,
          lng: _lng,
          phone: _phoneCtrl.text.trim(),
          whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
          googleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
          instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
          themeId: _selectedTheme,
          fontPackageId: _fontPackageId,
          density: _typeDensity,
          galleryStyle: _galleryStyle,
          lang: _siteLang,
          extraPages: _extraPages,
        ),
      );
    } else {
      ok = await LocalGenerationHelper.generateSinglePage(
        context: context,
        projectNameHint: _nameCtrl.text.trim(),
        kind: ProjectKind.genericBusiness,
        formData: formData,
        isEditing: widget.isEditing,
        buildHtml: () => generateBusinessSiteHtml(
          name: _nameCtrl.text.trim(),
          coverImage: coverUrl,
          tagline: _taglineCtrl.text.trim(),
          about: _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim(),
          services: services,
          gallery: _gallery,
          workingHours: _workingHours,
          address: _addressCtrl.text.trim(),
          lat: _lat,
          lng: _lng,
          phone: _phoneCtrl.text.trim(),
          whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
          googleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
          instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
          themeId: _selectedTheme,
          fontPackageId: _fontPackageId,
          density: _typeDensity,
          galleryStyle: _galleryStyle,
          lang: _siteLang,
        ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? '${t(context, 'Genel İşletme Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Genel İşletme Sitesi'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t(context, 'Sektörüne özel bir şablon bulamadıysan (kırtasiye, bakkal, kuyumcu, optik, züccaciye vb.) bu genel şablonu kullanabilirsin.'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            // --- Tek Sayfa / Çok Sayfa seçici ---
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
                  ? t(context, 'İstediğin kadar ek sayfa (Hakkımızda, Kurumsal, SSS vb.) ekleyebilirsin, hepsi ortak bir menüyle bağlanır.')
                  : t(context, 'Tüm içerik tek bir sayfada, kaydırarak gezilir.'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),

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
              decoration: InputDecoration(labelText: t(context, 'İşletme adı'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: InputDecoration(labelText: t(context, 'Slogan (opsiyonel)'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aboutCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: t(context, 'Hakkında (opsiyonel)'), border: const OutlineInputBorder()),
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
              controller: _servicesCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: t(context, 'Ürün/Hizmetler (her satıra bir tane: Ad - Fiyat)'),
                hintText: t(context, 'Kurşun Kalem - 15 TL\nDefter - 40 TL'),
                border: const OutlineInputBorder(),
              ),
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
            WorkingHoursPickerField(
              initialHours: _workingHours,
              onChanged: (v) => _workingHours = v,
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
              decoration: InputDecoration(labelText: t(context, 'Telefon'), border: const OutlineInputBorder()),
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
            // 01.09.2026 eklendi — Google İşletme Profili'ndeki "yorum yaz"
            // linki (örn. https://g.page/r/xxxxx/review). Doluysa sitede
            // diğer iletişim butonlarının yanına bir "Bizi Google'da
            // Değerlendirin" butonu eklenir (bkz. contactBlockHtml).
            TextField(
              controller: _googleReviewCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: t(context, 'Google Yorum Linki (opsiyonel)'),
                hintText: 'https://g.page/r/.../review',
                border: const OutlineInputBorder(),
              ),
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

            if (_multiPage) ...[
              const SizedBox(height: 24),
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
                    subtitle: Text('${_extraPages[i]['slug']}.html'),
                    onTap: () => _addOrEditPage(existing: _extraPages[i], index: i),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _extraPages.removeAt(i)),
                    ),
                  ),
                ),
            ],

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

/// Çok Sayfa modunda tek bir "ek sayfa"nın (Hakkımızda, Kurumsal, SSS vb.)
/// başlık + serbest metin içeriğini düzenlemek için alt sayfa.
class _ExtraPageEditorSheet extends StatefulWidget {
  final Map<String, String>? existing;
  final Set<String> existingSlugs;
  const _ExtraPageEditorSheet({this.existing, required this.existingSlugs});

  @override
  State<_ExtraPageEditorSheet> createState() => _ExtraPageEditorSheetState();
}

class _ExtraPageEditorSheetState extends State<_ExtraPageEditorSheet> {
  late final _titleCtrl = TextEditingController(text: widget.existing?['title'] ?? '');
  late final _contentCtrl = TextEditingController(text: widget.existing?['content'] ?? '');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showAppPopup(context, message: t(context, 'Sayfa başlığı gerekli.'), icon: '⚠️');
      return;
    }
    // Mevcut sayfayı düzenliyorsak slug'ı KORU (linkler kırılmasın); yeni
    // sayfada başlıktan üret (bkz. generic_business_html_generator.dart >
    // slugifyPageTitle).
    final slug = widget.existing?['slug'] ?? slugifyPageTitle(title, widget.existingSlugs);
    Navigator.pop(context, {
      'slug': slug,
      'title': title,
      'content': _contentCtrl.text.trim(),
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
            Text(
              t(context, widget.existing == null ? 'Yeni Sayfa' : 'Sayfayı Düzenle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'Sayfa başlığı (örn. Hakkımızda)'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: t(context, 'İçerik'),
                hintText: t(context, 'Paragrafları boş satırla ayırabilirsin.'),
                border: const OutlineInputBorder(),
              ),
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
