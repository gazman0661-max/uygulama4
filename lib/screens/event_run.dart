import 'package:flutter/material.dart';

import '../models/event_pick.dart';
import '../models/game_progress.dart';
import '../models/game_theme.dart';
import '../models/team_race.dart';
import '../services/merge_board_service.dart';
import '../widgets/game_board.dart';
import '../widgets/gem_dialogs.dart';
import 'merge_board_screen.dart';

/// Etkinlik oyunlari: ANA OYUNDAN AYRI. Oyuncu istedigi zaman etkinligi oynar, istedigi zaman normal bolumleri.
/// Her tur rastgele ZOR bolum + farkli tema; ana ilerleme etkilenmez.
class EventRun {
  EventRun._();

  /// Firlat Yarisi: rastgele zor bolum + rastgele tema.
  static Future<void> startThrow(BuildContext context) async {
    if (!GameProgress.instance.hasEnergy) {
      showNoEnergyDialog(context, onChanged: () {});
      return;
    }
    final ch = EventPick.hardChapter();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameBoard(
          theme: EventPick.theme(),
          chapterNumber: ch,
          chapterGoal: ChapterConfig.goalFor(ch),
          eventRun: true,
        ),
      ),
    );
  }

  /// TAKIM YARISI: Firlat modu turu (rastgele zor bolum + tema), ama enerji/puan TAKIM yarisina gider.
  /// Takim secilmemis ya da enerji yoksa false (cagiran ekran haber verir).
  static Future<bool> startTeam(BuildContext context) async {
    final tr = TeamRace.instance;
    if (!tr.canPlay) return false;
    final ch = EventPick.hardChapter();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameBoard(
          theme: EventPick.theme(),
          chapterNumber: ch,
          chapterGoal: ChapterConfig.goalFor(ch),
          eventRun: true,
          teamRace: true,
        ),
      ),
    );
    await tr.flush();
    return true;
  }

  /// Merge Tahtasi Yarisi: ayri etkinlik tahtasi (ana tahta korunur).
  static Future<void> startMerge(BuildContext context) async {
    final svc = MergeBoardService.instance;
    await svc.load();
    if (!context.mounted) return;
    svc.beginEventRun();
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MergeBoardScreen()));
    } finally {
      svc.endEventRun();
    }
  }
}
