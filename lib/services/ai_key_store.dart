import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının kendi Gemini API anahtarı ve seçtiği model.
/// Anahtar SADECE cihazın güvenli deposunda tutulur; sunucuya (Worker) hiç gönderilmez.
class AiKeyStore {
  AiKeyStore._();
  static const _storage = FlutterSecureStorage();
  static const _kKey = 'ai_gemini_key';
  static const _kModel = 'ai_gemini_model';

  static Future<String?> readKey() async {
    try {
      final v = await _storage.read(key: _kKey);
      return (v == null || v.trim().isEmpty) ? null : v.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveKey(String key) => _storage.write(key: _kKey, value: key.trim());

  static Future<void> deleteKey() async {
    await _storage.delete(key: _kKey);
    final p = await SharedPreferences.getInstance();
    await p.remove(_kModel);
  }

  static Future<String?> readModel() async => (await SharedPreferences.getInstance()).getString(_kModel);

  static Future<void> saveModel(String id) async =>
      (await SharedPreferences.getInstance()).setString(_kModel, id);

  static Future<bool> isReady() async => (await readKey()) != null && (await readModel()) != null;
}
