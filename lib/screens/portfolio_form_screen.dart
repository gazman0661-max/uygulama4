import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/portfolio_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/gallery_picker_field.dart';
import 'preview_screen.dart';

/// kuafor_form_screen.dart kalıbından kopyalandı. Generator:
/// portfolio_html_generator.dart -> generatePortfolioHtml.
/// Konum/çalışma saati yok (portfolyo sitesinde anlamsız); iletişim
/// e-posta üzerinden mailto formu ile çözülüyor (contactFormBlockHtml).
class PortfolioFormScreen extends StatefulWidget {
  const PortfolioFormScreen({super.key});

  @override
  State<PortfolioFormScreen> createState() => _PortfolioFormScreenState();
}

class _PortfolioFormScreenState extends State<PortfolioFormScreen> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController(); // virgülle ayrılmış
  final _timelineCtrl = TextEditingController(); // Yıl - Başlık - Açıklama
  final _emailCtrl = TextEditingController();
  bool _generating = false;

  List<Map<String, String?>> _works = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _photoCtrl.dispose();
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
        const SnackBar(content: Text('İsim ve e-posta gerekli.')),
      );
      return;
    }
    setState(() => _generating = true);

    final skills = _parseSkills(_skillsCtrl.text);
    final timeline = _parseTimeline(_timelineCtrl.text);
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: '${_nameCtrl.text.trim()} - Portfolyo',
      kind: ProjectKind.portfolio,
      buildHtml: () => generatePortfolioHtml(
        name: _nameCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        photo: _photoCtrl.text.trim().isEmpty ? 'https://placehold.co/600x600' : _photoCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        aboutText: _aboutCtrl.text.trim(),
        skills: skills,
        works: _works,
        timeline: timeline,
        contactEmail: _emailCtrl.text.trim(),
      ),
    );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreviewScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final generating = _generating || context.watch<AppState>().isGenerating;
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolyo Sitesi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'İsim', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Meslek / unvan', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: const InputDecoration(labelText: 'Slogan (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _photoCtrl,
              decoration: const InputDecoration(labelText: 'Profil fotoğrafı URL (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aboutCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Hakkında', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skillsCtrl,
              decoration: const InputDecoration(
                labelText: 'Yetenekler (virgülle ayır)',
                hintText: 'Figma, UI Tasarım, Flutter',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timelineCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Deneyim & eğitim (her satıra bir tane: Yıl - Başlık - Açıklama)',
                hintText: '2023 - UI/UX Tasarımcı - Freelance\n2020 - Grafik Tasarım - Üniversite',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GalleryPickerField(label: 'İş Örnekleri', initialImages: _works, onChanged: (v) => _works = v),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'İletişim e-postası', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: generating ? 'Oluşturuluyor...' : 'Siteyi Oluştur',
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
