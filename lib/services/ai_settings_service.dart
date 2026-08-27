import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının kendi Gemini API anahtarını ve seçtiği modeli cihazda
/// (SharedPreferences) saklar. Uygulama artık kişisel kullanım için
/// olduğundan (tek kullanıcı) bunlar sunucuya/buluta hiç gönderilmez.
class AiSettingsService {
  AiSettingsService._();
  static final AiSettingsService instance = AiSettingsService._();

  static const _apiKeyPrefsKey = 'gemini_api_key';
  static const _modelPrefsKey = 'gemini_model';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefsKey);
  }

  Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey.trim().isEmpty) {
      await prefs.remove(_apiKeyPrefsKey);
    } else {
      await prefs.setString(_apiKeyPrefsKey, apiKey.trim());
    }
  }

  Future<String?> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelPrefsKey);
  }

  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    if (model.trim().isEmpty) {
      await prefs.remove(_modelPrefsKey);
    } else {
      await prefs.setString(_modelPrefsKey, model.trim());
    }
  }

  Future<bool> isConfigured() async {
    final key = await getApiKey();
    final model = await getModel();
    return key != null && key.isNotEmpty && model != null && model.isNotEmpty;
  }
}
