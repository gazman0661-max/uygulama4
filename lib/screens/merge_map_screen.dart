import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/merge_board.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import '../services/log_service.dart';
import '../services/merge_board_service.dart';
import '../widgets/ui_kit.dart';
import 'merge_board_screen.dart' show kMbThemes;

/// MOD 2 BOLUM HARITASI: aktif dunyanin bolumleri asagidan yukariya giden bir yol.
/// Biten bolumler yesil tik, aktif bolum parlak (ilerlemesiyle), sonraki 6 bolum
/// onizleme (kural / ozel bolum rozetiyle). Dugume dokununca bolum bilgisi acilir.
/// Tahta tek ve surekli oldugu icin eski bolum tekrar oynanmaz (piyasadaki merge
/// oyunlarindaki gibi: yol ilerlemeyi ve odulleri gosterir).
class MergeMapScreen extends StatefulWidget {
  const MergeMapScreen({super.key});

  @override
  State<MergeMapScreen> createState() => _MergeMapScreenState();
}

class _MergeMapScreenState extends State<MergeMapScreen> {
  static const double _rowH = 120;
  static const double _hdrH = 52;
  static const int _preview = 6;
  static const List<double> _zig = [0.0, -0.55, 0.0, 0.55];

  final MergeBoardService _svc = MergeBoardService.instance;
  late final ScrollController _sc;

  String _lt(String key, [List<Object?> args = const []]) => AppStrings.instance.lt(key, args);

  @override
  void initState() {
    super.initState();
    final cur = _svc.board.chapter;
    final k = math.max(0, cur - 3); // altta kalacak bolum sayisi
    final headers = k == 0 ? 0 : (k + MbState.chaptersPerWorld - 1) ~/ MbState.chaptersPerWorld;
    _sc = ScrollController(initialScrollOffset: k * _rowH + headers * _hdrH);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _info(int n) {
    GameFx.instance.uiTap();
    final cur = _svc.board.chapter;
    final cfg = MbChapter.of(n);
    AppLog.i('mod2', 'harita: bolum $n bilgisi acildi durum=${n < cur ? "bitti" : (n == cur ? "aktif" : "gelecek")} kural=${cfg.rule.name} hedef=${cfg.goal} Lv${cfg.minLevel}-${cfg.maxLevel}');
    AnalyticsService.instance.log('mb_map_info', {'chapter': n, 'current': cur});
    final status = n < cur ? _lt('Completed') : (n == cur ? _lt('In progress') : _lt('Coming up'));
    final levels = cfg.minLevel == cfg.maxLevel
        ? _lt('Item level: Lv{0}', [cfg.maxLevel])
        : _lt('Item levels: Lv{0}-{1}', [cfg.minLevel, cfg.maxLevel]);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2B1B4D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_lt('Chapter {0}', [n]),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(status,
                      style: TextStyle(
                          color: n < cur ? Colors.greenAccent : const Color(0xFFFFE082),
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              if (cfg.titleEn.isNotEmpty)
                Text(_lt(cfg.titleEn),
                    style: TextStyle(
                        color: cfg.isSpecial ? const Color(0xFFFFD54F) : const Color(0xFF80DEEA),
                        fontWeight: FontWeight.w800,
                        fontSize: 15))
              else
                Text(_lt('Normal chapter'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              if (cfg.descEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_lt(cfg.descEn), style: const TextStyle(color: Colors.white70)),
                ),
              const SizedBox(height: 12),
              Text(_lt('Orders to deliver: {0}', [cfg.goal]), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 2),
              Text(_lt('Spawner gives up to Lv{0}', [cfg.maxSpawnLevel]), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 2),
              Text(levels, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 2),
              CoinText(_lt('Chapter reward: +{0} 🪙 · +{1} XP', [cfg.completionBonus, cfg.xpReward]),
                  style: const TextStyle(color: Color(0xFFFFE082), fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = _svc.board.chapter;
    final count = cur + _preview;
    return GameScaffold(
      title: _lt('Chapter map'),
      showCurrency: false,
      bodyColor: const Color(0xFF3B1E6E),
      body: ListView.builder(
        controller: _sc,
        reverse: true,
        padding: const EdgeInsets.only(top: 20, bottom: 24),
        itemCount: count,
        itemBuilder: (ctx, i) => _item(i + 1, cur),
      ),
    );
  }

  /// Bir bolum satiri; dunyanin ilk bolumunun ALTINA dunya basligi konur
  /// (liste asagidan yukari gittigi icin baslik o dunyanin baslangicini gosterir).
  Widget _item(int n, int cur) {
    final row = _row(n, cur);
    if ((n - 1) % MbState.chaptersPerWorld != 0) return row;
    return Column(mainAxisSize: MainAxisSize.min, children: [row, _worldHeader(n)]);
  }

  Widget _worldHeader(int firstChapter) {
    final theme = kMbThemes[MbState.worldOfChapter(firstChapter)];
    final last = firstChapter + MbState.chaptersPerWorld - 1;
    final reached = _svc.board.chapter >= firstChapter;
    return SizedBox(
      height: _hdrH,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: reached ? const Color(0xFFFFE082) : Colors.white24, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: reached ? 1 : 0.5,
                child: Image.asset(theme.byLevel(theme.maxLevel).imagePath, width: 24, height: 24, cacheWidth: 72),
              ),
              const SizedBox(width: 8),
              Text(
                '${AppStrings.instance.t(theme.themeNameKey)}  ·  $firstChapter-$last',
                style: TextStyle(
                    color: reached ? Colors.white : Colors.white60, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(int n, int cur) {
    final cfg = MbChapter.of(n);
    final done = n < cur;
    final current = n == cur;
    final accent = cfg.isSpecial ? const Color(0xFFFFD54F) : (cfg.isRule ? const Color(0xFF80DEEA) : Colors.white);
    final Color fill = done
        ? const Color(0xFF43A047)
        : (current ? const Color(0xFFFFB300) : const Color(0xFF5E4B8B));
    return SizedBox(
      height: _rowH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 6, color: Colors.white.withOpacity(0.14)),
          Align(
            alignment: Alignment(_zig[(n - 1) % 4], 0),
            child: GestureDetector(
              onTap: () => _info(n),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: current ? 76 : 64,
                        height: current ? 76 : 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fill.withOpacity(done || current ? 1 : 0.85),
                          border: Border.all(
                            color: (cfg.isSpecial || cfg.isRule) ? accent : Colors.white,
                            width: current ? 4 : 3,
                          ),
                          boxShadow: current
                              ? [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.6), blurRadius: 16, spreadRadius: 2)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: done
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 36)
                            : Text('$n',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: current ? 28 : 22)),
                      ),
                      if (cfg.isSpecial || cfg.isRule)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: const Color(0xFF2B1B4D), shape: BoxShape.circle, border: Border.all(color: accent, width: 1.5)),
                            child: Icon(cfg.isSpecial ? Icons.star_rounded : Icons.menu_book_rounded, color: accent, size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (current)
                    Text('${_svc.board.chapterProgress}/${cfg.goal}',
                        style: const TextStyle(color: Color(0xFFFFE082), fontWeight: FontWeight.w900, fontSize: 13))
                  else if (cfg.titleEn.isNotEmpty)
                    Text(_lt(cfg.titleEn).replaceFirst(RegExp(r'^[^:]*:\s*'), ''),
                        style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
