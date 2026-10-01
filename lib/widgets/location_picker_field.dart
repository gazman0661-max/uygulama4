import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../state/app_state.dart';
import 'app_popup.dart';
import 'premium_locked_popup.dart';

class LocationPickerField extends StatefulWidget {
  const LocationPickerField({
    super.key,
    required this.onChanged,
    this.initialAddress = '',
    this.initialLat = 41.0082,
    this.initialLng = 28.9784,
  });

  final String initialAddress;
  final double initialLat;
  final double initialLng;

  final void Function(String address, double lat, double lng) onChanged;

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  late final _addressCtrl = TextEditingController(text: widget.initialAddress);
  late double _lat = widget.initialLat;
  late double _lng = widget.initialLng;
  bool _searching = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _search() async {
    final query = _addressCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _results = [];
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'countrycodes': 'tr',
        'addressdetails': '0',
        'limit': '5',
        'accept-language': 'tr',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'SitoraApp/1.0 (com.sitora.ai)',
      });
      if (res.statusCode == 200) {
        final rawResults = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() => _results = rawResults.map((r) {
              return {
                'display_name': r['display_name'],
                'lat': r['lat'],
                'lon': r['lon'],
              };
            }).toList());
      } else if (mounted) {
        showAppPopup(context, message:
                '${isEnglish(context) ? 'Address search failed' : 'Adres araması başarısız'}: HTTP ${res.statusCode}',
                icon: '⚠️');
      }
    } catch (e) {
      if (mounted) {
        showAppPopup(context, message: 
                '${isEnglish(context) ? 'Address not found' : 'Adres aranamadı'}: $e', icon: '⚠️');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lng = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lng == null) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      _results = [];
      _addressCtrl.text = result['display_name']?.toString() ?? _addressCtrl.text;
    });
    widget.onChanged(_addressCtrl.text.trim(), _lat, _lng);
  }

  void _manualChange() {
    widget.onChanged(_addressCtrl.text.trim(), _lat, _lng);
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AppState>().qtCurrentIsPremium;
    if (!isPremium) {
      return _LockedLocationField(
        onTap: () => showPremiumLockedPopup(
          context,
          message: isEnglish(context)
              ? 'Adding a map to your site is available with a subscription or a custom-domain package (locked on the free plan).'
              : 'Sitene harita eklemek abonelik veya özel domain paketinde açılır (ücretsiz planda kilitli).',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'Konum'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  labelText: t(context, 'Adres'),
                  border: OutlineInputBorder(),
                  hintText: t(context, 'Mahalle, cadde, ilçe, il'),
                ),
                onChanged: (_) => _manualChange(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
              ),
            ),
          ],
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              children: _results.map((r) {
                return ListTile(
                  dense: true,
                  title: Text(
                    r['display_name']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => _select(r),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('lat_$_lat'),
                initialValue: _lat.toString(),
                decoration: InputDecoration(labelText: t(context, 'Enlem (lat)'), border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (v) {
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed != null) {
                    _lat = parsed;
                    _manualChange();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: ValueKey('lng_$_lng'),
                initialValue: _lng.toString(),
                decoration: InputDecoration(labelText: t(context, 'Boylam (lng)'), border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (v) {
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed != null) {
                    _lng = parsed;
                    _manualChange();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isEnglish(context)
              ? 'Type the address, search, and pick from the list — latitude/longitude fill in automatically. '
                  'You can also adjust them manually below if you want.'
              : 'Adresi yaz, ara ve listeden seç — enlem/boylam otomatik dolar. '
                  'İstersen aşağıdan elle de düzeltebilirsin.',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _LockedLocationField extends StatelessWidget {
  const _LockedLocationField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'Konum'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade100,
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEnglish(context)
                        ? 'Map & location — Premium plan feature'
                        : 'Harita & konum — Premium plan özelliği',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
