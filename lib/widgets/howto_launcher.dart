import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/game_theme.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import 'game_board.dart';
import 'tutorial_coach.dart';
import 'ui_kit.dart';

/// "Nasil Oynanir?": once kisa bir birlestirme-zinciri aciklamasi, sonra
/// Bolum 1 rehberi PRATIK modunda (odul/ilerleme/enerji etkilenmez).
/// Ana menudeki "?" dugmesi ve Ayarlar ayni fonksiyonu kullanir.
Future<void> openHowTo(BuildContext context) async {
  GameFx.instance.uiTap();
  AnalyticsService.instance.log('howto_open');
  final s = AppStrings.instance;
  final theme = ChapterConfig.themeFor(1);
  final imgs = [for (var i = 1; i <= 3; i++) theme.byLevel(i).imagePath];
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => GameAlertDialog(
      title: Text(s.t('howto_chain_title'), textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MergeChainHint(images: imgs),
          const SizedBox(height: 10),
          Text(s.t('howto_chain_body'), textAlign: TextAlign.center),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.t('howto_chain_btn'))),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GameBoard(
      theme: ChapterConfig.themeFor(1),
      chapterNumber: 1,
      chapterGoal: 99,
      practice: true,
    ),
  ));
}
