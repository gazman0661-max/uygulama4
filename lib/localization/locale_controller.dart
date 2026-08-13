import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulamanın desteklediği diller.
enum AppLanguage { tr, en }

/// Uygulama genelinde TR/EN dil tercihini tutar, kullanıcı tercihini
/// cihazda kalıcı olarak saklar ve kullanıcının daha önce bir dil seçip
/// seçmediğini (ilk açılış popup'ı için) izler.
/// (ThemeController ile aynı desen kullanılmıştır.)
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_language';
  static const _hasChosenKey = 'app_language_chosen';

  AppLanguage _language = AppLanguage.tr;
  bool _hasChosenLanguage = false;
  bool _isLoaded = false;

  AppLanguage get language => _language;
  bool get isEnglish => _language == AppLanguage.en;

  /// Kullanıcı daha önce (ilk açılış popup'ında veya ayarlardan)
  /// bilinçli olarak bir dil seçtiyse true döner.
  bool get hasChosenLanguage => _hasChosenLanguage;

  /// Kayıtlı tercih SharedPreferences'tan yüklendi mi?
  bool get isLoaded => _isLoaded;

  LocaleController() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    _hasChosenLanguage = prefs.getBool(_hasChosenKey) ?? false;
    _language = code == 'en' ? AppLanguage.en : AppLanguage.tr;
    _isLoaded = true;
    notifyListeners();
  }

  /// Kullanıcının bilinçli seçimiyle dili ayarlar (ilk açılış popup'ı
  /// veya ayarlar ekranındaki dil seçici için kullanılır).
  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    _hasChosenLanguage = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang == AppLanguage.en ? 'en' : 'tr');
    await prefs.setBool(_hasChosenKey, true);
  }

  Future<void> toggleLanguage() async {
    await setLanguage(isEnglish ? AppLanguage.tr : AppLanguage.en);
  }
}
