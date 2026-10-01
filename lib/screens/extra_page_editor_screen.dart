import '../widgets/rich_text_field.dart';
import '../widgets/style_pickers.dart';
import '../templates/html/rich_text_markup.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../localization/app_strings.dart';
import '../templates/html/extra_page_blocks.dart';
import '../templates/html/generic_business_html_generator.dart' show slugifyPageTitle;
import '../theme/app_theme.dart';
import '../widgets/app_popup.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/location_picker_field.dart';
import '../widgets/testimonial_consent_checkbox.dart';
import '../widgets/pill_button.dart';
import '../widgets/video_link_field.dart';
import '../widgets/working_hours_picker_field.dart';
import 'html_draft_preview_screen.dart';

class ExtraPageEditorScreen extends StatefulWidget {
  final Map<String, String>? existing;
  final Set<String> existingSlugs;
  final List<String> allowedBlockTypes;
  final bool isHome;
  final String Function(String title, String slug, List<Map<String, dynamic>> blocks)? previewBuilder;
  const ExtraPageEditorScreen({
    super.key,
    this.existing,
    required this.existingSlugs,
    this.allowedBlockTypes = kExtraPageBlockTypes,
    this.isHome = false,
    this.previewBuilder,
  });

  @override
  State<ExtraPageEditorScreen> createState() => _ExtraPageEditorScreenState();
}

const String _kBridgeJs = r'''
(function(){
var SEL=__SEL__,LEN=__LEN__;
if(!window.__fsInit){
window.__fsInit=true;
var st=document.createElement('style');
st.textContent='[data-fsb]{cursor:pointer}.fs-ph{margin:12px 16px;padding:22px 14px;border:2px dashed #999;border-radius:12px;text-align:center;font:14px sans-serif;color:#888}.fs-sel{outline:3px solid #2f80ed;outline-offset:-3px}.fs-add{display:flex;align-items:center;gap:8px;margin:0 16px;padding:5px 0;color:#2f80ed;font:600 11px sans-serif;cursor:pointer}.fs-add:before,.fs-add:after{content:"";flex:1;border-top:1px dashed #2f80ed}';
document.head.appendChild(st);
document.addEventListener('click',function(e){
var a=e.target.closest('.fs-add');
if(a){e.preventDefault();e.stopPropagation();FsBridge.postMessage('add:'+a.getAttribute('data-ins'));return;}
var b=e.target.closest('[data-fsb]');
if(b){e.preventDefault();e.stopPropagation();FsBridge.postMessage('sel:'+b.getAttribute('data-fsb'));}
},true);
window.__fsMark=function(n,sc){
document.querySelectorAll('.fs-sel').forEach(function(x){x.classList.remove('fs-sel');});
if(n<0)return;
var el=document.querySelector('[data-fsb="'+n+'"]');
if(!el)return;
var t=el;
if(!el.classList.contains('fs-ph')){t=null;for(var c=el.firstElementChild;c;c=c.nextElementSibling){if(c.tagName!=='STYLE'&&c.tagName!=='SCRIPT'){t=c;break;}}}
if(t){t.classList.add('fs-sel');if(sc&&t.scrollIntoView)t.scrollIntoView({block:'center'});}
};
}
document.querySelectorAll('.fs-add').forEach(function(x){x.remove();});
var els=[].slice.call(document.querySelectorAll('[data-fsb]'));
function bar(i){var d=document.createElement('div');d.className='fs-add';d.setAttribute('data-ins',i);d.textContent='__ADD__';return d;}
els.forEach(function(el){el.parentNode.insertBefore(bar(el.getAttribute('data-fsb')),el);});
if(els.length){var last=els[els.length-1];last.parentNode.insertBefore(bar(LEN),last.nextSibling);}
window.__fsMark(SEL,false);
})();
''';

String _summaryOf(Map<String, dynamic> d) {
  for (final k in const ['heading', 'tagline', 'label', 'body', 'address']) {
    final v = (d[k] ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.isNotEmpty) return v.length > 40 ? '${v.substring(0, 40)}…' : v;
  }
  return '';
}

class _BlockEntry {
  final int id;
  final Map<String, dynamic> data;
  _BlockEntry(this.id, this.data);
}

