import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../models/merge_board.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import '../services/merge_board_service.dart';
import '../utils/duration_format.dart';
import 'gem_dialogs.dart';
import 'rewarded_prompt.dart';
import 'ui_kit.dart';

/// Iki modun enerjisi AYRI: Sürükle-Bırak (merge tahtasi) = MbState.energy (100 bar, reklamla 200'e kadar),
/// Fırlat = GameProgress.energy (5 can, 10 dk'da bir dolar). Ust bar ve popup hangi modda
/// acildiysa onun enerjisini gosterir / doldurur.
enum EnergyMode { merge, throwMode }

/// Ana sayfadaki ust cubukla ayni zemin (assets/images/ui/pill) uzerinde ikon + deger rozeti.
/// [plus] true ise ikonun sol altinda yesil "+" dugmesi cikar.
class CurrencyPill extends StatelessWidget {
  final String iconAsset;
  final String value;
  final String? sub; // degerin altinda kucuk sari yazi (geri sayim)
  final bool plus;
  final bool warn; // true: deger kirmizimsi (enerji bitti)
  final VoidCallback? onTap;
  const CurrencyPill({
    super.key,
    required this.iconAsset,
    required this.value,
    this.sub,
    this.plus = false,
    this.warn = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: LayoutBuilder(builder: (context, box) => Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: SlicedBar(base: 'assets/images/ui/pill', capRatio: 0.65)),
            Padding(
              // dar pill'lerde (kucuk ekran / cok rozet) kenar boslugu azalir, icerik sigar
              padding: EdgeInsets.symmetric(horizontal: box.maxWidth < 92 ? 10 : 16, vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: Image.asset(iconAsset, fit: BoxFit.contain)),
                          if (plus)
                            Positioned(
                              left: -7,
                              bottom: -6,
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3DBE4E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.4),
                                ),
                                child: const Icon(Icons.add_rounded, size: 11, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: warn ? const Color(0xFFFFAB91) : Colors.white,
                            height: 1.0,
                          ),
                        ),
                        if (sub != null)
                          Text(
                            sub!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFFFFE082), height: 1.1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

/// Ust bar: ENERJI (+) | COIN | MUCEVHER (+). Enerji rozeti [mode]'a gore ilgili modun enerjisini
/// gosterir; "+" ya da rozete dokununca "Daha Fazla Enerji?" penceresi acilir, mucevher "+" magazayi acar.
/// Kendi zamanlayicisiyla yenilenir (geri sayimlar canli akar).
class GameTopBar extends StatefulWidget {
  final EnergyMode mode;
  final VoidCallback? onChanged; // enerji/mucevher degisince (ust ekran kendini yenilesin diye)
  const GameTopBar({super.key, required this.mode, this.onChanged});

  @override
  State<GameTopBar> createState() => _GameTopBarState();
}

class _GameTopBarState extends State<GameTopBar> {
  Timer? _timer;
  final MergeBoardService _svc = MergeBoardService.instance;

  @override
  void initState() {
    super.initState();
    if (widget.mode == EnergyMode.merge) {
      _svc.addListener(_refresh);
      if (!_svc.loaded) unawaited(_svc.load());
    }
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.mode == EnergyMode.merge) _svc.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openEnergy() async {
    await showEnergyPopup(context, mode: widget.mode, onChanged: widget.onChanged);
    if (mounted) setState(() {});
  }

  Future<void> _openGems() async {
    await openGemShop(context);
    widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final gp = GameProgress.instance;
    String value;
    String? sub;
    var empty = false;
    if (widget.mode == EnergyMode.merge) {
      if (_svc.loaded) {
        final e = _svc.energy;
        value = '$e';
        empty = e <= 0;
        if (e < MbState.maxEnergy) sub = formatCountdown(Duration(seconds: _svc.secondsToNextEnergy));
      } else {
        value = '–';
      }
    } else {
      final e = gp.energy;
      value = '$e/${GameProgress.maxEnergy}';
      empty = e <= 0;
      final next = gp.timeUntilNextEnergy;
      if (e < GameProgress.maxEnergy && next != null) sub = formatCountdown(next);
    }
    return Row(
      children: [
        Expanded(
          child: CurrencyPill(
            iconAsset: 'assets/images/ui/bolt.webp',
            value: value,
            sub: sub,
            plus: true,
            warn: empty,
            onTap: _openEnergy,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: CurrencyPill(
            iconAsset: 'assets/images/coin_icon.webp',
            value: '${gp.coins}',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: CurrencyPill(
            iconAsset: 'assets/images/ui/gem.webp',
            value: '${gp.gems}',
            plus: true,
            onTap: _openGems,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// "DAHA FAZLA ENERJI?" POPUP'I
// ─────────────────────────────────────────────────────────────────────
enum _EnergyAction { gems, ad }

/// Pencereyi acar; secilen eylemi (mucevherle al / reklam izle) uygular.
/// [onChanged] eylem bitince cagrilir.
Future<void> showEnergyPopup(BuildContext context, {required EnergyMode mode, VoidCallback? onChanged}) async {
  if (!context.mounted) return;
  GameFx.instance.uiTap();
  final action = await showDialog<_EnergyAction>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _EnergyPopup(mode: mode),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _EnergyAction.gems:
      if (!await _confirmGemEnergy(context, mode)) break;
      if (!context.mounted) break;
      await _buyWithGems(context, mode);
      break;
    case _EnergyAction.ad:
      await _watchAdForEnergy(context, mode);
      break;
  }
  onChanged?.call();
}

/// v200: elmasla enerji alirken ozel onay popup'i. Elmas yetmiyorsa onay sorulmaz
/// (satin alma akisi zaten "Yeterli elmas yok" penceresini acar).
Future<bool> _confirmGemEnergy(BuildContext context, EnergyMode mode) async {
  final merge = mode == EnergyMode.merge;
  final cost = merge ? MbState.gemPackCost : GameProgress.energyRefillGemCost;
  final amount = merge ? MbState.gemPackEnergy : GameProgress.maxEnergy;
  if (GameProgress.instance.gems < cost) return true;
  final s = AppStrings.instance;
  final res = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black45,
    builder: (ctx) => GameAlertDialog(
      title: Text(s.lt('Buy Energy?')),
      content: CoinText(
        s.lt('Spend {0} 💎 for {1} ⚡?', [cost, amount]),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF6B4A32)),
      ),
      actions: [
        CandyButton(
          label: s.lt('Buy'),
          height: 50,
          fontSize: 18,
          style: CandyStyle.green,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s.t('cancel')),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<void> _buyWithGems(BuildContext context, EnergyMode mode) async {
  final gp = GameProgress.instance;
  if (mode == EnergyMode.merge) {
    final svc = MergeBoardService.instance;
    await svc.load(); // yuklenmeden degistirmek, yukleme sirasinda ezilmeye yol acar
    switch (svc.buyEnergyPack()) {
      case MbBuyResult.ok:
        GameFx.instance.reward();
        if (context.mounted) unawaited(showGamePopup(context, '+${MbState.gemPackEnergy} ⚡', autoCloseMs: 1300));
        break;
      case MbBuyResult.noGems:
        GameFx.instance.denied();
        if (context.mounted) await showNotEnoughGemsDialog(context);
        break;
      case MbBuyResult.full:
        break;
    }
    return;
  }
  if (gp.energy >= GameProgress.maxEnergy) return;
  if (gp.gems < GameProgress.energyRefillGemCost) {
    GameFx.instance.denied();
    if (context.mounted) await showNotEnoughGemsDialog(context);
    return;
  }
  if (gp.refillEnergyWithGems()) {
    GameFx.instance.reward();
    if (context.mounted) {
      unawaited(showGamePopup(context, AppStrings.instance.lt('⚡ Energy fully refilled!'), autoCloseMs: 1300));
    }
  }
}

Future<void> _watchAdForEnergy(BuildContext context, EnergyMode mode) async {
  if (mode == EnergyMode.merge) {
    final svc = MergeBoardService.instance;
    await svc.load();
    if (!context.mounted || svc.energy >= MbState.energyCap) return;
    final ok = await watchRewardedAd(
      context,
      prompt: RewardedPrompt(
        icon: '⚡',
        title: AppStrings.instance.lt('Refill Energy'),
        reward: '+${MbState.adEnergy} ⚡',
        placement: 'mb_energy',
      ),
    );
    if (!ok) {
      AnalyticsService.instance.log('mb_ad_energy_failed', {'chapter': svc.board.chapter});
      return;
    }
    svc.addAdEnergy();
    GameFx.instance.reward();
    return;
  }
  final gp = GameProgress.instance;
  if (!gp.canWatchEnergyAd) return;
  final ok = await watchRewardedAd(
    context,
    prompt: RewardedPrompt(
      icon: '⚡',
      title: AppStrings.instance.lt('Refill Energy'),
      reward: '⚡ MAX',
      placement: 'energy',
    ),
  );
  if (!ok) return;
  gp.claimEnergyAdReward();
  GameFx.instance.reward();
}

class _EnergyPopup extends StatefulWidget {
  final EnergyMode mode;
  const _EnergyPopup({required this.mode});

  @override
  State<_EnergyPopup> createState() => _EnergyPopupState();
}

class _EnergyPopupState extends State<_EnergyPopup> {
  static const Color _ink = Color(0xFF8A4B3C);

  // v218: reklam butonundaki bekleme geri sayimi (60 sn) ve kota kilidi saniyede bir tazelensin.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final s = AppStrings.instance;
    final gp = GameProgress.instance;
    final merge = mode == EnergyMode.merge;

    // ── Mod'a gore: paket, fiyat, doluluk, reklam butonu ──
    final String body;
    final String amount;
    final String? caption;
    final int cost;
    final bool full;
    final String adLabel;
    final bool adEnabled;
    if (merge) {
      final svc = MergeBoardService.instance;
      final e = svc.loaded ? svc.energy : 0;
      body = s.lt('Spawning items needs energy. You can get more energy here!');
      amount = '${MbState.gemPackEnergy}';
      caption = null;
      cost = MbState.gemPackCost;
      full = svc.loaded && e >= MbState.energyCap;
      final adWait = AdService.instance.cooldownLeftFor('mb_energy');
      if (!full && adWait > 0) {
        adLabel = '⏳ ${formatCountdown(Duration(seconds: adWait))}';
        adEnabled = false;
      } else {
        adLabel = s.lt('Watch Ad · +{0} ⚡', [MbState.adEnergy]);
        adEnabled = !full;
      }
    } else {
      body = s.lt('Every failed attempt in Throw mode costs energy. Refill it here!');
      amount = '${GameProgress.maxEnergy}';
      caption = s.lt('Full refill');
      cost = GameProgress.energyRefillGemCost;
      full = gp.energy >= GameProgress.maxEnergy;
      final cooldown = gp.energyAdCooldownRemaining;
      final adWait = AdService.instance.cooldownLeftFor('energy');
      if (gp.canWatchEnergyAd && adWait > 0) {
        adLabel = '⏳ ${formatCountdown(Duration(seconds: adWait))}  (${gp.energyAdWatchesRemaining}/${GameProgress.maxEnergyAdWatches})';
        adEnabled = false;
      } else if (gp.canWatchEnergyAd) {
        adLabel = s.lt('Watch Ad · Full ⚡') + '  (${gp.energyAdWatchesRemaining}/${GameProgress.maxEnergyAdWatches})';
        adEnabled = true;
      } else if (!full && cooldown != null) {
        adLabel = formatCountdown(cooldown);
        adEnabled = false;
      } else {
        adLabel = s.lt('Watch Ad · Full ⚡');
        adEnabled = false;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 26),
              child: PanelFrame(
                padding: const EdgeInsets.fromLTRB(26, 46, 26, 26),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink, height: 1.25),
                      ),
                      const SizedBox(height: 14),
                      _EnergyPackCard(amount: amount, caption: caption),
                      const SizedBox(height: 14),
                      CandyButton(
                        height: 56,
                        fontSize: 24,
                        style: CandyStyle.green,
                        label: full ? s.lt('Energy is full') : '$cost',
                        leading: full ? null : Image.asset('assets/images/ui/gem.webp', width: 30, height: 30),
                        onTap: full ? null : () => Navigator.of(context).pop(_EnergyAction.gems),
                      ),
                      const SizedBox(height: 10),
                      CandyButton(
                        height: 52,
                        fontSize: 17,
                        style: CandyStyle.orange,
                        icon: Icons.play_circle_fill_rounded,
                        label: adLabel,
                        onTap: adEnabled ? () => Navigator.of(context).pop(_EnergyAction.ad) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: RibbonTitle(text: s.lt('More Energy?'), height: 56)),
            ),
            Positioned(
              top: 40,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  GameFx.instance.uiTap();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mor zeminli paket karti: parlayan enerji yigini + pembe-beyaz cizgili kutu + miktar.
class _EnergyPackCard extends StatelessWidget {
  final String amount;
  final String? caption;
  const _EnergyPackCard({required this.amount, this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: caption == null ? 196 : 212,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB57BFF), Color(0xFFE2A0FF)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(left: 28, top: 30, child: Icon(Icons.auto_awesome, size: 18, color: Colors.white70)),
            const Positioned(right: 34, top: 20, child: Icon(Icons.auto_awesome, size: 22, color: Colors.white70)),
            const Positioned(right: 24, top: 80, child: Icon(Icons.auto_awesome, size: 14, color: Colors.white60)),
            Positioned(
              top: 14,
              child: SizedBox(width: 190, height: 112, child: _EnergyBox()),
            ),
            Positioned(
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/ui/bolt.webp', width: 34, height: 34),
                      const SizedBox(width: 6),
                      _OutlinedText(amount, fontSize: 38),
                    ],
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Color(0xFF6A1B9A), blurRadius: 3, offset: Offset(0, 1))],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pembe-beyaz cizgili kutu + icinden tasan enerji simgeleri (oyunun kendi bolt gorseliyle).
class _EnergyBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget bolt(double size, double angle) =>
        Transform.rotate(angle: angle, child: Image.asset('assets/images/ui/bolt.webp', width: size, height: size));
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(left: 14, bottom: 30, child: bolt(54, -0.35)),
        Positioned(right: 14, bottom: 32, child: bolt(54, 0.3)),
        Positioned(left: 52, bottom: 34, child: bolt(70, -0.08)),
        Positioned(left: 34, bottom: 24, child: bolt(46, 0.2)),
        Positioned(
          left: 6,
          right: 6,
          bottom: 0,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFF48FB1), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Row(
                children: [
                  for (var i = 0; i < 9; i++)
                    Expanded(
                      child: ColoredBox(
                        color: i.isEven ? const Color(0xFFF8BBD0) : const Color(0xFFFCE4EC),
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Kutunun ust dudagi
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          height: 14,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF48FB1),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFF8BBD0), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Beyaz dolgulu, koyu konturlu buyuk sayi (karttaki "100" gibi).
class _OutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  const _OutlinedText(this.text, {required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF8A3B1F),
          ),
        ),
        Text(
          text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, height: 1.0, color: Colors.white),
        ),
      ],
    );
  }
}
