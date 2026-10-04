import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../free/free_block_editor.dart';
import '../free/free_canvas.dart';
import '../free/free_color_picker.dart';
import '../free/free_live_preview.dart';
import '../free/free_model.dart';
import '../free/free_section_preview.dart';
import '../free/free_size_stepper.dart';
import '../free/free_social.dart';
import '../free/free_templates.dart';
import '../free/free_theme.dart';
import '../localization/app_strings.dart';
import '../models/site_project.dart';
import '../services/free_plan_page_limit_service.dart';
import '../services/free_plan_restriction_service.dart';
import '../services/image_compress_service.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../templates/html/free_builder_html_generator.dart';
import '../widgets/app_popup.dart';
import '../widgets/premium_locked_popup.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import 'preview_screen.dart';

/// 02.10.2026 eklendi — "Sıfırdan Site Oluştur".
///
/// Sayfalar BÖLÜMLERDEN oluşur:
///   • Boş Alan  : serbest sürükle-bırak tuval (yazı, başlık, buton, resim, şekil, sosyal ikon)
///   • Galeri / Video / Hizmet Listesi / SSS : hazır bölümler (Sitora blok üreticileri)
///   • İletişim  : butonlar + talep formu (formu ücretsizde yayından düşer)
///
/// Tema/font/yoğunluk diğer sektörlerle AYNI seçicilerden gelir ve çıktı
/// wrapPageHtml içinden geçer. Kayıt: LocalGenerationHelper -> AppState
/// (Projelerim, rozet, kısıtlar, yayın hattı otomatik).
class FreeBuilderScreen extends StatefulWidget {
  const FreeBuilderScreen({super.key, this.initialData, this.isEditing = false});
  final Map<String, dynamic>? initialData;
  final bool isEditing;

  @override
  State<FreeBuilderScreen> createState() => _FreeBuilderScreenState();
}

class _FreeBuilderScreenState extends State<FreeBuilderScreen> {
  late FreeSite site = FreeSite.fromFormData(widget.initialData) ?? _newSite(isEnglish(context));
  int cur = 0;
  String? selId; // seçili öğe
  String? selSec; // seçili bölüm (canvas)
  bool? _mobileOverride;
  bool live = false;
  bool saving = false;

  /// Yeni site: site dili uygulama diliyle başlar; yer tutucu metinler o dilde gelir.
  static FreeSite _newSite(bool en) {
    final tx = FreeTexts(en);
    final s = FreeSite(name: tx.siteName, lang: en ? 'en' : 'tr');
    s.pages.first.name = tx.homeName;
    s.pages.first.sections.add(_heroSection(tx));
    s.pages.first.sections.add(FreeSection(id: newFreeId(), kind: 'contact'));
    return s;
  }

  static FreeSection _heroSection(FreeTexts tx) => FreeSection(id: newFreeId(), kind: 'canvas', els: [
        FreeElement(id: newFreeId(), type: FType.title, c: 4, r: 2, w: 40, h: 6, text: tx.heroTitle, size: 2),
        FreeElement(id: newFreeId(), type: FType.text, c: 6, r: 9, w: 36, h: 6, text: tx.heroText),
        FreeElement(id: newFreeId(), type: FType.button, c: 16, r: 17, w: 16, h: 5, text: tx.callButton),
      ]);

  FreePage get page => site.pages[cur];
  bool get isMobile => _mobileOverride ?? (MediaQuery.of(context).size.width < 700);
  FreeTheme get theme => FreeTheme.of(site);

  FreeSection? get _selSection {
    for (final s in page.sections) {
      if (s.id == selSec) return s;
    }
    return null;
  }

  FreeElement? get _selEl {
    final s = _selSection;
    if (s == null) return null;
    for (final e in s.els) {
      if (e.id == selId) return e;
    }
    return null;
  }

  void _changed() => setState(() {});

  String _tr(String s) => t(context, s);

  // ---------------------------------------------------------------- ekleme

