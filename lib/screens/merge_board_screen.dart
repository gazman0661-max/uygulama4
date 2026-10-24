import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../models/game_theme.dart';
import '../models/mb_story.dart';
import '../models/mb_tutorial.dart';
import '../models/merge_board.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/log_service.dart';
import '../services/game_fx.dart';
import '../services/merge_board_service.dart';
import '../utils/duration_format.dart';
import '../widgets/gem_dialogs.dart';
import '../widgets/story_scene.dart';
import '../widgets/tutorial_coach.dart';
import '../widgets/ui_kit.dart';
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
      _tutInit();
      WidgetsBinding.instance.addPostFrameCallback((_) => _storyCheck());
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
      content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
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
    if (!replay) {
      Future<void>.delayed(const Duration(milliseconds: 6200), () {
        if (mounted) _storyCheck();
      });
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
    if (!_tutReplay) WidgetsBinding.instance.addPostFrameCallback((_) => _storyCheck());
  }

  Future<void> _openHowTo() async {
    GameFx.instance.uiTap();
    AppLog.i('mod2', 'nasil oynanir penceresi acildi');
    AnalyticsService.instance.log('mb_howto_open');
    final theme = kMbThemes[_svc.worldIndex];
    final imgs = [for (var i = 1; i <= 3; i++) theme.byLevel(i).imagePath];
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_lt('How to play'), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MergeChainHint(images: imgs),
            const SizedBox(height: 10),
            Text(
              _lt('Tap Spawn to get items.\nDrag two items of the same level together to merge them.\nTap an item (or drop it on an order card) to deliver it.'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_lt('Close'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_lt('Show me'))),
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
        text = _lt('Tap Spawn!');
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
    if (plan.kind == MbTutKind.spawn) {
      out.add(Positioned(left: 0, right: 0, bottom: mq.padding.bottom + 112, child: Center(child: column)));
    } else {
      final raw = above ? anchorY! - targetD * 0.5 - 118 : anchorY! + targetD * 0.5 + 2;
      final top = math.max(mq.padding.top + 60, math.min(mq.size.height - 280, raw)).toDouble();
      out.add(Positioned(left: 0, right: 0, top: top, child: Center(child: column)));
    }
    return out;
  }

  // ── Eylemler ────────────────────────────────────────────────
  Future<void> _spawn() async {
    final r = _svc.spawn();
    switch (r) {
      case MbSpawnResult.ok:
        GameFx.instance.uiTap();
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

  Future<void> _noEnergy() async {
    final wait = formatCountdown(Duration(seconds: _svc.secondsToNextEnergy));
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_lt('Out of energy')),
        content: Text(_lt('Next ⚡ in {0}. Watch an ad for +{1} ⚡ or refill fully for {2} 💎.',
            [wait, MbState.adEnergy, MbState.refillGemCost])),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop('close'), child: Text(_lt('Close'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop('ad'), child: Text(_lt('Watch ad for energy'))),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('gems'),
            child: Text(_lt('Refill · {0} 💎', [MbState.refillGemCost])),
          ),
        ],
      ),
    );
    if (!mounted) return;
    AppLog.i('mod2', 'enerji penceresi secimi: ${choice ?? "kapatildi(disariya dokunma/geri)"} bekleme=$wait elmas=${GameProgress.instance.gems}');
    AnalyticsService.instance.log('mb_energy_choice', {
      'choice': choice ?? 'dismiss',
      'chapter': _svc.board.chapter,
      'gems': GameProgress.instance.gems,
    });
    if (choice == 'ad') {
      final ok = await AdService.instance.showRewarded(context, placement: 'mb_energy');
      AppLog.i('mod2', 'enerji reklami sonucu: odul=$ok');
      if (ok) {
        _svc.addAdEnergy();
        GameFx.instance.reward();
      } else {
        AnalyticsService.instance.log('mb_ad_energy_failed', {'chapter': _svc.board.chapter});
      }
    } else if (choice == 'gems') {
      if (_svc.refillWithGems()) {
        GameFx.instance.reward();
      } else if (GameProgress.instance.gems < MbState.refillGemCost) {
        AppLog.i('mod2', 'yetersiz elmas -> elmas magazasi onerisi aciliyor');
        await showNotEnoughGemsDialog(context);
      }
    }
  }

  void _move(int from, int to) {
    final lvl = _svc.board.cells[from];
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
    AppLog.i('mod2', 'dokunus: hucre=$cell Lv$lvl siparisler=${_svc.ordersText()}');
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
      AppLog.i('mod2', 'dokunus: Lv$lvl icin uygun siparis yok (teslim edilmedi)');
      return;
    }
    final from = _rectOf(_cellKeys[cell]);
    final to = _rectOf(_orderKeys[target]);
    final theme = kMbThemes[_svc.worldIndex];
    _deliver(cell, target);
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
          child: _face(theme, lvl, size),
        ),
      );
      overlay.insert(entry);
    }
  }

  void _deliver(int cell, int orderIndex) {
    final r = _svc.deliver(cell, orderIndex);
    if (!r.ok) {
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
      final bonusTxt = r.energyBonus > 0 ? '  +${r.energyBonus} ⚡' : '';
      _say('+${r.reward} 🪙$bonusTxt');
      if (r.chapterCompleted) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _chapterDone(r);
        });
      }
    } else {
      GameFx.instance.uiTap();
    }
  }

  Future<void> _chapterDone(MbDeliverResult r) async {
    GameFx.instance.reward();
    final next = _svc.board.chapterCfg;
    final lines = <String>[
      _lt('+{0} 🪙 chapter reward', [r.chapterBonus]),
      if (_svc.lastXp > 0) _lt('+{0} XP', [_svc.lastXp]),
      for (final lu in _svc.lastLevelUps) _lt('⬆️ Level {0}! +{1} 🪙, energy refilled', [lu.level, lu.coins]),
      if (r.worldCompleted)
        _lt('New world: {0} 🎉', [AppStrings.instance.t(kMbThemes[_svc.worldIndex].themeNameKey)]),
      '',
      _lt('Next: Chapter {0}', [next.number]),
      if (next.maxSpawnLevel > MbChapter.of(r.finishedChapter).maxSpawnLevel)
        _lt('The spawner now gives up to Lv{0}!', [next.maxSpawnLevel]),
      if (next.titleEn.isNotEmpty) _lt(next.titleEn),
      if (next.descEn.isNotEmpty) _lt(next.descEn),
    ];
    AppLog.i('mod2', 'bolum bitti penceresi aciliyor: bolum=${r.finishedChapter} sonraki=${next.number}');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(_lt('🎉 Chapter {0} complete!', [r.finishedChapter])),
        content: Text(lines.join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_lt('Continue'))),
        ],
      ),
    );
    AppLog.i('mod2', 'bolum bitti penceresi kapandi (Devam)');
    // Dunya bitti / yeni dunyaya girildi ise hikaye sahnesi.
    if (mounted) await _storyCheck();
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
                _ordersRow(theme),
                const SizedBox(height: 6),
                Expanded(child: _boardView(theme)),
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
      child: Row(
        children: [
          GlassCircleButton(icon: Icons.arrow_back_rounded, size: 42, onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _openMap,
              child: GlassPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(theme.byLevel(theme.maxLevel).imagePath, width: 22, height: 22, cacheWidth: 66),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppStrings.instance.t(theme.themeNameKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlassCircleButton(icon: Icons.help_outline_rounded, size: 42, onTap: _openHowTo),
          const SizedBox(width: 8),
          GlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/coin_icon.webp', width: 20, height: 20),
                const SizedBox(width: 5),
                Text('${GameProgress.instance.coins}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
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
  Widget _ordersRow(GameTheme theme) {
    final orders = _svc.board.orders;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        children: [
          for (var i = 0; i < MbBoard.orderSlots; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: i < orders.length
                    ? KeyedSubtree(key: _orderKeys[i], child: _orderCard(i, orders[i], theme))
                    : const SizedBox(height: 104),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orderCard(int oi, MbOrder o, GameTheme theme) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => _svc.board.canDeliver(d.data, oi),
      onAcceptWithDetails: (d) => _deliver(d.data, oi),
      builder: (ctx, cand, rej) {
        final hot = cand.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 104,
          padding: const EdgeInsets.all(6),
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
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 3,
                    runSpacing: 3,
                    children: [for (var k = 0; k < o.levels.length; k++) _need(theme, o.levels[k], o.filled[k])],
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
      },
    );
  }

  Widget _need(GameTheme theme, int level, bool filled) {
    final tier = theme.byLevel(level);
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: filled ? 0.3 : 1,
            child: Image.asset(tier.imagePath, width: 30, height: 30, cacheWidth: 90),
          ),
          Positioned(right: 0, bottom: 0, child: _levelChip(level, 10)),
          if (filled) const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
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
  Widget _boardView(GameTheme theme) {
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
                    for (var col = 0; col < MbBoard.cols; col++) _cell(r * MbBoard.cols + col, cell, theme),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _cell(int i, double size, GameTheme theme) {
    final lvl = _svc.board.cells[i];
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
          final mergeable = hot && lvl > 0 && lvl == dragLvl && lvl < MbBoard.maxLevel;
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
              child: lvl == 0 ? null : _item(i, lvl, size, theme),
            ),
          );
        },
      ),
    );
  }

  Widget _item(int i, int lvl, double size, GameTheme theme) {
    final feedbackSize = size * 1.3;
    final face = _face(theme, lvl, size);
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
        child: SizedBox(width: feedbackSize, height: feedbackSize, child: _face(theme, lvl, feedbackSize)),
      ),
      childWhenDragging: Opacity(opacity: 0.2, child: face),
      // Seviye degisince (yeni cikti / birlesti) kucuk bir "pop" animasyonu.
      child: TweenAnimationBuilder<double>(
        key: ValueKey('mb-$i-$lvl'),
        tween: Tween<double>(begin: 0.55, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
        child: face,
      ),
      ),
    );
  }

  Widget _face(GameTheme theme, int lvl, double size) {
    final tier = theme.byLevel(lvl);
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

  // ── Alt cubuk: enerji + uretec ──────────────────────────────
  Widget _bottomBar() {
    final energy = _svc.energy;
    final secs = _svc.secondsToNextEnergy;
    final canSpawn = energy > 0 && !_svc.board.isFull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassPill(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              '⚡ $energy/${MbState.maxEnergy}${secs > 0 ? '  ·  ${formatCountdown(Duration(seconds: secs))}' : ''}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          PulseGlow(
            active: _tutActive && _plan?.kind == MbTutKind.spawn,
            radius: 30,
            child: CandyButton(
              label: '${_lt('Spawn')}  ⚡1',
              onTap: _spawn,
              width: 250,
              height: 60,
              fontSize: 20,
              style: energy > 0 ? CandyStyle.green : CandyStyle.orange,
              pulse: canSpawn && _svc.board.emptyCount > 40,
              leading: Image.asset('assets/images/ui/chest.webp', width: 38, height: 38),
            ),
          ),
          const SizedBox(height: 4),
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
    return IgnorePointer(
      child: AnimatedBuilder(
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
            child: Opacity(
              opacity: (1.0 - (t - 0.8).clamp(0.0, 0.2) * 5).clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        child: Material(type: MaterialType.transparency, child: widget.child),
      ),
    );
  }
}
