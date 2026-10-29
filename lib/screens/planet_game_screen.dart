import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../models/planet_event.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import '../services/log_service.dart';
import '../services/planet_physics.dart';
import '../widgets/planet_face.dart';
import '../widgets/rewarded_prompt.dart';
import '../widgets/ufo_background.dart';
import '../widgets/ui_kit.dart';

/// HAFTA SONU ETKINLIGI oyun ekrani: yukaridan gezegen birak, ayni kademeler birlesir
/// (Suika tarzi). Tehlike cizgisinin ustunde kalan yigin oyunu bitirir.
/// Enerji hub'da ([PlanetEventScreen]) harcanir; "Tekrar oyna" burada 1 enerji daha harcar.
class PlanetGameScreen extends StatefulWidget {
  const PlanetGameScreen({super.key});

  @override
  State<PlanetGameScreen> createState() => _PlanetGameScreenState();
}

class _Floater {
  final String text;
  final double x;
  final double y;
  final Color color;
  double age = 0;
  _Floater(this.text, this.x, this.y, this.color);
}

class _PlanetGameScreenState extends State<PlanetGameScreen> with SingleTickerProviderStateMixin {
  static const String _tag = 'planet_game';
  static const double _dropCooldown = 0.55;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _clock = 0; // sn: yuz animasyonlari (goz kirpma vb.) icin surekli akan zaman
  PlanetWorld _world = PlanetWorld();
  final math.Random _rng = math.Random();
  final List<ui.Image?> _imgs = List<ui.Image?>.filled(PlanetConfig.tierCount, null);

  int _cur = 0;
  int _next = 0;
  double _aimX = PlanetConfig.worldW / 2;
  double _cool = 0.3;
  bool _over = false;
  bool _rescued = false;
  bool _dropped = false;
  int _runBest = 0;
  final List<_Floater> _floaters = [];
  String? _comboText;
  double _comboT = 0;
  final Map<int, double> _prevVy = {}; // inis algilama: onceki karedeki dikey hiz
  bool _paused = false; // guclendirici penceresi acikken fizik durur
  bool _deleteMode = false; // "Sil": bir gezegene dokunulmasi bekleniyor
  PlanetBody? _marked; // silinmek uzere secilen gezegen

  @override
  void initState() {
    super.initState();
    _cur = PlanetConfig.randomDropTier(_rng);
    _next = PlanetConfig.randomDropTier(_rng);
    _loadImages();
    _ticker = createTicker(_onTick)..start();
    AppLog.i(_tag, 'oyun ekrani acildi enerji=${PlanetEvent.instance.energy}');
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final i in _imgs) {
      i?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadImages() async {
    for (var t = 0; t < PlanetConfig.tierCount; t++) {
      try {
        final data = await rootBundle.load('assets/images/planet/pl_$t.webp');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 200);
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        _imgs[t] = frame.image;
      } catch (err) {
        AppLog.w('$_tag._loadImages', 'gezegen gorseli yuklenemedi (t=$t)', err);
      }
    }
  }