  void _addSection(String kind, [String? blockType]) {
    setState(() {
      switch (kind) {
        case 'canvas':
          page.sections.add(FreeSection(id: newFreeId(), kind: 'canvas'));
          break;
        case 'contact':
          if (page.sections.any((s) => s.isContact)) {
            showAppPopup(context, message: _tr('Bu sayfada zaten bir İletişim bölümü var.'));
            return;
          }
          page.sections.add(FreeSection(id: newFreeId(), kind: 'contact'));
          break;
        default:
          final block = <String, dynamic>{'type': blockType};
          if (blockType == 'gallery') block['style'] = 'grid';
          page.sections.add(FreeSection(id: newFreeId(), kind: 'block', block: block));
      }
    });
    final s = page.sections.last;
    if (s.isBlock) {
      _editBlock(s);
    } else if (s.isCanvas) {
      setState(() => selSec = s.id);
    }
  }

  void _addElement(FreeSection s, FType type) async {
    if (type == FType.social) {
      final p = await showModalBottomSheet<SocialPlatform>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final pf in SocialPlatform.values)
              ListTile(title: Text(FreeSocial.labelFor(pf)), onTap: () => Navigator.pop(context, pf)),
          ]),
        ),
      );
      if (p == null || !mounted) return;
      final link = await _ask(_tr('Bağlantı'), FreeSocial.defaultLinkFor(p));
      if (link == null) return;
      _insert(s, FreeElement(id: newFreeId(), type: type, w: 8, h: 8, platform: p.name, link: link));
      return;
    }
    if (type == FType.image) {
      if (_imageBlocked()) return;
      final data = await _pickImage();
      if (data == null || !mounted) return;
      _insert(s, FreeElement(id: newFreeId(), type: type, w: 20, h: 18, img: data, text: ''));
      return;
    }
    final tx = FreeTexts.of(site.lang);
    final defaults = <FType, List<Object>>{
      FType.title: [tx.title, 24, 5],
      FType.text: [tx.text, 24, 6],
      FType.button: [tx.button, 14, 5],
      FType.shape: ['', 16, 8],
    };
    final d = defaults[type]!;
    _insert(
      s,
      FreeElement(
        id: newFreeId(),
        type: type,
        w: d[1] as int,
        h: d[2] as int,
        text: d[0] as String,
        size: type == FType.title ? 1 : 1,
      ),
    );
  }

  void _insert(FreeSection s, FreeElement e) {
    var bottom = 0;
    for (final x in s.els) {
      if (x.r + x.h > bottom) bottom = x.r + x.h;
    }
    e.c = ((kCols - e.w) / 2).floor();
    e.r = s.els.isEmpty ? 1 : bottom + 1;
    setState(() {
      s.els.add(e);
      selSec = s.id;
      selId = e.id;
    });
  }

  bool _imageBlocked() {
    if (page.imageCount >= kMaxImagesPerPage) {
      showAppPopup(
        context,
        message: t(context, 'Bir sayfaya en fazla 14 görsel eklenebilir. Yayın boyut sınırı nedeniyle bir görseli silip tekrar dene.'),
        icon: '⚠️',
      );
      return true;
    }
    return false;
  }

  /// Seçilen görseli Sitora'nın ortak sıkıştırıcısıyla WebP'ye çevirip data URI döner.
  Future<String?> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (f == null) return null;
    final raw = await f.readAsBytes();
    final c = await ImageCompressService.compress(
      raw,
      isPng: f.name.toLowerCase().endsWith('.png'),
      maxWidth: 1000,
      quality: 75,
    );
    return 'data:${c.mime};base64,${base64Encode(c.bytes)}';
  }

  Future<String?> _ask(String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('İptal'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(_tr('Tamam'))),
        ],
      ),
    );
  }

  void _editBlock(FreeSection s) {
    final others = page.imageCount - _blockImages(s);
    final left = kMaxImagesPerPage - others;
    showFreeBlockEditor(
      context,
      section: s,
      maxImages: left < 0 ? 0 : left,
      onChanged: _changed,
    );
  }

  int _blockImages(FreeSection s) {
    final imgs = s.block['images'];
    return imgs is List ? imgs.length : 0;
  }

  // ---------------------------------------------------------------- sayfalar

  /// Sayfa limiti kontrolü EKLERKEN yapılır (kayıtta değil) — kullanıcı emek
  /// verdikten sonra "kilitli" uyarısı görmesin. Kural, kayıttaki kapıyla
  /// (LocalGenerationHelper.generateMultiPage) BİREBİR aynıdır.
  Future<bool> _pageLimitAllowsAnother() async {
    final appState = context.read<AppState>();
    final gateProject = widget.isEditing ? appState.qtCurrentProject : null;
    final tier = appState.subscriptionTierForPageGate(gateProject);
    final en = isEnglish(context);
    if (!FreePlanPageLimitService.canUseMultiPage(gateProject, tier: tier)) {
      await showPremiumLockedPopup(
        context,
        message: FreePlanPageLimitService.lockedMessage(en, alwaysMultiPage: false),
      );
      return false;
    }
    final max = FreePlanPageLimitService.maxTotalPagesFor(gateProject, tier: tier);
    if (site.pages.length >= max) {
      await showPremiumLockedPopup(
        context,
        message: FreePlanPageLimitService.tooManyPagesMessage(en, max, tier: tier),
      );
      return false;
    }
    return true;
  }

  Future<void> _addPage() async {
    if (!await _pageLimitAllowsAnother() || !mounted) return;
    final name = await _ask(_tr('Yeni sayfa adı'), '');
    if (name == null || name.isEmpty) return;
    setState(() {
      site.pages.add(FreePage(name, sections: [
        FreeSection(id: newFreeId(), kind: 'canvas', els: [
          FreeElement(id: newFreeId(), type: FType.title, c: 4, r: 2, w: 40, h: 6, text: name, size: 2),
        ]),
        FreeSection(id: newFreeId(), kind: 'contact'),
      ]));
      cur = site.pages.length - 1;
      selId = null;
      selSec = null;
    });
  }

  Future<void> _pageMenu(int i) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit), title: Text(_tr('Yeniden adlandır')), onTap: () => Navigator.pop(context, 'rename')),
          ListTile(leading: const Icon(Icons.search), title: Text(_tr('Google açıklaması (SEO)')), onTap: () => Navigator.pop(context, 'seo')),
          ListTile(leading: const Icon(Icons.dashboard_customize_outlined), title: Text(_tr('Şablon uygula')), onTap: () => Navigator.pop(context, 'template')),
          if (i > 0)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(_tr('Sayfayı sil')),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
        ]),
      ),
    );
    if (act == null || !mounted) return;
    final p = site.pages[i];
    if (act == 'rename') {
      final n = await _ask(_tr('Sayfa adı'), p.name);
      if (n != null && n.isNotEmpty) setState(() => p.name = n);
    } else if (act == 'template') {
      await _applyTemplate(p);
    } else if (act == 'seo') {
      final n = await _ask(_tr('Google açıklaması (SEO)'), p.desc);
      if (n != null) setState(() => p.desc = n);
    } else if (act == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isEnglish(context) ? 'Delete "${p.name}"?' : '"${p.name}" silinsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr('İptal'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_tr('Sil'))),
          ],
        ),
      );
      if (ok == true) {
        setState(() {
          site.pages.removeAt(i);
          cur = 0;
          selId = null;
          selSec = null;
        });
      }
    }
  }

  /// Seçilen şablon, sayfanın MEVCUT bölümlerinin yerine geçer (onaylı).
  Future<void> _applyTemplate(FreePage p) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final tpl in kFreeTemplates)
            ListTile(
              leading: Text(tpl.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(_tr(tpl.title)),
              subtitle: Text(_tr(tpl.subtitle)),
              onTap: () => Navigator.pop(context, tpl.id),
            ),
        ]),
      ),
    );
    if (id == null || !mounted) return;
    if (p.sections.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_tr('Sayfadaki mevcut bölümler şablonla değiştirilsin mi?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr('İptal'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_tr('Değiştir'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      p.sections = buildFreeTemplate(id, lang: site.lang);
      selId = null;
      selSec = null;
    });
  }

  // ---------------------------------------------------------------- bölüm işlemleri

  void _moveSection(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= page.sections.length) return;
    setState(() {
      final s = page.sections.removeAt(i);
      page.sections.insert(j, s);
    });
  }

  Future<void> _deleteSection(int i) async {
    final s = page.sections[i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr('Bu bölüm silinsin mi?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr('İptal'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_tr('Sil'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      page.sections.removeAt(i);
      if (selSec == s.id) {
        selSec = null;
        selId = null;
      }
    });
  }

  Future<void> _sectionBg(FreeSection s) async {
    final v = await showFreeColorPicker(context, initial: s.bg, title: _tr('Bölüm arka planı'));
    if (v != null) setState(() => s.bg = v);
  }

  /// Hazır bölümler (galeri/video/hizmet/SSS/iletişim) için yazı boyutu + rengi.
  /// Serbest alanda bu ayarlar her öğenin kendi alt panelindedir.
  Future<void> _sectionText(FreeSection s) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_tr('Bölüm yazısı'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              _tr('Yazı boyutu gövde metni içindir; başlık otomatik daha büyük olur.'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FreeSizeStepper(
                value: s.fs,
                autoPreview: 16,
                min: kMinSectionPx,
                max: kMaxSectionPx,
                allowAuto: true,
                onChanged: (v) {
                  set(() => s.fs = v);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FreeColorChip(
                label: _tr('Yazı rengi'),
                value: s.tc,
                onChanged: (v) {
                  set(() => s.tc = v);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('Tamam'))),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- UI parçaları

  String get _sizeInfo {
    final mb = page.embeddedBytes / (1024 * 1024);
    return '${page.imageCount}/$kMaxImagesPerPage ${_tr('görsel')} · ${mb.toStringAsFixed(1)} / 8 MB';
  }

  Color get _sizeColor {
    final r = page.embeddedBytes / kPageFileLimitBytes;
    if (r > 1) return Colors.redAccent;
    if (r > 0.75) return Colors.orange;
    return Colors.grey;
  }

  Widget _pageBar() => SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (var i = 0; i < site.pages.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: GestureDetector(
                  onLongPress: () => _pageMenu(i),
                  child: ChoiceChip(
                    label: Text(site.pages[i].name),
                    selected: cur == i,
                    onSelected: (_) => setState(() {
                      cur = i;
                      selId = null;
                      selSec = null;
                    }),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(_tr('Sayfa')), onPressed: _addPage),
            ),
            IconButton(
              tooltip: _tr('Sayfa ayarları'),
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _pageMenu(cur),
            ),
          ],
        ),
      );

  Widget _sectionHeader(int i, FreeSection s) {
    String label;
    if (s.isCanvas) {
      label = _tr('Serbest alan');
    } else if (s.isContact) {
      label = _tr('İletişim');
    } else {
      switch (s.blockType) {
        case 'gallery':
          label = _tr('Galeri');
          break;
        case 'video':
          label = _tr('Video');
          break;
        case 'services':
          label = _tr('Hizmet listesi');
          break;
        default:
          label = _tr('SSS');
      }
    }
    return Container(
      color: Colors.black.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        if (s.isBlock)
          TextButton.icon(
            onPressed: () => _editBlock(s),
            icon: const Icon(Icons.edit, size: 16),
            label: Text(_tr('Düzenle')),
          ),
        if (!s.isCanvas)
          IconButton(
            tooltip: _tr('Bölüm yazısı'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.format_size, size: 18),
            onPressed: () => _sectionText(s),
          ),
        IconButton(
          tooltip: _tr('Bölüm arka planı'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.palette_outlined, size: 18),
          onPressed: () => _sectionBg(s),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_upward, size: 18),
          onPressed: i == 0 ? null : () => _moveSection(i, -1),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_downward, size: 18),
          onPressed: i == page.sections.length - 1 ? null : () => _moveSection(i, 1),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
          onPressed: () => _deleteSection(i),
        ),
      ]),
    );
  }

  Widget _addElementBar(FreeSection s) {
    final items = <List<dynamic>>[
      [FType.title, Icons.title, 'Başlık'],
      [FType.text, Icons.notes, 'Yazı'],
      [FType.button, Icons.smart_button, 'Buton'],
      [FType.image, Icons.image_outlined, 'Resim'],
      [FType.shape, Icons.crop_square, 'Şekil'],
      [FType.social, Icons.share, 'Sosyal'],
    ];
    return SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: ActionChip(
              avatar: Icon(it[1] as IconData, size: 16),
              label: Text(_tr(it[2] as String)),
              onPressed: () => _addElement(s, it[0] as FType),
            ),
          ),
      ]),
    );
  }

  Widget _sectionBody(FreeSection s) {
    if (s.isCanvas) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FreeCanvas(
          section: s,
          theme: theme,
          mobile: isMobile,
          selId: selSec == s.id ? selId : null,
          onSelect: (id) => setState(() {
            selSec = s.id;
            selId = id;
          }),
          onChanged: _changed,
        ),
        if (selSec == s.id) _addElementBar(s),
      ]);
    }
    return GestureDetector(
      onTap: s.isBlock ? () => _editBlock(s) : null,
      child: FreeSectionPreview(
        section: s,
        site: site,
        theme: theme,
        premium: context.read<AppState>().qtCurrentIsPremium,
      ),
    );
  }

  Widget _editor() => ListView(padding: const EdgeInsets.only(bottom: 140), children: [
        for (var i = 0; i < page.sections.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sectionHeader(i, page.sections[i]),
              _sectionBody(page.sections[i]),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: _addSectionMenu,
            icon: const Icon(Icons.add),
            label: Text(_tr('Bölüm ekle')),
          ),
        ),
      ]);

  Future<void> _addSectionMenu() async {
    final items = <List<String>>[
      ['canvas', '', 'Serbest alan (sürükle-bırak)'],
      ['block', 'gallery', 'Galeri (ızgara, slayt, bento...)'],
      ['block', 'video', 'Video'],
      ['block', 'services', 'Hizmet ve fiyat listesi'],
      ['block', 'faq', 'Sık sorulan sorular'],
      ['contact', '', 'İletişim + talep formu'],
    ];
    final pick = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final it in items)
            ListTile(title: Text(_tr(it[2])), onTap: () => Navigator.pop(context, it)),
        ]),
      ),
    );
    if (pick != null) _addSection(pick[0], pick[1].isEmpty ? null : pick[1]);
  }

  // ---------------------------------------------------------------- seçili öğe paneli

  Widget? _propsPanel() {
    final e = _selEl;
    final s = _selSection;
    if (e == null || s == null || live) return null;
    final hasText = e.type == FType.title || e.type == FType.text || e.type == FType.button;
    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (hasText || e.type == FType.image)
              TextFormField(
                key: ValueKey('t${e.id}'),
                initialValue: e.text,
                maxLines: e.type == FType.text ? 4 : 1,
                minLines: 1,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: e.type == FType.image ? _tr('Resim açıklaması (alt metin)') : _tr('Metin'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => e.text = v),
              ),
            if (e.type == FType.button || e.type == FType.social) ...[
              const SizedBox(height: 6),
              TextFormField(
                key: ValueKey('l${e.id}'),
                initialValue: e.link == '#' ? '' : e.link,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(isDense: true, labelText: _tr('Bağlantı'), border: const OutlineInputBorder()),
                onChanged: (v) => setState(() => e.link = v.trim().isEmpty ? '#' : v.trim()),
              ),
            ],
            if (hasText) ...[
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: FreeSizeStepper(
                  value: e.fs,
                  autoPreview: e.fontPx,
                  min: e.type == FType.title ? kMinTitlePx : kMinTextPx,
                  max: e.type == FType.title ? kMaxTitlePx : kMaxTextPx,
                  onChanged: (v) => setState(() => e.fs = v == 0 ? 0 : v),
                ),
              ),
            ],
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                if (hasText) ...[
                  _segmentIcons(
                    const [Icons.format_align_left, Icons.format_align_center, Icons.format_align_right],
                    e.align,
                    (v) => setState(() => e.align = v),
                  ),
                  const SizedBox(width: 8),
                ],
                if (e.type == FType.title || e.type == FType.text)
                  FreeColorChip(label: _tr('Yazı rengi'), value: e.color, onChanged: (v) => setState(() => e.color = v)),
                if (e.type == FType.button) ...[
                  FreeColorChip(label: _tr('Yazı rengi'), value: e.color, onChanged: (v) => setState(() => e.color = v)),
                  FreeColorChip(label: _tr('Dolgu'), value: e.bg, onChanged: (v) => setState(() => e.bg = v)),
                ],
                if (e.type == FType.shape)
                  FreeColorChip(label: _tr('Dolgu'), value: e.bg, onChanged: (v) => setState(() => e.bg = v)),
                IconButton(
                  tooltip: _tr('Çoğalt'),
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    if (e.type == FType.image && _imageBlocked()) return;
                    final j = FreeElement.fromJson(e.toJson())
                      ..id = newFreeId()
                      ..r += 1
                      ..mo = null;
                    setState(() {
                      s.els.add(j);
                      selId = j.id;
                    });
                  },
                ),
                IconButton(
                  tooltip: _tr('Sil'),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    s.els.removeWhere((x) => x.id == e.id);
                    selId = null;
                  }),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _segmentIcons(List<IconData> icons, int value, ValueChanged<int> onTap) => ToggleButtons(
        isSelected: [for (var i = 0; i < icons.length; i++) i == value],
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        onPressed: onTap,
        children: [for (final i in icons) Icon(i, size: 18)],
      );

  // ---------------------------------------------------------------- ayarlar

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_tr('Site ayarları'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _settingField(_tr('Site adı'), site.name, (v) => site.name = v),
            _settingField(_tr('Telefon'), site.phone, (v) => site.phone = v, type: TextInputType.phone),
            _settingField(_tr('WhatsApp (905xxxxxxxxx)'), site.whatsapp, (v) => site.whatsapp = v, type: TextInputType.phone),
            _settingField('Instagram', site.instagram, (v) => site.instagram = v),
            Row(children: [
              Text(_tr('Site dili')),
              const SizedBox(width: 12),
              StatefulBuilder(
                builder: (c, set) => SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'tr', label: Text('TR')), ButtonSegment(value: 'en', label: Text('EN'))],
                  selected: {site.lang},
                  onSelectionChanged: (s) {
                    set(() => site.lang = s.first);
                    setState(() {});
                  },
                ),
              ),
            ]),
            const SizedBox(height: 16),
            ThemePickerField(
              initialThemeId: site.themeId,
              initialCustomTheme: site.customTheme,
              onChanged: (v) => setState(() => site.themeId = v),
              onCustomThemeChanged: (v) => setState(() => site.customTheme = v),
            ),
            const SizedBox(height: 16),
            TypographyPickerField(
              initialFontPackageId: site.fontPackageId,
              initialCustomFontPackage: site.customFontPackage,
              initialDensity: site.density,
              onFontPackageChanged: (v) => setState(() => site.fontPackageId = v),
              onCustomFontPackageChanged: (v) => setState(() => site.customFontPackage = v),
              onDensityChanged: (v) => setState(() => site.density = v),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('Tamam'))),
          ]),
        ),
      ),
    );
  }

  Widget _settingField(String label, String value, ValueChanged<String> onChanged, {TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          initialValue: value,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
        ),
      );

  // ---------------------------------------------------------------- canlı önizleme

  Map<String, String>? _liveFiles;
  int _liveKey = 0;

  void _toggleLive() {
    if (live) {
      setState(() => live = false);
      return;
    }
    try {
      final premium = context.read<AppState>().qtCurrentIsPremium;
      final files = FreePlanRestrictionService.runGeneration(premium, () => generateFreeBuilderSite(site));
      setState(() {
        _liveFiles = files;
        _liveKey++;
        live = true;
        selId = null;
      });
    } catch (e) {
      showAppPopup(context, message: '${_tr('Önizleme hazırlanamadı')}: $e', icon: '⚠️');
    }
  }

  // ---------------------------------------------------------------- kaydet

  Future<void> _save() async {
    if (saving) return;
    for (final p in site.pages) {
      if (p.embeddedBytes > kPageFileLimitBytes) {
        showAppPopup(
          context,
          message: isEnglish(context)
              ? 'The images on "${p.name}" exceed the 8 MB limit. Delete some images and try again.'
              : '"${p.name}" sayfasındaki görseller 8 MB sınırını aşıyor. Bazı görselleri silip tekrar dene.',
          icon: '⚠️',
        );
        return;
      }
    }
    setState(() => saving = true);
    final appState = context.read<AppState>();
    final formData = site.toFormData();
    final wasMulti = widget.isEditing && appState.qtSiteMode == SiteMode.multi;
    final multi = site.pages.length > 1 || wasMulti;
    bool ok;
    if (multi) {
      ok = await LocalGenerationHelper.generateMultiPage(
        context: context,
        projectNameHint: site.name,
        kind: ProjectKind.freeBuilder,
        formData: formData,
        isEditing: widget.isEditing,
        selectedThemeId: site.themeId,
        selectedFontPackageId: site.fontPackageId,
        buildFiles: () => generateFreeBuilderSite(site),
      );
    } else {
      ok = await LocalGenerationHelper.generateSinglePage(
        context: context,
        projectNameHint: site.name,
        kind: ProjectKind.freeBuilder,
        formData: formData,
        isEditing: widget.isEditing,
        selectedThemeId: site.themeId,
        selectedFontPackageId: site.fontPackageId,
        buildHtml: () => generateFreeBuilderSite(site).values.first,
      );
    }
    if (mounted) setState(() => saving = false);
    if (ok && mounted) {
      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()));
      }
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final panel = _propsPanel();
    return Scaffold(
      appBar: AppBar(
        title: Text(site.name.isEmpty ? _tr('Sıfırdan Site') : site.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: live ? _tr('Düzenlemeye dön') : _tr('Canlı önizleme'),
            icon: Icon(live ? Icons.edit : Icons.visibility_outlined),
            onPressed: _toggleLive,
          ),
          if (!live)
            IconButton(
              tooltip: isMobile ? _tr('Masaüstü düzeni') : _tr('Mobil düzen'),
              icon: Icon(isMobile ? Icons.desktop_windows_outlined : Icons.phone_android),
              onPressed: () => setState(() => _mobileOverride = !isMobile),
            ),
          IconButton(tooltip: _tr('Ayarlar'), icon: const Icon(Icons.tune), onPressed: _openSettings),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: saving ? null : _save,
              child: Text(saving
                  ? _tr('Oluşturuluyor...')
                  : (widget.isEditing ? _tr('Düzenlemeyi Bitir') : _tr('Siteyi Oluştur'))),
            ),
          ),
        ],
      ),
      body: live && _liveFiles != null
          ? FreeLivePreview(
              key: ValueKey(_liveKey),
              files: _liveFiles!,
              startFile: freePageFiles(site.pages)[cur],
            )
          : Column(children: [
              _pageBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(_sizeInfo, style: TextStyle(fontSize: 11, color: _sizeColor)),
                ),
              ),
              Expanded(child: _editor()),
            ]),
      bottomSheet: panel,
    );
  }
}
