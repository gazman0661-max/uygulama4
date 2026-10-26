import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../models/game_theme.dart';
import '../models/mb_story.dart';
import '../models/mb_tutorial.dart';
import '../models/merge_board.dart';
import '../services/analytics_service.dart';
import '../services/log_service.dart';
import '../services/game_fx.dart';
import '../services/merge_board_service.dart';
import '../services/review_service.dart';
import '../utils/duration_format.dart';
import '../widgets/energy_bar.dart';
import '../widgets/story_scene.dart';
import '../widgets/tutorial_coach.dart';
import '../widgets/ui_kit.dart';
import 'level_map_screen.dart';
import 'merge_map_screen.dart';

/// MOD 2: klasik merge tahtasi. Ureteci dokun -> obje cikar, ayni seviyeleri
/// surukleyip birlestir, siparis kartina birakip teslim et.
/// Mantik: models/merge_board.dart, durum/kayit: services/merge_board_service.dart.
const List<GameTheme> kMbThemes = [
  FastFoodTheme(),
  CafeTheme(),
  MagicTheme(),
  PirateTheme(),
  IceTheme(),
  SpaceTheme(),
];

class MergeBoardScreen extends StatefulWidget {
  const MergeBoardScreen({super.key});

  @override
  State<MergeBoardScreen> createState() => _MergeBoardScreenState();
}

class _MergeBoardScreenState extends State<MergeBoardScreen> with WidgetsBindingObserver {
  final MergeBoardService _svc = MergeBoardService.instance;
  Timer? _tick;
  bool _ready = false;
  int? _dragFrom;
  // Siparis kartlari animasyonu: daha once gorulen siparisler (yeni gelen = giris animasyonu).
  final Set<MbOrder> _seenOrders = Set<MbOrder>.identity();
  bool _ordersInit = false;
  int _entryDelayMs = 0;
  // Uretec (sandik) animasyonu: ucustaki objenin hedef hucresi gizlenir, inince gorunur.
  final Set<int> _flying = <int>{};
  final Map<int, int> _landed = <int, int>{}; // hucre -> inen obje seviyesi (tekrar "pop" yapma)
  final List<int> _genTaps = <int>[0, 0, 0]; // uretici (slot) basina dokunus sayaci (sikisma animasyonu)

  // ── OGRETICI (v163): Mod 1'deki gibi goster-yaptir. Mantik: models/mb_tutorial.dart ──
  static const String _tutKey = 'mb_tut'; // GameProgress.tutSeen anahtari (bir kez gosterilir)
  final GlobalKey _stackKey = GlobalKey();
  bool _tutActive = false;
  bool _tutReplay = false; // "?" ile tekrar: bitince tutSeen yazilmaz
  bool _tutSpawned = false;
  bool _tutMerged = false;
  bool _tutDelivered = false;
  int _tutStartMs = 0;
  String? _tutNote;
  MbTutPlan? _plan;
  String _lastPlanSig = '';
  final List<GlobalKey> _cellKeys = List<GlobalKey>.generate(MbBoard.size, (_) => GlobalKey());
  final List<GlobalKey> _orderKeys = List<GlobalKey>.generate(MbBoard.orderSlots, (_) => GlobalKey());

