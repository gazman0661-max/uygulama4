import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/howto_launcher.dart';
import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../services/game_fx.dart';
import '../services/cloud_save_service.dart';
import '../services/ad_service.dart';
import '../widgets/ui_kit.dart';
import '../widgets/game_board.dart';
import '../models/game_theme.dart';
import '../services/analytics_service.dart';
import 'legal_screen.dart';
import 'log_screen.dart';

/// SECENEKLER: muzik, ses efektleri, titresim, dil, kullanim sartlari ve
/// gizlilik politikasi.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool get _tr => AppStrings.instance.language == AppLanguage.tr;

  final CloudSaveService _cloud = CloudSaveService.instance;

  @override
  void initState() {
    super.initState();
    _cloud.addListener(_onCloud);
  }

  @override
  void dispose() {
    _cloud.removeListener(_onCloud);
    super.dispose();
  }

  void _onCloud() {
    if (mounted) setState(() {});
  }

  void _snack(String msg) {
    showGamePopup(context, msg, autoCloseMs: 3000);
  }

  Future<void> _cloudSignIn() async {
    GameFx.instance.uiTap();
    final ok = await _cloud.signIn();
    if (!mounted) return;
    _snack(ok
        ? (AppStrings.instance.lt('Signed in to Google Play Games'))
        : (AppStrings.instance.lt('Sign-in failed')));
  }

  void _toggleMusic() {
    final p = GameProgress.instance;
    p.setMusicEnabled(!p.musicEnabled);
    setState(() {});
  }

  void _toggleSfx() {
    final p = GameProgress.instance;
    p.setSoundEnabled(!p.soundEnabled);
    setState(() {});
    if (p.soundEnabled) GameFx.instance.uiTap(); // acilirken ornek "tik"
  }

  void _toggleHaptics() {
    final p = GameProgress.instance;
    p.setHapticsEnabled(!p.hapticsEnabled);
    setState(() {});
    if (p.hapticsEnabled) GameFx.instance.uiTap(); // acilirken hissettir
  }

  void _toggleScreenFx() {
    final p = GameProgress.instance;
    p.setScreenFxEnabled(!p.screenFxEnabled);
    setState(() {});
  }

  void _toggleLanguage() {
    GameFx.instance.uiTap();
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppStrings.instance.lt('Language'), textAlign: TextAlign.center),
        children: [
          for (final l in AppLanguage.values)
            SimpleDialogOption(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await AppStrings.instance.setLanguage(l);
                if (mounted) setState(() {});
              },
              child: Text(
                AppStrings.nativeName(l),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: l == AppStrings.instance.language ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "Nasil Oynanir?": Bolum 1 rehberini PRATIK modunda tekrar acar
  /// (odul/ilerleme/enerji etkilenmez, ilk teslimatta biter).
  void _openHowTo() => openHowTo(context);

  /// GELISTIRICI: "Nasil Oynanir?" dugmesine UZUN BAS -> ogretici hunisi
  /// (hangi adimda kac kisi cikiyor) cihazdaki sayaclardan gosterilir.
  // ---- GIZLI HATA KAYDI KAPISI ----
  // "Hakkinda" basligina 7 kez hizli dokun -> sifre sor -> LogScreen.
  // Sifreyi degistirmek icin: README'deki v145 notuna bak (FNV-1a hash).
  static const int _logPwHash = 3446228609;
  int _secretTaps = 0;
  DateTime? _secretLast;

  static int _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  void _secretTap() {
    final now = DateTime.now();
    if (_secretLast == null || now.difference(_secretLast!) > const Duration(seconds: 2)) {
      _secretTaps = 0;
    }
    _secretLast = now;
    if (++_secretTaps < 7) return;
    _secretTaps = 0;
    _askLogPassword();
  }

  Future<void> _askLogPassword() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teshis'),
        content: TextField(
          controller: c,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Sifre'),
          onSubmitted: (v) => Navigator.of(ctx).pop(_fnv1a(v.trim()) == _logPwHash),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Iptal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_fnv1a(c.text.trim()) == _logPwHash),
            child: const Text('Ac'),
          ),
        ],
      ),
    );
    // Dialog kapanis animasyonu surerken dispose edilirse "controller disposed" hatasi verir.
    Future<void>.delayed(const Duration(milliseconds: 500), c.dispose);
    if (ok == true && mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogScreen()));
    }
  }

  void _showFunnel() {
    GameFx.instance.uiTap();
    showDialog<void>(
      context: context,
      builder: (ctx) => GameAlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ogretici hunisi (bu cihaz)', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Text(
            AnalyticsService.instance.summary(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          CandyButton(height: 48, fontSize: 17, label: AppStrings.instance.lt('Close'), onTap: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  void _open(LegalKind k) {
    GameFx.instance.uiTap();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(kind: k)));
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF8A5A2B), letterSpacing: 1),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = GameProgress.instance;
    final tr = _tr;
    return GameScaffold(
      title: AppStrings.instance.lt('Settings'),
      showCurrency: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(26, 4, 26, 40),
        children: [
          _section(AppStrings.instance.lt('Sound')),
          _SettingToggle(label: AppStrings.instance.lt('Music'), value: p.musicEnabled, onTap: _toggleMusic),
          const SizedBox(height: 10),
          _SettingToggle(label: AppStrings.instance.lt('Sound Effects'), value: p.soundEnabled, onTap: _toggleSfx),
          _section(AppStrings.instance.lt('Device')),
          _SettingToggle(label: AppStrings.instance.lt('Vibration'), value: p.hapticsEnabled, onTap: _toggleHaptics),
          const SizedBox(height: 10),
          _SettingToggle(label: AppStrings.instance.lt('Screen Effects'), value: p.screenFxEnabled, onTap: _toggleScreenFx),
          if (CloudSaveService.enabled) _section(AppStrings.instance.lt('Game Account')),
          if (CloudSaveService.enabled && !_cloud.signedIn)
            CandyButton(
              label: _cloud.busy ? (AppStrings.instance.lt('Connecting…')) : (AppStrings.instance.lt('Sign in with Google Play Games')),
              icon: Icons.sports_esports,
              style: CandyStyle.green,
              height: 54,
              fontSize: 16,
              onTap: _cloud.busy ? () {} : _cloudSignIn,
            )
          else if (CloudSaveService.enabled) ...[
            Center(
              child: Text(
                AppStrings.instance.lt('✔ Google Play Games connected – progress saves automatically'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
              ),
            ),
          ],
          _section(AppStrings.instance.lt('Language')),
          CandyButton(
            label: AppStrings.nativeName(AppStrings.instance.language).toUpperCase(),
            icon: Icons.language,
            style: CandyStyle.blue,
            height: 54,
            fontSize: 18,
            onTap: _toggleLanguage,
          ),
          _section(AppStrings.instance.lt('Help')),
          GestureDetector(
            onLongPress: _showFunnel,
            child: CandyButton(
              label: AppStrings.instance.t('howto_title'),
              icon: Icons.help_outline,
              style: CandyStyle.blue,
              height: 54,
              fontSize: 18,
              onTap: _openHowTo,
            ),
          ),
          _section(AppStrings.instance.lt('Privacy')),
          CandyButton(
            label: AppStrings.instance.lt('Manage Ad Consent'),
            icon: Icons.privacy_tip_outlined,
            style: CandyStyle.blue,
            height: 54,
            fontSize: 16,
            onTap: () {
              GameFx.instance.uiTap();
              AdService.instance.openAdConsentForm(context);
            },
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _secretTap,
            child: _section(AppStrings.instance.lt('About')),
          ),
          CandyButton(
            label: AppStrings.instance.lt('Terms of Use'),
            style: CandyStyle.blue,
            height: 54,
            fontSize: 17,
            onTap: () => _open(LegalKind.terms),
          ),
          const SizedBox(height: 10),
          CandyButton(
            label: AppStrings.instance.lt('Privacy Policy'),
            style: CandyStyle.blue,
            height: 54,
            fontSize: 17,
            onTap: () => _open(LegalKind.privacy),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text('Worlds Merge  •  v1.0.0',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF8A5A2B))),
          ),
        ],
      ),
    );
  }
}

/// Isaret kutulu mavi ayar butonu: acikken kutuda tik, kapaliyken buton grilesir.
class _SettingToggle extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onTap;
  const _SettingToggle({required this.label, required this.value, required this.onTap});

  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Positioned.fill(child: SlicedBar(base: 'assets/images/ui/btn_blue', filter: value ? null : _grey)),
            Padding(
              padding: const EdgeInsets.only(left: 22, right: 22, bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFF184C9A), width: 2),
                    ),
                    child: value
                        ? const Icon(Icons.check_rounded, size: 22, color: Color(0xFF2E9E2E))
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Color(0xFF184C9A), offset: Offset(0, 2), blurRadius: 3)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
