import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

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

  static const List<Map<String, String>> options = [
    {'id': 'centered', 'label': 'Klasik (Ortalı)'},
    {'id': 'editorial', 'label': 'Editorial (Sola Yaslı)'},
    {'id': 'framed', 'label': 'Framed (Çerçeveli)'},
    {'id': 'split', 'label': 'Split (Yan Yana)'},
    {'id': 'diagonal', 'label': 'Diagonal (Çapraz Geçiş)'},
    {'id': 'social', 'label': 'Sosyal Kanıt (Yorum Kartı)'},
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
