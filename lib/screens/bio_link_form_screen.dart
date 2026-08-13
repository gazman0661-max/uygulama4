import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/bio_link_html_generator.dart';
import '../widgets/pill_button.dart';
import 'preview_screen.dart';

/// Kısa bir form doldurulur, AI'ya HİÇ gitmeden yerel olarak (bio_link_html_
/// generator.dart) tek sayfalık bir "biyo link" HTML'i üretilir.
class BioLinkFormScreen extends StatefulWidget {
  const BioLinkFormScreen({super.key});

  @override
  State<BioLinkFormScreen> createState() => _BioLinkFormScreenState();
}

class _BioLinkFormScreenState extends State<BioLinkFormScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  final _linksCtrl = TextEditingController();
  String _selectedTheme = 'clean_light';
  bool _generating = false;

  static const _themeOptions = [
    {'id': 'clean_light', 'label': 'Clean Light'},
    {'id': 'midnight_dark', 'label': 'Midnight Dark'},
    {'id': 'sunset_gradient', 'label': 'Sunset Gradient'},
    {'id': 'neon_cyber', 'label': 'Neon Cyber'},
    {'id': 'soft_pastel', 'label': 'Soft Pastel'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _avatarCtrl.dispose();
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
        const SnackBar(content: Text('İsim ve en az bir link gerekli.')),
      );
      return;
    }
    setState(() => _generating = true);

    final links = _parseLinks(_linksCtrl.text);
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: '${_nameCtrl.text.trim()} - Biyo Link',
      kind: ProjectKind.bioLink,
      buildHtml: () => generateBioLinkHtml(
        name: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        avatarUrl: _avatarCtrl.text.trim().isEmpty
            ? 'https://placehold.co/200x200'
            : _avatarCtrl.text.trim(),
        links: links,
        socials: const [],
        themeId: _selectedTheme,
      ),
    );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PreviewScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final generating = _generating || context.watch<AppState>().isGenerating;
    return Scaffold(
      appBar: AppBar(title: const Text('Biyo Link Sayfası')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'İsim / marka adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Kısa açıklama (opsiyonel, max 100 karakter)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _avatarCtrl,
              decoration: const InputDecoration(
                labelText: 'Profil fotoğrafı URL (opsiyonel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linksCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Linkler (her satıra bir tane: Etiket - URL)',
                hintText: 'Instagram - https://instagram.com/kullanici\nYoutube - https://youtube.com/@kanal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tema', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    label: generating ? 'Oluşturuluyor...' : 'Sayfayı Oluştur',
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
