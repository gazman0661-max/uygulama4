import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/mb_story.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import '../services/log_service.dart';

/// Hikaye sahnesini tam ekran diyalog olarak gosterir. Sef (mascot_chef.webp) HER sahnede
/// ayni resimdir; duygu kodla verilir (ziplama, titreme, egilme, solma + kafa ustu emoji).
/// Ekrana dokun = sonraki satir / yazi hizlica biter. "Gec" = sahneyi kapatir.
Future<void> showStoryScene(BuildContext context, StoryScene scene) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'story',
    barrierColor: Colors.black.withOpacity(0.82),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _StoryOverlay(scene: scene),
    transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );
}

class _StoryOverlay extends StatefulWidget {
  final StoryScene scene;
  const _StoryOverlay({required this.scene});

  @override
  State<_StoryOverlay> createState() => _StoryOverlayState();
}

class _StoryOverlayState extends State<_StoryOverlay> with TickerProviderStateMixin {
  late final AnimationController _loop; // surekli: nefes/ziplama
  late final AnimationController _pop; // her satirda 0 -> 1
  Timer? _typer;
  int _idx = 0;
  int _shown = 0;

  StoryLine get _line => widget.scene.lines[_idx];
  String _text(StoryLine l) => AppStrings.instance.lt(l.text);
  String _name(StoryLine l) => AppStrings.instance.lt(l.who);

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _startLine();
  }

  @override
  void dispose() {
    _typer?.cancel();
    _loop.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _startLine() {
    _typer?.cancel();
    _shown = 0;
    _pop.forward(from: 0);
    final full = _text(_line);
    _typer = Timer.periodic(const Duration(milliseconds: 24), (t) {
      if (!mounted) return;
      if (_shown >= full.characters.length) {
        t.cancel();
        return;
      }
      setState(() => _shown++);
    });
  }

  bool get _typing => _shown < _text(_line).characters.length;

  void _tap() {
    if (_typing) {
      _typer?.cancel();
      setState(() => _shown = _text(_line).characters.length);
      return;
    }
    GameFx.instance.uiTap();
    if (_idx >= widget.scene.lines.length - 1) {
      AppLog.i('story', 'sahne tamamlandi: ${widget.scene.id}');
      AnalyticsService.instance.log('story_done', {'id': widget.scene.id});
      Navigator.of(context).pop();
      return;
    }
    setState(() => _idx++);
    _startLine();
  }

  void _skip() {
    GameFx.instance.uiTap();
    AppLog.i('story', 'sahne atlandi: ${widget.scene.id} (satir ${_idx + 1}/${widget.scene.lines.length})');
    AnalyticsService.instance.log('story_skip', {'id': widget.scene.id, 'line': _idx + 1});
    Navigator.of(context).pop();
  }

  // ── Sefin duygusu ──────────────────────────────────────────
  static const List<double> _gray = <double>[
    0.55, 0.36, 0.09, 0, 0, //
    0.17, 0.74, 0.09, 0, 0,
    0.17, 0.36, 0.47, 0, 0,
    0, 0, 0, 1, 0,
  ];

  String _moodEmoji(StoryMood m) {
    switch (m) {
      case StoryMood.happy:
        return '✨';
      case StoryMood.shock:
        return '❗';
      case StoryMood.sad:
        return '💧';
      case StoryMood.think:
        return '💭';
      case StoryMood.normal:
        return '';
    }
  }

  Widget _chef(StoryMood mood, double speakerDim) {
    return AnimatedBuilder(
      animation: Listenable.merge([_loop, _pop]),
      builder: (_, __) {
        final t = _loop.value;
        final pop = Curves.easeOutBack.transform(_pop.value.clamp(0.0, 1.0).toDouble());
        double dx = 0, dy = math.sin(t * 2 * math.pi) * 4, rot = 0, scale = 1;
        switch (mood) {
          case StoryMood.happy:
            dy = -(math.sin(t * 4 * math.pi)).abs() * 16;
            break;
          case StoryMood.shock:
            scale = 1 + 0.14 * (1 - _pop.value);
            dx = math.sin(t * 40) * 4 * (1 - _pop.value);
            break;
          case StoryMood.sad:
            rot = -0.07;
            dy = 6 + math.sin(t * 2 * math.pi) * 2;
            break;
          case StoryMood.think:
            rot = math.sin(t * 2 * math.pi) * 0.06;
            break;
          case StoryMood.normal:
            break;
        }
        Widget img = Image.asset('assets/images/mascot_chef.webp', fit: BoxFit.contain);
        if (mood == StoryMood.sad) {
          img = ColorFiltered(colorFilter: const ColorFilter.matrix(_gray), child: img);
        }
        final emoji = _moodEmoji(mood);
        return Opacity(
          opacity: speakerDim,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scale: scale * (0.94 + 0.06 * pop),
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 190,
                  height: 230,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: img),
                      if (emoji.isNotEmpty)
                        Positioned(
                          top: -6,
                          right: 4,
                          child: Opacity(
                            opacity: pop.clamp(0.0, 1.0).toDouble(),
                            child: Text(emoji, style: const TextStyle(fontSize: 34)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _guest(StoryLine l) {
    return AnimatedBuilder(
      animation: Listenable.merge([_loop, _pop]),
      builder: (_, __) {
        final pop = Curves.easeOutBack.transform(_pop.value.clamp(0.0, 1.0).toDouble());
        final dy = math.sin(_loop.value * 2 * math.pi) * 5;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: 0.7 + 0.3 * pop,
            child: Container(
              width: 104,
              height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.14),
                border: Border.all(color: Colors.white54, width: 2),
              ),
              child: Text(l.emoji, style: const TextStyle(fontSize: 58)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = _line;
    final accent = Color(MbStory.accentFor(widget.scene));
    final full = _text(line);
    final shownText = full.characters.take(_shown).toString();
    // Sef konusmuyorsa soluk ama gorunur; konusurken tam.
    final chefMood = line.isChef ? line.mood : StoryMood.normal;
    final chefDim = line.isChef ? 1.0 : 0.72;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, accent.withOpacity(0.30)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  right: 12,
                  child: GestureDetector(
                    onTap: _skip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: Text(
                        AppStrings.instance.lt('Skip'),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            line.isChef ? const SizedBox(width: 104) : _guest(line),
                            _chef(chefMood, chefDim),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 132),
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E7),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: accent, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name(line),
                                style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shownText,
                                style: const TextStyle(
                                  color: Color(0xFF3B2A6B),
                                  fontSize: 19,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Opacity(
                                  opacity: _typing ? 0 : 0.55,
                                  child: Text(
                                    '${AppStrings.instance.lt('Tap to continue')}  ▶   ${_idx + 1}/${widget.scene.lines.length}',
                                    style: const TextStyle(color: Color(0xFF3B2A6B), fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
