import 'dart:math' as math;

import 'game_progress.dart';
import 'game_theme.dart';

/// ETKINLIK OTURUMLARI (Firlat Yarisi): ana oyundan ayri, her turda RASTGELE ZOR bolum + FARKLI tema.
class EventPick {
  EventPick._();

  static final math.Random _rng = math.Random();
  static int _lastTheme = -1;

  static const List<GameTheme> _themes = <GameTheme>[
    FastFoodTheme(),
    CafeTheme(),
    MagicTheme(),
    PirateTheme(),
    IceTheme(),
    SpaceTheme(),
  ];

  /// Bir onceki turdan FARKLI rastgele tema.
  static GameTheme theme() {
    var i = _rng.nextInt(_themes.length);
    var guard = 0;
    while (i == _lastTheme && guard < 10) {
      i = _rng.nextInt(_themes.length);
      guard++;
    }
    _lastTheme = i;
    return _themes[i];
  }

  /// Rastgele ZOR bolum numarasi: rahat (5'in kati) bolumler atlanir; boss ile sinirli atis / zamanli
  /// bolumler 3 kat agirlikla secilir. Zorluk oyuncunun ilerlemesine gore yukselir.
  static int hardChapter({int avoid = -1}) {
    final base = GameProgress.instance.maxUnlockedChapter;
    final lo = (base + 8).clamp(20, 70).toInt();
    final cands = <int>[];
    for (var c = lo; c < lo + 30; c++) {
      if (c == avoid) continue;
      final kind = ChapterConfig.kindFor(c);
      if (kind == ChapterKind.easy) continue;
      cands.add(c);
      if (kind == ChapterKind.boss || ChapterConfig.variantFor(c) != ChapterVariant.none) {
        cands.add(c);
        cands.add(c);
      }
    }
    return cands[_rng.nextInt(cands.length)];
  }
}
