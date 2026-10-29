/// Uzaktan ayar (Firebase Remote Config) degerlerinin SAF Dart deposu.
///
/// Oyun kodu `RemoteTuning.i('anahtar', varsayilan)` ile okur. Sunucudan deger gelmediyse
/// (internet yok, Firebase kapali, test ortami) varsayilan kullanilir; yani Remote Config
/// olmadan oyun aynen eskisi gibi calisir. Degerleri RemoteConfigService doldurur.
class RemoteTuning {
  RemoteTuning._();

  static final Map<String, String> _v = {};

  static void setAll(Map<String, String> values) {
    _v
      ..clear()
      ..addAll(values);
  }

  static int i(String key, int def) => int.tryParse(_v[key] ?? '') ?? def;

  /// Metin degeri (ornegin JSON). Yoksa [def].
  static String s(String key, [String def = '']) => _v[key] ?? def;

  static double d(String key, double def) => double.tryParse(_v[key] ?? '') ?? def;

  static bool b(String key, bool def) {
    final s = _v[key]?.toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return def;
  }
}
