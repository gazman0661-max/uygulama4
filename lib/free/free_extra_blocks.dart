import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/layout_style_picker_field.dart';
import '../widgets/working_hours_picker_field.dart';

/// Formlarda olup serbest builder'da OLMAYAN blokların editör alanları ve önizleme özeti.
/// HTML karşılığı: templates/html/extra_block_html.dart. Veri hep blok haritasında (d) durur.
const List<String> kExtraBlockTypes = [
  'hero', 'hours', 'testimonials', 'products', 'menu', 'packages', 'team', 'timeline', 'skills', 'review',
];

const Map<String, String> kExtraBlockTitles = {
  'hero': 'Hero (kapak düzeni)',
  'hours': 'Çalışma Saatleri',
  'testimonials': 'Müşteri Yorumları',
  'products': 'Ürünler',
  'menu': 'Menü',
  'packages': 'Paketler',
  'team': 'Ekip',
  'timeline': 'Hikâyemiz / Zaman Çizelgesi',
  'skills': 'Yetenek Etiketleri',
  'review': 'Google Yorum Butonu',
};

const Map<String, IconData> kExtraBlockIcons = {
  'hero': Icons.view_carousel_outlined,
  'hours': Icons.schedule,
  'testimonials': Icons.format_quote,
  'products': Icons.storefront_outlined,
  'menu': Icons.restaurant_menu,
  'packages': Icons.local_offer_outlined,
  'team': Icons.groups_outlined,
  'timeline': Icons.timeline,
  'skills': Icons.label_outline,
  'review': Icons.star_outline,
};

const Map<String, int> kExtraBlockRows = {
  'hero': 60, 'hours': 40, 'testimonials': 48, 'products': 56, 'menu': 56,
  'packages': 56, 'team': 52, 'timeline': 44, 'skills': 16, 'review': 14,
};

class _F {
  final String key, label, hint;
  final bool multiline, isBool;
  const _F(this.key, this.label, {this.hint = '', this.multiline = false, this.isBool = false});
}

class _Schema {
  final String itemLabel;
  final List<_F> fields;
  const _Schema(this.itemLabel, this.fields);
}

const Map<String, _Schema> _schemas = {
  'testimonials': _Schema('Yorum', [
    _F('name', 'Ad'),
    _F('text', 'Yorum', multiline: true),
    _F('rating', 'Puan (1-5, boş bırakılabilir)'),
  ]),
  'menu': _Schema('Kategori', [
    _F('title', 'Kategori adı'),
    _F('lines', 'Ürünler', hint: 'Her satır: Ad | Açıklama | Fiyat', multiline: true),
  ]),
  'packages': _Schema('Paket', [
    _F('title', 'Paket adı'),
    _F('sessionLabel', 'Seans / süre'),
    _F('price', 'Fiyat'),
    _F('originalPrice', 'Eski fiyat (üstü çizili)'),
    _F('services', 'İçerik', hint: 'Her satır bir madde', multiline: true),
    _F('note', 'Not'),
    _F('isFeatured', 'Öne çıkan paket', isBool: true),
  ]),
  'team': _Schema('Kişi', [
    _F('name', 'Ad Soyad'),
    _F('specialty', 'Uzmanlık'),
    _F('bio', 'Kısa bilgi', multiline: true),
    _F('tags', 'Etiketler', hint: 'Virgülle ayır'),
  ]),
  'timeline': _Schema('Adım', [
    _F('year', 'Yıl'),
    _F('title', 'Başlık'),
    _F('description', 'Açıklama', multiline: true),
  ]),
};

/// Düz metin alanı: kendi controller'ını yönetir, değişince blok haritasına yazar.
class _KeyField extends StatefulWidget {
  const _KeyField({required this.map, required this.k, required this.label, this.hint = '', this.multiline = false, required this.onChanged});
  final Map<String, dynamic> map;
  final String k, label, hint;
  final bool multiline;
  final VoidCallback onChanged;
  @override
  State<_KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<_KeyField> {
  late final _c = TextEditingController(text: (widget.map[widget.k] ?? '').toString());
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _c,
          minLines: widget.multiline ? 2 : 1,
          maxLines: widget.multiline ? 6 : 1,
          decoration: InputDecoration(
            labelText: t(context, widget.label),
            hintText: widget.hint.isEmpty ? null : t(context, widget.hint),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            widget.map[widget.k] = v;
            widget.onChanged();
          },
        ),
      );
}

/// Tekrarlı satır editörü (yorum, menü kategorisi, paket, kişi, zaman çizelgesi).
class _ListEditor extends StatefulWidget {
  const _ListEditor({required this.d, required this.schema, required this.onChanged});
  final Map<String, dynamic> d;
  final _Schema schema;
  final VoidCallback onChanged;
  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  List<Map<String, dynamic>> get _items {
    final raw = widget.d['items'];
    if (raw is! List) widget.d['items'] = <dynamic>[];
    return (widget.d['items'] as List).cast<Map<String, dynamic>>();
  }

