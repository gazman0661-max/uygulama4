import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../templates/html/rich_text_markup.dart';
import 'style_pickers.dart';

Color _muted(BuildContext c) => Theme.of(c).colorScheme.onSurface.withOpacity(0.6);
Color _ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;

class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final raw = text;
    if (!hasRichMarkup(raw)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final base = style ?? DefaultTextStyle.of(context).style;
    final baseSize = base.fontSize ?? 16.0;
    final tokenStyle = base.copyWith(
      fontSize: 1.0,
      color: const Color(0x22000000),
      backgroundColor: null,
      decoration: TextDecoration.none,
    );
    final children = <InlineSpan>[];
    var cur = RichStyle.none;
    var pos = 0;

    TextStyle styled(RichStyle st) {
      final deco = <TextDecoration>[
        if (st.underline) TextDecoration.underline,
        if (st.strike) TextDecoration.lineThrough,
      ];
      return base.copyWith(
        color: _parseHex(st.color) ?? base.color,
        fontSize: st.size != null ? baseSize * st.size! : baseSize,
        fontWeight: st.bold ? FontWeight.w700 : base.fontWeight,
        fontStyle: st.italic ? FontStyle.italic : base.fontStyle,
        decoration: deco.isEmpty ? base.decoration : TextDecoration.combine(deco),
        backgroundColor: _parseHex(st.highlight),
      );
    }

    void addText(String seg) {
      if (seg.isEmpty) return;
      children.add(TextSpan(text: seg, style: cur.isEmpty ? base : styled(cur)));
    }

    for (final m in kRichTokenRegExp.allMatches(raw)) {
      if (m.start > pos) addText(raw.substring(pos, m.start));
      children.add(TextSpan(text: raw.substring(m.start, m.end), style: tokenStyle));
      final payload = m.group(1);
      cur = payload == null ? RichStyle.none : RichStyle.fromPayload(payload);
      pos = m.end;
    }
    if (pos < raw.length) addText(raw.substring(pos));
    return TextSpan(style: base, children: children);
  }
}

Color? _parseHex(String? hex) {
  final n = normalizeHexColor(hex);
  if (n == null) return null;
  return Color(int.parse('FF${n.substring(1)}', radix: 16));
}

Widget Function(BuildContext, EditableTextState) richTextContextMenuBuilder(
  BuildContext fieldContext,
  TextEditingController controller,
) {
  return (BuildContext context, EditableTextState state) {
    final items = List<ContextMenuButtonItem>.from(state.contextMenuButtonItems);
    final sel = state.textEditingValue.selection;
    if (sel.isValid && !sel.isCollapsed) {
      items.add(
        ContextMenuButtonItem(
          label: t(fieldContext, 'Stil'),
          onPressed: () {
            state.hideToolbar();
            showRichStyleSheet(fieldContext, controller, selection: sel);
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  };
}

class RichTextField extends StatelessWidget {
  const RichTextField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          decoration: decoration,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          contextMenuBuilder: richTextContextMenuBuilder(context, controller),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ExcludeFocus(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.format_color_text, size: 16),
              label: Text(t(context, 'Kelime stili')),
              onPressed: () => _openFromButton(context),
            ),
          ),
        ),
      ],
    );
  }

  void _openFromButton(BuildContext context) {
    final sel = controller.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(t(context, 'Önce yazıda stil vermek istediğin kelimeyi veya cümleyi seç, sonra bu düğmeye bas.')),
        ),
      );
      return;
    }
    showRichStyleSheet(context, controller, selection: sel);
  }
}

Future<void> showRichStyleSheet(
  BuildContext context,
  TextEditingController controller, {
  required TextSelection selection,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RichStyleSheet(controller: controller, initialSelection: selection),
  );
}

class _RichStyleSheet extends StatefulWidget {
  const _RichStyleSheet({required this.controller, required this.initialSelection});
  final TextEditingController controller;
  final TextSelection initialSelection;

  @override
  State<_RichStyleSheet> createState() => _RichStyleSheetState();
}

class _RichStyleSheetState extends State<_RichStyleSheet> {
  late TextSelection _sel = widget.initialSelection;
  final TextEditingController _hexCtrl = TextEditingController();

