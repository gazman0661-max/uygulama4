import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../free/ai_edit_sheet.dart';
import '../free/free_block_editor.dart';
import '../free/free_extra_blocks.dart';
import '../free/free_canvas.dart';
import '../free/free_color_picker.dart';
import '../free/free_live_page.dart';
import '../free/free_model.dart';
import '../free/free_section_preview.dart';
import '../free/free_size_stepper.dart';
import '../free/free_social.dart';
import '../free/free_templates.dart';
import '../free/free_theme.dart';
import '../localization/app_strings.dart';
import '../models/site_project.dart';
import '../services/free_draft_service.dart';
import '../services/free_plan_page_limit_service.dart';
import '../services/free_plan_restriction_service.dart';
import '../services/image_compress_service.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../templates/html/free_builder_html_generator.dart';
import '../widgets/app_popup.dart';
import '../widgets/report_dialog.dart';
import '../services/report_service.dart' show ReportSource;
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
  const FreeBuilderScreen({super.key, this.initialData, this.isEditing = false, this.aiReportContext});
  final Map<String, dynamic>? initialData;

  /// AI ile üretilen sitelerde dolu gelir: AppBar'da "içeriği bildir" butonu görünür
  /// (Google Play yapay zekâ içeriği şartı). İçerik, bildirime bağlam olarak eklenir.
  final String? aiReportContext;
  final bool isEditing;

  @override
  State<FreeBuilderScreen> createState() => _FreeBuilderScreenState();
}

class _FreeBuilderScreenState extends State<FreeBuilderScreen> with WidgetsBindingObserver {
  late FreeSite site = FreeSite.fromFormData(widget.initialData) ?? _newSite(isEnglish(context));
  int cur = 0;
  String? selId; // seçili öğe
  bool? _mobileOverride;
  bool saving = false;
  late bool _editing = widget.isEditing; // ilk kayıttan sonra true: tekrar kaydedince AYNI projeyi günceller
  int _propTab = 0; // alt panel sekmesi: 0 içerik, 1 boyut, 2 stil

  /// Son kaydedilen/yüklenen sitenin imzası. Çıkışta mevcut imzayla karşılaştırılır:
  /// fark varsa "kaydedilmemiş değişiklik" uyarısı çıkar. İmza SADECE çıkış/kayıt anında
  /// hesaplanır (resimler base64 olduğu için her build'de hesaplamak ağır olurdu).
  String _savedSig = '';

  String _sig() => jsonEncode(site.toJson());
  bool get _hasUnsaved => _sig() != _savedSig;

  // ------------------------------------------------------------ taslak koruması
  // Kaydedilmemiş iş cihazda dosya olarak tutulur (FreeDraftService). Uygulama kapanır /
  // sistem tarafından öldürülürse editör bir sonraki açılışta "kaldığın yerden devam" önerir.
  // Yazma: değişiklikten 3 sn sonra (debounce) + uygulama arka plana giderken HEMEN.

  Timer? _draftTimer;
  String _lastDraftSig = '';
  // Geri yükleme kararı verilene kadar otomatik kayıt KAPALI: yoksa boş yeni site, eski taslağı ezerdi.
  bool _draftReady = false;

  /// Yeni site: 'new', AI ile üretilen yeni site: 'ai_new', mevcut proje: 'p_<id>'.
  String get _draftKey {
    if (_editing) return 'p_${context.read<AppState>().qtCurrentProjectId ?? 'x'}';
    return widget.aiReportContext != null ? 'ai_new' : 'new';
  }

