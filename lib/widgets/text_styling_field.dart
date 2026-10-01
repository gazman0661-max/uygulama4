import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../templates/html/section_registry.dart';
import '../templates/html/text_styling.dart';
import 'rich_text_field.dart';
import 'style_pickers.dart';

Color _muted(BuildContext c) => Theme.of(c).colorScheme.onSurface.withOpacity(0.6);
Color _ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;

class TextStylingField extends StatefulWidget {
  const TextStylingField({
    super.key,
    required this.sectionIds,
    required this.onChanged,
    this.initialValue,
  });

  final List<String> sectionIds;
  final Map<String, dynamic>? initialValue;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<TextStylingField> createState() => _TextStylingFieldState();
}

class _CustomEntry {
  _CustomEntry({
    required this.id,
    String heading = '',
    String body = '',
    this.after = 'end',
    this.align = '',
    Map<String, dynamic>? style,
  })  : heading = RichTextEditingController(text: heading),
        body = RichTextEditingController(text: body),
        style = style ?? <String, dynamic>{};

  final String id;
  final RichTextEditingController heading;
  final RichTextEditingController body;
  String after;
  String align;
  final Map<String, dynamic> style;

  void dispose() {
    heading.dispose();
    body.dispose();
  }
}

const Map<String, Map<String, String>> _extraLabels = {
  'hero': {'tr': 'Kapak (en üst)', 'en': 'Cover (top)'},
  'contact': {'tr': 'İletişim', 'en': 'Contact'},
};

class _TextStylingFieldState extends State<TextStylingField> {
  final Map<String, Map<String, dynamic>> _sections = {};
  final List<_CustomEntry> _customs = [];
  bool _expanded = false;
  int _idSeq = 0;

  List<String> get _keys {
    final out = <String>['hero'];
    for (final id in widget.sectionIds) {
      if (kStyleSectionClasses.containsKey(id) && !out.contains(id)) out.add(id);
    }
    out.add('contact');
    return out;
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialValue;
    if (init != null) {
      final sec = init['sections'];
      if (sec is Map) {
        sec.forEach((k, v) {
          if (v is Map) _sections[k.toString()] = v.map((a, b) => MapEntry(a.toString(), b));
        });
      }
      final cus = init['custom'];
      if (cus is List) {
        for (final e in cus) {
          if (e is! Map) continue;
          final id = (e['id'] ?? 'c${++_idSeq}').toString();
          final entry = _CustomEntry(
            id: id,
            heading: (e['heading'] ?? '').toString(),
            body: (e['body'] ?? '').toString(),
            after: (e['after'] ?? 'end').toString(),
            align: (e['align'] ?? '').toString(),
            style: e['style'] is Map
                ? (e['style'] as Map).map((a, b) => MapEntry(a.toString(), b))
                : null,
          );
          _attach(entry);
          _customs.add(entry);
        }
      }
      _expanded = _sections.isNotEmpty || _customs.isNotEmpty;
    }
  }

  void _attach(_CustomEntry e) {
    e.heading.addListener(_emit);
    e.body.addListener(_emit);
  }

