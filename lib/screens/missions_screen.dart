import '../widgets/ui_kit.dart';
import 'package:flutter/material.dart';
import '../models/game_progress.dart';
import '../models/mb_missions.dart';
import '../localization/app_strings.dart';
import '../services/game_fx.dart';
import '../utils/duration_format.dart';

/// Ana menudeki harita ikonunun SOLUNDAKI "Görevler" ikonuyla acilan
/// ekran. Eskiden gunluk gorevler ana menude 3 ayri kart olarak
/// duruyordu ve cok yer kapliyordu - simdi Gunluk/Haftalik/Aylik
/// sekmeleri halinde burada, ayri bir ekranda gosteriliyor.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Ekran acilirken gun/hafta/ay donumunu kontrol et - boylece
    // gece yarisini, hafta basini ya da ay basini gecmis bir ilerleme
    // hep guncel gorunur.
    GameProgress.instance.refreshMissions();
    MbMissions.instance.refresh(); // donem donumu + "bugun giris" sayimi
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _claim(bool Function() claimFn) {
    if (claimFn()) {
      GameFx.instance.reward();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final progress = GameProgress.instance;

    return GameScaffold(
      title: s.t('missions_title'),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.amber,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: [
          Tab(text: s.t('missions_tab_daily')),
          Tab(text: s.t('missions_tab_weekly')),
          Tab(text: s.t('missions_tab_monthly')),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MissionList(
            period: MbPeriod.daily,
            onChanged: () => setState(() {}),
            children: [
              _MissionRow(
                icon: Icons.local_shipping,
                label: s.missionProgressLabel(
                    progress.missionDeliverProgress, progress.missionDeliverTarget, 'mission_deliver'),
                progress: progress.missionDeliverProgress,
                target: progress.missionDeliverTarget,
                reward: GameProgress.missionDeliverReward,
                claimed: progress.missionDeliverClaimed,
                onClaim: () => _claim(GameProgress.instance.claimDeliverMission),
              ),
              _MissionRow(
                icon: Icons.merge_type,
                label: s.missionProgressLabel(
                    progress.missionMergeProgress, progress.missionMergeTarget, 'mission_merge'),
                progress: progress.missionMergeProgress,
                target: progress.missionMergeTarget,
                reward: GameProgress.missionMergeReward,
                claimed: progress.missionMergeClaimed,
                onClaim: () => _claim(GameProgress.instance.claimMergeMission),
              ),
              _MissionRow(
                icon: Icons.monetization_on,
                label: s.missionProgressLabel(
                    progress.missionCoinsProgress, progress.missionCoinsTarget, 'mission_coins'),
                progress: progress.missionCoinsProgress,
                target: progress.missionCoinsTarget,
                reward: GameProgress.missionCoinsReward,
                claimed: progress.missionCoinsClaimed,
                onClaim: () => _claim(GameProgress.instance.claimCoinsMission),
              ),
            ],
          ),
          _MissionList(
            period: MbPeriod.weekly,
            onChanged: () => setState(() {}),
            children: [
              _MissionRow(
                icon: Icons.local_shipping,
                label: s.missionProgressLabel(progress.missionWeeklyDeliverProgress,
                    progress.missionWeeklyDeliverTarget, 'mission_deliver'),
                progress: progress.missionWeeklyDeliverProgress,
                target: progress.missionWeeklyDeliverTarget,
                reward: GameProgress.missionWeeklyDeliverReward,
                gems: GameProgress.weeklyMissionGems,
                claimed: progress.missionWeeklyDeliverClaimed,
                onClaim: () => _claim(GameProgress.instance.claimWeeklyDeliverMission),
              ),
              _MissionRow(
                icon: Icons.merge_type,
                label: s.missionProgressLabel(
                    progress.missionWeeklyMergeProgress, progress.missionWeeklyMergeTarget, 'mission_merge'),
                progress: progress.missionWeeklyMergeProgress,
                target: progress.missionWeeklyMergeTarget,
                reward: GameProgress.missionWeeklyMergeReward,
                gems: GameProgress.weeklyMissionGems,
                claimed: progress.missionWeeklyMergeClaimed,
                onClaim: () => _claim(GameProgress.instance.claimWeeklyMergeMission),
              ),
              _MissionRow(
                icon: Icons.monetization_on,
                label: s.missionProgressLabel(
                    progress.missionWeeklyCoinsProgress, progress.missionWeeklyCoinsTarget, 'mission_coins'),
                progress: progress.missionWeeklyCoinsProgress,
                target: progress.missionWeeklyCoinsTarget,
                reward: GameProgress.missionWeeklyCoinsReward,
                gems: GameProgress.weeklyMissionGems,
                claimed: progress.missionWeeklyCoinsClaimed,
                onClaim: () => _claim(GameProgress.instance.claimWeeklyCoinsMission),
              ),
            ],
          ),
          _MissionList(
            period: MbPeriod.monthly,
            onChanged: () => setState(() {}),
            children: [
              _MissionRow(
                icon: Icons.local_shipping,
                label: s.missionProgressLabel(progress.missionMonthlyDeliverProgress,
                    progress.missionMonthlyDeliverTarget, 'mission_deliver'),
                progress: progress.missionMonthlyDeliverProgress,
                target: progress.missionMonthlyDeliverTarget,
                reward: GameProgress.missionMonthlyDeliverReward,
                gems: GameProgress.monthlyMissionGems,
                claimed: progress.missionMonthlyDeliverClaimed,
                onClaim: () => _claim(GameProgress.instance.claimMonthlyDeliverMission),
              ),
              _MissionRow(
                icon: Icons.merge_type,
                label: s.missionProgressLabel(
                    progress.missionMonthlyMergeProgress, progress.missionMonthlyMergeTarget, 'mission_merge'),
                progress: progress.missionMonthlyMergeProgress,
                target: progress.missionMonthlyMergeTarget,
                reward: GameProgress.missionMonthlyMergeReward,
                gems: GameProgress.monthlyMissionGems,
                claimed: progress.missionMonthlyMergeClaimed,
                onClaim: () => _claim(GameProgress.instance.claimMonthlyMergeMission),
              ),
              _MissionRow(
                icon: Icons.monetization_on,
                label: s.missionProgressLabel(
                    progress.missionMonthlyCoinsProgress, progress.missionMonthlyCoinsTarget, 'mission_coins'),
                progress: progress.missionMonthlyCoinsProgress,
                target: progress.missionMonthlyCoinsTarget,
                reward: GameProgress.missionMonthlyCoinsReward,
                gems: GameProgress.monthlyMissionGems,
                claimed: progress.missionMonthlyCoinsClaimed,
                onClaim: () => _claim(GameProgress.instance.claimMonthlyCoinsMission),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bir sekmenin icerigi (v187, TEK LISTE): ustte yenilenme sayaci, sonra Mod 2 (ana oyun) gorevleri
/// (alinmamislar ustte, alinanlar altta), donem sandigi, en altta Mod 1 (Firlat) gorevleri.
class _MissionList extends StatelessWidget {
  final MbPeriod period;
  final VoidCallback onChanged;
  final List<Widget> children;
  const _MissionList({required this.period, required this.onChanged, required this.children});

  IconData _icon(MbMetric m) {
    switch (m) {
      case MbMetric.chapters:
        return Icons.flag;
      case MbMetric.orders:
        return Icons.local_shipping;
      case MbMetric.bigMerges:
        return Icons.auto_awesome;
      case MbMetric.energy:
        return Icons.bolt;
      case MbMetric.maxItems:
        return Icons.emoji_events;
      case MbMetric.worlds:
        return Icons.public;
      case MbMetric.activeDays:
        return Icons.event_available;
      case MbMetric.wheel:
        return Icons.casino;
      case MbMetric.ruleChapters:
        return Icons.rule;
      case MbMetric.specialChapters:
        return Icons.stars;
      case MbMetric.chainItems:
        return Icons.account_tree;
    }
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.deepPurple.shade800)),
        ]),
      );

  static String _fmt(Duration d) => formatLongCountdown(d);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final mb = MbMissions.instance;
    final defs = [...MbMissions.defsFor(period)]
      ..sort((a, b) => (mb.isClaimed(a.id) ? 1 : 0).compareTo(mb.isClaimed(b.id) ? 1 : 0));
    final items = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade700,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.shade600, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.amber.shade300),
              const SizedBox(width: 6),
              Text(s.lt('Resets in {0}', [_fmt(mb.timeLeft(period))]),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
      ),
      for (final d in defs)
        _MissionRow(
          icon: _icon(d.metric),
          label: s.lt(MbMissions.labelKey(d.metric), [mb.progressOf(d.id).clamp(0, d.target), d.target]),
          progress: mb.progressOf(d.id),
          target: d.target,
          reward: d.coins,
          gems: d.gems,
          energy: d.energy,
          claimed: mb.isClaimed(d.id),
          onClaim: () {
            if (mb.claim(d.id)) {
              GameFx.instance.reward();
              onChanged();
            }
          },
        ),
      _ChestCard(
        period: period,
        onOpen: () {
          if (mb.claimChest(period)) {
            GameFx.instance.reward();
            onChanged();
          }
        },
      ),
      _header(s.lt('Throw missions')),
      ...children,
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => items[i],
    );
  }
}

