import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// Ilerleme kaydinin DOSYA yedegi (SharedPreferences'tan bagimsiz).
///
/// Neden var: Play'den kurulan surumde "kapat-ac yapinca ilerleme sifirlaniyor"
/// sikayeti geldi. SharedPreferences XML'i bozulur/sifirlanirsa oyun
/// sifirdan baslar. Ayni veri uygulamanin kalici dosya klasorune de yazilir;
/// acilista prefs bos/bozuksa buradan geri yuklenir. (Uygulama verisi
/// tamamen silinirse - "Verileri temizle" / yeniden kurulum - ikisi de gider,
/// o durumda geri getiren tek sey Play Games bulut kaydidir.)
///
/// Tum metotlar hata FIRLATMAZ (testte/eklentisiz ortamda sessizce null doner).
class ProgressMirror {
  ProgressMirror._();

  static const String _name = 'game_progress_mirror_v1.json';
  static const String _canary = 'storage_canary_v1.txt';
  static Directory? _dir;

  static Future<Directory?> _dirOrNull() async {
    if (_dir != null) return _dir;
    try {
      return _dir = await getApplicationSupportDirectory();
    } catch (_) {
      return null; // test ortami / eklenti yok
    }
  }

  /// Atomik yazma: once gecici dosya, sonra yeniden adlandirma.
  static Future<void> write(String data) async {
    try {
      final d = await _dirOrNull();
      if (d == null) return;
      if (!d.existsSync()) d.createSync(recursive: true);
      final tmp = File('${d.path}/$_name.tmp');
      await tmp.writeAsString(data, flush: true);
      await tmp.rename('${d.path}/$_name');
    } catch (err) {
      AppLog.w('mirror', 'yazilamadi', err);
    }
  }

  static Future<String?> read() async {
    try {
      final d = await _dirOrNull();
      if (d == null) return null;
      final f = File('${d.path}/$_name');
      if (!f.existsSync()) return null;
      final s = await f.readAsString();
      return s.isEmpty ? null : s;
    } catch (err) {
      AppLog.w('mirror', 'okunamadi', err);
      return null;
    }
  }

  /// Teshis: uygulama dosya klasoru gercekten kalici mi? Onceki acilistan
  /// kalan kanarya dosyasi var mi, yedek dosya var mi, boyutu ne?
  static Future<String> diagnose() async {
    try {
      final d = await _dirOrNull();
      if (d == null) return 'klasor=YOK';
      final c = File('${d.path}/$_canary');
      final canaryKalmis = c.existsSync();
      final m = File('${d.path}/$_name');
      final mirrorBoyut = m.existsSync() ? m.lengthSync() : 0;
      await c.writeAsString(DateTime.now().toIso8601String(), flush: true);
      return 'klasor=${d.path} dosyaKanaryaOncekindenKalmis=$canaryKalmis yedekBoyut=$mirrorBoyut';
    } catch (err) {
      return 'teshis hatasi: $err';
    }
  }
}
