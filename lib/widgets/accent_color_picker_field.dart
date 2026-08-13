import 'package:flutter/material.dart';

/// Sektörel site formlarında (kafe, kuaför, klinik, portfolyo, emlak vb.)
/// ortak kullanılan "Vurgu Rengi" seçicisi.
///
/// Biyo Link formundaki hazır tema seçiciyle aynı mantık: kullanıcı hazır
/// bir renk paletinden seçim yapar, seçilen HEX değeri generator'daki
/// `accentColor` parametresine geçilir (bkz. templates/html/*.dart —
/// hepsi zaten bu parametreyi destekliyor, sadece formlarda seçici yoktu).
class AccentColorPickerField extends StatefulWidget {
  const AccentColorPickerField({
    super.key,
    required this.onChanged,
    this.label = 'Vurgu / Arka Plan Rengi',
    this.initialColor = '#212529',
  });

  final String label;
  final String initialColor;
  final ValueChanged<String> onChanged;

  /// Tüm sektörlerde işe yarayan, birbirinden ayırt edilebilir hazır palet.
  static const List<Map<String, String>> palette = [
    {'label': 'Antrasit', 'hex': '#212529'},
    {'label': 'Lacivert', 'hex': '#1F4E79'},
    {'label': 'Okyanus', 'hex': '#0B5394'},
    {'label': 'Petrol', 'hex': '#2E7D6B'},
    {'label': 'Zümrüt', 'hex': '#1E8E5A'},
    {'label': 'Bordo', 'hex': '#8A2432'},
    {'label': 'Turuncu', 'hex': '#D9622B'},
    {'label': 'Kahve', 'hex': '#7B4B2A'},
    {'label': 'Mor', 'hex': '#5B3A9E'},
    {'label': 'Pembe', 'hex': '#C97B9E'},
    {'label': 'Gece Mavisi', 'hex': '#1A1A2E'},
    {'label': 'Altın', 'hex': '#B8860B'},
  ];

  @override
  State<AccentColorPickerField> createState() => _AccentColorPickerFieldState();
}

class _AccentColorPickerFieldState extends State<AccentColorPickerField> {
  late String _selected = widget.initialColor;

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AccentColorPickerField.palette.map((c) {
            final hex = c['hex']!;
            final selected = _selected.toUpperCase() == hex.toUpperCase();
            return GestureDetector(
              onTap: () {
                setState(() => _selected = hex);
                widget.onChanged(hex);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black87 : Colors.black12,
                        width: selected ? 2.4 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _hexToColor(hex).withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