  static const List<String> _highlights = [
    '#fde047', '#bbf7d0', '#bfdbfe', '#fbcfe8', '#fecaca', '#e9d5ff',
  ];
  static const List<MapEntry<String, double?>> _sizes = [
    MapEntry('Normal', null),
    MapEntry('Küçük', 0.8),
    MapEntry('Büyük', 1.3),
    MapEntry('Çok büyük', 1.7),
    MapEntry('Dev', 2.4),
  ];

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  RichStyle get _current {
    final text = widget.controller.text;
    final start = _sel.start.clamp(0, text.length);
    return richStyleAt(text, start);
  }

  void _apply(Map<String, Object?> patch) {
    final text = widget.controller.text;
    final start = _sel.start.clamp(0, text.length);
    final end = _sel.end.clamp(0, text.length);
    if (end <= start) return;
    final ps = richRawToPlain(text, start);
    final pe = richRawToPlain(text, end);
    final next = applyRichPatch(text, start, end, patch);
    final range = richRawRangeForPlain(next, ps, pe);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection(baseOffset: range.start, extentOffset: range.end),
    );
    setState(() => _sel = TextSelection(baseOffset: range.start, extentOffset: range.end));
  }

  Widget _toggle(String label, bool active, VoidCallback onTap, {TextStyle? style}) {
    return FilterChip(
      label: Text(label, style: style),
      selected: active,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }

  Widget _swatch(String? hex, {required bool selected, required VoidCallback onTap}) {
    final color = _parseHex(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? _ink(context) : _muted(context),
            width: selected ? 3 : 1,
          ),
        ),
        child: color == null ? Icon(Icons.block, size: 18, color: _muted(context)) : null,
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(context, 'Seçili kısmın stili'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                t(context, 'Sadece seçtiğin kısım değişir; sitedeki aynı kelimenin başka yerleri etkilenmez.'),
                style: TextStyle(fontSize: 12, color: _muted(context)),
              ),
              _label(t(context, 'Biçim')),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _toggle('B', cur.bold, () => _apply({'bold': !cur.bold}),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  _toggle('I', cur.italic, () => _apply({'italic': !cur.italic}),
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                  _toggle('U', cur.underline, () => _apply({'underline': !cur.underline}),
                      style: const TextStyle(decoration: TextDecoration.underline)),
                  _toggle('🔒 S', cur.strike, () => _apply({'strike': !cur.strike}),
                      style: const TextStyle(decoration: TextDecoration.lineThrough)),
                ],
              ),
              _label(t(context, '🔒 Yazı rengi (Premium)')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _swatch(null, selected: cur.color == null, onTap: () => _apply({'color': null})),
                  for (final c in [...kFreePaletteColors, ...kPremiumPaletteColors])
                    _swatch(c, selected: cur.color == c, onTap: () => _apply({'color': c})),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        labelText: t(context, 'Serbest renk (#rrggbb)'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final hex = normalizeHexColor(_hexCtrl.text);
                      if (hex == null) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(content: Text(t(context, 'Geçerli bir renk kodu yaz (örn. #e11d48).'))),
                        );
                        return;
                      }
                      _apply({'color': hex});
                    },
                    child: Text(t(context, 'Uygula')),
                  ),
                ],
              ),
              _label(t(context, '🔒 Boyut (Premium)')),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final s in _sizes)
                    _toggle(
                      t(context, s.key),
                      cur.size == s.value,
                      () => _apply({'size': s.value}),
                    ),
                ],
              ),
              _label(t(context, '🔒 Yazı tipi (Premium)')),
              StyleFontDropdown(
                label: t(context, 'Google Font'),
                value: cur.font,
                onChanged: (v) => _apply({'font': v}),
              ),
              _label(t(context, '🔒 Vurgu (fosforlu kalem — Premium)')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _swatch(null, selected: cur.highlight == null, onTap: () => _apply({'highlight': null})),
                  for (final c in _highlights)
                    _swatch(c, selected: cur.highlight == c, onTap: () => _apply({'highlight': c})),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _apply({
                      'color': null,
                      'size': null,
                      'bold': false,
                      'italic': false,
                      'underline': false,
                      'strike': false,
                      'highlight': null,
                      'font': null,
                    }),
                    child: Text(t(context, 'Stili temizle')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t(context, 'Tamam')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
