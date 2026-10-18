import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import 'analytics_service.dart';
import 'remote_tuning.dart';

/// ZORUNLU GUNCELLEME (Google Play In-App Updates).
///
/// Oyun acilirken Play'de yeni surum varsa Google'in tam ekran "Guncelle" penceresi cikar;
/// oyuncu guncelleyip oyun kendini yeniden acar (diger oyunlardaki gibi).
///  - Sadece Play'den kurulu surumde calisir. Debug/APK ile kurulu surumde sessizce atlanir.
///  - Yeni surum Play'de "yayinda" olmali; yuklenip yayina girmesi saatler surebilir.
///  - Hicbir hata oyunu engellemez (her sey try/catch icinde).
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  /// true: tam ekran, zorunlu (immediate). false: arka planda indirir, hazir olunca kurar (flexible).
  static bool get forceImmediate => RemoteTuning.b('update_force', true);

  /// Yayinlanmasindan beri bu kadar gun gecmeden zorlama yapma (0 = hemen).
  /// Ornek: 2 yaparsan yeni surum cikinca oyunculara 2 gun sure taninir.
  static int get minStalenessDays => RemoteTuning.i('update_min_stale_days', 0);

  bool _checked = false;

  /// TESHIS: false = zorunlu guncelleme kontrolu tamamen kapali (kayit sifirlama sorunu testi).
  static const bool enabled = false;

  Future<void> check() async {
    if (!enabled) return;
    if (_checked || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _checked = true;
    try {
      // Arayuz/Activity hazir olsun.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 8));
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      final stale = info.clientVersionStalenessDays ?? 0;
      if (stale < minStalenessDays) return;
      AnalyticsService.instance.log('update_available', {
        'stale_days': stale,
        'mode': forceImmediate && info.immediateUpdateAllowed ? 'immediate' : 'flexible',
      });
      if (forceImmediate && info.immediateUpdateAllowed) {
        final r = await InAppUpdate.performImmediateUpdate();
        AnalyticsService.instance.log('update_result', {'result': r.name});
      } else if (info.flexibleUpdateAllowed) {
        final r = await InAppUpdate.startFlexibleUpdate();
        AnalyticsService.instance.log('update_result', {'result': r.name});
        if (r == AppUpdateResult.success) await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {
      // Play'den kurulu degil / Play Hizmetleri yok / zaman asimi: oyun normal acilir.
    }
  }
}
