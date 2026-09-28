import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../templates/html/extra_page_blocks.dart';
import '../templates/html/generic_business_html_generator.dart' show slugifyPageTitle;
import '../theme/app_theme.dart';
import '../widgets/app_popup.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/pill_button.dart';
import '../widgets/video_link_field.dart';

/// 28.09.2026 eklendi (kanka isteği) — "Genel İşletme" çok sayfa modunda tek
/// bir ek sayfayı BLOK listesi olarak düzenleyen tam ekran editör.
///
/// Eskiden sadece başlık + düz metin vardı. Şimdi sayfa; yazı, tek görsel,
/// galeri, video, fiyat/hizmet listesi, SSS ve buton bloklarından oluşuyor;
/// bloklar ▲▼ ile sıralanıyor, 🗑 ile siliniyor. Sayfa başına ayrıca
/// "Google açıklaması (SEO)" alanı var.
///
/// Sonuç (Navigator.pop): {slug, title, content, blocks, seoDesc} — hepsi
/// String (bkz. qtDecodeStringMapList; `blocks` JSON metni). Eski sayfalar
/// (sadece `content` dolu) açılırken otomatik tek bir Yazı bloğuna çevrilir.
///
/// NOT (kanka kararı): fotoğraf/base64 boyut yapısına bu işte DOKUNULMADI;
/// görseller mevcut GalleryPickerField ile aynı şekilde (sıkıştırılıp HTML'e
/// gömülerek) eklenir.
class ExtraPageEditorScreen extends StatefulWidget {
  final Map<String, String>? existing;
  final Set<String> existingSlugs;
  const ExtraPageEditorScreen({super.key, this.existing, required this.existingSlugs});

  @override
  State<ExtraPageEditorScreen> createState() => _ExtraPageEditorScreenState();
}

class _BlockEntry {
  final int id;
  final Map<String, dynamic> data;
  _BlockEntry(this.id, this.data);
}

String _emojiFor(String type) {
  switch (type) {
    case 'text':
      return '✍️';
    case 'image':
      return '🖼️';
    case 'gallery':
      return '🎞️';
    case 'video':
      return '▶️';
    case 'services':
      return '💰';
    case 'faq':
      return '❓';
    case 'button':
      return '🔘';
  }
  return '▫️';
}

String _labelFor(String type) {
  switch (type) {
    case 'text':
      return 'Yazı';
    case 'image':
      return 'Tek Görsel';
    case 'gallery':
      return 'Galeri';
    case 'video':
      return 'Video';
    case 'services':
      return 'Fiyat / Hizmet Listesi';
    case 'faq':
      return 'Sık Sorulan Sorular';
    case 'button':
      return 'Buton';
  }
  return type;
}

String _hintFor(String type) {
  switch (type) {
    case 'text':
      return 'Başlık ve paragraflar';
    case 'image':
      return 'Büyük tek fotoğraf ve alt yazı';
    case 'gallery':
      return 'Birden fazla fotoğraf (ızgara, slayt, bento...)';
    case 'video':
      return 'YouTube veya Vimeo linki';
    case 'services':
      return 'Hizmet - süre - fiyat satırları';
    case 'faq':
      return 'Soru ve cevap çiftleri';
    case 'button':
      return 'Ara, WhatsApp, link veya Google yorum butonu';
  }
  return '';
}

Map<String, dynamic> _newBlock(String type) {
  switch (type) {
    case 'text':
      return {'type': 'text', 'heading': '', 'body': ''};
    case 'image':
      return {'type': 'image', 'heading': '', 'images': <Map<String, String?>>[]};
    case 'gallery':
      return {'type': 'gallery', 'heading': '', 'images': <Map<String, String?>>[], 'style': 'grid'};
    case 'video':
      return {'type': 'video', 'heading': '', 'url': '', 'orientation': 'landscape'};
    case 'services':
      return {'type': 'services', 'heading': '', 'lines': ''};
    case 'faq':
      return {
        'type': 'faq',
        'heading': '',
        'items': [
          {'question': '', 'answer': ''}
        ],
      };
    case 'button':
      return {'type': 'button', 'label': '', 'action': 'whatsapp', 'url': ''};
  }
  return {'type': type};
}