  @override
  void initState() {
    super.initState();
    final raw = widget.d['items'];
    // JSON'dan gelen Map<dynamic,dynamic>'leri Map<String,dynamic>'e çevir.
    widget.d['items'] = [
      if (raw is List) for (final e in raw) if (e is Map) Map<String, dynamic>.from(e),
    ];
    if ((widget.d['items'] as List).isEmpty) (widget.d['items'] as List).add(<String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < items.length; i++)
        Container(
          key: ObjectKey(items[i]),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('${t(context, widget.schema.itemLabel)} ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              if (items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() {
                    items.removeAt(i);
                    widget.onChanged();
                  }),
                ),
            ]),
            for (final f in widget.schema.fields)
              f.isBool
                  ? SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t(context, f.label), style: const TextStyle(fontSize: 13)),
                      value: items[i][f.key] == true,
                      onChanged: (v) => setState(() {
                        items[i][f.key] = v;
                        widget.onChanged();
                      }),
                    )
                  : _KeyField(map: items[i], k: f.key, label: f.label, hint: f.hint, multiline: f.multiline, onChanged: widget.onChanged),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            items.add(<String, dynamic>{});
            widget.onChanged();
          }),
          icon: const Icon(Icons.add),
          label: Text(isEnglish(context) ? 'Add ${t(context, widget.schema.itemLabel)}' : '${widget.schema.itemLabel} ekle'),
        ),
      ),
    ]);
  }
}

List<Map<String, String?>> _imgs(Map<String, dynamic> d) {
  final raw = d['images'];
  if (raw is! List) return [];
  return [for (final e in raw) if (e is Map) {'url': e['url']?.toString(), 'caption': e['caption']?.toString()}];
}

/// Bloğa özel alanlar (başlık alanı hariç; onu ortak editör ekler).
List<Widget> extraBlockFields(BuildContext context, String type, Map<String, dynamic> d, VoidCallback touch, {int maxImages = 10}) {
  switch (type) {
    case 'hero':
      return [
        LayoutStylePickerField(
          initialLayoutStyle: (d['layout'] ?? 'centered').toString(),
          onChanged: (v) {
            d['layout'] = v;
            touch();
          },
        ),
        const SizedBox(height: 12),
        _KeyField(map: d, k: 'eyebrow', label: 'Üst etiket (örn. sektör)', onChanged: touch),
        _KeyField(map: d, k: 'name', label: 'Ad / başlık', onChanged: touch),
        _KeyField(map: d, k: 'tagline', label: 'Alt yazı', multiline: true, onChanged: touch),
        _KeyField(map: d, k: 'ctaText', label: 'Buton yazısı', onChanged: touch),
        _KeyField(map: d, k: 'ctaHref', label: 'Buton linki (tel:, https://…)', onChanged: touch),
        GalleryPickerField(
          label: t(context, 'Kapak fotoğrafı'),
          maxImages: 1,
          initialImages: _imgs(d),
          showStyleOption: false,
          onChanged: (v) {
            d['images'] = [for (final m in v) {'url': m['url'], 'caption': m['caption']}];
            touch();
          },
        ),
      ];
    case 'hours':
      return [
        WorkingHoursPickerField(
          label: t(context, 'Çalışma Saatleri'),
          initialHours: () {
            final raw = d['items'];
            if (raw is! List || raw.isEmpty) return null;
            return [for (final e in raw) if (e is Map) {for (final en in e.entries) en.key.toString(): en.value?.toString()}];
          }(),
          onChanged: (v) {
            d['items'] = v;
            touch();
          },
        ),
      ];
    case 'products':
      return [
        GalleryPickerField(
          label: t(context, 'Ürün fotoğrafları (açıklama: "Ad - Fiyat")'),
          maxImages: maxImages > GalleryPickerField.kMaxGalleryImages ? GalleryPickerField.kMaxGalleryImages : maxImages,
          initialImages: _imgs(d),
          showStyleOption: false,
          onChanged: (v) {
            d['images'] = [for (final m in v) {'url': m['url'], 'caption': m['caption']}];
            touch();
          },
        ),
      ];
    case 'skills':
      return [_KeyField(map: d, k: 'skills', label: 'Etiketler', hint: 'Virgülle ya da satır satır', multiline: true, onChanged: touch)];
    case 'review':
      return [
        _KeyField(map: d, k: 'url', label: 'Google yorum linki (https://…)', onChanged: touch),
        Text(t(context, 'Not: Bu buton premium paketlerde yayınlanır.'), style: const TextStyle(fontSize: 12)),
      ];
    default:
      final s = _schemas[type];
      if (s == null) return const [];
      return [_ListEditor(d: d, schema: s, onChanged: touch)];
  }
}

/// Önizlemede gösterilecek kısa satırlar.
List<String> extraBlockSummary(String type, Map<String, dynamic> b) {
  String s(dynamic v) => v == null ? '' : v.toString().trim();
  final items = b['items'] is List ? [for (final e in b['items'] as List) if (e is Map) e] : <Map>[];
  switch (type) {
    case 'hero':
      return [s(b['name']), s(b['tagline'])].where((e) => e.isNotEmpty).toList();
    case 'hours':
      return [for (final e in items) '${s(e['day'])}  ${s(e['range']).isEmpty ? '—' : s(e['range'])}'];
    case 'testimonials':
      return [for (final e in items) if (s(e['name']).isNotEmpty) '“${s(e['text'])}” — ${s(e['name'])}'];
    case 'menu':
      return [for (final e in items) if (s(e['title']).isNotEmpty) s(e['title'])];
    case 'packages':
      return [for (final e in items) if (s(e['title']).isNotEmpty) '${s(e['title'])}  ${s(e['price'])}'];
    case 'team':
      return [for (final e in items) if (s(e['name']).isNotEmpty) '${s(e['name'])}  ${s(e['specialty'])}'];
    case 'timeline':
      return [for (final e in items) if (s(e['title']).isNotEmpty) '${s(e['year'])}  ${s(e['title'])}'];
    case 'products':
      final im = b['images'] is List ? (b['images'] as List).length : 0;
      return im == 0 ? [] : ['$im ürün'];
    case 'skills':
      return [s(b['skills'])].where((e) => e.isNotEmpty).toList();
    case 'review':
      return [s(b['url'])].where((e) => e.isNotEmpty).toList();
  }
  return [];
}
