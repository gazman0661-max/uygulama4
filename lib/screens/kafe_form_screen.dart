import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/cafe_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';

/// kuafor_form_screen.dart kalıbından kopyalandı. Generator:
/// cafe_html_generator.dart -> generateCafeHtml.
class KafeFormScreen extends StatefulWidget {
  const KafeFormScreen({super.key});

  @override
  State<KafeFormScreen> createState() => _KafeFormScreenState();
}

class _KafeFormScreenState extends State<KafeFormScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _menuCtrl = TextEditingController(); // kategori blokları
  final _menuUrlCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  bool _generating = false;

  List<Map<String, String?>> _gallery = [];
  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _aboutCtrl.dispose();
    _coverCtrl.dispose();
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

  Future<void> _generate() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme adı ve telefon gerekli.')),
      );
      return;
    }
    setState(() => _generating = true);

    final menuCategories = _parseMenu(_menuCtrl.text);
    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: _nameCtrl.text.trim(),
      kind: ProjectKind.kafe,
      buildHtml: () => generateCafeHtml(
        name: _nameCtrl.text.trim(),
        coverImage: _coverCtrl.text.trim().isEmpty
            ? 'https://placehold.co/1200x800'
            : _coverCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        about: _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim(),
        menuCategories: menuCategories,
        menuUrl: _menuUrlCtrl.text.trim().isEmpty ? null : _menuUrlCtrl.text.trim(),
        gallery: _gallery,
        workingHours: _workingHours,
        address: _addressCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        phone: _phoneCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('Kafe / Restoran Sitesi')),
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
              controller: _aboutCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Hakkında (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coverCtrl,
              decoration: const InputDecoration(labelText: 'Kapak görsel URL (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _menuCtrl,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Menü (kategoriler arasına boş satır bırak)',
                hintText: 'Kahveler\nEspresso - - 60 TL\nLatte - Sütlü - 75 TL\n\nTatlılar\nCheesecake - Ev yapımı - 90 TL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _menuUrlCtrl,
              decoration: const InputDecoration(labelText: 'Dijital/QR menü linki (opsiyonel)', border: OutlineInputBorder()),
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
