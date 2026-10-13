import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 06.10.2026 eklendi — "Sıfırdan Site" için TASLAK koruması.
///
/// Editördeki kaydedilmemiş iş, uygulama kapanırsa / sistem tarafından öldürülürse
/// kaybolmasın diye site JSON'u cihazda dosya olarak tutulur.
///
/// - SharedPreferences DEĞİL dosya: görseller base64 olduğu için içerik MB'lar düzeyinde olabilir.
/// - Yalnızca cihazda durur, sunucuya gitmez. Çıkışta / hesap silmede / kayıtta temizlenir.
/// - Yazma atomik: önce .tmp'ye yazılır, sonra yeniden adlandırılır (yazarken ölürse eski taslak bozulmaz).
class FreeDraft {
  FreeDraft({required this.site, required this.savedAt});
  final Map<String, dynamic> site;
  final DateTime savedAt;
}

class FreeDraftService {
  FreeDraftService._();

  static const _dirName = 'free_drafts';

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/$_dirName');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Anahtar dosya adına çevrilir (yalnız harf/rakam/_/-).
  static String _safe(String key) => key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static Future<File> _file(String key) async => File('${(await _dir()).path}/${_safe(key)}.json');

  /// [siteJson]: `jsonEncode(site.toJson())` — tekrar kodlanmaz, olduğu gibi zarfa konur.
  static Future<void> save(String key, String siteJson) async {
    try {
      final f = await _file(key);
      final tmp = File('${f.path}.tmp');
      final ms = DateTime.now().millisecondsSinceEpoch;
      await tmp.writeAsString('{"v":1,"t":$ms,"site":$siteJson}', flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('FreeDraftService.save hata: $e');
    }
  }

  static Future<FreeDraft?> load(String key) async {
    try {
      final f = await _file(key);
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map || raw['v'] != 1 || raw['site'] is! Map) return null;
      final t = raw['t'];
      return FreeDraft(
        site: Map<String, dynamic>.from(raw['site'] as Map),
        savedAt: DateTime.fromMillisecondsSinceEpoch(t is int ? t : 0),
      );
    } catch (e) {
      // Bozuk taslak: sessizce yok say ve sil.
      debugPrint('FreeDraftService.load hata: $e');
      await clear(key);
      return null;
    }
  }

  static Future<void> clear(String key) async {
    try {
      final f = await _file(key);
      if (await f.exists()) await f.delete();
      final tmp = File('${f.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (e) {
      debugPrint('FreeDraftService.clear hata: $e');
    }
  }

  /// Çıkış yapma / hesap silme: bu cihazdaki tüm taslaklar silinir.
  static Future<void> clearAll() async {
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/$_dirName');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (e) {
      debugPrint('FreeDraftService.clearAll hata: $e');
    }
  }
}
