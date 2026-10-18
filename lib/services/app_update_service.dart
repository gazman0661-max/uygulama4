import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'remote_tuning.dart';

/// GUVENLI GUNCELLEME KONTROLU (Google Play In-App Updates).
///
/// Eski surumun sorunlari ve cozumleri:
///  - Eski: acilis zincirinin icinde, onaydan hemen sonra, ZORUNLU tam ekran akis calisiyordu.
///    Yeni: acilis zincirinde HIC yok. Ana menu acildiktan 45 sn sonra, menu hala ustteyse
///    (oyuncu bolumde degilse) tek sefer calisir.
///  - Eski: varsayilan ZORUNLU (immediate). Yeni: varsayilan ESNEK (flexible): Play kucuk bir
///    pencere gosterir, indirmeyi arka planda yapar; uygulama otomatik yeniden BASLATILMAZ
///    (completeFlexibleUpdate cagrilmiyor; Play, uygulama arka plandayken kurulumu kendi yapar).
///  - Her olasi tekrar icin arada en az [minGapHours] saat bekler (en fazla 2 gunde bir sorar);
///    sormadan ONCE zamani yazar, boylece bir sorun olsa bile her acilista tekrarlanmaz.
///  - Uzaktan kapatilabilir: Remote Config 'update_enabled' = false -> hicbir sey yapmaz.
///  - Acil durum icin zorunlu mod hala var ama KAPALI: 'update_force' = true yapilirsa
///    (ve Play izin veriyorsa) immediate kullanilir.
///  - Her sey try/catch icinde; hicbir hata oyunu etkilemez. Sadece Play'den kurulu surumde
///    calisir (APK/debug'ta sessizce atlanir).
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static bool get enabled => RemoteTuning.b('update_enabled', true);

  /// true: tam ekran zorunlu. VARSAYILAN false (esnek).
  static bool get forceImmediate => RemoteTuning.b('update_force', false);

  /// Yeni surum yayinlandiktan bu kadar gun gecmeden sorma.
  static int get minStalenessDays => RemoteTuning.i('update_min_stale_days', 3);

  /// Iki soru arasinda en az bu kadar saat.
  static int get minGapHours => RemoteTuning.i('update_gap_hours', 48);

  static const String _kLastAsk = 'update_last_ask_ms_v1';

  bool _checked = false;

  /// Ana menu acildiktan bir sure sonra, tek sefer. Hata firlatmaz.
  Future<void> checkSafely() async {
    if (_checked || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _checked = true;
    try {
      if (!enabled) return;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(_kLastAsk) ?? 0;
      if (last > 0 && now - last < minGapHours * 3600000) return;

      final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 8));
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      final stale = info.clientVersionStalenessDays ?? 0;
      if (stale < minStalenessDays) return;

      // Sormadan ONCE yaz: akis takilsa/coksa bile her acilista tekrar denenmez.
      await prefs.setInt(_kLastAsk, now);

      final immediate = forceImmediate && info.immediateUpdateAllowed;
      AnalyticsService.instance.log('update_available', {
        'stale_days': stale,
        'mode': immediate ? 'immediate' : 'flexible',
      });
      if (immediate) {
        final r = await InAppUpdate.performImmediateUpdate();
        AnalyticsService.instance.log('update_result', {'result': r.name});
      } else if (info.flexibleUpdateAllowed) {
        // Sadece baslatilir; yeniden baslatma Play'e birakilir (oyunu ortasinda kesmeyiz).
        final r = await InAppUpdate.startFlexibleUpdate();
        AnalyticsService.instance.log('update_result', {'result': r.name});
      }
    } catch (_) {
      // Play'den kurulu degil / Play Hizmetleri yok / zaman asimi: oyun normal devam eder.
    }
  }
}
