import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site_project.dart';
import '../services/notification_service.dart';
import '../services/watermark_service.dart';

/// Üretim modu:
/// - single (A modu): tek `.html` dosyası — biolink/kartvizit, hızlı indirme.
/// - multi  (B modu): birden fazla bağlantılı sayfa — zip olarak indirilir,
///   kullanıcı istediği hosting'e yükler.
enum SiteMode { single, multi }

/// Sitora AI uygulamasının merkezi durumu.
/// Üretilen site kodu, aylık FORM/AI puan kotalarını ve seçilen görselleri tutar.
class AppState extends ChangeNotifier {
  // ------------------------------------------------------------------
  // MARKA ROZETİ (WatermarkService)
  // ------------------------------------------------------------------
  // Şu an SABİT true — ödeme sistemi bağlanana kadar TÜM kullanıcılar
  // (ücretsiz/ücretli ayrımı henüz yok) üretilen sitelerde rozeti görür.
  // İleride: kullanıcı domain bağlayınca / marka kaldırma satın alınca
  // bu alan false yapılacak; WatermarkService çağrı noktalarına
  // (aşağıdaki updateGeneratedCode/updateGeneratedFiles/
  // updateQtGeneratedCode/updateQtGeneratedFiles) DOKUNMAYA gerek
  // kalmadan rozet otomatik kalkacak.
  bool hasBranding = true;

  // Aktif uygulama dili (LocaleController ile main.dart'taki
  // ChangeNotifierProxyProvider üzerinden senkron tutulur). WatermarkService
  // çağrılarında rozet metninin TR/EN seçimi için kullanılır. AppState'in
  // kendisi BuildContext'e erişemediği için bu değeri dışarıdan "itiyoruz"
  // (proxy provider'ın update callback'i her dil değişiminde syncLanguage'i
  // çağırır).
  bool isEnglish = false;

  /// LocaleController değiştiğinde main.dart'taki proxy provider tarafından
  /// çağrılır. notifyListeners() YOK — sadece bir sonraki üretimde rozetin
  /// doğru dilde eklenmesi için bayrağı günceller; ekranı yeniden çizmesi
  /// gereken asıl watch LocaleController üzerinden zaten yapılıyor.
  void syncLanguage(bool isEnglish) {
    this.isEnglish = isEnglish;
  }

  // Uygulama kapatılıp açıldığında ekrandaki üretilmiş site kaybolmasın diye
  // bu alanlar da SharedPreferences'ta saklanır. Kullanıcı sadece SİL
  // butonuna bastığında (bkz. clearGeneratedSite) temizlenir.
  static const _generatedCodePrefsKey = 'generated_code';
  static const _generatedFilesPrefsKey = 'generated_files';
  static const _activeFilePrefsKey = 'active_file_name';
  static const _siteModePrefsKey = 'site_mode';

  // --- HIZLI ARAÇLAR (Quick Tools / form ile site oluşturma) İÇİN AYRI SLOT ---
  // AI Chat sohbetinden üretilen/açılan site ile ana sayfadaki Hızlı Araçlar
  // formlarından (Kafe, Kuaför, Emlak vb.) üretilen site TAMAMEN BAĞIMSIZ
  // tutulur. Böylece formdan bir site oluşturmak AI Chat'in ekranındaki veya
  // "ÖN İZLEME"sindeki siteyi asla değiştirmez/geçersiz kılmaz — ikisi de
  // kendi ekranında, kendi hâliyle kalır. (İkisi de yine de Projelerim'e
  // kaydedilir, sadece ekrandaki "aktif" slotları ayrıdır.)
  static const _qtGeneratedCodePrefsKey = 'qt_generated_code';
  static const _qtGeneratedFilesPrefsKey = 'qt_generated_files';
  static const _qtActiveFilePrefsKey = 'qt_active_file_name';
  static const _qtSiteModePrefsKey = 'qt_site_mode';
  static const _qtCurrentProjectIdPrefsKey = 'qt_current_project_id';

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