  String _lt(String key, [List<Object?> args = const []]) => AppStrings.instance.lt(key, args);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.addListener(_onChange);
    AppLog.i('mod2', 'ekran initState (yukleme basliyor, servisYuklu=${_svc.loaded})');
    _svc.load().then((_) {
      if (!mounted) {
        AppLog.w('mod2', 'yukleme bitti ama ekran artik yok');
        return;
      }
      setState(() => _ready = true);
      _svc.sessionStart();
      // Sira: ONCE hikaye (acilis sahnesi), SONRA birlestirme/teslim ogreticisi.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _storyCheck();
        if (mounted) _tutInit();
      });
    });
    // Enerji sayaci icin saniyede bir yenile.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _ready) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _svc.removeListener(_onChange);
    _tick?.cancel();
    if (_tutActive) {
      final step = _plan?.kind.name ?? 'none';
      AppLog.i('mod2', 'OGRETICI yarida birakildi: adim=$step tekrar=$_tutReplay');
      AnalyticsService.instance.log('mb_tut_quit', {'step': step, 'replay': _tutReplay ? 1 : 0});
    }
    _svc.sessionEnd();
    _svc.flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    AppLog.i('mod2', 'yasam dongusu: ${s.name} enerji=${_svc.loaded ? _svc.state.energy : -1}');
    if (s == AppLifecycleState.inactive ||
        s == AppLifecycleState.paused ||
        s == AppLifecycleState.hidden ||
        s == AppLifecycleState.detached) {
      _svc.flush();
    }
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_tutActive) {
      // Hamleden sonra hucre konumlari bir kare sonra dogru okunur: el/halka kaymasin.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tutActive) setState(() {});
      });
    }
  }

  void _say(String msg) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: CoinText(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
      duration: const Duration(milliseconds: 1200),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3B2A6B),
    ));
  }

  // ── Hikaye ("Kayip Tarif Defteri") ──────────────────────────
  bool _storyBusy = false;

  /// Sirada gorulmemis hikaye sahnesi varsa gosterir (ogretici sirasinda beklemeye alinir).
  /// Cagri yerleri: ekran acilisi, ogretici bitisi/atlanisi, bolum bitti penceresinden sonra.
  Future<void> _storyCheck() async {
    if (_storyBusy || !mounted || !_ready || _tutActive) return;
    final gp = GameProgress.instance;
    bool seen(String id) => gp.tutSeen(MbStory.keyFor(id));
    final ch = _svc.board.chapter;
    final skips = MbStory.catchUpSkips(ch, seen);
    for (final id in skips) {
      gp.markTutSeen(MbStory.keyFor(id));
    }
    if (skips.isNotEmpty) AppLog.i('story', 'gecmis sahneler sessizce gorulmus sayildi: ${skips.join(",")} (bolum=$ch)');
    _storyBusy = true;
    try {
      while (mounted && !_tutActive) {
        final scene = MbStory.next(ch, seen);
        if (scene == null) break;
        // Once isaretle: geri tusu/coken durumunda ayni sahne tekrar tekrar cikmasin.
        gp.markTutSeen(scene.seenKey);
        AppLog.i('story', 'sahne basladi: ${scene.id} (bolum=$ch)');
        AnalyticsService.instance.log('story_scene', {'id': scene.id, 'chapter': ch});
        await showStoryScene(context, scene);
        AppLog.i('story', 'sahne bitti: ${scene.id}');
      }
    } finally {
      _storyBusy = false;
    }
  }

  // ── Ogretici ────────────────────────────────────────────────
  /// Ilk giriste: yeni oyuncuya rehber. Daha once ilerlemis oyuncuya (teslim/bolum var) gosterilmez.
  void _tutInit() {
    final gp = GameProgress.instance;
    if (gp.tutSeen(_tutKey)) return;
    final b = _svc.board;
    if (b.delivered > 0 || b.chapter > 1) {
      gp.markTutSeen(_tutKey);
      AppLog.i('mod2', 'ogretici atlandi: oyuncu zaten ilerlemis (teslim=${b.delivered} bolum=${b.chapter})');
      return;
    }
    _tutStart(replay: false);
  }

  void _tutStart({required bool replay}) {
    if (!mounted) return;
    setState(() {
      _tutActive = true;
      _tutReplay = replay;
      _tutSpawned = false;
      _tutMerged = false;
      _tutDelivered = false;
      _tutNote = null;
      _lastPlanSig = '';
      _tutStartMs = DateTime.now().millisecondsSinceEpoch;
    });
    AppLog.i('mod2', 'OGRETICI basladi (tekrar=$replay) ${_svc.ordersText()}');
    AnalyticsService.instance.log(replay ? 'mb_tut_replay' : 'mb_tut_start');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tutActive) setState(() {});
    });
  }

  void _tutFinish() {
    final secs = ((DateTime.now().millisecondsSinceEpoch - _tutStartMs) / 1000).round();
    final replay = _tutReplay;
    _tutActive = false;
    _plan = null;
    if (!replay) GameProgress.instance.markTutSeen(_tutKey);
    AppLog.i('mod2', 'OGRETICI TAMAMLANDI: sure=${secs}s tekrar=$replay uret=$_tutSpawned birlesme=$_tutMerged');
    AnalyticsService.instance.log(replay ? 'mb_tut_replay_done' : 'mb_tut_done', {'secs': secs});
    final first = _lt('Awesome! Orders pay coins 🪙');
    final second = _lt('Energy ⚡ refills over time');
    setState(() => _tutNote = first);
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && _tutNote == first) setState(() => _tutNote = second);
    });
    Future<void>.delayed(const Duration(milliseconds: 5400), () {
      if (mounted && _tutNote == second) setState(() => _tutNote = null);
    });
    // Ogretici bitince (ipucu notlari kapandiktan sonra) hikaye acilisi.
    // Hikaye bittikten sonra: Mod 1 (Firlat) ogreticisine yonlendirme teklifi.
    if (!replay) {
      Future<void>.delayed(const Duration(milliseconds: 6200), () async {
        if (!mounted) return;
        await _storyCheck();
        await _offerMod1();
      });
    }
  }

  /// Mod 2 ogreticisi bitince (bitirme/atlama): yeni oyuncuyu Mod 1'e (Firlat) goturur.
  /// Mod 1'in kendi rehberi (harita > Bolge 1 > Bolum 1 + Bolum 1 ogreticisi) orada devreye girer.
  /// Yalnizca bir kez teklif edilir; Mod 1'i zaten oynamis oyuncuya gosterilmez.
  static const String _mod1OfferKey = 'mb_mod1_offer';

  Future<void> _offerMod1() async {
    final gp = GameProgress.instance;
    if (!mounted || _tutActive || _storyBusy) return;
    if (!gp.needsFirstRunGuide || gp.tutSeen(_mod1OfferKey)) return;
    gp.markTutSeen(_mod1OfferKey);
    AppLog.i('mod2', 'Mod 1 yonlendirme teklifi gosterildi');
    AnalyticsService.instance.log('mb_mod1_offer');
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => GameAlertDialog(
        title: Text(_lt('🎯 Now try Throw mode!'), textAlign: TextAlign.center),
        content: Text(
          _lt('Throw items onto the table and clear the chapter. We\'ll show you how, step by step!'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_lt('Let\'s go!'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_lt('Later'))),
        ],
      ),
    );
    AnalyticsService.instance.log('mb_mod1_offer_choice', {'go': go == true ? 1 : 0});
    if (go == true && mounted) {
      GameFx.instance.uiTap();
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LevelMapScreen()));
    }
  }

  void _tutSkip() {
    GameFx.instance.uiTap();
    final step = _plan?.kind.name ?? 'none';
    AppLog.i('mod2', 'OGRETICI ATLANDI: adim=$step tekrar=$_tutReplay');
    AnalyticsService.instance.log('mb_tut_skip', {'step': step, 'replay': _tutReplay ? 1 : 0});
    if (!_tutReplay) GameProgress.instance.markTutSeen(_tutKey);
    setState(() {
      _tutActive = false;
      _plan = null;
    });
    if (!_tutReplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _storyCheck();
        await _offerMod1();
      });
    }
  }

  Future<void> _openHowTo() async {
    GameFx.instance.uiTap();
    AppLog.i('mod2', 'nasil oynanir penceresi acildi');
    AnalyticsService.instance.log('mb_howto_open');
    final theme = kMbThemes[_svc.worldIndex];
    final imgs = [for (var i = 1; i <= 3; i++) theme.byLevel(i).imagePath];
    final steps = _lt('Tap the chest to get items.\nDrag two items of the same level together to merge them.\nTap an item (or drop it on an order card) to deliver it.')
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final go = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => GameAlertDialog(
        title: Text(_lt('How to play'), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MergeChainHint(images: imgs),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++) _MbStepRow(n: i + 1, text: steps[i]),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_lt('Show me'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_lt('Close'))),
        ],
      ),
    );
    AppLog.i('mod2', 'nasil oynanir secimi: ${go == true ? "goster" : "kapat"}');
    if (go == true && mounted) _tutStart(replay: true);
  }

  /// Hucre/kart merkezi, ust Stack'in yerel koordinatinda.
  Offset? _tutLocal(GlobalKey k) {
    final r = _rectOf(k);
    if (r == null) return null;
    final box = _stackKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached) return box.globalToLocal(r.center);
    return r.center;
  }

  Widget _skipChip() {
    return GestureDetector(
      onTap: _tutSkip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white54),
        ),
        child: Text(_lt('Skip'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }

  /// Katman: el + halka + balon. Hepsi gorsel; dokunusu engellemez (yalniz "Gec" dugmesi tiklanir).
  List<Widget> _tutOverlay() {
    final plan = _plan;
    final out = <Widget>[];
    final mq = MediaQuery.of(context);

    if (_tutNote != null && !_tutActive) {
      out.add(Positioned(
        left: 0,
        right: 0,
        top: mq.padding.top + 190,
        child: IgnorePointer(child: Center(child: CoachBubble(text: _tutNote!, fontSize: 18))),
      ));
    }
    if (!_tutActive || plan == null) return out;

    String text;
    var above = true; // balon hedefin ustunde mi (ok asagi) ya da altinda mi (ok yukari)
    double? anchorY; // balonun baglandigi y (yerel)
    var targetD = 50.0;

    switch (plan.kind) {
      case MbTutKind.spawn:
        final g = _svc.board.genCell < 0 ? -1 : MbWorlds.producerCells[plan.slot.clamp(0, MbWorlds.producerCells.length - 1).toInt()];
        final c = g >= 0 ? _tutLocal(_cellKeys[g]) : null;
        if (c == null) return out;
        targetD = (_rectOf(_cellKeys[g])?.width ?? 50) * 0.95;
        out.add(PulseRing(key: ValueKey('r1-${plan.sig}'), center: c, diameter: targetD));
        text = _lt('Tap the chest!');
        above = c.dy > mq.size.height * 0.42;
        anchorY = c.dy;
        break;
      case MbTutKind.merge:
        final a = _tutLocal(_cellKeys[plan.a]);
        final b = _tutLocal(_cellKeys[plan.b]);
        if (a == null || b == null) return out;
        targetD = (_rectOf(_cellKeys[plan.a])?.width ?? 50) * 0.95;
        out.add(PulseRing(key: ValueKey('r1-${plan.sig}'), center: a, diameter: targetD));
        out.add(PulseRing(key: ValueKey('r2-${plan.sig}'), center: b, diameter: targetD));
        out.add(CoachHand(key: ValueKey('h-${plan.sig}'), from: a, to: b, visible: _dragFrom == null));
        text = _lt('Merge Lv{0} + Lv{0}!', [plan.level]);
        above = (a.dy + b.dy) / 2 > mq.size.height * 0.42;
        anchorY = above ? math.min(a.dy, b.dy) : math.max(a.dy, b.dy);
        break;
      case MbTutKind.deliver:
        final c = _tutLocal(_cellKeys[plan.a]);
        if (c == null) return out;
        targetD = (_rectOf(_cellKeys[plan.a])?.width ?? 50) * 0.95;
        out.add(PulseRing(key: ValueKey('r1-${plan.sig}'), center: c, diameter: targetD));
        if (plan.b >= 0 && plan.b < MbBoard.orderSlots) {
          final oc = _tutLocal(_orderKeys[plan.b]);
          final orect = _rectOf(_orderKeys[plan.b]);
          if (oc != null) {
            out.add(PulseRing(key: ValueKey('r2-${plan.sig}'), center: oc, diameter: (orect?.height ?? 90) * 0.9));
            out.add(CoachHand(key: ValueKey('h-${plan.sig}'), from: c, to: oc, visible: _dragFrom == null));
          }
        }
        text = _lt('Tap it, or drop it on the order!');
        above = c.dy > mq.size.height * 0.42;
        anchorY = c.dy;
        break;
    }

    final bubble = IgnorePointer(
      child: CoachBubble(text: text, arrow: above ? CoachArrow.down : CoachArrow.up, fontSize: 18),
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: above ? [_skipChip(), const SizedBox(height: 6), bubble] : [bubble, const SizedBox(height: 6), _skipChip()],
    );
    final raw = above ? anchorY! - targetD * 0.5 - 118 : anchorY! + targetD * 0.5 + 2;
    final top = math.max(mq.padding.top + 60, math.min(mq.size.height - 280, raw)).toDouble();
    out.add(Positioned(left: 0, right: 0, top: top, child: Center(child: column)));
    return out;
  }

  // ── Eylemler ────────────────────────────────────────────────
  Future<void> _spawn([int slot = 0]) async {
    final r = _svc.spawn(slot: slot);
    switch (r) {
      case MbSpawnResult.ok:
        GameFx.instance.uiTap();
        _playSpawnAnim(_svc.state.lastSpawnIndex, slot);
        if (_svc.state.lastSpawnFree) _say(_lt('Free tap! No energy used ⚡'));
        if (_tutActive && !_tutSpawned) {
          _tutSpawned = true;
          if (!_tutReplay) AnalyticsService.instance.log('mb_tut_spawn');
        }
        break;
      case MbSpawnResult.full:
        GameFx.instance.denied();
        AppLog.i('mod2', 'ekran: "tahta dolu" mesaji gosterildi');
        _say(_lt('Board is full! Merge or deliver some items.'));
        break;
      case MbSpawnResult.noEnergy:
        GameFx.instance.denied();
        AppLog.i('mod2', 'ekran: "enerji bitti" penceresi aciliyor');
        await _noEnergy();
        break;
    }
  }

  /// Videodaki gibi: sandik sikisip ziplar, yeni obje sandiktan cikip yay cizerek
  /// secilen bos hucreye iner (beyaz parlama + hafif yaylanma).
  void _playSpawnAnim(int idx, [int slot = 0]) {
    final sl = slot.clamp(0, MbWorlds.producerCells.length - 1).toInt();
    final g = _svc.board.genCell < 0 ? -1 : MbWorlds.producerCells[sl];
    setState(() => _genTaps[sl]++);
    if (idx < 0 || g < 0 || !mounted) return;
    final from = _rectOf(_cellKeys[g]);
    final to = _rectOf(_cellKeys[idx]);
    final lvl = _svc.board.cells[idx];
    if (from == null || to == null || lvl <= 0) return;
    setState(() => _flying.add(idx));
    final size = to.width;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SpawnFly(
        from: from.center,
        to: to.center,
        size: size,
        delayMs: 110,
        onLand: () {
          if (!mounted) return;
          setState(() {
            _flying.remove(idx);
            _landed[idx] = lvl;
          });
        },
        onDone: () => entry.remove(),
        child: _face(lvl, size),
      ),
    );
    overlay.insert(entry);
  }

  /// Enerji bitince: "Daha Fazla Enerji?" penceresi (100 ⚡ = 10 💎 ya da reklam). Mantik: widgets/energy_bar.dart.
  Future<void> _noEnergy() async {
    final wait = formatCountdown(Duration(seconds: _svc.secondsToNextEnergy));
    AppLog.i('mod2', 'enerji penceresi acildi: bekleme=$wait elmas=${GameProgress.instance.gems}');
    AnalyticsService.instance.log('mb_energy_choice', {
      'choice': 'popup',
      'chapter': _svc.board.chapter,
      'gems': GameProgress.instance.gems,
    });
    await showEnergyPopup(context, mode: EnergyMode.merge);
    if (mounted) setState(() {});
  }

  void _move(int from, int to) {
    final lvl = MbBoard.lv(_svc.board.cells[from]);
    final r = _svc.move(from, to);
    switch (r) {
      case MbMove.merged:
        GameFx.instance.merge(lvl + 1);
        if (_tutActive && !_tutMerged) {
          _tutMerged = true;
          if (!_tutReplay) AnalyticsService.instance.log('mb_tut_merge');
        }
        break;
      case MbMove.moved:
      case MbMove.swapped:
        GameFx.instance.uiTap();
        break;
      case MbMove.none:
        break;
    }
  }

  Rect? _rectOf(GlobalKey k) {
    final ro = k.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  /// Objeye DOKUNUNCA: uygun siparis varsa obje karta ucar ve teslim olur.
  void _tapDeliver(int cell) {
    final b = _svc.board;
    final lvl = b.cells[cell];
    if (lvl == 0) return;
    final chain = _chainOf(lvl); // teslimden ONCE (dunya degisirse ucan obje yine dogru zincirin gorseli olsun)
    AppLog.i('mod2', 'dokunus: hucre=$cell Lv${MbBoard.lv(lvl)} siparisler=${_svc.ordersText()}');
    var target = -1;
    for (var i = 0; i < b.orders.length; i++) {
      if (!b.canDeliver(cell, i)) continue;
      // Once yarisi dolmus siparisi bitir.
      if (b.orders[i].filled.any((f) => f)) {
        target = i;
        break;
      }
      if (target < 0) target = i;
    }
    if (target < 0) {
      AppLog.i('mod2', 'dokunus: Lv${MbBoard.lv(lvl)} icin uygun siparis yok (teslim edilmedi)');
      return;
    }
    final from = _rectOf(_cellKeys[cell]);
    final to = _rectOf(_orderKeys[target]);
    _deliver(cell, target, flyMs: (from != null && to != null) ? 420 : 0);
    if (from != null && to != null && mounted) {
      final size = from.width * 0.9;
      final overlay = Overlay.of(context);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _FlyItem(
          from: from.center,
          to: to.center,
          size: size,
          onDone: () => entry.remove(),
          child: _face(lvl, size, chain: chain),
        ),
      );
      overlay.insert(entry);
    }
  }

  /// Hucre/siparis degeri (slot*10+seviye) -> bu dunyadaki zincir (tema indeksi).
  int _chainOf(int v) => _svc.state.chainOfSlot(MbBoard.slotOf(v));

  void _deliver(int cell, int orderIndex, {int flyMs = 0}) {
    // Teslimden ONCE: kartin ekran konumu + siparis nesnesi (animasyon icin).
    final orderRect = (orderIndex >= 0 && orderIndex < _orderKeys.length) ? _rectOf(_orderKeys[orderIndex]) : null;
    final orderObj = (orderIndex >= 0 && orderIndex < _svc.board.orders.length) ? _svc.board.orders[orderIndex] : null;
    // Yeni gelen siparis, eski kart kaybolurken sahneye girsin.
    _entryDelayMs = flyMs + 320;
    final r = _svc.deliver(cell, orderIndex);
    if (!r.ok) {
      _entryDelayMs = 0;
      GameFx.instance.denied();
      return;
    }
    AppLog.i('mod2', 'ekran: teslim animasyonu/mesaji tamamlandi=${r.completed} bolumBitti=${r.chapterCompleted}');
    if (_tutActive) {
      if (!_tutDelivered) {
        _tutDelivered = true;
        if (!_tutReplay) AnalyticsService.instance.log('mb_tut_deliver');
      }
      if (r.completed) _tutFinish();
    }
    if (r.completed) {
      GameFx.instance.orderDelivered();
      if (orderRect != null && orderObj != null) _showOrderGhost(orderRect, orderObj, flyMs);
      final bonusTxt = r.energyBonus > 0 ? '  +${r.energyBonus} ⚡' : '';
      _showRewardToast('+${r.reward} 🪙$bonusTxt', delayMs: flyMs + 120);
      if (r.chapterCompleted) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _chapterDone(r);
        });
      }
    } else {
      _entryDelayMs = 0;
      GameFx.instance.uiTap();
    }
  }

  /// Teslim edilen siparis kartinin "hayalet" kopyasi: tamamlandi gorunumu, buyur,
  /// yukari suzulup kaybolur. Asil kart modelden hemen silindigi icin overlay'de oynar.
  void _showOrderGhost(Rect rect, MbOrder o, int delayMs) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _OrderGhost(
        rect: rect,
        delayMs: delayMs,
        onDone: () => entry.remove(),
        child: _orderBody(o, hot: false),
      ),
    );
    overlay.insert(entry);
  }

  /// Teslim odulu: ekranin ortasinda belirir, yukari suzulup silinir.
  void _showRewardToast(String text, {int delayMs = 0}) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _RewardToast(text: text, delayMs: delayMs, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  Future<void> _chapterDone(MbDeliverResult r) async {
    GameFx.instance.reward();
    final next = _svc.board.chapterCfg;
    final rewards = <Widget>[
      _MbPill(text: _lt('+{0} 🪙 chapter reward', [r.chapterBonus]), tint: const Color(0xFFE0A100)),
      if (_svc.lastXp > 0) _MbPill(text: _lt('+{0} XP', [_svc.lastXp]), tint: const Color(0xFF7B4FD6)),
      for (final lu in _svc.lastLevelUps)
        _MbPill(text: _lt('⬆️ Level {0}! +{1} 🪙, energy refilled', [lu.level, lu.coins]), tint: const Color(0xFF2E9E3E)),
      if (r.worldCompleted)
        _MbPill(
          text: _lt('New world: {0} 🎉', [AppStrings.instance.t(kMbThemes[_svc.worldIndex].themeNameKey)]),
          tint: const Color(0xFFD6447A),
        ),
    ];
    final info = <String>[
      if (r.newProducer) _lt('New producer unlocked! Tap its chest to use it.'),
      if (next.maxSpawnLevel > MbChapter.of(r.finishedChapter).maxSpawnLevel)
        _lt('The spawner now gives up to Lv{0}!', [next.maxSpawnLevel]),
      if (next.titleEn.isNotEmpty) _lt(next.titleEn),
      if (next.descEn.isNotEmpty) _lt(next.descEn),
    ];
    AppLog.i('mod2', 'bolum bitti penceresi aciliyor: bolum=${r.finishedChapter} sonraki=${next.number}');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => GameAlertDialog(
        title: Text(_lt('🎉 Chapter {0} complete!', [r.finishedChapter]), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...rewards,
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0x1F5D2E00),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _lt('Next: Chapter {0}', [next.number]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
                  ),
                  for (final line in info) ...[
                    const SizedBox(height: 4),
                    CoinText(
                      line,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B4A32), height: 1.25),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_lt('Continue'))),
        ],
      ),
    );
    AppLog.i('mod2', 'bolum bitti penceresi kapandi (Devam)');
    // Dunya bitti / yeni dunyaya girildi ise hikaye sahnesi.
    if (mounted) await _storyCheck();
    // v179: Google Play puanlama penceresi (3. bolumden itibaren; ReviewService kendi siniri/araligini uygular).
    if (mounted && !_tutActive) unawaited(ReviewService.instance.maybeAskMod2(finishedChapter: r.finishedChapter));
  }

  Future<void> _openMap() async {
    GameFx.instance.uiTap();
    AppLog.i('mod2', 'bolum haritasi aciliyor: bolum=${_svc.board.chapter}');
    AnalyticsService.instance.log('mb_map_open', {'chapter': _svc.board.chapter});
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MergeMapScreen()));
    if (mounted) setState(() {});
  }

  // ── Arayuz ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF2B1B4D),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = kMbThemes[_svc.worldIndex];
    _plan = _tutActive ? MbTutorial.plan(_svc.board) : null;
    final planSig = _plan?.sig ?? '-';
    if (_tutActive && planSig != _lastPlanSig) {
      _lastPlanSig = planSig;
      AppLog.i('mod2', 'ogretici adim: $planSig siparis=${_svc.ordersText()} obje=[${_svc.boardHist()}]');
    }
    return Scaffold(
      backgroundColor: const Color(0xFF2B1B4D),
      body: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: Image.asset(
              theme.tableImagePath,
              key: ValueKey<int>(_svc.worldIndex),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.55)),
          SafeArea(
            child: Column(
              children: [
                _topBar(theme),
                const SizedBox(height: 6),
                _chapterBanner(),
                const SizedBox(height: 6),
                _ordersRow(),
                const SizedBox(height: 6),
                Expanded(child: _boardView()),
                _bottomBar(),
              ],
            ),
          ),
          ..._tutOverlay(),
        ],
      ),
    );
  }

  Widget _topBar(GameTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      // v184: ENERJI (+) | COIN | MUCEVHER (+) cubugu. Enerji = Mod 2 (Surukle-Birak) enerjisi.
      // Dunya adi/harita: bolum seridine dokununca zaten harita acilir.
      child: Row(
        children: [
          GlassCircleButton(icon: Icons.arrow_back_rounded, size: 42, onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 8),
          const Expanded(child: GameTopBar(mode: EnergyMode.merge)),
          const SizedBox(width: 8),
          GlassCircleButton(icon: Icons.help_outline_rounded, size: 42, onTap: _openHowTo),
        ],
      ),
    );
  }

  // ── Bolum seridi ────────────────────────────────────────────
  Widget _chapterBanner() {
    final b = _svc.board;
    final cfg = b.chapterCfg;
    final accent = cfg.isSpecial
        ? const Color(0xFFFFD54F)
        : (cfg.isRule ? const Color(0xFF80DEEA) : Colors.white);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: _openMap,
        child: GlassPill(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📖 ${_lt('Chapter {0}', [cfg.number])}  ·  ${b.chapterProgress}/${cfg.goal}',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.map_rounded, size: 16, color: accent),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: b.chapterProgress / cfg.goal,
                        minHeight: 7,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ),
                ],
              ),
              if (cfg.titleEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(_lt(cfg.titleEn),
                      style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Siparisler ──────────────────────────────────────────────
  Widget _ordersRow() {
    final orders = _svc.board.orders;
    if (!_ordersInit) {
      // Ilk acilis: mevcut siparisler animasyonsuz gorunur.
      _seenOrders.addAll(orders);
      _ordersInit = true;
    }
    final fresh = <MbOrder>{for (final o in orders) if (!_seenOrders.contains(o)) o};
    final entryDelay = _entryDelayMs;
    if (fresh.isNotEmpty) {
      _seenOrders.addAll(fresh);
      _entryDelayMs = 0;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        children: [
          for (var i = 0; i < MbBoard.orderSlots; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: i < orders.length
                    ? KeyedSubtree(
                        key: _orderKeys[i],
                        child: _OrderSlot(
                          key: ObjectKey(orders[i]),
                          animateIn: fresh.contains(orders[i]),
                          delayMs: entryDelay,
                          child: _orderCard(i, orders[i]),
                        ),
                      )
                    : const SizedBox(height: _kOrderH),
              ),
            ),
        ],
      ),
    );
  }

  static const double _kOrderH = 118;

  Widget _orderCard(int oi, MbOrder o) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => _svc.board.canDeliver(d.data, oi),
      onAcceptWithDetails: (d) => _deliver(d.data, oi),
      builder: (ctx, cand, rej) => _orderBody(o, hot: cand.isNotEmpty),
    );
  }

  Widget _orderBody(MbOrder o, {required bool hot}) {
    // Az kalemli kartta urunler buyuk, cok kalemlide kucuk (kart genisligine sigar).
    final n = o.levels.length;
    final itemSize = n <= 1 ? 62.0 : (n == 2 ? 50.0 : 36.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: _kOrderH,
      padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
      transform: Matrix4.identity()..scale(hot ? 1.05 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6).withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hot ? const Color(0xFFFFB300) : const Color(0xFF8D6E63), width: hot ? 3 : 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var k = 0; k < o.levels.length; k++) ...[
                      if (k > 0) const SizedBox(width: 3),
                      _need(o.levels[k], o.filled[k], itemSize),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/coin_icon.webp', width: 16, height: 16),
              const SizedBox(width: 4),
              Text('${o.reward}',
                  style: const TextStyle(color: Color(0xFF4E342E), fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _need(int v, bool filled, double size) {
    final level = MbBoard.lv(v);
    final tier = kMbThemes[_chainOf(v)].byLevel(level);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: filled ? 0.3 : 1,
            child: Image.asset(tier.imagePath, width: size, height: size, cacheWidth: (size * 3).round()),
          ),
          Positioned(right: 0, bottom: 0, child: _levelChip(level, size >= 48 ? 11 : 10)),
          if (filled) Icon(Icons.check_circle_rounded, color: const Color(0xFF2E7D32), size: size * 0.7),
        ],
      ),
    );
  }

  Widget _levelChip(int level, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
      child: Text('$level', style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w900)),
    );
  }

  // ── Tahta ───────────────────────────────────────────────────
  Widget _boardView() {
    return LayoutBuilder(builder: (ctx, c) {
      final cell = math.min(c.maxWidth / MbBoard.cols, c.maxHeight / MbBoard.rows);
      return Center(
        child: SizedBox(
          width: cell * MbBoard.cols,
          height: cell * MbBoard.rows,
          child: Column(
            children: [
              for (var r = 0; r < MbBoard.rows; r++)
                Row(
                  children: [
                    for (var col = 0; col < MbBoard.cols; col++) _cell(r * MbBoard.cols + col, cell),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _cell(int i, double size) {
    final lvl = _svc.board.cells[i];
    final gs = _svc.board.genSlotOf(i);
    if (gs >= 0) return _generatorCell(i, size, gs);
    return SizedBox(
      key: _cellKeys[i],
      width: size,
      height: size,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != i,
        onAcceptWithDetails: (d) => _move(d.data, i),
        builder: (ctx, cand, rej) {
          final hot = cand.isNotEmpty;
          final dragLvl = _dragFrom == null ? 0 : _svc.board.cells[_dragFrom!];
          final mergeable = hot && lvl > 0 && lvl == dragLvl && MbBoard.lv(lvl) < MbBoard.maxLevel;
          return Padding(
            padding: const EdgeInsets.all(2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(mergeable ? 0.1 : 0.28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: mergeable ? Colors.greenAccent : (hot ? Colors.white70 : Colors.white12),
                  width: hot ? 2.5 : 1,
                ),
              ),
              child: (lvl == 0 || _flying.contains(i)) ? null : _item(i, lvl, size),
            ),
          );
        },
      ),
    );
  }

  /// Tahtadaki URETICI (sandik): dokununca ⚡1 harcar (seviyeye gore bazen bedava), yakin bos
  /// hucrelere KENDI zincirinden obje uretir. Sol alttaki Lv rozetine dokun / uzun bas: yukselt.
  Widget _generatorCell(int i, double size, int slot) {
    final energy = _svc.energy;
    final canSpawn = energy > 0 && !_svc.board.isFull;
    final chain = _svc.state.chainOfSlot(slot);
    final level = _svc.producerLevel(chain);
    final cost = _svc.producerUpgradeCost(chain);
    final canUpgrade = cost != null && GameProgress.instance.coins >= cost;
    return SizedBox(
      key: _cellKeys[i],
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _spawn(slot),
        onLongPress: () => _openProducer(slot),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: PulseGlow(
            active: _tutActive && _plan?.kind == MbTutKind.spawn && _plan?.slot == slot,
            radius: 12,
            child: _GeneratorView(
              taps: _genTaps[slot],
              canSpawn: canSpawn,
              hasEnergy: energy > 0,
              emblem: kMbThemes[chain].byLevel(1).imagePath,
              level: level,
              canUpgrade: canUpgrade,
              onUpgrade: () => _openProducer(slot),
            ),
          ),
        ),
      ),
    );
  }

  /// Uretici penceresi: zincir, seviye, etkiler ve coinle yukseltme.
  Future<void> _openProducer(int slot) async {
    GameFx.instance.uiTap();
    final chain = _svc.state.chainOfSlot(slot);
    final theme = kMbThemes[chain];
    final imgs = [for (var i = 1; i <= 3; i++) theme.byLevel(i).imagePath];
    AppLog.i('mod2', 'uretici penceresi acildi: slot=$slot zincir=$chain Lv${_svc.producerLevel(chain)}');
    AnalyticsService.instance.log('mb_producer_open', {'chain': chain, 'level': _svc.producerLevel(chain)});
    String? note;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final level = _svc.producerLevel(chain);
        final cost = _svc.producerUpgradeCost(chain);
        const lineStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B4A32), height: 1.3);
        return GameAlertDialog(
          title: Text(
            '${AppStrings.instance.t(theme.themeNameKey)} · ${_lt('Producer')}',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MergeChainHint(images: imgs),
              const SizedBox(height: 10),
              Text(
                _lt('Producer Lv{0} / {1}', [level, MbWorlds.maxProducerLevel]),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
              ),
              const SizedBox(height: 6),
              CoinText(
                _lt('Higher level items: +{0}% chance', [MbWorlds.bonusPct(level)]),
                textAlign: TextAlign.center,
                style: lineStyle,
              ),
              CoinText(
                _lt('Free taps (no ⚡): {0}% chance', [MbWorlds.freeTapPct(level)]),
                textAlign: TextAlign.center,
                style: lineStyle,
              ),
              if (cost != null) ...[
                const SizedBox(height: 6),
                CoinText(
                  _lt('Next level: +{0}% items, {1}% free taps', [MbWorlds.bonusPct(level + 1), MbWorlds.freeTapPct(level + 1)]),
                  textAlign: TextAlign.center,
                  style: lineStyle.copyWith(color: const Color(0xFF2E7D32)),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(_lt('Max level reached!'),
                    textAlign: TextAlign.center,
                    style: lineStyle.copyWith(color: const Color(0xFF2E7D32))),
              ],
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note!,
                    textAlign: TextAlign.center,
                    style: lineStyle.copyWith(color: const Color(0xFFC62828))),
              ],
            ],
          ),
          actions: [
            if (cost != null)
              FilledButton(
                onPressed: () {
                  final r = _svc.upgradeProducer(chain);
                  if (r == MbUpgradeResult.ok) {
                    GameFx.instance.reward();
                    note = null;
                  } else {
                    GameFx.instance.denied();
                    note = _lt('Not enough coins');
                  }
                  setD(() {});
                  if (mounted) setState(() {});
                },
                child: CoinText(_lt('Upgrade · {0} 🪙', [cost])),
              ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_lt('Close'))),
          ],
        );
      }),
    );
    if (mounted) setState(() {});
  }

  Widget _item(int i, int lvl, double size) {
    final feedbackSize = size * 1.3;
    final face = _face(lvl, size);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapDeliver(i),
      child: Draggable<int>(
      data: i,
      dragAnchorStrategy: (draggable, context, position) => Offset(feedbackSize / 2, feedbackSize * 0.9),
      onDragStarted: () {
        GameFx.instance.uiTap();
        AppLog.i('mod2', 'surukleme basladi: hucre=$i Lv$lvl');
        setState(() => _dragFrom = i);
      },
      onDragEnd: (d) {
        if (!d.wasAccepted) AppLog.i('mod2', 'surukleme bos/gecersiz yere birakildi: hucre=$i Lv$lvl (hicbir sey olmadi)');
        if (mounted) setState(() => _dragFrom = null);
      },
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(width: feedbackSize, height: feedbackSize, child: _face(lvl, feedbackSize)),
      ),
      childWhenDragging: Opacity(opacity: 0.2, child: face),
      // Seviye degisince (yeni cikti / birlesti) kucuk bir "pop" animasyonu.
      child: TweenAnimationBuilder<double>(
        key: ValueKey('mb-$i-$lvl'),
        tween: Tween<double>(begin: _landed[i] == lvl ? 1.0 : 0.55, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
        child: face,
      ),
      ),
    );
  }

  /// [v] = slot*10 + seviye. Gorsel, objenin ZINCIRINE gore secilir ([chain] verilirse o zincir).
  Widget _face(int v, double size, {int? chain}) {
    final lvl = MbBoard.lv(v);
    final tier = kMbThemes[chain ?? _chainOf(v)].byLevel(lvl);
    final isMax = lvl == MbBoard.maxLevel;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tier.color.withOpacity(0.32),
              border: isMax ? Border.all(color: const Color(0xFFFFD54F), width: 2) : null,
            ),
          ),
          Image.asset(tier.imagePath, width: size * 0.8, height: size * 0.8, cacheWidth: 200),
          Positioned(right: size * 0.06, bottom: size * 0.04, child: _levelChip(lvl, math.max(9, size * 0.17))),
        ],
      ),
    );
  }

  // ── Alt cubuk: ipucu (enerji artik ustteki cubukta; uretec tahtada) ──────────────────────────────
  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _lt('Drag matching items together to merge · tap an item to deliver it to an order'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Tahtadaki uretec nesnesi: altin cerceveli sandik, ⚡1 rozeti. Dokununca sikisip ziplar;
/// bosta hafifce "nefes alir" (enerji varken). Enerji yok / tahta doluysa soluk gorunur.
class _GeneratorView extends StatefulWidget {
  final int taps;
  final bool canSpawn;
  final bool hasEnergy;

  /// Ureticinin zincirini gosteren kucuk rozet gorseli (zincirin Lv1 objesi), uretici seviyesi,
  /// yukseltmeye coin yetiyor mu, rozete dokunma.
  final String? emblem;
  final int level;
  final bool canUpgrade;
  final VoidCallback? onUpgrade;
  const _GeneratorView({
    required this.taps,
    required this.canSpawn,
    required this.hasEnergy,
    this.emblem,
    this.level = 1,
    this.canUpgrade = false,
    this.onUpgrade,
  });

  @override
  State<_GeneratorView> createState() => _GeneratorViewState();
}

class _GeneratorViewState extends State<_GeneratorView> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final size = math.min(c.maxWidth, c.maxHeight);
      return AnimatedBuilder(
        animation: _idle,
        builder: (ctx, _) {
          final t = Curves.easeInOut.transform(_idle.value);
          final breathe = widget.canSpawn ? 1.0 + 0.035 * t : 1.0;
          final glow = widget.canSpawn ? 0.25 + 0.35 * t : 0.0;
          // Dokunus: key degisince bastan oynar. Once sikisir, sonra yukari yaylanir.
          return TweenAnimationBuilder<double>(
            key: ValueKey<int>(widget.taps),
            tween: Tween<double>(begin: widget.taps == 0 ? 1.0 : 0.0, end: 1.0),
            duration: const Duration(milliseconds: 420),
            builder: (ctx, v, child) {
              final squash = math.sin(v * math.pi * 2) * (1 - v);
              final sx = 1.0 - 0.16 * squash;
              final sy = 1.0 + 0.16 * squash;
              return Transform.scale(scaleX: sx * breathe, scaleY: sy * breathe, child: child);
            },
            child: Opacity(
              opacity: widget.canSpawn ? 1.0 : 0.72,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8A5A1F), Color(0xFF4E2F0E)],
                  ),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 2.2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFFD54F).withOpacity(glow), blurRadius: 12, spreadRadius: 1),
                    BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset('assets/images/ui/chest.webp', width: size * 0.74, height: size * 0.74),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                        decoration: BoxDecoration(
                          color: widget.hasEnergy ? const Color(0xFF1E6FD6) : const Color(0xFFC62828),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: CoinText('⚡1',
                            style: TextStyle(color: Colors.white, fontSize: math.max(9, size * 0.19), fontWeight: FontWeight.w900)),
                      ),
                    ),
                    Positioned(
                      left: 3,
                      top: 1,
                      child: Opacity(
                        opacity: widget.canSpawn ? (0.35 + 0.65 * t) : 0.0,
                        child: Icon(Icons.auto_awesome, size: size * 0.2, color: Colors.white),
                      ),
                    ),
                    if (widget.emblem != null)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: size * 0.36,
                          height: size * 0.36,
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
                          ),
                          child: Image.asset(widget.emblem!, fit: BoxFit.contain, cacheWidth: 96),
                        ),
                      ),
                    Positioned(
                      left: 1,
                      bottom: 1,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onUpgrade,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                          decoration: BoxDecoration(
                            color: widget.canUpgrade ? const Color(0xFF2E9E3E) : const Color(0xFF3B2A6B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            widget.canUpgrade ? 'Lv${widget.level} ▲' : 'Lv${widget.level}',
                            style: TextStyle(color: Colors.white, fontSize: math.max(8, size * 0.16), fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Uretilen objenin sandiktan hedef hucreye ucusu: kucuk baslar, yay cizip buyur, inince
/// hafifce yaylanir ve beyaz bir parlama birakir. [onLand] inis aninda (hucre gorunsun diye).
class _SpawnFly extends StatefulWidget {
  final Offset from;
  final Offset to;
  final double size;
  final int delayMs;
  final Widget child;
  final VoidCallback onLand;
  final VoidCallback onDone;
  const _SpawnFly({
    required this.from,
    required this.to,
    required this.size,
    required this.delayMs,
    required this.child,
    required this.onLand,
    required this.onDone,
  });

  @override
  State<_SpawnFly> createState() => _SpawnFlyState();
}

class _SpawnFlyState extends State<_SpawnFly> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  bool _started = false;
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() => _started = true);
      _c.addListener(() {
        // Ucus %78'de biter; sonrasi yalniz yaylanma + parlama (hucredeki obje zaten gorunur).
        if (!_landed && _c.value >= 0.78) {
          _landed = true;
          widget.onLand();
        }
      });
      _c.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      child: Material(type: MaterialType.transparency, child: widget.child),
      builder: (ctx, child) {
        final v = _c.value;
        final f = (v / 0.78).clamp(0.0, 1.0); // ucus ilerlemesi
        final t = Curves.easeInOutCubic.transform(f);
        final pos = Offset.lerp(widget.from, widget.to, t)!;
        final lift = -math.sin(t * math.pi) * widget.size * 0.85;
        var scale = 0.3 + 0.7 * Curves.easeOutBack.transform(math.min(1.0, f * 1.25));
        var glow = 0.0;
        if (v > 0.78) {
          // Inis: kucuk yaylanma (1.0 -> 1.12 -> 1.0) + beyaz parlama sonmesi.
          final r = (v - 0.78) / 0.22;
          scale = 1.0 + 0.12 * math.sin(r * math.pi);
          glow = 1.0 - r;
        }
        final s = widget.size;
        return Positioned(
          left: pos.dx - s / 2,
          top: pos.dy - s / 2 + lift,
          width: s,
          height: s,
          child: IgnorePointer(
            child: Stack(
                alignment: Alignment.center,
                children: [
                  if (glow > 0 || f < 1)
                    Container(
                      width: s * 0.9,
                      height: s * 0.9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(v > 0.78 ? 0.55 * glow : 0.25 * f),
                        boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.5 * (v > 0.78 ? glow : f)), blurRadius: 14)],
                      ),
                    ),
                  Transform.scale(scale: scale, child: child),
                ],
              ),
          ),
        );
      },
    );
  }
}

