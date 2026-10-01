import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { tr, en }

class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_language';
  static const _hasChosenKey = 'app_language_chosen';

  AppLanguage _language = AppLanguage.tr;
  bool _hasChosenLanguage = false;
  bool _isLoaded = false;

  AppLanguage get language => _language;
  bool get isEnglish => _language == AppLanguage.en;

  bool get hasChosenLanguage => _hasChosenLanguage;

  bool get isLoaded => _isLoaded;

  LocaleController() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    _hasChosenLanguage = prefs.getBool(_hasChosenKey) ?? false;
    if (code != null) {
      _language = code == 'en' ? AppLanguage.en : AppLanguage.tr;
    } else {
      final deviceLanguageCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _language = deviceLanguageCode == 'tr' ? AppLanguage.tr : AppLanguage.en;
    }
    _isLoaded = true;
    notifyListeners();
  }

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
