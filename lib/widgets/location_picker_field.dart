import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../localization/app_strings.dart';

/// Ortak konum seçici.
///
/// NOT: Projede şu an google_maps_flutter (veya benzeri bir harita SDK'sı)
/// pubspec'te YOK — eklemek Android/iOS tarafında API key + native
/// konfigürasyon gerektiriyor ve bu repo'da o dosyalar (AndroidManifest,
/// Info.plist, pubspec.yaml) elimde değildi, o yüzden görsel "haritada
/// pin sürükleme" burada YAPILMADI. Bunun yerine API key gerektirmeyen
/// OpenStreetMap Nominatim adres arama servisiyle "adrese göre konum bul"
/// akışı kuruldu: kullanıcı adres yazar, eşleşen sonuçlardan birini seçer,
/// enlem/boylam otomatik doldurulur. Gerekirse manuel enlem/boylam girişi
/// de var. `pubspec.yaml`'a `http` paketinin eklenmesi gerekiyor.
///
/// Gerçek bir sürükle-bırak harita istenirse: google_maps_flutter (Google
/// Maps API key + AndroidManifest/Info.plist ayarları) ya da flutter_map
/// (API key gerektirmez, OSM tile) eklenip bu widget'ın içi
/// GoogleMap/FlutterMap ile değiştirilebilir; dışarıya verdiği
/// (address, lat, lng) sözleşmesi aynı kalır.
class LocationPickerField extends StatefulWidget {
  const LocationPickerField({
    super.key,
    required this.onChanged,
    this.initialAddress = '',
    this.initialLat = 41.0082, // İstanbul varsayılan
    this.initialLng = 28.9784,
  });

  final String initialAddress;
  final double initialLat;
  final double initialLng;

  /// address alanı serbest metin olarak kalır (kullanıcı elle düzenleyebilir);
  /// lat/lng seçilen sonuçtan ya da manuel girişten gelir.
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
        'limit': '5',
        'countrycodes': 'tr',
      });
      final res = await http.get(uri, headers: {
        // Nominatim kullanım politikası tanımlanabilir bir User-Agent ister.
        'User-Agent': 'SitoraApp/1.0',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() => _results = data.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(
                '${isEnglish(context) ? 'Address not found' : 'Adres aranamadı'}: $e')));
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