/// Donem sandigi: tum gorevler alininca acilir. Aylik sandik buyuk/gorunur odul olarak vurgulanir.
class _ChestCard extends StatelessWidget {
  final MbPeriod period;
  final VoidCallback onOpen;
  const _ChestCard({required this.period, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final mb = MbMissions.instance;
    final c = MbMissions.chestOf(period);
    final total = MbMissions.defsFor(period).length;
    final done = mb.claimedCount(period);
    final opened = mb.isChestClaimed(period);
    final ready = mb.isChestReady(period);
    final big = period == MbPeriod.monthly;
    final title = switch (period) {
      MbPeriod.daily => s.lt('Daily Chest'),
      MbPeriod.weekly => s.lt('Weekly Chest'),
      MbPeriod.monthly => s.lt('Monthly Grand Prize'),
    };
    final parts = <String>[
      if (c.coins > 0) '🪙${c.coins}',
      if (c.gems > 0) '💎${c.gems}',
      if (c.energy > 0) '⚡${c.energy}',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: big
              ? [Colors.amber.shade200, Colors.orange.shade200]
              : [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ready ? Colors.green : (big ? Colors.amber.shade700 : Colors.deepPurple.shade200), width: ready ? 3 : 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Text(opened ? '📭' : (big ? '👑' : '🎁'), style: TextStyle(fontSize: big ? 34 : 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                CoinText(parts.join('  '), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 6,
                    backgroundColor: Colors.white70,
                    valueColor: AlwaysStoppedAnimation(opened ? Colors.grey.shade400 : Colors.green.shade500),
                  ),
                ),
                const SizedBox(height: 3),
                Text(opened ? '✔ $done/$total' : '$done/$total  •  ${s.lt('Claim all missions to open it')}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CandyButton(
            width: 96,
            height: 42,
            fontSize: 12,
            style: CandyStyle.green,
            label: opened ? s.t('mission_claimed') : s.t('mission_claim'),
            onTap: ready ? onOpen : null,
          ),
        ],
      ),
    );
  }
}

/// Tek bir gorev karti - ilerleme cubugu + hedefe ulasilinca aktif
/// olan "Al" butonu. (Eskiden main_menu_screen.dart icindeydi, gorevler
/// ayri bir ekrana tasinirken buraya alindi - gorunumu degismedi.)
class _MissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int progress;
  final int target;
  final int reward;
  final int gems; // ek mucevher odulu (0 = yok)
  final int energy; // ek Mod 2 enerjisi (0 = yok)
  final bool claimed;
  final VoidCallback onClaim;

  const _MissionRow({
    required this.icon,
    required this.label,
    required this.progress,
    required this.target,
    required this.reward,
    this.gems = 0,
    this.energy = 0,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    final done = progress >= target;
    final ratio = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.brown.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(claimed ? Colors.grey.shade400 : Colors.green.shade400),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CandyButton(
            width: 128,
            height: 42,
            fontSize: 11,
            style: CandyStyle.green,
            label: claimed
                ? s.t('mission_claimed')
                : '${s.t('mission_claim')} ${[
                    if (reward > 0) '+$reward',
                    if (gems > 0) '+$gems💎',
                    if (energy > 0) '+$energy⚡',
                  ].join(' ')}',
            onTap: (done && !claimed) ? onClaim : null,
          ),
        ],
      ),
    );
  }
}
