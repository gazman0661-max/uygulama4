import '../widgets/rewarded_prompt.dart';
import '../widgets/energy_bar.dart';
import '../services/merge_board_service.dart';
import '../models/merge_board.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/game_progress.dart';
import '../models/mb_missions.dart';
import '../models/game_theme.dart';
import '../localization/app_strings.dart';
import '../services/ad_service.dart';
import '../services/game_fx.dart';
import '../utils/duration_format.dart';
import 'level_map_screen.dart';
import 'merge_board_screen.dart';
import 'missions_screen.dart';
import 'album_screen.dart';
import 'town_screen.dart';
import 'wheel_screen.dart';
import 'season_screen.dart';
import 'piggy_screen.dart';
import 'event_screen.dart';
import '../models/engage.dart';
import '../models/weekly_event.dart';
import '../models/piggy.dart';
import '../services/notification_service.dart';
import '../models/season.dart';
import '../models/town.dart';
import 'gem_shop_screen.dart';
import 'inbox_screen.dart';
import '../services/inbox_service.dart';
import 'settings_screen.dart';
import 'upgrades_screen.dart';
import '../widgets/menu_fx.dart';
import '../widgets/ui_kit.dart';
import '../widgets/tutorial_coach.dart';
import '../widgets/guided_tour.dart';
import '../widgets/howto_launcher.dart';
import '../services/analytics_service.dart';

