import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/portfolio_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import 'preview_screen.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// portfolio_form_screen.dart kalıbından kopyalandı. Generator: AYNI
/// generatePortfolioHtml (portfolio_html_generator.dart), sadece başlık
/// ve metinler Fotoğrafçı Sitesi için özelleştirildi.
class PhotographerFormScreen extends StatefulWidget {
  const PhotographerFormScreen({super.key, this.initialMultiPage = false});

  /// Ana ekrandaki üst "Tek Sayfa / Çok Sayfa" seçicisinden hangi modla
  /// açıldığını taşır — true ise form, çok sayfalı anahtarı açık başlar.
  final bool initialMultiPage;

  @override
  State<PhotographerFormScreen> createState() => _PhotographerFormScreenState();
}

class _PhotographerFormScreenState extends State<PhotographerFormScreen> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController(); // virgülle ayrılmış
  final _timelineCtrl = TextEditingController(); // Yıl - Başlık - Açıklama
  final _emailCtrl = TextEditingController();
  String _selectedTheme = 'clean_light';
  bool _generating = false;
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BA�ĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  // Varsayılan olarak açılışta app diline eşitlenir (initState), kullanıcı
  // isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';
  late bool _multiPage = widget.initialMultiPage; // false: tek sayfa (generatePortfolioHtml), true: Ana Sayfa+iş detay sayfaları (generatePortfolioSite)

  List<Map<String, String?>> _photo = [];
  List<Map<String, String?>> _works = [];

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
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _aboutCtrl.dispose();
    _skillsCtrl.dispose();
    _timelineCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
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

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'İsim ve e-posta gerekli.'))),
      );
      return;
    }
    setState(() => _generating = true);

    final skills = _parseSkills(_skillsCtrl.text);
    final timeline = _parseTimeline(_timelineCtrl.text);
    final siteLang = _siteLang;
    final ok = _multiPage
        ? await LocalGenerationHelper.generateMultiPage(
            context: context,
            projectNameHint: '${_nameCtrl.text.trim()} - Portfolyo',
            kind: ProjectKind.photographer,
            activeFileName: 'index.html',
            buildFiles: () => generatePortfolioSite(
              name: _nameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photo: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : 'https://placehold.co/600x600',
              tagline: _taglineCtrl.text.trim(),
              aboutText: _aboutCtrl.text.trim(),
              skills: skills,
              works: _works,
              timeline: timeline,
              contactEmail: _emailCtrl.text.trim(),
              themeId: _selectedTheme,
              lang: siteLang,
            ),
          )
        : await LocalGenerationHelper.generateSinglePage(
            context: context,
            projectNameHint: '${_nameCtrl.text.trim()} - Portfolyo',
            kind: ProjectKind.photographer,
            buildHtml: () => generatePortfolioHtml(
              name: _nameCtrl.text.trim(),
              title: _titleCtrl.text.trim(),
              photo: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
                  ? _photo.first['url']!
                  : 'https://placehold.co/600x600',
              tagline: _taglineCtrl.text.trim(),
              aboutText: _aboutCtrl.text.trim(),
              skills: skills,
              works: _works,
              timeline: timeline,
              contactEmail: _emailCtrl.text.trim(),
              themeId: _selectedTheme,
              lang: siteLang,
            ),
          );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final generating = _generating || context.watch<AppState>().isGenerating;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'Fotoğrafçı Sitesi'))),
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
              decoration: InputDecoration(labelText: t(context, 'İsim'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'Uzmanlık (örn. Düğün Fotoğrafçısı)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: InputDecoration(labelText: t(context, 'Slogan (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            GalleryPickerField(
              label: t(context, 'Profil Fotoğrafı'),
              maxImages: 1,
              initialImages: _photo,
              onChanged: (v) => _photo = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aboutCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: t(context, 'Hakkında'), border: OutlineInputBorder()),
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
            GalleryPickerField(label: t(context, 'Fotoğraf Örnekleri'), initialImages: _works, onChanged: (v) => _works = v),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: t(context, 'İletişim e-postası'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ThemePickerField(
              initialThemeId: _selectedTheme,
              onChanged: (v) => _selectedTheme = v,
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