/// Siparis kartinin sahneye giris animasyonu: yukaridan kayar, buyuyerek oturur.
/// [animateIn] false ise (ilk acilis / var olan kart) animasyonsuz gorunur.
class _OrderSlot extends StatefulWidget {
  final bool animateIn;
  final int delayMs;
  final Widget child;
  const _OrderSlot({super.key, required this.animateIn, required this.delayMs, required this.child});

  @override
  State<_OrderSlot> createState() => _OrderSlotState();
}

class _OrderSlotState extends State<_OrderSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animateIn) {
      _c.value = 1;
      _started = true;
      return;
    }
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() => _started = true);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return Opacity(opacity: 0, child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (ctx, child) {
        final t = _c.value;
        final pop = Curves.easeOutBack.transform(t);
        final fade = Curves.easeOut.transform((t * 1.6).clamp(0.0, 1.0));
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, -46 * (1 - pop)),
            child: Transform.scale(scale: 0.55 + 0.45 * pop, child: child),
          ),
        );
      },
    );
  }
}

/// Teslim edilen siparis kartinin cikis animasyonu (overlay'de): once hafifce
/// buyur ve yesil parlar, sonra yukari suzulup solar.
class _OrderGhost extends StatefulWidget {
  final Rect rect;
  final int delayMs;
  final Widget child;
  final VoidCallback onDone;
  const _OrderGhost({required this.rect, required this.delayMs, required this.child, required this.onDone});

