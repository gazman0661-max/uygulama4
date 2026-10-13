import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/location_picker_field.dart';
import '../widgets/video_link_field.dart';
import 'free_extra_blocks.dart';
import 'free_model.dart';

/// Hazır bölümü (galeri / video / hizmet listesi / SSS) düzenleyen alt sayfa.
/// Blok JSON'u extra_page_blocks.dart ile AYNI şemadadır.
///
/// [maxImages]: bu bölüm için kalan görsel hakkı (sayfa başına 14 sınırından).
Future<void> showFreeBlockEditor(
  BuildContext context, {
  required FreeSection section,
  required int maxImages,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BlockEditor(section: section, maxImages: maxImages, onChanged: onChanged),
  );
}

class _FaqRow {
  final TextEditingController q;
  final TextEditingController a;
  _FaqRow(String q, String a)
      : q = TextEditingController(text: q),
        a = TextEditingController(text: a);
  void dispose() {
    q.dispose();
    a.dispose();
  }
}

class _BlockEditor extends StatefulWidget {
  final FreeSection section;
  final int maxImages;
  final VoidCallback onChanged;
  const _BlockEditor({required this.section, required this.maxImages, required this.onChanged});

  @override
  State<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<_BlockEditor> {
  Map<String, dynamic> get d => widget.section.block;
  String get type => widget.section.blockType;

  late final _heading = TextEditingController(text: (d['heading'] ?? '').toString());
  late final _url = TextEditingController(text: (d['url'] ?? '').toString());
  late final _lines = TextEditingController(text: (d['lines'] ?? '').toString());
  final List<_FaqRow> _faq = [];

  @override
  void initState() {
    super.initState();
    final raw = d['items'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) _faq.add(_FaqRow((e['question'] ?? '').toString(), (e['answer'] ?? '').toString()));
      }
    }
    if (type == 'faq' && _faq.isEmpty) _faq.add(_FaqRow('', ''));
    _url.addListener(_urlListener);
  }

  @override
  void dispose() {
    _url.removeListener(_urlListener);
    _heading.dispose();
    _url.dispose();
    _lines.dispose();
    for (final f in _faq) {
      f.dispose();
    }
    super.dispose();
  }

  void _touch() => widget.onChanged();

  void _syncFaq() {
    d['items'] = [
      for (final f in _faq) {'question': f.q.text, 'answer': f.a.text},
    ];
    _touch();
  }

  String get _title {
    switch (type) {
      case 'gallery':
        return 'Galeri';
      case 'video':
        return 'Video';
      case 'services':
        return 'Hizmet ve Fiyat Listesi';
      case 'faq':
        return 'Sık Sorulan Sorular';
      case 'map':
        return 'Harita';
    }
    return kExtraBlockTitles[type] ?? 'Bölüm';
  }

  List<Map<String, String?>> _images() {
    final raw = d['images'];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map) {'url': e['url']?.toString(), 'caption': e['caption']?.toString()},
    ];
  }

  Widget _headingField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _heading,
          onChanged: (v) {
            d['heading'] = v;
            _touch();
          },
          decoration: InputDecoration(
            labelText: t(context, 'Başlık (opsiyonel)'),
            border: const OutlineInputBorder(),
          ),
        ),
      );

  List<Widget> _fields() {
    switch (type) {
      case 'gallery':
        final cur = _images().length;
        final cap = widget.maxImages < cur ? cur : widget.maxImages;
        return [
          _headingField(),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t(context, 'Önce / Sonra görünümü'), style: const TextStyle(fontSize: 13)),
            value: d['beforeAfter'] == true || d['beforeAfter'] == 'true',
            onChanged: (v) => setState(() {
              d['beforeAfter'] = v;
              _touch();
            }),
          ),
          GalleryPickerField(
            label: t(context, 'Galeri'),
            maxImages: cap > GalleryPickerField.kMaxGalleryImages ? GalleryPickerField.kMaxGalleryImages : cap,
            initialImages: _images(),
            showStyleOption: true,
            // 'beforeAfter' anahtarı aşağıda ayrıca eklenir
            initialStyle: (d['style'] ?? '').toString().isEmpty ? 'grid' : d['style'].toString(),
            onStyleChanged: (v) {
              d['style'] = v;
              _touch();
            },
            onChanged: (v) {
              d['images'] = [
                for (final m in v) {'url': m['url'], 'caption': m['caption']},
              ];
              _touch();
            },
          ),
        ];
      case 'map':
        return [
          _headingField(),
          LocationPickerField(
            initialAddress: (d['address'] ?? '').toString(),
            initialLat: double.tryParse((d['lat'] ?? '').toString()) ?? 41.0082,
            initialLng: double.tryParse((d['lng'] ?? '').toString()) ?? 28.9784,
            onChanged: (address, lat, lng) {
              d['address'] = address;
              d['lat'] = lat;
              d['lng'] = lng;
              _touch();
            },
          ),
        ];
      case 'video':
        return [
          _headingField(),
          VideoLinkField(
            urlController: _url,
            orientation: (d['orientation'] ?? '') == 'portrait' ? 'portrait' : 'landscape',
            onOrientationChanged: (v) => setState(() {
              d['orientation'] = v;
              _touch();
            }),
          ),
        ];
      case 'services':
        return [
          _headingField(),
          TextField(
            controller: _lines,
            maxLines: 6,
            onChanged: (v) {
              d['lines'] = v;
              _touch();
            },
            decoration: InputDecoration(
              labelText: t(context, 'Hizmetler ve fiyatlar'),
              hintText: 'Saç Kesimi - 30 dk - 250 TL',
              helperText: t(context,
                  'Her satıra bir hizmet: Ad - Süre - Fiyat. Süre zorunlu değil, "Ad - Fiyat" da yazabilirsin. Ayırıcı tirenin iki yanında boşluk olsun.'),
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      case 'faq':
        return [
          _headingField(),
          for (var i = 0; i < _faq.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Text('${t(context, 'Soru')} ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  if (_faq.length > 1)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _faq.removeAt(i).dispose();
                        _syncFaq();
                      }),
                    ),
                ]),
                TextField(
                  controller: _faq[i].q,
                  onChanged: (_) => _syncFaq(),
                  decoration: InputDecoration(labelText: t(context, 'Soru'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _faq[i].a,
                  maxLines: 3,
                  onChanged: (_) => _syncFaq(),
                  decoration: InputDecoration(labelText: t(context, 'Cevap'), border: const OutlineInputBorder()),
                ),
              ]),
            ),
          TextButton.icon(
            onPressed: () => setState(() {
              _faq.add(_FaqRow('', ''));
              _syncFaq();
            }),
            icon: const Icon(Icons.add, size: 18),
            label: Text(t(context, 'Soru Ekle')),
          ),
        ];
    }
    if (kExtraBlockTypes.contains(type)) {
      return [
        if (type != 'hero' && type != 'review') _headingField(),
        ...extraBlockFields(context, type, d, _touch,
            maxImages: widget.maxImages),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t(context, _title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ..._fields(),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(t(context, 'Tamam'))),
        ]),
      ),
    );
  }

  void _urlListener() {
    if ((d['url'] ?? '').toString() != _url.text) {
      d['url'] = _url.text;
      _touch();
    }
  }
}
