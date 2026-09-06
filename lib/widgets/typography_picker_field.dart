import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// Sektörel site formlarında ortak kullanılan TİPOGRAFİ seçicisi.
///
/// ThemePickerField (renk teması) ile BİREBİR AYNI mantık: kullanıcı ham
/// font ailesi/boyut/renk seçmez — küratörlü "font çifti" paketlerinden
/// birini seçer (bkz. templates/html/shared_html_blocks.dart ->
/// fontPackageOf), böylece sonuç her zaman uyumlu çıkar. Hedef kitle
/// tasarımcı değil esnaf; sınırsız seçenek çoğu zaman ya hiç kullanılmaz
/// ya da kötü kombinasyonlarla siteyi çirkinleştirir.
///
/// İkinci, bağımsız bir seçim de "Yoğunluk" (başlık kalınlığı/boyutu) —
/// sadece 3 kademe: İnce / Normal / Kalın. Serbest slider YOK; body metni
/// hep normal ağırlıkta kalır (bkz. typeDensityOf).
class TypographyPickerField extends StatefulWidget {
  const TypographyPickerField({
    super.key,
    required this.onFontPackageChanged,
    required this.onDensityChanged,
    this.label = 'Tipografi',
    this.initialFontPackageId = 'modern_sade',
    this.initialDensity = 'normal',
  });

  final String label;
  final String initialFontPackageId;
  final String initialDensity;
  final ValueChanged<String> onFontPackageChanged;
  final ValueChanged<String> onDensityChanged;

  /// shared_html_blocks.dart -> _fontPackageData id'leriyle birebir eşleşmeli.
  static const List<Map<String, String>> fontPackageOptions = [
    {'id': 'editorial', 'label': 'Editoryal'},
    {'id': 'modern_sade', 'label': 'Modern Sade'},
    {'id': 'sicak_elyazisi', 'label': 'Sıcak'},
    {'id': 'klasik', 'label': 'Klasik'},
    {'id': 'kalin_vurgulu', 'label': 'Kalın / Vurgulu'},
  ];

  /// shared_html_blocks.dart -> _typeDensityData id'leriyle birebir eşleşmeli.
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
          children: TypographyPickerField.fontPackageOptions.map((f) {
            final selected = _selectedPackage == f['id'];
            return ChoiceChip(
              label: Text(t(context, f['label']!)),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedPackage = f['id']!);
                widget.onFontPackageChanged(f['id']!);
              },
            );
          }).toList(),
        ),
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
