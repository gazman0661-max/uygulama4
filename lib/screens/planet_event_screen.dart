import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/planet_event.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import '../services/log_service.dart';
import '../widgets/rewarded_prompt.dart';
import '../widgets/ui_kit.dart';
import 'planet_game_screen.dart';

/// HAFTA SONU ETKINLIGI ana ekrani: geri sayim, enerji, gorevler, odul alma, OYNA.
class PlanetEventScreen extends StatefulWidget {
  const PlanetEventScreen({super.key});

  @override
  State<PlanetEventScreen> createState() => _PlanetEventScreenState();
}

class _PlanetEventScreenState extends State<PlanetEventScreen> {
  final PlanetEvent _ev = PlanetEvent.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log('pe_open');
    // Geri sayimlar (etkinlik suresi, enerji dolumu) her saniye tazelenir.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _dur(Duration d) {
    final s = AppStrings.instance;
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final days = total ~/ 86400;
    final hours = (total % 86400) ~/ 3600;
    final mins = (total % 3600) ~/ 60;
    final secs = total % 60;
    if (days > 0) return s.lt('{0}d {1}h', [days, hours]);
    if (hours > 0) return s.lt('{0}h {1}m', [hours, mins]);
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _rewardText(PlanetReward r) {
    final p = <String>[];
    if (r.coins > 0) p.add('🪙${r.coins}');
    if (r.gems > 0) p.add('💎${r.gems}');
    if (r.energy > 0) p.add('⚡${r.energy}');
    return p.join('  ');
  }

