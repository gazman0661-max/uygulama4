import '../widgets/guided_tour.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/album.dart';
import '../models/game_progress.dart';
import '../models/town.dart';
import '../services/ad_service.dart';
import '../services/game_fx.dart';
import '../widgets/rewarded_prompt.dart';
import '../utils/duration_format.dart';
import '../widgets/menu_fx.dart' show Bobbing;
import '../widgets/ui_kit.dart';

/// KASABA: 6 dunyanin binasini haritada goren, kaydirilip yakinlastirilan
/// bir ada. Her bina seviyesine gore pasif COIN URETIR (depoda birikir,
/// dokunarak toplanir) ve ayrica kalici bir bonus verir.

/// Ozel bina gorseli (assets/images/town/b{dunya}_s{1..3}.webp) HAZIR olan dunyalar.
/// Yeni dunya gorselleri eklenince sadece bu kumeye numarasini ekle; olmayan
/// dunyalar eski obje (tier) gorseliyle cizilmeye devam eder.
const Set<int> _kBuildingArtWorlds = {0, 1, 2, 3, 4, 5};

/// Seviye 1-3 -> s1, 4-7 -> s2, 8-10 -> s3 (seviye 0'da s1 silueti kullanilir).
String _buildingImage(int world, int level) {
  if (_kBuildingArtWorlds.contains(world)) {
    final stage = level <= 3 ? 1 : (level <= 7 ? 2 : 3);
    return 'assets/images/town/b${world}_s$stage.webp';
  }
  return AlbumCatalog.themes[world].byLevel(_TownScreenState._tierFor(level)).imagePath;
}

/// v200: insaatci penceresi (ust cubuktaki insaatci rozetinden ve kasabadan acilir).
void showBuilderDialog(BuildContext context, {VoidCallback? onChanged}) {
  GameFx.instance.uiTap();
  final gp = GameProgress.instance;
  final maxed = gp.builderCount >= TownCatalog.maxBuilders;
  showDialog<void>(
    context: context,
    builder: (ctx) => GameAlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(AppStrings.instance.lt('🔨 Builders'),
          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(
        (AppStrings.instance.lt('You can upgrade as many buildings at once as you have builders.\\nRight now: {0}/{1} busy.', [gp.townBusyBuilders, gp.builderCount])) +
            (maxed ? (AppStrings.instance.lt('\\n\\nYou have the maximum builders!')) : ''),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (!maxed)
          FilledButton(
            onPressed: gp.gems >= gp.nextBuilderGemCost
                ? () {
                    if (GameProgress.instance.buyBuilder()) {
                      GameFx.instance.reward();
                      Navigator.of(ctx).pop();
                      onChanged?.call();
                      if (context.mounted) {
                        showGamePopup(context, AppStrings.instance.lt('New builder hired!'));
                      }
                    }
                  }
                : null,
            child: Text(AppStrings.instance.lt('Builder #{0}  💎 {1}', [gp.builderCount + 1, gp.nextBuilderGemCost])),
          ),
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppStrings.instance.lt('Close'))),
      ],
    ),
  );
}

/// v201: harita gorseli (assets/images/town/map_bg.webp, 1120x1592) = 800x1072 ada + etrafinda
/// deniz boslugu (sol/sag 160, ust 240, alt 280). Boylece binalar ust cubuk, yan ikonlar ve
/// alt dock'un arkasindan kaydirilarak cikarilabilir.
const double _kCanvasW = 1120;
const double _kCanvasH = 1592;

/// 6 dunya binasinin harita uzerindeki merkez noktalari (ada koordinati + bosluk ofseti 160,240).
/// Sira: alt-sol (0) -> alt-sag -> orta -> sag-ust -> sol-ust -> ust-orta (5).
const List<Offset> _kPlots = [
  Offset(330, 1048),
  Offset(781, 1044),
  Offset(575, 887),
  Offset(790, 606),
  Offset(321, 606),
  Offset(557, 463),
];