  @override
  State<_OrderGhost> createState() => _OrderGhostState();
}

class _OrderGhostState extends State<_OrderGhost> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: math.max(0, widget.delayMs - 120)), () {
      if (!mounted) return;
      _c.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: Material(type: MaterialType.transparency, child: widget.child),
      builder: (ctx, child) {
        final t = _c.value;
        // 0-0.3: buyu (pop), 0.3-1: kuculerek yukari suzul + sol.
        final pop = t < 0.3 ? Curves.easeOut.transform(t / 0.3) : 1.0;
        final out = t < 0.3 ? 0.0 : Curves.easeIn.transform((t - 0.3) / 0.7);
        final scale = 1.0 + 0.12 * pop - 0.3 * out;
        final dy = -50 * out;
        final glow = (t < 0.3 ? pop : 1 - out).clamp(0.0, 1.0);
        return Positioned(
          left: widget.rect.left,
          top: widget.rect.top + dy,
          width: widget.rect.width,
          height: widget.rect.height,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - out).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.7 * glow), blurRadius: 18, spreadRadius: 2)],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Teslim odulu ("+6 🪙 +2 ⚡"): ekranin ortasinda belirir, yukari suzulup kaybolur.
class _RewardToast extends StatefulWidget {
  final String text;
  final int delayMs;
  final VoidCallback onDone;
  const _RewardToast({required this.text, required this.delayMs, required this.onDone});

