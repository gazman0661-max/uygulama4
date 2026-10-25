import '../widgets/ui_kit.dart';
import 'package:flutter/material.dart';
import '../models/game_progress.dart';
import '../localization/app_strings.dart';
import '../services/ad_service.dart';
import '../services/game_fx.dart';
import '../widgets/rewarded_prompt.dart';

/// Ana menudeki gorevler ikonunun YANINDAKI "Yukseltmeler" ikonuyla
/// acilan ekran. Eskiden bu 3 kart (atis hizi / sans / siparis slotu)
/// ana menude dogrudan, "Oyna" butonunun hemen altinda, sayfayi
/// asagi kaydirarak gorulen bir liste halinde duruyordu - simdi
/// Gorevler ekraniyla ayni mantikla ayri bir ekrana tasindi, ana
/// menude sadece kucuk bir kisayol ikonu var.
class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key});

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  void _buyUpgrade(bool Function() buyFn, String successMessage) {
    final bought = buyFn();
    if (bought) {
      GameFx.instance.reward();
    } else {
      GameFx.instance.denied();
    }
    setState(() {});
    if (!mounted) return;
    showGamePopup(context, bought ? successMessage : AppStrings.instance.t('insufficient_coins'));
  }

  bool get _tr => AppStrings.instance.language == AppLanguage.tr;

  /// v118: 10.000+ maliyetli kalemde reklam izle -> o kalem %25 ucuzlar (satin alinana kadar kalir).
  Future<void> _discountAd(String item, int baseCost) async {
    final gp = GameProgress.instance;
    if (!gp.canGetAdDiscount(item, baseCost)) return;
    GameFx.instance.uiTap();
    final ok = await watchRewardedAd(
      context,
      prompt: RewardedPrompt(
        icon: '🏷️',
        title: AppStrings.instance.lt('25% Off'),
        reward: AppStrings.instance.lt('This upgrade is 25% cheaper'),
        note: AppStrings.instance.lt('Discounts left today: {0}', [gp.adQuotaRemaining('discount')]),
        placement: 'upgrade_discount',
      ),
    );
    if (!ok || !mounted) return;
    if (gp.claimAdDiscount(item, baseCost)) {
      GameFx.instance.reward();
      setState(() {});
      showGamePopup(context, AppStrings.instance.lt('Discount applied! 🏷️'), autoCloseMs: 1500);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final progress = GameProgress.instance;
    final tLvl = progress.throwCooldownLevel;
    final lLvl = progress.luckLevel;
    final tBase = tLvl < GameProgress.maxUpgradeLevel ? GameProgress.throwCooldownCost[tLvl] : null;
    final lBase = lLvl < GameProgress.maxUpgradeLevel ? GameProgress.luckCost[lLvl] : null;

    return GameScaffold(
      title: s.t('shop_upgrades'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UpgradeCard(
            icon: Icons.bolt,
            iconColor: Colors.orange,
            title: s.t('upgrade_throw_title'),
            description: s.t('upgrade_throw_desc'),
            level: tLvl,
            maxLevel: GameProgress.maxUpgradeLevel,
            nextCost: tBase == null ? null : progress.throwCooldownCostNow(),
            baseCost: tBase,
            discounted: progress.hasAdDiscount('throw'),
            onAd: tBase != null && progress.canGetAdDiscount('throw', tBase) ? () => _discountAd('throw', tBase) : null,
            onBuy: () => _buyUpgrade(
              GameProgress.instance.buyThrowCooldownUpgrade,
              s.t('upgrade_success_throw'),
            ),
          ),
          const SizedBox(height: 12),
          _UpgradeCard(
            icon: Icons.auto_awesome,
            iconColor: Colors.purple,
            title: s.t('upgrade_luck_title'),
            description: s.t('upgrade_luck_desc'),
            level: lLvl,
            maxLevel: GameProgress.maxUpgradeLevel,
            nextCost: lBase == null ? null : progress.luckCostNow(),
            baseCost: lBase,
            discounted: progress.hasAdDiscount('luck'),
            onAd: lBase != null && progress.canGetAdDiscount('luck', lBase) ? () => _discountAd('luck', lBase) : null,
            onBuy: () => _buyUpgrade(
              GameProgress.instance.buyLuckUpgrade,
              s.t('upgrade_success_luck'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.instance.lt('Tip: every Speed/Luck level gives +1% chapter coins.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.brown.shade400, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Tek bir yukseltme karti - ikon + baslik/aciklama + seviye + "satin
/// al" butonu (fiyat ya da MAX rozeti). (Eskiden main_menu_screen.dart
/// icindeydi, yukseltmeler ayri bir ekrana tasinirken buraya alindi -
/// gorunumu degismedi.)
class _UpgradeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final int level;
  final int maxLevel;
  final int? nextCost;
  final int? baseCost;
  final bool discounted;
  final VoidCallback? onAd;
  final VoidCallback onBuy;

  const _UpgradeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.level,
    required this.maxLevel,
    required this.nextCost,
    required this.onBuy,
    this.baseCost,
    this.discounted = false,
    this.onAd,
  });

  @override
  Widget build(BuildContext context) {
    final isMaxed = nextCost == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Text(
                  '${AppStrings.instance.t('level_of')} $level / $maxLevel',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade400, fontWeight: FontWeight.w600),
                ),
                if (discounted && baseCost != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '🏷️ -25%  (${baseCost})',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none),
                    ),
                  ),
                if (onAd != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: onAd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade400, width: 1.5),
                        ),
                        child: Text(
                          AppStrings.instance.lt('📺 Watch ad: 25% off'),
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.green.shade800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CandyButton(
            width: 104,
            height: 42,
            fontSize: 14,
            style: CandyStyle.orange,
            leading: isMaxed ? null : Image.asset('assets/images/coin_icon.webp', width: 16, height: 16),
            label: isMaxed ? AppStrings.instance.t('max') : '$nextCost',
            onTap: isMaxed ? null : onBuy,
          ),
        ],
      ),
    );
  }
}
