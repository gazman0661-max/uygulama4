import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/bio_link_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/gallery_picker_field.dart';
import 'preview_screen.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// Kısa bir form doldurulur, uzak sunucuya HİÇ gitmeden yerel olarak (bio_link_html_
/// generator.dart) tek sayfalık bir "biyo link" HTML'i üretilir.
class BioLinkFormScreen extends StatefulWidget {
  const BioLinkFormScreen({super.key});

  @override
  State<BioLinkFormScreen> createState() => _BioLinkFormScreenState();
}

class _BioLinkFormScreenState extends State<BioLinkFormScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _linksCtrl = TextEditingController();
  String _selectedTheme = 'clean_light';
  bool _generating = false;
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BA�ĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  // Varsayılan olarak açılışta app diline eşitlenir (initState), kullanıcı
  // isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';

  List<Map<String, String?>> _avatar = [];

  static const _themeOptions = [
    {'id': 'clean_light', 'label': 'Clean Light'},
    {'id': 'midnight_dark', 'label': 'Midnight Dark'},
    {'id': 'sunset_gradient', 'label': 'Sunset Gradient'},
    {'id': 'neon_cyber', 'label': 'Neon Cyber'},
    {'id': 'soft_pastel', 'label': 'Soft Pastel'},
  ];

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
    _bioCtrl.dispose();
    _linksCtrl.dispose();
    super.dispose();
  }

  /// "Etiket - URL" formatındaki satırları {title, url} listesine çevirir.
  List<Map<String, String>> _parseLinks(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.contains('-'))
        .map((line) {
      final idx = line.indexOf('-');
      return {
        'title': line.substring(0, idx).trim(),
        'url': line.substring(idx + 1).trim(),
      };
    }).toList();
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _linksCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'İsim ve en az bir link gerekli.'))),
      );
      return;
    }
    setState(() => _generating = true);

    final links = _parseLinks(_linksCtrl.text);
    final siteLang = _siteLang;
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: '${_nameCtrl.text.trim()} - Biyo Link',
      kind: ProjectKind.bioLink,
      buildHtml: () => generateBioLinkHtml(
        name: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        avatarUrl: _avatar.isNotEmpty && (_avatar.first['url'] ?? '').isNotEmpty
            ? _avatar.first['url']!
            : 'https://placehold.co/200x200',
        links: links,
        socials: const [],
        themeId: _selectedTheme,
        lang: siteLang,
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
      appBar: AppBar(title: Text(t(context, 'Biyo Link Sayfası'))),
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
                labelText: t(context, 'İsim / marka adı'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: t(context, 'Kısa açıklama (opsiyonel, max 100 karakter)'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            GalleryPickerField(
              label: t(context, 'Profil Fotoğrafı'),
              maxImages: 1,
              initialImages: _avatar,
              onChanged: (v) => _avatar = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linksCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: t(context, 'Linkler (her satıra bir tane: Etiket - URL)'),
                hintText: t(context, 'Instagram - https://instagram.com/kullanici\nYoutube - https://youtube.com/@kanal'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(t(context, 'Tema'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _themeOptions.map((t) {
                final selected = _selectedTheme == t['id'];
                return ChoiceChip(
                  label: Text(t['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedTheme = t['id']!),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: t(context, generating ? 'Oluşturuluyor...' : 'Sayfayı Oluştur'),
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
