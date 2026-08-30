import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// Sektörel site formlarında (kafe, kuaför, klinik, portfolyo, emlak vb.)
/// ortak kullanılan hazır TEMA seçicisi.
///
/// Biyo Link formundaki tema seçiciyle BİREBİR AYNI 5 hazır temayı
/// kullanır (bkz. templates/html/shared_html_blocks.dart -> siteThemes),
/// böylece tüm sektörlerde tutarlı, tek bir seçim deneyimi olur. Önceki
/// "Vurgu Rengi" seçicisinin (AccentColorPickerField) yerini alır: artık
/// kullanıcı tek bir rengi değil, tam bir görsel kimliği (arkaplan + kart
/// yüzeyi + metin tonları + vurgu rengi) seçmiş oluyor.
class ThemePickerField extends StatefulWidget {
  const ThemePickerField({
    super.key,
    required this.onChanged,
    this.label = 'Tema',
    this.initialThemeId = 'clean_light',
  });

  final String label;
  final String initialThemeId;
  final ValueChanged<String> onChanged;

  /// siteThemes'teki id'lerle birebir eşleşmeli.
  static const List<Map<String, String>> options = [
    {'id': 'clean_light', 'label': 'Clean Light'},
    {'id': 'midnight_dark', 'label': 'Midnight Dark'},
    {'id': 'sunset_gradient', 'label': 'Sunset Gradient'},
    {'id': 'neon_cyber', 'label': 'Neon Cyber'},
    {'id': 'soft_pastel', 'label': 'Soft Pastel'},
  ];

  @override
  State<ThemePickerField> createState() => _ThemePickerFieldState();
}

class _ThemePickerFieldState extends State<ThemePickerField> {
  late String _selected = widget.initialThemeId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, widget.label), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ThemePickerField.options.map((t) {
            final selected = _selected == t['id'];
            return ChoiceChip(
              label: Text(t['label']!),
              selected: selected,
              onSelected: (_) {
                setState(() => _selected = t['id']!);
                widget.onChanged(t['id']!);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
