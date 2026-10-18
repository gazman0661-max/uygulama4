import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'remote_tuning.dart';

import 'log_service.dart';
/// Firebase Remote Config: zorluk/ekonomi sayilarini yeni surum yuklemeden panelden degistirmek icin.
///
/// Firebase Console > Engage > Remote Config > parametre ekle. Anahtar adlari asagidaki listede.
/// Sadece panelde YAYINLANMIS parametreler oyunu etkiler; yayinlanmayan parametre varsayilan kalir.
/// Degerler acilista uygulanir (once cihazdaki son deger, sonra sunucudan tazelenir).
///
/// ANAHTARLAR (varsayilan):
///   order_time_scale_pct (85)    siparis suresi carpani, yuzde (100 = eski sure)
///   penalty_balls (1)            siparis suresi dolunca dusen Lv1 top
///   penalty_balls_late (2)       ... penalty_late_chapter (25) ve sonrasinda
///   penalty_late_chapter (25)
///   pressure_lv3_max_pct (25)    siradaki Lv3 top gelme tavani, yuzde
///   order_floor_ch2 (3)  order_floor_ch3 (8)  order_floor_ch4 (15)  order_floor_ch5 (25)
///                                siparis alt seviyesi 2/3/4/5 olan bolumler
///   shots_per_order (13)  shots_base (15)   sinirli atis: hedef*13+15
///   continue_shots (150)                    devam edince eklenen atis
///   seconds_per_order (12)  seconds_base (30)  continue_seconds (30)   zamanli bolum
///   inter_every_chapters (3)  inter_grace_chapters (6)   gecis reklami sikligi / ilk muaf bolumler
///   update_force (true)  update_min_stale_days (0)       zorunlu guncelleme
///   review_min_chapter (8)                               puanlama isteginin en erken bolumu
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  bool _started = false;

  /// Firebase.initializeApp'tan SONRA cagrilir. Hata oyunu etkilemez.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      _apply(rc); // cihazdaki son aktif degerler
      try {
        await rc.fetchAndActivate().timeout(const Duration(seconds: 10));
        _apply(rc);
      } catch (err) { AppLog.w('remote_config_service.init', 'yutulan hata', err); }
    } catch (err) { AppLog.w('remote_config_service.init', 'yutulan hata', err); }
  }

  void _apply(FirebaseRemoteConfig rc) {
    final out = <String, String>{};
    rc.getAll().forEach((k, v) {
      if (v.source == ValueSource.valueRemote) out[k] = v.asString();
    });
    RemoteTuning.setAll(out);
  }
}
