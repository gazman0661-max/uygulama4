import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/site_project.dart';
import '../services/notification_service.dart';
import '../services/watermark_service.dart';
import '../services/hosting_service.dart';
import '../services/domain_service.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';

/// Üretim modu:
/// - single (A modu): tek `.html` dosyası — biolink/kartvizit, hızlı indirme.
/// - multi  (B modu): birden fazla bağlantılı sayfa — zip olarak indirilir,
///   kullanıcı istediği hosting'e yükler.
enum SiteMode { single, multi }

/// Sitora AI uygulamasının merkezi durumu.
/// Üretilen site kodu, aylık FORM/AI puan kotalarını ve seçilen görselleri tutar.
class AppState extends ChangeNotifier {
  // ------------------------------------------------------------------
  // MARKA ROZETİ (WatermarkService) — SİTE BAZLI, TEK SEFERLİK MODEL
  // ------------------------------------------------------------------
  // Rozet durumu artık HESAP GENELİNDE tek bir global bayrak değil, HER
  // SiteProject'in kendi `watermarkRemoved` alanında tutulur (bkz.
  // models/site_project.dart). Ekrandaki iki bağımsız slot (AI Chat ve
  // Hızlı Araçlar) o an hangi projeye bağlıysa (currentProjectId /
  // qtCurrentProjectId) rozet kararı O projenin bayrağından okunur —
  // aşağıdaki iki getter bunu sağlar. Henüz hiçbir projeye kaydedilmemiş
  // (yepyeni, projects listesinde karşılığı olmayan) bir slot için
  // varsayılan olarak rozetli (true) kabul edilir; proje ilk kez
  // kaydedildiğinde (bkz. _touchProjectFromCurrent/_touchQtProjectFromCurrent)
  // watermarkRemoved=false ile oluşur, yani davranış aynı kalır.
  //
  // SATIN ALMA TAMAMLANDIĞINDA: removeWatermarkForProject(id) çağrılır —
  // bkz. o metodun dokümantasyonu.
  bool get currentHasBranding => !_isWatermarkRemoved(currentProjectId);
  bool get qtCurrentHasBranding => !_isWatermarkRemoved(qtCurrentProjectId);

  bool _isWatermarkRemoved(String? projectId) {
    if (projectId == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].watermarkRemoved;
  }

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
    generatedFiles = currentHasBranding ? WatermarkService.applyToFiles(files, isEnglish: isEnglish) : files;
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
    final finalContent = (currentHasBranding && isHtml)
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
    qtGeneratedCode = qtCurrentHasBranding ? WatermarkService.apply(code, isEnglish: isEnglish) : code;
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
    qtGeneratedFiles = qtCurrentHasBranding ? WatermarkService.applyToFiles(files, isEnglish: isEnglish) : files;
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
    final finalContent = (qtCurrentHasBranding && isHtml)
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
  //    - Aylık kota: 15 puan (eskiden 30'du; ücretsiz kullanıcının puan
  //      satın alma/rozet kaldırma akışlarına daha erken çarpması için
  //      düşürüldü — bkz. sohbet geçmişi/ürün kararı). 15 puanla en az
  //      3 tek-sayfa deneme hakkı kalıyor (5+5+5), bu kasıtlı: kullanıcı
  //      1-2 denemede "olmadı" dese bile hâlâ payı olsun diye 10 DEĞİL
  //      15 seçildi.
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

  static const int maxFormPoints = 15;
  static const int maxAiPoints = 20;

  static const int costSinglePage = 5;
  static const int costMultiPage = 10;
  static const int costEdit = 2;

  int formCredits = maxFormPoints;
  int aiCredits = maxAiPoints;

