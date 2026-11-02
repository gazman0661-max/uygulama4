import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../services/connectivity_service.dart';
import 'guided_tour.dart';
import 'ui_kit.dart';

/// "Internet yok" uyarisi. Kapatilamaz: kullanici TAMAM'a basinca (ya da geri
/// tusuna basinca) oyundan cikilir.
class NoInternetDialog {
  NoInternetDialog._();

  static bool _showing = false;

  static void _exitGame() => SystemNavigator.pop();

  static Future<void> show(BuildContext context) async {
    if (_showing) return;
    _showing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.78),
        builder: (ctx) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _exitGame();
            },
            child: GameAlertDialog(
              title: Text(AppStrings.instance.lt('No Internet')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 58, color: Color(0xFF5D2E00)),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.instance.lt('An internet connection is required to play. Turn on Wi-Fi or mobile data and start the game again.'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: _exitGame,
                  child: Text(AppStrings.instance.lt('OK')),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _showing = false;
    }
  }

  /// Uygulama arka plandan donunce cagrilir: acilis kontrolu gecildiyse internet
  /// yeniden denenir, yoksa uyari gosterilir.
  static Future<void> recheckOnResume() async {
    final svc = ConnectivityService.instance;
    if (!ConnectivityService.checkOnResume || !svc.startupPassed || _showing) return;
    if (await svc.hasInternet()) return;
    final ctx = GuidedTour.navKey?.currentState?.overlay?.context;
    if (ctx == null || !ctx.mounted) return;
    await show(ctx);
  }
}