  @override
  State<_RewardToast> createState() => _RewardToastState();
}

class _RewardToastState extends State<_RewardToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() => _started = true);
      _c.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) {
        final t = _c.value;
        // Giris: 0-0.2 buyuyerek belir; 0.2-0.65 bekle; 0.65-1 yukari suzulup sol.
        final inT = Curves.easeOutBack.transform((t / 0.2).clamp(0.0, 1.0));
        final outT = ((t - 0.65) / 0.35).clamp(0.0, 1.0);
        final opacity = (t < 0.2 ? (t / 0.2) : 1.0) * (1 - Curves.easeIn.transform(outT));
        final dy = -70 * Curves.easeOut.transform(t) - 30 * outT;
        return Positioned(
          left: 0,
          right: 0,
          top: size.height * 0.42,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * inT,
                  child: Center(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B2A6B).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: CoinText(
                          widget.text,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Teslim edilen objenin siparis kartina ucus animasyonu (Mod 1'deki gibi).
class _FlyItem extends StatefulWidget {
  final Offset from;
  final Offset to;
  final double size;
  final Widget child;
  final VoidCallback onDone;
  const _FlyItem({
    required this.from,
    required this.to,
    required this.size,
    required this.child,
    required this.onDone,
  });

  @override
  State<_FlyItem> createState() => _FlyItemState();
}

class _FlyItemState extends State<_FlyItem> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Positioned dogrudan Overlay'in Stack'ine baglanmali; arada IgnorePointer
    // (RenderObjectWidget) olursa "Incorrect use of ParentDataWidget" hatasi verir.
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, child) {
        final t = Curves.easeInCubic.transform(_c.value);
        final pos = Offset.lerp(widget.from, widget.to, t)!;
        // Hafif yay: ortada yukari kalkar.
        final lift = -math.sin(t * math.pi) * 36;
        final scale = 1.0 - 0.55 * t;
        return Positioned(
          left: pos.dx - widget.size / 2,
          top: pos.dy - widget.size / 2 + lift,
          width: widget.size,
          height: widget.size,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1.0 - (t - 0.8).clamp(0.0, 0.2) * 5).clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
  }
}


/// "Nasil oynanir" penceresindeki numarali adim satiri.
class _MbStepRow extends StatelessWidget {
  final int n;
  final String text;
  const _MbStepRow({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFB444), Color(0xFFFF8A1F)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                textAlign: TextAlign.start,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF6B4A32), height: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bolum sonu penceresindeki odul satiri (coin/enerji/elmas ikonlari CoinText ile cizilir).
class _MbPill extends StatelessWidget {
  final String text;
  final Color tint;
  const _MbPill({required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withOpacity(0.5), width: 1.5),
      ),
      child: CoinText(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
      ),
    );
  }
}
