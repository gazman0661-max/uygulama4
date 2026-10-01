import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../templates/html/google_font_catalog.dart';
import '../templates/html/rich_text_markup.dart';

Color _muted(BuildContext c) => Theme.of(c).colorScheme.onSurface.withOpacity(0.6);
Color _ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;

Color? _hexToColor(String? hex) {
  final n = normalizeHexColor(hex);
  if (n == null) return null;
  return Color(int.parse('FF${n.substring(1)}', radix: 16));
}

class StyleColorPicker extends StatefulWidget {
  const StyleColorPicker({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<StyleColorPicker> createState() => _StyleColorPickerState();
}

class _StyleColorPickerState extends State<StyleColorPicker> {
  final TextEditingController _hex = TextEditingController();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Widget _dot(String? hex) {
    final n = normalizeHexColor(hex);
    final cur = normalizeHexColor(widget.value);
    final selected = cur == n;
    final color = _hexToColor(n);
    return GestureDetector(
      onTap: () => widget.onChanged(n),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? _ink(context) : _muted(context), width: selected ? 3 : 1),
        ),
        child: color == null ? Icon(Icons.block, size: 18, color: _muted(context)) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = normalizeHexColor(widget.value);
    final isCustom = cur != null && !isFreePaletteColor(cur);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [_dot(null), for (final c in kFreePaletteColors) _dot(c)],
        ),
        const SizedBox(height: 8),
        Text(
          t(context, '🔒 Daha fazla renk (Premium)'),
          style: TextStyle(fontSize: 12, color: _muted(context)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final c in kPremiumPaletteColors) _dot(c)],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hex,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: t(context, 'Serbest renk (#rrggbb)'),
                  helperText: isCustom ? cur : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final hex = normalizeHexColor(_hex.text);
                if (hex == null) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text(t(context, 'Geçerli bir renk kodu yaz (örn. #e11d48).'))),
                  );
                  return;
                }
                widget.onChanged(hex);
              },
              child: Text(t(context, 'Uygula')),
            ),
          ],
        ),
      ],
    );
  }
}

class StyleFontDropdown extends StatelessWidget {
  const StyleFontDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = fontNameFromSlug(value) == null ? null : value;
    return DropdownButtonFormField<String?>(
      value: current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        helperText: t(context, 'Sayfada en fazla 3 ek font yüklenir.'),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(t(context, 'Otomatik (sitenin fontu)')),
        ),
        for (final name in kGoogleFontCatalog)
          DropdownMenuItem<String?>(value: fontSlug(name), child: Text(name)),
      ],
      onChanged: onChanged,
    );
  }
}
