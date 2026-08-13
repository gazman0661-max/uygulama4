import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/clinic_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/working_hours_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';

/// kuafor_form_screen.dart kalıbından kopyalandı. Generator:
/// clinic_html_generator.dart -> generateClinicHtml.
///
/// NOT: Bu şablonda galeri bölümü yok (generator'da da yok) — pratisyen
/// fotoğrafı hero + tanıtım bölümünde kullanılıyor.
class ClinicFormScreen extends StatefulWidget {
  const ClinicFormScreen({super.key});

  @override
  State<ClinicFormScreen> createState() => _ClinicFormScreenState();
}

class _ClinicFormScreenState extends State<ClinicFormScreen> {
  final _businessNameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(); // "Uzman Psikolog" gibi unvan
  final _photoCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController(); // uzmanlık alanları
  final _bioCtrl = TextEditingController();
  final _credentialsCtrl = TextEditingController(); // her satır bir unvan/sertifika
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  bool _generating = false;

  List<Map<String, String?>> _workingHours = [];
  double _lat = 41.0082;
  double _lng = 28.9784;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _titleCtrl.dispose();
    _photoCtrl.dispose();
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
        const SnackBar(content: Text('Klinik/uzman adı ve telefon gerekli.')),
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
      kind: ProjectKind.clinic,
      buildHtml: () => generateClinicHtml(
        businessName: _businessNameCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        photoUrl: _photoCtrl.text.trim().isEmpty
            ? 'https://placehold.co/800x800'
            : _photoCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        services: services,
        practitioner: {
          'name': _businessNameCtrl.text.trim(),
          'title': _titleCtrl.text.trim(),
          'photoUrl': _photoCtrl.text.trim().isEmpty
              ? 'https://placehold.co/800x800'
              : _photoCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('Klinik / Sağlık Sitesi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _businessNameCtrl,
              decoration: const InputDecoration(labelText: 'Klinik / uzman adı', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Unvan (örn. Uzman Psikolog)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: const InputDecoration(labelText: 'Slogan (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _photoCtrl,
              decoration: const InputDecoration(labelText: 'Fotoğraf URL (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _servicesCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Uzmanlık alanları (her satıra bir tane)',
                hintText: 'Aile Danışmanlığı\nBireysel Terapi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Kısa özgeçmiş / tanıtım', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _credentialsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Sertifika / unvan rozetleri (her satıra bir tane, opsiyonel)',
                hintText: 'PhD - Klinik Psikoloji\nEMDR Sertifikası',
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
