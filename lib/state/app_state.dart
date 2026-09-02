import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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

/// Sitora uygulamasının merkezi durumu.
/// Üretilen site kodu, aylık FORM puan kotasını ve seçilen görselleri tutar.
class AppState extends ChangeNotifier {
  // ------------------------------------------------------------------
  // MARKA ROZETİ (WatermarkService) — SİTE BAZLI, TEK SEFERLİK MODEL
  // ------------------------------------------------------------------
  // Rozet durumu HESAP GENELİNDE tek bir global bayrak değil, HER
  // SiteProject'in kendi `watermarkRemoved` alanında tutulur (bkz.
  // models/site_project.dart). Ekrandaki Hızlı Araçlar slotu o an hangi
  // projeye bağlıysa (qtCurrentProjectId) rozet kararı O projenin
  // bayrağından okunur — aşağıdaki getter bunu sağlar. Henüz hiçbir
  // projeye kaydedilmemiş (yepyeni, projects listesinde karşılığı olmayan)
  // bir slot için varsayılan olarak rozetli (true) kabul edilir; proje ilk
  // kez kaydedildiğinde (bkz. _touchQtProjectFromCurrent) watermarkRemoved=
  // false ile oluşur, yani davranış aynı kalır.
  //
  // SATIN ALMA TAMAMLANDIĞINDA: removeWatermarkForProject(id) çağrılır —
  // bkz. o metodun dokümantasyonu.
  bool get qtCurrentHasBranding => !_isWatermarkRemoved(qtCurrentProjectId);

  bool _isWatermarkRemoved(String? projectId) {
    if (projectId == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].watermarkRemoved;
  }