  // --- Hızlı Araçlar (Quick Tools) ekranındaki BAĞIMSIZ slot ---
  // Yukarıdaki generatedCode/generatedFiles/activeFileName/siteMode AI
  // Chat'e aittir; formdan üretilen siteler SADECE bu alanları kullanır.
  String qtGeneratedCode = '';
  Map<String, String> qtGeneratedFiles = {};
  String? qtActiveFileName;
  SiteMode qtSiteMode = SiteMode.single;
  String? qtCurrentProjectId;

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
    generatedFiles = hasBranding ? WatermarkService.applyToFiles(files, isEnglish: isEnglish) : files;
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
    final isHtml = activeFileName!.toLowerCase().endsWith('.html');
    final finalContent = (hasBranding && isHtml)
        ? WatermarkService.apply(newContent, isEnglish: isEnglish)
        : newContent;
    generatedFiles = {...generatedFiles, activeFileName!: finalContent};
    notifyListeners();
    _saveGeneratedFilesToPrefs();
    _touchProjectFromCurrent();
  }

  // ---------------------------------------------------------------------
  // Hızlı Araçlar (Quick Tools) — yukarıdakilerin BİREBİR karşılığı, ama
  // qtGeneratedCode/qtGeneratedFiles slotuna yazar. AI Chat slotuna hiç
  // dokunmaz.
  // ---------------------------------------------------------------------
  void setQtSiteMode(SiteMode mode) {
    qtSiteMode = mode;
    notifyListeners();
    _savePrefString(_qtSiteModePrefsKey, mode.name);
  }

  void updateQtGeneratedCode(String code, {String? projectName, ProjectKind? kind}) {
    qtGeneratedCode = hasBranding ? WatermarkService.apply(code, isEnglish: isEnglish) : code;
    notifyListeners();
    _savePrefString(_qtGeneratedCodePrefsKey, code);
    _touchQtProjectFromCurrent(nameForNew: projectName, kind: kind);
  }

  void updateQtGeneratedFiles(
    Map<String, String> files, {
    String? projectName,
    ProjectKind? kind,
    String? activeFileName,
  }) {
    qtGeneratedFiles = hasBranding ? WatermarkService.applyToFiles(files, isEnglish: isEnglish) : files;
    qtActiveFileName = activeFileName ??
        (files.containsKey('index.html')
            ? 'index.html'
            : (files.keys.isNotEmpty ? files.keys.first : null));
    notifyListeners();
    _saveQtGeneratedFilesToPrefs();
    _touchQtProjectFromCurrent(nameForNew: projectName, kind: kind);
  }

  void setQtActiveFile(String fileName) {
    if (!qtGeneratedFiles.containsKey(fileName)) return;
    qtActiveFileName = fileName;
    notifyListeners();
    _savePrefString(_qtActiveFilePrefsKey, fileName);
  }

  void updateQtActiveFileContent(String newContent) {
    if (qtActiveFileName == null) return;
    final isHtml = qtActiveFileName!.toLowerCase().endsWith('.html');
    final finalContent = (hasBranding && isHtml)
        ? WatermarkService.apply(newContent, isEnglish: isEnglish)
        : newContent;
    qtGeneratedFiles = {...qtGeneratedFiles, qtActiveFileName!: finalContent};
    notifyListeners();
    _saveQtGeneratedFilesToPrefs();
    _touchQtProjectFromCurrent();
  }

  Future<void> _saveQtGeneratedFilesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qtGeneratedFilesPrefsKey, jsonEncode(qtGeneratedFiles));
    if (qtActiveFileName != null) {
      await prefs.setString(_qtActiveFilePrefsKey, qtActiveFileName!);
    } else {
      await prefs.remove(_qtActiveFilePrefsKey);
    }
  }

  /// Hızlı Araçlar'da yeni bir form gönderilmeden ÖNCE çağrılır: ekrandaki
  /// qt slotunu boşaltır ki her form gönderimi Projelerim'de kendi AYRI
  /// kaydını oluştursun (öncekinin üstüne yazılmasın).
  Future<void> detachQtSlotForNewProject() async {
    qtGeneratedCode = '';
    qtGeneratedFiles = {};
    qtActiveFileName = null;
    qtCurrentProjectId = null;
    qtSiteMode = SiteMode.single;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qtGeneratedCodePrefsKey);
    await prefs.remove(_qtGeneratedFilesPrefsKey);
    await prefs.remove(_qtActiveFilePrefsKey);
    await prefs.remove(_qtCurrentProjectIdPrefsKey);
  }

  bool isGenerating = false;

  // ------------------------------------------------------------------
  // AYLIK ÜCRETSİZ PUAN SİSTEMİ — İKİ BAĞIMSIZ HAVUZ
  // ------------------------------------------------------------------
  // NOT: Şimdilik tamamen CİHAZDA (shared_preferences) tutuluyor. Bu,
  // uygulama verisi silinip yeniden yüklenirse kotanın da sıfırlanacağı
  // anlamına gelir — ileride Google girişi + sunucu tarafı (D1) takibe
  // geçilene kadar bilinçli bir MVP kısıtı.
  //
  // 1) FORM havuzu (form doldur → AI'sız yerel HTML üretimi):
  //    - Tek sayfa üretim = 5 puan, çok sayfa üretim = 10 puan.
  //    - Düzenleme YOK (form akışında düzenleme ekranı bulunmuyor).
  //    - Aylık kota: 30 puan.
  // 2) AI havuzu (AI Chat → Worker/Gemini üzerinden üretim):
  //    - Tek sayfa üretim = 5 puan, çok sayfa üretim = 10 puan,
  //      düzenleme (full_edit/section_edit/bg_edit) = 2 puan.
  //    - Aylık kota: 20 puan.
  //
  // İki havuz TAMAMEN BAĞIMSIZ: form tarafında harcama AI kotasını
  // etkilemez, tersi de öyle. Her ikisi de her ayın 1'inde (UTC ay
  // sınırında) YENİDEN dolar; harcanmayan puan bir sonraki aya
  // TAŞINMAZ.
  static const _formPointsPrefsKey = 'form_points_remaining';
  static const _formPointsResetMonthPrefsKey = 'form_points_reset_month_utc';
  static const _aiPointsPrefsKey = 'ai_points_remaining';
  static const _aiPointsResetMonthPrefsKey = 'ai_points_reset_month_utc';

  static const int maxFormPoints = 30;
  static const int maxAiPoints = 20;

  static const int costSinglePage = 5;
  static const int costMultiPage = 10;
  static const int costEdit = 2;

  int formCredits = maxFormPoints;
  int aiCredits = maxAiPoints;

  String _thisMonthUtcKey() {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// UTC ayı değiştiyse ilgili havuzu tavan değerine sıfırlar
  /// (biriktirmeden). Hem uygulama açılışında hem her puan
  /// kontrolünden önce çağrılır. [isForm] true ise FORM havuzu,
  /// false ise AI havuzu kontrol edilir.
  Future<void> _ensureMonthlyPointsReset(
    bool isForm, {
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final thisMonth = _thisMonthUtcKey();
    final resetKey =
        isForm ? _formPointsResetMonthPrefsKey : _aiPointsResetMonthPrefsKey;
    final pointsKey = isForm ? _formPointsPrefsKey : _aiPointsPrefsKey;
    final max = isForm ? maxFormPoints : maxAiPoints;
    final storedMonth = prefs.getString(resetKey);
    if (storedMonth != thisMonth) {
      if (isForm) {
        formCredits = max;
      } else {
        aiCredits = max;
      }
      await prefs.setString(resetKey, thisMonth);
      await prefs.setInt(pointsKey, max);
      if (notify) notifyListeners();
    }
  }

  /// FORM havuzundan bir üretim öncesi çağrılır (puanı HENÜZ DÜŞMEZ).
  Future<bool> ensureFormQuotaFor(int cost) async {
    await _ensureMonthlyPointsReset(true);
    return formCredits >= cost;
  }

  /// FORM üretimi BAŞARIYLA tamamlandıktan SONRA çağrılmalı.
  Future<void> consumeFormQuota(int cost) async {
    await _ensureMonthlyPointsReset(true, notify: false);
    formCredits = (formCredits - cost).clamp(0, maxFormPoints);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_formPointsPrefsKey, formCredits);
  }

  /// AI havuzundan bir işlem (üretim/düzenleme) öncesi çağrılır
  /// (puanı HENÜZ DÜŞMEZ).
  Future<bool> ensureAiQuotaFor(int cost) async {
    await _ensureMonthlyPointsReset(false);
    return aiCredits >= cost;
  }

  /// AI işlemi BAŞARIYLA tamamlandıktan SONRA çağrılmalı.
  Future<void> consumeAiQuota(int cost) async {
    await _ensureMonthlyPointsReset(false, notify: false);
    aiCredits = (aiCredits - cost).clamp(0, maxAiPoints);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiPointsPrefsKey, aiCredits);
  }

  AppState() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

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

    // Hızlı Araçlar (Quick Tools) qt-slotu: AI Chat'ten tamamen bağımsız,
    // kendi anahtarlarından geri yüklenir.
    qtGeneratedCode = prefs.getString(_qtGeneratedCodePrefsKey) ?? '';
    final qtFilesRaw = prefs.getString(_qtGeneratedFilesPrefsKey);
    if (qtFilesRaw != null && qtFilesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(qtFilesRaw) as Map<String, dynamic>;
        qtGeneratedFiles = decoded.map((k, v) => MapEntry(k, v as String));
      } catch (_) {
        qtGeneratedFiles = {};
      }
    }
    qtActiveFileName = prefs.getString(_qtActiveFilePrefsKey);
    final qtModeRaw = prefs.getString(_qtSiteModePrefsKey);
    if (qtModeRaw != null) {
      qtSiteMode = SiteMode.values.firstWhere(
        (m) => m.name == qtModeRaw,
        orElse: () => SiteMode.single,
      );
    }
    qtCurrentProjectId = prefs.getString(_qtCurrentProjectIdPrefsKey);

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

    // Aylık ücretsiz puan (FORM + AI, bağımsız havuzlar): UTC ayı hâlâ
    // aynıysa kayıtlı kalan puanı yükle, ay değiştiyse tavana sıfırla
    // (biriktirmeden).
    final thisMonth = _thisMonthUtcKey();
    final storedFormMonth = prefs.getString(_formPointsResetMonthPrefsKey);
    if (storedFormMonth == thisMonth) {
      formCredits = prefs.getInt(_formPointsPrefsKey) ?? maxFormPoints;
    } else {
      formCredits = maxFormPoints;
      await prefs.setString(_formPointsResetMonthPrefsKey, thisMonth);
      await prefs.setInt(_formPointsPrefsKey, formCredits);
    }

    final storedAiMonth = prefs.getString(_aiPointsResetMonthPrefsKey);
    if (storedAiMonth == thisMonth) {
      aiCredits = prefs.getInt(_aiPointsPrefsKey) ?? maxAiPoints;
    } else {
      aiCredits = maxAiPoints;
      await prefs.setString(_aiPointsResetMonthPrefsKey, thisMonth);
      await prefs.setInt(_aiPointsPrefsKey, aiCredits);
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

  /// [_touchProjectFromCurrent]'ın Hızlı Araçlar qt-slotu için birebir
  /// karşılığı: aynı paylaşılan `projects` (Projelerim) listesine yazar,
  /// ama AI Chat'in currentProjectId/generatedCode alanlarına DOKUNMAZ —
  /// kendi qtCurrentProjectId/qtGeneratedCode alanlarını kullanır.
  Future<void> _touchQtProjectFromCurrent({String? nameForNew, ProjectKind? kind}) async {
    final hasContent = qtSiteMode == SiteMode.multi
        ? qtGeneratedFiles.isNotEmpty
        : qtGeneratedCode.trim().isNotEmpty;
    if (!hasContent) return;

    final now = DateTime.now();
    if (qtCurrentProjectId == null) {
      final id = now.microsecondsSinceEpoch.toString();
      projects.insert(
        0,
        SiteProject(
          id: id,
          name: _deriveProjectName(nameForNew),
          mode: qtSiteMode,
          kind: kind ?? ProjectKind.site,
          code: qtGeneratedCode,
          files: Map<String, String>.from(qtGeneratedFiles),
          activeFileName: qtActiveFileName,
          createdAt: now,
          updatedAt: now,
        ),
      );
      qtCurrentProjectId = id;
    } else {
      final idx = projects.indexWhere((p) => p.id == qtCurrentProjectId);
      if (idx == -1) {
        qtCurrentProjectId = null;
        await _touchQtProjectFromCurrent(nameForNew: nameForNew, kind: kind);
        return;
      }
      projects[idx] = projects[idx].copyWith(
        mode: qtSiteMode,
        kind: kind,
        code: qtGeneratedCode,
        files: Map<String, String>.from(qtGeneratedFiles),
        activeFileName: qtActiveFileName,
        updatedAt: now,
      );
    }
    notifyListeners();
    await _persistProjects();
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
    generatedCode = hasBranding ? WatermarkService.apply(code, isEnglish: isEnglish) : code;
    notifyListeners();
    _savePrefString(_generatedCodePrefsKey, generatedCode);
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
