import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/clinic_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// clinic_form_screen.dart kalıbından kopyalandı. Generator: AYNI
/// generateClinicHtml (clinic_html_generator.dart), sadece başlık ve
/// metinler Veteriner Kliniği Sitesi için özelleştirildi.
class VeterinarianFormScreen extends StatefulWidget {
  const VeterinarianFormScreen({super.key});

  @override
  State<VeterinarianFormScreen> createState() => _VeterinarianFormScreenState();
}

class _VeterinarianFormScreenState extends State<VeterinarianFormScreen> {
  final _businessNameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(); // "Uzman Psikolog" gibi unvan
  final _taglineCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController(); // uzmanlık alanları
  final _bioCtrl = TextEditingController();
  final _credentialsCtrl = TextEditingController(); // her satır bir unvan/sertifika
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  String _selectedTheme = 'clean_light';
  bool _generating = false;

  List<Map<String, String?>> _photo = [];
  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _servicesCtrl.dispose();
    _bioCtrl.dispose();
    _credentialsCtrl.dispose();
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
        .map((line) => {'name': line, 'duration': null, 'price': ''})
        .toList();
  }

  Future<void> _generate() async {
    if (_businessNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'Klinik/uzman adı ve telefon gerekli.'))),
      );
      return;
    }
    setState(() => _generating = true);

    final services = _parseServices(_servicesCtrl.text);
    final credentials = _credentialsCtrl.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => {'label': l})
        .toList();

    final ok = await LocalGenerationHelper.generateSinglePage(
      context: context,
      projectNameHint: _businessNameCtrl.text.trim(),
      kind: ProjectKind.veterinarian,
      buildHtml: () => generateClinicHtml(
        businessName: _businessNameCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        photoUrl: _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
            ? _photo.first['url']!
            : 'https://placehold.co/800x800',
        tagline: _taglineCtrl.text.trim(),
        services: services,
        practitioner: {
          'name': _businessNameCtrl.text.trim(),
          'title': _titleCtrl.text.trim(),
          'photoUrl': _photo.isNotEmpty && (_photo.first['url'] ?? '').isNotEmpty
              ? _photo.first['url']!
              : 'https://placehold.co/800x800',
          'bio': _bioCtrl.text.trim(),
          'credentials': credentials,
        },
        workingHours: _workingHours,
        address: _addressCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        phone: _phoneCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
        themeId: _selectedTheme,
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
      appBar: AppBar(title: Text(t(context, 'Veteriner Kliniği Sitesi'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _businessNameCtrl,
              decoration: InputDecoration(labelText: t(context, 'Klinik / veteriner adı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'Unvan (örn. Veteriner Hekim)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: InputDecoration(labelText: t(context, 'Slogan (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            GalleryPickerField(
              label: t(context, 'Fotoğraf'),
              maxImages: 1,
              initialImages: _photo,
              onChanged: (v) => _photo = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _servicesCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t(context, 'Hizmetler (her satıra bir tane)'),
                hintText: t(context, 'Aşı & Kontrol\nCerrahi Operasyon\nMikroçip'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: t(context, 'Kısa özgeçmiş / tanıtım'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _credentialsCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t(context, 'Sertifika / unvan rozetleri (her satıra bir tane, opsiyonel)'),
                hintText: t(context, 'PhD - Klinik Psikoloji\nEMDR Sertifikası'),
                border: OutlineInputBorder(),
              ),
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
