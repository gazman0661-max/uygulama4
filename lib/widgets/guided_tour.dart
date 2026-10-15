import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../services/analytics_service.dart';
import 'tutorial_coach.dart';

/// REHBERLI TUR (Empires & Puzzles tarzi, "yaptirarak ogret").
///
/// Ekrani karartir, SADECE gosterilen hedefe dokundurur (geri kalan her yer
/// kilitli), hedefin yanina ok + sef maskotlu konusma balonu koyar.
/// Hedefe dokunulunca oyunun KENDI islemi calisir (dokunus delikten gecer);
/// ilgili ekran bunu [GuidedTour.event] ile bildirir ve tur sonraki adima gecer.
///
/// Kullanim:
///  1) Hedef widget'i [TourTarget] ile sar:  TourTarget(id: 'menu_town', child: ...)
///  2) Tur baslat: GuidedTour.instance.start(key: 'tour_town', steps: [...])
///  3) Oyun kodunda ilgili yerde:  GuidedTour.instance.event('town_opened');
///
/// Guvenlik: hedef 6 sn bulunamazsa adim sessizce atlanir; 12 sn ayni adimda
/// kalinirsa kucuk bir "Atla" cikar. Oyuncu asla kilitli kalmaz.

/// Tek bir tur adimi.
class TourStep {
  /// Vurgulanacak [TourTarget] kimligi. null ise sadece konusma (Devam butonu).
  final String? target;

  /// Bu olay gelince sonraki adima gecilir (hedefli adimlar icin). null ise
  /// hedefe dokunulunca [GuidedTour.event] cagrisini bekler; dialog adimlarinda
  /// "Devam" dokunusu ilerletir.
  final String? waitFor;

  /// Metin anahtarlari (AppStrings) ya da dogrudan metin: [text] once denenir.
  final String textKey;

  /// Balon okunun yonu (hedefe gore balonun yeri otomatik secilir).
  final bool bubbleAbove;

  /// Hedefin etrafinda nabiz atan halka yerine parlama yerine dokunma eli de goster.
  final bool showHand;

  /// Tek dokunusla gecilen dialog adiminda dugme metni anahtari.
  final String buttonKey;

  const TourStep({
    this.target,
    this.waitFor,
    required this.textKey,
    this.bubbleAbove = false,
    this.showHand = true,
    this.buttonKey = 'tour_continue',
  });

  bool get isDialog => target == null;
}

/// Hedef widget'larin kayit defteri + tur denetleyicisi.
class GuidedTour extends ChangeNotifier {
  GuidedTour._();
  static final GuidedTour instance = GuidedTour._();

  /// MaterialApp'in navigatorKey'i (main.dart): overlay butun sayfalarin ve
  /// alt panellerin USTUNE, kok Overlay'e konur.
  static GlobalKey<NavigatorState>? navKey;

  final Map<String, GlobalKey> _targets = <String, GlobalKey>{};
  OverlayEntry? _entry;
  List<TourStep> _steps = const [];
  int _index = 0;
  String? _tourKey;
  DateTime _stepStart = DateTime.now();

  bool get active => _entry != null && _index < _steps.length;
  TourStep? get current => active ? _steps[_index] : null;
  String? get tourKey => _tourKey;
  Duration get stepAge => DateTime.now().difference(_stepStart);

  // ── Hedef kaydi ──
  GlobalKey keyFor(String id) => _targets.putIfAbsent(id, () => GlobalKey(debugLabel: 'tour_$id'));

  /// Hedefin ekrandaki dikdortgeni (yoksa null).
  Rect? rectOf(String id) {
    final ctx = _targets[id]?.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final topLeft = ro.localToGlobal(Offset.zero);
    return topLeft & ro.size;
  }

  // ── Tur yonetimi ──

  /// Tur baslatir. [key] daha once gorulduyse (tutSeen) hicbir sey yapmaz.
  /// Zaten baska bir tur sürüyorsa yeni tur baslamaz.
  bool start({required String key, required List<TourStep> steps, VoidCallback? onDone}) {
    final gp = GameProgress.instance;
    if (gp.tutSeen(key) || active || steps.isEmpty) return false;
    final nav = navKey?.currentState;
    final overlay = nav?.overlay;
    if (overlay == null) return false;
    _tourKey = key;
    _steps = steps;
    _index = 0;
    _onDone = onDone;
    _stepStart = DateTime.now();
    _entry = OverlayEntry(builder: (_) => const _TourOverlay());
    overlay.insert(_entry!);
    AnalyticsService.instance.log('${key}_start');
    notifyListeners();
    return true;
  }

  VoidCallback? _onDone;

  /// Oyun kodu "su oldu" der: [waitFor] ile eslesirse sonraki adima gecilir.
  void event(String name) {
    final st = current;
    if (st == null) return;
    if (st.waitFor == name) _advance();
  }

