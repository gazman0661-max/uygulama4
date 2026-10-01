import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../templates/html/google_font_catalog.dart';

const List<String> kCuratedGoogleFontNames = kGoogleFontCatalog;

class TypographyPickerField extends StatefulWidget {
  const TypographyPickerField({
    super.key,
    required this.onFontPackageChanged,
    required this.onDensityChanged,
    this.onCustomFontPackageChanged,
    this.label = 'Tipografi',
    this.initialFontPackageId = 'modern_sade',
    this.initialDensity = 'normal',
    this.initialCustomFontPackage,
  });

  final String label;
  final String initialFontPackageId;
  final String initialDensity;
  final ValueChanged<String> onFontPackageChanged;
  final ValueChanged<String> onDensityChanged;

  final ValueChanged<Map<String, String>>? onCustomFontPackageChanged;

  final Map<String, String>? initialCustomFontPackage;

  static const String customFontPackageId = 'custom_font';

  static const List<Map<String, String>> fontPackageOptions = [
    {'id': 'editorial', 'label': 'Editoryal'},
    {'id': 'modern_sade', 'label': 'Modern Sade'},
    {'id': 'sicak_elyazisi', 'label': 'Sıcak'},
    {'id': 'klasik', 'label': 'Klasik'},
    {'id': 'kalin_vurgulu', 'label': 'Kalın / Vurgulu'},
  ];

  static const List<Map<String, String>> densityOptions = [
    {'id': 'ince', 'label': 'İnce'},
    {'id': 'normal', 'label': 'Normal'},
    {'id': 'kalin', 'label': 'Kalın'},
  ];

  @override
  State<TypographyPickerField> createState() => _TypographyPickerFieldState();
}

class _TypographyPickerFieldState extends State<TypographyPickerField> {
  late String _selectedPackage = widget.initialFontPackageId;
  late String _selectedDensity = widget.initialDensity;
  late final _headingCtrl =
      TextEditingController(text: widget.initialCustomFontPackage?['heading'] ?? '');
  late final _bodyCtrl = TextEditingController(text: widget.initialCustomFontPackage?['body'] ?? '');

  bool get _showCustomPanel =>
      widget.onCustomFontPackageChanged != null &&
      _selectedPackage == TypographyPickerField.customFontPackageId;

  @override
  void dispose() {
    _headingCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _emitCustomFontPackage() {
    widget.onCustomFontPackageChanged?.call({
      'heading': _headingCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
    });
  }

  Widget _fontSearchField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 220,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue value) {
          if (value.text.trim().isEmpty) return kCuratedGoogleFontNames;
          final q = value.text.toLowerCase();
          return kCuratedGoogleFontNames.where((name) => name.toLowerCase().contains(q));
        },
        initialValue: TextEditingValue(text: ctrl.text),
        onSelected: (selection) {
          ctrl.text = selection;
          _emitCustomFontPackage();
        },
        fieldViewBuilder: (context, fieldCtrl, focusNode, onSubmitted) {
          fieldCtrl.text = ctrl.text;
          return TextField(
            controller: fieldCtrl,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: t(context, label),
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
            onChanged: (v) {
              ctrl.text = v;
              _emitCustomFontPackage();
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 220,
                height: options.length > 6 ? 260 : options.length * 42.0 + 8,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final opt = options.elementAt(i);
                    return ListTile(
                      dense: true,
                      title: Text(opt),
                      onTap: () => onSelected(opt),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
          children: [
            ...TypographyPickerField.fontPackageOptions.map((f) {
              final selected = _selectedPackage == f['id'];
              return ChoiceChip(
                label: Text(t(context, f['label']!)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedPackage = f['id']!);
                  widget.onFontPackageChanged(f['id']!);
                },
              );
            }),
            if (widget.onCustomFontPackageChanged != null)
              ChoiceChip(
                label: Text(t(context, '🔒 Serbest Font Seçimi')),
                selected: _selectedPackage == TypographyPickerField.customFontPackageId,
                onSelected: (_) {
                  setState(() => _selectedPackage = TypographyPickerField.customFontPackageId);
                  widget.onFontPackageChanged(TypographyPickerField.customFontPackageId);
                  _emitCustomFontPackage();
                },
              ),
          ],
        ),
        if (_showCustomPanel) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'Google Fonts\'tan ara ve seç (Premium)'),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _fontSearchField('Başlık Fontu', _headingCtrl),
                    _fontSearchField('Gövde Fontu', _bodyCtrl),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(t(context, 'Yoğunluk'), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TypographyPickerField.densityOptions.map((d) {
            final selected = _selectedDensity == d['id'];
            return ChoiceChip(
              label: Text(t(context, d['label']!)),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedDensity = d['id']!);
                widget.onDensityChanged(d['id']!);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
