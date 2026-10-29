import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/live_events.dart';
import '../models/planet_event.dart' show PlanetReward;
import '../services/game_fx.dart';
import '../widgets/ui_kit.dart';
import 'event_leaderboard_screen.dart';
import 'level_map_screen.dart';
import 'merge_board_screen.dart';

/// Etkinligin ekranda gorunen adi: once uzaktan gelen dil basligi, sonra yerel anahtar, en son id.
String eventTitle(EventDef d) {
  final s = AppStrings.instance;
  final t = d.titleFor(s.language.name);
  if (t.isNotEmpty) return t;
  if (d.titleKey.isNotEmpty) return s.lt(d.titleKey);
  return d.id;
}

/// Ana sayfadaki ikonun altindaki KISA ad (dar ikon: uzun basliklar sigmaz).
String eventMenuLabel(EventDef d) {
  if (d.titles.isEmpty && d.titleKey == 'Merge Board Race') return AppStrings.instance.lt('Merge Race');
  return eventTitle(d);
}

/// Etkinligin ikon emojisi (menu ikonu + etkinlik ekrani basligi).
String eventEmoji(EventDef d) {
  switch (d.metric) {
    case EventMetric.orderMod2:
      return '🧩'; // Merge Tahtasi
    case EventMetric.comboMod1:
      return '🔥';
    default:
      return '🎯'; // Firlat modu
  }
}

/// Etkinligin sayildigi oyun Merge Tahtasi mi (degilse Firlat modu).
bool eventIsMergeBoard(EventDef d) => d.metric == EventMetric.orderMod2;

/// Hedef satirinin metni (metrige gore).
String eventGoalText(String metric, int target) {
  final s = AppStrings.instance;
  if (metric.startsWith('order')) return s.lt('Deliver {0} orders', [target]);
  if (metric.startsWith('merge')) return s.lt('Make {0} merges', [target]);
  return s.lt('Make {0} combos', [target]);
}

/// Puan biriminin kisa metni (metrige gore).
String eventUnitText(String metric) {
  final s = AppStrings.instance;
  if (metric.startsWith('order')) return s.lt('orders delivered');
  if (metric.startsWith('merge')) return s.lt('merges made');
  return s.lt('combos made');
}

/// Genel CANLI ETKINLIK ekrani: hedefler, (botluysa) siralama ve siralama odulleri.
/// Siralama saniyede bir tazelenir (botlarin puani zamandan hesaplanir).
class LiveEventScreen extends StatefulWidget {
  final String eventId;
  const LiveEventScreen({super.key, required this.eventId});

  @override
  State<LiveEventScreen> createState() => _LiveEventScreenState();
}

