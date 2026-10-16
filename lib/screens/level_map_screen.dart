import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../models/game_theme.dart';
import '../models/town.dart';
import '../services/game_fx.dart';
import '../widgets/menu_fx.dart';
import '../widgets/ui_kit.dart';
import '../widgets/tutorial_coach.dart';
import 'region_screen.dart';

/// HARITA: 8'er bolumluk BOLGELERIN listesi. Her bolge, dunyasinin arka
/// plani uzerinde bir kart (yildiz ve ilerleme cubugu ile). Aktif bolgeye
/// kadar acik; sonraki 2 bolge kilitli onizleme. Bolgeye dokununca
/// [RegionScreen] acilir (8 bolum dugumu).
///
/// Sinirsiz ilerleme: bolum numarasi arttikca yeni bolgeler (ve dunya temalari
/// 6'sinda bir tekrar eden) gorunur; hedef/zorluk [ChapterConfig]'ten gelir.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

const double _kCardH = 132;
const double _kCardGap = 14;

class _LevelMapScreenState extends State<LevelMapScreen> {
  static const int _lockedPreview = 2;
  Timer? _tick;
  late final ScrollController _sc;

  @override
  void initState() {
    super.initState();
    final cur = regionOfChapter(GameProgress.instance.maxUnlockedChapter);
    _sc = ScrollController(initialScrollOffset: max(0, cur - 2) * (_kCardH + _kCardGap));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _openRegion(int region, bool locked) async {
    if (locked) {
      GameFx.instance.denied();
      return;
    }
    GameFx.instance.uiTap();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegionScreen(region: region)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final tr = s.language == AppLanguage.tr;
    final currentRegion = regionOfChapter(GameProgress.instance.maxUnlockedChapter);
    final count = currentRegion + _lockedPreview;
    return GameScaffold(
      title: AppStrings.instance.lt('Map'),
      trailing: const EnergyPill(),
      bodyColor: const Color(0xFF3B1E6E),
      body: ListView.builder(
        controller: _sc,
        padding: const EdgeInsets.only(top: 16, bottom: 30),
        itemCount: count,
        itemBuilder: (context, i) {
          final region = i + 1;
          return _RegionCard(
            region: region,
            locked: region > currentRegion,
            current: region == currentRegion,
            // YENI OYUNCU: Bolge 1 karti parlar + "Bolgeye dokun!" balonu.
            guide: region == 1 && GameProgress.instance.needsFirstRunGuide,
            onTap: () => _openRegion(region, region > currentRegion),
          );
        },
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final int region;
  final bool locked;
  final bool current;
  final bool guide;
  final VoidCallback onTap;
  const _RegionCard({
    required this.region,
    required this.locked,
    required this.current,
    required this.onTap,
    this.guide = false,
  });

  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final tr = s.language == AppLanguage.tr;
    final gp = GameProgress.instance;
    final first = firstChapterOfRegion(region);
    final world = TownCatalog.worldOfChapter(first);
    final theme = ChapterConfig.themeFor(first);
    final bg = kMenuBackgroundImages[world];
    var stars = 0;
    for (var c = first; c < first + kChaptersPerRegion; c++) {
      stars += gp.starsFor(c);
    }
    final cleared = (gp.maxUnlockedChapter - first).clamp(0, kChaptersPerRegion).toInt();
    final complete = cleared >= kChaptersPerRegion;
    final borderColor = current ? const Color(0xFF9CF25B) : (complete ? const Color(0xFFFFD54F) : Colors.white.withOpacity(0.55));

    Widget background = bg == null
        ? const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF51299B)))
        : Image.asset(bg, fit: BoxFit.cover, alignment: const Alignment(0, -0.25));
    if (locked) background = ColorFiltered(colorFilter: _grey, child: background);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, _kCardGap),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PulseGlow(
              active: guide,
              radius: 24,
              child: _buildCard(background, current, locked, borderColor, tr, s, theme, stars, cleared, complete),
            ),
            if (guide)
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: IgnorePointer(
                  child: Center(
                    child: CoachBubble(text: s.t('tut_tap_region'), arrow: CoachArrow.up, fontSize: 18, maxWidth: 220),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Widget background, bool current, bool locked, Color borderColor, bool tr, AppStrings s,
      GameTheme theme, int stars, int cleared, bool complete) {
    return Container(
        height: _kCardH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: current ? 3.5 : 2.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4)),
            if (current) BoxShadow(color: const Color(0xFF9CF25B).withOpacity(0.5), blurRadius: 16, spreadRadius: 1),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              background,
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xDD000000), Color(0x66000000), Color(0x11000000)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFE082), Color(0xFFFF9800)],
                        ),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Color(0xFF9A4A00), offset: Offset(0, 4))],
                      ),
                      child: Text(
                        '$region',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black38, offset: Offset(0, 2), blurRadius: 2)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AppStrings.instance.lt('REGION')} $region',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFFFE082), height: 1.0),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              s.t(theme.themeNameKey),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Image.asset('assets/images/ui/star_full.webp', width: 16, height: 16),
                              const SizedBox(width: 3),
                              Text('$stars/${kChaptersPerRegion * 3}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: cleared / kChaptersPerRegion,
                                    minHeight: 9,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation(complete ? const Color(0xFFFFD54F) : const Color(0xFF9CF25B)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('$cleared/$kChaptersPerRegion',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: locked ? 0.4 : 1.0,
                      child: Image.asset(theme.byLevel(theme.maxLevel).imagePath, width: 66, height: 66),
                    ),
                  ],
                ),
              ),
              if (locked)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: Image.asset('assets/images/ui/lock.webp', width: 44, height: 44),
                ),
              if (current)
                Positioned(
                  right: 10,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3CC13A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.6),
                    ),
                    child: Text(
                      AppStrings.instance.lt('CONTINUE'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
  }
}