  @override
  void dispose() {
    for (final c in _customs) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _clean(Map<String, dynamic> st) {
    final out = <String, dynamic>{};
    st.forEach((k, v) {
      if (v == null || v == '' || v == false) return;
      out[k] = v;
    });
    return out;
  }

  void _emit() {
    final sections = <String, dynamic>{};
    _sections.forEach((k, v) {
      final c = _clean(v);
      if (c.isNotEmpty) sections[k] = c;
    });
    final custom = _customs
        .map((c) => <String, dynamic>{
              'id': c.id,
              'heading': c.heading.text,
              'body': c.body.text,
              'after': c.after,
              if (c.align.isNotEmpty) 'align': c.align,
              if (_clean(c.style).isNotEmpty) 'style': _clean(c.style),
            })
        .toList();
    widget.onChanged({'sections': sections, 'custom': custom});
  }

  String _labelOf(BuildContext context, String key) {
    final en = isEnglish(context);
    final extra = _extraLabels[key];
    if (extra != null) return extra[en ? 'en' : 'tr']!;
    return sectionLabel(key, en ? 'en' : 'tr');
  }

  bool _isStyled(String key) => _clean(_sections[key] ?? {}).isNotEmpty;

  void _openSectionEditor(String key) {
    final style = _sections.putIfAbsent(key, () => <String, dynamic>{});
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StyleEditorSheet(
        title: _labelOf(context, key),
        style: style,
        isHero: key == 'hero',
        allowRename: key != 'hero',
        onChanged: () {
          _emit();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _openCustomStyle(_CustomEntry c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StyleEditorSheet(
        title: t(context, 'Bu bölümün yazı stili'),
        style: c.style,
        isHero: false,
        allowRename: false,
        onChanged: () {
          _emit();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _addCustom() {
    if (_customs.length >= TextStylingPolicy.maxCustomSections) return;
    var id = 'c${++_idSeq}';
    while (_customs.any((e) => e.id == id)) {
      id = 'c${++_idSeq}';
    }
    final e = _CustomEntry(id: id);
    _attach(e);
    setState(() => _customs.add(e));
    _emit();
  }

  void _removeCustom(_CustomEntry c) {
    setState(() => _customs.remove(c));
    c.dispose();
    _emit();
  }

  List<DropdownMenuItem<String>> _placementItems(BuildContext context) {
    final en = isEnglish(context);
    return [
      DropdownMenuItem(value: 'hero', child: Text(t(context, 'Kapağın hemen altı'))),
      for (final id in widget.sectionIds)
        if (kStyleSectionClasses.containsKey(id))
          DropdownMenuItem(
            value: id,
            child: Text(en
                ? 'Below "${sectionLabel(id, 'en')}"'
                : '"${sectionLabel(id, 'tr')}" bölümünün altı'),
          ),
      DropdownMenuItem(value: 'end', child: Text(t(context, 'Sayfa sonu (iletişimden önce)'))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('🎨', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'Yazı ve Başlık Stilleri'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          t(context, 'Bölüm renkleri, boyutlar, kendi başlıkların ve kelime bazlı stil'),
                          style: TextStyle(fontSize: 12, color: _muted(context)),
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'İpucu: Hakkında, slogan ve kendi bölümlerinin yazısında bir kelimeyi seçip "Stil"e dokunursan SADECE o kısım renklenir/büyür/çizilir.'),
                    style: TextStyle(fontSize: 12, color: _muted(context)),
                  ),
                  const SizedBox(height: 12),
                  Text(t(context, 'Bölüm stilleri'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final key in _keys)
                        ActionChip(
                          avatar: _isStyled(key) ? const Icon(Icons.check_circle, size: 16) : null,
                          label: Text(_labelOf(context, key)),
                          onPressed: () => _openSectionEditor(key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(t(context, 'Kendi bölümlerim'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    t(context, 'İstediğin yere kendi başlığını ve yazını ekle. Ücretsiz planda 2 bölüm; fazlası Premium.'),
                    style: TextStyle(fontSize: 12, color: _muted(context)),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _customs.length; i++) _customCard(context, i, _customs[i]),
                  if (_customs.length < TextStylingPolicy.maxCustomSections)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _addCustom,
                        icon: const Icon(Icons.add),
                        label: Text(t(context, 'Başlık / bölüm ekle')),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customCard(BuildContext context, int index, _CustomEntry c) {
    final items = _placementItems(context);
    final value = items.any((i) => i.value == c.after) ? c.after : 'end';
    final locked = index >= TextStylingPolicy.freeCustomSections;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${locked ? '🔒 ' : ''}${t(context, 'Bölüm')} ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: t(context, 'Sil'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeCustom(c),
              ),
            ],
          ),
          RichTextField(
            controller: c.heading,
            decoration: InputDecoration(
              labelText: t(context, 'Başlık'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          RichTextField(
            controller: c.body,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: t(context, 'Yazı (boş satırla paragraf ayır)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: t(context, 'Nerede görünsün?'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: items,
            onChanged: (v) {
              if (v == null) return;
              setState(() => c.after = v);
              _emit();
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final a in const [
                MapEntry('', 'Otomatik'),
                MapEntry('left', 'Sola'),
                MapEntry('center', 'Ortala'),
                MapEntry('right', 'Sağa'),
              ])
                ChoiceChip(
                  label: Text(t(context, a.value)),
                  selected: c.align == a.key,
                  onSelected: (_) {
                    setState(() => c.align = a.key);
                    _emit();
                  },
                ),
              TextButton.icon(
                onPressed: () => _openCustomStyle(c),
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: Text(t(context, 'Renk ve boyut')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleEditorSheet extends StatefulWidget {
  const _StyleEditorSheet({
    required this.title,
    required this.style,
    required this.isHero,
    required this.allowRename,
    required this.onChanged,
  });

  final String title;
  final Map<String, dynamic> style;
  final bool isHero;
  final bool allowRename;
  final VoidCallback onChanged;

  @override
  State<_StyleEditorSheet> createState() => _StyleEditorSheetState();
}

class _StyleEditorSheetState extends State<_StyleEditorSheet> {
  late final RichTextEditingController _titleCtrl =
      RichTextEditingController(text: (widget.style['title'] ?? '').toString());

  static const List<MapEntry<String, String>> _sizeOptions = [
    MapEntry('', 'Otomatik'),
    MapEntry('s', 'Küçük'),
    MapEntry('l', 'Büyük'),
    MapEntry('xl', 'Çok büyük'),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() {
      widget.style['title'] = _titleCtrl.text;
      widget.onChanged();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _set(String key, Object? value) {
    setState(() => widget.style[key] = value);
    widget.onChanged();
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _sizeChips(String key) {
    final cur = (widget.style[key] ?? '').toString();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final o in _sizeOptions)
          ChoiceChip(
            label: Text(t(context, o.value)),
            selected: cur == o.key,
            onSelected: (_) => _set(key, o.key),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (widget.allowRename) ...[
                const SizedBox(height: 12),
                RichTextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: t(context, 'Bölüm başlığını değiştir (boşsa otomatik)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              _label(widget.isHero ? t(context, 'Site adı (büyük başlık) rengi') : t(context, 'Başlık rengi')),
              StyleColorPicker(value: widget.style['hc']?.toString(), onChanged: (v) => _set('hc', v)),
              _label(widget.isHero ? t(context, 'Site adı boyutu') : t(context, 'Başlık boyutu')),
              _sizeChips('hs'),
              const SizedBox(height: 12),
              StyleFontDropdown(
                label: t(context, '🔒 Başlık yazı tipi (Premium)'),
                value: widget.style['hf']?.toString(),
                onChanged: (v) => _set('hf', v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(t(context, 'Başlık kalın')),
                    selected: widget.style['hb'] == true,
                    onSelected: (v) => _set('hb', v),
                  ),
                  FilterChip(
                    label: Text(t(context, 'Başlığın altına çizgi')),
                    selected: widget.style['hu'] == true,
                    onSelected: (v) => _set('hu', v),
                  ),
                ],
              ),
              _label(widget.isHero ? t(context, 'Slogan rengi') : t(context, 'Yazı rengi')),
              StyleColorPicker(value: widget.style['tc']?.toString(), onChanged: (v) => _set('tc', v)),
              _label(widget.isHero ? t(context, 'Slogan boyutu') : t(context, 'Yazı boyutu')),
              _sizeChips('ts'),
              const SizedBox(height: 12),
              StyleFontDropdown(
                label: t(context, '🔒 Yazı tipi (Premium)'),
                value: widget.style['tf']?.toString(),
                onChanged: (v) => _set('tf', v),
              ),
              const SizedBox(height: 8),
              FilterChip(
                label: Text(t(context, 'Yazı italik')),
                selected: widget.style['it'] == true,
                onSelected: (v) => _set('it', v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        widget.style.clear();
                        _titleCtrl.text = '';
                      });
                      widget.onChanged();
                    },
                    child: Text(t(context, 'Sıfırla')),
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
