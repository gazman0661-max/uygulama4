import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/kuafor_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/accent_color_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';

/// kuafor_form_screen.dart kalıbından kopyalandı. Generator: AYNI
/// generateBusinessSiteHtml (kuafor_html_generator.dart) — dosyanın kendi
/// yorumunda da belirtildiği gibi oto yıkama bu genel BusinessSite
/// yapısını başlıklar değiştirilerek kullanabilir.
class CarWashFormScreen extends StatefulWidget {
  const CarWashFormScreen({super.key});

  @override
  State<CarWashFormScreen> createState() => _CarWashFormScreenState();
}

class _CarWashFormScreenState extends State<CarWashFormScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController(); // "Ad - Süre - Fiyat"
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  String _accentColor = '#0B5394';
  bool _generating = false;

  List<Map<String, String?>> _gallery = [];
  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _coverCtrl.dispose();
    _servicesCtrl.dispose();
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
        const SnackBar(content: Text('İşletme adı ve telefon gerekli.')),
      );
      return;
    }
    setState(() => _generating = true);

    final services = _parseServices(_servicesCtrl.text);
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: _nameCtrl.text.trim(),
      kind: ProjectKind.carWash,
      buildHtml: () => generateBusinessSiteHtml(
        name: _nameCtrl.text.trim(),
        coverImage: _coverCtrl.text.trim().isEmpty
            ? 'https://placehold.co/1200x800'
            : _coverCtrl.text.trim(),
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
        servicesTitle: 'Yıkama & Bakım Paketleri',
        ctaText: 'Randevu Al',
        accentColor: _accentColor,
      ),
    );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreviewScreen(isQuickTools: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final generating = _generating || context.watch<AppState>().isGenerating;
    return Scaffold(
      appBar: AppBar(title: const Text('Oto Yıkama / Servis Sitesi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'İşletme adı', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: const InputDecoration(labelText: 'Slogan (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coverCtrl,
              decoration: const InputDecoration(labelText: 'Kapak görsel URL (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _servicesCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Paketler (her satıra bir tane: Ad - Süre - Fiyat)',
                hintText: 'İç-Dış Yıkama - 30 dk - 250 TL\nSeramik Kaplama - 1500 TL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GalleryPickerField(initialImages: _gallery, onChanged: (v) => _gallery = v),
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
              decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp (opsiyonel, 90XXXXXXXXXX)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instagramCtrl,
              decoration: const InputDecoration(labelText: 'Instagram kullanıcı adı (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            AccentColorPickerField(
              initialColor: _accentColor,
              onChanged: (v) => _accentColor = v,
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