  // ------------------------------------------------------------ dongu
  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt < 0) dt = 0;
    if (dt > 0.05) dt = 0.05;
    _clock += dt;

    if (!_over && !_paused) {
      if (_cool > 0) _cool = math.max(0.0, _cool - dt);
      _world.step(dt);
      _handleEvents();
      // Inis sesi: yeni birakilan gezegenin dikey hizi aniden dusunce (yigina/zemine carpti).
      for (final b in _world.bodies) {
        if (b.age > 3) {
          _prevVy.remove(b.id);
          continue;
        }
        final prev = _prevVy[b.id];
        if (prev != null && prev > 45 && b.vy < prev * 0.4) GameFx.instance.planetLand(prev);
        _prevVy[b.id] = b.vy;
      }
      // Tehlike cizgisine yigilma: kalp atisi gibi hafif titresim.
      if (_world.dangerTimer > 0.3) GameFx.instance.tensionPulse();
      if (_world.gameOver) _onGameOver();
    }
    for (final f in _floaters) {
      f.age += dt;
    }
    _floaters.removeWhere((f) => f.age > 1.0);
    if (_comboT > 0) _comboT = math.max(0.0, _comboT - dt);
    if (mounted) setState(() {});
  }

  void _handleEvents() {
    final events = _world.takeEvents();
    if (events.isEmpty) return;
    final pe = PlanetEvent.instance;
    var delay = 0;
    for (final e in events) {
      pe.onMerge(e.tier, e.combo);
      if (e.tier < 0) {
        GameFx.instance.mergeMax(delayMs: delay);
      } else {
        final best = e.tier > _runBest && e.tier >= 3;
        if (e.tier > _runBest) _runBest = e.tier;
        GameFx.instance.merge((e.tier + 1).clamp(2, 8).toInt(), isNewBest: best, delayMs: delay);
      }
      if (e.combo >= 2) GameFx.instance.planetCombo(e.combo, delayMs: delay + 40);
      delay += 60;
      _floaters.add(_Floater('+${e.points}', e.x, e.y, e.combo >= 2 ? Colors.amberAccent : Colors.white));
      if (e.combo >= 2) {
        _comboText = 'x${e.combo}';
        _comboT = 1.2;
      }
    }
    pe.onScore(_world.score);
  }

  void _onGameOver() {
    if (_over) return;
    _over = true;
    _deleteMode = false;
    _marked = null;
    GameFx.instance.gameOver();
    PlanetEvent.instance.onScore(_world.score);
    AppLog.i(_tag, 'OYUN BITTI skor=${_world.score} enYuksekKademe=${_world.bestTier} birlestirme=${_world.merges} enIyiKombo=${_world.maxCombo}');
    AnalyticsService.instance.log('pe_run_end', {
      'score': _world.score,
      'tier': _world.bestTier,
      'merges': _world.merges,
      'combo': _world.maxCombo,
    });
  }

  // ------------------------------------------------------------ girdi
  void _setAim(double dxPx, double scale) {
    _aimX = (dxPx / scale).clamp(0.0, PlanetConfig.worldW).toDouble();
  }

  void _drop() {
    if (_over || _paused || _cool > 0) return;
    _world.drop(_cur, _aimX);
    GameFx.instance.throwBall();
    _dropped = true;
    _cur = _next;
    _next = PlanetConfig.randomDropTier(_rng);
    _cool = _dropCooldown;
  }

  // ------------------------------------------------------------ cikis / tekrar
  Future<void> _confirmExit() async {
    final s = AppStrings.instance;
    if (_over) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.lt('Leave the game?')),
        content: Text(s.lt('Your run ends and the energy is not refunded.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.lt('Stay'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.lt('Leave'))),
        ],
      ),
    );
    if (leave == true && mounted) {
      AppLog.i(_tag, 'OYUNDAN CIKILDI (yarim) skor=${_world.score}');
      AnalyticsService.instance.log('pe_run_quit', {'score': _world.score});
      Navigator.of(context).pop();
    }
  }

  void _playAgain() {
    GameFx.instance.uiTap();
    if (!PlanetEvent.instance.startRun()) {
      // Dugme zaten enerji yokken pasif; yine de yaris durumda hub'a don (enerji orada doldurulur).
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _world = PlanetWorld();
      _cur = PlanetConfig.randomDropTier(_rng);
      _next = PlanetConfig.randomDropTier(_rng);
      _over = false;
      _rescued = false;
      _runBest = 0;
      _floaters.clear();
      _prevVy.clear();
      _comboText = null;
      _cool = 0.3;
    });
  }

  // ------------------------------------------------------------ guclendiriciler
  static const Map<String, int> _powerCost = {
    'shake': PlanetConfig.powerShakeGems,
    'swap': PlanetConfig.powerSwapGems,
    'delete': PlanetConfig.powerDeleteGems,
  };

  /// Odeme penceresi: reklam izle YA DA mucevher ode. true = guclendirici kullanilabilir.
  Future<bool> _payForPower(String kind) async {
    final s = AppStrings.instance;
    final cost = _powerCost[kind]!;
    _paused = true;
    try {
      final c = await showDialog<int>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _PowerDialog(kind: kind, cost: cost),
      );
      if (!mounted || c == null) return false;
      if (c == 1) {
        if (!GameProgress.instance.spendGems(cost, 'planet_power_$kind')) {
          AppLog.w(_tag, 'GUCLENDIRICI elmas yetmedi: $kind (${GameProgress.instance.gems}/$cost)');
          GameFx.instance.denied();
          if (mounted) showGamePopup(context, s.lt('Not enough 💎'));
          return false;
        }
        AppLog.i(_tag, 'GUCLENDIRICI: $kind elmasla (-$cost)');
        AnalyticsService.instance.log('pe_power', {'kind': kind, 'via': 'gems'});
        return true;
      }
      final ok = await AdService.instance.showRewarded(context, placement: 'pe_power_$kind');
      if (!mounted || !ok) return false;
      AppLog.i(_tag, 'GUCLENDIRICI: $kind reklamla');
      AnalyticsService.instance.log('pe_power', {'kind': kind, 'via': 'ad'});
      return true;
    } finally {
      _paused = false;
    }
  }

  Widget _powerBar(AppStrings s) {
    Widget btn(String kind, IconData icon, String label) {
      final enabled = !_over;
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? () => _onPower(kind) : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: (kind == 'delete' && _deleteMode) ? Colors.amber.shade700 : Colors.white12,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  CoinText('🎬 / ${_powerCost[kind]}💎',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          btn('shake', Icons.vibration_rounded, s.lt('Shake')),
          btn('swap', Icons.swap_horiz_rounded, s.lt('Swap')),
          btn('delete', Icons.delete_outline_rounded, s.lt('Delete')),
        ],
      ),
    );
  }

  Future<void> _onPower(String kind) async {
    final s = AppStrings.instance;
    if (_over || _paused) return;
    GameFx.instance.uiTap();
    switch (kind) {
      case 'shake':
        if (_world.bodies.isEmpty) return;
        if (!await _payForPower('shake') || !mounted) return;
        _world.shake(_rng);
        GameFx.instance.planetShake();
        break;
      case 'swap':
        if (_cur == _next) {
          showGamePopup(context, s.lt('Both planets are the same'));
          return;
        }
        if (!await _payForPower('swap') || !mounted) return;
        GameFx.instance.planetSwap();
        setState(() {
          final tmp = _cur;
          _cur = _next;
          _next = tmp;
        });
        break;
      case 'delete':
        if (_world.bodies.isEmpty) return;
        setState(() => _deleteMode = !_deleteMode); // odeme, gezegen secildikten SONRA
        break;
    }
  }

  /// "Sil" modunda bir noktaya dokunuldu: gezegen secilirse odeme sorulur, odenirse silinir.
  Future<void> _tryDelete(double wx, double wy) async {
    if (_paused) return;
    final b = _world.bodyAt(wx, wy);
    if (b == null) return; // bos yere dokundu: modda kal
    setState(() => _marked = b);
    final ok = await _payForPower('delete');
    if (!mounted) return;
    if (ok && _world.removeBody(b)) {
      GameFx.instance.mergeMax();
      AppLog.i(_tag, 'SIL: kademe=${b.tier} silindi');
    }
    setState(() {
      _marked = null;
      _deleteMode = false;
    });
  }

  Future<void> _continueAd() async {
    final s = AppStrings.instance;
    GameFx.instance.uiTap();
    final ok = await AdService.instance.showRewarded(
      context,
      prompt: RewardedPrompt(
        icon: '🎬',
        reward: s.lt('Clear the top planets and continue'),
        placement: 'pe_continue',
      ),
    );
    if (!mounted || !ok) return;
    _world.rescue(count: 6);
    _over = false;
    _rescued = true;
    _cool = 0.5;
    AppLog.i(_tag, 'REKLAMLA DEVAM: skor=${_world.score}');
    AnalyticsService.instance.log('pe_continue', {'score': _world.score});
  }

  // ------------------------------------------------------------ arayuz
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0A2A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // "Ufolar" temasi (AstroFelyx): yildizlar, kayan yildizlar, ucan UFO'lar.
            const Positioned.fill(child: UfosBackground()),
            SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _hud(s),
                  Expanded(child: _board(s)),
                  _powerBar(s),
                  const SizedBox(height: 8),
                ],
              ),
              if (_comboText != null && _comboT > 0)
                Positioned(
                  top: 90,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (_comboT / 1.2).clamp(0.0, 1.0).toDouble(),
                      child: Center(
                        child: Text(
                          '${s.lt('Combo')} $_comboText',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_over) _gameOverCard(s),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _hud(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Row(
        children: [
          GlassCircleButton(icon: Icons.arrow_back_rounded, onTap: _confirmExit),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.lt('Score'), style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
                Text('${_world.score}',
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.0)),
              ],
            ),
          ),
          Column(
            children: [
              Text(s.lt('Next'), style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/planet/pl_$_next.webp', fit: BoxFit.contain),
                    PlanetFaceOverlay(tier: _next, time: _clock, id: 8100),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Column(
            children: [
              Text(s.lt('Best'), style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/planet/pl_${_world.bestTier}.webp', fit: BoxFit.contain),
                    PlanetFaceOverlay(tier: _world.bestTier, time: _clock, id: 8200),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _board(AppStrings s) {
    return LayoutBuilder(builder: (context, c) {
      final sc = math.min(c.maxWidth / PlanetConfig.worldW, c.maxHeight / PlanetConfig.worldH);
      final w = PlanetConfig.worldW * sc;
      final h = PlanetConfig.worldH * sc;
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _setAim(e.localPosition.dx, sc),
            onPointerMove: (e) => _setAim(e.localPosition.dx, sc),
            onPointerUp: (e) {
              if (_deleteMode) {
                _tryDelete(e.localPosition.dx / sc, e.localPosition.dy / sc);
                return;
              }
              _setAim(e.localPosition.dx, sc);
              _drop();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BoardPainter(
                      world: _world,
                      imgs: _imgs,
                      aimX: _aimX,
                      cur: _cur,
                      ready: _cool <= 0 && !_over,
                      floaters: _floaters,
                      marked: _marked,
                      time: _clock,
                    ),
                  ),
                ),
                if (_deleteMode)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(s.lt('Tap the planet you want to delete'),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => setState(() => _deleteMode = false),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_dropped && !_over && !_deleteMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: IgnorePointer(
                      child: Text(
                        s.lt('Slide to aim, release to drop'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _gameOverCard(AppStrings s) {
    final pe = PlanetEvent.instance;
    final energy = pe.energy;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A0F5C), Color(0xFF51299B)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.lt('Game over'),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/planet/pl_${_world.bestTier}.webp', fit: BoxFit.contain),
                    PlanetFaceOverlay(tier: _world.bestTier, time: _clock, id: 8300),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text('${_world.score}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 36, fontWeight: FontWeight.w900)),
              Text(
                s.lt('{0} merges · best combo x{1}', [_world.merges, _world.maxCombo]),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              if (!_rescued) ...[
                CandyButton(
                  style: CandyStyle.blue,
                  height: 50,
                  fontSize: 15,
                  maxLines: 2,
                  label: '🎬 ${s.lt('Continue (watch ad)')}',
                  onTap: _continueAd,
                ),
                const SizedBox(height: 8),
              ],
              CandyButton(
                height: 50,
                fontSize: 16,
                maxLines: 2,
                label: energy >= 1 ? '${s.lt('Play again')}  ⚡$energy' : s.lt('No energy left'),
                onTap: energy >= 1 ? _playAgain : null,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  GameFx.instance.uiTap();
                  Navigator.of(context).pop();
                },
                child: Text(s.lt('Back to event'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tahtayi DUNYA BIRIMLERINDE (100 x 150) cizer; canvas olcekle buyutulur.
class _BoardPainter extends CustomPainter {
  final PlanetWorld world;
  final List<ui.Image?> imgs;
  final double aimX;
  final int cur;
  final bool ready;
  final List<_Floater> floaters;
  final PlanetBody? marked;
  final double time;

  _BoardPainter({
    required this.world,
    required this.imgs,
    required this.aimX,
    required this.cur,
    required this.ready,
    required this.floaters,
    this.marked,
    this.time = 0,
  });

  static const List<Color> _fallback = [
    Color(0xFF9E9E9E), Color(0xFFE53935), Color(0xFFB87333), Color(0xFF80DEEA), Color(0xFFD84315),
    Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFF3949AB), Color(0xFF4DD0E1), Color(0xFFFFCA28),
    Color(0xFFEC407A), Color(0xFFFFB300), Color(0xFF212121),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sc = size.width / PlanetConfig.worldW;
    canvas.save();
    canvas.scale(sc);

    // Kabin zemini.
    final full = Rect.fromLTWH(0, 0, PlanetConfig.worldW, PlanetConfig.worldH);
    final box = RRect.fromRectAndRadius(full, const Radius.circular(3));
    canvas.drawRRect(
      box,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x9914123F), Color(0x991F1A5E)],
        ).createShader(full),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white24,
    );

    // Tehlike cizgisi (kesikli): sayac isledikce kirmiziya doner.
    final t = (world.dangerTimer / PlanetConfig.dangerSeconds).clamp(0.0, 1.0).toDouble();
    final lineColor = Color.lerp(Colors.white24, Colors.redAccent, t)!;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5 + 0.6 * t;
    for (double x = 0; x < PlanetConfig.worldW; x += 5) {
      canvas.drawLine(Offset(x, PlanetConfig.dangerY), Offset(x + 2.5, PlanetConfig.dangerY), linePaint);
    }

    // Nisan: birakilacak gezegen + dikey kilavuz.
    final r = PlanetConfig.radiusOf(cur);
    final ax = aimX.clamp(r, PlanetConfig.worldW - r).toDouble();
    canvas.drawLine(
      Offset(ax, PlanetConfig.dangerY),
      Offset(ax, PlanetConfig.worldH),
      Paint()
        ..color = Colors.white.withOpacity(ready ? 0.12 : 0.05)
        ..strokeWidth = 0.4,
    );
    _planet(canvas, cur, ax, PlanetConfig.dangerY - r - 2, r, 0, ready ? 1.0 : 0.4, id: 900 + cur);

    // Gezegenler.
    for (final b in world.bodies) {
      final worried = world.dangerTimer > 0.2 && b.y - b.r < PlanetConfig.dangerY + 4;
      _planet(canvas, b.tier, b.x, b.y, b.r, b.pop, 1.0, id: b.id, vy: b.vy, worried: worried, joy: b.joy);
    }

    // Silinmek uzere secilen gezegenin etrafina halka.
    final m = marked;
    if (m != null) {
      canvas.drawCircle(
        Offset(m.x, m.y),
        m.r + 1.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.amberAccent,
      );
    }

    // Yukselen puan yazilari.
    for (final f in floaters) {
      final a = (1.0 - f.age).clamp(0.0, 1.0).toDouble();
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            color: f.color.withOpacity(a),
            fontSize: 5.2,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black.withOpacity(a), blurRadius: 1)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(f.x - tp.width / 2, f.y - 4 - f.age * 12));
    }
    canvas.restore();
  }

  void _planet(Canvas c, int tier, double x, double y, double r, double pop, double opacity,
      {int id = 0, double vy = 0, bool worried = false, double joy = 0}) {
    final img = imgs[tier];
    if (img == null) {
      c.drawCircle(Offset(x, y), r, Paint()..color = _fallback[tier].withOpacity(opacity));
      PlanetFace.paint(c,
          tier: tier, id: id, x: x, y: y, bodyR: r, t: time, pop: math.max(pop, joy > 0.02 ? 0.06 : 0.0), vy: vy, worried: worried, opacity: opacity);
      return;
    }
    final d = r * 2 * PlanetConfig.drawScale[tier] * (1 + 0.22 * pop);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: Offset(x, y), width: d, height: d),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    // Sevimli, canli yuz (goz kirpma, dil cikarma, saskinlik...). Bkz. widgets/planet_face.dart
    PlanetFace.paint(c,
        tier: tier,
        id: id,
        x: x,
        y: y,
        bodyR: PlanetFace.bodyRadius(tier, d),
        t: time,
        pop: math.max(pop, joy > 0.02 ? 0.06 : 0.0),
        vy: vy,
        worried: worried,
        opacity: opacity);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

/// Guclendirici odeme penceresi: 1 = mucevher, 2 = reklam izle, null = vazgec.
class _PowerDialog extends StatelessWidget {
  final String kind;
  final int cost;
  const _PowerDialog({required this.kind, required this.cost});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final String title;
    final String desc;
    switch (kind) {
      case 'shake':
        title = s.lt('Shake');
        desc = s.lt('Gives all planets a small push to loosen a stuck pile.');
        break;
      case 'swap':
        title = s.lt('Swap');
        desc = s.lt('Swaps the planet in your hand with the next one.');
        break;
      default:
        title = s.lt('Delete');
        desc = s.lt('Removes the planet you chose.');
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A0F5C), Color(0xFF51299B)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            CandyButton(
              style: CandyStyle.blue,
              height: 50,
              fontSize: 15,
              label: '🎬 ${s.lt('Watch ad')}',
              onTap: () => Navigator.of(context).pop(2),
            ),
            const SizedBox(height: 8),
            CandyButton(
              style: CandyStyle.orange,
              height: 50,
              fontSize: 15,
              label: s.lt('Use for {0} 💎', [cost]),
              onTap: () => Navigator.of(context).pop(1),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.lt('Cancel'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