  /// Dialog adiminda "Devam" dokunusu.
  void next() {
    final st = current;
    if (st == null) return;
    if (st.isDialog) _advance();
  }

  void _advance() {
    AnalyticsService.instance.log('${_tourKey}_step${_index + 1}');
    _index++;
    _stepStart = DateTime.now();
    if (_index >= _steps.length) {
      _finish(completed: true);
    } else {
      notifyListeners();
    }
  }

  /// Hedef bulunamadi / oyuncu atladi: tur biter ve "goruldu" sayilir
  /// (tekrar tekrar karsisina cikmasin).
  void skip() => _finish(completed: false);

  void _finish({required bool completed}) {
    final key = _tourKey;
    final done = _onDone;
    _entry?.remove();
    _entry = null;
    _steps = const [];
    _index = 0;
    _tourKey = null;
    _onDone = null;
    if (key != null) {
      GameProgress.instance.markTutSeen(key);
      AnalyticsService.instance.log(completed ? '${key}_done' : '${key}_skipped');
    }
    notifyListeners();
    if (done != null) done();
  }
}

/// Bir widget'i tur hedefi yapar. Tur yokken hicbir etkisi yoktur.
class TourTarget extends StatelessWidget {
  final String id;
  final Widget child;
  const TourTarget({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: GuidedTour.instance.keyFor(id), child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Overlay
// ─────────────────────────────────────────────────────────────────────

class _TourOverlay extends StatefulWidget {
  const _TourOverlay();

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _lastIndex = -1;
  DateTime? _missingSince;

  @override
  void initState() {
    super.initState();
    GuidedTour.instance.addListener(_onTour);
    // Hedefin yeri sayfa kaydirma/animasyonla degisebilir: her karede yeniden olc.
    _ticker = createTicker((_) {
      final t = GuidedTour.instance;
      final st = t.current;
      if (st != null && st.target != null) {
        final r = t.rectOf(st.target!);
        if (r == null) {
          _missingSince ??= DateTime.now();
          if (DateTime.now().difference(_missingSince!) > const Duration(seconds: 6)) {
            _missingSince = null;
            t.skip();
            return;
          }
        } else {
          _missingSince = null;
        }
      }
      if (mounted) setState(() {});
    })..start();
  }

  void _onTour() {
    _missingSince = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GuidedTour.instance.removeListener(_onTour);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = GuidedTour.instance;
    final st = t.current;
    if (st == null) return const SizedBox.shrink();
    final s = AppStrings.instance;
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final text = s.t(st.textKey);

    // ── Sadece konusma adimi: tam ekran karartma + ortada balon ──
    if (st.isDialog) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(color: Colors.black.withOpacity(0.62)),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: size.height * 0.5 - 90,
            child: _MentorDialog(text: text, buttonLabel: s.t(st.buttonKey), onButton: t.next),
          ),
          _SkipButton(show: t.stepAge > const Duration(seconds: 12), onSkip: t.skip),
        ],
      );
    }

    // ── Hedefli adim ──
    final rect = t.rectOf(st.target!);
    if (rect == null) {
      // Hedef henuz yok (sayfa geciyor): dokunusu engelleme, karartma da koyma.
      return const SizedBox.shrink();
    }
    final hole = rect.inflate(8);
    final center = hole.center;
    final targetInTopHalf = center.dy < size.height * 0.5;
    // Balon, hedefin ters yaninda durur (hedef ustteyse altinda, altaysa ustunde).
    final bubbleBelow = st.bubbleAbove ? false : targetInTopHalf;
    final bubbleTop = bubbleBelow ? (hole.bottom + 54).clamp(pad.top + 8, size.height - 220).toDouble() : null;
    final bubbleBottom = bubbleBelow ? null : (size.height - hole.top + 54).clamp(8.0, size.height - pad.top - 120).toDouble();

    return Stack(
      children: [
        // Karartma: delik disinda her yeri yakalar, delik ICINDE dokunusu alttaki
        // widget'a birakir (hitTest false).
        Positioned.fill(child: _HoleBarrier(hole: hole, radius: 18)),
        // Hedefi cevreleyen nabiz halkasi
        Positioned.fill(child: IgnorePointer(child: _HoleGlow(hole: hole, radius: 18))),
        // Ok (hedefe dogru)
        Positioned(
          left: center.dx - 24,
          top: bubbleBelow ? hole.bottom + 2 : null,
          bottom: bubbleBelow ? null : size.height - hole.top + 2,
          child: IgnorePointer(
            child: _BobArrow(pointUp: bubbleBelow),
          ),
        ),
        if (st.showHand)
          CoachTapHand(position: Offset(center.dx, center.dy + (hole.height * 0.15))),
        // Konusma balonu
        Positioned(
          left: 14,
          right: 14,
          top: bubbleTop,
          bottom: bubbleBottom,
          child: IgnorePointer(child: _MentorBubble(text: text)),
        ),
        _SkipButton(show: t.stepAge > const Duration(seconds: 12), onSkip: t.skip),
      ],
    );
  }
}