String _emojiFor(String type) {
  switch (type) {
    case 'hero':
      return '🌟';
    case 'hours':
      return '🕒';
    case 'map':
      return '📍';
    case 'reviews':
      return '⭐';
    case 'contact':
      return '📞';
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
    case 'hero':
      return 'Kapak (Hero)';
    case 'hours':
      return 'Çalışma Saatleri';
    case 'map':
      return 'Harita';
    case 'reviews':
      return 'Müşteri Yorumları';
    case 'contact':
      return 'İletişim / Talep Formu';
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
    case 'hero':
      return 'Büyük kapak görseli, başlık, slogan ve buton';
    case 'hours':
      return 'Günlere göre açılış-kapanış saatleri';
    case 'map':
      return 'Adres ve Google Haritası (abonelikte açılır)';
    case 'reviews':
      return 'İsim, yorum ve puan satırları';
    case 'contact':
      return 'Ara, WhatsApp, Instagram butonları ve talep formu';
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
    case 'hero':
      return {
        'type': 'hero',
        'heading': '',
        'tagline': '',
        'images': <Map<String, String?>>[],
        'action': 'whatsapp',
        'label': '',
        'url': '',
      };
    case 'hours':
      return {'type': 'hours', 'heading': '', 'hours': <Map<String, String?>>[]};
    case 'map':
      return {'type': 'map', 'heading': '', 'address': '', 'lat': 41.0082, 'lng': 28.9784};
    case 'reviews':
      return {'type': 'reviews', 'heading': '', 'lines': '', 'consent': false};
    case 'contact':
      return {'type': 'contact', 'heading': '', 'leadForm': true};
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

class _ExtraPageEditorScreenState extends State<ExtraPageEditorScreen> with WidgetsBindingObserver {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existing?['title'] ?? '');
  late final TextEditingController _seoCtrl =
      TextEditingController(text: widget.existing?['seoDesc'] ?? '');
  final List<_BlockEntry> _blocks = [];
  int _nextId = 0;

  bool _split = true;
  WebViewController? _pv;
  bool _pvLoading = true;
  Timer? _pvTimer;
  double _pvScrollY = 0;
  bool _keyboardWasOpen = false;

  int? _sel;
  final ScrollController _listCtrl = ScrollController();

  bool get _canSplit => widget.previewBuilder != null;

  @override
  void initState() {
    super.initState();
    if (_canSplit) {
      WidgetsBinding.instance.addObserver(this);
      _pv = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('FsBridge', onMessageReceived: (m) => _onBridge(m.message))
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (r) =>
                (!r.isMainFrame || r.url.startsWith('about:') || r.url.startsWith('data:'))
                    ? NavigationDecision.navigate
                    : NavigationDecision.prevent,
            onPageFinished: (_) async {
              if (_pvScrollY > 0) {
                try {
                  await _pv!.runJavaScript('window.scrollTo(0, $_pvScrollY);');
                } catch (_) {}
              }
              await _injectBridge();
              if (mounted) setState(() => _pvLoading = false);
            },
          ),
        );
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
    }
    final decoded = decodeExtraPageBlocks(widget.existing?['blocks'], allowed: widget.allowedBlockTypes);
    if (decoded.isNotEmpty) {
      for (final b in decoded) {
        _blocks.add(_BlockEntry(_nextId++, b));
      }
    } else {
      final legacy = (widget.existing?['content'] ?? '').trim();
      if (legacy.isNotEmpty) {
        _blocks.add(_BlockEntry(_nextId++, {'type': 'text', 'heading': '', 'body': legacy}));
      }
    }
  }

  @override
  void dispose() {
    _pvTimer?.cancel();
    if (_canSplit) WidgetsBinding.instance.removeObserver(this);
    _titleCtrl.dispose();
    _seoCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted || !_canSplit) return;
    final open = MediaQuery.of(context).viewInsets.bottom > 0;
    if (_keyboardWasOpen && !open) _schedulePreview();
    _keyboardWasOpen = open;
  }

  Future<void> _injectBridge() async {
    if (_pv == null) return;
    final sel = (_sel != null && _sel! < _blocks.length) ? _sel! : -1;
    final js = _kBridgeJs.replaceAll('__SEL__', '$sel').replaceAll('__LEN__', '${_blocks.length}').replaceAll('__ADD__', t(context, '+ Blok ekle').replaceAll("'", ' '));
    try {
      await _pv!.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _markSelected({bool scroll = false}) async {
    if (_pv == null) return;
    try {
      await _pv!.runJavaScript('window.__fsMark&&window.__fsMark(${_sel ?? -1},$scroll);');
    } catch (_) {}
  }

  void _onBridge(String msg) {
    if (!mounted) return;
    if (msg.startsWith('sel:')) {
      final i = int.tryParse(msg.substring(4));
      if (i != null && i >= 0 && i < _blocks.length) _select(i, scroll: false);
    } else if (msg.startsWith('add:')) {
      final i = int.tryParse(msg.substring(4));
      if (i != null) _addBlock(at: i);
    }
  }

  void _select(int? i, {bool scroll = true}) {
    FocusScope.of(context).unfocus();
    setState(() => _sel = i);
    if (_listCtrl.hasClients) _listCtrl.jumpTo(0);
    _markSelected(scroll: scroll && i != null);
  }

  int _insertIndex(int? at) {
    int idx = (at ?? _blocks.length).clamp(0, _blocks.length).toInt();
    if (idx == 0 && _blocks.isNotEmpty && _blocks.first.data['type'] == 'hero') idx = 1;
    return idx;
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final item = _blocks[oldIndex];
    if (item.data['type'] == 'hero') return;
    if (_blocks.first.data['type'] == 'hero' && newIndex == 0) newIndex = 1;
    setState(() {
      _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, item);
    });
    _schedulePreview();
  }

  void _schedulePreview() {
    if (!_canSplit || !_split) return;
    _pvTimer?.cancel();
    _pvTimer = Timer(const Duration(milliseconds: 500), _refreshPreview);
  }

  Future<void> _refreshPreview() async {
    if (!mounted || !_canSplit || !_split || _pv == null) return;
    final html = _previewHtmlOrNull();
    if (html == null) return;
    try {
      final y = await _pv!.runJavaScriptReturningResult('window.scrollY');
      _pvScrollY = double.tryParse(y.toString()) ?? 0;
    } catch (_) {
      _pvScrollY = 0;
    }
    if (!mounted) return;
    setState(() => _pvLoading = true);
    await _pv!.loadHtmlString(html);
  }

  String? _previewHtmlOrNull() {
    final builder = widget.previewBuilder;
    if (builder == null) return null;
    final title = _titleCtrl.text.trim().isEmpty ? 'Sayfa' : _titleCtrl.text.trim();
    final slug = widget.isHome
        ? 'index'
        : (widget.existing?['slug'] ?? slugifyPageTitle(title, widget.existingSlugs));
    try {
      return builder(title, slug, _blocks.map((e) => e.data).toList());
    } catch (_) {
      return null;
    }
  }

  Future<void> _addBlock({int? at}) async {
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
            for (final type in widget.allowedBlockTypes)
              if (!((type == 'hero' || type == 'contact') && _blocks.any((e) => e.data['type'] == type)))
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
    setState(() {
      final entry = _BlockEntry(_nextId++, _newBlock(type));
      final idx = type == 'hero' ? 0 : _insertIndex(at);
      _blocks.insert(idx, entry);
      if (_canSplit) _sel = idx;
    });
    if (_canSplit && _listCtrl.hasClients) _listCtrl.jumpTo(0);
    _schedulePreview();
  }

  void _deleteBlock(int index) {
    final removed = _blocks[index];
    setState(() {
      _blocks.removeAt(index);
      _sel = null;
    });
    _schedulePreview();
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
            _schedulePreview();
          },
        ),
      ),
    );
  }

  void _move(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= _blocks.length) return;
    if (_blocks[index].data['type'] == 'hero') return;
    if (to == 0 && _blocks.first.data['type'] == 'hero') return;
    setState(() {
      final item = _blocks.removeAt(index);
      _blocks.insert(to, item);
      if (_sel == index) _sel = to;
    });
    _schedulePreview();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (!widget.isHome && title.isEmpty) {
      showAppPopup(context, message: t(context, 'Sayfa başlığı gerekli.'), icon: '⚠️');
      return;
    }
    for (final e in _blocks) {
      final d = e.data;
      if (d['type'] == 'reviews' &&
          d['consent'] != true &&
          parseTestimonialLines((d['lines'] ?? '').toString()).isNotEmpty) {
        showAppPopup(
          context,
          message: t(context, 'Müşteri Yorumları alanına yazı girdin ama altındaki onay kutusunu işaretlemedin. Devam etmek için lütfen kutuyu işaretle.'),
          icon: '⚠️',
        );
        return;
      }
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
    final slug = widget.isHome
        ? 'index'
        : (widget.existing?['slug'] ?? slugifyPageTitle(title, widget.existingSlugs));
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pop<Map<String, String>>(context, <String, String>{
      'slug': slug,
      'title': title,
      'content': '',
      'blocks': encodeExtraPageBlocks(_blocks.map((e) => e.data).toList()),
      'seoDesc': _seoCtrl.text.trim(),
    });
  }

  void _preview() {
    if (widget.previewBuilder == null) return;
    FocusScope.of(context).unfocus();
    final html = _previewHtmlOrNull();
    if (html == null) {
      showAppPopup(context, message: t(context, 'Önizleme hazırlanamadı.'), icon: '⚠️');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HtmlDraftPreviewScreen(html: html)),
    );
  }

  Widget _splitPanel(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final h = MediaQuery.of(context).size.height * 0.34;
    return Offstage(
      offstage: !_split || keyboardOpen || _blocks.isEmpty,
      child: SizedBox(
        height: h,
        child: Stack(
          children: [
            WebViewWidget(controller: _pv!),
            if (_pvLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Row(
                children: [
                  _miniBtn(Icons.refresh, t(context, 'Yenile'), _refreshPreview),
                  const SizedBox(width: 6),
                  _miniBtn(Icons.fullscreen, t(context, 'Tam ekran'), _preview),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, String tip, VoidCallback onTap) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 20, color: Colors.white),
          onPressed: onTap,
        ),
      );

  List<Widget> _builderBody(BuildContext context) {
    if (_blocks.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline, size: 40, color: AppTheme.accentBlue),
              const SizedBox(height: 10),
              Text(t(context, 'Sayfan boş'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                t(context, 'Bir blok ekleyerek başla. Site adı, telefon ve tema sonra.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _addBlock,
                icon: const Icon(Icons.add),
                label: Text(t(context, 'Blok Ekle')),
              ),
            ],
          ),
        ),
      ];
    }
    final sel = _sel;
    if (sel != null && sel >= 0 && sel < _blocks.length) {
      final e = _blocks[sel];
      return [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _select(null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(t(context, 'Bloklar')),
            ),
            const Spacer(),
            Text(
              t(context, _labelFor((e.data['type'] ?? '').toString())),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        _BlockCard(
          key: ValueKey(e.id),
          data: e.data,
          onCommit: _schedulePreview,
          showAppearance: widget.allowedBlockTypes.contains('contact'),
          canUp: sel > 0,
          canDown: sel < _blocks.length - 1,
          onUp: () => _move(sel, -1),
          onDown: () => _move(sel, 1),
          onDelete: () => _deleteBlock(sel),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t(context, 'Sayfada bir bloğa dokun veya listeden seç. Sıralamak için tutup sürükle.'),
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
      ),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: _reorder,
        children: [
          for (var i = 0; i < _blocks.length; i++)
            ListTile(
              key: ValueKey('row_${_blocks[i].id}'),
              contentPadding: EdgeInsets.zero,
              leading: Text(_emojiFor((_blocks[i].data['type'] ?? '').toString()), style: const TextStyle(fontSize: 22)),
              title: Text(t(context, _labelFor((_blocks[i].data['type'] ?? '').toString()))),
              subtitle: _summaryOf(_blocks[i].data).isEmpty
                  ? null
                  : Text(_summaryOf(_blocks[i].data), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
              onTap: () => _select(i),
            ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _addBlock,
        icon: const Icon(Icons.add),
        label: Text(t(context, 'Blok Ekle')),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, widget.isHome
            ? 'Ana Sayfa'
            : (widget.existing == null ? 'Yeni Sayfa' : 'Sayfayı Düzenle'))),
        actions: [
          if (_canSplit)
            IconButton(
              tooltip: t(context, _split ? 'Canlı önizlemeyi gizle' : 'Canlı önizlemeyi göster'),
              icon: Icon(_split ? Icons.web_asset_off_outlined : Icons.web_asset_outlined),
              onPressed: () {
                setState(() => _split = !_split);
                if (_split) _refreshPreview();
              },
            ),
          if (_canSplit)
            IconButton(
              tooltip: t(context, 'Önizle'),
              icon: const Icon(Icons.visibility_outlined),
              onPressed: _preview,
            ),
          if (_canSplit)
            IconButton(
              tooltip: t(context, 'Kaydet'),
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_canSplit) ...[
              _splitPanel(context),
              if (_split && _blocks.isNotEmpty && MediaQuery.of(context).viewInsets.bottom == 0) const Divider(height: 1),
            ],
            Expanded(
              child: ListView(
          controller: _listCtrl,
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (!widget.isHome && !(_canSplit && _sel != null)) ...[
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: t(context, 'Sayfa başlığı (örn. Hakkımızda)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_canSplit)
              ..._builderBody(context)
            else ...[
            if (_blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  t(context, widget.isHome
                      ? 'Henüz blok yok. Aşağıdan kapak, yazı, görsel, galeri, çalışma saatleri, harita, yorumlar, iletişim, fiyat listesi, SSS veya buton ekleyerek ana sayfanı oluştur.'
                      : 'Henüz blok yok. Aşağıdan yazı, görsel, galeri, video, fiyat listesi, SSS veya buton ekleyerek sayfanı oluştur.'),
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
              ),
            for (var i = 0; i < _blocks.length; i++)
              _BlockCard(
                key: ValueKey(_blocks[i].id),
                data: _blocks[i].data,
                onCommit: _schedulePreview,
                showAppearance: widget.allowedBlockTypes.contains('contact'),
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
            ],
            const SizedBox(height: 12),
            if (!widget.isHome)
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
            if (widget.previewBuilder != null) ...[
              OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(t(context, 'Önizle')),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 12),
            ],
            PillButton(
              label: t(context, 'Kaydet'),
              borderColor: AppTheme.accentBlue,
              textColor: AppTheme.accentBlue,
              onTap: _save,
            ),
          ],
        ),
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

class _BlockCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool canUp;
  final bool canDown;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onDelete;
  final VoidCallback? onCommit;
  final bool showAppearance;

  const _BlockCard({
    super.key,
    required this.data,
    this.onCommit,
    this.showAppearance = false,
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

  late final RichTextEditingController _heading = RichTextEditingController(text: _s('heading'));
  late final RichTextEditingController _body = RichTextEditingController(text: _s('body'));
  late final TextEditingController _url = TextEditingController(text: _s('url'));
  late final TextEditingController _lines = TextEditingController(text: _s('lines'));
  late final TextEditingController _label = TextEditingController(text: _s('label'));
  late final RichTextEditingController _tagline = RichTextEditingController(text: _s('tagline'));
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
    _tagline.dispose();
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
    bool rich = false,
  }) {
    final deco = InputDecoration(
      labelText: t(context, label),
      hintText: hint == null ? null : t(context, hint),
      helperText: helper == null ? null : t(context, helper),
      helperMaxLines: 3,
      border: const OutlineInputBorder(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: rich
          ? RichTextField(
              controller: c,
              maxLines: maxLines,
              onChanged: onChanged,
              decoration: deco,
            )
          : TextField(
              controller: c,
              maxLines: maxLines,
              keyboardType: keyboardType,
              onChanged: onChanged,
              decoration: deco,
            ),
    );
  }

  Widget _headingField() => _field(
        _heading,
        'Başlık (opsiyonel)',
        (v) => d['heading'] = v,
        rich: true,
      );

  Widget _appearance() {
    const aligns = <List<String>>[
      ['', 'Otomatik'],
      ['left', 'Sola'],
      ['center', 'Ortala'],
      ['right', 'Sağa'],
    ];
    const tones = <List<String>>[
      ['', 'Varsayılan'],
      ['soft', 'Yumuşak'],
      ['accent', 'Vurgu rengi'],
      ['dark', 'Koyu'],
    ];
    final align = blockAlignOf(d);
    final tone = blockToneOf(d);
    Widget chips(List<List<String>> opts, String current, String key) => Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in opts)
              ChoiceChip(
                label: Text(t(context, o[1])),
                selected: current == o[0],
                onSelected: (_) {
                  setState(() {
                    if (o[0].isEmpty) {
                      d.remove(key);
                    } else {
                      d[key] = o[0];
                    }
                  });
                  widget.onCommit?.call();
                },
              ),
          ],
        );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        initiallyExpanded: align.isNotEmpty || tone.isNotEmpty || blockHasTextStyle(d),
        title: Text(
          t(context, 'Görünüm (renk, hizalama ve yazı stili)'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_type != 'hero') ...[
            Text(t(context, 'Hizalama'), style: const TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 4),
            chips(aligns, align, 'align'),
            const SizedBox(height: 10),
            Text(t(context, 'Zemin rengi'), style: const TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 4),
            chips(tones, tone, 'tone'),
            const SizedBox(height: 10),
          ],
          ..._textStyleControls(),
        ],
      ),
    );
  }

  Widget _muted(String s) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(s, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      );

  Widget _paletteRow(String key) {
    return StyleColorPicker(
      value: d[key]?.toString(),
      onChanged: (v) {
        setState(() {
          if (v == null) {
            d.remove(key);
          } else {
            d[key] = v;
          }
        });
        widget.onCommit?.call();
      },
    );
  }

  Widget _fontRow(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: StyleFontDropdown(
        label: t(context, label),
        value: d[key]?.toString(),
        onChanged: (v) {
          setState(() {
            if (v == null) {
              d.remove(key);
            } else {
              d[key] = v;
            }
          });
          widget.onCommit?.call();
        },
      ),
    );
  }

  Widget _sizeRow(String key) {
    const opts = <List<String>>[
      ['', 'Otomatik'],
      ['s', 'Küçük'],
      ['l', 'Büyük'],
      ['xl', 'Çok büyük'],
    ];
    final cur = (d[key] ?? '').toString();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final o in opts)
          ChoiceChip(
            label: Text(t(context, o[1])),
            selected: cur == o[0],
            onSelected: (_) {
              setState(() {
                if (o[0].isEmpty) {
                  d.remove(key);
                } else {
                  d[key] = o[0];
                }
              });
              widget.onCommit?.call();
            },
          ),
      ],
    );
  }

  Widget _flagChip(String key, String label) => FilterChip(
        label: Text(t(context, label)),
        selected: d[key] == true,
        onSelected: (v) {
          setState(() {
            if (v) {
              d[key] = true;
            } else {
              d.remove(key);
            }
          });
          widget.onCommit?.call();
        },
      );

  List<Widget> _textStyleControls() {
    return [
      _muted(t(context, 'Başlık rengi')),
      _paletteRow('hc'),
      _muted(t(context, 'Başlık boyutu')),
      _sizeRow('hs'),
      _fontRow('hf', '🔒 Başlık yazı tipi (Premium)'),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        _flagChip('hb', 'Başlık kalın'),
        _flagChip('hu', 'Başlığın altına çizgi'),
      ]),
      if (_type != 'hero') ...[
        _muted(t(context, 'Yazı rengi')),
        _paletteRow('tc'),
        _muted(t(context, 'Yazı boyutu')),
        _sizeRow('ts'),
        _fontRow('tf', '🔒 Yazı tipi (Premium)'),
        const SizedBox(height: 6),
        _flagChip('it', 'Yazı italik'),
      ] else ...[
        _muted(t(context, 'Slogan rengi')),
        _paletteRow('tc'),
        _muted(t(context, 'Slogan boyutu')),
        _sizeRow('ts'),
        _fontRow('tf', '🔒 Slogan yazı tipi (Premium)'),
      ],
    ];
  }

  List<Widget> _bodyWidgets() {
    switch (_type) {
      case 'hero':
        final heroAction = _s('action').isEmpty ? 'whatsapp' : _s('action');
        const heroActions = <List<String>>[
          ['whatsapp', 'WhatsApp'],
          ['call', 'Ara'],
          ['link', 'Link'],
          ['none', 'Buton yok'],
        ];
        return [
          _field(
            _heading,
            'Başlık (boşsa site adı yazılır)',
            (v) => d['heading'] = v,
            rich: true,
          ),
          _field(_tagline, 'Slogan (opsiyonel)', (v) => d['tagline'] = v, maxLines: 2, rich: true),
          GalleryPickerField(
            label: t(context, 'Kapak Görseli'),
            maxImages: 1,
            initialImages: _imgs(),
            onChanged: (v) {
              d['images'] = v;
              widget.onCommit?.call();
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final a in heroActions)
                ChoiceChip(
                  label: Text(t(context, a[1])),
                  selected: heroAction == a[0],
                  onSelected: (_) {
                    setState(() => d['action'] = a[0]);
                    widget.onCommit?.call();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (heroAction != 'none')
            _field(_label, 'Buton yazısı (boşsa varsayılan)', (v) => d['label'] = v, hint: 'Randevu Al'),
          if (heroAction == 'link')
            _field(
              _url,
              'Link',
              (v) => d['url'] = v,
              keyboardType: TextInputType.url,
              hint: 'https://ornek.com/randevu',
            ),
          if (heroAction == 'call' || heroAction == 'whatsapp')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t(
                  context,
                  heroAction == 'call'
                      ? 'Sitenin telefon numarası kullanılır.'
                      : 'Sitenin WhatsApp numarası kullanılır.',
                ),
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t(context, 'Kapağın düzeni (ortalı, bölünmüş vb.) formdaki "Hero düzeni" seçicisinden gelir.'),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
        ];
      case 'map':
        return [
          _headingField(),
          LocationPickerField(
            initialAddress: _s('address'),
            initialLat: (d['lat'] is num) ? (d['lat'] as num).toDouble() : 41.0082,
            initialLng: (d['lng'] is num) ? (d['lng'] as num).toDouble() : 28.9784,
            onChanged: (address, lat, lng) {
              final moved = d['lat'] != lat || d['lng'] != lng;
              d['address'] = address;
              d['lat'] = lat;
              d['lng'] = lng;
              if (moved) widget.onCommit?.call();
            },
          ),
        ];
      case 'reviews':
        return [
          _headingField(),
          _field(
            _lines,
            'Müşteri Yorumları (opsiyonel — her satıra bir tane: İsim | Yorum | Puan)',
            (v) => d['lines'] = v,
            maxLines: 6,
            hint: 'Ayşe K. | Harika hizmet, teşekkürler! | 5',
            helper: 'Puan (1-5) zorunlu değil. Yorumlar gerçek müşterilerine ait olmalı.',
          ),
          TestimonialConsentCheckbox(
            value: d['consent'] == true,
            onChanged: (v) {
              setState(() => d['consent'] = v);
              widget.onCommit?.call();
            },
          ),
        ];
      case 'contact':
        return [
          _headingField(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t(context, 'Talep formunu göster')),
            subtitle: Text(t(context, 'Ziyaretçiler isim ve telefon/e-posta bırakabilir (abonelikte açılır). Sitenin genel talep formu anahtarı kapalıysa burası da çıkmaz.')),
            value: d['leadForm'] != false,
            onChanged: (v) {
              setState(() => d['leadForm'] = v);
              widget.onCommit?.call();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              t(context, 'Butonlar sitenin telefon, WhatsApp, Instagram ve Google yorum bilgisinden gelir. Bu bloğu eklersen sayfa sonundaki otomatik iletişim bölümü kalkar; iletişim bu bloğun olduğu yerde çıkar.'),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
        ];
      case 'hours':
        return [
          _headingField(),
          WorkingHoursPickerField(
            initialHours: hoursOfBlock(d['hours']),
            onChanged: (v) {
              d['hours'] = v;
              widget.onCommit?.call();
            },
          ),
        ];
      case 'text':
        return [
          _headingField(),
          _field(
            _body,
            'Yazı',
            (v) => d['body'] = v,
            maxLines: 6,
            hint: 'Paragrafları boş satırla ayırabilirsin.',
            rich: true,
          ),
        ];
      case 'image':
        return [
          _headingField(),
          GalleryPickerField(
            label: t(context, 'Görsel'),
            maxImages: 1,
            initialImages: _imgs(),
            onChanged: (v) {
              d['images'] = v;
              widget.onCommit?.call();
            },
          ),
        ];
      case 'gallery':
        return [
          _headingField(),
          GalleryPickerField(
            label: t(context, 'Galeri'),
            initialImages: _imgs(),
            onChanged: (v) {
              d['images'] = v;
              widget.onCommit?.call();
            },
            showStyleOption: true,
            initialStyle: _s('style').isEmpty ? 'grid' : _s('style'),
            onStyleChanged: (v) {
              d['style'] = v;
              widget.onCommit?.call();
            },
          ),
        ];
      case 'video':
        return [
          _headingField(),
          VideoLinkField(
            urlController: _url,
            orientation: _s('orientation') == 'portrait' ? 'portrait' : 'landscape',
            onOrientationChanged: (v) {
              setState(() => d['orientation'] = v);
              widget.onCommit?.call();
            },
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
                  onSelected: (_) {
                    setState(() => d['action'] = a[0]);
                    widget.onCommit?.call();
                  },
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
            if (widget.showAppearance) _appearance(),
          ],
        ),
      ),
    );
  }
}