class _ExtraPageEditorScreenState extends State<ExtraPageEditorScreen> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existing?['title'] ?? '');
  late final TextEditingController _seoCtrl =
      TextEditingController(text: widget.existing?['seoDesc'] ?? '');
  final List<_BlockEntry> _blocks = [];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    final decoded = decodeExtraPageBlocks(widget.existing?['blocks']);
    if (decoded.isNotEmpty) {
      for (final b in decoded) {
        _blocks.add(_BlockEntry(_nextId++, b));
      }
    } else {
      // Eski (blok öncesi) sayfa: düz metni tek bir Yazı bloğuna çevir.
      final legacy = (widget.existing?['content'] ?? '').trim();
      if (legacy.isNotEmpty) {
        _blocks.add(_BlockEntry(_nextId++, {'type': 'text', 'heading': '', 'body': legacy}));
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _seoCtrl.dispose();
    super.dispose();
  }

  Future<void> _addBlock() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                t(ctx, 'Blok Ekle'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final type in kExtraPageBlockTypes)
              ListTile(
                leading: Text(_emojiFor(type), style: const TextStyle(fontSize: 22)),
                title: Text(t(ctx, _labelFor(type))),
                subtitle: Text(t(ctx, _hintFor(type))),
                onTap: () => Navigator.pop(ctx, type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    setState(() => _blocks.add(_BlockEntry(_nextId++, _newBlock(type))));
  }

  /// Bloğu siler ama veriyi tutar: "Geri Al" ile AYNI sıraya, içeriği (fotoğraflar
  /// dahil) kaybetmeden geri konur. Kart verisini doğrudan data haritasına
  /// yazdığı için (bkz. _BlockCard) geri eklenen kart eski haliyle açılır.
  void _deleteBlock(int index) {
    final removed = _blocks[index];
    setState(() => _blocks.removeAt(index));
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t(context, 'Blok silindi')),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: t(context, 'Geri Al'),
          onPressed: () {
            if (!mounted) return;
            setState(() => _blocks.insert(index.clamp(0, _blocks.length), removed));
          },
        ),
      ),
    );
  }

  void _move(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= _blocks.length) return;
    setState(() {
      final item = _blocks.removeAt(index);
      _blocks.insert(to, item);
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showAppPopup(context, message: t(context, 'Sayfa başlığı gerekli.'), icon: '⚠️');
      return;
    }
    for (final e in _blocks) {
      final d = e.data;
      if (d['type'] == 'button' &&
          d['action'] == 'link' &&
          (d['label'] ?? '').toString().trim().isNotEmpty &&
          sanitizeButtonUrl((d['url'] ?? '').toString()) == null) {
        showAppPopup(
          context,
          message: t(context, 'Buton linki geçersiz. https:// ile başlayan bir adres, e-posta (mailto:) veya telefon (tel:) yazın.'),
          icon: '⚠️',
        );
        return;
      }
    }
    // Mevcut sayfayı düzenliyorsak slug'ı KORU (linkler kırılmasın).
    final slug = widget.existing?['slug'] ?? slugifyPageTitle(title, widget.existingSlugs);
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pop<Map<String, String>>(context, <String, String>{
      'slug': slug,
      'title': title,
      'content': '',
      'blocks': encodeExtraPageBlocks(_blocks.map((e) => e.data).toList()),
      'seoDesc': _seoCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, widget.existing == null ? 'Yeni Sayfa' : 'Sayfayı Düzenle')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'Sayfa başlığı (örn. Hakkımızda)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  t(context, 'Henüz blok yok. Aşağıdan yazı, görsel, galeri, video, fiyat listesi, SSS veya buton ekleyerek sayfanı oluştur.'),
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
              ),
            for (var i = 0; i < _blocks.length; i++)
              _BlockCard(
                key: ValueKey(_blocks[i].id),
                data: _blocks[i].data,
                canUp: i > 0,
                canDown: i < _blocks.length - 1,
                onUp: () => _move(i, -1),
                onDown: () => _move(i, 1),
                onDelete: () => _deleteBlock(i),
              ),
            OutlinedButton.icon(
              onPressed: _addBlock,
              icon: const Icon(Icons.add),
              label: Text(t(context, 'Blok Ekle')),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                t(context, 'Google açıklaması (SEO)'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                TextField(
                  controller: _seoCtrl,
                  maxLines: 3,
                  maxLength: 160,
                  decoration: InputDecoration(
                    labelText: t(context, 'Kısa açıklama (opsiyonel)'),
                    helperText: t(context, 'Google sonuçlarında bu sayfanın altında görünür. Boş bırakırsan ilk yazı bloğundan alınır.'),
                    helperMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PillButton(
              label: t(context, 'Kaydet'),
              borderColor: AppTheme.accentBlue,
              textColor: AppTheme.accentBlue,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqRow {
  final TextEditingController q;
  final TextEditingController a;
  _FaqRow(String question, String answer)
      : q = TextEditingController(text: question),
        a = TextEditingController(text: answer);
  void dispose() {
    q.dispose();
    a.dispose();
  }
}

/// Tek bir bloğun düzenleme kartı. Veriyi doğrudan [data] haritasına yazar
/// (kaydırmayla kart dispose/yeniden oluşsa bile değerler kaybolmaz).
class _BlockCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool canUp;
  final bool canDown;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onDelete;

  const _BlockCard({
    super.key,
    required this.data,
    required this.canUp,
    required this.canDown,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
  });

  @override
  State<_BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends State<_BlockCard> {
  Map<String, dynamic> get d => widget.data;
  String get _type => (d['type'] ?? '').toString();
  String _s(String k) => (d[k] ?? '').toString();

  late final TextEditingController _heading = TextEditingController(text: _s('heading'));
  late final TextEditingController _body = TextEditingController(text: _s('body'));
  late final TextEditingController _url = TextEditingController(text: _s('url'));
  late final TextEditingController _lines = TextEditingController(text: _s('lines'));
  late final TextEditingController _label = TextEditingController(text: _s('label'));
  final List<_FaqRow> _faq = [];

  @override
  void initState() {
    super.initState();
    _url.addListener(() => d['url'] = _url.text);
    if (_type == 'faq') {
      final items = d['items'];
      if (items is List) {
        for (final e in items) {
          if (e is Map) {
            _faq.add(_FaqRow((e['question'] ?? '').toString(), (e['answer'] ?? '').toString()));
          }
        }
      }
      if (_faq.isEmpty) _faq.add(_FaqRow('', ''));
    }
  }

  @override
  void dispose() {
    _heading.dispose();
    _body.dispose();
    _url.dispose();
    _lines.dispose();
    _label.dispose();
    for (final r in _faq) {
      r.dispose();
    }
    super.dispose();
  }

  void _syncFaq() {
    d['items'] = _faq.map((r) => {'question': r.q.text, 'answer': r.a.text}).toList();
  }

  List<Map<String, String?>> _imgs() {
    final raw = d['images'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v?.toString())))
        .toList();
  }

  Widget _field(
    TextEditingController c,
    String label,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: t(context, label),
          hintText: hint == null ? null : t(context, hint),
          helperText: helper == null ? null : t(context, helper),
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _headingField() => _field(
        _heading,
        'Başlık (opsiyonel)',
        (v) => d['heading'] = v,
      );

  List<Widget> _bodyWidgets() {
    switch (_type) {
      case 'text':
        return [
          _headingField(),
          _field(
            _body,
            'Yazı',
            (v) => d['body'] = v,
            maxLines: 6,
            hint: 'Paragrafları boş satırla ayırabilirsin.',
          ),
        ];
      case 'image':
        return [
          _headingField(),
          GalleryPickerField(
            label: t(context, 'Görsel'),
            maxImages: 1,
            initialImages: _imgs(),
            onChanged: (v) => d['images'] = v,
          ),
        ];
      case 'gallery':
        return [
          _headingField(),
          GalleryPickerField(
            label: t(context, 'Galeri'),
            initialImages: _imgs(),
            onChanged: (v) => d['images'] = v,
            showStyleOption: true,
            initialStyle: _s('style').isEmpty ? 'grid' : _s('style'),
            onStyleChanged: (v) => d['style'] = v,
          ),
        ];
      case 'video':
        return [
          _headingField(),
          VideoLinkField(
            urlController: _url,
            orientation: _s('orientation') == 'portrait' ? 'portrait' : 'landscape',
            onOrientationChanged: (v) => setState(() => d['orientation'] = v),
          ),
        ];
      case 'services':
        return [
          _headingField(),
          _field(
            _lines,
            'Hizmetler ve fiyatlar',
            (v) => d['lines'] = v,
            maxLines: 6,
            hint: 'Saç Kesimi - 30 dk - 250 TL',
            helper: 'Her satıra bir hizmet: Ad - Süre - Fiyat. Süre zorunlu değil, "Ad - Fiyat" da yazabilirsin. Ayırıcı tirenin iki yanında boşluk olsun.',
          ),
        ];
      case 'faq':
        return [
          _headingField(),
          for (var i = 0; i < _faq.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t(context, 'Soru')} ${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
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
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _faq[i].q,
                      onChanged: (_) => _syncFaq(),
                      decoration: InputDecoration(
                        labelText: t(context, 'Soru'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _faq[i].a,
                      maxLines: 3,
                      onChanged: (_) => _syncFaq(),
                      decoration: InputDecoration(
                        labelText: t(context, 'Cevap'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
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
      case 'button':
        final action = _s('action').isEmpty ? 'whatsapp' : _s('action');
        const actions = <List<String>>[
          ['whatsapp', 'WhatsApp'],
          ['call', 'Ara'],
          ['link', 'Link'],
          ['review', 'Google Yorum'],
        ];
        return [
          _field(_label, 'Buton yazısı', (v) => d['label'] = v, hint: 'Randevu Al'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final a in actions)
                ChoiceChip(
                  label: Text(t(context, a[1])),
                  selected: action == a[0],
                  onSelected: (_) => setState(() => d['action'] = a[0]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (action == 'link')
            _field(
              _url,
              'Link',
              (v) => d['url'] = v,
              keyboardType: TextInputType.url,
              hint: 'https://ornek.com/randevu',
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t(
                  context,
                  action == 'call'
                      ? 'Sitenin telefon numarası kullanılır.'
                      : action == 'whatsapp'
                          ? 'Sitenin WhatsApp numarası kullanılır.'
                          : 'Formdaki Google yorum linki kullanılır (abonelikte açılır).',
                ),
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
        ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_emojiFor(_type)}  ${t(context, _labelFor(_type))}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: widget.canUp ? widget.onUp : null,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_downward, size: 20),
                  onPressed: widget.canDown ? widget.onDown : null,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ..._bodyWidgets(),
          ],
        ),
      ),
    );
  }
}
