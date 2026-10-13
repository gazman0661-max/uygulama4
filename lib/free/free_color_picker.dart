import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// "Otomatik" = 0 (tema / zemine göre otomatik renk).
const int kAutoColor = 0;

const List<int> _quick = [
  0xFF111111, 0xFF444444, 0xFF888888, 0xFFFFFFFF,
  0xFFE53935, 0xFFFB8C00, 0xFFFDD835, 0xFF43A047,
  0xFF00ACC1, 0xFF1E88E5, 0xFF3949AB, 0xFF8E24AA,
  0xFFEC407A, 0xFF6D4C41, 0xFF26C6DA, 0xFFFFD54F,
];

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

String _hexOf(Color c) => (c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// Her bölüm / öğe için serbest renk seçici.
/// Döner: seçilen ARGB (alfa her zaman FF), [kAutoColor] (= otomatik) ya da
/// iptal edilirse null.
///
/// [initial]: şu anki değer (0 = otomatik). [allowAuto]: "Otomatik" düğmesi.
Future<int?> showFreeColorPicker(
  BuildContext context, {
  required int initial,
  String? title,
  bool allowAuto = true,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PickerSheet(initial: initial, title: title, allowAuto: allowAuto),
  );
}

class _PickerSheet extends StatefulWidget {
  final int initial;
  final String? title;
  final bool allowAuto;
  const _PickerSheet({required this.initial, required this.title, required this.allowAuto});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial == 0 ? const Color(0xFF111111) : Color(widget.initial));
  late final TextEditingController _hex = TextEditingController(text: _hexOf(_hsv.toColor()));

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _set(HSVColor v) {
    setState(() => _hsv = v);
    _hex.text = _hexOf(_color);
  }

  void _fromSv(Offset p, Size size) {
    final s = _c01(p.dx / size.width);
    final v = 1 - _c01(p.dy / size.height);
    _set(_hsv.withSaturation(s).withValue(v));
  }

  void _fromHue(double dx, double width) {
    var next = _hsv.withHue(_c01(dx / width) * 360);
    if (next.saturation == 0) next = next.withSaturation(1.0);
    if (next.value == 0) next = next.withValue(1.0);
    _set(next);
  }

  void _fromHex(String v) {
    final t = v.replaceAll('#', '').trim();
    if (t.length != 6) return;
    final n = int.tryParse(t, radix: 16);
    if (n == null) return;
    setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | n)));
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title ?? t(context, 'Renk Seç'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in _quick)
              GestureDetector(
                onTap: () => _set(HSVColor.fromColor(Color(c))),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (ctx, bc) {
            final size = Size(bc.maxWidth, 170);
            return GestureDetector(
              onPanDown: (d) => _fromSv(d.localPosition, size),
              onPanUpdate: (d) => _fromSv(d.localPosition, size),
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(colors: [Colors.white, hueColor])),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black]),
                  ),
                  child: Stack(children: [
                    Positioned(
                      left: _hsv.saturation * size.width - 8,
                      top: (1 - _hsv.value) * size.height - 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (ctx, bc) {
            final w = bc.maxWidth;
            return GestureDetector(
              onPanDown: (d) => _fromHue(d.localPosition.dx, w),
              onPanUpdate: (d) => _fromHue(d.localPosition.dx, w),
              child: Container(
                width: w,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(colors: [
                    Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                    Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
                  ]),
                ),
                child: Stack(children: [
                  Positioned(
                    left: _hsv.hue / 360 * w - 3,
                    child: Container(
                      width: 6,
                      height: 26,
                      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hex,
                maxLength: 7,
                textCapitalization: TextCapitalization.characters,
                onChanged: _fromHex,
                decoration: const InputDecoration(prefixText: '#', counterText: '', isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.allowAuto)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(kAutoColor),
                  child: Text(t(context, 'Otomatik')),
                ),
              ),
            if (widget.allowAuto) const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(0xFF000000 | (_color.value & 0xFFFFFF)),
                child: Text(t(context, 'Tamam')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Seçili rengi gösteren küçük yuvarlak + etiket; dokununca seçici açılır.
class FreeColorChip extends StatelessWidget {
  final String label;
  final int value; // 0 = otomatik
  final ValueChanged<int> onChanged;
  final bool allowAuto;
  const FreeColorChip({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowAuto = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final v = await showFreeColorPicker(context, initial: value, title: label, allowAuto: allowAuto);
        if (v != null) onChanged(v);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: value == 0 ? Colors.transparent : Color(value),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey),
            ),
            child: value == 0 ? const Icon(Icons.auto_awesome, size: 14) : null,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
