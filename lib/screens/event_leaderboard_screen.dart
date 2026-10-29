import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../models/live_events.dart';
import '../models/planet_event.dart' show PlanetReward;
import '../widgets/ui_kit.dart';
import 'live_event_screen.dart' show eventTitle;

/// Siralama yuvarlagi rengi: 1. altin, 2. gumus, 3. bronz, digerleri acik turuncu.
Color eventRankColor(int rank) {
  switch (rank) {
    case 1:
      return Colors.amber.shade600;
    case 2:
      return Colors.blueGrey.shade300;
    case 3:
      return Colors.brown.shade300;
    default:
      return Colors.orange.shade100;
  }
}

/// Odul metni: 🪙1000  💎5  ⚡20
String eventRewardText(PlanetReward r) {
  final p = <String>[];
  if (r.coins > 0) p.add('🪙${r.coins}');
  if (r.gems > 0) p.add('💎${r.gems}');
  if (r.energy > 0) p.add('⚡${r.energy}');
  return p.join('  ');
}

/// Siralamada tek satir (ana etkinlik ekrani ve liderlik sayfasi ORTAK kullanir).
/// [rank] gercek sira (1500. bile olsa dogru yazilir). [reward] bos degilse sagda kucuk gorunur.
class EventStandingRow extends StatelessWidget {
  final int rank;
  final RaceStanding standing;
  final double leader;
  final PlanetReward reward;

  const EventStandingRow({
    super.key,
    required this.rank,
    required this.standing,
    required this.leader,
    this.reward = const PlanetReward(),
  });

  Widget _avatar() {
    final e = standing;
    if (e.isPlayer) {
      return CircleAvatar(
        radius: 15,
        backgroundColor: Colors.amber.shade700,
        child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
      );
    }
    final p = e.profile;
    final icon = p?.avatarIcon ?? '';
    return CircleAvatar(
      radius: 15,
      backgroundColor: Color(p?.avatarColor ?? 0xFF5C6BC0),
      child: icon.isNotEmpty
          ? Text(icon, style: const TextStyle(fontSize: 16, height: 1.0))
          : Text(e.name.isEmpty ? '?' : e.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }

  Color _bg(bool me) {
    if (me) return Colors.amber.shade50;
    switch (rank) {
      case 1:
        return const Color(0xFFFFF4C2);
      case 2:
        return const Color(0xFFECEFF1);
      case 3:
        return const Color(0xFFF3E1D3);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = standing;
    final me = e.isPlayer;
    final p = (e.score / (leader < 1 ? 1.0 : leader)).clamp(0.0, 1.0).toDouble();
    final top3 = rank >= 1 && rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bg(me),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: me ? Colors.amber.shade700 : (top3 ? eventRankColor(rank) : Colors.orange.shade200),
          width: me ? 2.5 : (top3 ? 2.0 : 1.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: eventRankColor(rank), borderRadius: BorderRadius.circular(15)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          _avatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: me ? FontWeight.w900 : FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Text('Lv.${me ? GameProgress.instance.playerLevel : (e.profile?.level ?? 1)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: p,
                    backgroundColor: Colors.orange.shade100,
                    valueColor: AlwaysStoppedAnimation(me ? Colors.amber.shade800 : Colors.indigo.shade300),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${e.score}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              if (!reward.isEmpty) CoinText(eventRewardText(reward), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// ETKINLIK LIDERLIK SIRALAMASI: ilk 100 kisi (kaydirilir) + ekranin altinda HER ZAMAN gorunen kendi satirin.
/// 100'un disindaysan gercek siran yazilir (ornek #847) ve "100. siraya X puan kaldi" gosterilir.
class EventLeaderboardScreen extends StatefulWidget {
  final String eventId;
  const EventLeaderboardScreen({super.key, required this.eventId});

  @override
  State<EventLeaderboardScreen> createState() => _EventLeaderboardScreenState();
}

class _EventLeaderboardScreenState extends State<EventLeaderboardScreen> {
  static const int shown = 100;
  final LiveEvents _ev = LiveEvents.instance;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Botlarin puani dakikada bir degisir; oyuncu puani oyundan donunce degisir. 3 sn yeterli.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final d = _ev.byId(widget.eventId);
    final rows = (d == null || d.bots == null)
        ? const <RaceStanding>[]
        : _ev.standings(d, playerName: s.lt('You'), limit: shown);
    if (d == null || rows.isEmpty) {
      return GameScaffold(
        title: s.lt('Leaderboard'),
        body: Center(child: Text(s.lt('This event has ended.'))),
      );
    }
    final myRank = _ev.rank(d);
    final myScore = _ev.score(d);
    final total = _ev.totalRacers(d);
    final leader = rows.first.score < 1 ? 1.0 : rows.first.score.toDouble();
    final me = RaceStanding(s.lt('You'), myScore, true, -1);
    final outside = myRank > shown;
    final toCut = outside ? _ev.pointsToEnter(d, shown) : null;
    final toNext = _ev.pointsToNextRank(d);

    String? hint;
    if (myScore <= 0) {
      hint = s.lt('Play to enter the leaderboard!');
    } else if (toCut != null) {
      hint = s.lt('{0} more to reach #{1}', [toCut, shown]);
    } else if (toNext != null) {
      hint = s.lt('{0} more to reach #{1}', [toNext, myRank - 1]);
    }

    return GameScaffold(
      title: s.lt('Leaderboard'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(eventTitle(d), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                Text(s.lt('{0} players', [total]),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.brown.shade700)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              itemCount: rows.length,
              itemBuilder: (_, i) => EventStandingRow(
                rank: i + 1,
                standing: rows[i],
                leader: leader,
                reward: LiveEvents.rankReward(d, i + 1),
              ),
            ),
          ),
          // Kendi satirin: liste ne kadar kaydirilirsa kaydirilsin altta sabit.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0B2),
              border: Border(top: BorderSide(color: Colors.orange.shade300, width: 2)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EventStandingRow(
                    rank: myRank,
                    standing: me,
                    leader: leader,
                    reward: LiveEvents.rankReward(d, myRank),
                  ),
                  if (hint != null)
                    Text(hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.brown.shade800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