  @override
  void initState() {
    super.initState();
    _savedSig = _sig();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDraft());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _flushDraft();
    }
  }

  void _scheduleDraft() {
    if (!_draftReady || saving) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 3), _flushDraft);
  }

  Future<void> _flushDraft() async {
    _draftTimer?.cancel();
    if (!_draftReady || saving || !mounted) return;
    final key = _draftKey;
    final sig = _sig();
    if (sig == _savedSig) {
      // Kayıtlı hâlle aynı: taslağa gerek yok.
      if (_lastDraftSig.isNotEmpty) await FreeDraftService.clear(key);
      _lastDraftSig = '';
      return;
    }
    if (sig == _lastDraftSig) return;
    _lastDraftSig = sig;
    await FreeDraftService.save(key, sig);
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    _lastDraftSig = '';
    await FreeDraftService.clear(_draftKey);
  }

  Future<void> _checkDraft() async {
    final key = _draftKey;
    // AI ile yeni üretilen site: eski bir taslağı önermek kafa karıştırır; sil ve başla.
    if (widget.aiReportContext != null && !_editing) {
      await FreeDraftService.clear(key);
      if (mounted) _draftReady = true;
      return;
    }
    final draft = await FreeDraftService.load(key);
    if (!mounted) return;
    if (draft == null) {
      _draftReady = true;
      return;
    }
    final draftSite = FreeSite.fromJson(draft.site);
    final draftSig = jsonEncode(draftSite.toJson());
    if (draftSig == _savedSig) {
      await FreeDraftService.clear(key);
      if (mounted) _draftReady = true;
      return;
    }
    final en = isEnglish(context);
    final d = draft.savedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final when = '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(_tr('Kaydedilmemiş çalışman bulundu')),
        content: Text(en
            ? 'Your last unsaved work ($when) was found. Do you want to continue from where you left off?'
            : 'Son kaydedilmemiş çalışman ($when) bulundu. Kaldığın yerden devam etmek ister misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr('Sil ve baştan başla'), style: const TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_tr('Devam et'))),
        ],
      ),
    );
    if (!mounted) return;
    if (restore == true) {
      setState(() {
        site = draftSite;
        cur = 0;
        selId = null;
      });
      _lastDraftSig = draftSig;
    } else {
      await FreeDraftService.clear(key);
    }
    _draftReady = true;
  }

  /// Sistem geri tuşu / AppBar geri oku: değişiklik varsa onay ister, yoksa doğrudan çıkar.
  Future<void> _onBack() async {
    if (saving) return;
    if (!_hasUnsaved) {
      await _clearDraft();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr('Kaydedilmemiş değişiklikler var')),
        content: Text(_tr('Şimdi çıkarsan yaptığın değişiklikler kaybolur. Kaydetmek için önce sağ üstteki düğmeye bas.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr('Düzenlemeye devam et'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr('Kaydetmeden çık'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (leave == true) {
      await _clearDraft();
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Yeni site: site dili uygulama diliyle başlar; yer tutucu metinler o dilde gelir.
  static FreeSite _newSite(bool en) {
    final tx = FreeTexts(en);
    final s = FreeSite(name: tx.siteName, lang: en ? 'en' : 'tr');
    s.pages.first.name = tx.homeName;
    s.pages.first.setSections([_heroSection(tx), FreeSection(id: newFreeId(), kind: 'contact')]);
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

  /// Sayfanın tek tuvali (tüm öğeler burada).
  FreeSection get pc => page.canvas;

  FreeElement? get _selEl {
    if (selId == null) return null;
    for (final e in pc.els) {
      if (e.id == selId) return e;
    }
    return null;
  }

  void _changed() => setState(() {});

  /// "AI ile düzenle" geri alma yığını (en fazla 3 adım; site JSON anlık görüntüsü).
  final List<String> _aiUndo = [];

  Future<void> _aiEdit() async {
    final res = await showAiEditSheet(context, site: site, pageIndex: cur, canAddPage: _pageLimitAllowsAnother);
    if (res == null || !mounted) return;
    _aiUndo.add(jsonEncode(site.toJson()));
    if (_aiUndo.length > 3) _aiUndo.removeAt(0);
    final addedPage = res.pages.length > site.pages.length;
    setState(() {
      site = res;
      selId = null;
      if (addedPage) {
        cur = site.pages.length - 1; // AI'ın eklediği yeni sayfaya geç
      } else if (cur >= site.pages.length) {
        cur = 0;
      }
    });
  }

  void _aiUndoLast() {
    if (_aiUndo.isEmpty) return;
    final s = _aiUndo.removeLast();
    setState(() {
      site = FreeSite.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
      selId = null;
      if (cur >= site.pages.length) cur = 0;
    });
  }

  String _tr(String s) => t(context, s);

  // ---------------------------------------------------------------- ekleme

  int _bottomRow() {
    var bottom = 0;
    for (final x in pc.els) {
      if (x.type == FType.band) continue;
      if (x.r + x.h > bottom) bottom = x.r + x.h;
    }
    return bottom;
  }

  /// Hazır blok (galeri/video/hizmet/SSS) veya iletişim: tuvale ÖĞE olarak eklenir.
  void _addBlockElement(FType type, [String? blockType]) {
    if (type == FType.contact && pc.els.any((x) => x.type == FType.contact)) {
      showAppPopup(context, message: _tr('Bu sayfada zaten bir İletişim bölümü var.'));
      return;
    }
    final block = <String, dynamic>{};
    var h = kContactDefaultRows;
    if (type == FType.block) {
      block['type'] = blockType;
      if (blockType == 'gallery') block['style'] = 'grid';
      h = kBlockDefaultRows[blockType] ?? kExtraBlockRows[blockType] ?? 40;
    }
    final e = FreeElement(
      id: newFreeId(),
      type: type,
      c: 0,
      w: kCols,
      r: pc.els.isEmpty ? 0 : _bottomRow() + 1,
      h: h,
      block: block,
    );
    _giveManualOrder(e);
    setState(() {
      pc.els.add(e);
      selId = e.id;
    });
    if (type == FType.block) _editBlock(e);
  }

  /// Hazır yerleşim (hero, resim+yazı, kutular, çağrı bandı): tuvalin altına eklenir.
  void _addPreset(String id) {
    setState(() {
      page.appendSections([buildFreeSectionPreset(id, lang: site.lang)]);
      if (pc.manualOrder) {
        // Mobil sıra elle düzenlenmişse yeni öğeler sona eklensin.
        var m = 0;
        for (final x in pc.els) {
          if (x.mo != null && x.mo! > m) m = x.mo!;
        }
        for (final x in pc.els) {
          if (x.type != FType.band && x.mo == null) x.mo = ++m;
        }
      }
      selId = null;
    });
  }

  /// Mobil sıra elle düzenlenmişse (tüm öğelerde [mo] var) yeni öğe sona eklenir;
  /// aksi halde sıra zaten konumdan türetilir.
  void _giveManualOrder(FreeElement e) {
    if (e.type == FType.band || !pc.manualOrder) return;
    var m = 0;
    for (final x in pc.els) {
      if (x.mo != null && x.mo! > m) m = x.mo!;
    }
    e.mo = m + 1;
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
    if (e.type == FType.band) {
      e.c = 0;
      e.w = kCols;
      e.r = 0;
    } else {
      e.c = ((kCols - e.w) / 2).floor();
      e.r = s.els.isEmpty ? 1 : _bottomRow() + 1;
      _giveManualOrder(e);
    }
    setState(() {
      s.els.add(e);
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

  /// Blok öğesinin geçici bölüm görünümü: [block] haritası AYNI nesnedir, bu yüzden
  /// blok editörünün yaptığı değişiklik doğrudan öğeye yazılır.
  FreeSection _tempSec(FreeElement e) => FreeSection(
        id: e.id,
        kind: e.type == FType.contact ? 'contact' : 'block',
        bg: e.bg,
        fs: e.fs,
        tc: e.color,
        block: e.block,
      );

  void _editBlock(FreeElement e) {
    final others = page.imageCount - _blockImages(e);
    final left = kMaxImagesPerPage - others;
    showFreeBlockEditor(
      context,
      section: _tempSec(e),
      maxImages: left < 0 ? 0 : left,
      onChanged: _changed,
    );
  }

  int _blockImages(FreeElement e) {
    final imgs = e.block['images'];
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
    if (p.canvas.els.isNotEmpty) {
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
      p.setSections(buildFreeTemplate(id, lang: site.lang));
      selId = null;
    });
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

  /// Her zaman görünen ekleme çubuğu: öğeler, şerit, hazır bloklar, hazır yerleşim.
  Widget _addBar() {
    final items = <List<dynamic>>[
      [FType.title, Icons.title, 'Başlık', null],
      [FType.text, Icons.notes, 'Yazı', null],
      [FType.button, Icons.smart_button, 'Buton', null],
      [FType.image, Icons.image_outlined, 'Resim', null],
      [FType.shape, Icons.crop_square, 'Şekil', null],
      [FType.social, Icons.share, 'Sosyal', null],
      [FType.band, Icons.view_stream_outlined, 'Arka plan şeridi', null],
      [FType.block, Icons.photo_library_outlined, 'Galeri', 'gallery'],
      [FType.block, Icons.play_circle_outline, 'Video', 'video'],
      [FType.block, Icons.list_alt, 'Hizmet listesi', 'services'],
      [FType.block, Icons.help_outline, 'SSS', 'faq'],
      [FType.block, Icons.map_outlined, 'Harita', 'map'],
      for (final k in kExtraBlockTypes) [FType.block, kExtraBlockIcons[k], kExtraBlockTitles[k], k],
      [FType.contact, Icons.contact_phone_outlined, 'İletişim', null],
    ];
    return SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: ActionChip(
            avatar: const Icon(Icons.dashboard_customize_outlined, size: 16),
            label: Text(_tr('Hazır yerleşim')),
            onPressed: _addSectionMenu,
          ),
        ),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: ActionChip(
              avatar: Icon(it[1] as IconData, size: 16),
              label: Text(_tr(it[2] as String)),
              onPressed: () {
                final type = it[0] as FType;
                if (type == FType.block || type == FType.contact) {
                  _addBlockElement(type, it[3] as String?);
                } else {
                  _addElement(pc, type);
                }
              },
            ),
          ),
      ]),
    );
  }

  /// Blok / iletişim öğesinin editördeki önizlemesi (tıklamayı yutmaz, kutuya sığmazsa kırpılır).
  Widget _specialPreview(FreeElement e) => IgnorePointer(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: FreeSectionPreview(
              section: _tempSec(e),
              site: site,
              theme: theme,
              premium: context.read<AppState>().qtCurrentIsPremium,
            ),
          ),
        ),
      );

  /// Mobil görünümde geometri düzenleniyor mu? (ayrı mobil düzen açık + mobil görünüm)
  bool get _mobGeo => isMobile && page.mobileCustom;

  /// Mobil düzeni masaüstünden yeniden üretir (mobil konum/boyut/yazı boyutları silinir).
  Future<void> _resetMobileLayout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(_tr('Mobil düzen masaüstü düzeninden yeniden oluşturulsun mu? Mobilde yaptığın elle yerleşim silinir.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr('İptal'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_tr('Tamam'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      for (final x in pc.els) {
        x.mc = null;
        x.mr = null;
        x.mw = null;
        x.mh = null;
        x.mfs = 0;
      }
      page.ensureMobileGeometry();
    });
  }

  Widget _editor() {
    // Ayrı mobil düzen açıkken sonradan eklenen öğelere mobil konum ver.
    if (page.mobileCustom) page.ensureMobileGeometry();
    return ListView(padding: const EdgeInsets.only(bottom: 160), children: [
        if (isMobile)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.view_agenda_outlined, size: 18),
                  label: Text(_tr('Otomatik sıra')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.phone_android, size: 18),
                  label: Text(_tr('Ayrı mobil düzen')),
                ),
              ],
              selected: {page.mobileCustom},
              onSelectionChanged: (v) => setState(() {
                final on = v.first;
                if (on) page.ensureMobileGeometry();
                page.mobileCustom = on;
              }),
            ),
          ),
        if (_mobGeo)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetMobileLayout,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: Text(_tr('Masaüstünden yeniden oluştur')),
              ),
            ),
          ),
        if (isMobile && !page.mobileCustom && pc.manualOrder)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  for (final x in pc.els) {
                    x.mo = null;
                  }
                }),
                icon: const Icon(Icons.sort, size: 16),
                label: Text(_tr('Konuma göre sırala')),
              ),
            ),
          ),
        FreeCanvas(
          section: pc,
          theme: theme,
          mobile: isMobile,
          mobileCustom: page.mobileCustom,
          selId: selId,
          onSelect: (id) => setState(() => selId = id),
          onChanged: _changed,
          specialBuilder: _specialPreview,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            _mobGeo
                ? _tr('Ayrı mobil düzen: öğeleri telefonda göründüğü gibi istediğin yere sürükle; masaüstü düzeni değişmez. Galeri/SSS gibi kutular içerik kadar uzar; kesin görünüm için Canlı Önizleme.')
                : isMobile
                    ? _tr('Mobil düzen: öğeler alt alta dizilir; uzun basıp sürükleyerek sırayı değiştir. Arka plan şeritlerini masaüstü düzeninde düzenle.')
                    : _tr('Her şeyi istediğin yere sürükle. Galeri/video/hizmet/SSS/iletişim kutularında içerik yüksekliği aşarsa kutuyu uzat; kesin görünüm için Canlı Önizleme.'),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ]);
  }

  /// Hazır yerleşimler: tuvalin altına eklenir (sonra her öğe serbestçe taşınır/silinir).
  Future<void> _addSectionMenu() async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(_tr('Hazır yerleşimler'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
            ),
            for (final p in kFreeSectionPresets)
              ListTile(
                leading: Text(p.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(_tr(p.title)),
                onTap: () => Navigator.pop(context, p.id),
              ),
          ]),
        ),
      ),
    );
    if (pick != null) _addPreset(pick);
  }

  void _deleteElement(FreeSection s, FreeElement e) {
    setState(() {
      s.els.removeWhere((x) => x.id == e.id);
      selId = null;
    });
  }

  /// Katman sırası: listede sonraki = üstte. Şeritler zaten hep en arkada.
  void _reorderZ(FreeSection s, FreeElement e, {required bool front}) {
    setState(() {
      s.els.removeWhere((x) => x.id == e.id);
      if (front) {
        s.els.add(e);
      } else {
        s.els.insert(0, e);
      }
    });
  }

  /// Resim öğesine (yeni ya da boş) fotoğraf seç / değiştir.
  Future<void> _pickElementImage(FreeElement e) async {
    final had = (e.img ?? '').isNotEmpty;
    if (!had && _imageBlocked()) return;
    final data = await _pickImage();
    if (data == null || !mounted) return;
    setState(() => e.img = data);
  }

  // ---------------------------------------------------------------- seçili öğe paneli

  Widget? _propsPanel() {
    final e = _selEl;
    final s = pc;
    if (e == null) return null;
    final hasText = e.type == FType.title || e.type == FType.text || e.type == FType.button;
    final isBand = e.type == FType.band;
    final isSpecial = e.type == FType.block || e.type == FType.contact;
    final m = _mobGeo; // ayrı mobil düzende mobil konum/boyut düzenleniyor
    final hasContent = hasText || e.type == FType.image || e.type == FType.social || isSpecial;
    final tabs = <int, String>{
      if (hasContent) 0: 'İçerik',
      1: 'Boyut',
      2: 'Stil',
    };
    final tab = tabs.containsKey(_propTab) ? _propTab : tabs.keys.first;

    Widget body;
    if (tab == 0) {
      body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
        if (e.type == FType.block)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _editBlock(e),
              icon: const Icon(Icons.edit, size: 18),
              label: Text(_tr('İçeriği düzenle')),
            ),
          ),
        if (e.type == FType.contact) ...[
          Text(
            _tr('Telefon, WhatsApp ve Instagram bilgileri Site ayarlarından gelir.'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(_tr('Site ayarları')),
            ),
          ),
        ],
        if (e.type == FType.image) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _pickElementImage(e),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text((e.img ?? '').isEmpty ? _tr('Resim seç') : _tr('Resmi değiştir')),
            ),
          ),
        ],
        if (e.type == FType.button || e.type == FType.social) ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('l${e.id}'),
            initialValue: e.link == '#' ? '' : e.link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(isDense: true, labelText: _tr('Bağlantı'), border: const OutlineInputBorder()),
            onChanged: (v) => setState(() => e.link = v.trim().isEmpty ? '#' : v.trim()),
          ),
        ],
      ]);
    } else if (tab == 1) {
      body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!isBand)
          FreeIntStepper(
            label: _tr('Genişlik'),
            value: e.wOn(m),
            min: 1,
            max: kCols - e.cOn(m),
            format: (v) => '$v / $kCols',
            onChanged: (v) => setState(() => e.setW(m, v)),
          ),
        FreeIntStepper(
          label: _tr('Yükseklik'),
          value: e.hOn(m),
          min: 1,
          max: 300,
          format: (v) => '${v * kRow.toInt()} px',
          onChanged: (v) => setState(() => e.setH(m, v)),
        ),
        FreeIntStepper(
          label: _tr('Yukarıdan'),
          value: e.rOn(m),
          min: 0,
          max: 1000,
          format: (v) => '${v * kRow.toInt()} px',
          onChanged: (v) => setState(() => e.setR(m, v)),
        ),
        if (!isBand)
          FreeIntStepper(
            label: _tr('Soldan'),
            value: e.cOn(m),
            min: 0,
            max: kCols - e.wOn(m),
            format: (v) => '$v / $kCols',
            onChanged: (v) => setState(() => e.setC(m, v)),
          ),
        if (isMobile && !m)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              _tr('Genişlik masaüstü düzeninde geçerlidir; mobilde tam genişlik görünür.'),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            if (!isBand) ...[
              ActionChip(
                avatar: const Icon(Icons.swap_horiz, size: 16),
                label: Text(_tr('Tam genişlik')),
                onPressed: () => setState(() {
                  e.setC(m, 0);
                  e.setW(m, kCols);
                }),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.format_align_center, size: 16),
                label: Text(_tr('Ortala')),
                onPressed: () => setState(() => e.setC(m, ((kCols - e.wOn(m)) / 2).floor())),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.flip_to_front, size: 16),
                label: Text(_tr('Öne getir')),
                onPressed: () => _reorderZ(s, e, front: true),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.flip_to_back, size: 16),
                label: Text(_tr('Arkaya gönder')),
                onPressed: () => _reorderZ(s, e, front: false),
              ),
            ],
          ]),
        ),
        if (isSpecial) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text(_tr('Yazı boyutu'), style: const TextStyle(fontSize: 12)),
              FreeSizeStepper(
                value: e.fs,
                autoPreview: 16,
                min: kMinSectionPx,
                max: kMaxSectionPx,
                allowAuto: true,
                onChanged: (v) => setState(() => e.fs = v),
              ),
            ]),
          ),
        ],
        if (hasText) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text(m ? _tr('Mobil yazı boyutu') : _tr('Yazı boyutu'), style: const TextStyle(fontSize: 12)),
              if (m)
                // 0 = "Otomatik": masaüstüyle aynı boyut.
                FreeSizeStepper(
                  value: e.mfs,
                  autoPreview: e.fontPx,
                  allowAuto: true,
                  min: e.type == FType.title ? kMinTitlePx : kMinTextPx,
                  max: e.type == FType.title ? kMaxTitlePx : kMaxTextPx,
                  onChanged: (v) => setState(() => e.mfs = v),
                )
              else
                FreeSizeStepper(
                  value: e.fs,
                  autoPreview: e.fontPx,
                  min: e.type == FType.title ? kMinTitlePx : kMinTextPx,
                  max: e.type == FType.title ? kMaxTitlePx : kMaxTextPx,
                  onChanged: (v) => setState(() => e.fs = v),
                ),
            ]),
          ),
        ],
      ]);
    } else {
      body = SingleChildScrollView(
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
          if (isBand)
            FreeColorChip(label: _tr('Renk'), value: e.bg, onChanged: (v) => setState(() => e.bg = v)),
          if (isSpecial) ...[
            FreeColorChip(label: _tr('Yazı rengi'), value: e.color, onChanged: (v) => setState(() => e.color = v)),
            FreeColorChip(label: _tr('Arka plan'), value: e.bg, onChanged: (v) => setState(() => e.bg = v)),
          ],
          if (e.type != FType.contact)
          IconButton(
            tooltip: _tr('Çoğalt'),
            icon: const Icon(Icons.copy),
            onPressed: () {
              if ((e.type == FType.image || e.type == FType.block) && _imageBlocked()) return;
              final j = FreeElement.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>)
                ..id = newFreeId()
                ..r += 1
                ..mo = null;
              if (j.hasMobileGeo) j.mr = j.mr! + 1;
              _giveManualOrder(j);
              setState(() {
                s.els.add(j);
                selId = j.id;
              });
            },
          ),
        ]),
      );
    }

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 0),
              child: Row(children: [
                for (final entry in tabs.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_tr(entry.value)),
                      selected: tab == entry.key,
                      onSelected: (_) => setState(() => _propTab = entry.key),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: _tr('Sil'),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteElement(s, e),
                ),
                IconButton(
                  tooltip: _tr('Kapat'),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => setState(() => selId = null),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: body,
              ),
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

  /// Canlı Önizleme AYRI sayfa olarak açılır: geri tuşu önizlemeyi kapatıp bu editöre,
  /// kaldığın yerden döner (editör yok edilmez). Önizlemedeki tema değişikliği tüm siteye
  /// uygulanır ve [site] aynı nesne olduğu için editöre de yansır.
  Future<void> _openLive() async {
    final premium = context.read<AppState>().qtCurrentIsPremium;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FreeLivePage(
        site: site,
        startFile: freePageFiles(site.pages)[cur],
        premium: premium,
        onSiteChanged: () {
          if (mounted) setState(() {});
        },
      ),
    ));
    if (mounted) setState(() {});
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
    final wasMulti = _editing && appState.qtSiteMode == SiteMode.multi;
    final multi = site.pages.length > 1 || wasMulti;
    bool ok;
    if (multi) {
      ok = await LocalGenerationHelper.generateMultiPage(
        context: context,
        projectNameHint: site.name,
        kind: ProjectKind.freeBuilder,
        formData: formData,
        isEditing: _editing,
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
        isEditing: _editing,
        selectedThemeId: site.themeId,
        selectedFontPackageId: site.fontPackageId,
        buildHtml: () => generateFreeBuilderSite(site).values.first,
      );
    }
    if (mounted) setState(() => saving = false);
    if (ok) {
      _savedSig = _sig();
      // Kayıt başarılı: bu çalışmanın taslağı artık gereksiz (anahtar _editing değişmeden ÖNCE silinir).
      await _clearDraft();
    }
    if (ok && mounted) {
      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        // Önizlemeye PUSH edilir (replace değil): önizlemede geri tuşu bu editöre,
        // kaldığın yerden döner. İlk kayıttan sonra proje oluştuğu için sonraki kayıtlar
        // yeni proje açmaz, AYNI projeyi günceller.
        _editing = true;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()));
        if (!mounted) return;
        // Önizlemedeki "Düzenle" başka bir editör örneğinde kayıt yapmış olabilir:
        // en güncel kaydı yükle ki eski bir hâl üzerine yazılmasın.
        final latest = FreeSite.fromFormData(context.read<AppState>().qtFormData);
        if (latest != null) {
          setState(() {
            site = latest;
            if (cur >= site.pages.length) cur = 0;
            selId = null;
          });
          _savedSig = _sig();
        }
      }
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    _scheduleDraft(); // her yeniden çizimde sayaç sıfırlanır; 3 sn sakinlikte taslak yazılır
    final panel = _propsPanel();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(site.name.isEmpty ? _tr('Sıfırdan Site') : site.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.aiReportContext != null)
            IconButton(
              tooltip: _tr('Bu içeriği bildir'),
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => showReportDialog(
                context: context,
                source: ReportSource.preview,
                chatContext: '[AI ile üretildi]\n${widget.aiReportContext}',
              ),
            ),
          if (_aiUndo.isNotEmpty)
            IconButton(tooltip: _tr('AI değişikliğini geri al'), icon: const Icon(Icons.undo), onPressed: _aiUndoLast),
          IconButton(tooltip: _tr('AI ile düzenle'), icon: const Icon(Icons.auto_awesome), onPressed: _aiEdit),
          IconButton(
            tooltip: _tr('Canlı önizleme'),
            icon: const Icon(Icons.visibility_outlined),
            onPressed: _openLive,
          ),
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
      body: Column(children: [
        _pageBar(),
        _addBar(),
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
      ),
    );
  }
}