import '../services/log_service.dart';
/// ANA SAYFA: ustte coin / enerji / elmas ikonlari, yanlarda ikon seklinde
/// kisayollar (kumbara, kasaba, cark, sezon, etkinlik), altta ikon cubugu
/// (albüm, gorevler, HARITA, dukkan, menu). Gunluk odul acilista popup olarak
/// cikar. "Oyna" butonu yok: oyuna HARITA ikonundan girilir.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  // Enerji/reklam-kota geri sayimlarinin canli gorunmesi icin periyodik setState.
  Timer? _tickTimer;

  /// Gunluk odul popup'i oturum basina (uygulama acilisinda) bir kez; gun
  /// degisirse (gece yarisi) tekrar cikar.
  bool _dailyDialogOpen = false;

  /// YENI OYUNCU: menu gosterilmeden dogrudan haritaya gidilir; bu sirada
  /// (ve ilk bolum bitip menuye donene kadar) acilis popup'lari bekletilir.
  bool _firstRunGuide = false;

  @override
  void initState() {
    super.initState();
    // v168: ANA OYUN = Mod 2 (merge tahtasi). Yeni oyuncu dogrudan Mod 2'ye (kendi ogreticisi
    // orada) gider; Mod 2 ogreticisi bir kez gorulunce (mb_tut) bu yonlendirme bir daha olmaz.
    if (GameProgress.instance.needsFirstRunGuide && !GameProgress.instance.tutSeen('mb_tut')) {
      _firstRunGuide = true;
      AnalyticsService.instance.log('tut_firstrun_mb');
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, __, ___) => const MergeBoardScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          ),
        );
        _firstRunGuide = false;
        if (mounted) setState(() {});
      });
    }
    // Ilk bolum bitince (menuye donuldugunde) bildirim izni bir kez istenir.
    if (GameProgress.instance.maxUnlockedChapter >= 2) {
      Future.delayed(const Duration(seconds: 2), NotificationService.instance.requestPermissionOnce);
    }
    unawaited(MergeBoardService.instance.load()); // ust cubuktaki Surukle-Birak enerjisi icin
    GameProgress.instance.refreshMissions();
    InboxService.instance.maybeSync(); // gelen kutusu + davet durumu: yalnizca acilista (periyodik yenileme yok)
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Menu baska bir ekranin (oyun/harita) altindayken tum menuyu her
      // saniye yeniden kurmak oyunu kasiyordu; sadece ustteyken yenile.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      setState(() {});
      _maybeShowPopups();
      _maybeStartTour();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPopups());
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  /// Acilis popup'lari: once hos geldin / geri donus hediyesi, sonra gunluk
  /// odul. Her biri kendi "acik mi" bayragini kontrol ettigi icin periyodik
  /// cagrilarda ust uste binmez.
  Future<void> _maybeShowPopups() async {
    if (_firstRunGuide) return;
    await _maybeShowGift();
    await _maybeShowDaily();
  }

  bool _giftDialogOpen = false;

  /// Hos geldin / geri donus hediyesi bekliyorsa (menu ustte iken) gosterir.
  Future<void> _maybeShowGift() async {
    if (_giftDialogOpen || _dailyDialogOpen || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final eg = EngageService.instance;
    final bool welcome = eg.welcomePending;
    final int days = eg.pendingAwayDays;
    if (!welcome && days <= 0) return;
    _giftDialogOpen = true;
    final s = AppStrings.instance;
    final r = welcome ? EngageService.welcomeReward : EngageService.comebackReward(days);
    final parts = <String>[];
    if (r.coins > 0) parts.add('🪙 ${r.coins}');
    if (r.gems > 0) parts.add('💎 ${r.gems}');
    if (r.energy) parts.add('⚡ ${s.t('gift_energy')}');
    if (r.booster != null) parts.add('🎁 1');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameAlertDialog(
        title: Text(s.t(welcome ? 'welcome_title' : 'back_title'), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.t(welcome ? 'welcome_body' : 'back_body'), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            for (final p in parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: CoinText(p, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
        actions: [
          CandyButton(
            height: 52,
            fontSize: 18,
            label: s.t('gift_claim'),
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    if (welcome) {
      eg.claimWelcome();
    } else {
      eg.claimComeback();
    }
    GameFx.instance.reward();
    _giftDialogOpen = false;
    if (mounted) setState(() {});
  }

  /// GUNLUK ODUL popup'i: 7 gunluk seri + buyuk hediye + "AL" butonu.
  /// Yalnizca butonla kapanir (disari dokunarak gecilemez).
  Future<void> _maybeShowDaily() async {
    if (_dailyDialogOpen || _giftDialogOpen || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final gp = GameProgress.instance;
    if (!gp.canClaimDailyReward) return;
    final eg = EngageService.instance;
    if (eg.welcomePending || eg.pendingAwayDays > 0) return;
    _dailyDialogOpen = true;
    await _offerStreakSave(); // v123: seri bozulduysa once kurtarma teklifi
    if (!mounted) {
      _dailyDialogOpen = false;
      return;
    }
    final tr = AppStrings.instance.language == AppLanguage.tr;
    final streak = gp.pendingDailyIndex % GameProgress.dailyRewardCoins.length;
    final amount = gp.nextDailyRewardAmount;
    final gemBonus = gp.nextDailyRewardGems;
    GameFx.instance.reward();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PanelFrame(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.instance.lt('Daily Reward'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
                ),
                Text(
                  AppStrings.instance.lt('Streak: day {0}/7', [streak + 1]),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF8A5A2B)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < GameProgress.dailyRewardCoins.length; i++)
                      Expanded(child: _DayChip(index: i, streak: streak)),
                  ],
                ),
                const SizedBox(height: 14),
                Bobbing(
                  amplitude: 6,
                  child: Image.asset('assets/images/ui/gift.webp', width: 110, height: 110),
                ),
                const SizedBox(height: 6),
                CoinText(
                  '+$amount 🪙${gemBonus > 0 ? '   +$gemBonus 💎' : ''}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
                ),
                const SizedBox(height: 16),
                CandyButton(
                  height: 60,
                  fontSize: 22,
                  pulse: true,
                  label: AppStrings.instance.lt('CLAIM'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _claimDailyReward();
    _dailyDialogOpen = false;
  }

  /// SERI KORUMA (v123): gunluk odul serisi 1-3 gun kacirildiysa elmasla (ya da tek gun
  /// kacirildiysa reklamla) kurtarma teklifi. Sayilar: GameProgress.streakSave*.
  Future<void> _offerStreakSave() async {
    final gp = GameProgress.instance;
    if (!mounted || !gp.canSaveDailyStreak) return;
    final tr = AppStrings.instance.language == AppLanguage.tr;
    final days = gp.dailyStreak + 1; // kaybolacak seri uzunlugu
    final cost = gp.dailyStreakSaveCost;
    final canAd = gp.canSaveDailyStreakWithAd;
    final enough = gp.gems >= cost;
    AnalyticsService.instance.log('streak_save_shown', {'days': days, 'missed': gp.dailyMissedDays});
    GameFx.instance.denied();
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PanelFrame(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 56)),
                Text(
                  AppStrings.instance.lt('Your streak is breaking!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.instance.lt('You can save your {0}-day reward streak. Otherwise you start again from day 1.', [days]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B4A32)),
                ),
                const SizedBox(height: 16),
                CandyButton(
                  height: 56,
                  fontSize: 18,
                  style: CandyStyle.blue,
                  pulse: enough,
                  label: enough
                      ? (AppStrings.instance.lt('Save for 💎 {0}', [cost]))
                      : (AppStrings.instance.lt('Need 💎 {0} (Shop)', [cost])),
                  onTap: () => Navigator.of(ctx).pop(enough ? 'gems' : 'shop'),
                ),
                if (canAd) ...[
                  const SizedBox(height: 10),
                  CandyButton(
                    height: 52,
                    fontSize: 16,
                    style: CandyStyle.orange,
                    icon: Icons.smart_display_outlined,
                    label: AppStrings.instance.lt('Watch Ad, Save'),
                    onTap: () => Navigator.of(ctx).pop('ad'),
                  ),
                ],
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('skip'),
                  child: Text(
                    AppStrings.instance.lt('Let it go'),
                    style: const TextStyle(color: Color(0xFF6B4A32), fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'gems':
        if (gp.saveDailyStreakWithGems()) {
          AnalyticsService.instance.log('streak_save_gems', {'days': days});
          GameFx.instance.reward();
          setState(() {});
        }
        break;
      case 'ad':
        final watched = await watchRewardedAd(
          context,
          prompt: RewardedPrompt(
            icon: '🔥',
            title: AppStrings.instance.lt('Save Streak'),
            reward: AppStrings.instance.lt('{0}-day streak', [days]),
            placement: 'streak_save',
          ),
        );
        if (watched && mounted && gp.saveDailyStreakFree()) {
          AnalyticsService.instance.log('streak_save_ad', {'days': days});
          GameFx.instance.reward();
          setState(() {});
        }
        break;
      case 'shop':
        await _openGemShop();
        if (mounted) await _offerStreakSave(); // elmas aldiysa teklif tekrar
        break;
      default:
        AnalyticsService.instance.log('streak_save_declined', {'days': days});
    }
  }

  void _claimDailyReward() {
    final amount = GameProgress.instance.claimDailyReward();
    if (amount <= 0) return;
    GameFx.instance.reward();
    if (mounted) setState(() {});
  }

  // Cift dokunusta ayni ekranin (ornegin Kasaba) iki kez acilmasini engeller.
  bool _pushing = false;

  Future<void> _push(Widget page) async {
    if (_pushing) {
      AppLog.w('nav', 'cift dokunus engellendi: ${page.runtimeType}');
      return;
    }
    _pushing = true;
    AppLog.i('nav', 'ac: ${page.runtimeType}');
    try {
      GameFx.instance.uiTap();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } finally {
      _pushing = false;
    }
    if (mounted) setState(() {});
  }

  // ── OZELLIK ACILIS VURGULARI (v89) ──────────────────────────────────
  // Bir ozellik ilk kez acildiginda menude o ikon parlar + yaninda tek
  // cumlelik etiket cikar. Ayni anda SADECE BIR vurgu (siradaki). Ikona
  // dokununca tutSeen isaretlenir, vurgu kapanir. Hediye YOK (para birimi
  // degeri dusmesin). Eski kayitlar icin hepsi "gorulmus" sayilir.
  static const List<String> _featOrder = [
    'feat_town',
    'feat_upgrades', // v126: Dukkan (Sv 2)
    'feat_invite', // v126: Arkadas daveti (Sv 3)
    'feat_album', // v126: Album (Sv 4)
    'feat_missions',
    'feat_event',
    'feat_wheel',
    'feat_season',
    'feat_piggy',
  ];
  final Set<String> _featShownLogged = <String>{};

  bool _featUnlocked(String key) {
    final p = GameProgress.instance;
    switch (key) {
      case 'feat_town':
        return p.maxUnlockedChapter >= 2; // ilk bolum bitti -> ilk bina ucretsiz kurulur
      case 'feat_upgrades':
        return p.maxUnlockedChapter >= 2 && p.upgradesTourReady;
      case 'feat_invite':
        return InboxService.isConfigured && p.inviteTourReady; // sunucu yoksa davet turu hic cikmaz
      case 'feat_album':
        return p.albumTourReady;
      case 'feat_missions':
        return p.missionsUnlocked;
      case 'feat_event':
        return p.eventUnlocked;
      case 'feat_wheel':
        return p.wheelUnlocked;
      case 'feat_season':
        return p.seasonUnlocked;
      case 'feat_piggy':
        return p.piggyUnlocked;
    }
    return false;
  }

  String? _activeFeature() {
    final p = GameProgress.instance;
    for (final k in _featOrder) {
      if (_featUnlocked(k) && !p.tutSeen(k)) return k;
    }
    return null;
  }

  /// Ikonun onTap'ini sarar: ilk dokunusta "goruldu" isaretler ve huniye yazar.
  VoidCallback _feat(String key, VoidCallback open) => () {
        final p = GameProgress.instance;
        if (!p.tutSeen(key)) {
          p.markTutSeen(key);
          AnalyticsService.instance.log('tut_feat_tapped_${key.substring(5)}');
          if (mounted) setState(() {});
        }
        GuidedTour.instance.event('${key.substring(5)}_opened');
        open();
      };


  // ── REHBERLI TURLAR (guided_tour.dart) ──────────────────────────────
  // Menu ustteyken, acilis popup'lari yokken siradaki turu baslatir.
  // Eski oyuncular (feat_* zaten goruldu) turu gormez.
  void _maybeStartTour() {
    if (!mounted || _firstRunGuide) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (GuidedTour.instance.active) return;
    final p = GameProgress.instance;
    final key = _activeFeature();
    if (key == null) return;
    final tourKey = 'tour_${key.substring(5)}';
    if (p.tutSeen(tourKey)) return;
    final name = key.substring(5); // town, upgrades, invite, album, missions, event, wheel, season, piggy
    if (key == 'feat_invite') {
      // Mesaj Kutusu > Davetler sekmesi > kod/paylasim > kademe odulleri (v126)
      GuidedTour.instance.start(key: tourKey, steps: [
        const TourStep(target: 'menu_invite', waitFor: 'invite_opened', textKey: 'tour_invite_1'),
        const TourStep(target: 'invite_tab', waitFor: 'invite_tab_opened', textKey: 'tour_invite_2'),
        TourStep(textKey: 'tour_invite_3', textBuilder: _inviteTourShare),
        TourStep(textKey: 'tour_invite_4', textBuilder: _inviteTourRewards, buttonKey: 'tour_gotit'),
      ]);
      return;
    }
    if (key == 'feat_town') {
      if (p.townLevel(0) > 0) {
        p.markTutSeen(tourKey);
        return;
      }
      GuidedTour.instance.start(key: tourKey, steps: const [
        TourStep(textKey: 'tour_town_1'),
        TourStep(target: 'menu_town', waitFor: 'town_opened', textKey: 'tour_town_2'),
        TourStep(target: 'town_plot_0', waitFor: 'building_opened', textKey: 'tour_town_3'),
        TourStep(target: 'town_build_btn', waitFor: 'upgrade_started', textKey: 'tour_town_4'),
        TourStep(target: 'town_skip_btn', waitFor: 'upgrade_skipped', textKey: 'tour_town_5'),
        TourStep(textKey: 'tour_town_6', buttonKey: 'tour_gotit'),
      ]);
      return;
    }
    GuidedTour.instance.start(key: tourKey, steps: [
      TourStep(target: 'menu_$name', waitFor: '${name}_opened', textKey: 'tour_${name}_1'),
      TourStep(textKey: 'tour_${name}_2', buttonKey: 'tour_gotit'),
    ]);
  }

  // Davet turu metinleri: seviye ve odul sayilari sunucu ayarindan (InboxService) gelir.
  String _inviteTourShare() {
    final svc = InboxService.instance;
    final tr = AppStrings.instance.language == AppLanguage.tr;
    return AppStrings.instance.lt('Send your code or invite link to a friend. When they reach level {0} the invite counts and they get {1} 💎!', [svc.qualifyLevel, svc.inviteeBonus]);
  }

  String _inviteTourRewards() {
    final svc = InboxService.instance;
    final tr = AppStrings.instance.language == AppLanguage.tr;
    final fc = svc.tiers.isNotEmpty ? svc.tiers.first.count : InboxService.defaultTiers.first[0];
    final fg = svc.tiers.isNotEmpty ? svc.tiers.first.gems : InboxService.defaultTiers.first[1];
    final lc = svc.tiers.isNotEmpty ? svc.tiers.last.count : InboxService.defaultTiers.last[0];
    final lg = svc.tiers.isNotEmpty ? svc.tiers.last.gems : InboxService.defaultTiers.last[1];
    final redeem = svc.canRedeem
        ? (AppStrings.instance.lt('\\nIf someone sent you a code, enter it before level {0}.', [svc.qualifyLevel]))
        : '';
    return AppStrings.instance.lt('You earn milestone rewards as friends join: {0} 💎 at {1} friend(s), {2} 💎 at {3}! Collect them from this tab.{4}', [fg, fc, lg, lc, redeem]);
  }

  /// Mod 1 (firlat / fizik masasi + harita) - yan oyun, sol sutundaki ikon.
  Future<void> _openMap() {
    AppLog.i('menu', 'Mod 1 (Firlat) ikonuna dokunuldu');
    AnalyticsService.instance.log('mod1_menu_tap');
    return _push(const LevelMapScreen());
  }

  /// ANA OYUN: Mod 2 (merge tahtasi). Ortadaki kahraman obje + alttaki Oyna dugmesi.
  Future<void> _openMain(String from) {
    AppLog.i('menu', 'ANA OYUN (Mod 2) acildi: $from');
    AnalyticsService.instance.log('mb_menu_tap', {'from': from});
    return _push(const MergeBoardScreen());
  }
  /// Kilitli ikona dokunulunca: ozel "Seviye X'te acilir" penceresi (ozellik acilmaz).
  VoidCallback _lockedTap(int level, String image, String name) => () {
        GameFx.instance.denied();
        final cur = GameProgress.instance.playerLevel;
        showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: PanelFrame(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(opacity: 0.45, child: Image.asset(image, width: 96, height: 96, fit: BoxFit.contain)),
                          Image.asset('assets/images/ui/lock.webp', width: 52, height: 52, fit: BoxFit.contain),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00))),
                    const SizedBox(height: 4),
                    Text(AppStrings.instance.lt('🔒 Unlocks at Level {0}', [level]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                    const SizedBox(height: 8),
                    Text(AppStrings.instance.lt('Reach Level {0} to unlock this! You are Level {1} now.', [level, cur]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B4A32))),
                    const SizedBox(height: 16),
                    CandyButton(
                      height: 52,
                      fontSize: 18,
                      label: AppStrings.instance.lt('Close'),
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      };

  Future<void> _openMissions() => _push(const MissionsScreen());
  Future<void> _openAlbum() => _push(const AlbumScreen());
  Future<void> _openPiggy() => _push(const PiggyScreen());
  Future<void> _openSeason() => _push(const SeasonScreen());
  Future<void> _openWheel() => _push(const WheelScreen());
  Future<void> _openTown() => _push(const TownScreen());
  void _showLevelInfo() {
    GameFx.instance.uiTap();
    final gp = GameProgress.instance;
    final need = GameProgress.xpNeededForLevel(gp.playerLevel);
    final tr = AppStrings.instance.language == AppLanguage.tr;
    showDialog(
      context: context,
      builder: (ctx) => GameAlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.instance.lt('Level {0}', [gp.playerLevel]),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: gp.levelProgress, minHeight: 12),
            ),
            const SizedBox(height: 6),
            Text('${gp.playerXp} / $need XP', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              AppStrings.instance.lt('Earn XP by completing chapters.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGemShop() => _push(const GemShopScreen());
  Future<void> _openUpgrades() => _push(const UpgradesScreen());
  Future<void> _openInbox() => _push(const InboxScreen());
  Future<void> _openEvent() => _push(const EventScreen());
  Future<void> _openSettings() => _push(const SettingsScreen());

  /// Sol sutundaki "Bedava elmas" ikonu: rewarded reklam izle -> gunluk hakki varsa elmas ver.
  Future<void> _watchGemAd() async {
    final gp = GameProgress.instance;
    if (gp.adGemsRemaining <= 0) {
      GameFx.instance.uiTap();
      return;
    }
    GameFx.instance.uiTap();
    final tr = AppStrings.instance.language == AppLanguage.tr;
    final watched = await watchRewardedAd(
      context,
      prompt: RewardedPrompt(
        icon: '💎',
        title: AppStrings.instance.lt('Free Gems'),
        reward: AppStrings.instance.lt('Earn +💎 gems'),
        placement: 'free_gems',
      ),
    );
    if (!watched || !mounted) return;
    final got = gp.claimAdGems();
    if (got > 0) {
      GameFx.instance.reward();
      setState(() {});
      showGamePopup(context, '+$got 💎', autoCloseMs: 1600);
    }
  }

  /// Ust cubuktaki enerji rozeti = ANA OYUN (Surukle-Birak) enerjisi. Dokununca "Daha Fazla Enerji?" penceresi.
  Future<void> _openEnergyPopup() async {
    await showEnergyPopup(context, mode: EnergyMode.merge);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = GameProgress.instance;
    progress.tickTownUpgrades(); // biten kasaba insaatlarini uygula
    final s = AppStrings.instance;
    final tr = s.language == AppLanguage.tr;
    final activeFeat = _activeFeature();
    if (activeFeat != null && _featShownLogged.add(activeFeat)) {
      AnalyticsService.instance.log('tut_feat_shown_${activeFeat.substring(5)}');
    }
    // Eski parlayan etiket yerine rehberli tur (guided_tour.dart) kullanilir.
    String? hintFor(String key) => null;
    final world = TownCatalog.worldOfChapter(progress.maxUnlockedChapter);
    final activeTheme = ChapterConfig.themeFor(progress.maxUnlockedChapter);
    final heroTier = activeTheme.byLevel(activeTheme.maxLevel);
    final townLevel = progress.townLevel(world);
    final townStage = townLevel <= 3 ? 1 : (townLevel <= 7 ? 2 : 3);
    final townImage = townLevel == 0 ? 'assets/images/town/ruin.webp' : 'assets/images/town/b${world}_s$townStage.webp';
    final mbSvc = MergeBoardService.instance;
    final mbEnergy = mbSvc.loaded ? mbSvc.energy : null;
    final mbNext = (mbEnergy != null && mbEnergy < MbState.maxEnergy)
        ? formatCountdown(Duration(seconds: mbSvc.secondsToNextEnergy))
        : null;
    final piggy = PiggyService.instance;
    final adLeft = progress.adGemsRemaining;
    final adCd = progress.adGemsCooldownRemaining;
    final adLabel = adLeft > 0
        ? (AppStrings.instance.lt('Free 💎 {0}/{1}', [adLeft, GameProgress.adGemsPerWindow]))
        : (adCd != null ? formatCountdown(adCd) : (AppStrings.instance.lt('Free 💎')));

    // Kalabalik olmasin: acilmis ozellikler hep gorunur; kilitlilerden sadece SIRADAKI 2'si (en dusuk seviye).
    final lockedNow = <String, bool>{
      'missions': !progress.missionsUnlocked,
      'event': !progress.eventUnlocked,
      'wheel': !progress.wheelUnlocked,
      'season': !progress.seasonUnlocked,
      'piggy': !progress.piggyUnlocked,
    };
    final shownLocked = <String>{};
    for (final k in const ['missions', 'event', 'wheel', 'season', 'piggy']) { // seviyeye gore artan
      if (lockedNow[k]! && shownLocked.length < 2) shownLocked.add(k);
    }
    bool show(String k) => !lockedNow[k]! || shownLocked.contains(k);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: MenuBackground(world: world)),
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Ortada: ilerlenen dunyanin kahraman objesi (dokununca harita) ──
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, -0.12),
                    child: GestureDetector(
                      onTap: () => _openMain('hero'),
                      child: SizedBox(
                        width: 250,
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(opacity: 0.45, child: const SunburstRays(size: 250)),
                            Positioned(
                              bottom: 30,
                              child: Container(
                                width: 110,
                                height: 16,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(60),
                                  color: Colors.black.withOpacity(0.22),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14)],
                                ),
                              ),
                            ),
                            Bobbing(
                              amplitude: 8,
                              child: Image.asset(heroTier.imagePath, width: 150, height: 150, cacheWidth: 360),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Ust cubuk: SEVIYE | ENERJI | COIN | ELMAS ──
                Positioned(
                  top: 8,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      // Sol ust: OYUNCU SEVIYESI (XP halkali rozet)
                      GestureDetector(
                        onTap: _showLevelInfo,
                        child: _LevelBadge(
                          level: progress.playerLevel,
                          progress: progress.levelProgress,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ENERJI (+) | COIN | MUCEVHER (+): oyun ici ekranlarla ayni cubuk.
                      // Enerji = Surukle-Birak (ana oyun). Firlat enerjisi Firlat ikonunda / Firlat ekranlarinda.
                      Expanded(
                        child: CurrencyPill(
                          iconAsset: 'assets/images/ui/bolt.webp',
                          value: mbEnergy == null ? '–' : '$mbEnergy',
                          sub: mbNext,
                          plus: true,
                          warn: mbEnergy != null && mbEnergy <= 0,
                          onTap: _openEnergyPopup,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CurrencyPill(
                          iconAsset: 'assets/images/coin_icon.webp',
                          value: '${progress.coins}',
                          onTap: _openUpgrades,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CurrencyPill(
                          iconAsset: 'assets/images/ui/gem.webp',
                          value: '${progress.gems}',
                          plus: true,
                          onTap: _openGemShop,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Sol sutun: Reklam izle (bedava elmas), Magaza, Dukkan, Ejderha kumbarasi, Kasaba ──
                // Alt ikon cubugunun ustunde biter; kucuk ekranda ikonlar kendiliginden kuculur.
                Positioned(
                  left: 10,
                  top: 78,
                  bottom: 124,
                  width: 84,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        _SideIcon(
                          image: 'assets/images/ui/gem.webp',
                          label: adLabel,
                          badge: adLeft > 0,
                          dim: adLeft <= 0,
                          corner: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3DBE4E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, size: 17, color: Colors.white),
                          ),
                          onTap: _watchGemAd,
                        ),
                        const SizedBox(height: 10),
                        _SideIcon(
                          image: 'assets/images/ui/nav_shop.webp',
                          label: AppStrings.instance.lt('Store'),
                          onTap: _openGemShop,
                        ),
                        const SizedBox(height: 10),
                        _SideIcon(
                          image: 'assets/images/ui/hammer.webp',
                          label: AppStrings.instance.lt('Shop'),
                          tourId: 'menu_upgrades',
                          onTap: _feat('feat_upgrades', _openUpgrades),
                        ),
                        const SizedBox(height: 10),
                        if (progress.starterOfferRemaining != null) ...[
                          _OfferIcon(
                            image: 'assets/images/ui/gem.webp',
                            tag: AppStrings.instance.lt('DEAL!'),
                            timer: formatCountdown(progress.starterOfferRemaining ?? Duration.zero),
                            onTap: _openGemShop,
                          ),
                          const SizedBox(height: 10),
                        ],
                        _SideIcon(
                          image: townImage,
                          label: AppStrings.instance.lt('Town'),
                          badge: progress.hasTownUpgradeAvailable || progress.hasTownCollectable,
                          hint: hintFor('feat_town'),
                          tourId: 'menu_town',
                          onTap: _feat('feat_town', _openTown),
                        ),
                        const SizedBox(height: 10),
                        _SideIcon(
                          emoji: '🎯',
                          label: AppStrings.instance.lt('Throw Mode'),
                          // Firlat modunun kendi enerjisi (Surukle-Birak enerjisinden ayri).
                          corner: _MiniEnergyChip(text: '${progress.energy}/${GameProgress.maxEnergy}'),
                          onTap: _openMap,
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Sag sutun: Cark, Kumbara, Sezon, Etkinlik ──
                // Hepsi HER ZAMAN gorunur; seviyesi gelmemis olanlar kilitli (kilit + "Lv.X") durur.
                // "?" dugmesinin ustunde biter; kucuk ekranda ikonlar kendiliginden kuculur.
                Positioned(
                  right: 10,
                  top: 78,
                  bottom: 176,
                  width: 84,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        if (show('wheel')) ...[
                        _SideIcon(
                          image: 'assets/images/ui/wheel.webp',
                          label: s.t('wheel_title'),
                          badge: progress.wheelUnlocked && progress.hasWheelReady,
                          hint: hintFor('feat_wheel'),
                          tourId: 'menu_wheel',
                          hintSide: HintSide.left,
                          lockLevel: progress.wheelUnlocked ? null : GameProgress.wheelUnlockLevel,
                          onTap: progress.wheelUnlocked
                              ? _feat('feat_wheel', _openWheel)
                              : _lockedTap(GameProgress.wheelUnlockLevel, 'assets/images/ui/wheel.webp', s.t('wheel_title')),
                        ),
                        const SizedBox(height: 10),
                        ],
                        if (show('piggy')) ...[
                        _SideIcon(
                          image: 'assets/images/ui/dragon_1.webp',
                          label: s.t('piggy_title'),
                          badge: progress.piggyUnlocked && piggy.canBreak,
                          hint: hintFor('feat_piggy'),
                          tourId: 'menu_piggy',
                          hintSide: HintSide.left,
                          lockLevel: progress.piggyUnlocked ? null : GameProgress.piggyUnlockLevel,
                          onTap: progress.piggyUnlocked
                              ? _feat('feat_piggy', _openPiggy)
                              : _lockedTap(GameProgress.piggyUnlockLevel, 'assets/images/ui/dragon_1.webp', s.t('piggy_title')),
                        ),
                        const SizedBox(height: 10),
                        ],
                        if (show('season')) ...[
                        _SideIcon(
                          image: 'assets/images/ui/ticket.webp',
                          label: s.t('season_title'),
                          badge: progress.seasonUnlocked && SeasonService.instance.hasClaimable,
                          hint: hintFor('feat_season'),
                          tourId: 'menu_season',
                          hintSide: HintSide.left,
                          lockLevel: progress.seasonUnlocked ? null : GameProgress.seasonUnlockLevel,
                          onTap: progress.seasonUnlocked
                              ? _feat('feat_season', _openSeason)
                              : _lockedTap(GameProgress.seasonUnlockLevel, 'assets/images/ui/ticket.webp', s.t('season_title')),
                        ),
                        const SizedBox(height: 10),
                        ],
                        if (show('event'))
                        _SideIcon(
                          image: 'assets/images/ui/trophy.webp',
                          label: AppStrings.instance.lt('Event'),
                          badge: progress.eventUnlocked && WeeklyEvent.instance.hasClaimable,
                          hint: hintFor('feat_event'),
                          tourId: 'menu_event',
                          hintSide: HintSide.left,
                          lockLevel: progress.eventUnlocked ? null : GameProgress.eventUnlockLevel,
                          onTap: progress.eventUnlocked
                              ? _feat('feat_event', _openEvent)
                              : _lockedTap(GameProgress.eventUnlockLevel, 'assets/images/ui/trophy.webp', AppStrings.instance.lt('Event')),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Nasil oynanir "?" dugmesi (yeni oyuncular icin hep gorunur) ──
                Positioned(
                  right: 14,
                  bottom: 128,
                  child: GlassCircleButton(
                    icon: Icons.question_mark_rounded,
                    size: 42,
                    onTap: () => openHowTo(context),
                  ),
                ),
                // ── Alt ikon cubugu ──
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _BottomDock(
                    items: [
                      _DockItem(
                        image: 'assets/images/ui/nav_album.webp',
                        label: s.t('album_title'),
                        badge: progress.hasAlbumClaimable,
                        tourId: 'menu_album',
                        onTap: _feat('feat_album', _openAlbum),
                      ),
                      if (show('missions'))
                      _DockItem(
                        image: 'assets/images/ui/nav_missions.webp',
                        label: s.t('missions_title'),
                        badge: progress.missionsUnlocked &&
                            (progress.hasMissionClaimable || MbMissions.instance.hasClaimable),
                        hint: hintFor('feat_missions'),
                        tourId: 'menu_missions',
                        lockLevel: progress.missionsUnlocked ? null : GameProgress.missionsUnlockLevel,
                        onTap: progress.missionsUnlocked
                            ? _feat('feat_missions', _openMissions)
                            : _lockedTap(GameProgress.missionsUnlockLevel, 'assets/images/ui/nav_missions.webp', s.t('missions_title')),
                      ),
                      _DockItem(
                        image: 'assets/images/ui/nav_map.webp',
                        label: AppStrings.instance.lt('Play'),
                        big: true,
                        onTap: () => _openMain('dock'),
                      ),
                      _DockItem(
                        image: 'assets/images/ui/gift.webp',
                        label: AppStrings.instance.lt('Inbox'),
                        badge: InboxService.instance.hasBadge,
                        tourId: 'menu_invite',
                        onTap: _feat('feat_invite', _openInbox),
                      ),
                      _DockItem(
                        image: 'assets/images/ui/nav_settings.webp',
                        label: AppStrings.instance.lt('Menu'),
                        onTap: _openSettings,
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
}

/// Sol ustteki oyuncu seviyesi rozeti: altin cerceveli mor rozet gorseli + XP ilerleme halkasi + seviye sayisi.
class _LevelBadge extends StatelessWidget {
  final int level;
  final double progress; // 0..1
  const _LevelBadge({required this.level, required this.progress});

  static const double _size = 60;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset('assets/images/ui/level_badge.webp', width: _size, height: _size, fit: BoxFit.contain),
          // XP halkasi: morun icinde, altin cerceveye degmeden
          SizedBox(
            width: _size * 0.66,
            height: _size * 0.66,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9CF25B)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('LV',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFFFE082), height: 1.0)),
                Text('$level',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fırlat ikonunun köşesindeki küçük enerji rozeti ("3/5").
class _MiniEnergyChip extends StatelessWidget {
  final String text;
  const _MiniEnergyChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1E6E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/ui/bolt.webp', width: 12, height: 12),
          const SizedBox(width: 2),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, height: 1.1)),
        ],
      ),
    );
  }
}

/// Yan kisayol ikonu: resim + altinda konturlu yazi + bildirim noktasi.
class _SideIcon extends StatelessWidget {
  final String image;
  final String? emoji; // doluysa resim yerine bu emoji cizilir (resmi olmayan ozellikler icin)
  final String label;
  final bool badge;
  final VoidCallback onTap;
  final Widget? corner; // ikonun sag alt kosesinde kucuk rozet (ornegin reklam "oynat" isareti)
  final bool dim; // true: soluk (kullanilamaz) gorunum
  final String? hint; // doluysa: ikon parlar + yaninda bu etiket cikar (ozellik acilis vurgusu)
  final HintSide hintSide;
  final String? tourId; // rehberli tur hedefi (guided_tour.dart)
  final int? lockLevel; // doluysa: ikon KILITLI (kilit + "Lv.X"), bu seviyede acilir
  const _SideIcon({
    this.image = '',
    this.emoji,
    required this.label,
    required this.onTap,
    this.tourId,
    this.lockLevel,
    this.badge = false,
    this.corner,
    this.dim = false,
    this.hint,
    this.hintSide = HintSide.right,
  });

  @override
  Widget build(BuildContext context) {
    final w = _inner(context);
    return tourId == null ? w : TourTarget(id: tourId!, child: w);
  }

  Widget _inner(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SpotlightHint(
                  active: hint != null,
                  label: hint ?? '',
                  side: hintSide,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.25),
                      border: Border.all(color: Colors.white.withOpacity(0.55), width: 2),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Opacity(
                      opacity: (dim || lockLevel != null) ? 0.4 : 1.0,
                      child: emoji != null
                          ? FittedBox(fit: BoxFit.contain, child: Text(emoji!, style: const TextStyle(fontSize: 40)))
                          : Image.asset(image, fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (lockLevel != null) Positioned.fill(child: _LockOverlay(level: lockLevel!, size: 34)),
                if (corner != null) Positioned(right: -3, bottom: -3, child: corner!),
                if (badge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE94F4F),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Text('!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, height: 1.0)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
                    Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kilitli ikonun ustune binen kilit gorseli + altinda kucuk "Lv.X" hapi.
class _LockOverlay extends StatelessWidget {
  final int level;
  final double size;
  final double? box; // verilirse overlay bu kare icinde ortalanir (dock); yoksa ustundeki alani doldurur
  const _LockOverlay({required this.level, required this.size, this.box});

  @override
  Widget build(BuildContext context) {
    final w = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Image.asset('assets/images/ui/lock.webp', width: size, height: size, fit: BoxFit.contain),
        Positioned(
          bottom: box != null ? 0 : 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFE082), width: 1),
            ),
            child: Text(
              'Lv.$level',
              maxLines: 1,
              style: const TextStyle(color: Color(0xFFFFE082), fontSize: 10, fontWeight: FontWeight.w900, height: 1.1),
            ),
          ),
        ),
      ],
    );
    if (box != null) return SizedBox(width: box, height: box, child: w);
    return IgnorePointer(child: w);
  }
}

/// Kisa sureli firsat (baslangic paketi) ikonu: nabiz gibi atan altin parlama,
/// donen isik halkasi, ustte "FIRSAT!" kurdelesi, altta geri sayim hapi.
class _OfferIcon extends StatefulWidget {
  final String image;
  final String tag;
  final String timer;
  final VoidCallback onTap;
  const _OfferIcon({required this.image, required this.tag, required this.timer, required this.onTap});

  @override
  State<_OfferIcon> createState() => _OfferIconState();
}

class _OfferIconState extends State<_OfferIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        width: 84,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
            final scale = 1.0 + 0.05 * pulse;
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFC21A).withOpacity(0.35 + 0.45 * pulse),
                                blurRadius: 10 + 12 * pulse,
                                spreadRadius: 1 + 3 * pulse,
                              ),
                            ],
                            gradient: SweepGradient(
                              transform: GradientRotation(t * 2 * math.pi),
                              colors: const [
                                Color(0xFFFFE066),
                                Color(0xFFFF8A00),
                                Color(0xFFFFF6B0),
                                Color(0xFFFF4E50),
                                Color(0xFFFFE066),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(3.5),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Color(0xFF7B3FE4), Color(0xFF2A0F5E)],
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(widget.image, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      // Ustte egik "FIRSAT!" kurdelesi
                      Positioned(
                        top: -12,
                        child: Transform.rotate(
                          angle: -0.06,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFF5A5A), Color(0xFFC81E3A)],
                              ),
                              border: Border.all(color: const Color(0xFFFFE066), width: 1.6),
                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Text(
                              widget.tag,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                height: 1.1,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(0, 1))],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Sag altta kucuk parlayan yildiz
                      Positioned(
                        right: -2,
                        bottom: 0,
                        child: Opacity(
                          opacity: 0.6 + 0.4 * pulse,
                          child: const Text('✨', style: TextStyle(fontSize: 18, height: 1.0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Geri sayim hapi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF6F00)]),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '⏳ ${widget.timer}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Gunluk odul popup'indaki tek gun kutusu.
class _DayChip extends StatelessWidget {
  final int index;
  final int streak;
  const _DayChip({required this.index, required this.streak});

  @override
  Widget build(BuildContext context) {
    final today = index == streak;
    final past = index < streak;
    final coins = GameProgress.dailyRewardCoins[index];
    final gems = GameProgress.dailyGemsForIndex(index);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: today ? Colors.amber.shade200 : (past ? Colors.green.shade100 : Colors.white.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: today ? Colors.amber.shade700 : Colors.brown.shade200, width: today ? 2.5 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF8A5A2B), height: 1.0)),
          const SizedBox(height: 3),
          past
              ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF2E9E2E))
              : Image.asset('assets/images/coin_icon.webp', width: 18, height: 18),
          const SizedBox(height: 2),
          Text('$coins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00), height: 1.0)),
          if (gems > 0)
            Text('+$gems', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.purple.shade600, height: 1.2)),
        ],
      ),
    );
  }
}

/// Alttaki etiketli ikon cubugu.
class _BottomDock extends StatelessWidget {
  final List<_DockItem> items;
  const _BottomDock({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [for (final it in items) Expanded(child: it)],
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback onTap;
  final bool badge;
  final bool big;
  final String? hint; // doluysa: ikon parlar + ustunde bu etiket cikar (ozellik acilis vurgusu)
  final String? tourId; // rehberli tur hedefi
  final int? lockLevel; // doluysa: ikon KILITLI (kilit + "Lv.X")
  const _DockItem({
    required this.image,
    required this.label,
    required this.onTap,
    this.tourId,
    this.lockLevel,
    this.badge = false,
    this.big = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final w = _inner(context);
    return tourId == null ? w : TourTarget(id: tourId!, child: w);
  }

  Widget _inner(BuildContext context) {
    final size = big ? 78.0 : 54.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Harita (buyuk): arkasinda yesil isik halkasi
              if (big)
                Container(
                  width: size + 8,
                  height: size + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF9CF25B).withOpacity(0.55), const Color(0xFF9CF25B).withOpacity(0.0)],
                    ),
                  ),
                ),
              SpotlightHint(
                active: hint != null,
                label: hint ?? '',
                side: HintSide.top,
                offset: size + 6,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Opacity(
                    opacity: lockLevel != null ? 0.4 : 1.0,
                    child: Image.asset(image, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (lockLevel != null) _LockOverlay(level: lockLevel!, size: 28, box: size),
              if (badge)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.0,
                shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