  // ------------------------------------------------------------------
  // UYGULAMA İÇİNDE DÜZENLENEBİLİRLİK (SiteProject.editableInApp)
  // ------------------------------------------------------------------
  // Ekrandaki Hızlı Araçlar slotu hangi projeye bağlıysa (qtCurrentProjectId)
  // "Düzenle" butonunun gösterilip gösterilmeyeceği O projenin kendi
  // editableInApp bayrağından okunur (bkz. models/site_project.dart).
  // Henüz hiçbir projeye kaydedilmemiş (yepyeni) bir slot için varsayılan
  // olarak düzenlenebilir (true) kabul edilir — admin panelinden enjekte
  // edilen projeler zaten AppState.projects listesinde false olarak gelir.
  bool get qtCurrentEditableInApp {
    final projectId = qtCurrentProjectId;
    if (projectId == null) return true;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return true;
    return projects[idx].editableInApp;
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

  // --- HIZLI ARAÇLAR (Quick Tools / form ile site oluşturma) SLOTU ---
  // Ana sayfadaki Hızlı Araçlar formlarından (Kafe, Kuaför, Emlak vb.)
  // üretilen site, uygulama kapatılıp açıldığında kaybolmasın diye bu
  // alanlar SharedPreferences'ta saklanır.
  static const _qtGeneratedCodePrefsKey = 'qt_generated_code';
  static const _qtGeneratedFilesPrefsKey = 'qt_generated_files';
  static const _qtActiveFilePrefsKey = 'qt_active_file_name';
  static const _qtSiteModePrefsKey = 'qt_site_mode';
  static const _qtCurrentProjectIdPrefsKey = 'qt_current_project_id';
  // 25.08.2026 eklendi: Önizleme ekranındaki "Düzenle" akışı — o an
  // ekrandaki slotun HANGİ form türünden (ProjectKind) üretildiğini ve o
  // formun ham alan değerlerini (metin kutuları, galeri, tema, konum vb.)
  // saklar ki kullanıcı Düzenle'ye bastığında doğru form BOŞ değil, DOLU
  // açılsın (bkz. screens/preview_screen.dart > _openEditForm,
  // screens/form_screen_router.dart).
  static const _qtFormDataPrefsKey = 'qt_form_data';
  static const _qtCurrentKindPrefsKey = 'qt_current_kind';

  // --- PROJELERİM (çoklu proje) ---
  static const _projectsPrefsKey = 'saved_projects_v1';

  // ------------------------------------------------------------------
  // 02.09.2026 eklendi — KESİN ÇÖKME DÜZELTMESİ (OutOfMemoryError):
  // ------------------------------------------------------------------
  // Yukarıdaki dört alan (qt_generated_code, qt_generated_files,
  // qt_form_data, saved_projects_v1) galeri fotoğrafları base64 DATA URI
  // olarak HTML/JSON içine gömülü şekilde onlarca MB'a ulaşabiliyordu.
  // SharedPreferences Android'de TEK bir XML dosyasıdır ve bu dosyaya
  // HERHANGİ bir okuma/yazma isteğinde (SharedPreferences.getInstance() ilk
  // çağrısı → SharedPreferencesImpl.awaitLoadedLocked → getAll()) TÜM
  // içerik parse edilip belleğe TEK SEFERDE yükleniyordu. Birden fazla
  // galeri fotoğrafı toplayan formlarda (kafe, otel, restoran, emlak,
  // kuaför vb.) bu toplam boyut cihazın ayırdığı heap sınırını (log'da
  // görüldüğü gibi ~140-200MB) kolayca aşıyor ve "Site Oluştur"a basılır
  // basılmaz java.lang.OutOfMemoryError fırlatıyordu — WebView'daki
  // loadHtmlString çökmesi (bkz. preview_screen.dart) düzeltildikten SONRA
  // ortaya çıkan asıl kök neden buydu.
  //
  // ÇÖZÜM: bu dört büyük alan artık SharedPreferences'a DEĞİL, uygulamanın
  // kendi Documents dizinine düz dosya olarak yazılıyor (aşağıdaki
  // _writeLargeData/_readLargeData/_deleteLargeData). Dosya sistemi büyük
  // içerikleri sorunsuz, TEK SEFERDE tüm veriyi belleğe kopyalamadan
  // okuyup yazabiliyor. SharedPreferences'ta artık sadece küçük skaler
  // ayarlar (puan, bayrak, aktif dosya adı, proje id'si vb.) kalıyor.
  //
  // GERİYE DÖNÜK UYUMLULUK: uygulama bu sürüme güncellenen bir cihazda
  // açıldığında, eski verinin hâlâ SharedPreferences'ta durduğu ilk açılışta
  // otomatik olarak yeni dosya konumuna TAŞINIR (bkz. _loadFromPrefs
  // içindeki _migrateLegacyPrefValue çağrıları) — kullanıcı hiçbir veri
  // kaybetmez.
  static const _qtGeneratedCodeFile = 'qt_generated_code.html';
  static const _qtGeneratedFilesFile = 'qt_generated_files.json';
  static const _qtFormDataFile = 'qt_form_data.json';
  static const _projectsFile = 'saved_projects.json';

  Future<Directory> _largeDataDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/sitora_data');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// [name] dosyasına [content]'i yazar. Yarım/bozuk dosya oluşmasın diye
  /// önce geçici bir dosyaya yazılıp ardından hedef dosyanın üzerine
  /// ATOMİK olarak taşınır (rename) — yazma sırasında uygulama
  /// kapanırsa/çökerse eski dosya bozulmadan kalır.
  Future<void> _writeLargeData(String name, String content) async {
    try {
      final dir = await _largeDataDir();
      final tmp = File('${dir.path}/$name.tmp');
      await tmp.writeAsString(content, flush: true);
      await tmp.rename('${dir.path}/$name');
    } catch (_) {
      // Diske yazma başarısız olsa bile (ör. disk dolu) uygulama akışını
      // bloklamaya değmez — ekrandaki içerik bir sonraki değişiklikte
      // tekrar yazılmaya çalışılır.
    }
  }

  Future<String?> _readLargeData(String name) async {
    try {
      final dir = await _largeDataDir();
      final file = File('${dir.path}/$name');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteLargeData(String name) async {
    try {
      final dir = await _largeDataDir();
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Silinemezse önemli değil — bir sonraki yazma zaten üzerine yazar.
    }
  }

  /// Eski sürümlerde [prefsKey] altında SharedPreferences'a yazılmış olan
  /// büyük veriyi (varsa) [fileName]'e taşır ve prefs'ten siler. Sadece
  /// dosya HENÜZ yoksa (yani bu cihazda migrasyon daha önce yapılmadıysa)
  /// çalışır — idempotent, her açılışta güvenle çağrılabilir.
  Future<void> _migrateLegacyPrefValue(
    SharedPreferences prefs,
    String prefsKey,
    String fileName,
  ) async {
    final dir = await _largeDataDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return; // zaten taşınmış
    final legacy = prefs.getString(prefsKey);
    if (legacy == null) return; // eski veri yok (yeni kurulum)
    await _writeLargeData(fileName, legacy);
    await prefs.remove(prefsKey);
  }

  List<SiteProject> projects = [];

  /// Projelerim ekranında gösterilecek liste: en son güncellenen en üstte.
  List<SiteProject> get projectsByRecency {
    final list = List<SiteProject>.from(projects);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  final List<File> pickedImages = [];

  // --- Hızlı Araçlar (Quick Tools) ekranındaki slot ---
  String qtGeneratedCode = '';
  Map<String, String> qtGeneratedFiles = {};
  String? qtActiveFileName;
  SiteMode qtSiteMode = SiteMode.single;
  String? qtCurrentProjectId;

  /// Ekrandaki slotu üreten form türü — Düzenle akışı hangi form ekranına
  /// dönüleceğini bundan bulur. Eski kayıtlarda null olabilir.
  ProjectKind? qtCurrentKind;

  /// O an ekranda açık sitenin, kendisini üreten formun alanlarına ait ham
  /// (JSON-uyumlu) anlık görüntüsü — bkz. services/qt_form_data_codec.dart.
  Map<String, dynamic> qtFormData = {};

  /// Bir form ekranı üretim/düzenleme BAŞARIYLA tamamlandıktan sonra çağrılır.
  /// [data] o formun _captureFormData() çıktısıdır.
  ///
  /// 26.08.2026 eklendi: [data], sadece geçici qtFormData slotuna değil,
  /// o an ekrandaki projenin (qtCurrentProjectId) KENDİ SiteProject
  /// kaydındaki formData alanına da YAZILIR. Bu metod her zaman
  /// updateQtGeneratedCode/Files'tan SONRA çağrıldığı için (bkz.
  /// LocalGenerationHelper), qtCurrentProjectId bu noktada zaten set
  /// edilmiş olur — proje Projelerim'den (farklı bir oturumda) tekrar
  /// açıldığında "Düzenle" formu bu sayede DOLU açılabilir (bkz.
  /// openQtProject).
  void setQtFormData(Map<String, dynamic> data, {ProjectKind? kind}) {
    qtFormData = data;
    if (kind != null) qtCurrentKind = kind;
    notifyListeners();
    _writeLargeData(_qtFormDataFile, jsonEncode(data));
    if (kind != null) _savePrefString(_qtCurrentKindPrefsKey, kind.name);

    final pid = qtCurrentProjectId;
    if (pid != null) {
      final idx = projects.indexWhere((p) => p.id == pid);
      if (idx != -1) {
        projects[idx] = projects[idx].copyWith(formData: data);
        unawaited(_persistProjects());
        unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
      }
    }
  }

  // ---------------------------------------------------------------------
  // Hızlı Araçlar (Quick Tools)
  // ---------------------------------------------------------------------
  void setQtSiteMode(SiteMode mode) {
    qtSiteMode = mode;
    notifyListeners();
    _savePrefString(_qtSiteModePrefsKey, mode.name);
  }

  void updateQtGeneratedCode(String code, {String? projectName, ProjectKind? kind}) {
    qtGeneratedCode = qtCurrentHasBranding ? WatermarkService.apply(code, isEnglish: isEnglish) : code;
    notifyListeners();
    // NOT: davranış aynı kalsın diye önceki sürümdeki gibi ORİJİNAL (rozet
    // uygulanmamış) [code] kaydediliyor, bellekteki qtGeneratedCode değil.
    _writeLargeData(_qtGeneratedCodeFile, code);
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
    await _writeLargeData(_qtGeneratedFilesFile, jsonEncode(qtGeneratedFiles));
    final prefs = await SharedPreferences.getInstance();
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
    qtFormData = {};
    qtCurrentKind = null;
    notifyListeners();
    await _deleteLargeData(_qtGeneratedCodeFile);
    await _deleteLargeData(_qtGeneratedFilesFile);
    await _deleteLargeData(_qtFormDataFile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qtActiveFilePrefsKey);
    await prefs.remove(_qtCurrentProjectIdPrefsKey);
    await prefs.remove(_qtCurrentKindPrefsKey);
  }

  bool isGenerating = false;

  // ------------------------------------------------------------------
  // AYLIK ÜCRETSİZ PUAN SİSTEMİ — FORM HAVUZU
  // ------------------------------------------------------------------
  // NOT: Şimdilik tamamen CİHAZDA (shared_preferences) tutuluyor. Bu,
  // uygulama verisi silinip yeniden yüklenirse kotanın da sıfırlanacağı
  // anlamına gelir — ileride Google girişi + sunucu tarafı (D1) takibe
  // geçilene kadar bilinçli bir MVP kısıtı.
  //
  // FORM havuzu (form doldur → yerel HTML üretimi):
  //    - Tek sayfa üretim = 5 puan, çok sayfa üretim = 10 puan.
  //    - Düzenleme YOK (form akışında düzenleme ekranı bulunmuyor).
  //    - Aylık kota: 15 puan. 15 puanla en az 3 tek-sayfa deneme hakkı
  //      kalıyor (5+5+5), bu kasıtlı: kullanıcı 1-2 denemede "olmadı"
  //      dese bile hâlâ payı olsun diye 10 DEĞİL 15 seçildi.
  //
  // Havuz her ayın 1'inde (UTC ay sınırında) YENİDEN dolar; harcanmayan
  // puan bir sonraki aya TAŞINMAZ.
  static const _formPointsPrefsKey = 'form_points_remaining';
  static const _formPointsResetMonthPrefsKey = 'form_points_reset_month_utc';

  static const int maxFormPoints = 15;

  static const int costSinglePage = 5;
  static const int costMultiPage = 10;
  // 25.08.2026 eklendi: Önizleme > Düzenle > Düzenlemeyi Bitir akışında,
  // sayfa tek/çok olmasına bakılmaksızın HER "Düzenlemeyi Bitir" başına
  // sabit 2 puan düşülür (bkz. LocalGenerationHelper.generateSinglePage/
  // generateMultiPage'in isEditing parametresi).
  static const int costEdit = 2;

  int formCredits = maxFormPoints;

  // ------------------------------------------------------------------
  // SATIN ALINAN PUAN BAKİYESİ (İSKELET) — bkz. billing_constants.dart
  // (kProductPoints15/30/50/100), billing_service.dart, buy_points_sheet.dart
  // ------------------------------------------------------------------
  // Aylık ücretsiz FORM havuzunun AKSİNE bu bakiye AYIN 1'İNDE
  // SIFIRLANMAZ — kullanıcı harcayana kadar kalır. Aylık ücretsiz kota
  // bittiğinde ensureFormQuotaFor otomatik olarak bu bakiyeye de bakar,
  // consumeFormQuota önce aylık havuzdan, o yetmezse buradan düşer
  // (bkz. _spendFromPool).
  static const _purchasedPointsPrefsKey = 'purchased_points_balance';
  int purchasedPoints = 0;

  /// Bir puan paketi satın alma tamamlandığında (bkz. BillingService
  /// .buyConsumable başarılı döndükten SONRA) çağrılır.
  Future<void> addPurchasedPoints(int amount) async {
    purchasedPoints += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_purchasedPointsPrefsKey, purchasedPoints);
    unawaited(_syncAccountStateToCloudIfSignedIn());
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
    unawaited(_syncAccountStateToCloudIfSignedIn());
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
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
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  String _thisMonthUtcKey() {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// UTC ayı değiştiyse FORM havuzunu tavan değerine sıfırlar
  /// (biriktirmeden). Hem uygulama açılışında hem her puan
  /// kontrolünden önce çağrılır.
  Future<void> _ensureMonthlyPointsReset({bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final thisMonth = _thisMonthUtcKey();
    final storedMonth = prefs.getString(_formPointsResetMonthPrefsKey);
    if (storedMonth != thisMonth) {
      formCredits = maxFormPoints;
      await prefs.setString(_formPointsResetMonthPrefsKey, thisMonth);
      await prefs.setInt(_formPointsPrefsKey, maxFormPoints);
      if (notify) notifyListeners();
    }
  }

  /// FORM havuzundan bir üretim öncesi çağrılır (puanı HENÜZ DÜŞMEZ).
  /// Aylık ücretsiz kota yetmiyorsa satın alınmış puan bakiyesi de
  /// (bkz. purchasedPoints) hesaba katılır.
  Future<bool> ensureFormQuotaFor(int cost) async {
    await _ensureMonthlyPointsReset();
    return (formCredits + purchasedPoints) >= cost;
  }

  /// FORM üretimi BAŞARIYLA tamamlandıktan SONRA çağrılmalı. Önce aylık
  /// ücretsiz FORM havuzundan düşer, yetmezse kalanı satın alınmış puan
  /// bakiyesinden (bkz. purchasedPoints) düşer.
  Future<void> consumeFormQuota(int cost) async {
    await _ensureMonthlyPointsReset(notify: false);
    formCredits = await _spendFromPool(pool: formCredits, cost: cost);
    notifyListeners();
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  /// Ortak harcama mantığı: önce aylık FORM havuzundan düşer, o yetmezse
  /// kalanı paylaşılan purchasedPoints bakiyesinden düşer. Güncellenmiş
  /// aylık havuz değerini döner (çağıran taraf formCredits'e atar).
  Future<int> _spendFromPool({
    required int pool,
    required int cost,
  }) async {
    final fromPool = cost.clamp(0, pool);
    final remaining = cost - fromPool;
    final newPool = (pool - fromPool).clamp(0, maxFormPoints);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_formPointsPrefsKey, newPool);

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
  // yaptığında (ilk kez veya farklı bir cihazda tekrar), cihazdaki FORM
  // kredisi bulutla senkronize edilir. FIREBASE_SETUP.md'de planlanan
  // "güvenli kota taşıma" mantığı UserDataService tarafında zaten
  // yazılıydı, burada sadece bağlanıyor.
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
  /// yaptığında bir şey yapar (çıkışta cihazdaki puanlar/projeler olduğu
  /// gibi kalır, misafir moduna güvenle döner — çıkış hiçbir yerel veriyi
  /// silmez).
  ///
  /// BURASI, kullanıcının telefon değiştirse bile (ya da uygulamayı silip
  /// tekrar kurup AYNI e-posta ile giriş yapsa bile) puanlarına, satın
  /// aldığı haklara VE projelerine (yayındaki siteler dahil) erişebilmesini
  /// sağlayan tek nokta:
  ///   1) fetchOrCreateUserDoc: bu hesapla İLK kez giriş yapılıyorsa
  ///      cihazdaki mevcut durum (kota/puan/hak/projeler) buluta taşınır.
  ///      Hesap zaten buluttaysa (başka bir cihazdan/daha önce açıldıysa)
  ///      cihaz değerleri yok sayılır, bulut esas alınır.
  ///   2) Bulut, hesap genelindeki bakiyeleri (formCredits/purchasedPoints/
  ///      freeSitePublishUsed/extraPublishCredits) bu cihaza yazar.
  ///   3) fetchProjects + _mergeCloudProjects: buluttaki proje listesi
  ///      (users/{uid}/projects) cihazdaki listeyle id bazında birleştirilir
  ///      — her id için hangisinin updatedAt'i daha yeniyse O kazanır (yeni
  ///      telefonda liste genelde boştur, bulut kazanır; aynı hesapla iki
  ///      cihazda art arda düzenleme yapılırsa en son değişiklik kazanır).
  ///      Birleşimden sonra yerelde olup buluta henüz yazılmamış (ya da
  ///      yereldeki daha yeni olduğu için kazanan) projeler geri buluta
  ///      yazılır ki iki cihaz da senkron kalsın.
  Future<void> _onAuthChanged(User? user) async {
    if (user == null) return;
    try {
      final cloudData = await UserDataService.instance.fetchOrCreateUserDoc(
        uid: user.uid,
        email: user.email,
        deviceFormCredits: formCredits,
        deviceResetMonth: _thisMonthUtcKey(),
        maxFormPoints: maxFormPoints,
        deviceExtraPurchasedPoints: purchasedPoints,
        deviceFreeSitePublishUsed: freeSitePublishUsed,
        deviceExtraPublishCredits: extraPublishCredits,
        deviceProjects: projects.map((p) => p.toJson()).toList(),
      );

      // Bulut esas alınır (doküman ilk kez oluşturulduysa zaten cihaz
      // değerleriyle aynıdır, tekrar giriş yapıldıysa buluttaki güncel
      // değer geçerli olur).
      final cloudResetMonth = cloudData['pointsResetMonth'] as String?;
      final thisMonth = _thisMonthUtcKey();
      if (cloudResetMonth == thisMonth) {
        formCredits = (cloudData['formCredits'] as num?)?.toInt() ?? formCredits;
      }
      purchasedPoints = (cloudData['purchasedPoints'] as num?)?.toInt() ?? purchasedPoints;
      freeSitePublishUsed = cloudData['freeSitePublishUsed'] as bool? ?? freeSitePublishUsed;
      extraPublishCredits = (cloudData['extraPublishCredits'] as num?)?.toInt() ?? extraPublishCredits;

      // Projeler: bulut + cihaz listesini id bazında birleştir (bkz. yukarı
      // açıklama). Buluttan hiç çekilemezse (ağ hatası) cihazdaki liste
      // olduğu gibi kalır — kullanıcı akışı kesilmez.
      final cloudProjects = await UserDataService.instance.fetchProjects(user.uid);
      final toReupload = _mergeCloudProjects(cloudProjects);

      // Cihazdaki kayıtla da eşitle ki uygulama yeniden açıldığında
      // (henüz auth state gelmeden) doğru değer görünsün.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_formPointsPrefsKey, formCredits);
      await prefs.setString(_formPointsResetMonthPrefsKey, thisMonth);
      await prefs.setInt(_purchasedPointsPrefsKey, purchasedPoints);
      await prefs.setBool(_freeSitePublishUsedPrefsKey, freeSitePublishUsed);
      await prefs.setInt(_extraPublishCreditsPrefsKey, extraPublishCredits);
      await _persistProjects();
      notifyListeners();

      // Birleşimden "yereldeki kazandı" çıkan projeleri buluta geri yaz —
      // sessizce, akışı bloklamadan (fire-and-forget).
      for (final project in toReupload) {
        unawaited(_syncProjectToCloudIfSignedIn(project));
      }
    } catch (_) {
      // Bulut senkronizasyonu başarısız olsa da uygulama cihazdaki
      // (misafir) değerlerle çalışmaya devam eder — kullanıcı akışı
      // kesilmez.
    }
  }

  /// [cloudProjects] (Firestore'dan gelen ham JSON listesi) ile cihazdaki
  /// `projects` listesini id bazında birleştirir: aynı id hem bulutta hem
  /// cihazda varsa `updatedAt`'i daha yeni olan kazanır; sadece bulutta
  /// varsa (başka bir cihazda oluşturulmuş/yayınlanmış site) cihaza eklenir;
  /// sadece cihazda varsa (henüz hiç senkronlanmamış misafir/yerel proje)
  /// olduğu gibi kalır. Sonucu `projects`'e yazar (en son güncellenen en
  /// üstte olacak şekilde sıralamaya dokunmaz, projectsByRecency zaten
  /// kendi sıralamasını yapıyor) ve buluta GERİ yazılması gereken
  /// projelerin listesini döner (cihazda kazanan ama henüz bulutta o halde
  /// olmayanlar).
  List<SiteProject> _mergeCloudProjects(List<Map<String, dynamic>> cloudProjects) {
    final cloudById = <String, SiteProject>{};
    for (final raw in cloudProjects) {
      try {
        final p = SiteProject.fromJson(raw);
        cloudById[p.id] = p;
      } catch (_) {
        // Bozuk/eksik bir bulut kaydı varsa o kaydı yok say, diğerlerini etkileme.
      }
    }

    final merged = <String, SiteProject>{};
    final reupload = <SiteProject>[];

    for (final local in projects) {
      final cloud = cloudById.remove(local.id);
      if (cloud == null) {
        // Sadece cihazda var — henüz buluta hiç yazılmamış, olduğu gibi
        // kalır ve aşağıda buluta yazılacaklar listesine eklenir.
        merged[local.id] = local;
        reupload.add(local);
      } else if (local.updatedAt.isAfter(cloud.updatedAt)) {
        // Cihazdaki daha yeni — o kazanır, bulut güncellenmeli.
        merged[local.id] = local;
        reupload.add(local);
      } else {
        // Bulut aynı veya daha yeni — o kazanır.
        merged[local.id] = cloud;
      }
    }
    // Sadece bulutta kalanlar (bu cihazda hiç yoktu — başka bir cihazdan
    // eklenmiş/yayınlanmış siteler): doğrudan ekle, tekrar buluta yazmaya
    // gerek yok (zaten oradan geldi).
    for (final cloud in cloudById.values) {
      merged[cloud.id] = cloud;
    }

    projects = merged.values.toList();
    return reupload;
  }

  /// Giriş yapılmışsa hesap genelindeki bakiyeleri (aylık FORM kotası,
  /// satın alınan puan, ücretsiz/satın alınan yayın hakkı) bulutla eşitler;
  /// misafirse hiçbir şey yapmaz (sessizce). consumeFormQuota,
  /// addPurchasedPoints, addPurchasedPublishCredit ve grantPublishRight
  /// içinden çağrılır — bu dört metot hesap bakiyelerinden en az birini
  /// değiştirir.
  Future<void> _syncAccountStateToCloudIfSignedIn() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await UserDataService.instance.updateAccountState(
        uid: user.uid,
        formCredits: formCredits,
        pointsResetMonth: _thisMonthUtcKey(),
        purchasedPoints: purchasedPoints,
        freeSitePublishUsed: freeSitePublishUsed,
        extraPublishCredits: extraPublishCredits,
      );
    } catch (_) {
      // Bulut güncellemesi başarısız olsa da cihazdaki değer zaten
      // düşürüldü/kaydedildi — kullanıcı akışını bloklamaya değmez.
    }
  }

  /// Giriş yapılmışsa [project]'i (SiteProject.toJson() ile) buluta
  /// yazar; misafirse hiçbir şey yapmaz. Projeyi değiştiren HER metot
  /// (yayınlama, rozet kaldırma, yeniden adlandırma, domain bağlama vb.)
  /// kendi yerel kaydını (_persistProjects) yaptıktan SONRA bunu da
  /// çağırır — böylece ikinci bir cihazdan giriş yapıldığında bu değişiklik
  /// oradan da görülebilir.
  Future<void> _syncProjectToCloudIfSignedIn(SiteProject project) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await UserDataService.instance.upsertProject(
        uid: user.uid,
        projectJson: project.toJson(),
      );
    } catch (_) {
      // Bulut güncellemesi başarısız olsa da yerel kayıt zaten yapıldı —
      // kullanıcı akışını bloklamaya değmez; bir sonraki değişiklikte ya
      // da bir sonraki girişte tekrar denenir.
    }
  }

  /// Giriş yapılmışsa buluttaki proje kaydını da siler; misafirse hiçbir
  /// şey yapmaz. deleteProject içinden, yerel silme ile birlikte çağrılır.
  Future<void> _deleteProjectFromCloudIfSignedIn(String projectId) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await UserDataService.instance.deleteProject(
        uid: user.uid,
        projectId: projectId,
      );
    } catch (_) {
      // Aynı gerekçe: yerel silme zaten tamamlandı, bulut hatası kullanıcı
      // akışını bloklamaz.
    }
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // 02.09.2026 eklendi — bu sürümden önce kurulmuş bir uygulamada bu dört
    // büyük alan hâlâ SharedPreferences'ta olabilir; ilk açılışta yeni dosya
    // konumuna TAŞI (bkz. _migrateLegacyPrefValue dokümantasyonu). Dosya
    // zaten varsa (migrasyon daha önce yapıldıysa ya da yeni kurulumsa)
    // no-op'tur.
    await _migrateLegacyPrefValue(prefs, _qtGeneratedCodePrefsKey, _qtGeneratedCodeFile);
    await _migrateLegacyPrefValue(prefs, _qtGeneratedFilesPrefsKey, _qtGeneratedFilesFile);
    await _migrateLegacyPrefValue(prefs, _qtFormDataPrefsKey, _qtFormDataFile);
    await _migrateLegacyPrefValue(prefs, _projectsPrefsKey, _projectsFile);

    // Uygulama kapatılıp yeniden açıldığında ekrandaki üretilmiş site
    // (tek dosya veya çoklu sayfa) kaybolmasın diye Hızlı Araçlar slotu
    // kendi dosyalarından geri yüklenir (artık SharedPreferences'tan DEĞİL
    // — bkz. yukarıdaki 02.09.2026 notu).
    qtGeneratedCode = await _readLargeData(_qtGeneratedCodeFile) ?? '';
    final qtFilesRaw = await _readLargeData(_qtGeneratedFilesFile);
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
    final qtFormDataRaw = await _readLargeData(_qtFormDataFile);
    if (qtFormDataRaw != null && qtFormDataRaw.isNotEmpty) {
      try {
        qtFormData = jsonDecode(qtFormDataRaw) as Map<String, dynamic>;
      } catch (_) {
        qtFormData = {};
      }
    }
    final qtKindRaw = prefs.getString(_qtCurrentKindPrefsKey);
    if (qtKindRaw != null) {
      for (final k in ProjectKind.values) {
        if (k.name == qtKindRaw) {
          qtCurrentKind = k;
          break;
        }
      }
    }

    // Projelerim: kaydedilmiş tüm siteler + ekrandaki slotun hangi projeye
    // karşılık geldiği.
    final projectsRaw = await _readLargeData(_projectsFile);
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
    // Aylık ücretsiz FORM puanı: UTC ayı hâlâ aynıysa kayıtlı kalan puanı
    // yükle, ay değiştiyse tavana sıfırla (biriktirmeden).
    final thisMonth = _thisMonthUtcKey();
    final storedFormMonth = prefs.getString(_formPointsResetMonthPrefsKey);
    if (storedFormMonth == thisMonth) {
      formCredits = prefs.getInt(_formPointsPrefsKey) ?? maxFormPoints;
    } else {
      formCredits = maxFormPoints;
      await prefs.setString(_formPointsResetMonthPrefsKey, thisMonth);
      await prefs.setInt(_formPointsPrefsKey, formCredits);
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

  // ------------------------------------------------------------------
  // PROJELERİM — çoklu proje yönetimi
  // ------------------------------------------------------------------

  /// GÜVENLİK (2026-09-01 eklendi): proje/site ID'si worker'a `siteId`
  /// olarak gönderilir ve yayınlanan sitenin HTML'ine gömülür
  /// (window.__SITORA_LEAD__) — yani bu ID gizli DEĞİL, herkes "sayfa
  /// kaynağını görüntüle" ile okuyabilir. Worker'daki DELETE/report/stats
  /// uçları bu ID'yi bilmekten başka bir yetki kontrolü yapmıyor, bu
  /// yüzden ID'nin TAHMİN EDİLEMEZ olması şart. Eskiden
  /// `DateTime.now().microsecondsSinceEpoch` kullanılıyordu — bu bir zaman
  /// damgasıdır, dar bir aralıkta taranarak tahmin edilebilir (bir
  /// saldırgan başkasının sitesinin ID'sini kaynak koddan okuyup
  /// silebiliyordu). Artık 128 bit'lik kriptografik olarak güvenli rastgele
  /// bir kimlik üretiliyor (Random.secure() — Dart'ın CSPRNG'i, ek paket
  /// gerekmez) — pratikte tahmin edilemez.
  String _generateSecureId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _deriveProjectName(String? hint) {
    if (hint != null && hint.trim().isNotEmpty) {
      final oneLine = hint.trim().replaceAll(RegExp(r'\s+'), ' ');
      return oneLine.length > 42 ? '${oneLine.substring(0, 42)}…' : oneLine;
    }
    return 'Proje ${projects.length + 1}';
  }

  /// Ekrandaki Hızlı Araçlar slotunun (qtGeneratedCode/qtGeneratedFiles)
  /// içeriğini, o an bağlı olduğu projeye yazar; henüz hiçbir projeye bağlı
  /// değilse YENİ bir proje kaydı oluşturur. Site üretimi dahil ekrandaki
  /// slotu değiştiren HER akış tarafından otomatik çağrılır — kullanıcının
  /// ayrıca "kaydet" demesine gerek yoktur.
  ///
  /// [nameForNew] sadece YENİ bir proje oluşturulacaksa kullanılır.
  Future<void> _touchQtProjectFromCurrent({String? nameForNew, ProjectKind? kind}) async {
    final hasContent = qtSiteMode == SiteMode.multi
        ? qtGeneratedFiles.isNotEmpty
        : qtGeneratedCode.trim().isNotEmpty;
    if (!hasContent) return;

    final now = DateTime.now();
    if (qtCurrentProjectId == null) {
      final id = _generateSecureId();
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
    final touchedIdx = projects.indexWhere((p) => p.id == qtCurrentProjectId);
    if (touchedIdx != -1) {
      unawaited(_syncProjectToCloudIfSignedIn(projects[touchedIdx]));
    }
  }

  Future<void> _persistProjects() async {
    await _writeLargeData(
      _projectsFile,
      jsonEncode(projects.map((p) => p.toJson()).toList()),
    );
  }

  /// Projelerim listesinden bir projeyi ekrandaki Hızlı Araçlar slotuna
  /// yükler (DÜZENLE akışı bunu kullanır). Açmadan önce, o an ekranda açık
  /// olan farklı bir proje varsa önce O kaybolmadan kaydedilir.
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
    qtCurrentKind = p.kind;
    // 26.08.2026 değişti: ARTIK sıfırlanmıyor — proje kendi formData'sını
    // taşıyorsa (bkz. SiteProject.formData / setQtFormData) ondan geri
    // yüklenir. Eski kayıtlarda bu alan yoksa (null) boş kalır — o zaman
    // "Düzenle" formu eskisi gibi boş açılır, geriye dönük tamamen uyumlu.
    qtFormData = p.formData ?? {};
    notifyListeners();
    await _writeLargeData(_qtGeneratedCodeFile, p.code);
    await _writeLargeData(_qtGeneratedFilesFile, jsonEncode(p.files));
    await _writeLargeData(_qtFormDataFile, jsonEncode(qtFormData));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qtSiteModePrefsKey, p.mode.name);
    await prefs.setString(_qtCurrentKindPrefsKey, p.kind.name);
    if (p.activeFileName != null) {
      await prefs.setString(_qtActiveFilePrefsKey, p.activeFileName!);
    } else {
      await prefs.remove(_qtActiveFilePrefsKey);
    }
    await prefs.setString(_qtCurrentProjectIdPrefsKey, p.id);
  }

  /// Projelerim listesinden bir projeyi kalıcı olarak siler. Silinen proje
  /// o an ekranda açık olan proje ise Hızlı Araçlar slotu da temizlenir.
  ///
  /// (2026-09-02 eklendi) Proje YAYINDAYSA, yerel kayıt silinmeden ÖNCE
  /// worker'a unpublish isteği atılır — BİLEREK önce bu, sonra yerel silme:
  /// project.ownerToken sadece bu kayıtta duruyor, kayıt silinince o token
  /// da SONSUZA DEK kaybolur ve site worker'da YETİM (sahipsiz, bir daha
  /// hiçbir cihazdan kaldırılamaz) kalır. Worker isteği başarısız olursa
  /// (ağ sorunu vb.) yine de yerel silme akışını BLOKLAMAZ — kullanıcı
  /// "Proje silindi" sonucunu her durumda görür, tıpkı bulut senkronu gibi
  /// best-effort'tur. Yayında olmayan bir projede bu adım hiç çalışmaz.
  Future<void> deleteProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx != -1 && projects[idx].isPublished) {
      try {
        await HostingService.unpublish(siteId: id, ownerToken: projects[idx].ownerToken);
      } catch (_) {
        // Best-effort: worker'a ulaşılamasa bile kullanıcı projesini
        // Projelerim'den kaldırabilmeli. Site worker'da yetim kalabilir
        // ama kullanıcının cihazında engelleyici bir hata görünmez.
      }
    }
    projects.removeWhere((p) => p.id == id);
    if (qtCurrentProjectId == id) {
      qtGeneratedCode = '';
      qtGeneratedFiles = {};
      qtActiveFileName = null;
      qtCurrentProjectId = null;
      await _deleteLargeData(_qtGeneratedCodeFile);
      await _deleteLargeData(_qtGeneratedFilesFile);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_qtActiveFilePrefsKey);
      await prefs.remove(_qtCurrentProjectIdPrefsKey);
    }
    notifyListeners();
    await _persistProjects();
    unawaited(_deleteProjectFromCloudIfSignedIn(id));
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
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
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

