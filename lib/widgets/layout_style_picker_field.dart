import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// 06.09.2026 eklendi (kanka isteği) — Hero (üst kapak) DÜZEN seçici.
/// [ThemePickerField] renk/font kimliğini seçtirirken, bu widget hero
/// bölümünün YERLEŞİMİNİ seçtirir (bkz. templates/html/shared_html_blocks.dart
/// > heroBlockHtml [layoutStyle] parametresi).
///
/// 28.09.2026: tüm hero düzenleri ÜCRETSİZ ('framed' dahil, bkz.
/// shared_html_blocks.dart > premiumLayoutStyleIds — şu an boş). Gate
/// altyapısı (LocalGenerationHelper) ileride yeni premium düzen için yerinde.
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
    {'id': 'framed', 'label': 'Framed (Çerçeveli)'},
    // 27.09.2026 eklendi (kanka isteği) — foto üstüne yazı bindirme
    // yerine ayrı foto kutusu (split) ve yönlü/çapraz gradient (diagonal).
    // Not: önce premium eklenmişti, kanka kararıyla ÜCRETSİZ yapıldı
    // (bkz. shared_html_blocks.dart > premiumLayoutStyleIds) — o yüzden
    // burada 👑 yok.
    {'id': 'split', 'label': 'Split (Yan Yana)'},
    {'id': 'diagonal', 'label': 'Diagonal (Çapraz Geçiş)'},
    // 28.09.2026 eklendi (kanka isteği) — foto kutusunun üstünde işletmenin
    // GERÇEK bir yorumundan üretilen yüzen kart (bkz. shared_html_blocks.dart
    // > heroBlockHtml [featuredTestimonial]). Yorum eklenmemişse kart
    // basılmaz, düzen sessizce 'split' gibi görünür — bu yüzden ÜCRETSİZ.
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
