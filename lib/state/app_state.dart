import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Üretim modu:
/// - single (A modu): tek `.html` dosyası — biolink/kartvizit, hızlı indirme.
/// - multi  (B modu): birden fazla bağlantılı sayfa — zip olarak indirilir,
///   kullanıcı istediği hosting'e yükler.
enum SiteMode { single, multi }

/// Sitora AI uygulamasının merkezi durumu.
/// API anahtarı, seçili model, üretilen site kodu ve seçilen görselleri tutar.
class AppState extends ChangeNotifier {
  static const _apiKeyPrefsKey = 'gemini_api_key';
  static const _modelPrefsKey = 'gemini_model';
  // Uygulama kapatılıp açıldığında ekrandaki üretilmiş site kaybolmasın diye
  // bu alanlar da SharedPreferences'ta saklanır. Kullanıcı sadece SİL
  // butonuna bastığında (bkz. clearGeneratedSite) temizlenir.
  static const _generatedCodePrefsKey = 'generated_code';
  static const _generatedFilesPrefsKey = 'generated_files';
  static const _activeFilePrefsKey = 'active_file_name';
  static const _siteModePrefsKey = 'site_mode';

  String? apiKey;
  String selectedModel = 'gemini-2.5-flash';
  List<String> availableModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
  ];

  String generatedCode = '';
  final List<File> pickedImages = [];

  // --- A/B Modu ---
  SiteMode siteMode = SiteMode.single;

  /// B modunda (çok sayfa) üretilen dosyalar: dosya adı -> içerik.
  /// Örn: {'index.html': '...', 'urunler.html': '...', 'style.css': '...'}
  Map<String, String> generatedFiles = {};

  /// B modunda düzenle/önizleme ekranlarında hangi dosyanın aktif
  /// (üzerinde çalışılan) olduğunu tutar. generatedFiles içinde bir key.
  String? activeFileName;

  void setSiteMode(SiteMode mode) {
    siteMode = mode;
    notifyListeners();
    _savePrefString(_siteModePrefsKey, mode.name);
  }

  /// B modu çıktısını (dosya haritasını) günceller ve varsayılan olarak
  /// index.html'i aktif dosya yapar.
  void updateGeneratedFiles(Map<String, String> files) {
    generatedFiles = files;
    activeFileName = files.containsKey('index.html')
        ? 'index.html'
        : (files.keys.isNotEmpty ? files.keys.first : null);
    notifyListeners();
    _saveGeneratedFilesToPrefs();
  }

  void setActiveFile(String fileName) {
    if (!generatedFiles.containsKey(fileName)) return;
    activeFileName = fileName;
    notifyListeners();
    _savePrefString(_activeFilePrefsKey, fileName);
  }

  /// Aktif dosyanın içeriğini günceller (DÜZENLE ekranındaki AI/manuel
  /// düzenlemeler bunu çağırır) — diğer dosyalara dokunmaz.
  void updateActiveFileContent(String newContent) {
    if (activeFileName == null) return;
    generatedFiles = {...generatedFiles, activeFileName!: newContent};
    notifyListeners();
    _saveGeneratedFilesToPrefs();
  }

  bool isGenerating = false;

  // ------------------------------------------------------------------
  // GÜNLÜK ÜCRETSİZ PUAN SİSTEMİ
  // ------------------------------------------------------------------
  // Kendi Gemini API anahtarını GİRMEYEN kullanıcılar için: istekler
  // Worker üzerinden (sunucu tarafı anahtarla) yapılır ve puan düşülür.
  // - 1 site oluşturma  (generateSiteCode / generateMultiPageSite) = 5 puan
  // - 1 düzenleme işlemi (editFullCode / editSection / editBackground) = 2 puan
  // - Günlük kota 15 puan, her gün UTC 00:00'da YENİDEN 15'e ayarlanır.
  // - Puanlar GÜN İÇİNDE HARCANMAZSA biriktirilmez / bir sonraki güne
  //   TAŞINMAZ: her yeni UTC günü kota sıfırdan 15 olarak başlar.
  // Kendi API anahtarını giren kullanıcı bu sisteme hiç tabi değildir
  // (sınırsız, doğrudan Gemini'ye gider) — bkz. effectiveApiKey.
  static const _pointsPrefsKey = 'daily_points_remaining';
  static const _pointsResetDatePrefsKey = 'daily_points_reset_date_utc';

  static const int maxDailyPoints = 15;
  static const int costGenerateSite = 5;
  static const int costEdit = 2;

  int credits = maxDailyPoints;
  int maxCredits = maxDailyPoints;

  /// Kendi API anahtarı boşsa (null/'') true — bu kullanıcı ücretsiz
  /// günlük puan kotasına tabidir ve istekleri Worker'a gider.
  bool get usesFreeQuota => apiKey == null || apiKey!.trim().isEmpty;

  /// GeminiService çağrılarına verilecek anahtar: boş string'i null'a
  /// normalize eder (Worker fallback'ini bu null tetikler).
  String? get effectiveApiKey =>
      (apiKey != null && apiKey!.trim().isNotEmpty) ? apiKey : null;

  String _todayUtcKey() {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// UTC günü değiştiyse günlük puanı 15'e sıfırlar (biriktirmeden).
  /// Hem uygulama açılışında hem her puan kontrolünden önce çağrılır.
  Future<void> _ensureDailyPointsReset({bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayUtcKey();
    final storedDate = prefs.getString(_pointsResetDatePrefsKey);
    if (storedDate != today) {
      credits = maxDailyPoints;
      await prefs.setString(_pointsResetDatePrefsKey, today);
      await prefs.setInt(_pointsPrefsKey, credits);
      if (notify) notifyListeners();
    }
  }

  /// Bir AI işlemi öncesi çağrılır. Kendi anahtarı olan kullanıcı için
  /// her zaman true (sınırsız). Ücretsiz kullanıcı için günü kontrol edip
  /// yeterli puan olup olmadığını döner — puanı HENÜZ DÜŞMEZ.
  Future<bool> ensureQuotaFor(int cost) async {
    if (!usesFreeQuota) return true;
    await _ensureDailyPointsReset();
    return credits >= cost;
  }

  /// İşlem BAŞARIYLA tamamlandıktan SONRA çağrılmalı. Kendi anahtarı olan
  /// kullanıcıdan puan düşmez.
  Future<void> consumeQuota(int cost) async {
    if (!usesFreeQuota) return;
    await _ensureDailyPointsReset(notify: false);
    credits = (credits - cost).clamp(0, maxDailyPoints);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsPrefsKey, credits);
  }

  /// Reklam izleyip bonus puan kazanma gibi akışlar için (günlük tavanı
  /// aşmaz, biriktirme kotasının üstüne çıkarmaz).
  Future<void> addCredits(int amount) async {
    await _ensureDailyPointsReset(notify: false);
    credits = (credits + amount).clamp(0, maxDailyPoints);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsPrefsKey, credits);
  }

  AppState() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey = prefs.getString(_apiKeyPrefsKey);
    selectedModel = prefs.getString(_modelPrefsKey) ?? selectedModel;

    // Uygulama kapatılıp yeniden açıldığında ekrandaki üretilmiş site
    // (tek dosya veya çoklu sayfa) kaybolmasın diye burada geri yükleniyor.
    generatedCode = prefs.getString(_generatedCodePrefsKey) ?? '';
    final filesRaw = prefs.getString(_generatedFilesPrefsKey);
    if (filesRaw != null && filesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(filesRaw) as Map<String, dynamic>;
        generatedFiles = decoded.map((k, v) => MapEntry(k, v as String));
      } catch (_) {
        generatedFiles = {};
      }
    }
    activeFileName = prefs.getString(_activeFilePrefsKey);
    final modeRaw = prefs.getString(_siteModePrefsKey);
    if (modeRaw != null) {
      siteMode = SiteMode.values.firstWhere(
        (m) => m.name == modeRaw,
        orElse: () => SiteMode.single,
      );
    }

    // Günlük ücretsiz puan: UTC günü hâlâ aynıysa kayıtlı kalan puanı
    // yükle, gün değiştiyse 15'e sıfırla (biriktirmeden).
    final today = _todayUtcKey();
    final storedDate = prefs.getString(_pointsResetDatePrefsKey);
    if (storedDate == today) {
      credits = prefs.getInt(_pointsPrefsKey) ?? maxDailyPoints;
    } else {
      credits = maxDailyPoints;
      await prefs.setString(_pointsResetDatePrefsKey, today);
      await prefs.setInt(_pointsPrefsKey, credits);
    }

    notifyListeners();
  }

  Future<void> _savePrefString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveGeneratedFilesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_generatedFilesPrefsKey, jsonEncode(generatedFiles));
    if (activeFileName != null) {
      await prefs.setString(_activeFilePrefsKey, activeFileName!);
    } else {
      await prefs.remove(_activeFilePrefsKey);
    }
  }

  /// Kullanıcı ekrandaki üretilmiş siteyi SİL butonuyla kendisi silmek
  /// istediğinde çağrılır — hem bellekten hem kalıcı depodan temizler.
  Future<void> clearGeneratedSite() async {
    generatedCode = '';
    generatedFiles = {};
    activeFileName = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_generatedCodePrefsKey);
    await prefs.remove(_generatedFilesPrefsKey);
    await prefs.remove(_activeFilePrefsKey);
  }

  Future<void> saveApiKey(String key) async {
    apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, key);
    notifyListeners();
  }

  Future<void> deleteApiKey() async {
    apiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPrefsKey);
    notifyListeners();
  }

  Future<void> setModel(String model) async {
    selectedModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPrefsKey, model);
    notifyListeners();
  }

  void addImage(File file) {
    pickedImages.add(file);
    notifyListeners();
  }

  void removeImage(File file) {
    pickedImages.remove(file);
    notifyListeners();
  }

  void clearImages() {
    pickedImages.clear();
    notifyListeners();
  }

  void updateGeneratedCode(String code) {
    generatedCode = code;
    notifyListeners();
    _savePrefString(_generatedCodePrefsKey, code);
  }

  void setGenerating(bool value) {
    isGenerating = value;
    notifyListeners();
  }
}
