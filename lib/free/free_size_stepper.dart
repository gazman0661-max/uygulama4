import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// px cinsinden yazı boyutu ayarlayıcı: − / + (1'er px), kaydırıcı ve
/// sayıya dokununca elle yazma. [value] 0 ise "Otomatik" gösterilir
/// ([allowAuto] true iken); − / + / kaydırıcı otomatiği kapatıp [autoPreview]
/// (varsayılan olarak görünen boyut) değerinden başlar.
class FreeSizeStepper extends StatelessWidget {
  final int value; // 0 = otomatik
  final int min;
  final int max;
  final int autoPreview; // otomatikken ekrandaki yaklaşık px (başlangıç noktası)
  final bool allowAuto;
  final ValueChanged<int> onChanged;

  const FreeSizeStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.autoPreview = 16,
    this.allowAuto = false,
  });

  int get _shown => value > 0 ? value : autoPreview;
  int _clamp(int v) => v < min ? min : (v > max ? max : v);

  Future<void> _type(BuildContext context) async {
    final ctrl = TextEditingController(text: '$_shown');
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(context, 'Yazı boyutu (px)')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: '$min – $max'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t(context, 'İptal'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(t(context, 'Tamam')),
          ),
        ],
      ),
    );
    if (res != null) onChanged(_clamp(res));
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () => onChanged(_clamp(_shown - 1)),
      ),
      GestureDetector(
        onTap: () => _type(context),
        child: Container(
          constraints: const BoxConstraints(minWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(value > 0 ? '$value px' : t(context, 'Oto'), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => onChanged(_clamp(_shown + 1)),
      ),
      SizedBox(
        width: 120,
        child: Slider(
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          value: _clamp(_shown).toDouble(),
          onChanged: (v) => onChanged(_clamp(v.round())),
        ),
      ),
      if (allowAuto && value > 0)
        TextButton(onPressed: () => onChanged(0), child: Text(t(context, 'Otomatik'))),
    ]);
  }
}
