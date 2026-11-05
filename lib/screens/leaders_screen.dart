import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/live_events.dart';
import '../models/team_race.dart';
import '../services/game_fx.dart';
import '../widgets/ui_kit.dart';
import 'event_leaderboard_screen.dart';
import 'live_event_screen.dart' show eventTitle, eventEmoji;
import 'team_race_screen.dart';

/// LIDERLER SIRALAMASI: aktif yarislarin (Firlat / Merge Tahtasi) ilk 100 listesi + oyuncunun kendi sirasi.
class LeadersScreen extends StatefulWidget {
  const LeadersScreen({super.key});

  @override
  State<LeadersScreen> createState() => _LeadersScreenState();
}

const String _teamId = '__team_race__';

class _Tab {
  final String id;
  final String emoji;
  final String title;
  const _Tab(this.id, this.emoji, this.title);
}

class _LeadersScreenState extends State<LeadersScreen> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final defs = [for (final d in LiveEvents.instance.activeDefs) if (d.bots != null) d];
    final team = TeamRace.instance.isActive; // takim yarisi haftasinda takim siralamasi da burada
    if (defs.isEmpty && !team) {
      return GameScaffold(
        title: s.lt('Leaders'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              s.lt('No active race right now.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.brown.shade700),
            ),
          ),
        ),
      );
    }
    final tabs = <_Tab>[
      if (team) _Tab(_teamId, '🛡️', s.lt('Team Race')),
      for (final d in defs) _Tab(d.id, eventEmoji(d), eventTitle(d)),
    ];
    final sel = tabs.any((t) => t.id == _sel) ? _sel! : tabs.first.id;
    return GameScaffold(
      title: s.lt('Leaders'),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              children: [
                for (final d in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        GameFx.instance.uiTap();
                        setState(() => _sel = d.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: d.id == sel ? Colors.amber : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade300, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(d.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(d.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: sel == _teamId
                ? const _TeamStandingsBody(key: ValueKey(_teamId))
                : EventLeaderboardBody(key: ValueKey(sel), eventId: sel),
          ),
        ],
      ),
    );
  }
}

/// TAKIM YARISI siralamasi (Liderler ekraninda): 10 takim, kendi takimin vurgulu, bir takima dokununca uyeleri acilir.
/// Saniyede bir tazelenir (botlarin puani zamandan hesaplanir).
class _TeamStandingsBody extends StatefulWidget {
  const _TeamStandingsBody({super.key});

  @override
  State<_TeamStandingsBody> createState() => _TeamStandingsBodyState();
}

class _TeamStandingsBodyState extends State<_TeamStandingsBody> {
  final TeamRace _tr = TeamRace.instance;
  Timer? _tick;
  int _open = -1; // acik takim (uyeleri gosterilen)

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final st = _tr.standings();
    if (st.isEmpty) {
      return Center(child: Text(s.lt('No active race right now.'), style: const TextStyle(fontWeight: FontWeight.w800)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      children: [
        Text(s.lt('Team standings'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 8),
        for (final e in st) ...[
          GestureDetector(
            onTap: () {
              GameFx.instance.uiTap();
              setState(() => _open = _open == e.team ? -1 : e.team);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: e.isMine ? Color(TeamRace.teams[e.team].color).withOpacity(0.16) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: e.rank <= TeamRace.rewardedTeams ? Colors.amber.shade400 : Colors.indigo.shade100,
                  width: e.rank <= TeamRace.rewardedTeams ? 2 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(e.rank == 1 ? '🥇' : e.rank == 2 ? '🥈' : e.rank == 3 ? '🥉' : '#${e.rank}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  Text(TeamRace.teams[e.team].emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(TeamRace.teams[e.team].name,
                        style: TextStyle(fontWeight: e.isMine ? FontWeight.w900 : FontWeight.w700, fontSize: 15)),
                  ),
                  Text(_fmt(e.score), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  Icon(_open == e.team ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
          if (_open == e.team) _members(s, e.team),
        ],
        const SizedBox(height: 10),
        CandyButton(
          label: '🛡️ ${s.lt('Team Race')}',
          height: 50,
          fontSize: 16,
          onTap: () {
            GameFx.instance.uiTap();
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TeamRaceScreen()));
          },
        ),
      ],
    );
  }

  Widget _members(AppStrings s, int team) {
    final m = _tr.members(team, playerName: s.lt('You'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 6, right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          for (var i = 0; i < m.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: m[i].isPlayer ? Colors.amber.withOpacity(0.25) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w800, fontSize: 12))),
                  Expanded(
                    child: Text(m[i].isPlayer ? '⭐ ${m[i].name}' : m[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: m[i].isPlayer ? FontWeight.w900 : FontWeight.w600, fontSize: 13)),
                  ),
                  Text(_fmt(m[i].score), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