    // 2) Bu proje o an ekrandaki Hızlı Araçlar slotunda açıksa, kullanıcı
    // bir şey yapmadan rozetin ANINDA kaybolduğunu görsün diye ekrandaki
    // kopyayı da temizle.
    if (qtCurrentProjectId == id) {
      qtGeneratedCode = WatermarkService.strip(qtGeneratedCode);
      qtGeneratedFiles = WatermarkService.stripFromFiles(qtGeneratedFiles);
      await _writeLargeData(_qtGeneratedCodeFile, qtGeneratedCode);
      await _writeLargeData(_qtGeneratedFilesFile, jsonEncode(qtGeneratedFiles));
    }

    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

  // ------------------------------------------------------------------
  // İNDİRME HAKKI — SATIN ALMA SONRASI ÇAĞRILACAK TEK NOKTA
  // ------------------------------------------------------------------
  // 28.08.2026 eklendi, 28.08.2026'da fiyat/akış revizyonuyla güncellendi.
  // kProductDownloadWatermarked (29.90) satın alındığında çağrılır — bu
  // projeyi tekrar tekrar, ücretsiz indirebilme HAKKINI verir (bkz.
  // widgets/download_purchase_sheet.dart). ÖNEMLİ: rozetin kendisine
  // DOKUNMAZ — proje o an rozetsizse (watermarkRemoved=true) indirilen
  // dosya zaten rozetsiz olur, rozetliyse rozetli iner. Yani artık
  // watermarkRemoved TEK BAŞINA bu metodun çağrılmasını GEREKSİZ KILMAZ:
  // rozeti önceden kaldırmış bir kullanıcı bile indirme hakkını AYRICA
  // satın almalıdır (bkz. canDownloadFreely).
  Future<void> unlockDownloadForProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final project = projects[idx];
    if (project.downloadPurchased) return; // zaten hakkı var