  // ------------------------------------------------------------------
  // SATIN ALINAN PUAN BAKİYESİ (İSKELET) — bkz. billing_constants.dart
  // (kProductPoints15/30/50/100), billing_service.dart, buy_points_sheet.dart
  // ------------------------------------------------------------------
  // Aylık ücretsiz FORM/AI havuzlarının AKSİNE bu bakiye AYIN 1'İNDE
  // SIFIRLANMAZ — kullanıcı harcayana kadar kalır. Tek, PAYLAŞILAN bir
  // havuzdur (FORM ile AI arasında ayrım yapılmaz); aylık ücretsiz kota
  // bittiğinde ensureFormQuotaFor/ensureAiQuotaFor otomatik olarak bu
  // bakiyeye de bakar, consumeFormQuota/consumeAiQuota önce aylık havuzdan,
  // o yetmezse buradan düşer (bkz. _spendFromPool).
  static const _purchasedPointsPrefsKey = 'purchased_points_balance';
  int purchasedPoints = 0;

  /// Bir puan paketi satın alma tamamlandığında (bkz. BillingService
  /// .buyConsumable başarılı döndükten SONRA) çağrılır.
  Future<void> addPurchasedPoints(int amount) async {
    purchasedPoints += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_purchasedPointsPrefsKey, purchasedPoints);
  }

  // ------------------------------------------------------------------
  // SİTE YAYIN HAKKI (İSKELET) — bkz. billing_constants.dart
  // (kProductPublishSlot), billing_service.dart, publish_paywall_sheet.dart
  // ------------------------------------------------------------------
  // İlk site yayını hesap başına ÜCRETSİZ. İkinci ve sonraki HER YENİ site
  // için (hepsi aynı fiyattan) bir "yayın hakkı" satın alınması gerekir.
  // Bir projeye bir kez hak tanındıktan sonra (SiteProject.publishRightGranted)
  // o proje kaç kez unpublish/republish edilirse edilsin bir daha ödeme
  // istenmez — bkz. canPublishProject/grantPublishRight.
  static const _freeSitePublishUsedPrefsKey = 'free_site_publish_used';
  static const _extraPublishCreditsPrefsKey = 'extra_publish_credits';
  bool freeSitePublishUsed = false;
  int extraPublishCredits = 0;

  /// [project] şu an satın alma gerektirmeden yayınlanabilir mi?
  /// true dönerse showPublishSheet doğrudan açılabilir; false dönerse önce
  /// publish_paywall_sheet.dart ile bir "yayın hakkı" satın alınmalı.
  bool canPublishProject(SiteProject project) {
    if (project.publishRightGranted) return true;
    if (!freeSitePublishUsed) return true;
    return extraPublishCredits > 0;
  }

  /// [project] YENİ yayınlanmadan hemen ÖNCE (ilk kez `isPublished` true
  /// olacaksa) çağrılmalı — bkz. preview_screen.dart > _publishSite. Bu
  /// proje zaten hakkını kullanmışsa (publishRightGranted true) HİÇBİR ŞEY
  /// yapmadan çıkar (idempotent), yani markProjectPublished içinden her
  /// yayınlamada güvenle çağrılabilir.
  Future<void> grantPublishRight(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1 || projects[idx].publishRightGranted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!freeSitePublishUsed) {
      freeSitePublishUsed = true;
      await prefs.setBool(_freeSitePublishUsedPrefsKey, true);
    } else {
      extraPublishCredits = (extraPublishCredits - 1).clamp(0, 1 << 30);
      await prefs.setInt(_extraPublishCreditsPrefsKey, extraPublishCredits);
    }
    projects[idx] = projects[idx].copyWith(publishRightGranted: true);
    notifyListeners();
    await _persistProjects();
  }

  /// Bir "yayın hakkı" (kProductPublishSlot) satın alma tamamlandığında
  /// çağrılır — canPublishProject bir sonraki kontrolde true dönsün diye
  /// bakiyeyi bir artırır. Asıl "harcama" (azaltma) grantPublishRight'ta,
  /// kullanıcı gerçekten o siteyi yayınladığında olur — satın alma ile
  /// kullanım arasında kredi bekleme halinde durur.
  Future<void> addPurchasedPublishCredit() async {
    extraPublishCredits += 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_extraPublishCreditsPrefsKey, extraPublishCredits);
  }

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
  /// Aylık ücretsiz kota yetmiyorsa satın alınmış puan bakiyesi de
  /// (bkz. purchasedPoints) hesaba katılır.
  Future<bool> ensureFormQuotaFor(int cost) async {
    await _ensureMonthlyPointsReset(true);
    return (formCredits + purchasedPoints) >= cost;
  }

  /// FORM üretimi BAŞARIYLA tamamlandıktan SONRA çağrılmalı. Önce aylık
  /// ücretsiz FORM havuzundan düşer, yetmezse kalanı satın alınmış puan
  /// bakiyesinden (bkz. purchasedPoints) düşer.
  Future<void> consumeFormQuota(int cost) async {
    await _ensureMonthlyPointsReset(true, notify: false);
    formCredits = await _spendFromPool(pool: formCredits, cost: cost, isForm: true);
    notifyListeners();
    unawaited(_syncCreditsToCloudIfSignedIn());
  }

  /// AI havuzundan bir işlem (üretim/düzenleme) öncesi çağrılır
  /// (puanı HENÜZ DÜŞMEZ). Aylık ücretsiz kota yetmiyorsa satın alınmış
  /// puan bakiyesi de hesaba katılır.
  Future<bool> ensureAiQuotaFor(int cost) async {
    await _ensureMonthlyPointsReset(false);
    return (aiCredits + purchasedPoints) >= cost;
  }

  /// AI işlemi BAŞARIYLA tamamlandıktan SONRA çağrılmalı. Önce aylık
  /// ücretsiz AI havuzundan düşer, yetmezse kalanı satın alınmış puan
  /// bakiyesinden düşer.
  Future<void> consumeAiQuota(int cost) async {
    await _ensureMonthlyPointsReset(false, notify: false);
    aiCredits = await _spendFromPool(pool: aiCredits, cost: cost, isForm: false);
    notifyListeners();
    unawaited(_syncCreditsToCloudIfSignedIn());
  }

  /// Ortak harcama mantığı: önce ilgili aylık havuzdan (FORM ya da AI, hangisi
  /// olduğu [isForm] ile belirlenir — sadece hangi SharedPreferences
  /// anahtarına yazılacağını seçmek için kullanılır), o yetmezse kalanı
  /// paylaşılan purchasedPoints bakiyesinden düşer. Güncellenmiş aylık havuz
  /// değerini döner (çağıran taraf formCredits/aiCredits'e atar).
  Future<int> _spendFromPool({
    required int pool,
    required int cost,
    required bool isForm,
  }) async {
    final fromPool = cost.clamp(0, pool);
    final remaining = cost - fromPool;
    final newPool = (pool - fromPool).clamp(0, isForm ? maxFormPoints : maxAiPoints);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(isForm ? _formPointsPrefsKey : _aiPointsPrefsKey, newPool);

    if (remaining > 0) {
      purchasedPoints = (purchasedPoints - remaining).clamp(0, 1 << 30);
      await prefs.setInt(_purchasedPointsPrefsKey, purchasedPoints);
    }
    return newPool;
  }

  // ------------------------------------------------------------------
  // BULUT SENKRONİZASYONU (Google ile Giriş) — bkz. user_data_service.dart
  // ------------------------------------------------------------------
  // AuthService.instance.authStateChanges dinlenir: kullanıcı giriş
  // yaptığında (ilk kez veya farklı bir cihazda tekrar), cihazdaki puan
  // (FORM/AI kredisi) bulutla senkronize edilir. FIREBASE_SETUP.md'de
  // planlanan "güvenli kota taşıma" mantığı UserDataService tarafında
  // zaten yazılıydı, burada sadece bağlanıyor.
  //
  // Giriş yoksa (misafir) hiçbir şey değişmez, uygulama SharedPreferences
  // ile eskisi gibi çalışmaya devam eder — bu akış tamamen ek/opsiyonel.
  StreamSubscription<User?>? _authSub;

  AppState() {
    _loadFromPrefs();
    // AuthService.isAvailable false ise (Firebase henüz initialize
    // olmadıysa) authStateChanges zaten boş bir stream döner, güvenli.
    _authSub = AuthService.instance.authStateChanges.listen(_onAuthChanged);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Giriş durumu değiştiğinde tetiklenir. Sadece kullanıcı GİRİŞ
  /// yaptığında bir şey yapar (çıkışta cihazdaki puanlar olduğu gibi
  /// kalır, misafir moduna güvenle döner).
  Future<void> _onAuthChanged(User? user) async {
    if (user == null) return;
    try {
      final cloudData = await UserDataService.instance.fetchOrCreateUserDoc(
        uid: user.uid,
        email: user.email,
        deviceAiCredits: aiCredits,
        deviceFormCredits: formCredits,
        deviceResetMonth: _thisMonthUtcKey(),
        maxAiPoints: maxAiPoints,
        maxFormPoints: maxFormPoints,
      );
      // Bulut esas alınır (doküman ilk kez oluşturulduysa zaten cihaz
      // değerleriyle aynıdır, tekrar giriş yapıldıysa buluttaki güncel
      // değer geçerli olur).
      final cloudResetMonth = cloudData['pointsResetMonth'] as String?;
      final thisMonth = _thisMonthUtcKey();
      if (cloudResetMonth == thisMonth) {
        aiCredits = (cloudData['aiCredits'] as num?)?.toInt() ?? aiCredits;
        formCredits = (cloudData['formCredits'] as num?)?.toInt() ?? formCredits;
      }
      // Cihazdaki kayıtla da eşitle ki uygulama yeniden açıldığında
      // (henüz auth state gelmeden) doğru değer görünsün.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_aiPointsPrefsKey, aiCredits);
      await prefs.setInt(_formPointsPrefsKey, formCredits);
      await prefs.setString(_aiPointsResetMonthPrefsKey, thisMonth);
      await prefs.setString(_formPointsResetMonthPrefsKey, thisMonth);
      notifyListeners();
    } catch (_) {
      // Bulut senkronizasyonu başarısız olsa da uygulama cihazdaki
      // (misafir) değerlerle çalışmaya devam eder — kullanıcı akışı
      // kesilmez.
    }
  }

  /// Giriş yapılmışsa bulut kaydını da günceller; misafirse hiçbir şey
  /// yapmaz (sessizce). consumeFormQuota/consumeAiQuota içinden çağrılır.
  Future<void> _syncCreditsToCloudIfSignedIn() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await UserDataService.instance.updateCredits(
        uid: user.uid,
        aiCredits: aiCredits,
        formCredits: formCredits,
        pointsResetMonth: _thisMonthUtcKey(),
      );
    } catch (_) {
      // Bulut güncellemesi başarısız olsa da cihazdaki puan zaten
      // düşürüldü/kaydedildi — kullanıcı akışını bloklamaya değmez.
    }
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

    // Satın alınan puan bakiyesi ve site yayın hakkı durumu — ikisi de
    // AYIN 1'İNDE sıfırlanmaz, kullanıcı harcayana/hakkı kullanana kadar
    // olduğu gibi kalır (bkz. yukarıdaki alan tanımları).
    purchasedPoints = prefs.getInt(_purchasedPointsPrefsKey) ?? 0;
    freeSitePublishUsed = prefs.getBool(_freeSitePublishUsedPrefsKey) ?? false;
    extraPublishCredits = prefs.getInt(_extraPublishCreditsPrefsKey) ?? 0;

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
  ///
  /// NOT: Bu SADECE AI Chat slotunu (generatedCode/generatedFiles/
  /// currentProjectId) doldurur — kind == ProjectKind.site olan (AI Chat
  /// kökenli) projeler için kullanılır. Form kökenli projeler için
  /// [openQtProject] kullanılmalı (bkz. ProjectsScreen._openProject).
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

  /// [openProject] ile birebir aynı iş, ama Hızlı Araçlar (form) slotu
  /// (qtGeneratedCode/qtGeneratedFiles/qtCurrentProjectId) için. Projelerim
  /// listesinde kind != ProjectKind.site olan (yani formdan üretilmiş)
  /// bir projeye dokunulduğunda bu kullanılır, çünkü QuickToolsPreviewScreen
  /// içeriği AI Chat slotundan değil bu slottan okur (bkz.
  /// preview_screen.dart _slotCode/_slotFiles).
  Future<void> openQtProject(String id) async {
    if (id == qtCurrentProjectId) return;
    await _touchQtProjectFromCurrent();
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final p = projects[idx];
    qtCurrentProjectId = p.id;
    qtSiteMode = p.mode;
    qtGeneratedCode = p.code;
    qtGeneratedFiles = Map<String, String>.from(p.files);
    qtActiveFileName = p.activeFileName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qtSiteModePrefsKey, p.mode.name);
    await prefs.setString(_qtGeneratedCodePrefsKey, p.code);
    await prefs.setString(_qtGeneratedFilesPrefsKey, jsonEncode(p.files));
    if (p.activeFileName != null) {
      await prefs.setString(_qtActiveFilePrefsKey, p.activeFileName!);
    } else {
      await prefs.remove(_qtActiveFilePrefsKey);
    }
    await prefs.setString(_qtCurrentProjectIdPrefsKey, p.id);
  }

  /// Projelerim listesinden bir projeyi kalıcı olarak siler. Silinen proje
  /// o an ekranda açık olan proje ise (AI Chat ya da Hızlı Araçlar slotu
  /// fark etmeksizin) ilgili slot da temizlenir.
  Future<void> deleteProject(String id) async {
    projects.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    if (currentProjectId == id) {
      generatedCode = '';
      generatedFiles = {};
      activeFileName = null;
      currentProjectId = null;
      await prefs.remove(_generatedCodePrefsKey);
      await prefs.remove(_generatedFilesPrefsKey);
      await prefs.remove(_activeFilePrefsKey);
      await prefs.remove(_currentProjectIdPrefsKey);
    }
    if (qtCurrentProjectId == id) {
      qtGeneratedCode = '';
      qtGeneratedFiles = {};
      qtActiveFileName = null;
      qtCurrentProjectId = null;
      await prefs.remove(_qtGeneratedCodePrefsKey);
      await prefs.remove(_qtGeneratedFilesPrefsKey);
      await prefs.remove(_qtActiveFilePrefsKey);
      await prefs.remove(_qtCurrentProjectIdPrefsKey);
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

  // ------------------------------------------------------------------
  // ROZET KALDIRMA — SATIN ALMA SONRASI ÇAĞRILACAK TEK NOKTA
  // ------------------------------------------------------------------
  // Gerçek ödeme (Apple/Google IAP) katmanı henüz bağlı değil — bkz.
  // widgets/remove_watermark_sheet.dart üzerindeki TODO. Bir mağaza
  // sağlayıcısı eklendiğinde, YALNIZCA satın alma/makbuz doğrulaması
  // BAŞARILI olduktan SONRA bu metod çağrılmalı; metodun kendisi ödeme
  // yapmaz, sadece "ödeme onaylandı" sonucunu projeye işler.
  //
  // Tek seferlik ve SİTE BAZLI: sadece [id] ile eşleşen SiteProject
  // etkilenir, kullanıcının diğer projeleri rozetli kalmaya devam eder.
  // Geri alma (iade dışında) yoktur — watermarkRemoved bir kez true
  // olduktan sonra AppState içinde tekrar false yapan bir yol sunulmaz.
  Future<void> removeWatermarkForProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final project = projects[idx];
    if (project.watermarkRemoved) return; // zaten satın alınmış, tekrar işlem yapma

    // 1) Projenin KENDİ kaydında zaten üretilmiş/kaydedilmiş içerikten
    // rozeti geriye dönük temizle (üretim anında gömüldüğü için).
    projects[idx] = project.copyWith(
      watermarkRemoved: true,
      code: WatermarkService.strip(project.code),
      files: WatermarkService.stripFromFiles(project.files),
      updatedAt: DateTime.now(),
    );

    // 2) Bu proje o an ekrandaki iki slottan (AI Chat / Hızlı Araçlar)
    // birinde açıksa, kullanıcı bir şey yapmadan rozetin ANINDA
    // kaybolduğunu görsün diye ekrandaki kopyayı da temizle.
    if (currentProjectId == id) {
      generatedCode = WatermarkService.strip(generatedCode);
      generatedFiles = WatermarkService.stripFromFiles(generatedFiles);
      await _savePrefString(_generatedCodePrefsKey, generatedCode);
      await _savePrefString(_generatedFilesPrefsKey, jsonEncode(generatedFiles));
    }
    if (qtCurrentProjectId == id) {
      qtGeneratedCode = WatermarkService.strip(qtGeneratedCode);
      qtGeneratedFiles = WatermarkService.stripFromFiles(qtGeneratedFiles);
      await _savePrefString(_qtGeneratedCodePrefsKey, qtGeneratedCode);
      await _savePrefString(_qtGeneratedFilesPrefsKey, jsonEncode(qtGeneratedFiles));
    }

    notifyListeners();
    await _persistProjects();
  }

  // ------------------------------------------------------------------
  // YAYIN DURUMU (hosting) — ALT YAPI
  // ------------------------------------------------------------------
  // "Yayınla" butonu/ekranı henüz yok (bkz. HostingService — worker
  // deploy edilene kadar dormant). Bu iki metod, o buton eklendiğinde
  // publish/unpublish sonucunu SiteProject'e (ve dolayısıyla Projelerim
  // listesine) yazmak için hazır bekliyor — şu an hiçbir yerden
  // çağrılmıyor, çağrıldığında davranışları:
  //   markProjectPublished  -> HostingService.publish() başarılı dönünce
  //   markProjectUnpublished -> HostingService.unpublish() başarılı dönünce
  // İkisi de projects listesini SharedPreferences'a persist eder, tıpkı
  // renameProject/deleteProject gibi.

  /// [subdomain]/[url] HostingService.publish()'in döndürdüğü
  /// [PublishResult.subdomain]/[PublishResult.url] olmalı.
  Future<void> markProjectPublished({
    required String id,
    required String subdomain,
    required String url,
  }) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(
      publishedSubdomain: subdomain,
      publishedUrl: url,
      publishedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    // Ücretsiz hakkı/satın alınan krediyi burada "harcarız" — bu proje
    // daha önce hiç yayınlanmadıysa (publishRightGranted false) ücretsiz
    // hakkı ya da bir satın alınmış krediyi tüketir; daha önce zaten
    // yayınlanmışsa (republish/güncelleme) grantPublishRight no-op'tur
    // (bkz. metodun kendi dokümantasyonu). ÖNEMLİ: bu noktaya gelinmeden
    // ÖNCE preview_screen.dart > _publishSite zaten canPublishProject ile
    // kontrol etmiş ve gerekirse satın alma akışını tamamlatmış olmalı —
    // burası sadece o kararın SONUCUNU kalıcı hale getirir.
    await grantPublishRight(id);
  }

  /// HostingService.unpublish() başarılı olduktan sonra çağrılır —
  /// sadece yerel kaydı temizler, worker/R2 tarafındaki silme işini
  /// HostingService.unpublish() zaten yapmış olur.
  Future<void> markProjectUnpublished(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(unpublish: true, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
  }

  // ------------------------------------------------------------------
  // "KENDİ DOMAİNİMİ BAĞLA" DURUMU — ALT YAPI
  // ------------------------------------------------------------------
  // markProjectPublished/markProjectUnpublished ile aynı desende: bu iki
  // metod DomainConnectScreen tarafından çağrılıyor (bkz.
  // lib/screens/domain_connect_screen.dart), sonucu SiteProject'e yazıp
  // SharedPreferences'a persist ediyor — böylece uygulama kapatılıp
  // açılsa bile "bu projeye bağlı bir domain var" bilgisi kaybolmuyor.

  /// [domain]/[status] DomainService.connect() veya DomainService.status()
  /// çağrılarının döndürdüğü değerler olmalı ('pending' | 'active' | 'error').
  Future<void> markProjectDomainStatus({
    required String id,
    required String domain,
    required String status,
  }) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final existing = projects[idx];
    // Domain bağlama 1 YIL SÜRELİDİR (ürün kararı). "active" durumuna YENİ
    // geçiliyorsa (daha önce bağlı değildi, ya da domain adı değiştiyse)
    // 1 yıllık süreç sıfırdan başlar. Aynı domain zaten 'active' iken
    // status tekrar 'active' gelirse (ör. polling) — süreyi SIFIRLAMIYORUZ,
    // yoksa kullanıcı her açılışta süresi uzuyormuş gibi görünür.
    final isNewActivation = status == 'active' &&
        (existing.domainConnectedAt == null ||
            existing.customDomain != domain ||
            existing.domainStatus != 'active');
    projects[idx] = existing.copyWith(
      customDomain: domain,
      domainStatus: status,
      domainConnectedAt: isNewActivation ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
  }

  /// Kullanıcı süresi dolmuş/dolmak üzere olan bir domain'i "yenile"diğinde
  /// çağrılır (bkz. DomainConnectScreen "Yenile" butonu). ÖNCE worker'a
  /// POST /api/domains/:siteId/renew çağrısı atılır (bkz. DomainService.renew)
  /// — süre worker tarafında GERÇEKTEN uygulandığı için (serveCustomDomainSite
  /// süresi dolmuş domain'leri artık servis etmiyor), istemci tarafındaki
  /// sayacı worker'a hiç sormadan sıfırlamak, kullanıcıya "uzatıldı" gösterip
  /// aslında sitesinin hâlâ kapalı kalmasına yol açardı. İstek başarısız
  /// olursa (örn. internet yok) exception yukarı fırlatılır, çağıran taraf
  /// (DomainConnectScreen._renew) bunu yakalayıp kullanıcıya hata gösterir —
  /// bu durumda yerel tarih DEĞİŞTİRİLMEZ.
  Future<void> renewProjectDomain(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final result = await DomainService.renew(siteId: id);
    final refreshedIdx = projects.indexWhere((p) => p.id == id);
    if (refreshedIdx == -1) return;
    projects[refreshedIdx] = projects[refreshedIdx].copyWith(
      domainConnectedAt: result.domainConnectedAt,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
  }

  /// DomainService.disconnect() başarılı olduktan sonra çağrılır — sadece
  /// yerel kaydı temizler, worker/Cloudflare tarafındaki silme işini
  /// DomainService.disconnect() zaten yapmış olur.
  Future<void> clearProjectDomain(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(clearDomain: true, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
  }

  /// Yayınlanmış bir projenin ziyaretçi sayısını worker'dan okur (bkz.
  /// HostingService.fetchStats). Proje yayınlanmamışsa (isPublished false)
  /// worker'a hiç istek atmadan null döner — gereksiz ağ isteği/hata
  /// önlenmiş olur. Worker henüz deploy edilmediyse veya istek başarısız
  /// olursa da null döner; UI bu durumda sayaç yerine "bilinmiyor" gibi
  /// bir şey gösterebilir, exception fırlatılmaz.
  Future<SiteStats?> fetchVisitorStats(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1 || !projects[idx].isPublished) return null;
    try {
      return await HostingService.fetchStats(siteId: projectId);
    } catch (_) {
      return null;
    }
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
    generatedCode = currentHasBranding ? WatermarkService.apply(code, isEnglish: isEnglish) : code;
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
    // NOT: Bildirim kurulumu burada BİLEREK try/catch içinde. Bu metod
    // indirme/dışa aktarma BAŞARILI OLDUKTAN SONRA çağrılıyor; bir
    // hatırlatma bildirimi kurulamaması indirmenin kendisini
    // "başarısız" göstermemeli (bkz. home/preview/edit screen'lerdeki
    // İndirme başarısız try/catch blokları).
    try {
      await NotificationService.instance.scheduleProjectUpdateReminder(
        projectId: project.id,
        projectName: projectNameOverride ?? project.name,
      );
    } catch (_) {
      // NotificationService kendi içinde zaten hataları yutuyor; bu sadece
      // ekstra güvenlik katmanı.
    }
  }
}