  /// 350000 -> 350.000 (binlik ayirac nokta).
  static String _fmt(int n) {
    final t = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      if (i > 0 && (t.length - i) % 3 == 0) b.write('.');
      b.write(t[i]);
    }
    return b.toString();
  }

  String _taskName(int i) {
    final s = AppStrings.instance;
    switch (PlanetEvent.tasks[i].id) {
      case 'neptune':
        return s.lt('Reach Neptune');
      case 'uranus':
        return s.lt('Reach Uranus');
      case 'saturn':
        return s.lt('Reach Saturn');
      case 'combo':
        return s.lt('Chain a x{0} combo, {1} times', [PlanetEvent.targetCombo, PlanetEvent.tasks[i].target]);
      case 'merges':
        return s.lt('Make {0} merges during the event', [PlanetEvent.targetMerges]);
      case 'score':
        return s.lt('Score {0} points in a single game', [PlanetEvent.targetScore]);
      case 'total':
        return s.lt('Earn {0} total points during the event', [_fmt(PlanetEvent.targetTotalScore)]);
    }
    return PlanetEvent.tasks[i].id;
  }

  void _claim(int i) {
    final r = _ev.claim(i);
    if (r != null) GameFx.instance.reward();
    setState(() {});
  }

  void _claimGrand() {
    final r = _ev.claimGrand();
    if (r != null) GameFx.instance.reward();
    setState(() {});
  }

  Future<void> _play() async {
    final s = AppStrings.instance;
    GameFx.instance.uiTap();
    if (!_ev.isActive) {
      showGamePopup(context, s.lt('The event opens on Saturday. Come back then!'));
      return;
    }
    if (_ev.energy < 1) {
      GameFx.instance.denied();
      showGamePopup(context, s.lt('No energy left. Wait, watch an ad or use 💎.'));
      return;
    }
    if (!_ev.startRun()) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlanetGameScreen()));
    await _ev.flush();
    if (mounted) setState(() {});
  }

  Future<void> _refillAd() async {
    final s = AppStrings.instance;
    if (!_ev.canAdRefill) {
      GameFx.instance.denied();
      return;
    }
    GameFx.instance.uiTap();
    final ok = await AdService.instance.showRewarded(
      context,
      prompt: RewardedPrompt(
        icon: '⚡',
        reward: s.lt('Full energy ⚡⚡⚡'),
        note: s.lt('{0} ad refills left', [_ev.adRefillsLeft]),
        placement: 'pe_energy',
      ),
    );
    if (!mounted) return;
    if (ok && _ev.refillAfterAd()) {
      GameFx.instance.reward();
    } else if (ok) {
      AppLog.w('planet', 'reklam izlendi ama dolum uygulanamadi (limit/dolu)');
    }
    setState(() {});
  }

  void _refillGems() {
    final s = AppStrings.instance;
    GameFx.instance.uiTap();
    if (_ev.refillWithGems()) {
      GameFx.instance.reward();
    } else {
      GameFx.instance.denied();
      showGamePopup(context, s.lt('Not enough 💎'));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final active = _ev.isActive;
    final energy = _ev.energy;
    return GameScaffold(
      title: s.lt('Weekend Event'),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _hero(s, active),
          const SizedBox(height: 12),
          _energyCard(s, active, energy),
          const SizedBox(height: 12),
          CandyButton(
            label: s.lt('Play'),
            height: 62,
            fontSize: 24,
            pulse: active && energy >= 1,
            onTap: _play,
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < PlanetEvent.tasks.length; i++) _taskCard(i),
          _grandCard(s),
        ],
      ),
    );
  }

  Widget _hero(AppStrings s, bool active) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1B1464), Color(0xFF5B2A9B)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Image.asset('assets/images/planet/pl_9.webp', fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.lt('Planet Merge'),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(s.lt('Merge planets, reach Neptune, Uranus and Saturn and collect rewards!'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? Colors.amber : Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: active ? Colors.black87 : Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        active
                            ? s.lt('Ends in {0}', [_dur(_ev.timeLeft)])
                            : s.lt('Starts in {0}', [_dur(_ev.timeLeft)]),
                        style: TextStyle(
                            fontWeight: FontWeight.w900, color: active ? Colors.black87 : Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _energyCard(AppStrings s, bool active, int energy) {
    final next = _ev.nextEnergyIn;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.t('energy_title'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(width: 10),
              for (var i = 0; i < PlanetEvent.maxEnergy; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.bolt_rounded,
                      size: 28, color: i < energy ? Colors.amber.shade700 : Colors.grey.shade300),
                ),
              const Spacer(),
              if (active && next != null)
                Text(s.lt('Next ⚡ in {0}', [_dur(next)]),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          if (!active) ...[
            const SizedBox(height: 6),
            Text(s.lt('The event opens on Saturday. Come back then!'),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ],
          if (active && energy < PlanetEvent.maxEnergy) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CandyButton(
                    style: CandyStyle.blue,
                    height: 46,
                    fontSize: 13,
                    maxLines: 2,
                    label: _ev.canAdRefill ? '🎬 ${s.lt('Refill with ad')}' : '🎬 ${s.lt('No ad refills left')}',
                    onTap: _ev.canAdRefill ? _refillAd : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CandyButton(
                    style: CandyStyle.orange,
                    height: 46,
                    fontSize: 13,
                    maxLines: 2,
                    label: s.lt('Refill · {0} 💎', [PlanetEvent.gemRefillCost]),
                    onTap: _refillGems,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _taskCard(int i) {
    final s = AppStrings.instance;
    final t = PlanetEvent.tasks[i];
    final claimed = _ev.isClaimed(i);
    final can = _ev.canClaim(i);
    final prog = _ev.progressOf(i);
    final shown = prog > t.target ? t.target : prog;
    final p = (prog / t.target).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: claimed ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: can ? Colors.green : Colors.orange.shade200, width: can ? 3 : 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_taskName(i), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                CoinText(_rewardText(t.reward), style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: p,
                          backgroundColor: Colors.orange.shade100,
                          valueColor: AlwaysStoppedAnimation(claimed ? Colors.grey : Colors.deepPurple),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${_fmt(shown)}/${_fmt(t.target)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(Icons.check_circle, color: Colors.green, size: 32)
          else
            CandyButton(
              width: 92,
              height: 42,
              fontSize: 13,
              label: s.t('mission_claim'),
              onTap: can ? () => _claim(i) : null,
            ),
        ],
      ),
    );
  }

  Widget _grandCard(AppStrings s) {
    final can = _ev.canClaimGrand;
    final claimed = _ev.grandClaimed;
    var done = 0;
    for (var i = 0; i < PlanetEvent.tasks.length; i++) {
      if (_ev.isDone(i)) done++;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: claimed ? [Colors.grey.shade300, Colors.grey.shade200] : [Colors.amber.shade300, Colors.orange.shade300],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: can ? Colors.green : Colors.orange.shade400, width: can ? 3 : 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.lt('Grand prize: complete all tasks'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 4),
                CoinText(_rewardText(PlanetEvent.grandReward),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('$done/${PlanetEvent.tasks.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(Icons.check_circle, color: Colors.green, size: 32)
          else
            CandyButton(
              width: 92,
              height: 42,
              fontSize: 13,
              label: s.t('mission_claim'),
              onTap: can ? _claimGrand : null,
            ),
        ],
      ),
    );
  }
}