/// Delik disinda dokunusu yutan, delik icinde gecirgen katman.
class _HoleBarrier extends LeafRenderObjectWidget {
  final Rect hole;
  final double radius;
  const _HoleBarrier({required this.hole, required this.radius});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHoleBarrier(hole, radius);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderHoleBarrier ro) {
    ro
      ..hole = hole
      ..radius = radius;
  }
}

class _RenderHoleBarrier extends RenderBox {
  Rect _hole;
  double _radius;
  _RenderHoleBarrier(this._hole, this._radius);

  set hole(Rect v) {
    if (v == _hole) return;
    _hole = v;
    markNeedsPaint();
  }

  set radius(double v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Global koordinat: bu katman tum ekrani kapladigi icin yerel == global (sol ust 0,0).
    if (_hole.contains(position)) return false; // delik: alttaki widget alir
    result.add(BoxHitTestEntry(this, position));
    return true; // delik disi: yut
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final full = Offset.zero & size;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full.shift(offset))
      ..addRRect(RRect.fromRectAndRadius(_hole.shift(offset), Radius.circular(_radius)));
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.72));
  }
}

class _HoleGlow extends StatefulWidget {
  final Rect hole;
  final double radius;
  const _HoleGlow({required this.hole, required this.radius});

  @override
  State<_HoleGlow> createState() => _HoleGlowState();
}

class _HoleGlowState extends State<_HoleGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return CustomPaint(
          painter: _GlowPainter(widget.hole, widget.radius, t),
        );
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Rect hole;
  final double radius;
  final double t;
  _GlowPainter(this.hole, this.radius, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(hole.inflate(2 + 3 * t), Radius.circular(radius + 2));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = kCoachGlow.withOpacity(0.55 + 0.45 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 4 * t),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withOpacity(0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter o) => o.hole != hole || o.t != t || o.radius != radius;
}

class _BobArrow extends StatefulWidget {
  final bool pointUp;
  const _BobArrow({required this.pointUp});

  @override
  State<_BobArrow> createState() => _BobArrowState();
}

class _BobArrowState extends State<_BobArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final d = 8 * Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, widget.pointUp ? d : -d),
          child: Icon(
            widget.pointUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 48,
            color: kCoachOrange,
            shadows: const [Shadow(color: Colors.white, blurRadius: 10), Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        );
      },
    );
  }
}

/// Dokunma ipucu eli (hedefin uzerinde basip birakir).
class CoachTapHand extends StatefulWidget {
  final Offset position;
  const CoachTapHand({super.key, required this.position});

  @override
  State<CoachTapHand> createState() => _CoachTapHandState();
}

class _CoachTapHandState extends State<CoachTapHand> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 4,
      top: widget.position.dy - 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final press = t < 0.5 ? t / 0.5 : 1 - (t - 0.5) / 0.5;
            return Transform.scale(
              scale: 1.0 - 0.18 * press,
              child: Transform.translate(
                offset: Offset(0, 6 * press),
                child: const Icon(
                  Icons.touch_app,
                  size: 46,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final bool show;
  final VoidCallback onSkip;
  const _SkipButton({required this.show, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final top = MediaQuery.of(context).padding.top + 6;
    return Positioned(
      right: 10,
      top: top,
      child: GestureDetector(
        onTap: onSkip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
          child: Text(
            AppStrings.instance.t('tour_skip'),
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
          ),
        ),
      ),
    );
  }
}

/// Sef maskotu + beyaz konusma balonu (referans oyundaki gibi). Dokunusu yutmaz.
class _MentorBubble extends StatelessWidget {
  final String text;
  const _MentorBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 34, top: 10),
            padding: const EdgeInsets.fromLTRB(46, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF8A5A2B), width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3A2410),
              ),
            ),
          ),
          const Positioned(left: 0, top: 0, child: _MentorAvatar()),
        ],
      ),
    );
  }
}

class _MentorAvatar extends StatelessWidget {
  const _MentorAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFE9C7),
        border: Border.all(color: const Color(0xFFFF9A1F), width: 3.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 6)],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.asset('assets/images/mascot_chef.webp', fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Sadece konusma adimi: balon + "Devam" butonu.
class _MentorDialog extends StatelessWidget {
  final String text;
  final String buttonLabel;
  final VoidCallback onButton;
  const _MentorDialog({required this.text, required this.buttonLabel, required this.onButton});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MentorBubble(text: text),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onButton,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB444), Color(0xFFFF8A1F)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