/// Kalan insaat suresi: "2g 5sa", "3sa 12dk" veya "07:42".
String _fmtRemain(Duration d, bool tr) {
  final total = d.inSeconds.clamp(0, 1 << 30).toInt();
  final days = total ~/ 86400;
  final hours = (total % 86400) ~/ 3600;
  final mins = (total % 3600) ~/ 60;
  final secs = total % 60;
  if (days > 0) return AppStrings.instance.lt('{0}d {1}h||{0}g {1}sa', [days, hours]);
  if (hours > 0) return AppStrings.instance.lt('{0}h {1}m', [hours, mins]);
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

class _Pop {
  final int id;
  final int world;
  final int amount;
  const _Pop(this.id, this.world, this.amount);
}

class TownScreen extends StatefulWidget {
  /// v200: true ise kasaba ANA SAYFA olarak (menu ikonlariyla birlikte) gomulu calisir:
  /// geri tusu / ust cubuk / coin-elmas yok (menu cubugunda var), ozet panel ve
  /// "Hepsini Topla" menu ikonlarina gore yeniden konumlanir.
  final bool embedded;
  const TownScreen({super.key, this.embedded = false});

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> {
  // Ayni anda tek bina penceresi: cift dokunusta iki pencere ust uste acilip
  // ayni GlobalKey'i (tour_town_build_btn) iki kez agaca koyuyordu.
  bool _sheetOpen = false;
  bool get _tr => AppStrings.instance.language == AppLanguage.tr;

  Timer? _timer;
  final TransformationController _tc = TransformationController();
  bool _viewInit = false;
  final List<_Pop> _pops = [];
  int _popId = 0;

  @override
  void initState() {
    super.initState();
    // Biriken coin sayaclari canli aksin diye saniyede bir yenile.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      GameProgress.instance.tickTownUpgrades();
      if (GameProgress.instance.pendingTownResults.isNotEmpty) _drainResults();
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameProgress.instance.tickTownUpgrades();
      if (GameProgress.instance.pendingTownResults.isNotEmpty) _drainResults();
    });
  }

  bool _showingResult = false;

  /// Biten insaatlarin sonuc (kutlama) diyaloglarini sirayla gosterir.
  Future<void> _drainResults() async {
    if (_showingResult) return;
    _showingResult = true;
    final gp = GameProgress.instance;
    while (mounted && gp.pendingTownResults.isNotEmpty) {
      final r = gp.pendingTownResults.removeAt(0);
      GameFx.instance.reward();
      await _showUpgradeDialog(r);
    }
    _showingResult = false;
    if (mounted) setState(() {});
  }

  static String _fmtMin(int m, bool tr) {
    if (m < 60) return AppStrings.instance.lt('{0} min', [m]);
    if (m < 1440) {
      final h = m / 60;
      final hs = m % 60 == 0 ? h.toStringAsFixed(0) : h.toStringAsFixed(1);
      return AppStrings.instance.lt('{0} h', [hs]);
    }
    final d = m ~/ 1440;
    final h = (m % 1440) ~/ 60;
    return h > 0 ? AppStrings.instance.lt('{0} d {1} h', [d, h]) : AppStrings.instance.lt('{0} d', [d]);
  }

  void _snack(String msg) {
    showGamePopup(context, msg);
  }

  void _showBuilderDialog() => showBuilderDialog(context, onChanged: () {
        if (mounted) setState(() {});
      });

  @override
  void dispose() {
    _timer?.cancel();
    _tc.dispose();
    super.dispose();
  }

  double _minScale = 0.5;

  /// v200: kamera en son kurulan (en ileri) binaya ortalanir; harita hep ekrani doldurur.
  void _initView(double w, double h) {
    if (_viewInit) return;
    _viewInit = true;
    final cover = max(w / _kCanvasW, h / _kCanvasH);
    _minScale = cover;
    final scale = max(cover, 0.85).clamp(cover, 2.5).toDouble();
    final gp = GameProgress.instance;
    var focus = 0;
    for (var i = 0; i < TownCatalog.worldCount; i++) {
      if (gp.townLevel(i) > 0) focus = i;
    }
    final f = _kPlots[focus];
    final tx = (w / 2 - f.dx * scale).clamp(w - _kCanvasW * scale, 0.0).toDouble();
    final ty = (h * 0.5 - f.dy * scale).clamp(h - _kCanvasH * scale, 0.0).toDouble();
    _tc.value = Matrix4.diagonal3Values(scale, scale, 1.0)..setTranslationRaw(tx, ty, 0.0);
  }

  void _addPop(int world, int amount) {
    final id = _popId++;
    _pops.add(_Pop(id, world, amount));
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() => _pops.removeWhere((p) => p.id == id));
    });
  }

  void _collect(int world) {
    final amt = GameProgress.instance.collectTown(world);
    if (amt <= 0) return;
    GameFx.instance.reward();
    _addPop(world, amt);
    setState(() {});
  }

  /// v118: tek binanin deposunu reklamla x2 topla.
  Future<void> _collectDoubled(int world) async {
    final gp = GameProgress.instance;
    if (gp.adQuotaRemaining('collect') <= 0 || gp.townPending(world) <= 0) return;
    GameFx.instance.uiTap();
    final ok = await watchRewardedAd(context, prompt: _collectPrompt(gp.townPending(world) * 2, 'town_collect_x2'));
    if (!ok || !mounted) return;
    final amt = gp.collectTown(world);
    if (amt <= 0) return;
    gp.claimCollectBonus(amt);
    GameFx.instance.reward();
    _addPop(world, amt * 2);
    setState(() {});
  }

  /// v118: tum depolari reklamla x2 topla (tek reklam, tek hak).
  Future<void> _collectAllDoubled() async {
    final gp = GameProgress.instance;
    if (gp.adQuotaRemaining('collect') <= 0 || gp.townPendingTotal <= 0) return;
    GameFx.instance.uiTap();
    final ok = await watchRewardedAd(context, prompt: _collectPrompt(gp.townPendingTotal * 2, 'town_collect_all_x2'));
    if (!ok || !mounted) return;
    var total = 0;
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      final amt = gp.collectTown(w);
      if (amt > 0) {
        total += amt;
        _addPop(w, amt * 2);
      }
    }
    if (total > 0) {
      gp.claimCollectBonus(total);
      GameFx.instance.reward();
    }
    setState(() {});
  }

  RewardedPrompt _collectPrompt(int doubledAmount, String placement) => RewardedPrompt(
        icon: '📦',
        title: AppStrings.instance.lt('Double the Storage'),
        reward: AppStrings.instance.lt('🪙 +{0} (×2)', [doubledAmount]),
        note: AppStrings.instance.lt('Left today: {0}', [GameProgress.instance.adQuotaRemaining('collect')]),
        placement: placement,
      );

  /// v118: bina indirim reklami (10.000+ maliyetli yukseltmede %25).
  Future<void> _discountAd(int world) async {
    final gp = GameProgress.instance;
    final base = gp.townBaseCost(world);
    if (!gp.canGetAdDiscount('town$world', base)) return;
    GameFx.instance.uiTap();
    final ok = await watchRewardedAd(
      context,
      prompt: RewardedPrompt(
        icon: '🏷️',
        title: AppStrings.instance.lt('25% Off'),
        reward: AppStrings.instance.lt('This building upgrade is 25% cheaper'),
        note: AppStrings.instance.lt('Discounts left today: {0}', [gp.adQuotaRemaining('discount')]),
        placement: 'town_discount',
      ),
    );
    if (!ok || !mounted) return;
    if (gp.claimAdDiscount('town$world', base)) {
      GameFx.instance.reward();
      setState(() {});
      showGamePopup(context, AppStrings.instance.lt('Discount applied! 🏷️'), autoCloseMs: 1500);
    }
  }

  /// v200: kucuk yuvarlak "Topla" ikonu: hepsini toplar, odul popup'inda kucuk "x2" reklam teklifi.
  Future<void> _collectAllAndOffer() async {
    final gp = GameProgress.instance;
    var total = 0;
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      final amt = gp.collectTown(w);
      if (amt > 0) {
        total += amt;
        _addPop(w, amt);
      }
    }
    if (total <= 0) {
      GameFx.instance.denied();
      setState(() {});
      return;
    }
    GameFx.instance.reward();
    setState(() {});
    if (!mounted) return;
    if (gp.adQuotaRemaining('collect') <= 0) {
      unawaited(showGamePopup(context, '+$total 🪙', autoCloseMs: 1400));
      return;
    }
    final s = AppStrings.instance;
    final wantDouble = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => GameAlertDialog(
        title: Text(s.lt('Collected!')),
        content: CoinText(
          '+$total 🪙',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF6B4A32)),
        ),
        actions: [
          CandyButton(
            label: s.lt('×2  🪙 +{0}', [total]),
            height: 42,
            fontSize: 15,
            style: CandyStyle.orange,
            icon: Icons.play_circle_fill_rounded,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.t('ok')),
          ),
        ],
      ),
    );
    if (wantDouble != true || !mounted) return;
    GameFx.instance.uiTap();
    final ok = await watchRewardedAd(context, prompt: _collectPrompt(total * 2, 'town_collect_all_x2'));
    if (!ok || !mounted) return;
    if (gp.claimCollectBonus(total)) {
      GameFx.instance.reward();
      setState(() {});
      unawaited(showGamePopup(context, '+$total 🪙 (×2)', autoCloseMs: 1500));
    }
  }

  void _collectAll() {
    final gp = GameProgress.instance;
    var total = 0;
    for (var w = 0; w < TownCatalog.worldCount; w++) {
      final amt = gp.collectTown(w);
      if (amt > 0) {
        total += amt;
        _addPop(w, amt);
      }
    }
    if (total > 0) {
      GameFx.instance.reward();
    } else {
      GameFx.instance.denied();
    }
    setState(() {});
  }

  void _openBuilding(int w) {
    if (_sheetOpen) return;
    _sheetOpen = true;
    GameFx.instance.uiTap();
    GuidedTour.instance.event('building_opened');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 450), () {
        final ctx = GuidedTour.instance.active ? GuidedTour.instance.keyFor('town_build_btn').currentContext : null;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200));
      });
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final gp = GameProgress.instance;
        final pending = gp.townPending(w);
        final cap = gp.townCapacity(w);
        final rate = gp.townCoinsPerHour(w);
        return PanelFrame(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(3)),
                  ),
                  if (rate > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade400, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Text('📦', style: TextStyle(fontSize: 30)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (AppStrings.instance.lt('Storage')) + ': $pending / $cap',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                if (gp.townIsUpgrading(w))
                                  Text(
                                    AppStrings.instance.lt('⏸ Output paused while upgrading'),
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.deepOrange.shade700),
                                  ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: cap <= 0 ? 0.0 : (pending / cap).clamp(0.0, 1.0).toDouble(),
                                    minHeight: 10,
                                    backgroundColor: Colors.amber.shade100,
                                    valueColor: AlwaysStoppedAnimation(
                                        pending >= cap ? Colors.deepOrange : Colors.amber.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: pending > 0
                                ? () {
                                    Navigator.of(ctx).pop();
                                    _collect(w);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(AppStrings.instance.lt('Collect'),
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  if (rate > 0 && pending > 0 && gp.adQuotaRemaining('collect') > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CandyButton(
                        height: 44,
                        fontSize: 15,
                        style: CandyStyle.orange,
                        label: AppStrings.instance.lt('📺 Collect ×2  🪙 +{0}', [pending * 2]),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _collectDoubled(w);
                        },
                      ),
                    ),
                  if (gp.townIsUpgrading(w))
                    _BuildStatus(
                      world: w,
                      tr: _tr,
                      onSkipped: () {
                        Navigator.of(ctx).pop();
                        _drainResults();
                      },
                    ),
                  _BuildingCard(
                    world: w,
                    tr: _tr,
                    onUpgrade: () {
                      Navigator.of(ctx).pop();
                      _upgrade(w);
                    },
                    onDiscountAd: () async {
                      Navigator.of(ctx).pop();
                      // Eski pencerenin kapanis animasyonu bitmeden yenisi acilirsa
                      // tur butonunun GlobalKey'i agacta iki kez gorunur.
                      await Future<void>.delayed(const Duration(milliseconds: 400));
                      await _discountAd(w);
                      if (mounted) _openBuilding(w);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _sheetOpen = false;
    });
  }

  Future<void> _upgrade(int world) async {
    final gp = GameProgress.instance;
    if (gp.townIsMax(world)) return;
    if (!gp.townWorldUnlocked(world)) {
      GameFx.instance.denied();
      showGamePopup(
        context,
        !gp.townChapterReached(world)
            ? (AppStrings.instance.lt('Unlocks when you reach this world (Chapter {0})', [gp.townUnlockChapter(world)]))
            : (AppStrings.instance.lt('Upgrade the previous building to level {0} to unlock this one', [TownCatalog.unlockPrevLevel])),
      );
      return;
    }
    if (gp.townIsUpgrading(world)) return;
    if (!gp.townHasFreeBuilder) {
      GameFx.instance.denied();
      _snack(AppStrings.instance.lt('All builders are busy! Finish a build or hire a builder.'));
      return;
    }
    if (!gp.startTownUpgrade(world)) {
      GameFx.instance.denied();
      final s = AppStrings.instance;
      _snack(!gp.townStarsOk(world) ? s.t('town_need_stars') : s.t('town_need_coins'));
      return;
    }
    GameFx.instance.reward();
    setState(() {});
    GuidedTour.instance.event('upgrade_started');
    if (GuidedTour.instance.current?.target == 'town_skip_btn') {
      // Tur: hizlandirma dugmesi insaat paneli icinde; paneli kendimiz ac.
      // Panel zaten acildigi icin "Insaat basladi" popup'i gosterilmez.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openBuilding(world);
      });
      return;
    }
    _snack(AppStrings.instance.lt('🏗️ Construction started! Time: {0}', [_fmtMin(gp.townUpgradeMinutes(world), false)]));
  }

  Future<void> _showUpgradeDialog(TownUpgradeResult r) async {
    final s = AppStrings.instance;
    final theme = AlbumCatalog.themes[r.world];
    final tier = _tierFor(r.newLevel);
    final perk = TownCatalog.perks[r.world];
    await showDialog<void>(
      context: context,
      builder: (ctx) => GameAlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          '${s.t('town_b${r.world}')} • ${s.t('level_of')} ${r.newLevel}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(_buildingImage(r.world, r.newLevel), width: 120, height: 120),
            const SizedBox(height: 8),
            Text(s.t('town_upgraded'),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(TownCatalog.perkText(perk, r.newLevel, _tr),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            CoinText(
                AppStrings.instance.lt('Output: 🪙 {0}/h', [TownCatalog.coinsPerHour(r.world, r.newLevel, bonus: GameProgress.instance.townPassiveBonus)]),
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.amber.shade800, fontSize: 15)),
            for (final m in r.milestones) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade600, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🏆 ${s.t('town_milestone_reward')} (${m.totalLevel})',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    CoinText([
                      if (m.coins > 0) '🪙 ${m.coins}',
                      if (m.gems > 0) '💎 ${m.gems}',
                    ].join('   '), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              GameFx.instance.uiTap();
              Navigator.of(ctx).pop();
            },
            child: Text(s.t('town_ok')),
          ),
        ],
      ),
    );
  }

  /// Bina seviyesine gore gosterilen obje kademesi (1-8): bina buyudukce
  /// dunyanin daha ust seviye objesi sergilenir.
  static int _tierFor(int level) {
    if (level <= 0) return 1;
    return ((level * 8 + TownCatalog.maxLevel - 1) ~/ TownCatalog.maxLevel).clamp(1, 8).toInt();
  }

  Widget _buildCanvas(int total) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/town/map_bg.webp',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
          ),
        ),
        for (var w = 0; w < TownCatalog.worldCount; w++)
          _MapBuilding(
            world: w,
            tr: _tr,
            onTap: () => _openBuilding(w),
            onCollect: () => _collect(w),
          ),
        // Henuz acilmamis dunyalarin binalari bulutla orttulur.
        for (var w = 0; w < TownCatalog.worldCount; w++)
          if (!GameProgress.instance.townWorldUnlocked(w))
            Positioned(
              left: _kPlots[w].dx - 120,
              top: _kPlots[w].dy - 140,
              width: 240,
              height: 220,
              child: const IgnorePointer(child: _CloudPatch()),
            ),
        for (final p in _pops)
          Positioned(
            key: ValueKey('pop_${p.id}'),
            left: _kPlots[p.world].dx - 60,
            top: _kPlots[p.world].dy - 150,
            width: 120,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                builder: (context, v, child) => Opacity(
                  opacity: v < 0.6 ? 1.0 : (1.0 - (v - 0.6) / 0.4).clamp(0.0, 1.0).toDouble(),
                  child: Transform.translate(offset: Offset(0, -60 * v), child: child),
                ),
                child: CoinText(
                  '+${p.amount} 🪙',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0xFF7A4A00), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final gp = GameProgress.instance;
    final total = gp.totalTownLevel;
    final nextIdx = gp.townMilestoneIdx;
    final hasNext = nextIdx < TownCatalog.milestones.length;
    final next = hasNext ? TownCatalog.milestones[nextIdx] : null;
    final prevTotal = nextIdx == 0 ? 0 : TownCatalog.milestones[nextIdx - 1].totalLevel;
    final pendingTotal = gp.townPendingTotal;
    final perHour = gp.townCoinsPerHourTotal;

    return Scaffold(
      backgroundColor: const Color(0xFF56B85C),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (context, box) {
              _initView(box.maxWidth, box.maxHeight);
              return InteractiveViewer(
                transformationController: _tc,
                constrained: false,
                minScale: _minScale,
                maxScale: 2.5,
                boundaryMargin: EdgeInsets.zero,
                child: SizedBox(width: _kCanvasW, height: _kCanvasH, child: _buildCanvas(total)),
              );
            }),
          ),
          // ── Ust: geri + unvan/ilerleme + coin/mucevher ──
          if (!widget.embedded)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            GameFx.instance.uiTap();
                            Navigator.of(context).maybePop();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.4),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.t('town_rank_${TownCatalog.rankIndex(total)}'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    Text('$total/${TownCatalog.maxTotalLevel}',
                                        style: const TextStyle(
                                            color: Colors.amberAccent, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: next == null
                                        ? 1.0
                                        : ((total - prevTotal) / (next.totalLevel - prevTotal))
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                    minHeight: 8,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                CoinText(
                                  next == null
                                      ? s.t('town_all_done')
                                      : '${s.t('town_next_reward')} (${next.totalLevel}): '
                                          '${next.coins > 0 ? '🪙 ${next.coins}  ' : ''}${next.gems > 0 ? '💎 ${next.gems}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _showBuilderDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: gp.townHasFreeBuilder ? Colors.lightGreenAccent : Colors.white54, width: 1.4),
                              ),
                              child: Text('🔨 ${gp.townBusyBuilders}/${gp.builderCount}  +',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.amber.shade300, width: 1.4),
                            ),
                            child: CoinText('🪙 ${gp.coins}    💎 ${gp.gems}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Alt: saatlik gelir + HEPSINI TOPLA ──
          if (!widget.embedded)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CoinText(
                        perHour > 0
                            ? (AppStrings.instance.lt('⏱ Total output: 🪙 {0}/hour', [perHour]))
                            : (AppStrings.instance.lt('Upgrade a building to start producing coins!')),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CandyButton(
                      label: pendingTotal > 0
                          ? (AppStrings.instance.lt('Collect All  🪙 +{0}', [pendingTotal]))
                          : (AppStrings.instance.lt('Storage empty')),
                      height: 58,
                      fontSize: 19,
                      pulse: pendingTotal > 0,
                      onTap: pendingTotal > 0 ? _collectAll : null,
                    ),
                    if (pendingTotal > 0 && GameProgress.instance.adQuotaRemaining('collect') > 0) ...[
                      const SizedBox(height: 6),
                      CandyButton(
                        label: AppStrings.instance.lt('📺 Collect All ×2  🪙 +{0}', [pendingTotal * 2]),
                        height: 48,
                        fontSize: 16,
                        style: CandyStyle.orange,
                        onTap: _collectAllDoubled,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // ── v200: ANA SAYFA (gomulu) yerlesimi: menu ikonlarinin arasinda kalan orta serit ──
          if (widget.embedded)
            Positioned.fill(
              child: SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 78,
                      left: 98,
                      right: 98,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (perHour > 0) ...[
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: CoinText('🪙 $perHour/${_tr ? 'sa' : 'h'}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (pendingTotal > 0)
                      Positioned(
                        bottom: 128,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _collectAllAndOffer,
                            child: Bobbing(amplitude: 3, child: _CollectBadge(amount: pendingTotal)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Haritadaki tek bir bina: platform + bina gorseli + isim/seviye + coin balonu.
class _MapBuilding extends StatelessWidget {
  final int world;
  final bool tr;
  final VoidCallback onTap;
  final VoidCallback onCollect;
  const _MapBuilding({required this.world, required this.tr, required this.onTap, required this.onCollect});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final gp = GameProgress.instance;
    final level = gp.townLevel(world);
    final unlocked = gp.townWorldUnlocked(world);
    final pending = gp.townPending(world);
    final full = gp.townStorageFull(world);
    final canUp = gp.canUpgradeTown(world);
    final upgrading = gp.townIsUpgrading(world);
    final remaining = gp.townUpgradeRemaining(world);
    final theme = AlbumCatalog.themes[world];
    final imagePath = _buildingImage(world, level);
    final pos = _kPlots[world];

    // Seviye 0 (henuz kurulmamis): siluet yerine INSAAT ALANI gorseli.
    Widget image = Image.asset(level == 0 ? 'assets/images/town/ruin.webp' : imagePath, fit: BoxFit.contain);

    return Positioned(
      left: pos.dx - 72,
      top: pos.dy - 118,
      width: 144,
      height: 178,
      child: GestureDetector(
        key: world == 0 ? GuidedTour.instance.keyFor('town_plot_0') : null,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: unlocked ? 1.0 : 0.62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Platform (arsa)
              Positioned(
                left: 14,
                right: 14,
                bottom: 40,
                height: 34,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE0D2AE), Color(0xFFA88B5B)]),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white.withOpacity(0.75), width: 2.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                ),
              ),
              // Bina
              Positioned(
                left: 20,
                right: 20,
                top: 36,
                height: 104,
                child: Bobbing(
                  amplitude: 3,
                  duration: Duration(milliseconds: 1800 + world * 230),
                  child: image,
                ),
              ),
              // Yukseltme sirasinda bina brandayla ortulur (vinc emojisi kaldirildi).
              if (upgrading && level > 0)
                const Positioned(
                  left: 14,
                  right: 14,
                  top: 22,
                  height: 124,
                  child: IgnorePointer(child: CustomPaint(painter: _TarpPainter())),
                ),
              if (!unlocked)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 60,
                  child: Center(child: Image.asset('assets/images/ui/lock.webp', width: 36, height: 36)),
                ),
              // Isim + seviye
              Positioned(
                left: 4,
                right: 4,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.shade300, width: 1.6),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.t('town_b$world'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF4A2C0A)),
                      ),
                      Text(
                        upgrading
                            ? '⏳ ${_fmtRemain(remaining, tr)}'
                            : (level >= TownCatalog.maxLevel ? s.t('town_max') : 'Lv $level/${TownCatalog.maxLevel}'),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.teal.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              // Coin balonu (dokun -> topla)
              if (pending > 0)
                Positioned(
                  top: 0,
                  left: 8,
                  right: 8,
                  height: 36,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCollect,
                      child: Bobbing(
                        amplitude: 4,
                        duration: const Duration(milliseconds: 900),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFB300)]),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: full ? Colors.deepOrange : Colors.white, width: 2.2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/images/coin_icon.webp', width: 16, height: 16),
                              const SizedBox(width: 4),
                              Text(
                                full ? '$pending  MAX' : '$pending',
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Yukseltme yapilabilir oku
              if (canUp)
                Positioned(
                  right: 4,
                  top: 46,
                  child: Bobbing(
                    amplitude: 5,
                    duration: const Duration(milliseconds: 800),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final int world;
  final bool tr;
  final VoidCallback onUpgrade;
  final VoidCallback? onDiscountAd;

  const _BuildingCard({required this.world, required this.tr, required this.onUpgrade, this.onDiscountAd});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final gp = GameProgress.instance;
    final level = gp.townLevel(world);
    final isMax = gp.townIsMax(world);
    final perk = TownCatalog.perks[world];
    final theme = AlbumCatalog.themes[world];
    final imagePath = _buildingImage(world, level);
    final unlocked = gp.townWorldUnlocked(world);
    final starsOk = gp.townStarsOk(world);
    final coinsOk = gp.coins >= gp.townUpgradeCost(world);

    // Harabe: insaat alani gorseli (siluet degil)
    final Widget image = Image.asset(level == 0 ? 'assets/images/town/ruin.webp' : imagePath, width: 84, height: 84, fit: BoxFit.contain);

    final rateNow = TownCatalog.coinsPerHour(world, level, bonus: gp.townPassiveBonus);
    final rateNext = TownCatalog.coinsPerHour(world, level + 1, bonus: gp.townPassiveBonus);
    final prodText = (AppStrings.instance.lt('Output')) +
        ': 🪙 ${gp.townIsUpgrading(world) ? 0 : rateNow}/' +
        (AppStrings.instance.lt('h')) +
        (gp.townIsUpgrading(world) ? ' ⏸' : '') +
        (isMax ? '' : '  →  $rateNext');

    final upgrading = gp.townIsUpgrading(world);
    String buttonLabel;
    bool enabled = true;
    CandyStyle bStyle = CandyStyle.green;
    if (!unlocked) {
      final ch = gp.townUnlockChapter(world);
      if (!gp.townChapterReached(world)) {
        buttonLabel = AppStrings.instance.lt('🔒 Unlocks at Chapter {0}', [ch]);
      } else {
        final need = TownCatalog.unlockPrevLevel;
        buttonLabel = AppStrings.instance.lt('🔒 Prev. building Lv.{0}', [need]);
      }
      enabled = false;
    } else if (isMax) {
      buttonLabel = s.t('town_max');
      enabled = false;
    } else if (upgrading) {
      buttonLabel = AppStrings.instance.lt('⏳ Under construction');
      enabled = false;
    } else if (!starsOk) {
      buttonLabel = '🔒 ⭐ ${gp.worldStars(world)}/${gp.townStarsNeeded(world)}';
      enabled = false;
    } else {
      buttonLabel = '🪙 ${gp.townUpgradeCost(world)}';
      bStyle = coinsOk ? CandyStyle.green : CandyStyle.orange;
    }

    return Opacity(
      opacity: unlocked ? 1.0 : 0.6,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: level == 0 ? Colors.grey.shade300 : Colors.teal.shade200, width: 2),
      ),
      child: Row(
        children: [
          SizedBox(width: 84, height: 84, child: image),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('town_b$world'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(s.t(theme.themeNameKey),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (var i = 1; i <= TownCatalog.maxLevel; i++)
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= level ? Colors.teal.shade500 : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${s.t('town_perk_now')}: ${TownCatalog.perkText(perk, level, tr)}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (!isMax && unlocked)
                  Text('${s.t('town_perk_next')}: ${TownCatalog.perkText(perk, level + 1, tr)}',
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade700)),
                const SizedBox(height: 2),
                CoinText(prodText,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.amber.shade800)),
                if (!isMax && unlocked && !upgrading) ...[
                  const SizedBox(height: 2),
                  Text(
                    '⏱ ${AppStrings.instance.lt('Time')}: ${_TownScreenState._fmtMin(gp.townUpgradeMinutes(world), tr)}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade600),
                  ),
                ],
                const SizedBox(height: 8),
                CandyButton(
                  key: GuidedTour.instance.active ? GuidedTour.instance.keyFor('town_build_btn') : null,
                  height: 46,
                  fontSize: 15,
                  style: bStyle,
                  label: buttonLabel,
                  onTap: enabled ? onUpgrade : null,
                ),
                if (unlocked && !isMax && !upgrading && starsOk && onDiscountAd != null) ...[
                  if (gp.hasAdDiscount('town$world'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: CoinText(
                        '🏷️ -25%  (🪙 ${gp.townBaseCost(world)})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade700),
                      ),
                    )
                  else if (gp.canGetAdDiscount('town$world', gp.townBaseCost(world)))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: onDiscountAd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade400, width: 1.5),
                          ),
                          child: Text(
                            AppStrings.instance.lt('📺 Watch ad: 25% off'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade800),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Bottom sheet icinde: devam eden insaatin geri sayimi + "Hizlandir" butonu.
class _BuildStatus extends StatefulWidget {
  final int world;
  final bool tr;
  final VoidCallback onSkipped;
  const _BuildStatus({required this.world, required this.tr, required this.onSkipped});

  @override
  State<_BuildStatus> createState() => _BuildStatusState();
}

class _BuildStatusState extends State<_BuildStatus> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = GameProgress.instance;
    final w = widget.world;
    final tr = widget.tr;
    if (!gp.townIsUpgrading(w)) return const SizedBox.shrink();
    final rem = gp.townUpgradeRemaining(w);
    final totalSec = max(1, gp.townUpgradeMinutes(w) * 60);
    final progress = (1 - rem.inSeconds / totalSec).clamp(0.0, 1.0).toDouble();
    final cost = gp.townSkipCost(w);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade300, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏗️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(AppStrings.instance.lt('Under construction'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              Text(_fmtRemain(rem, tr),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.blue.shade800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.blue.shade100,
              valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
            ),
          ),
          const SizedBox(height: 10),
          CandyButton(
            key: GuidedTour.instance.active ? GuidedTour.instance.keyFor('town_skip_btn') : null,
            height: 46,
            fontSize: 16,
            style: CandyStyle.blue,
            label: cost == 0
                ? (AppStrings.instance.lt('Finish now (free)'))
                : (AppStrings.instance.lt('Speed up  💎 {0}', [cost])),
            onTap: gp.gems >= cost
                ? () {
                    if (GameProgress.instance.skipTownUpgrade(w)) {
                      GameFx.instance.reward();
                      GuidedTour.instance.event('upgrade_skipped');
                      widget.onSkipped();
                    }
                  }
                : null,
          ),
          if (cost > 0 && gp.adQuotaRemaining('build') > 0) ...[
            const SizedBox(height: 8),
            CandyButton(
              height: 44,
              fontSize: 15,
              style: CandyStyle.orange,
              label: tr
                  ? '📺 Reklam izle: -${GameProgress.buildAdMinutes} dk  (${gp.adQuotaRemaining('build')})'
                  : '📺 Watch ad: -${GameProgress.buildAdMinutes} min  (${gp.adQuotaRemaining('build')})',
              onTap: () async {
                GameFx.instance.uiTap();
                final ok = await watchRewardedAd(
                  context,
                  prompt: RewardedPrompt(
                    icon: '🏗️',
                    title: AppStrings.instance.lt('Speed Up Construction'),
                    reward: AppStrings.instance.lt('⏱ -{0} minutes', [GameProgress.buildAdMinutes]),
                    note: AppStrings.instance.lt('Left today: {0}', [gp.adQuotaRemaining('build')]),
                    placement: 'town_skip',
                  ),
                );
                if (!ok || !mounted) return;
                final stillBuilding = GameProgress.instance.townIsUpgrading(w);
                if (stillBuilding && GameProgress.instance.claimBuildAd(w)) {
                  GameFx.instance.reward();
                  GuidedTour.instance.event('upgrade_skipped');
                  if (!GameProgress.instance.townIsUpgrading(w)) {
                    widget.onSkipped(); // reklam insaati bitirdi
                  } else {
                    setState(() {});
                  }
                } else if (!stillBuilding) {
                  widget.onSkipped();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}


/// Yukseltilen binayi ortu brandasi + turuncu-beyaz uyari seridi + direklerle cizer.
class _TarpPainter extends CustomPainter {
  const _TarpPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final top = h * 0.10, bottom = h * 0.84;

    // Branda govdesi (ustte hafif sivri kivrimlar)
    final body = Path()
      ..moveTo(w * 0.05, top + h * 0.10)
      ..lineTo(w * 0.28, top)
      ..lineTo(w * 0.50, top + h * 0.12)
      ..lineTo(w * 0.72, top)
      ..lineTo(w * 0.95, top + h * 0.10)
      ..lineTo(w * 0.95, bottom)
      ..lineTo(w * 0.05, bottom)
      ..close();

    // Golge
    canvas.drawShadow(body, Colors.black.withOpacity(0.55), 4, false);

    // 4 panel, farkli mavi tonlari (kivrim hissi)
    canvas.save();
    canvas.clipPath(body);
    const tones = [Color(0xFF4F9BE6), Color(0xFF3B84D6), Color(0xFF5BA7F0), Color(0xFF3577C4)];
    final x0 = w * 0.05, pw = (w * 0.90) / tones.length;
    for (var i = 0; i < tones.length; i++) {
      final r = Rect.fromLTWH(x0 + pw * i, 0, pw + 0.5, h);
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tones[i], Color.lerp(tones[i], const Color(0xFF1F4F94), 0.45)!],
          ).createShader(r),
      );
      // kivrim cizgisi
      canvas.drawLine(
        Offset(r.left, top),
        Offset(r.left, bottom),
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..strokeWidth = 1.2,
      );
    }
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF1F4F94)
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );

    // Uyari seridi (turuncu/beyaz capraz)
    final tape = Rect.fromLTWH(0, h * 0.70, w, h * 0.11);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(tape, const Radius.circular(2)));
    canvas.drawRect(tape, Paint()..color = Colors.white);
    final orange = Paint()..color = const Color(0xFFFF7A1A);
    const sw = 9.0;
    for (double x = -tape.height; x < w + tape.height; x += sw * 2) {
      final stripe = Path()
        ..moveTo(x, tape.bottom)
        ..lineTo(x + sw, tape.bottom)
        ..lineTo(x + sw + tape.height, tape.top)
        ..lineTo(x + tape.height, tape.top)
        ..close();
      canvas.drawPath(stripe, orange);
    }
    canvas.restore();

    // Direkler
    final post = Paint()..color = const Color(0xFF8E98A4);
    final cap = Paint()..color = const Color(0xFFC9D1DA);
    for (final fx in [0.03, 0.50, 0.97]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * fx, h * 0.75), width: 5, height: h * 0.34),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, post);
      canvas.drawCircle(Offset(w * fx, h * 0.75 - h * 0.17), 3.2, cap);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Kucuk yuvarlak "Topla" ikonu: altin coin + biriken miktar rozeti.
class _CollectBadge extends StatelessWidget {
  final int amount;
  const _CollectBadge({required this.amount});

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Center(child: Image.asset('assets/images/coin_icon.webp', width: 38, height: 38)),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF3DBE4E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text('+${_compact(amount)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kilitli bolgeyi orten hafif bulut: ust uste binen yumusak radyal beyaz daireler (gorsel dosyasi yok).
class _CloudPatch extends StatelessWidget {
  const _CloudPatch();

  Widget _puff(double l, double t, double d, double a) => Positioned(
        left: l,
        top: t,
        width: d,
        height: d,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.white.withOpacity(a), Colors.white.withOpacity(0)],
              stops: const [0.35, 1.0],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _puff(10, 40, 130, 0.72),
        _puff(100, 30, 140, 0.72),
        _puff(55, 0, 130, 0.7),
        _puff(55, 80, 140, 0.7),
        _puff(0, 100, 110, 0.6),
        _puff(130, 100, 110, 0.6),
      ],
    );
  }
}
