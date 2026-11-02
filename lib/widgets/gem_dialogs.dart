import 'ui_kit.dart';
import 'energy_bar.dart';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../screens/gem_shop_screen.dart';
import '../services/game_fx.dart';

/// FIRLAT modunda enerji bittiğinde gösterilen pencere: "Daha Fazla Enerji?" (mücevherle
/// tam dolum ya da reklam izle). Ana harita ve oyun ekranı ortak kullanır.
/// [onChanged] enerji/mücevher değişince çağrılır. (Sürükle-Bırak modu kendi enerjisiyle
/// showEnergyPopup(mode: EnergyMode.merge) çağırır.)
Future<void> showNoEnergyDialog(BuildContext context, {VoidCallback? onChanged}) {
  return showEnergyPopup(context, mode: EnergyMode.throwMode, onChanged: onChanged);
}

/// Mücevher yetmediğinde: iptal ya da mağazayı aç.
Future<void> showNotEnoughGemsDialog(BuildContext context, {VoidCallback? onChanged}) {
  final s = AppStrings.instance;
  return showDialog<void>(
    context: context,
    builder: (ctx) => GameAlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(s.t('not_enough_gems_title')),
      content: Text(s.t('not_enough_gems_body')),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            openGemShop(context).then((_) => onChanged?.call());
          },
          child: Text(s.t('gem_shop_open')),
        ),
      ],
    ),
  );
}

Future<void> openGemShop(BuildContext context) {
  GameFx.instance.uiTap();
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GemShopScreen()));
}

/// Güçlendirici ikon/isim/açıklama yardımcıları (oyun ve mağaza ortak).
IconData boosterIcon(BoosterType t) {
  switch (t) {
    case BoosterType.aimGuide:
      return Icons.my_location;
    case BoosterType.joker:
      return Icons.auto_awesome;
    case BoosterType.revive:
      return Icons.favorite;
    case BoosterType.hammer:
      return Icons.hardware;
    case BoosterType.upgrade:
      return Icons.arrow_circle_up;
    case BoosterType.fan:
      return Icons.air;
  }
}

String boosterNameKey(BoosterType t) {
  switch (t) {
    case BoosterType.aimGuide:
      return 'booster_aim_name';
    case BoosterType.joker:
      return 'booster_joker_name';
    case BoosterType.revive:
      return 'booster_revive_name';
    case BoosterType.hammer:
      return 'booster_hammer_name';
    case BoosterType.upgrade:
      return 'booster_upgrade_name';
    case BoosterType.fan:
      return 'booster_fan_name';
  }
}

String boosterDescKey(BoosterType t) {
  switch (t) {
    case BoosterType.aimGuide:
      return 'booster_aim_desc';
    case BoosterType.joker:
      return 'booster_joker_desc';
    case BoosterType.revive:
      return 'booster_revive_desc';
    case BoosterType.hammer:
      return 'booster_hammer_desc';
    case BoosterType.upgrade:
      return 'booster_upgrade_desc';
    case BoosterType.fan:
      return 'booster_fan_desc';
  }
}