class _LiveEventScreenState extends State<LiveEventScreen> {
  final LiveEvents _ev = LiveEvents.instance;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ev.flush();
    super.dispose();
  }

  String _left(Duration d) {
    final s = AppStrings.instance;
    final secs = d.inSeconds < 0 ? 0 : d.inSeconds;
    final days = secs ~/ 86400;
    final hours = (secs % 86400) ~/ 3600;
    final mins = (secs % 3600) ~/ 60;
    final rest = secs % 60;
    if (days > 0) return s.lt('{0}d {1}h', [days, hours]);
    if (hours > 0) return s.lt('{0}h {1}m', [hours, mins]);
    return '${mins.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  String _rewardText(PlanetReward r) {
    final p = <String>[];
    if (r.coins > 0) p.add('🪙${r.coins}');
    if (r.gems > 0) p.add('💎${r.gems}');
    if (r.energy > 0) p.add('⚡${r.energy}');
    return p.join('  ');
  }

  /// OYNA: etkinligin sayildigi oyunu acar (Merge Tahtasi ya da Firlat modu haritasi).
  Future<void> _play(EventDef d, bool active) async {
    final s = AppStrings.instance;
    GameFx.instance.uiTap();
    if (!active) {
      showGamePopup(context, s.lt('The next one starts soon.'));
      return;
    }
    final Widget page = eventIsMergeBoard(d) ? const MergeBoardScreen() : const LevelMapScreen();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  static const int _previewCount = 5;

  Future<void> _openLeaderboard(EventDef d) async {
    GameFx.instance.uiTap();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EventLeaderboardScreen(eventId: d.id)));
    if (mounted) setState(() {});
  }

  /// "Bir ust siraya X puan kaldi" yazisi: oyuncuyu oynamaya iten en guclu ipucu.
  Widget _climbHint(AppStrings s, EventDef d, int myRank) {
    String? t;
    if (_ev.score(d) <= 0) {
      t = s.lt('Play to enter the leaderboard!');
    } else {
      final toNext = _ev.pointsToNextRank(d);
      if (toNext != null) t = s.lt('{0} more to reach #{1}', [toNext, myRank - 1]);
    }
    if (t == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(t,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.brown.shade800)),
    );
  }

  void _claim(EventDef d, int i) {
    if (_ev.claim(d, i) != null) GameFx.instance.reward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final d = _ev.byId(widget.eventId);
    if (d == null) {
      // Etkinlik uzaktan kapatilmis olabilir.
      return GameScaffold(
        title: s.lt('Event'),
        body: Center(child: Text(s.lt('This event has ended.'))),
      );
    }
    final active = _ev.isActive(d);
    final hasBots = d.bots != null;
    // Ana ekranda yalnizca ilk 5 + kendi satirin; tamami "Liderlik Sirasi" sayfasinda (ilk 100).
    final standings = hasBots ? _ev.standings(d, playerName: s.lt('You'), limit: _previewCount) : const <RaceStanding>[];
    final double leader = standings.isEmpty ? 1.0 : (standings.first.score < 1 ? 1.0 : standings.first.score.toDouble());
    final myRank = hasBots ? _ev.rank(d) : 0;
    return GameScaffold(
      title: eventTitle(d),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _header(s, d, active),
          const SizedBox(height: 12),
          CandyButton(
            label: s.lt('Play'),
            height: 62,
            fontSize: 24,
            pulse: active,
            onTap: () => _play(d, active),
          ),
          const SizedBox(height: 14),
          if (active && d.goals.isNotEmpty) ...[
            _title(s.lt('Goals')),
            for (var i = 0; i < d.goals.length; i++) _milestone(d, i),
            const SizedBox(height: 14),
          ],
          if (active && hasBots && standings.isNotEmpty) ...[
            _title(s.lt('Standings')),
            for (var i = 0; i < standings.length; i++)
              EventStandingRow(
                rank: i + 1,
                standing: standings[i],
                leader: leader,
                reward: LiveEvents.rankReward(d, i + 1),
              ),
            if (myRank > _previewCount) ...[
              Center(child: Text('⋮', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.brown.shade400))),
              EventStandingRow(
                rank: myRank,
                standing: RaceStanding(s.lt('You'), _ev.score(d), true, -1),
                leader: leader,
                reward: LiveEvents.rankReward(d, myRank),
              ),
            ],
            _climbHint(s, d, myRank),
            const SizedBox(height: 6),
            CandyButton(
              label: s.lt('Full leaderboard'),
              height: 50,
              fontSize: 18,
              style: CandyStyle.blue,
              onTap: () => _openLeaderboard(d),
            ),
            const SizedBox(height: 14),
          ],
          if (hasBots && d.rankRewards.isNotEmpty) ...[
            _title(s.lt('Rank rewards')),
            _rankRewards(d),
            const SizedBox(height: 10),
            Text(
              d.restGetsLast
                  ? s.lt('Rewards for your rank are added automatically when the event ends.')
                  : s.lt('Only the top {0} win rank rewards. They are added automatically when the event ends.', [d.rankRewards.length]),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.brown.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      );

  Widget _header(AppStrings s, EventDef d, bool active) {
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
            child: FittedBox(fit: BoxFit.contain, child: Text(eventEmoji(d), style: const TextStyle(fontSize: 56))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eventTitle(d), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  active ? s.lt('Collect as many as you can before time runs out!') : s.lt('The next one starts soon.'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (active) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_ev.score(d)}',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 28, fontWeight: FontWeight.w900, height: 1.0)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(eventUnitText(d.metric), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
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
                                ? s.lt('Ends in {0}', [_left(_ev.timeLeft(d))])
                                : s.lt('Starts in {0}', [_left(_ev.timeLeft(d))]),
                            style: TextStyle(
                                fontWeight: FontWeight.w900, color: active ? Colors.black87 : Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (active && d.bots != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Text(s.lt('Your rank: #{0}', [_ev.rank(d)]),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 13)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestone(EventDef d, int i) {
    final s = AppStrings.instance;
    final g = d.goals[i];
    final claimed = _ev.isClaimed(d, i);
    final can = _ev.canClaim(d, i);
    final p = (_ev.score(d) / g.target).clamp(0.0, 1.0).toDouble();
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
                Text('${i + 1}. ${eventGoalText(d.metric, g.target)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                CoinText(_rewardText(g.reward), style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: p,
                    backgroundColor: Colors.orange.shade100,
                    valueColor: AlwaysStoppedAnimation(claimed ? Colors.grey : Colors.deepOrange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(Icons.check_circle, color: Colors.green, size: 32)
          else
            CandyButton(
              width: 96,
              height: 42,
              fontSize: 13,
              label: s.t('mission_claim'),
              onTap: can ? () => _claim(d, i) : null,
            ),
        ],
      ),
    );
  }

  /// Ayni oduller art arda geliyorsa tek satirda toplar: 1, 2, 3, 4-5, 6-10.
  Widget _rankRewards(EventDef d) {
    final s = AppStrings.instance;
    final list = d.rankRewards;
    final groups = <({int from, int to, PlanetReward r})>[];
    for (var i = 0; i < list.length; i++) {
      final r = list[i];
      if (groups.isNotEmpty) {
        final g = groups.last;
        if (g.r.coins == r.coins && g.r.gems == r.gems && g.r.energy == r.energy) {
          groups[groups.length - 1] = (from: g.from, to: i + 1, r: g.r);
          continue;
        }
      }
      groups.add((from: i + 1, to: i + 1, r: r));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    height: 26,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: eventRankColor(g.from), borderRadius: BorderRadius.circular(13)),
                    child: Text(g.from == g.to ? '${g.from}' : '${g.from}-${g.to}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      g.from == g.to ? s.lt('Rank {0}', [g.from]) : s.lt('Ranks {0}-{1}', [g.from, g.to]),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  CoinText(_rewardText(g.r), style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
