import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/real_estate_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';

/// kuafor_form_screen.dart kalıbından FARKLI bir yapıda — real_estate_
/// html_generator.dart Çok Sayfa (B) modu üretiyor (index.html + her ilan
/// için ayrı listing_<id>.html), bu yüzden tekil form yerine "ilan listesi
/// + ilan ekle" akışı kuruldu. Üretim LocalGenerationHelper.generateMultiPage
/// üzerinden (bkz. services/local_generation_helper.dart).
class RealEstateFormScreen extends StatefulWidget {
  const RealEstateFormScreen({super.key});

  @override
  State<RealEstateFormScreen> createState() => _RealEstateFormScreenState();
}

class _RealEstateFormScreenState extends State<RealEstateFormScreen> {
  final _agentNameCtrl = TextEditingController();
  final _agentLogoCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _generating = false;

  final List<Map<String, dynamic>> _listings = [];

  @override
  void dispose() {
    _agentNameCtrl.dispose();
    _agentLogoCtrl.dispose();
    _taglineCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _openListingEditor({Map<String, dynamic>? existing, int? index}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ListingEditorSheet(existing: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _listings[index] = result;
      } else {
        _listings.add(result);
      }
    });
  }

  Future<void> _generate() async {
    if (_agentNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emlakçı/ofis adı ve telefon gerekli.')),
      );
      return;
    }
    if (_listings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az 1 ilan eklemelisin.')),
      );
      return;
    }
    setState(() => _generating = true);

    final ok = await LocalGenerationHelper.generateMultiPage(
      context: context,
      projectNameHint: _agentNameCtrl.text.trim(),
      kind: ProjectKind.realEstate,
      activeFileName: 'index.html',
      buildFiles: () => generateRealEstateSite(
        agentName: _agentNameCtrl.text.trim(),
        agentLogo: _agentLogoCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        agentPhone: _phoneCtrl.text.trim(),
        agentWhatsapp: _whatsappCtrl.text.trim(),
        listings: _listings,
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
      appBar: AppBar(title: const Text('Emlak Sitesi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _agentNameCtrl,
              decoration: const InputDecoration(labelText: 'Emlakçı / ofis adı', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: const InputDecoration(labelText: 'Slogan (opsiyonel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _agentLogoCtrl,
              decoration: const InputDecoration(labelText: 'Logo/foto URL (opsiyonel)', border: OutlineInputBorder()),
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
              decoration: const InputDecoration(labelText: 'WhatsApp (90XXXXXXXXXX)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('İlanlar (${_listings.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openListingEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('İlan Ekle'),
                ),
              ],
            ),
            for (var i = 0; i < _listings.length; i++)
              Card(
                child: ListTile(
                  title: Text(_listings[i]['title']?.toString() ?? ''),
                  subtitle: Text(
                    '${_listings[i]['price']} TL · ${_listings[i]['m2']} m² · ${_listings[i]['roomLabel']}',
                  ),
                  onTap: () => _openListingEditor(existing: _listings[i], index: i),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _listings.removeAt(i)),
                  ),
                ),
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

/// Tek bir ilanın eklenmesi/düzenlenmesi için alt sayfa (bottom sheet).
class _ListingEditorSheet extends StatefulWidget {
  const _ListingEditorSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_ListingEditorSheet> createState() => _ListingEditorSheetState();
}

class _ListingEditorSheetState extends State<_ListingEditorSheet> {
  late final _titleCtrl = TextEditingController(text: widget.existing?['title']?.toString() ?? '');
  late final _priceCtrl = TextEditingController(text: widget.existing?['price']?.toString() ?? '');
  late final _m2Ctrl = TextEditingController(text: widget.existing?['m2']?.toString() ?? '');
  late final _roomCtrl = TextEditingController(text: widget.existing?['roomLabel']?.toString() ?? '');
  late final _floorCtrl = TextEditingController(text: widget.existing?['floor']?.toString() ?? '');
  late final _aidatCtrl = TextEditingController(text: widget.existing?['aidat']?.toString() ?? '');
  late final _locationTagCtrl = TextEditingController(text: widget.existing?['locationTag']?.toString() ?? '');
  late final _descriptionCtrl = TextEditingController(text: widget.existing?['description']?.toString() ?? '');
  late final _addressCtrl = TextEditingController(text: widget.existing?['address']?.toString() ?? '');

  late List<Map<String, String?>> _gallery =
      (widget.existing?['gallery'] as List?)?.cast<Map<String, String?>>() ?? [];
  late double _lat = (widget.existing?['lat'] as num?)?.toDouble() ?? 41.0082;
  late double _lng = (widget.existing?['lng'] as num?)?.toDouble() ?? 28.9784;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _m2Ctrl.dispose();
    _roomCtrl.dispose();
    _floorCtrl.dispose();
    _aidatCtrl.dispose();
    _locationTagCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlan başlığı ve fiyat gerekli.')),
      );
      return;
    }
    final id = widget.existing?['id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final coverImage = _gallery.isNotEmpty ? _gallery.first['url'] ?? '' : 'https://placehold.co/800x600';
    Navigator.pop(context, {
      'id': id,
      'title': _titleCtrl.text.trim(),
      'coverImage': coverImage,
      'price': double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0,
      'm2': double.tryParse(_m2Ctrl.text.replaceAll(',', '.')) ?? 0,
      'roomLabel': _roomCtrl.text.trim(),
      'floor': int.tryParse(_floorCtrl.text.trim()),
      'aidat': double.tryParse(_aidatCtrl.text.replaceAll(',', '.')),
      'locationTag': _locationTagCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'lat': _lat,
      'lng': _lng,
      'gallery': _gallery,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Yeni İlan' : 'İlanı Düzenle',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'İlan başlığı', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fiyat (TL)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _m2Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'm²', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _roomCtrl,
                  decoration: const InputDecoration(labelText: 'Oda (örn. 3+1)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _floorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kat (opsiyonel)', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _aidatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Aidat (opsiyonel)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _locationTagCtrl,
                  decoration: const InputDecoration(labelText: 'Semt/ilçe etiketi', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            GalleryPickerField(
              label: 'İlan Galerisi',
              initialImages: _gallery,
              onChanged: (v) => _gallery = v,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Kaydet',
                    borderColor: AppTheme.accentBlue,
                    textColor: AppTheme.accentBlue,
                    onTap: _save,
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
