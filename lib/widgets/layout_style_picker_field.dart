import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// 06.09.2026 eklendi (kanka isteği) — Hero (üst kapak) DÜZEN seçici.
/// [ThemePickerField] renk/font kimliğini seçtirirken, bu widget hero
/// bölümünün YERLEŞİMİNİ seçtirir (bkz. templates/html/shared_html_blocks.dart
/// > heroBlockHtml [layoutStyle] parametresi).
///
/// 'framed' PREMİUM'dur (bkz. o dosyadaki premiumLayoutStyleIds) ama
/// ThemePickerField'daki AYNI kararla burada da KİLİTLİ/blur gösterilmez —
/// herkes seçip önizleyebilir, kısıtlama sadece "Oluştur"a basılınca
/// (LocalGenerationHelper'daki gate) devreye girer.
class LayoutStylePickerField extends StatefulWidget {
  const LayoutStylePickerField({
    super.key,
    required this.onChanged,
    this.label = 'Hero Düzeni',
    this.initialLayoutStyle = 'centered',
  });

  final String label;
  final String initialLayoutStyle;
  final ValueChanged<String> onChanged;

  /// heroBlockHtml'deki layoutStyle id'leriyle birebir eşleşmeli.
  static const List<Map<String, String>> options = [
    {'id': 'centered', 'label': 'Klasik (Ortalı)'},
    {'id': 'editorial', 'label': 'Editorial (Sola Yaslı)'},
    {'id': 'framed', 'label': '👑 Framed (Çerçeveli)'},
  ];

  @override
  State<LayoutStylePickerField> createState() => _LayoutStylePickerFieldState();
}

class _LayoutStylePickerFieldState extends State<LayoutStylePickerField> {
  late String _selected = widget.initialLayoutStyle;

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
          children: LayoutStylePickerField.options.map((o) {
            final selected = _selected == o['id'];
            return ChoiceChip(
              label: Text(t(context, o['label']!)),
              selected: selected,
              onSelected: (_) {
                setState(() => _selected = o['id']!);
                widget.onChanged(o['id']!);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
