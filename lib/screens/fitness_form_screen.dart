import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/extended_business_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/accent_color_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';

/// kuafor_form_screen.dart kalıbından kopyalandı. Generator:
/// extended_business_html_generator.dart -> generateExtendedBusinessSiteHtml
/// (schedule dolu, beforeAfterGallery boş — güzellik salonunun tersi).
class FitnessFormScreen extends StatefulWidget {
  const FitnessFormScreen({super.key});

  @override
  State<FitnessFormScreen> createState() => _FitnessFormScreenState();
}

class _FitnessFormScreenState extends State<FitnessFormScreen> {
  final _nameCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController(); // Gün - Saat - Ders - Eğitmen
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  String _accentColor = '#1A1A2E';
  bool _generating = false;

  List<Map<String, String?>> _gallery = [];
  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _coverCtrl.dispose();
    _servicesCtrl.dispose();
    _scheduleCtrl.dispose();
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
      if (parts.length >= 2) return {'name': parts[0], 'duration': null, 'price': parts[1]};
      return {'name': parts[0], 'duration': null, 'price': ''};
    }).toList();
  }

  List<Map<String, String?>> _parseSchedule(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
      final parts = line.split('-').map((p) => p.trim()).toList();
      return {
        'day': parts.isNotEmpty ? parts[0] : '',
        'time': parts.length > 1 ? parts[1] : '',
        'className': parts.length > 2 ? parts[2] : '',
        'trainer': parts.length > 3 ? parts[3] : '',
      };
    }).toList();
  }

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stüdyo adı ve telefon gerekli.')),
      );
      return;
    }
    setState(() => _generating = true);

    final services = _parseServices(_servicesCtrl.text);
    final schedule = _parseSchedule(_scheduleCtrl.text);
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: _nameCtrl.text.trim(),
      kind: ProjectKind.fitness,
      buildHtml: () => generateExtendedBusinessSiteHtml(
        businessName: _nameCtrl.text.trim(),
        coverImageUrl: _coverCtrl.text.trim().isEmpty
            ? 'https://placehold.co/1200x800'
            : _coverCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim(),
        services: services,
        schedule: schedule,
        gallery: _gallery,
        workingHours: _workingHours,
        address: _addressCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        phone: _phoneCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('Fitness Stüdyosu Sitesi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Stüdyo adı', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sloganCtrl,
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
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Üyelik / hizmet paketleri (her satıra bir tane: Ad - Fiyat)',
                hintText: 'Aylık Üyelik - 1200 TL\nGrup Dersi (tekli) - 150 TL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scheduleCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Ders programı (her satıra bir tane: Gün - Saat - Ders - Eğitmen)',
                hintText: 'Pazartesi - 18:00 - CrossFit - Ahmet\nÇarşamba - 19:00 - Yoga - Elif',
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
