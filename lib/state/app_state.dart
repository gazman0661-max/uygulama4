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
import '../services/free_plan_restriction_service.dart';
import '../services/hosting_service.dart';
import '../services/domain_service.dart';
import '../services/mini_package_service.dart';
import '../services/watermark_sync_service.dart';
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

  // ------------------------------------------------------------------
  // PREMİUM (ÖZEL DOMAIN PLANI) DURUMU — PROJE BAZLI
  // ------------------------------------------------------------------
  // 04.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği).
  // Ekrandaki Hızlı Araçlar slotu hangi projeye bağlıysa (qtCurrentProjectId)
  // galeri limiti gibi SİTE İÇERİĞİ kısıtlamaları O projenin kendi
  // isPremium'ından (bkz. SiteProject.isPremium = isDomainConnected)
  // okunur — hesap genelinde başka bir sitesi premium olsa bile bu proje
  // kendi domain'ini bağlamadıysa free limitte kalır. Henüz hiçbir projeye
  // kaydedilmemiş (yepyeni, ilk kez oluşturulan) bir slot için varsayılan
  // olarak free (false) kabul edilir — yeni bir site domain bağlanmadan
  // premium olamaz.
  bool get qtCurrentIsPremium {
    final projectId = qtCurrentProjectId;
    if (projectId == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].isPremium;
  }

  // ------------------------------------------------------------------
  // ÇOK SAYFA KISITLAMASI (FreePlanPageLimitService) — PROJE NESNESİ
  // ------------------------------------------------------------------
  // 06.09.2026 eklendi (kanka isteği). qtCurrentIsPremium/qtCurrentHasBranding
  // gibi bool DEĞİL, SiteProject'in KENDİSİNİ döner — çünkü çok sayfa
  // sınırı (bkz. FreePlanPageLimitService) sadece "premium mi değil mi"
  // değil, PREMİUM'UN KAYNAĞININ (domain mi mini paket mi) NE olduğunu da
  // ayırt etmek zorunda (domain = sınırsız, mini paket = 3 ek sayfa).
  // qtCurrentIsPremium ile AYNI arama deseni: hiçbir projeye kaydedilmemiş
  // (yepyeni) bir slot için null döner.
  SiteProject? get qtCurrentProject {
    final projectId = qtCurrentProjectId;
    if (projectId == null) return null;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return null;
    return projects[idx];
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

  // --- BULUT SENKRON KUYRUĞU (04.09.2026 eklendi) ---
  // _syncProjectToCloudIfSignedIn "unawaited" (arka planda, sonucu
  // beklenmeden) çağrıldığı için, o istek bitmeden uygulama kapanırsa/
  // silinirse ya da o an internet yoksa proje buluta HİÇ yazılmamış olabilir
  // — kullanıcı puanlarını geri alır ama projesi boş gelir. Bunu önlemek
  // için: bir proje senkronu BAŞARISIZ olursa id'si burada (cihazda kalıcı
  // olarak) tutulur; bir sonraki uygulama açılışında (girişten hemen sonra,
  // bkz. _onAuthChanged > _flushPendingProjectSyncs) otomatik tekrar
  // denenir. Böylece internet o an yoksa bile veri KAYBOLMAZ, sadece
  // ertelenir.
  static const _pendingProjectSyncPrefsKey = 'pending_project_cloud_sync_ids';
  final Set<String> _pendingProjectSync = {};

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

  /// 04.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği).
  /// Hesapta en az bir PREMİUM (özel domain bağlı) proje var mı. Bazı
  /// kısıtlamalar (ör. Talep Kutusu) proje bazlı değil, HESAP BAZLI bir
  /// sekme/özellik olduğu için tek tek projeye değil bu genel duruma bakar:
  /// kullanıcının en az bir premium sitesi varsa hesap "free" sayılmaz.
  bool get hasPremiumProject => projects.any((p) => p.isPremium);

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

  /// Bir HTML içeriğine, o anki plana göre gereken TÜM dönüşümleri
  /// (05.09.2026: önce free-plan kilitli bölüm temizliği, sonra rozet)
  /// uygulayan tek nokta — bkz. updateQtGeneratedCode/updateQtGeneratedFiles/
  /// updateQtActiveFileContent. Sıra önemli değil (iki dönüşüm de HTML'in
  /// FARKLI bölümlerine dokunuyor) ama tutarlılık için hep aynı sırada.
  String _finalizeHtml(String raw) {
    final stripped = FreePlanRestrictionService.strip(raw, isPremium: qtCurrentIsPremium);
    return qtCurrentHasBranding ? WatermarkService.apply(stripped, isEnglish: isEnglish) : stripped;
  }

  Map<String, String> _finalizeHtmlFiles(Map<String, String> raw) {
    final stripped = FreePlanRestrictionService.stripFromFiles(raw, isPremium: qtCurrentIsPremium);
    return qtCurrentHasBranding ? WatermarkService.applyToFiles(stripped, isEnglish: isEnglish) : stripped;
  }

  void updateQtGeneratedCode(String code, {String? projectName, ProjectKind? kind}) {
    qtGeneratedCode = _finalizeHtml(code);
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
    qtGeneratedFiles = _finalizeHtmlFiles(files);
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
    final finalContent = isHtml ? _finalizeHtml(newContent) : newContent;
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

  // ------------------------------------------------------------------
  // HEDİYE PUAN BAKİYESİ — 03.09.2026 eklendi.
  // ------------------------------------------------------------------
  // Kutu'dan (bkz. MailboxService) admin tarafından gönderilen puan
  // hediyeleri artık BURAYA ekleniyor — satın alınan puandan (purchasedPoints)
  // BİLEREK AYRI tutuluyor ki Ayarlar ekranında kullanıcı "satın aldığım
  // puan" ile "hediye gelen puan"ı ayrı ayrı görebilsin (bkz.
  // settings_sheet.dart > _BalancesSection). purchasedPoints gibi bu
  // bakiye de ayın 1'inde SIFIRLANMAZ — kullanıcı harcayana kadar kalır.
  static const _giftPointsPrefsKey = 'gift_points_balance';
  int giftPoints = 0;

  /// Kutu'dan bir puan hediyesi teslim alındığında (bkz.
  /// mailbox_screen.dart > _claim, `giftType == 'points'`) çağrılır.
  Future<void> addGiftPoints(int amount) async {
    giftPoints += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftPointsPrefsKey, giftPoints);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

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

  // ------------------------------------------------------------------
  // HEDİYE YAYIN HAKKI — 03.09.2026 eklendi.
  // ------------------------------------------------------------------
  // Kutu'dan (admin panelinde giftType == 'publishCredit') gelen yayın
  // hakkı hediyeleri artık BURAYA ekleniyor — satın alınan yayın hakkından
  // (extraPublishCredits) BİLEREK AYRI tutuluyor ki Ayarlar ekranında
  // "satın aldığım hak" ile "hediye gelen hak" ayrı ayrı görünsün (bkz.
  // giftPoints/purchasedPoints'teki AYNI ayrım — settings_sheet.dart >
  // _BalancesSection).
  static const _giftPublishCreditsPrefsKey = 'gift_publish_credits';
  int giftPublishCredits = 0;

  /// Kutu'dan bir yayın hakkı hediyesi teslim alındığında (bkz.
  /// mailbox_screen.dart > _claim, `giftType == 'publishCredit'`) çağrılır.
  Future<void> addGiftPublishCredit() async {
    giftPublishCredits += 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftPublishCreditsPrefsKey, giftPublishCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  // ------------------------------------------------------------------
  // HEDİYE ROZET KALDIRMA / İNDİRME HAKLARI — 03.09.2026 eklendi.
  // ------------------------------------------------------------------
  // giftPoints/giftPublishCredits ile AYNI desen: admin panelinden
  // (Kutu > "watermarkRemoval" | "downloadWatermarked" | "downloadClean"
  // hediye türleri) gelen haklar HESAP GENELİNDE bir bakiye olarak tutulur
  // — rozet kaldırma/indirme hakkının kendisi SİTE BAZLI olsa da (bkz.
  // WatermarkService, AppState.removeWatermarkForProject/
  // unlockDownloadForProject/unlockDownloadWithoutWatermark), bir HEDİYE
  // hangi projeye uygulanacağını admin panelinden BİLEMEZ (mailbox "all"a
  // ya da tek bir uid'e gider, belirli bir projeye değil). Bu yüzden
  // kullanıcı bakiyeyi Kutu'dan teslim alır, SONRA dilediği projede
  // (remove_watermark_sheet.dart / download_purchase_sheet.dart üzerinden)
  // "Hediye hakkımı kullan" ile harcar — bkz. aşağıdaki redeemGift* metotları.
  static const _giftWatermarkRemovalCreditsPrefsKey = 'gift_watermark_removal_credits';
  static const _giftDownloadWatermarkedCreditsPrefsKey = 'gift_download_watermarked_credits';
  static const _giftDownloadCleanCreditsPrefsKey = 'gift_download_clean_credits';
  int giftWatermarkRemovalCredits = 0;
  int giftDownloadWatermarkedCredits = 0;
  int giftDownloadCleanCredits = 0;

  // 05.09.2026 eklendi (kanka isteği) — yukarıdakilerle AYNI desen, admin
  // panelinden (Kutu > "domainConnect" | "miniPackage" hediye türleri)
  // gelen haklar. Domain paketi worker'a GERÇEK bir bağlanma isteği
  // (domain adı + DomainService.connect) gerektirdiği için bu bakiye
  // SADECE ödemeyi atlar — kredi varsa domain_purchase_sheet.dart
  // "Kullan hediye hakkı"na bastığında normal satın alma yerine bu
  // bakiyeden düşer ve AYNI `true` dönüşü yapar, asıl bağlanma isteğini
  // yine çağıran taraf (domain_connect_screen.dart > _connect/_renew)
  // atar — gerçek satın almayla BİREBİR aynı akış. Mini paket ise tamamen
  // yerel (activateMiniPackage) olduğu için redeem metodu doğrudan onu
  // da tetikler.
  static const _giftDomainConnectCreditsPrefsKey = 'gift_domain_connect_credits';
  static const _giftMiniPackageCreditsPrefsKey = 'gift_mini_package_credits';
  int giftDomainConnectCredits = 0;
  int giftMiniPackageCredits = 0;

  /// Kutu'dan bir "watermark kaldırma hakkı" hediyesi teslim alındığında
  /// (bkz. mailbox_screen.dart > _claim, `giftType == 'watermarkRemoval'`)
  /// çağrılır. [amount] admin panelindeki giftAmount'tur (genelde 1, ama
  /// admin isterse tek mesajda birden fazla hak da hediye edebilir).
  Future<void> addGiftWatermarkRemovalCredit(int amount) async {
    if (amount <= 0) return;
    giftWatermarkRemovalCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftWatermarkRemovalCreditsPrefsKey, giftWatermarkRemovalCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  /// Kutu'dan bir "watermarklı indirme hakkı" hediyesi teslim alındığında
  /// (`giftType == 'downloadWatermarked'`) çağrılır.
  Future<void> addGiftDownloadWatermarkedCredit(int amount) async {
    if (amount <= 0) return;
    giftDownloadWatermarkedCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDownloadWatermarkedCreditsPrefsKey, giftDownloadWatermarkedCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  /// Kutu'dan bir "watermarksız indirme hakkı" hediyesi teslim alındığında
  /// (`giftType == 'downloadClean'`) çağrılır.
  Future<void> addGiftDownloadCleanCredit(int amount) async {
    if (amount <= 0) return;
    giftDownloadCleanCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDownloadCleanCreditsPrefsKey, giftDownloadCleanCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  /// Kutu'dan bir "özel domain bağlama hakkı" hediyesi teslim alındığında
  /// (`giftType == 'domainConnect'`) çağrılır.
  Future<void> addGiftDomainConnectCredit(int amount) async {
    if (amount <= 0) return;
    giftDomainConnectCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDomainConnectCreditsPrefsKey, giftDomainConnectCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  /// Kutu'dan bir "1 aylık mini paket hakkı" hediyesi teslim alındığında
  /// (`giftType == 'miniPackage'`) çağrılır.
  Future<void> addGiftMiniPackageCredit(int amount) async {
    if (amount <= 0) return;
    giftMiniPackageCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftMiniPackageCreditsPrefsKey, giftMiniPackageCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  /// [id] projesinde hediye bakiyesinden 1 "rozet kaldırma hakkı" harcar.
  /// Bakiye yoksa (>0 değilse) HİÇBİR ŞEY yapmadan `false` döner — çağıran
  /// taraf (remove_watermark_sheet.dart) bu durumda normal ödeme akışını
  /// göstermeye devam etmeli. Başarılıysa bakiyeyi düşer VE
  /// removeWatermarkForProject ile projeye asıl etkiyi uygular.
  Future<bool> redeemGiftWatermarkRemoval(String projectId) async {
    if (giftWatermarkRemovalCredits <= 0) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    // Zaten rozetsizse hediyeyi boşuna harcama — çağıran taraf zaten bu
    // durumda popup'ı göstermemeli ama savunma amaçlı burada da kontrol edilir.
    if (idx != -1 && projects[idx].watermarkRemoved) return true;

    giftWatermarkRemovalCredits -= 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftWatermarkRemovalCreditsPrefsKey, giftWatermarkRemovalCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());

    await removeWatermarkForProject(projectId);
    return true;
  }

  /// [id] projesinde hediye bakiyesinden 1 "watermarklı indirme hakkı"
  /// harcar — bkz. [redeemGiftWatermarkRemoval] dokümantasyonu, AYNI desen.
  Future<bool> redeemGiftDownloadWatermarked(String projectId) async {
    if (giftDownloadWatermarkedCredits <= 0) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx != -1 && projects[idx].downloadPurchased) return true;

    giftDownloadWatermarkedCredits -= 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDownloadWatermarkedCreditsPrefsKey, giftDownloadWatermarkedCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());

    await unlockDownloadForProject(projectId);
    return true;
  }

  /// [id] projesinde hediye bakiyesinden 1 "watermarksız indirme hakkı"
  /// harcar — hem rozeti kaldırır hem indirme hakkı verir (bkz.
  /// unlockDownloadWithoutWatermark), AYNI kombo mantığı.
  Future<bool> redeemGiftDownloadClean(String projectId) async {
    if (giftDownloadCleanCredits <= 0) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx != -1 && projects[idx].watermarkRemoved && projects[idx].downloadPurchased) {
      return true;
    }

    giftDownloadCleanCredits -= 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDownloadCleanCreditsPrefsKey, giftDownloadCleanCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());

    await unlockDownloadWithoutWatermark(projectId);
    return true;
  }

  /// Hediye bakiyesinden 1 "özel domain bağlama hakkı" harcar — SADECE
  /// ÖDEMEYİ atlar (bkz. yukarıdaki alan dokümantasyonu). Bakiye yoksa
  /// `false` döner, çağıran taraf (domain_purchase_sheet.dart) normal
  /// ödeme akışını göstermeye devam etmeli. Gerçek bağlanma/yenileme
  /// isteğini (worker'a domain adıyla) HÂLÂ çağıran taraf
  /// (domain_connect_screen.dart) bu `true` dönüşünden SONRA, gerçek bir
  /// satın almadan sonra yaptığı ile BİREBİR AYNI şekilde atar.
  Future<bool> redeemGiftDomainConnect() async {
    if (giftDomainConnectCredits <= 0) return false;
    giftDomainConnectCredits -= 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDomainConnectCreditsPrefsKey, giftDomainConnectCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
    return true;
  }

  /// [id] projesinde hediye bakiyesinden 1 "1 aylık mini paket hakkı"
  /// harcar. Mini paket tamamen yerel olduğu için (worker'a hiç istek
  /// atmıyor, bkz. DEGISIKLIKLER_05_09_2026_MINI_PAKET.md) redeem doğrudan
  /// activateMiniPackage'i de tetikler — domain'in aksine ayrıca bir
  /// "gerçek istek" adımına gerek yok.
  Future<bool> redeemGiftMiniPackage(String projectId) async {
    if (giftMiniPackageCredits <= 0) return false;
    giftMiniPackageCredits -= 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftMiniPackageCreditsPrefsKey, giftMiniPackageCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());

    await activateMiniPackage(projectId);
    return true;
  }

  /// [project] şu an satın alma gerektirmeden yayınlanabilir mi?
  /// true dönerse showPublishSheet doğrudan açılabilir; false dönerse önce
  /// publish_paywall_sheet.dart ile bir "yayın hakkı" satın alınmalı.
  bool canPublishProject(SiteProject project) {
    if (project.publishRightGranted) return true;
    if (!freeSitePublishUsed) return true;
    return (giftPublishCredits + extraPublishCredits) > 0;
  }

  /// [project] YENİ yayınlanmadan hemen ÖNCE (ilk kez `isPublished` true
  /// olacaksa) çağrılmalı — bkz. preview_screen.dart > _publishSite. Bu
  /// proje zaten hakkını kullanmışsa (publishRightGranted true) HİÇBİR ŞEY
  /// yapmadan çıkar (idempotent), yani markProjectPublished içinden her
  /// yayınlamada güvenle çağrılabilir.
  ///
  /// Harcama sırası: önce ücretsiz ilk hak, sonra HEDİYE yayın hakkı
  /// (kullanıcının PARA ÖDEMEDİĞİ bakiye), en son satın alınan yayın hakkı
  /// (extraPublishCredits — puan bakiyelerindeki AYNI mantık, bkz.
  /// _spendFromPool).
  Future<void> grantPublishRight(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1 || projects[idx].publishRightGranted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!freeSitePublishUsed) {
      freeSitePublishUsed = true;
      await prefs.setBool(_freeSitePublishUsedPrefsKey, true);
    } else if (giftPublishCredits > 0) {
      giftPublishCredits -= 1;
      await prefs.setInt(_giftPublishCreditsPrefsKey, giftPublishCredits);
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
  /// Aylık ücretsiz kota yetmiyorsa satın alınmış (purchasedPoints) VE
  /// hediye (giftPoints) puan bakiyeleri de hesaba katılır.
  Future<bool> ensureFormQuotaFor(int cost) async {
    await _ensureMonthlyPointsReset();
    return (formCredits + giftPoints + purchasedPoints) >= cost;
  }

  /// FORM üretimi BAŞARIYLA tamamlandıktan SONRA çağrılmalı. Harcama
  /// sırası: önce aylık ücretsiz FORM havuzu (zaten ay sonunda sıfırlanacağı
  /// için önce o eritilir), sonra hediye puan (giftPoints — kullanıcının
  /// PARA ÖDEMEDİĞİ bakiye), en son satın alınan puan (purchasedPoints —
  /// kullanıcının parasıyla aldığı bakiye elden geldiğince en son harcanır).
  Future<void> consumeFormQuota(int cost) async {
    await _ensureMonthlyPointsReset(notify: false);
    formCredits = await _spendFromPool(pool: formCredits, cost: cost);
    notifyListeners();
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  /// Ortak harcama mantığı: önce aylık FORM havuzundan düşer; o yetmezse
  /// kalanı önce giftPoints'ten, o da yetmezse purchasedPoints'ten düşer
  /// (bkz. yukarıdaki sıralama açıklaması). Güncellenmiş aylık havuz
  /// değerini döner (çağıran taraf formCredits'e atar).
  Future<int> _spendFromPool({
    required int pool,
    required int cost,
  }) async {
    final fromPool = cost.clamp(0, pool);
    var remaining = cost - fromPool;
    final newPool = (pool - fromPool).clamp(0, maxFormPoints);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_formPointsPrefsKey, newPool);

    if (remaining > 0) {
      final fromGift = remaining.clamp(0, giftPoints);
      giftPoints = (giftPoints - fromGift).clamp(0, 1 << 30);
      await prefs.setInt(_giftPointsPrefsKey, giftPoints);
      remaining -= fromGift;
    }

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

  // 14.09.2026 eklendi (kanka bulgusu — KRİTİK BUG) — bkz. [_resetToGuestDefaults]
  // dokümanı. Gerçek bir "çıkış" ile "uygulama ilk kez açıldı, hiç giriş
  // yapılmamış" (misafir) durumunu ayırt etmek için kullanılır.
  String? _lastKnownUid;
  bool _authListenerFired = false;

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

  /// 14.09.2026 DÜZELTİLDİ (kanka bulgusu — KRİTİK BUG): "misafir modunda
  /// önceki hesabın puanları/projeleri görünmeye devam ediyor VE yeni açılan
  /// bir hesapta bile eski hesabın verileri çıkıyor" şikayetinin kök nedeni
  /// burasıydı. Eski davranış: `if (user == null) return;` — yani ÇIKIŞTA
  /// hiçbir yerel veri temizlenmiyordu. Bu, tek cihazda iki farklı hesap
  /// art arda kullanıldığında şuna yol açıyordu: Hesap A çıkış yapar, cihazda
  /// A'nın puanları/projeleri AYNEN kalır → Hesap B ilk kez giriş yapar →
  /// aşağıdaki fetchOrCreateUserDoc, B'nin bulutta HENÜZ dokümanı olmadığı
  /// için cihazdaki (hâlâ A'ya ait) değerleri B'nin "ilk cihaz verisi" olarak
  /// buluta yazıyordu — yani A'nın puanları/projeleri LİTERALMENTE B'ye
  /// kopyalanıyordu. Misafir moda dönüşte de aynı sebepten A'nın verileri
  /// ekranda kalmaya devam ediyordu.
  ///
  /// YENİ davranış: [_lastKnownUid]/[_authListenerFired] ile GERÇEK bir
  /// çıkışı (önceden dolu bir UID vardı, şimdi null oldu) veya araya
  /// signOut girmeden DOĞRUDAN farklı bir hesaba geçişi ayırt ediyoruz —
  /// bu durumlarda [_resetToGuestDefaults] çağrılır. Uygulamanın İLK
  /// açılışında (hiç giriş yapılmamış saf misafir — ilk emisyon zaten null
  /// gelir) HİÇBİR ŞEY silinmez, misafir ilerlemesi olduğu gibi korunur
  /// (aşağıdaki asıl giriş akışı bunu ilk girişte buluta taşımaya devam
  /// eder — bkz. altındaki 1-3 numaralı adımlar, DEĞİŞMEDİ).
  ///
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
    final previousUid = _lastKnownUid;
    final isFirstEmission = !_authListenerFired;
    _authListenerFired = true;
    _lastKnownUid = user?.uid;

    if (user == null) {
      // Gerçek bir ÇIKIŞ (önceden dolu bir UID vardı) ise cihazı temizle.
      // İlk açılışta (hiç login olmamış saf misafir) DOKUNMA.
      if (!isFirstEmission && previousUid != null) {
        await _resetToGuestDefaults();
      }
      return;
    }

    // Araya bir signOut girmeden DOĞRUDAN farklı bir hesaba geçiş — normal
    // akışta olmaz ama önlem: önceki hesaptan kalan cihaz değerleri YENİ
    // hesabın "ilk cihaz verisi" gibi buluta yazılmasın diye önce temizle.
    if (previousUid != null && previousUid != user.uid) {
      await _resetToGuestDefaults();
    }
    try {
      final cloudData = await UserDataService.instance.fetchOrCreateUserDoc(
        uid: user.uid,
        email: user.email,
        deviceFormCredits: formCredits,
        deviceResetMonth: _thisMonthUtcKey(),
        maxFormPoints: maxFormPoints,
        deviceExtraPurchasedPoints: purchasedPoints,
        deviceGiftPoints: giftPoints,
        deviceFreeSitePublishUsed: freeSitePublishUsed,
        deviceExtraPublishCredits: extraPublishCredits,
        deviceGiftPublishCredits: giftPublishCredits,
        deviceGiftWatermarkRemovalCredits: giftWatermarkRemovalCredits,
        deviceGiftDownloadWatermarkedCredits: giftDownloadWatermarkedCredits,
        deviceGiftDownloadCleanCredits: giftDownloadCleanCredits,
        deviceGiftDomainConnectCredits: giftDomainConnectCredits,
        deviceGiftMiniPackageCredits: giftMiniPackageCredits,
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
      giftPoints = (cloudData['giftPoints'] as num?)?.toInt() ?? giftPoints;
      freeSitePublishUsed = cloudData['freeSitePublishUsed'] as bool? ?? freeSitePublishUsed;
      extraPublishCredits = (cloudData['extraPublishCredits'] as num?)?.toInt() ?? extraPublishCredits;
      giftPublishCredits = (cloudData['giftPublishCredits'] as num?)?.toInt() ?? giftPublishCredits;
      giftWatermarkRemovalCredits =
          (cloudData['giftWatermarkRemovalCredits'] as num?)?.toInt() ?? giftWatermarkRemovalCredits;
      giftDownloadWatermarkedCredits =
          (cloudData['giftDownloadWatermarkedCredits'] as num?)?.toInt() ?? giftDownloadWatermarkedCredits;
      giftDownloadCleanCredits =
          (cloudData['giftDownloadCleanCredits'] as num?)?.toInt() ?? giftDownloadCleanCredits;
      giftDomainConnectCredits =
          (cloudData['giftDomainConnectCredits'] as num?)?.toInt() ?? giftDomainConnectCredits;
      giftMiniPackageCredits =
          (cloudData['giftMiniPackageCredits'] as num?)?.toInt() ?? giftMiniPackageCredits;

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
      await prefs.setInt(_giftPointsPrefsKey, giftPoints);
      await prefs.setBool(_freeSitePublishUsedPrefsKey, freeSitePublishUsed);
      await prefs.setInt(_extraPublishCreditsPrefsKey, extraPublishCredits);
      await prefs.setInt(_giftPublishCreditsPrefsKey, giftPublishCredits);
      await prefs.setInt(_giftWatermarkRemovalCreditsPrefsKey, giftWatermarkRemovalCredits);
      await prefs.setInt(_giftDownloadWatermarkedCreditsPrefsKey, giftDownloadWatermarkedCredits);
      await prefs.setInt(_giftDownloadCleanCreditsPrefsKey, giftDownloadCleanCredits);
      await prefs.setInt(_giftDomainConnectCreditsPrefsKey, giftDomainConnectCredits);
      await prefs.setInt(_giftMiniPackageCreditsPrefsKey, giftMiniPackageCredits);
      await _persistProjects();
      notifyListeners();

      // Birleşimden "yereldeki kazandı" çıkan projeleri buluta geri yaz —
      // sessizce, akışı bloklamadan (fire-and-forget).
      for (final project in toReupload) {
        unawaited(_syncProjectToCloudIfSignedIn(project));
      }

      // Bir önceki oturumdan kalan, buluta hiç ulaşamamış proje varsa
      // (bkz. _pendingProjectSync dokümantasyonu) şimdi giriş yapılmışken
      // tekrar dene — kullanıcı fark etmeden, sessizce.
      unawaited(_flushPendingProjectSyncs());
    } catch (_) {
      // Bulut senkronizasyonu başarısız olsa da uygulama cihazdaki
      // (misafir) değerlerle çalışmaya devam eder — kullanıcı akışı
      // kesilmez.
    }
  }

  /// 14.09.2026 eklendi (kanka bulgusu — KRİTİK BUG, bkz. [_onAuthChanged]
  /// dokümanı). Cihazdaki HESABA ÖZEL tüm alanları gerçek "ilk kurulum"
  /// varsayılanlarına döndürür: puanlar/haklar/projeler + o an ekranda
  /// açık olan Hızlı Araçlar slotu (bkz. [detachQtSlotForNewProject]).
  /// Hem bellekteki (in-memory) hem SharedPreferences/dosyadaki kopyayı
  /// günceller — yoksa uygulama kapatılıp açıldığında eski hesabın
  /// değerleri SharedPreferences'tan geri okunurdu.
  ///
  /// NOT: Bu fonksiyon SADECE gerçek bir çıkış/hesap değişimi anında
  /// çağrılır (bkz. [_onAuthChanged]) — uygulamanın ilk açılışında, hiç
  /// giriş yapılmamış saf bir misafirin ilerlemesini SİLMEZ.
  Future<void> _resetToGuestDefaults() async {
    formCredits = maxFormPoints;
    purchasedPoints = 0;
    giftPoints = 0;
    freeSitePublishUsed = false;
    extraPublishCredits = 0;
    giftPublishCredits = 0;
    giftWatermarkRemovalCredits = 0;
    giftDownloadWatermarkedCredits = 0;
    giftDownloadCleanCredits = 0;
    giftDomainConnectCredits = 0;
    giftMiniPackageCredits = 0;
    projects = [];
    notifyListeners();

    // Ekranda o an açık olan (kaydedilmemiş olabilecek) siteyi de temizle
    // — yoksa yeni hesap/misafir moduna dönüldüğünde Hızlı Araçlar'da
    // önceki hesabın üretimi görünmeye devam ederdi.
    await detachQtSlotForNewProject();
    await _persistProjects();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_formPointsPrefsKey, formCredits);
    await prefs.setString(_formPointsResetMonthPrefsKey, _thisMonthUtcKey());
    await prefs.setInt(_purchasedPointsPrefsKey, purchasedPoints);
    await prefs.setInt(_giftPointsPrefsKey, giftPoints);
    await prefs.setBool(_freeSitePublishUsedPrefsKey, freeSitePublishUsed);
    await prefs.setInt(_extraPublishCreditsPrefsKey, extraPublishCredits);
    await prefs.setInt(_giftPublishCreditsPrefsKey, giftPublishCredits);
    await prefs.setInt(_giftWatermarkRemovalCreditsPrefsKey, giftWatermarkRemovalCredits);
    await prefs.setInt(_giftDownloadWatermarkedCreditsPrefsKey, giftDownloadWatermarkedCredits);
    await prefs.setInt(_giftDownloadCleanCreditsPrefsKey, giftDownloadCleanCredits);
    await prefs.setInt(_giftDomainConnectCreditsPrefsKey, giftDomainConnectCredits);
    await prefs.setInt(_giftMiniPackageCreditsPrefsKey, giftMiniPackageCredits);
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
        giftPoints: giftPoints,
        freeSitePublishUsed: freeSitePublishUsed,
        extraPublishCredits: extraPublishCredits,
        giftPublishCredits: giftPublishCredits,
        giftWatermarkRemovalCredits: giftWatermarkRemovalCredits,
        giftDownloadWatermarkedCredits: giftDownloadWatermarkedCredits,
        giftDownloadCleanCredits: giftDownloadCleanCredits,
        giftDomainConnectCredits: giftDomainConnectCredits,
        giftMiniPackageCredits: giftMiniPackageCredits,
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
  /// Döner: senkron BAŞARILI mı? (çağıran taraf, kritik akışlarda —
  /// yayınlama, yeni proje, silme — bu sonucu `await` edip kullanıcıya
  /// "kaydedilemedi, tekrar denenecek" gibi bir bilgi gösterebilir; rutin
  /// arka plan güncellemelerinde ise sonuç yok sayılıp yine fire-and-forget
  /// çağrılabilir — başarısızlık HER DURUMDA aşağıda kuyruğa yazılır,
  /// bir sonraki girişte otomatik tekrar denenir, bkz. _flushPendingProjectSyncs.)
  Future<bool> _syncProjectToCloudIfSignedIn(SiteProject project) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return true; // misafir modda senkron gerekmiyor, hata sayılmaz

    // 05.09.2026 eklendi — KRİTİK DÜZELTME: "bekliyor" işareti artık istek
    // BAŞLAMADAN ÖNCE diske yazılıyor (önceki sürümde sadece catch bloğunda,
    // yani istek BAŞARISIZ OLDUKTAN SONRA yazılıyordu). Eski haliyle: süreç
    // tam istek ağa giderken (ne başarı ne hata cevabı gelmeden) öldürülürse
    // catch bloğu hiç çalışmıyor, id kuyruğa hiç girmiyor, proje sessizce
    // kayboluyordu. await kullanılıyor ki bu yazı, ağ isteği başlamadan
    // GERÇEKTEN diske ulaşmış olsun.
    final alreadyQueued = _pendingProjectSync.contains(project.id);
    if (!alreadyQueued) {
      _pendingProjectSync.add(project.id);
      await _persistPendingProjectSync();
    }
    try {
      await UserDataService.instance.upsertProject(
        uid: user.uid,
        projectJson: project.toJson(),
      );
      if (_pendingProjectSync.remove(project.id)) {
        unawaited(_persistPendingProjectSync());
      }
      return true;
    } catch (_) {
      // Kuyruğa zaten YUKARIDA (istekten önce) eklendi — burada tekrar
      // eklemeye gerek yok.
      return false;
    }
  }

  /// Bekleyen (daha önce buluta yazılamamış) proje senkronlarını tekrar
  /// dener. _onAuthChanged içinde, buluttaki asıl liste zaten çekilip
  /// birleştirildikten SONRA çağrılır — böylece "hangi proje daha yeni"
  /// kararı zaten verilmiş olur, burası sadece o kararın buluta gerçekten
  /// ULAŞMASINI garanti etmeye çalışır.
  Future<void> _flushPendingProjectSyncs() async {
    if (_pendingProjectSync.isEmpty) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    // Kopya üzerinde gez: _syncProjectToCloudIfSignedIn başarılı olursa
    // orijinal seti değiştiriyor (remove), aynı anda üzerinde dönmek hataya
    // yol açar.
    for (final id in List<String>.from(_pendingProjectSync)) {
      final idx = projects.indexWhere((p) => p.id == id);
      if (idx == -1) {
        // Proje bu cihazdan da silinmiş — artık senkronlanacak bir şey yok.
        _pendingProjectSync.remove(id);
        unawaited(_persistPendingProjectSync());
        continue;
      }
      await _syncProjectToCloudIfSignedIn(projects[idx]);
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
    giftPoints = prefs.getInt(_giftPointsPrefsKey) ?? 0;
    freeSitePublishUsed = prefs.getBool(_freeSitePublishUsedPrefsKey) ?? false;
    extraPublishCredits = prefs.getInt(_extraPublishCreditsPrefsKey) ?? 0;
    giftPublishCredits = prefs.getInt(_giftPublishCreditsPrefsKey) ?? 0;
    giftWatermarkRemovalCredits = prefs.getInt(_giftWatermarkRemovalCreditsPrefsKey) ?? 0;
    giftDownloadWatermarkedCredits = prefs.getInt(_giftDownloadWatermarkedCreditsPrefsKey) ?? 0;
    giftDownloadCleanCredits = prefs.getInt(_giftDownloadCleanCreditsPrefsKey) ?? 0;
    giftDomainConnectCredits = prefs.getInt(_giftDomainConnectCreditsPrefsKey) ?? 0;
    giftMiniPackageCredits = prefs.getInt(_giftMiniPackageCreditsPrefsKey) ?? 0;

    // Bir önceki oturumda buluta yazılamamış (internet yoktu/uygulama
    // yarıda kapandı) proje id'leri varsa yükle — girişten sonra
    // _flushPendingProjectSyncs bunları tekrar dener.
    _pendingProjectSync
      ..clear()
      ..addAll(prefs.getStringList(_pendingProjectSyncPrefsKey) ?? const []);

    notifyListeners();

    // 05.09.2026 eklendi — uygulama her açılışında, süresi geçen bir domain
    // paketi varsa o projenin rozetini geri getir (bkz.
    // revertExpiredDomainWatermarks dokümantasyonu). notifyListeners()'dan
    // SONRA çağrılır ki UI önce normal projelerle bir kere çizilsin, sweep
    // kendi notifyListeners()'ını ayrıca tetikler.
    unawaited(revertExpiredDomainWatermarks());
    // 05.09.2026 eklendi — mini paket için AYNI gerekçe (bkz.
    // revertExpiredMiniPackages dokümantasyonu).
    unawaited(revertExpiredMiniPackages());
  }

  Future<void> _persistPendingProjectSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingProjectSyncPrefsKey, _pendingProjectSync.toList());
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
    // 05.09.2026 eklendi — KRİTİK DÜZELTME: qtCurrentProjectId eskiden
    // SADECE openQtProject() içinde SharedPreferences'a yazılıyordu. Yeni
    // bir site İLK KEZ oluşturulduğunda (bu fonksiyonun yukarıdaki
    // qtCurrentProjectId == null dalı) bu satır hiç çalışmıyordu — yani
    // bellekte qtCurrentProjectId doğru olsa bile, uygulama süreci
    // öldürülüp yeniden açıldığında (Android'in arka plandaki uygulamayı
    // düşük bellekte kapatması gibi) diskteki değer eski/boş kalıyordu.
    // Sonuç: Projelerim'den az önce oluşturulan siteye tıklandığında
    // openQtProject "zaten bu proje açık" sanıp (id == qtCurrentProjectId
    // güvenli görünüyordu ama aslında disk/bellek arasında TUTARSIZDI)
    // içeriği yeniden yüklemiyor, önizleme "Henüz üretilmiş bir site yok"
    // uyarısı gösteriyordu. Artık her dokunuşta anında diske de yazılıyor.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qtCurrentProjectIdPrefsKey, qtCurrentProjectId!);
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
  // TEK İSTİSNA: [viaDomain] veya [viaMiniPackage] true iken verilen
  // kaldırma, domain/mini paket süresi dolduğunda sırasıyla
  // revertExpiredDomainWatermarks / revertExpiredMiniPackages tarafından
  // geri alınabilir (bkz. SiteProject.watermarkRemovedByDomain /
  // watermarkRemovedByMiniPackage dokümantasyonu). İkisi AYNI ANDA true
  // OLAMAZ — bir kaldırma tek bir kaynağa aittir.
  Future<void> removeWatermarkForProject(
    String id, {
    bool viaDomain = false,
    bool viaMiniPackage = false,
  }) async {
    assert(!(viaDomain && viaMiniPackage));
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final project = projects[idx];
    if (project.watermarkRemoved) {
      // Zaten rozetsiz. Tek anlamlı durum: daha önce SADECE domain veya mini
      // paketle (geçici) kaldırılmıştı, şimdi GERÇEK bir satın alma
      // (viaDomain:false, viaMiniPackage:false) geliyor — bu, kaldırmayı
      // KALICI hale getirir (süre dolsa bile artık rozet geri gelmez).
      // İçerik zaten rozetsiz olduğundan tekrar strip etmeye gerek yok.
      if (!viaDomain &&
          !viaMiniPackage &&
          (project.watermarkRemovedByDomain || project.watermarkRemovedByMiniPackage)) {
        projects[idx] = project.copyWith(
          watermarkRemovedByDomain: false,
          watermarkRemovedByMiniPackage: false,
        );
        notifyListeners();
        await _persistProjects();
        unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
        // 06.09.2026 eklendi — worker'a da bildir ki premiumDowngradeSweep
        // bu siteye BİR DAHA rozet enjekte etmesin (bkz. WatermarkSyncService
        // dokümanı). Best-effort, satın alma akışını etkilemez.
        unawaited(WatermarkSyncService.markPermanent(siteId: id).catchError((_) {}));
      }
      return; // diğer tüm durumlarda no-op
    }

    // 1) Projenin KENDİ kaydında zaten üretilmiş/kaydedilmiş içerikten
    // rozeti geriye dönük temizle (üretim anında gömüldüğü için).
    projects[idx] = project.copyWith(
      watermarkRemoved: true,
      watermarkRemovedByDomain: viaDomain,
      watermarkRemovedByMiniPackage: viaMiniPackage,
      code: WatermarkService.strip(project.code),
      files: WatermarkService.stripFromFiles(project.files),
      updatedAt: DateTime.now(),
    );
    // 06.09.2026 eklendi — SADECE gerçek/kalıcı satın almada (ne domain ne
    // mini paket yan etkisi) worker'a bildir; viaDomain/viaMiniPackage true
    // ise BİLEREK atlanır (geçici kaldırma, süresi dolunca sweep zaten geri
    // ekleyecek — bkz. WatermarkSyncService dokümanı).
    if (!viaDomain && !viaMiniPackage) {
      unawaited(WatermarkSyncService.markPermanent(siteId: id).catchError((_) {}));
    }

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
    // 04.09.2026 değiştirildi — ARTIK `await` ediliyor (önceden unawaited
    // idi). Yayınlama, kullanıcının "işim bitti" dediği kritik an: publish
    // sheet zaten bu çağrının bitmesini bekliyor (bkz. publish_sheet.dart >
    // `await widget.onPublished(...)`), yani ekstra bir bekleme hissi
    // yaratmıyoruz ama uygulamanın bu noktadan SONRA (örn. hemen kapatılıp
    // silinmesi) proje verisini bulutta kaybetme riskini ortadan kaldırıyor.
    // Bulut o an ulaşılamazsa (internet yok vb.) sync başarısız kuyruğa
    // (_pendingProjectSync) düşer, bir sonraki girişte otomatik tekrar
    // denenir — kullanıcı akışı yine de bloklanmaz/hataya düşmez.
    await _syncProjectToCloudIfSignedIn(projects[idx]);
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

  /// domain_connect_screen.dart, ödemeyi ALDIKTAN (showDomainPurchaseSheet
  /// `true` döndürdükten) hemen SONRA, worker'a DomainService.connect
  /// isteği atılmadan ÖNCE çağırır — bu satın alma HAKKININ bir yere
  /// (SharedPreferences) yazılmasını sağlar, böylece uygulama tam bu
  /// aradayken kapanırsa/çökerse bile ödeme kaybolmaz: kullanıcı ekranı
  /// tekrar açtığında hasPendingDomainConnectPurchase true kalır ve
  /// tekrar ödeme istenmeden doğrudan bağlanma denenir.
  Future<void> markDomainConnectPurchased(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(domainConnectPurchasePending: true);
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

  /// domain_connect_screen.dart > _connect, "Bağla"ya basıldığında
  /// showDomainPurchaseSheet'i tekrar açıp açmayacağına bunun sonucuna göre
  /// karar verir: true dönerse (önceki bir ödeme worker'a hiç ulaşmadan/
  /// başarısız kalmış demektir) satın alma sheet'i ATLANIR, doğrudan
  /// DomainService.connect tekrar denenir — kullanıcı İKİNCİ KEZ ödeme
  /// yapmaz (bkz. SiteProject.domainConnectPurchasePending dokümantasyonu).
  bool hasPendingDomainConnectPurchase(String projectId) {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].domainConnectPurchasePending;
  }

  /// `markDomainConnectPurchased` ile BİREBİR AYNI gerekçe, "Uzat" akışı
  /// için: domain_connect_screen.dart > _renew, ödemeyi ALDIKTAN hemen
  /// SONRA, worker'a DomainService.renew isteği atılmadan ÖNCE çağırır.
  Future<void> markDomainRenewPurchased(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(domainRenewPurchasePending: true);
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

  /// `hasPendingDomainConnectPurchase` ile BİREBİR AYNI gerekçe, "Uzat"
  /// akışı için — true dönerse domain_connect_screen.dart > _renew satın
  /// alma sheet'ini ATLAYIP doğrudan DomainService.renew'i tekrar dener.
  bool hasPendingDomainRenewPurchase(String projectId) {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].domainRenewPurchasePending;
  }

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
      // Bu metod DomainService.connect() worker'a BAŞARIYLA ulaştıktan
      // sonra çağrılıyor (bkz. domain_connect_screen.dart > _connect) —
      // yani ödenmiş hak artık kullanıldı, bekleyen bir "ödendi ama
      // bağlanmadı" durumu kalmadı (bkz. markDomainConnectPurchased).
      domainConnectPurchasePending: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));

    // 05.09.2026 eklendi — kProductConnectDomain satın alma akışı kuruldu
    // (bkz. widgets/domain_purchase_sheet.dart). En baştaki ürün kararı
    // (bkz. DEGISIKLIKLER_05_09_2026.md üst bağlam notu) buydu: "domain
    // bağladığı SİTESİ için kilitler açılacak + rozet OTOMATİK kalkacak" —
    // yani kullanıcı domain paketini bu proje için satın alıp bağlantı
    // gerçekten 'active' olduğunda ayrıca "Rozeti Kaldır"ı da satın almak
    // ZORUNDA kalmamalı. removeWatermarkForProject zaten watermarkRemoved
    // true ise no-op olduğundan bunu SADECE isNewActivation true iken
    // çağırmak (her polling turunda gereksiz yere çağırmamak için) yeterli
    // güvenli — ama aynı zamanda idempotent olduğu için tekrar çağrılsa da
    // zararsız. ÖNEMLİ: bu, watermarkRemoved'ı KALICI olarak true yapar —
    // domain daha sonra süresi dolup sökülse bile (bkz. isPremium/
    // isDomainExpired) rozet GERİ GELMEZ, tıpkı ayrı satın alındığında
    // olduğu gibi (bkz. removeWatermarkForProject dokümantasyonu: "Geri
    // alma yoktur"). Diğer premium kilitler (Talep Kutusu, galeri, harita,
    // vb.) ise bundan FARKLI olarak isPremium'a bağlı kalmaya devam eder —
    // domain süresi dolarsa onlar tekrar kilitlenir.
    //
    // 05.09.2026 GÜNCELLENDİ (kanka kararı) — rozet ARTIK kalıcı DEĞİL:
    // "Ödediği para 1 yıl için geçerliydi, süre dolunca ücretsiz katmana
    // düşer" kararıyla, domain paketinin verdiği rozet kaldırma diğer
    // premium alanlarla AYNI mantığa uydurulur — viaDomain:true ile
    // işaretlenir, süre dolunca revertExpiredDomainWatermarks tarafından
    // geri alınır (bkz. SiteProject.watermarkRemovedByDomain).
    if (isNewActivation) {
      await removeWatermarkForProject(id, viaDomain: true);
    }
  }

  /// 05.09.2026 eklendi (kanka kararı) — "Domain süresi dolunca rozet geri
  /// gelsin, çünkü ücretsiz katmana düşüyor" ürün kararının uygulaması.
  ///
  /// Hesap içindeki TÜM projeleri tarar; bir proje için rozet kaldırma
  /// SADECE domain paketinin yan etkisiyle verilmişse (watermarkRemovedByDomain
  /// true) VE o domain artık süresi dolmuşsa (isDomainExpired true), rozeti
  /// [WatermarkService.apply]/[applyToFiles] ile içeriğe GERİ enjekte eder
  /// ve bayrakları sıfırlar. Kullanıcı rozeti AYRICA (gerçek parayla) satın
  /// almışsa (watermarkRemovedByDomain=false) BU FONKSİYON O PROJEYE
  /// DOKUNMAZ — o kaldırma kalıcıdır.
  ///
  /// Çağrı noktaları: uygulama açılışında (_loadFromPrefs sonunda) ve proje
  /// listesi/domain ekranı gibi kullanıcının bu durumu göreceği yerlerde —
  /// böylece süresi dolmuş bir domain'in rozeti, uygulama tekrar
  /// açıldığında veya ilgili ekran ziyaret edildiğinde geri gelmiş olur.
  Future<void> revertExpiredDomainWatermarks() async {
    var changed = false;
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      if (p.watermarkRemoved && p.watermarkRemovedByDomain && p.isDomainExpired) {
        projects[i] = p.copyWith(
          watermarkRemoved: false,
          watermarkRemovedByDomain: false,
          code: WatermarkService.apply(p.code, isEnglish: isEnglish),
          files: WatermarkService.applyToFiles(p.files, isEnglish: isEnglish),
          updatedAt: DateTime.now(),
        );
        // Bu proje o an ekrandaki Hızlı Araçlar slotunda açıksa, kullanıcı
        // bir şey yapmadan rozetin geri döndüğünü ANINDA görsün.
        if (qtCurrentProjectId == p.id) {
          qtGeneratedCode = WatermarkService.apply(qtGeneratedCode, isEnglish: isEnglish);
          qtGeneratedFiles = WatermarkService.applyToFiles(qtGeneratedFiles, isEnglish: isEnglish);
          unawaited(_writeLargeData(_qtGeneratedCodeFile, qtGeneratedCode));
          unawaited(_writeLargeData(_qtGeneratedFilesFile, jsonEncode(qtGeneratedFiles)));
        }
        unawaited(_syncProjectToCloudIfSignedIn(projects[i]));
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _persistProjects();
    }
  }

  // ------------------------------------------------------------------
  // "1 AYLIK MİNİ PAKET" — SATIN ALMA SONRASI ÇAĞRILACAK TEK NOKTA
  // ------------------------------------------------------------------
  // 05.09.2026 eklendi (kanka isteği). kProductMiniPackage satın alındığında
  // çağrılır — kProductConnectDomain'in KISA SÜRELİ (1 ay, 1 yıl değil) ve
  // İNDİRME HAKKI VERMEYEN versiyonu: rozeti kaldırır + diğer premium
  // kilitleri (Talep Kutusu, tam galeri, harita, talep formu, Google yorum
  // butonu, ziyaretçi sayısı — bkz. SiteProject.isPremium) açar, ama
  // downloadPurchased'a HİÇ dokunmaz — indirmek isteyen kullanıcı yine
  // kProductDownloadWatermarked/kProductDownloadNoWatermark'ı AYRICA satın
  // almalıdır (bkz. canDownloadFreely, unlockDownloadForProject).
  //
  // markProjectDomainStatus'taki isNewActivation mantığının AYNISI burada
  // gerekmiyor çünkü bu metod SADECE gerçek bir satın alma sonucunda
  // çağrılır (polling yok) — her çağrı YENİ bir 1 aylık süre başlatır
  // (kullanıcı süre dolmadan tekrar satın alırsa bile mevcut süreyi
  // sıfırdan 1 aya uzatır, bu bilinçli bir ürün kararı: "yenileme" = yeni
  // satın alma).
  Future<void> activateMiniPackage(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(
      miniPackageActivatedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));

    // 06.09.2026 eklendi (kanka isteği) — worker'daki D1'e de yaz ki
    // premiumDowngradeSweep süresi dolunca canlı R2 içeriğini gerçekten
    // ücretsiz katmana indirebilsin (bkz. MiniPackageService dokümanı).
    // BEST-EFFORT: site henüz yayınlanmadıysa ya da internet yoksa bu satır
    // sessizce başarısız olur, aktivasyonun geri kalanını ETKİLEMEZ.
    unawaited(MiniPackageService.activate(siteId: id).catchError((_) {}));

    // 06.09.2026 eklendi (kanka isteği) — domain yenileme hatırlatmasıyla
    // AYNI desen (bkz. NotificationService.scheduleDomainRenewalReminder):
    // süre dolmadan 7 gün önce bir uyarı + bitiş gününde bir "süresi
    // doldu" bildirimi. NOT: BİLEREK try/catch içinde — bir hatırlatma
    // kurulamaması mini paket aktivasyonunun (rozet kaldırma, persist)
    // kendisini ASLA "başarısız" göstermemeli.
    try {
      final expiresAt = projects[idx].miniPackageExpiresAt;
      if (expiresAt != null) {
        await NotificationService.instance.scheduleMiniPackageExpiryReminder(
          projectId: id,
          expiresAt: expiresAt,
        );
      }
    } catch (_) {
      // NotificationService kendi içinde zaten hataları yutuyor; bu sadece
      // ekstra güvenlik katmanı.
    }

    // Rozeti de kaldır — removeWatermarkForProject zaten watermarkRemoved
    // true ise no-op olduğundan (ör. proje zaten domain paketiyle rozetsizse)
    // güvenle her seferinde çağrılabilir. viaMiniPackage:true olduğu için
    // BU kaldırma, mini paketin süresi dolduğunda (bkz.
    // revertExpiredMiniPackages) geri alınabilir — kalıcı DEĞİLDİR.
    await removeWatermarkForProject(id, viaMiniPackage: true);
  }

  /// 05.09.2026 eklendi (kanka isteği) — "Mini paketin süresi dolunca
  /// dolunca rozet + diğer kilitler geri gelsin, yenilenmezse ücretsiz
  /// katmana düşsün" ürün kararının uygulaması. revertExpiredDomainWatermarks
  /// ile AYNI desen, sadece domain yerine mini paket süresine bakar.
  ///
  /// Diğer premium kilitler (Talep Kutusu, galeri, harita, talep formu vb.)
  /// AYRICA bir "geri alma" gerektirmez — onlar isPremium'dan CANLI olarak
  /// okunur (bkz. SiteProject.isPremium), miniPackageActivatedAt süresi
  /// dolduğunda isMiniPackageActive zaten kendiliğinden false döner. SADECE
  /// rozet BURADA ayrıca ele alınıyor çünkü o, üretim anında HTML içine
  /// GÖMÜLÜYOR — geri almak için içeriği yeniden yazmak gerekiyor.
  ///
  /// Çağrı noktaları: revertExpiredDomainWatermarks ile AYNI yerler
  /// (uygulama açılışında _loadFromPrefs sonunda).
  Future<void> revertExpiredMiniPackages() async {
    var changed = false;
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      if (p.watermarkRemoved && p.watermarkRemovedByMiniPackage && p.isMiniPackageExpired) {
        projects[i] = p.copyWith(
          watermarkRemoved: false,
          watermarkRemovedByMiniPackage: false,
          code: WatermarkService.apply(p.code, isEnglish: isEnglish),
          files: WatermarkService.applyToFiles(p.files, isEnglish: isEnglish),
          updatedAt: DateTime.now(),
        );
        // Bu proje o an ekrandaki Hızlı Araçlar slotunda açıksa, kullanıcı
        // bir şey yapmadan rozetin geri döndüğünü ANINDA görsün.
        if (qtCurrentProjectId == p.id) {
          qtGeneratedCode = WatermarkService.apply(qtGeneratedCode, isEnglish: isEnglish);
          qtGeneratedFiles = WatermarkService.applyToFiles(qtGeneratedFiles, isEnglish: isEnglish);
          unawaited(_writeLargeData(_qtGeneratedCodeFile, qtGeneratedCode));
          unawaited(_writeLargeData(_qtGeneratedFilesFile, jsonEncode(qtGeneratedFiles)));
        }
        unawaited(_syncProjectToCloudIfSignedIn(projects[i]));
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _persistProjects();
    }
  }

  /// Kullanıcı süresi dolmuş/dolmak üzere olan bir domain'i "yenile"diğinde
  /// çağrılır (bkz. DomainConnectScreen "Yenile" butonu). 05.09.2026
  /// GÜNCELLENDİ (kanka kararı) — bu artık ÜCRETSİZ değil: bu metod
  /// çağrılmadan ÖNCE domain_connect_screen.dart > _renew, kProductConnectDomain'i
  /// (bkz. billing_constants.dart) tekrar satın alıp
  /// markDomainRenewPurchased ile ödemeyi persist etmiş OLMALI — _connect'teki
  /// ÇİFTE ÖDEME KORUMASI deseninin AYNISI (bkz. domainRenewPurchasePending).
  /// Bu metodun kendisi ödeme yapmaz/kontrol etmez, SADECE ödeme onaylandıktan
  /// sonra worker'a `/renew` isteğini atar.
  ///
  /// ÖNCE worker'a POST /api/domains/:siteId/renew çağrısı atılır (bkz.
  /// DomainService.renew) — süre worker tarafında GERÇEKTEN uygulandığı için
  /// (serveCustomDomainSite süresi dolmuş domain'leri artık servis etmiyor),
  /// istemci tarafındaki sayacı worker'a hiç sormadan sıfırlamak, kullanıcıya
  /// "uzatıldı" gösterip aslında sitesinin hâlâ erişilemez kalmasına yol
  /// açardı. İstek başarısız olursa (örn. internet yok) exception yukarı
  /// fırlatılır, çağıran taraf (DomainConnectScreen._renew) bunu yakalayıp
  /// kullanıcıya hata gösterir — bu durumda yerel tarih DEĞİŞTİRİLMEZ VE
  /// domainRenewPurchasePending true KALIR (ödeme kaybolmaz, bir sonraki
  /// "Uzat" denemesinde satın alma sheet'i tekrar açılmaz).
  Future<void> renewProjectDomain(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final result = await DomainService.renew(siteId: id);
    final refreshedIdx = projects.indexWhere((p) => p.id == id);
    if (refreshedIdx == -1) return;
    projects[refreshedIdx] = projects[refreshedIdx].copyWith(
      domainConnectedAt: result.domainConnectedAt,
      // Worker'a başarıyla ulaşıldı — ödenmiş hak artık kullanıldı, bekleyen
      // bir "ödendi ama worker'a ulaşmadı" durumu kalmadı (bkz.
      // markDomainRenewPurchased). Bir sonraki yenileme YENİDEN satın
      // alınmalı.
      domainRenewPurchasePending: false,
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