    projects[idx] = project.copyWith(
      downloadPurchased: true,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

  // ------------------------------------------------------------------
  // "WATERMARKSIZ İNDİR" KOMBO HAKKI — SATIN ALMA SONRASI ÇAĞRILACAK TEK NOKTA
  // ------------------------------------------------------------------
  // 28.08.2026 eklendi. kProductDownloadNoWatermark (169.90) satın
  // alındığında çağrılır — TEK ödemede hem removeWatermarkForProject'in
  // hem de unlockDownloadForProject'in yaptığını uygular: rozeti kalıcı
  // olarak kaldırır VE indirme hakkını verir. SADECE proje henüz
  // rozetsiz DEĞİLKEN sunulur (bkz. download_purchase_sheet.dart) ama
  // savunma amaçlı burada da idempotent tutulur.
  Future<void> unlockDownloadWithoutWatermark(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    // Zaten ikisine de sahipse tekrar işlem yapma.
    if (projects[idx].watermarkRemoved && projects[idx].downloadPurchased) {
      return;
    }

    // Rozet henüz kaldırılmadıysa önce onu kaldır (mevcut içerikten de
    // geriye dönük temizler) — removeWatermarkForProject zaten
    // watermarkRemoved=true ise no-op olduğundan güvenle çağrılabilir.
    await removeWatermarkForProject(id);

    final idx2 = projects.indexWhere((p) => p.id == id);
    if (idx2 == -1) return;
    if (projects[idx2].downloadPurchased) return;

    projects[idx2] = projects[idx2].copyWith(
      downloadPurchased: true,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx2]));
  }

  /// İndirme popup'ının (bkz. download_purchase_sheet.dart) gösterilip
  /// gösterilmeyeceğini belirler. 28.08.2026 revizyonu: SADECE
  /// downloadPurchased bakılır — watermarkRemoved artık indirme hakkı
  /// VERMEZ (rozet kaldırma ve indirme hakkı ayrı satın almalardır).
  /// [id] henüz Projelerim'e hiç kaydedilmemiş (yepyeni, ilk kez üretilen)
  /// bir slotsa proje bulunamaz — bu durumda false dönülür, yani ilk
  /// indirmede popup normal şekilde çıkar (satın alınca proje zaten bu
  /// noktada kaydedilmiş olur, bkz. preview_screen.dart).
  bool canDownloadFreely(String? id) {
    if (id == null) return false;
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return false;
    return projects[idx].downloadPurchased;
  }


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
    // GÜVENLİK (2026-09-01 eklendi): worker sadece İLK publish'te bir
    // ownerToken döner (bkz. PublishResult.ownerToken) — o durumda burada
    // kalıcı olarak saklanır. Sonraki republish'lerde worker null döner,
    // bu da sorun değil çünkü copyWith zaten `ownerToken ?? this.ownerToken`
    // ile ESKİ değeri korur.
    String? ownerToken,
  }) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(
      publishedSubdomain: subdomain,
      publishedUrl: url,
      publishedAt: DateTime.now(),
      ownerToken: ownerToken,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
    // Ücretsiz hakkı/satın alınan krediyi burada "harcarız" — bu proje
    // daha önce hiç yayınlanmadıysa (publishRightGranted false) ücretsiz
    // hakkı ya da bir satın alınmış krediyi tüketir; daha önce zaten
    // yayınlanmışsa (republish/güncelleme) grantPublishRight no-op'tur
    // (bkz. metodun kendi dokümantasyonu). ÖNEMLİ: bu noktaya gelinmeden
    // ÖNCE preview_screen.dart > _publishSite zaten canPublishProject ile
    // kontrol etmiş ve gerekirse satın alma akışını tamamlatmış olmalı —
    // burası sadece o kararın SONUCUNU kalıcı hale getirir.
    await grantPublishRight(id);
    // Kullanıcının artık yayında en az bir sitesi var — günlük "sitenizi
    // kim ziyaret etti" hatırlatmasını kur (bkz. NotificationService
    // dokümantasyonu: bu tek, TEKRAR EDEN bir bildirimdir, her yayınlamada
    // yeniden kurulsa da çoğalmaz). Bildirim kurulamazsa yayınlama akışını
    // ASLA etkilememeli, o yüzden ayrı bir try/catch (NotificationService
    // zaten kendi içinde de yutuyor, bu ekstra güvenlik katmanı).
    try {
      await NotificationService.instance.scheduleDailyVisitorCheckIn();
    } catch (_) {}
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
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
    // Artık yayında HİÇ site kalmadıysa günlük ziyaretçi hatırlatması
    // anlamsız hale gelir (bakacak bir sayı yok) — iptal et. En az bir
    // yayında site kaldıysa dokunma (o zaten kurulu, gereksiz yeniden
    // kurmaya gerek yok).
    if (!projects.any((p) => p.isPublished)) {
      try {
        await NotificationService.instance.cancelDailyVisitorCheckIn();
      } catch (_) {}
    }
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
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
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
    unawaited(_syncProjectToCloudIfSignedIn(projects[refreshedIdx]));
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
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
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
    if (qtCurrentProjectId == null) return;
    final idx = projects.indexWhere((p) => p.id == qtCurrentProjectId);
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
