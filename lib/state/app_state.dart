import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site_project.dart';
import '../services/notification_service.dart';

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

  // --- PROJELERİM (çoklu proje) ---
  // Ekrandaki tek "slot" (generatedCode/generatedFiles) hâlâ o an üzerinde
  // çalışılan siteyi tutar; bu iki alan ise TÜM kaydedilmiş siteleri
  // (projeleri) saklar. currentProjectId, ekrandaki slotun projects
  // listesindeki hangi kayda karşılık geldiğini işaretler (null ise henüz
  // hiçbir projeye kaydedilmemiş / yeni başlanmış demektir).
  static const _projectsPrefsKey = 'saved_projects_v1';
  static const _currentProjectIdPrefsKey = 'current_project_id';

  List<SiteProject> projects = [];
  String? currentProjectId;

  /// Projelerim ekranında gösterilecek liste: en son güncellenen en üstte.
  List<SiteProject> get projectsByRecency {
    final list = List<SiteProject>.from(projects);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

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
  ///
  /// [projectName] sadece ekrandaki slot HENÜZ hiçbir projeye bağlı
  /// değilse (yeni bir site) Projelerim'deki kaydın adını belirlemek için
  /// kullanılır; devam eden bir projede yoksayılır.
  void updateGeneratedFiles(
    Map<String, String> files, {
    String? projectName,
    ProjectKind? kind,
    String? activeFileName,
  }) {
    generatedFiles = files;
    this.activeFileName = activeFileName ??
        (files.containsKey('index.html')
            ? 'index.html'
            : (files.keys.isNotEmpty ? files.keys.first : null));
    notifyListeners();
    _saveGeneratedFilesToPrefs();
    _touchProjectFromCurrent(nameForNew: projectName, kind: kind);
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
    _touchProjectFromCurrent();
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

    // Projelerim: kaydedilmiş tüm siteler + ekrandaki slotun hangi projeye
    // karşılık geldiği.
    final projectsRaw = prefs.getString(_projectsPrefsKey);
    if (projectsRaw != null && projectsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(projectsRaw) as List;
        projects = decoded
            .map((e) => SiteProject.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        projects = [];
      }
    }
    currentProjectId = prefs.getString(_currentProjectIdPrefsKey);

    // Geriye dönük uyumluluk: bu güncellemeden ÖNCE üretilmiş, henüz hiçbir
    // projeye kaydedilmemiş bir site varsa (eski tek-slot sistemden kalma),
    // Projelerim'de görünmesi için otomatik olarak ilk proje kaydı oluşturulur.
    if (currentProjectId == null &&
        projects.isEmpty &&
        (generatedCode.trim().isNotEmpty || generatedFiles.isNotEmpty)) {
      _touchProjectFromCurrent(nameForNew: 'Mevcut Site');
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

  /// clearGeneratedSite'tan farklı olarak, o an bağlı olan projeyi SİLMEZ
  /// — sadece ekrandaki üretim slotunu boşaltır. Hızlı Araçlar (QR/Biyo
  /// Link/Dijital Kartvizit) yeni, ayrı bir proje üretmeden önce mevcut
  /// site düzenleme oturumunu korumak için kullanılır.
  Future<void> detachSlotForNewProject() async {
    generatedCode = '';
    generatedFiles = {};
    activeFileName = null;
    currentProjectId = null;
    siteMode = SiteMode.single;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_generatedCodePrefsKey);
    await prefs.remove(_generatedFilesPrefsKey);
    await prefs.remove(_activeFilePrefsKey);
    await prefs.remove(_currentProjectIdPrefsKey);
  }

  /// Kullanıcı ekrandaki üretilmiş siteyi SİL butonuyla kendisi silmek
  /// istediğinde çağrılır — hem bellekten hem kalıcı depodan temizler.
  /// Bu işlem geri alınamaz olduğu için, ekrandaki slot bir projeye
  /// bağlıysa (currentProjectId) o proje kaydı da Projelerim'den silinir.
  Future<void> clearGeneratedSite() async {
    if (currentProjectId != null) {
      projects.removeWhere((p) => p.id == currentProjectId);
    }
    generatedCode = '';
    generatedFiles = {};
    activeFileName = null;
    currentProjectId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_generatedCodePrefsKey);
    await prefs.remove(_generatedFilesPrefsKey);
    await prefs.remove(_activeFilePrefsKey);
    await prefs.remove(_currentProjectIdPrefsKey);
    await _persistProjects();
  }

  // ------------------------------------------------------------------
  // PROJELERİM — çoklu proje yönetimi
  // ------------------------------------------------------------------

  /// Ekrandaki slotun (generatedCode/generatedFiles) içeriğini, o an bağlı
  /// olduğu projeye yazar; henüz hiçbir projeye bağlı değilse YENİ bir
  /// proje kaydı oluşturur. Site üretimi, manuel/AI düzenleme ve içe
  /// aktarma dahil ekrandaki slotu değiştiren HER akış tarafından otomatik
  /// çağrılır — kullanıcının ayrıca "kaydet" demesine gerek yoktur.
  ///
  /// [nameForNew] sadece YENİ bir proje oluşturulacaksa kullanılır (örn.
  /// kullanıcının sohbete yazdığı istek metni ya da içe aktarılan dosya adı).
  Future<void> _touchProjectFromCurrent({String? nameForNew, ProjectKind? kind}) async {
    final hasContent = siteMode == SiteMode.multi
        ? generatedFiles.isNotEmpty
        : generatedCode.trim().isNotEmpty;
    if (!hasContent) return;

    final now = DateTime.now();
    if (currentProjectId == null) {
      final id = now.microsecondsSinceEpoch.toString();
      projects.insert(
        0,
        SiteProject(
          id: id,
          name: _deriveProjectName(nameForNew),
          mode: siteMode,
          kind: kind ?? ProjectKind.site,
          code: generatedCode,
          files: Map<String, String>.from(generatedFiles),
          activeFileName: activeFileName,
          createdAt: now,
          updatedAt: now,
        ),
      );
      currentProjectId = id;
    } else {
      final idx = projects.indexWhere((p) => p.id == currentProjectId);
      if (idx == -1) {
        // Beklenmedik durum (kayıt bulunamadı): yeniden oluştur.
        currentProjectId = null;
        await _touchProjectFromCurrent(nameForNew: nameForNew, kind: kind);
        return;
      }
      projects[idx] = projects[idx].copyWith(
        mode: siteMode,
        kind: kind,
        code: generatedCode,
        files: Map<String, String>.from(generatedFiles),
        activeFileName: activeFileName,
        updatedAt: now,
      );
    }
    notifyListeners();
    await _persistProjects();
  }

  String _deriveProjectName(String? hint) {
    if (hint != null && hint.trim().isNotEmpty) {
      final oneLine = hint.trim().replaceAll(RegExp(r'\s+'), ' ');
      return oneLine.length > 42 ? '${oneLine.substring(0, 42)}…' : oneLine;
    }
    return 'Proje ${projects.length + 1}';
  }

  Future<void> _persistProjects() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _projectsPrefsKey,
      jsonEncode(projects.map((p) => p.toJson()).toList()),
    );
    if (currentProjectId != null) {
      await prefs.setString(_currentProjectIdPrefsKey, currentProjectId!);
    } else {
      await prefs.remove(_currentProjectIdPrefsKey);
    }
  }

  /// Projelerim listesinden bir projeyi ekrandaki slota yükler (DÜZENLE
  /// akışı bunu kullanır). Açmadan önce, o an ekranda açık olan farklı bir
  /// proje varsa önce O kaybolmadan kaydedilir.
  Future<void> openProject(String id) async {
    if (id == currentProjectId) return;
    await _touchProjectFromCurrent();
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final p = projects[idx];
    currentProjectId = p.id;
    siteMode = p.mode;
    generatedCode = p.code;
    generatedFiles = Map<String, String>.from(p.files);
    activeFileName = p.activeFileName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_siteModePrefsKey, p.mode.name);
    await prefs.setString(_generatedCodePrefsKey, p.code);
    await prefs.setString(_generatedFilesPrefsKey, jsonEncode(p.files));
    if (p.activeFileName != null) {
      await prefs.setString(_activeFilePrefsKey, p.activeFileName!);
    } else {
      await prefs.remove(_activeFilePrefsKey);
    }
    await prefs.setString(_currentProjectIdPrefsKey, p.id);
  }

  /// Projelerim listesinden bir projeyi kalıcı olarak siler. Silinen proje
  /// o an ekranda açık olan proje ise ekrandaki slot da temizlenir.
  Future<void> deleteProject(String id) async {
    projects.removeWhere((p) => p.id == id);
    if (currentProjectId == id) {
      generatedCode = '';
      generatedFiles = {};
      activeFileName = null;
      currentProjectId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_generatedCodePrefsKey);
      await prefs.remove(_generatedFilesPrefsKey);
      await prefs.remove(_activeFilePrefsKey);
      await prefs.remove(_currentProjectIdPrefsKey);
    }
    notifyListeners();
    await _persistProjects();
  }

  /// Bir projenin Projelerim'de görünen adını değiştirir.
  Future<void> renameProject(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(name: trimmed, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
  }

  /// Cihazdan içe aktarılan bir dosyayı ekrana yükler.
  ///
  /// ÖNEMLİ: Eskiden içe aktarılan içerik doğrudan tek slota
  /// (generatedCode) yazılıyordu; ekranda o an açık olan farklı bir proje
  /// varsa sessizce onun üzerine yazılıp kayboluyordu. Bunun önüne geçmek
  /// için: önce ekrandaki mevcut proje (varsa) kaybolmadan kaydedilir,
  /// ardından içe aktarılan dosya için AYRI, YENİ bir proje başlatılır.
  Future<void> importCodeAsNewProject(String content, {required String sourceName}) async {
    await _touchProjectFromCurrent();
    currentProjectId = null;
    siteMode = SiteMode.single;
    generatedCode = content;
    generatedFiles = {};
    activeFileName = null;
    await _touchProjectFromCurrent(nameForNew: sourceName);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_siteModePrefsKey, SiteMode.single.name);
    await prefs.setString(_generatedCodePrefsKey, content);
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

  /// [projectName] sadece ekrandaki slot HENÜZ hiçbir projeye bağlı
  /// değilse (yeni bir site) Projelerim'deki kaydın adını belirlemek için
  /// kullanılır; devam eden bir projede yoksayılır.
  void updateGeneratedCode(String code, {String? projectName, ProjectKind? kind}) {
    generatedCode = code;
    notifyListeners();
    _savePrefString(_generatedCodePrefsKey, code);
    _touchProjectFromCurrent(nameForNew: projectName, kind: kind);
  }

  void setGenerating(bool value) {
    isGenerating = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Dışa aktarma sonrası "30 gün sonra güncelle" hatırlatması
  // ---------------------------------------------------------------------
  /// DownloadService ile bir site kaydedildikten/paylaşıldıktan SONRA
  /// çağrılır (ilgili ekranlarda export başarılı olduğunda). Hosting
  /// sorumluluğu kullanıcıda kaldığı için burada sadece 30 gün sonra
  /// yerel bir hatırlatma bildirimi kuruyoruz — riski yok, sunucu yok.
  Future<void> markProjectExported({String? projectNameOverride}) async {
    if (currentProjectId == null) return;
    final idx = projects.indexWhere((p) => p.id == currentProjectId);
    if (idx == -1) return;
    final project = projects[idx];
    await NotificationService.instance.scheduleProjectUpdateReminder(
      projectId: project.id,
      projectName: projectNameOverride ?? project.name,
    );
  }
}
