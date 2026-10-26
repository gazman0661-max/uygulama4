import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/app_strings.dart';
import '../services/analytics_service.dart';
import '../services/game_fx.dart';
import '../services/log_service.dart';
import '../widgets/ui_kit.dart';

/// Bizim diger uygulama / oyunlarimiz. Yeni oyun eklemek icin [kMoreApps] listesine
/// bir satir ekle (ikonu assets/images/apps/ altina koy). Satira dokununca Play Store acilir.
class MoreApp {
  final String id; // analitik icin kisa kimlik
  final String name;
  final String icon; // asset yolu
  final String packageId; // Play Store paket adi
  const MoreApp({required this.id, required this.name, required this.icon, required this.packageId});

  Uri get webUri => Uri.parse('https://play.google.com/store/apps/details?id=$packageId');
  Uri get marketUri => Uri.parse('market://details?id=$packageId');
}

const List<MoreApp> kMoreApps = [
  MoreApp(
    id: 'astrofelyx',
    name: 'Astrofelyx: Galaxy Puzzle',
    icon: 'assets/images/apps/astrofelyx.webp',
    packageId: 'com.astrofelyx.pro',
  ),
];

class MoreGamesScreen extends StatelessWidget {
  const MoreGamesScreen({super.key});

  Future<void> _open(BuildContext context, MoreApp app) async {
    GameFx.instance.uiTap();
    AnalyticsService.instance.log('more_games_tap', {'app': app.id});
    var ok = false;
    try {
      // Once Play Store uygulamasi, olmazsa tarayici.
      ok = await launchUrl(app.marketUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      try {
        ok = await launchUrl(app.webUri, mode: LaunchMode.externalApplication);
      } catch (err) {
        AppLog.w('more_games', 'link acilamadi: ${app.id}', err);
      }
    }
    if (!ok && context.mounted) {
      showGamePopup(context, AppStrings.instance.lt("Couldn't open Google Play."), autoCloseMs: 2200);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    return GameScaffold(
      title: s.lt('Our Games and Apps'),
      showCurrency: false,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: kMoreApps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final app = kMoreApps[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _open(context, app),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE0B97A), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(app.icon, width: 72, height: 72, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          app.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF5D2E00)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.shop_two_rounded, size: 16, color: Color(0xFF2E9E2E)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                s.lt('Open in Google Play'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 30, color: Color(0xFF8A5A2B)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
