import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/planet_event.dart' show PlanetReward;
import '../models/team_race.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import '../widgets/rewarded_prompt.dart';
import '../widgets/ui_kit.dart';
import 'event_run.dart';
import 'leaders_screen.dart';

/// TAKIM YARISI ana ekrani: geri sayim, takim secimi, enerji (+ saatte 1 reklam), OYNA, takim siralamasi,
/// ve odul listesi. SIRALAMA BU EKRANDA YOK: takim siralamasi yalniz Liderler ekraninda (diger yarislarla ayni).
class TeamRaceScreen extends StatefulWidget {
  const TeamRaceScreen({super.key});

  @override
  State<TeamRaceScreen> createState() => _TeamRaceScreenState();
}

class _TeamRaceScreenState extends State<TeamRaceScreen> {
  final TeamRace _tr = TeamRace.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log('tr_open');
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tr.flush();
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

  static String _fmt(int n) {
    final t = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      if (i > 0 && (t.length - i) % 3 == 0) b.write('.');
      b.write(t[i]);
    }
    return b.toString();
  }

  Future<void> _play() async {
    final s = AppStrings.instance;
    GameFx.instance.uiTap();
    if (!_tr.isActive) {
      showGamePopup(context, s.lt('The Team Race starts on Monday at 10:00.'));
      return;
    }
    if (!_tr.hasTeam) {
      GameFx.instance.denied();
      showGamePopup(context, _tr.joinClosed ? s.lt('Team joining is closed. Join the next race!') : s.lt('Pick a team first!'));
      return;
    }
    if (!_tr.hasStarted) {
      GameFx.instance.denied();
      showGamePopup(context, s.lt('Race starts in {0}', [_dur(_tr.startsIn)]));
      return;
    }
    if (_tr.energy < 1) {
      GameFx.instance.denied();
      showGamePopup(context, s.lt('No energy left. Wait or watch an ad.'));
      return;
    }
    AnalyticsService.instance.log('tr_run_start', {'team': _tr.team, 'orders': _tr.orders});
    await EventRun.startTeam(context);
    if (mounted) setState(() {});
  }

  Future<void> _refillAd() async {
    final s = AppStrings.instance;
    if (!_tr.canAdRefill) {
      GameFx.instance.denied();
      return;
    }
    GameFx.instance.uiTap();
    final ok = await AdService.instance.showRewarded(
      context,
      prompt: RewardedPrompt(
        icon: '⚡',
        reward: s.lt('Full energy ⚡⚡⚡'),
        note: s.lt('Refill with ad (1 per hour)'),
        placement: 'tr_energy',
      ),
    );
    if (!mounted) return;
    if (ok && _tr.refillAfterAd()) GameFx.instance.reward();
    setState(() {});
  }

  Future<void> _join(int t) async {
    GameFx.instance.uiTap();
    final s = AppStrings.instance;
    final info = TeamRace.teams[t];
    // Secim kesin (degistirme / ayrilma yok): onay iste.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${info.emoji} ${s.lt('Join {0}?', [info.name])}', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(s.lt('Your team choice is final for this race: no switching or leaving.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.lt('Cancel'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.lt('Join'), style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!_tr.chooseTeam(t)) {
      GameFx.instance.denied();
      if (_tr.joinClosed) showGamePopup(context, s.lt('Team joining is closed. Join the next race!'));
      if (mounted) setState(() {});
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final active = _tr.isActive;
    final energy = _tr.energy;
    return GameScaffold(
      title: s.lt('Team Race'),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _hero(s, active),
          const SizedBox(height: 12),
          if (active && !_tr.hasTeam && _tr.canJoin) _teamPicker(s) else if (active && !_tr.hasTeam) ...[
            _joinClosedCard(s),
            const SizedBox(height: 12),
            CandyButton(
              label: '🏆 ${s.lt('Team standings')}',
              height: 54,
              fontSize: 18,
              onTap: () {
                GameFx.instance.uiTap();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LeadersScreen()));
              },
            ),
            const SizedBox(height: 14),
            _rewardsCard(s),
          ] else if (_tr.inRegistration) ...[
            // Kayit donemi: takim secildi, yaris henuz baslamadi -> geri sayim (Oyna / enerji yok)
            _myTeamCard(s),
            const SizedBox(height: 12),
            _waitCard(s),
            const SizedBox(height: 14),
            _rewardsCard(s),
          ] else ...[
            if (active) _myTeamCard(s),
            if (active) const SizedBox(height: 12),
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
            _rewardsCard(s),
          ],
        ],
      ),
    );
  }

  Widget _hero(AppStrings s, bool active) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D3B66), Color(0xFF7B2FF7)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 52)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.lt('Team Race'),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(s.lt('Deliver orders for your team. The top 3 teams win rewards!'),
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
                        _tr.inRegistration
                            ? s.lt('Race starts in {0}', [_dur(_tr.startsIn)])
                            : active
                                ? s.lt('Ends in {0}', [_dur(_tr.timeLeft)])
                                : s.lt('Starts in {0}', [_dur(_tr.timeLeft)]),
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

  Widget _card({required Widget child, Color? border}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border ?? Colors.indigo.shade100, width: 1.5),
        ),
        child: child,
      );

  /// Takim secimi: 10 takim (yalniz ad + emoji; siralama/puan YOK, o Liderler ekraninda). Secim kesindir.
  Widget _teamPicker(AppStrings s) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.lt('Pick your team'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(s.lt('Your team choice is final for this race: no switching or leaving.'),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(s.lt('Joining closes in {0}', [_dur(_tr.joinTimeLeft)]),
              style: TextStyle(color: Colors.deepOrange.shade700, fontSize: 12, fontWeight: FontWeight.w900)),
          Text(s.lt('Everyone starts together when the countdown ends!'),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var t = 0; t < TeamRace.teamCount; t++)
                  SizedBox(
                    width: w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _join(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Color(TeamRace.teams[t].color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(TeamRace.teams[t].color), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Text(TeamRace.teams[t].emoji, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(TeamRace.teams[t].name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Kayit donemi: takimi secmis oyuncu icin yarisin baslamasina geri sayim.
  Widget _waitCard(AppStrings s) {
    return _card(
      border: Colors.amber.shade600,
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.lt('Race starts in {0}', [_dur(_tr.startsIn)]),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 2),
                Text(s.lt('Everyone starts together when the countdown ends!'),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Katilma suresi dolmus (takimsiz) oyuncu: yarisi izler, bir sonraki yarisa katilir.
  Widget _joinClosedCard(AppStrings s) {
    return _card(
      border: Colors.grey.shade400,
      child: Row(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.lt('Team joining is closed for this race. You can still watch the standings and join the next race!'),
              style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _myTeamCard(AppStrings s) {
    final t = TeamRace.teams[_tr.team];
    return _card(
      border: Color(t.color),
      child: Row(
        children: [
          Text(t.emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.lt('Your team: {0}', [t.name]), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 2),
                Text(s.lt('Your orders: {0}', [_fmt(_tr.orders)]),
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _energyCard(AppStrings s, bool active, int energy) {
    final next = _tr.nextEnergyIn;
    final cd = _tr.adCooldownLeft;
    return _card(
      border: Colors.orange.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.t('energy_title'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(width: 10),
              for (var i = 0; i < TeamRace.maxEnergy; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.bolt_rounded, size: 28, color: i < energy ? Colors.amber.shade700 : Colors.grey.shade300),
                ),
              const Spacer(),
              if (active && next != null)
                Text(s.lt('Next ⚡ in {0}', [_dur(next)]),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          if (!active) ...[
            const SizedBox(height: 6),
            Text(s.lt('The Team Race starts on Monday at 10:00.'), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ],
          if (active && energy < TeamRace.maxEnergy) ...[
            const SizedBox(height: 10),
            CandyButton(
              style: CandyStyle.blue,
              height: 46,
              fontSize: 13,
              maxLines: 2,
              label: _tr.canAdRefill
                  ? '🎬 ${s.lt('Refill with ad (1 per hour)')}'
                  : '🎬 ${s.lt('Ad available again in {0}', [_dur(cd)])}',
              onTap: _tr.canAdRefill ? _refillAd : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _rewardsCard(AppStrings s) {
    return _card(
      border: Colors.amber.shade300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.lt('Team rewards'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          for (var i = 0; i < TeamRace.rankRewards.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 34, child: Text(i == 0 ? '🥇' : i == 1 ? '🥈' : '🥉', style: const TextStyle(fontSize: 22))),
                  Expanded(child: Text(s.lt('Rank {0}', [i + 1]), style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(_rewardText(TeamRace.rankRewards[i]), style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(s.lt('Rewards need at least {0} orders from you.', [TeamRace.minOrders]),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          Text(s.lt('Rewards for your rank are added automatically when the event ends.'),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      ),
    );
  }
}
