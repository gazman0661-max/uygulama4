import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/kuafor_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// ŞABLON EKRAN — diğer sektör formları bu dosyanın yapısı kopyalanarak
/// üretildi (kafe, güzellik salonu, klinik, fitness, oto yıkama, emlak,
/// portfolyo — bkz. lib/screens/). Değişen tek şey: form alanları + hangi
/// generator fonksiyonunun çağrıldığı.
///
/// Uzak sunucuya HİÇ gitmiyor — form verisi doğrudan generateBusinessSiteHtml'e
/// (kuafor_html_generator.dart) parametre olarak geçiyor.
///
/// Galeri / çalışma saatleri / konum artık ortak widget'lardan geliyor:
/// widgets/gallery_picker_field.dart, working_hours_picker_field.dart,
/// location_picker_field.dart.
class KuaforFormScreen extends StatefulWidget {
  const KuaforFormScreen({super.key});

  @override
  State<KuaforFormScreen> createState() => _KuaforFormScreenState();
}

class _KuaforFormScreenState extends State<KuaforFormScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController(); // "Ad - Süre - Fiyat" satır satır
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  String _selectedTheme = 'clean_light';
  bool _generating = false;
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BA�ĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  // Varsayılan olarak açılışta app diline eşitlenir (initState), kullanıcı
  // isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';

  List<Map<String, String?>> _cover = [];
  List<Map<String, String?>> _gallery = [];
  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  @override
  void initState() {
    super.initState();
    // Açılışta uygulamanın o anki diliyle eşitle — kullanıcı isterse
    // aşağıdaki seçiciden değiştirebilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _siteLang = context.read<LocaleController>().isEnglish ? 'en' : 'tr';
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _servicesCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  /// "Ad - Süre - Fiyat" ya da "Ad - Fiyat" satırlarını parse eder.
  /// Süre opsiyonel olduğu için 2 veya 3 parçalı satırları da kabul eder.
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

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'İşletme adı ve telefon gerekli.'))),
      );
      return;
    }
    setState(() => _generating = true);

    final services = _parseServices(_servicesCtrl.text);
    final siteLang = _siteLang;
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: _nameCtrl.text.trim(),
      kind: ProjectKind.kuafor,
      buildHtml: () => generateBusinessSiteHtml(
        name: _nameCtrl.text.trim(),
        coverImage: _cover.isNotEmpty && (_cover.first['url'] ?? '').isNotEmpty
            ? _cover.first['url']!
            : 'https://placehold.co/1200x800',
        tagline: _taglineCtrl.text.trim(),
        services: services,
        gallery: _gallery,
        workingHours: _workingHours,
        address: _addressCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        phone: _phoneCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
        themeId: _selectedTheme,
        lang: siteLang,
        schemaType: 'HairSalon',
      ),
    );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final generating = _generating || context.watch<AppState>().isGenerating;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'Kuaför / Berber Sitesi'))),
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
                labelText: t(context, 'Hizmetler (her satıra bir tane: Ad - Süre - Fiyat)'),
                hintText: t(context, 'Saç Kesimi - 30 dk - 150 TL\nSakal Tıraşı - 100 TL'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GalleryPickerField(
              initialImages: _gallery,
              onChanged: (v) => _gallery = v,
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
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: t(context, generating ? 'Oluşturuluyor...' : 'Siteyi Oluştur'),
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
