import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/site_project.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/watermark_service.dart';
import '../services/free_plan_restriction_service.dart';
import '../services/hosting_service.dart';
import '../services/google_verification_service.dart';
import '../services/domain_service.dart';
import '../services/transfer_service.dart';
import '../services/activation_retry.dart';
import '../services/mini_package_service.dart';
import '../services/subscription_service.dart';
import '../services/subscription_quota_sync_service.dart';
import '../services/watermark_sync_service.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import '../services/server_time_service.dart';
import '../constants/billing_constants.dart';

/// Üretim modu:
/// - single (A modu): tek `.html` dosyası — biolink/kartvizit, hızlı indirme.
/// - multi  (B modu): birden fazla bağlantılı sayfa — zip olarak indirilir,
///   kullanıcı istediği hosting'e yükler.
enum SiteMode { single, multi }

/// [AppState.claimTransferredProject] sonucu — 16.09.2026 eklendi.
/// Devralınan proje BİLGİSİNİN yanında, ekranın kullanıcıya watermark/
/// abonelik durumunu AÇIKÇA anlatabilmesi için [premiumLost] bayrağını
/// da taşır (bkz. claimTransferredProject dokümanı).
class TransferClaimOutcome {
  final SiteProject project;
  final bool premiumLost;

  /// 16.09.2026 eklendi (kanka isteği — "domain devirde kaybolmasın"
  /// akışı) — worker'ın domainOutcome'u ('kept_via_subscription' |
  /// 'kept_via_purchase' | 'stripped' | 'not_applicable') OLDUĞU GİBİ
  /// buraya taşınır, ekran bunu kullanıcıya doğru mesajı göstermek için
  /// kullanır (bkz. projects_screen.dart > _claimTransferCode).
  final String domainOutcome;

  const TransferClaimOutcome({
    required this.project,
    required this.premiumLost,
    this.domainOutcome = 'not_applicable',
  });
}

/// Sitora uygulamasının merkezi durumu.
/// Üretilen site kodu ve seçilen görselleri tutar.
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

  // --- WORKER AKTİVASYON KUYRUĞU (20.09.2026 eklendi, kanka isteği) ---
  // Mini paket aktivasyonu ve kalıcı rozet kaldırma, worker'ın sıkı modunda
  // doğrulanmış bir satın alma KREDİSİ harcar. İstek ağ hatasıyla düşerse kredi
  // harcanmadan bekliyordu ama istemci ikinci bir deneme yapmıyordu (çağrı
  // `unawaited` + hatayı yut idi) — kullanıcı ödemiş, worker/canlı site
  // bilmiyordu. Artık her istek ÖNCE buraya (cihazda kalıcı) yazılır, sonra
  // denenir; başarılı olana ya da tekrar denemenin anlamsız olduğu bir
  // cevap gelene (bkz. SyncRetry.never) kadar kuyrukta kalır. Tasarım ve
  // "neden tekrar güvenli" için bkz. lib/services/activation_retry.dart.
  static const _pendingActivationsPrefsKey = 'pending_worker_activations_v1';

  /// Kuyrukta bu kadar bekleyen kayıttan vazgeçilir (ör. site hiç
  /// yayınlanmadığı için hep 404 dönüyorsa açılışta sonsuza dek denenmesin).
  static const Duration _activationMaxAge = Duration(days: 30);

  /// Uygulama AÇIKKEN geçici arıza (SyncRetry.soon) sonrası bekleme süreleri
  /// (toplam ~4,5 dk). Bundan sonrası kuyrukta kalır; bir sonraki tetik
  /// (uygulama açılışı, giriş, site yayınlama) yeniden dener.
  static const List<Duration> _activationRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 20),
    Duration(seconds: 60),
    Duration(seconds: 180),
  ];

  // "tür|siteId" -> kayıt. Aynı tür + site için tek kayıt tutulur.
  final Map<String, PendingActivation> _pendingActivations = {};
  bool _flushingActivations = false;
  bool _activationFlushRequested = false;

  // --- "SİTEYİ DEVRET" — OTOMATİK KOTA SERBEST BIRAKMA (16.09.2026 eklendi,
  // kanka isteği: bkz. proje sohbeti/ekran görüntüleri) ---
  // ÖNCEDEN initiateProjectTransfer'ın ürettiği kod HİÇBİR YERE
  // kaydedilmiyordu — sadece bir dialogda GÖSTERİLİYORDU. Müşteri kodu
  // kullanıp siteyi devraldığında (bkz. worker > handleTransferClaim), eski
  // sahibin CİHAZI bundan haberdar olmuyor, site Projelerim'de "hâlâ
  // benimmiş gibi" görünmeye devam edip site/domain kotasını GEREKSİZ YERE
  // işgal ediyordu — kullanıcı ELLE "Sil"e basana kadar. Bu map, ÜRETİLEN
  // her devir kodunu siteId'siyle eşleyip kalıcı tutar (JSON,
  // SharedPreferences — küçük veri, ayrı bir dosyaya gerek yok, bkz.
  // _projectsFile'ın AKSİNE) — bkz. checkPendingTransferClaims: bu kayıtlar
  // üzerinden worker'a "durumu ne?" diye sorulur (handleTransferStatus,
  // KODU TÜKETMEZ), 'claimed' dönerse proje kendi deleteProject'iyle yerel
  // listeden düşürülür (kota otomatik serbest kalır).
  static const _pendingTransferCodesPrefsKey = 'pending_transfer_codes_v1';
  // siteId -> {'code': ..., 'expiresAt': ISO8601}
  final Map<String, Map<String, String>> _pendingTransferCodes = {};

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
  // ayarlar (bayrak, aktif dosya adı, proje id'si vb.) kalıyor.
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
  // giftPublishCredits ile AYNI ayrım — settings_sheet.dart >
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
  // giftPublishCredits ile AYNI desen: admin panelinden
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
  ///
  /// 15.09.2026 GÜNCELLENDİ (kanka isteği) — aylık abonelik kotası da
  /// (bkz. yukarıdaki "AYLIK ABONELİK" bölümü) ÜCRETSİZ bir yol: proje
  /// zaten kota içindeyse VEYA hesabın boş bir slotu varsa true döner —
  /// aboneliği olan bir kullanıcı AYRICA yayın hakkı satın almak zorunda
  /// KALMAMALI.
  bool canPublishProject(SiteProject project) {
    if (project.publishRightGranted) return true;
    if (project.subscriptionQuotaExpiresAt != null) return true;
    final tier = activeSubscriptionTier;
    if (tier != null && subscriptionQuotaUsed < tier.siteQuota) return true;
    if (!freeSitePublishUsed) return true;
    return (giftPublishCredits + extraPublishCredits) > 0;
  }

  /// [project] YENİ yayınlanmadan hemen ÖNCE (ilk kez `isPublished` true
  /// olacaksa) çağrılmalı — bkz. preview_screen.dart > _publishSite. Bu
  /// proje zaten hakkını kullanmışsa (publishRightGranted true VEYA zaten
  /// abonelik kotasında) HİÇBİR ŞEY yapmadan çıkar (idempotent), yani
  /// markProjectPublished içinden her yayınlamada güvenle çağrılabilir.
  ///
  /// Harcama sırası: önce aylık ABONELİK kota slotu (zaten aylık ödeniyor,
  /// bkz. assignProjectToSubscriptionQuota — 15.09.2026 eklendi, kanka
  /// isteği), sonra ücretsiz ilk hak, sonra HEDİYE yayın hakkı (kullanıcının
  /// PARA ÖDEMEDİĞİ bakiye), en son satın alınan yayın hakkı
  /// (extraPublishCredits).
  Future<void> grantPublishRight(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1 || projects[idx].publishRightGranted) return;
    if (projects[idx].subscriptionQuotaExpiresAt != null) return;

    if (await assignProjectToSubscriptionQuota(projectId)) return;

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

  // ------------------------------------------------------------------
  // AYLIK ABONELİK (Mini / Freelancer / Freelancer Max) — 15.09.2026
  // eklendi (kanka isteği). bkz. billing_constants.dart dosya başı,
  // billing_service.dart > buySubscription, cloudflare/worker/src/index.mjs
  // > handleVerifySubscription/handleSubscriptionStatus, schema.sql >
  // subscriptions tablosu.
  // ------------------------------------------------------------------
  // HESAP BAZLI (site bazlı DEĞİL) — publishRightGranted/extraPublishCredits
  // gibi PROJEYE kalıcı olarak bağlanan haklardan FARKLI olarak, "hangi
  // projeler o anki abonelik kotasının içinde" sorusu HER ZAMAN canlı
  // olarak SiteProject.subscriptionQuotaExpiresAt'ten okunur (bkz.
  // subscriptionQuotaProjects) — TEK doğruluk kaynağı worker'daki D1
  // `subscriptions` tablosudur, buradaki iki alan sadece bir ÖNBELLEKTİR
  // (uygulama açılışında/girişte refreshSubscriptionStatus ile tazelenir).
  static const _activeSubscriptionProductIdPrefsKey = 'active_subscription_product_id';
  static const _activeSubscriptionExpiresAtPrefsKey = 'active_subscription_expires_at';
  String? activeSubscriptionProductId;
  DateTime? activeSubscriptionExpiresAt;

  /// Aktif paketin sabit bilgileri (kota vb.) — abonelik yoksa/süresi
  /// dolmuşsa null.
  SubscriptionTierInfo? get activeSubscriptionTier {
    if (!hasActiveSubscription) return null;
    return kSubscriptionTierByProductId[activeSubscriptionProductId];
  }

  /// Hesabın ŞU AN geçerli (satın alınmış VE süresi dolmamış) bir aboneliği
  /// var mı — isMiniPackageActive/isDomainConnected'daki AYNI clock-skew
  /// gerekçesi (ServerTimeService).
  bool get hasActiveSubscription =>
      activeSubscriptionProductId != null &&
      activeSubscriptionExpiresAt != null &&
      ServerTimeService.now().isBefore(activeSubscriptionExpiresAt!);

  /// O an abonelik kota slotuna atanmış (subscriptionQuotaExpiresAt != null)
  /// TÜM projeler — süresi dolmuş olsa BİLE listede kalır (geri alma işi
  /// revertExpiredSubscriptionQuota'nındır, burada SADECE "atanmış mı"
  /// sorusuna bakılır).
  List<SiteProject> get subscriptionQuotaProjects =>
      projects.where((p) => p.subscriptionQuotaExpiresAt != null).toList();

  /// Şu an kaç kota slotu kullanılıyor.
  int get subscriptionQuotaUsed => subscriptionQuotaProjects.length;

  /// Kota, hesabın o anki paketinden DAHA FAZLA site tutuyor mu (paket
  /// düşürüldü ya da abonelik süresi dolup yenilenmedi) — bu true olduğu
  /// sürece UI kullanıcıya HANGİ site(ler)in kota içinde kalacağını
  /// seçtirmeli (bkz. dosya başı "KOTA AŞIMI DAVRANIŞI" kararı, ileride
  /// eklenecek quota_overflow_picker_sheet.dart). Abonelik TAMAMEN
  /// bitmişse (hasActiveSubscription false) hedef kota 0 kabul edilir —
  /// yani kota içinde tek bir site bile varsa bu true döner.
  bool get hasSubscriptionQuotaOverflow =>
      subscriptionQuotaUsed > (activeSubscriptionTier?.siteQuota ?? 0);

  // ------------------------------------------------------------------
  // ABONELİK DOMAIN KOTASI — 16.09.2026 eklendi (kanka isteği: "domainQuota
  // tanımlı ama kullanılmıyor" bulgusu). siteQuota'nın domain karşılığı:
  // her paket "X site + X siteye özel domain" vaat ediyor (bkz.
  // billing_constants.dart), ama domain_connect_screen.dart bugüne kadar
  // buna HİÇ bakmıyordu — abonesi olan biri bile domain bağlamak için
  // eski tek seferlik ücreti (kProductConnectDomain) ödemek zorunda
  // kalıyordu. Aşağıdaki üç üye, subscriptionQuotaProjects/subscriptionQuotaUsed
  // ile AYNI desen — SiteProject.domainViaSubscription TEK doğruluk kaynağı,
  // burası sadece onun üzerinden sayar.
  // ------------------------------------------------------------------
  List<SiteProject> get domainQuotaProjects =>
      projects.where((p) => p.domainViaSubscription).toList();

  int get domainQuotaUsed => domainQuotaProjects.length;

  /// 16.09.2026 eklendi (kanka isteği — DEGISIKLIKLER_16_09_2026_DOMAIN_KOTA_
  /// BILINCLI_EKLENDI.md > madde 2) — hasSubscriptionQuotaOverflow ile
  /// BİREBİR AYNI desen, domain kotası için: paket düşürüldüğünde ya da
  /// abonelik süresi dolup yenilenmediğinde, hesabın domainQuotaProjects'i
  /// o anki paketin domainQuota'sından FAZLA olursa true döner. UI
  /// (home_screen.dart bannerı + domain_quota_overflow_picker_sheet.dart)
  /// bu true olduğu sürece kullanıcıya HANGİ domain(ler)in bağlı kalacağını
  /// seçtirmeli — seçilmeyenler GERÇEKTEN sökülür (bkz. o sheet'in dosya
  /// başı dokümanı — rozet kotası aşımından FARKI budur).
  bool get hasDomainQuotaOverflow =>
      domainQuotaUsed > (activeSubscriptionTier?.domainQuota ?? 0);

  /// [project] için ÜCRETSİZ (kProductConnectDomain ödemeden) domain
  /// bağlanabilir mi — proje zaten bir abonelik domain slotuna sahipse
  /// (domainViaSubscription) VEYA hesabın boş bir domain slotu varsa true.
  /// domain_connect_screen.dart > _connect bu kontrolle satın alma
  /// sheet'ini ATLAYIP ATLAMAYACAĞINA karar verir.
  bool canConnectDomainViaSubscription(SiteProject project) {
    if (project.domainViaSubscription) return true;
    final tier = activeSubscriptionTier;
    if (tier == null) return false;
    return domainQuotaUsed < tier.domainQuota;
  }

  /// [projectId] için bir domain kota slotu ayırmaya ÇALIŞIR —
  /// assignProjectToSubscriptionQuota ile AYNI desen. true dönerse çağıran
  /// taraf (domain_connect_screen.dart) satın alma sheet'ini ATLAYIP
  /// doğrudan DomainService.connect'e geçebilir. Rozete/kilitlere HİÇ
  /// dokunmaz — onlar zaten subscriptionQuotaExpiresAt/site-quota
  /// üzerinden yönetiliyor (bkz. SiteProject.domainViaSubscription dokümanı).
  Future<bool> assignDomainQuota(String projectId) async {
    final tier = activeSubscriptionTier;
    if (tier == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    if (projects[idx].domainViaSubscription) return true; // zaten atanmış
    if (domainQuotaUsed >= tier.domainQuota) return false;

    projects[idx] = projects[idx].copyWith(domainViaSubscription: true, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));

    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(SubscriptionQuotaSyncService.assignDomain(siteId: projectId, uid: uid, ownerToken: projects[idx].ownerToken).catchError((_) {}));
    }
    return true;
  }

  /// [projectId]'nin domain kota slotunu KALDIRIR. [alsoDisconnect] true
  /// ise (varsayılan) domain'in kendisini de GERÇEKTEN söker (worker'a
  /// DomainService.disconnect ile) — bu domain hiçbir zaman STANDALONE
  /// ödenmediği için, kota bittiğinde canlı kalmaya devam etmesi bir
  /// kaçaktır (bkz. schema.sql > subscription_domain_uid dokümanı). Sadece
  /// kota kaydını temizleyip domain'i canlı bırakmak istenen TEK durum:
  /// kullanıcı tam o anda AYRICA (gerçek parayla) domain satın alıyorsa —
  /// o akış zaten kendi customDomain/domainConnectedAt'ini yeniden yazacağı
  /// için burada [alsoDisconnect]: false ile çağrılabilir.
  Future<void> unassignDomainQuota(String projectId, {bool alsoDisconnect = true}) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1 || !projects[idx].domainViaSubscription) return;
    projects[idx] = projects[idx].copyWith(domainViaSubscription: false, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
    unawaited(SubscriptionQuotaSyncService.unassignDomain(siteId: projectId, ownerToken: projects[idx].ownerToken).catchError((_) {}));

    if (alsoDisconnect) {
      try {
        await DomainService.disconnect(siteId: projectId, ownerToken: projects[idx].ownerToken);
      } catch (_) {
        // best-effort — worker'daki günlük abonelik-domain sweep'i zaten
        // aynı işi bir sonraki taramada tekrar dener (bkz. premiumDowngradeSweep).
      }
      await clearProjectDomain(projectId);
    }
  }

  /// [otomatik seç] — domain kotası için autoResolveSubscriptionQuotaOverflow
  /// ile BİREBİR AYNI desen (16.09.2026 eklendi, kanka isteği: domain
  /// sheet'ine de site sheet'indeki "seçim yapılmadan kapatılırsa otomatik
  /// söktür" davranışı eklendi). EN YENİ bağlanan `allowed` kadar domain'i
  /// kota içinde tutar; geri kalan (yani İLK/en eski bağlanan fazlalık
  /// domain'ler) unassignDomainQuota (alsoDisconnect: true — varsayılan)
  /// ile GERÇEKTEN söktürülür. Site tarafındaki fark: burada site YAYINDAN
  /// KALKMAZ, sadece o domain'in bağlantısı kopar (bkz. dosya başı
  /// domain_quota_overflow_picker_sheet.dart dokümanı).
  ///
  /// Kota zaten aşılmamışsa (hasDomainQuotaOverflow false) no-op'tur ve boş
  /// liste döner. Döndürdüğü liste, GERÇEKTEN sökülen domain'lerin site
  /// isimleridir (çağıran taraf bunu kullanıcıya özetlemek için kullanabilir).
  Future<List<String>> autoResolveDomainQuotaOverflow() async {
    final allowed = activeSubscriptionTier?.domainQuota ?? 0;
    final quota = domainQuotaProjects;
    if (quota.length <= allowed) return const [];

    // En yeni bağlanan `allowed` kadarı kalsın diye EN ESKİ bağlanandan
    // başlayarak sırala — baştaki fazlalık kadarı (en eski domain'ler)
    // sökülür. domainConnectedAt boşsa (teoride olmamalı) o proje "en eski"
    // kabul edilir — güvenli taraf, autoResolveSubscriptionQuotaOverflow'daki
    // AYNI gerekçe.
    final sorted = [...quota]..sort(
        (a, b) => (a.domainConnectedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.domainConnectedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    final excessCount = sorted.length - allowed;
    final toRemove = sorted.take(excessCount).toList();

    final removedNames = <String>[];
    for (final p in toRemove) {
      removedNames.add(p.name);
      await unassignDomainQuota(p.id);
    }
    return removedNames;
  }

  /// Worker'daki `/api/subscription-status`u sorup yerel önbelleği tazeler.
  /// Çağrı noktaları: uygulama açılışı (_loadFromPrefs sonunda), giriş
  /// yapıldığında (_onAuthChanged) ve bir satın alma UI'ı `buySubscription`
  /// `true` döndürdüğünde — worker'a zaten `/api/verify-subscription` ile
  /// YAZILMIŞ olması gerekir (bkz. billing_service.dart), o çağrı bu
  /// metoddan ÖNCE tamamlanmış olur çünkü aynı satın alma akışının bir
  /// parçasıdır.
  ///
  /// Giriş yapılmamışsa (misafir) HİÇBİR ŞEY yapmaz — abonelik HESAP
  /// bazlı olduğu için misafir modda anlamsızdır.
  Future<void> refreshSubscriptionStatus() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final status = await SubscriptionService.fetchStatus(uid);
    // null: ağ/sunucu hatası — GÜVENLİ TARAF (bkz. SubscriptionService
    // dokümanı): mevcut yerel durumu DEĞİŞTİRME, sessizce çık.
    if (status == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (!status.active) {
      activeSubscriptionProductId = null;
      activeSubscriptionExpiresAt = null;
      await prefs.remove(_activeSubscriptionProductIdPrefsKey);
      await prefs.remove(_activeSubscriptionExpiresAtPrefsKey);
    } else {
      activeSubscriptionProductId = status.productId;
      activeSubscriptionExpiresAt = status.expiresAt;
      if (status.productId != null) {
        await prefs.setString(_activeSubscriptionProductIdPrefsKey, status.productId!);
      }
      if (status.expiresAt != null) {
        await prefs.setString(
            _activeSubscriptionExpiresAtPrefsKey, status.expiresAt!.toIso8601String());
      }
    }
    _syncAnalyticsUserProperties();
    notifyListeners();
    await _reconcileSubscriptionQuota();
  }

  /// [projectId] için bir kota slotu ayırmaya ÇALIŞIR — hesabın aktif bir
  /// aboneliği VE boş bir slotu varsa (ya da proje zaten atanmışsa) true
  /// döner, rozeti kaldırır/kilitleri açar. Slot yoksa (kota dolu ya da
  /// abonelik yok) false döner — çağıran taraf (grantPublishRight) bu
  /// durumda normal (ücretli/ücretsiz) akışa devam etmeli.
  Future<bool> assignProjectToSubscriptionQuota(String projectId) async {
    final tier = activeSubscriptionTier;
    if (tier == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    if (projects[idx].subscriptionQuotaExpiresAt != null) return true; // zaten atanmış
    if (subscriptionQuotaUsed >= tier.siteQuota) return false;

    projects[idx] = projects[idx].copyWith(
      subscriptionQuotaExpiresAt: activeSubscriptionExpiresAt,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));

    // Rozeti de kaldır — removeWatermarkForProject zaten watermarkRemoved
    // true ise no-op, viaDomain/viaMiniPackage'ın AYNI "geri alınabilir"
    // mantığı burada viaSubscription ile.
    await removeWatermarkForProject(projectId, viaSubscription: true);

    // 16.09.2026 eklendi (kanka isteği — "gerçek sorun #3" fix'i) —
    // worker'a da bildir ki premiumDowngradeSweep bu sitenin HANGİ hesabın
    // aboneliğiyle kota içinde tutulduğunu bilsin (bkz.
    // SubscriptionQuotaSyncService dokümanı). Best-effort, kota atama
    // akışını ASLA bozmaz.
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(
        SubscriptionQuotaSyncService.assign(siteId: projectId, uid: uid, ownerToken: projects[idx].ownerToken).catchError((_) {}),
      );
    }
    return true;
  }

  /// [projectId]'yi kota slotundan ÇIKARIR — quota_overflow_picker_sheet
  /// (ileride) kullanıcı "bu site kota dışında kalsın" dediğinde çağırır.
  /// Rozet/kilitler otomatik geri gelir (revertExpiredSubscriptionQuota ile
  /// AYNI etkiyi burada ANINDA uygular, süre dolmasını BEKLEMEZ).
  Future<void> unassignProjectFromSubscriptionQuota(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1 || projects[idx].subscriptionQuotaExpiresAt == null) return;
    var p = projects[idx].copyWith(subscriptionQuotaExpiresAt: null);
    if (p.watermarkRemovedBySubscription) {
      p = p.copyWith(
        watermarkRemoved: false,
        watermarkRemovedBySubscription: false,
        code: WatermarkService.apply(p.code, isEnglish: isEnglish),
        files: WatermarkService.applyToFiles(p.files, isEnglish: isEnglish),
      );
    }
    projects[idx] = p.copyWith(updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
    unawaited(SubscriptionQuotaSyncService.unassign(siteId: projectId, ownerToken: projects[idx].ownerToken).catchError((_) {}));
  }

  /// [otomatik seç] — kullanıcı hangi site(ler)in kota içinde kalacağını
  /// KENDİSİ seçmek istemediğinde quota_overflow_picker_sheet.dart'taki
  /// "Otomatik Seç" butonu tarafından çağrılır (16.09.2026 eklendi, kanka
  /// isteği — eski "Daha sonra karar ver" butonunun yerine geçti). EN YENİ
  /// yayınlanan `allowed` kadar siteyi kota içinde tutar; geri kalan (yani
  /// İLK/en eski yayınlanan fazlalık siteler) hem kota slotundan ÇIKARILIR
  /// HEM DE GERÇEKTEN yayından kaldırılır (bkz. _forceUnpublishAndUnassignQuota).
  ///
  /// Bu, billing_constants.dart > "KOTA AŞIMI DAVRANIŞI" kararındaki "hiçbir
  /// site otomatik yayından indirilmez" kuralının BİLİNÇLİ bir istisnasıdır
  /// — SADECE kullanıcı bunu kendisi (bu butona basarak) tetiklediğinde
  /// geçerlidir. Kullanıcı sheet'i seçim yapmadan kapatırsa (geri tuşu/
  /// dışarı dokunma) eski davranış AYNEN sürer: hiçbir şey değişmez.
  ///
  /// Kota zaten aşılmamışsa (hasSubscriptionQuotaOverflow false) no-op'tur
  /// ve boş liste döner. Döndürdüğü liste, GERÇEKTEN yayından kaldırılan
  /// projelerin isimleridir (çağıran taraf bunu kullanıcıya özetlemek için
  /// kullanabilir).
  Future<List<String>> autoResolveSubscriptionQuotaOverflow() async {
    final allowed = activeSubscriptionTier?.siteQuota ?? 0;
    final quota = subscriptionQuotaProjects;
    if (quota.length <= allowed) return const [];

    // En yeni yayınlanan `allowed` kadarı kalsın diye EN ESKİ yayınlanandan
    // başlayarak sırala — baştaki fazlalık kadarı (en eski siteler) kaldırılır.
    // publishedAt boşsa (teoride olmamalı, bkz. assignProjectToSubscriptionQuota
    // dokümanı) o proje "en eski" kabul edilir — güvenli taraf.
    final sorted = [...quota]..sort(
        (a, b) => (a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    final excessCount = sorted.length - allowed;
    final toRemove = sorted.take(excessCount).toList();

    final removedNames = <String>[];
    for (final p in toRemove) {
      removedNames.add(p.name);
      await _forceUnpublishAndUnassignQuota(p.id);
    }
    return removedNames;
  }

  /// [autoResolveSubscriptionQuotaOverflow] tarafından kullanılan yardımcı —
  /// bir projeyi hem GERÇEKTEN yayından kaldırır (HostingService.unpublish —
  /// deleteProject'teki AYNI gerekçeyle best-effort: worker'a ulaşılamasa
  /// bile kullanıcı akışını BLOKLAMAZ, sadece site worker'da yetim kalabilir)
  /// hem de abonelik kota slotundan çıkarır (rozet/kilitler geri gelir,
  /// worker'a bildirilir — bkz. unassignProjectFromSubscriptionQuota).
  Future<void> _forceUnpublishAndUnassignQuota(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    final p = projects[idx];
    if (p.isPublished) {
      try {
        await HostingService.unpublish(siteId: projectId, ownerToken: p.ownerToken);
      } catch (_) {
        // best-effort — bkz. deleteProject dokümanı.
      }
    }
    projects[idx] = projects[idx].copyWith(unpublish: true, updatedAt: DateTime.now());
    AnalyticsService.logSiteUnpublished(reason: 'quota');
    _syncAnalyticsUserProperties();
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
    await unassignProjectFromSubscriptionQuota(projectId);
    if (!projects.any((pp) => pp.isPublished)) {
      try {
        await NotificationService.instance.cancelDailyVisitorCheckIn();
      } catch (_) {}
    }
  }

  /// refreshSubscriptionStatus SONRASI çağrılır — kota içindeki projelerin
  /// subscriptionQuotaExpiresAt'ini YENİ abonelik bitiş tarihine TAZELER
  /// (yenileme senaryosu). Kota AŞIMI varsa (paket küçüldü/abonelik bitti)
  /// HİÇBİR PROJEYİ OTOMATİK ÇIKARMAZ — bkz. dosya başı "KOTA AŞIMI
  /// DAVRANIŞI" kararı: kullanıcı kendisi seçene kadar dokunulmaz, sadece
  /// hasSubscriptionQuotaOverflow true döner ve UI bunu bir uyarı olarak
  /// gösterebilir.
  Future<void> _reconcileSubscriptionQuota() async {
    if (!hasActiveSubscription) return; // aşım varsa bile burada BİR ŞEY YAPILMAZ
    final newExpiry = activeSubscriptionExpiresAt;
    if (newExpiry == null) return;
    var changed = false;
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      if (p.subscriptionQuotaExpiresAt != null &&
          p.subscriptionQuotaExpiresAt != newExpiry) {
        projects[i] = p.copyWith(
          subscriptionQuotaExpiresAt: newExpiry,
          updatedAt: DateTime.now(),
        );
        unawaited(_syncProjectToCloudIfSignedIn(projects[i]));
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _persistProjects();
    }
    // 16.09.2026 eklendi (kanka isteği — "gerçek bug #2" fix'i, kod
    // incelemesi bulgusu) — bkz. _backfillSubscriptionQuota dokümanı.
    await _backfillSubscriptionQuota();
  }

  /// 16.09.2026 eklendi (kanka isteği — "gerçek bug #2" fix'i, kod
  /// incelemesi bulgusu): ÖNCEDEN assignProjectToSubscriptionQuota SADECE
  /// iki yerden çağrılıyordu — grantPublishRight (bir site İLK KEZ
  /// yayınlanırken) ve claimTransferredProject (devir alınan site). Yani
  /// bir kullanıcının ZATEN yayınlanmış siteleri varken abonelik satın
  /// alması gibi en yaygın senaryoda (kimse "önce abone ol, sonra
  /// sitelerimi yayınla" sırasını izlemez) o mevcut siteler kotaya HİÇBİR
  /// ZAMAN giremiyordu — ne otomatik ne elle (böyle bir buton da yoktu).
  /// Kullanıcı parasını ödüyor ama mevcut hiçbir sitesi rozetsiz/premium
  /// olmuyordu; abonelik SADECE satın almadan SONRA ilk kez yayınlanan
  /// yeni sitelerde işe yarıyordu.
  ///
  /// _reconcileSubscriptionQuota'nın (dolayısıyla refreshSubscriptionStatus'un
  /// HER çağrısının — uygulama açılışı, giriş, satın alma sonrası) sonunda
  /// çalışır: boş kota slotu kaldığı sürece YAYINLANMIŞ ama henüz kota
  /// dışındaki projeleri, proje listesi sırasıyla (en basit/öngörülebilir
  /// kural — burada bir "öncelik" tartışması YOK, kullanıcı istemediği bir
  /// siteyi zaten quota_overflow_picker_sheet'ten çıkarabilir) slotlar
  /// dolana kadar kotaya ekler. assignProjectToSubscriptionQuota zaten
  /// idempotent VE kendi kota/abonelik kontrolünü kendi içinde yapıyor —
  /// burada sadece "hangi projeler aday" listesi süzülüp sırayla deneniyor.
  /// Yayınlanmamış projeler BİLEREK atlanır — henüz canlı olmayan bir
  /// siteye slot harcamanın kullanıcıya hiçbir görünür faydası yoktur,
  /// yayınlandığı an zaten grantPublishRight kendi payını dener.
  Future<void> _backfillSubscriptionQuota() async {
    final tier = activeSubscriptionTier;
    if (tier == null) return;
    if (subscriptionQuotaUsed >= tier.siteQuota) return;
    for (final p in projects) {
      if (subscriptionQuotaUsed >= tier.siteQuota) break;
      if (!p.isPublished) continue;
      if (p.subscriptionQuotaExpiresAt != null) continue;
      await assignProjectToSubscriptionQuota(p.id);
    }
  }

  /// Kota slotu süresi dolmuş (abonelik yenilenmemiş) projelerin rozetini/
  /// kilitlerini geri getirir — revertExpiredMiniPackages/
  /// revertExpiredDomainWatermarks ile BİREBİR AYNI desen. NOT: bu SADECE
  /// premium özellikleri geri alır, projeyi YAYINDAN KALDIRMAZ (bkz. dosya
  /// başı kararı — otomatik indirme YOK).
  Future<void> revertExpiredSubscriptionQuota() async {
    var changed = false;
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      if (p.watermarkRemovedBySubscription && !p.isSubscriptionQuotaActive) {
        projects[i] = p.copyWith(
          watermarkRemoved: false,
          watermarkRemovedBySubscription: false,
          code: WatermarkService.apply(p.code, isEnglish: isEnglish),
          files: WatermarkService.applyToFiles(p.files, isEnglish: isEnglish),
          updatedAt: DateTime.now(),
        );
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
    // 20.09.2026: yükleme bitince analitik kullanıcı özelliklerini
    // (site sayısı kovası / abonelik planı) ilk kez yaz.
    unawaited(_loadFromPrefs().then((_) => _syncAnalyticsUserProperties()));
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
  ///      cihazdaki mevcut durum (hak/projeler) buluta taşınır.
  ///      Hesap zaten buluttaysa (başka bir cihazdan/daha önce açıldıysa)
  ///      cihaz değerleri yok sayılır, bulut esas alınır.
  ///   2) Bulut, hesap genelindeki bakiyeleri (freeSitePublishUsed/
  ///      extraPublishCredits) bu cihaza yazar.
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

      // 15.09.2026 eklendi (kanka isteği) — abonelik HESAP bazlı olduğu
      // için (Firestore'daki cihaz/bulut alanlarının aksine) TEK doğruluk
      // kaynağı worker'daki D1 — burada AYRICA bir cloudData alanı OKUNMAZ,
      // doğrudan worker'a sorulur (bkz. refreshSubscriptionStatus
      // dokümanı). NOT: giriş anında henüz worker'dan cevap gelmeden UI
      // çizilebilir — refreshSubscriptionStatus kendi notifyListeners'ını
      // ayrıca tetikler, akışı BLOKLAMAZ (unawaited).
      unawaited(refreshSubscriptionStatus());
    } catch (_) {
      // Bulut senkronizasyonu başarısız olsa da uygulama cihazdaki
      // (misafir) değerlerle çalışmaya devam eder — kullanıcı akışı
      // kesilmez.
    }

    // 20.09.2026 eklendi (kanka isteği) — giriş yapıldı: token gerektiren
    // (sıkı mod) bekleyen aktivasyonlar artık gönderilebilir. Bulut senkronu
    // başarısız olsa bile çalışsın diye try/catch'in DIŞINDA.
    unawaited(_flushPendingActivations());
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
    freeSitePublishUsed = false;
    extraPublishCredits = 0;
    giftPublishCredits = 0;
    giftWatermarkRemovalCredits = 0;
    giftDownloadWatermarkedCredits = 0;
    giftDownloadCleanCredits = 0;
    giftDomainConnectCredits = 0;
    giftMiniPackageCredits = 0;
    activeSubscriptionProductId = null;
    activeSubscriptionExpiresAt = null;
    projects = [];
    notifyListeners();

    // Ekranda o an açık olan (kaydedilmemiş olabilecek) siteyi de temizle
    // — yoksa yeni hesap/misafir moduna dönüldüğünde Hızlı Araçlar'da
    // önceki hesabın üretimi görünmeye devam ederdi.
    await detachQtSlotForNewProject();
    await _persistProjects();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_freeSitePublishUsedPrefsKey, freeSitePublishUsed);
    await prefs.setInt(_extraPublishCreditsPrefsKey, extraPublishCredits);
    await prefs.setInt(_giftPublishCreditsPrefsKey, giftPublishCredits);
    await prefs.setInt(_giftWatermarkRemovalCreditsPrefsKey, giftWatermarkRemovalCredits);
    await prefs.setInt(_giftDownloadWatermarkedCreditsPrefsKey, giftDownloadWatermarkedCredits);
    await prefs.setInt(_giftDownloadCleanCreditsPrefsKey, giftDownloadCleanCredits);
    await prefs.setInt(_giftDomainConnectCreditsPrefsKey, giftDomainConnectCredits);
    await prefs.setInt(_giftMiniPackageCreditsPrefsKey, giftMiniPackageCredits);
    await prefs.remove(_activeSubscriptionProductIdPrefsKey);
    await prefs.remove(_activeSubscriptionExpiresAtPrefsKey);
    // 20.09.2026 eklendi — önceki hesabın bekleyen worker aktivasyonları yeni
    // hesabın token'ıyla ASLA gönderilmesin.
    _pendingActivations.clear();
    await prefs.remove(_pendingActivationsPrefsKey);
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

  /// Giriş yapılmışsa hesap genelindeki bakiyeleri (ücretsiz/satın alınan
  /// yayın hakkı) bulutla eşitler; misafirse hiçbir şey yapmaz (sessizce).
  /// addPurchasedPublishCredit ve grantPublishRight içinden çağrılır — bu
  /// iki metot hesap bakiyelerinden en az birini değiştirir.
  Future<void> _syncAccountStateToCloudIfSignedIn() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await UserDataService.instance.updateAccountState(
        uid: user.uid,
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
    // Site yayın hakkı durumu — AYIN 1'İNDE sıfırlanmaz, kullanıcı hakkı
    // kullanana kadar olduğu gibi kalır (bkz. yukarıdaki alan tanımları).
    freeSitePublishUsed = prefs.getBool(_freeSitePublishUsedPrefsKey) ?? false;
    extraPublishCredits = prefs.getInt(_extraPublishCreditsPrefsKey) ?? 0;
    giftPublishCredits = prefs.getInt(_giftPublishCreditsPrefsKey) ?? 0;
    giftWatermarkRemovalCredits = prefs.getInt(_giftWatermarkRemovalCreditsPrefsKey) ?? 0;
    giftDownloadWatermarkedCredits = prefs.getInt(_giftDownloadWatermarkedCreditsPrefsKey) ?? 0;
    giftDownloadCleanCredits = prefs.getInt(_giftDownloadCleanCreditsPrefsKey) ?? 0;
    giftDomainConnectCredits = prefs.getInt(_giftDomainConnectCreditsPrefsKey) ?? 0;
    giftMiniPackageCredits = prefs.getInt(_giftMiniPackageCreditsPrefsKey) ?? 0;
    activeSubscriptionProductId = prefs.getString(_activeSubscriptionProductIdPrefsKey);
    final activeSubscriptionExpiresAtRaw =
        prefs.getString(_activeSubscriptionExpiresAtPrefsKey);
    activeSubscriptionExpiresAt = activeSubscriptionExpiresAtRaw != null
        ? DateTime.tryParse(activeSubscriptionExpiresAtRaw)
        : null;

    // Bir önceki oturumda buluta yazılamamış (internet yoktu/uygulama
    // yarıda kapandı) proje id'leri varsa yükle — girişten sonra
    // _flushPendingProjectSyncs bunları tekrar dener.
    _pendingProjectSync
      ..clear()
      ..addAll(prefs.getStringList(_pendingProjectSyncPrefsKey) ?? const []);

    // 20.09.2026 eklendi — bir önceki oturumdan kalan, worker'a henüz
    // ulaşmamış aktivasyonlar (bkz. _pendingActivations dokümantasyonu).
    // Bozuk bir kayıt varsa yok sayılır.
    _pendingActivations.clear();
    for (final raw in prefs.getStringList(_pendingActivationsPrefsKey) ?? const <String>[]) {
      final entry = PendingActivation.tryParse(raw);
      if (entry != null) _pendingActivations[entry.key] = entry;
    }

    // 16.09.2026 eklendi (kanka isteği — "otomatik kota serbest bırakma"
    // fix'i, bkz. yukarıdaki _pendingTransferCodes dokümantasyonu).
    final pendingTransferRaw = prefs.getString(_pendingTransferCodesPrefsKey);
    _pendingTransferCodes.clear();
    if (pendingTransferRaw != null && pendingTransferRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(pendingTransferRaw) as Map<String, dynamic>;
        decoded.forEach((siteId, value) {
          if (value is Map) {
            _pendingTransferCodes[siteId] = value.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        });
      } catch (_) {
        _pendingTransferCodes.clear();
      }
    }

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
    // 15.09.2026 eklendi (kanka isteği) — abonelik kota slotu için AYNI
    // gerekçe (bkz. revertExpiredSubscriptionQuota dokümantasyonu). Giriş
    // yapılmışsa AYRICA worker'dan güncel durumu sorar (refreshSubscriptionStatus
    // zaten misafir modda no-op) — böylece uygulama açılışında Google'ın
    // arka planda yaptığı bir yenileme/iptal de yakalanır.
    unawaited(revertExpiredSubscriptionQuota());
    unawaited(refreshSubscriptionStatus());
    // 16.09.2026 eklendi (kanka isteği — "otomatik kota serbest bırakma"
    // fix'i) — AYNI gerekçe: uygulama her açılışında, cihazda kayıtlı
    // bekleyen devir kodlarından biri müşteri tarafından KULLANILMIŞSA
    // (bkz. checkPendingTransferClaims dokümanı) o siteyi otomatik olarak
    // Projelerim'den düşürüp kotayı serbest bırakır.
    unawaited(checkPendingTransferClaims());
    // 20.09.2026 eklendi (kanka isteği) — bir önceki oturumda ağ hatasıyla
    // düşen mini paket / kalıcı rozet aktivasyonlarını tekrar dene (bkz.
    // _pendingActivations). Giriş henüz hazır değilse (sıkı mod -> 401)
    // kayıt kuyrukta kalır, _onAuthChanged girişten sonra tekrar tetikler.
    unawaited(_flushPendingActivations());
  }

  Future<void> _persistPendingProjectSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingProjectSyncPrefsKey, _pendingProjectSync.toList());
  }

  // ------------------------------------------------------------------
  // WORKER AKTİVASYON KUYRUĞU — 20.09.2026 eklendi (kanka isteği).
  // Alan/sabit dokümantasyonu için bkz. _pendingActivations; tasarım ve
  // "neden tekrar güvenli" için bkz. lib/services/activation_retry.dart.
  // ------------------------------------------------------------------

  /// [kind] ([PendingActivation.kindMini] / [PendingActivation.kindWatermark])
  /// türünde bir aktivasyon isteğini [siteId] için kuyruğa yazar ve hemen
  /// göndermeyi dener. Çağıranlar `unawaited` kullanır: aktivasyonun kendisi
  /// (rozet kaldırma, yerel kayıt, bildirim) buna ASLA bağlı DEĞİLDİR.
  ///
  /// Kayıt istek BAŞLAMADAN ÖNCE diske yazılır (bkz. _syncProjectToCloudIfSignedIn
  /// içindeki aynı gerekçe): süreç istek uçuştayken öldürülürse kayıt kaybolmaz,
  /// bir sonraki açılışta tekrar denenir.
  Future<void> _queueWorkerActivation(String kind, String siteId) async {
    final entry = PendingActivation(kind, siteId, DateTime.now());
    _pendingActivations[entry.key] = entry;
    try {
      await _persistPendingActivations();
    } catch (_) {
      // Kalıcı yazılamasa bile bu oturumda yine de denenir.
    }
    await _flushPendingActivations();
  }

  /// Kuyruktaki tüm kayıtları dener. Geçici arızada (SyncRetry.soon) uygulama
  /// AÇIKKEN [_activationRetryDelays] aralıklarıyla tekrar dener; koşul
  /// değişince düzelecek kayıtlar (SyncRetry.later: giriş yok / site
  /// yayınlanmamış) kuyrukta bekler ve bir sonraki tetikte denenir — tetikler:
  /// uygulama açılışı (_loadFromPrefs), giriş (_onAuthChanged), site
  /// yayınlama (markProjectPublished). Aynı anda tek bir tur çalışır; tur
  /// sürerken gelen yeni kayıt/tetik bir sonraki turda yakalanır.
  Future<void> _flushPendingActivations() async {
    if (_pendingActivations.isEmpty) return;
    if (_flushingActivations) {
      _activationFlushRequested = true;
      return;
    }
    _flushingActivations = true;
    try {
      var round = 0;
      Set<String>? onlyKeys; // null = kuyruktaki hepsi
      while (true) {
        _activationFlushRequested = false;
        final soonKeys = await _flushActivationsOnce(onlyKeys);
        if (_activationFlushRequested) {
          // Tur sürerken yeni bir kayıt/tetik geldi — baştan, hepsiyle.
          round = 0;
          onlyKeys = null;
          continue;
        }
        if (soonKeys.isEmpty || round >= _activationRetryDelays.length) break;
        await Future<void>.delayed(_activationRetryDelays[round]);
        round++;
        // Bekleme sırasında yeni bir tetik geldiyse hepsini dene; yoksa sadece
        // geçici arızayla düşenleri (later'lar aynı turda boşuna tekrar denenmez).
        onlyKeys = _activationFlushRequested ? null : soonKeys;
      }
    } catch (_) {
      // Kuyruk zaten cihazda kalıcı — bir sonraki tetikte tekrar denenir.
    } finally {
      _flushingActivations = false;
    }
  }

  /// Kuyruğu BİR kez gezer ([onlyKeys] doluysa sadece o kayıtları). Geçici
  /// arızayla (SyncRetry.soon) düşen kayıtların anahtarlarını döner.
  Future<Set<String>> _flushActivationsOnce(Set<String>? onlyKeys) async {
    final soonKeys = <String>{};
    for (final entry in List<PendingActivation>.from(_pendingActivations.values)) {
      if (onlyKeys != null && !onlyKeys.contains(entry.key)) continue;

      final idx = projects.indexWhere((p) => p.id == entry.siteId);
      // Proje bu cihazdan silinmiş (ya da hesap değişip liste sıfırlanmış) ya da
      // kayıt çok eski — gönderilecek anlamlı bir şey kalmadı.
      if (idx == -1 || DateTime.now().difference(entry.queuedAt) > _activationMaxAge) {
        await _dropActivation(entry);
        continue;
      }
      final project = projects[idx];
      // Mini paket yerelde zaten BİTMİŞSE worker'da yeni bir 30 günlük süre
      // başlatmak yanlış olur (canlı site bedava uzar) — vazgeç.
      if (entry.kind == PendingActivation.kindMini && project.isMiniPackageExpired) {
        await _dropActivation(entry);
        continue;
      }

      final retry = await _attemptActivation(entry, project);
      if (retry == null || retry == SyncRetry.never) {
        // Başarılı (null) ya da tekrar denemenin anlamsız olduğu bir cevap.
        await _dropActivation(entry);
      } else if (retry == SyncRetry.soon) {
        soonKeys.add(entry.key);
      }
      // SyncRetry.later: kuyrukta kalır.
    }
    return soonKeys;
  }

  /// Tek bir kaydı worker'a gönderir. Başarılıysa null, değilse yeniden deneme
  /// sınıfını döner.
  Future<SyncRetry?> _attemptActivation(PendingActivation entry, SiteProject project) async {
    try {
      switch (entry.kind) {
        case PendingActivation.kindMini:
          await MiniPackageService.activate(siteId: entry.siteId, ownerToken: project.ownerToken);
          return null;
        case PendingActivation.kindWatermark:
          await WatermarkSyncService.markPermanent(siteId: entry.siteId, ownerToken: project.ownerToken);
          return null;
        default:
          return SyncRetry.never; // bilinmeyen tür
      }
    } on MiniPackageException catch (e) {
      return e.retry;
    } on WatermarkSyncException catch (e) {
      return e.retry;
    } on HostingNotConfiguredException {
      return SyncRetry.never; // çalışma anında kendiliğinden düzelmez
    } catch (_) {
      return SyncRetry.later; // beklenmeyen hata: hemen değil, sonraki tetikte
    }
  }

  /// [entry]'yi kuyruktan çıkarır — yalnızca AYNI kayıt hâlâ kuyruktaysa
  /// (istek sürerken yeniden kuyruğa alınmış daha yeni bir kayda dokunma).
  Future<void> _dropActivation(PendingActivation entry) async {
    if (identical(_pendingActivations[entry.key], entry)) {
      _pendingActivations.remove(entry.key);
      try {
        await _persistPendingActivations();
      } catch (_) {}
    }
  }

  Future<void> _persistPendingActivations() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pendingActivations.isEmpty) {
      await prefs.remove(_pendingActivationsPrefsKey);
    } else {
      await prefs.setStringList(
        _pendingActivationsPrefsKey,
        _pendingActivations.values.map((e) => e.encode()).toList(),
      );
    }
  }

  /// bkz. _pendingTransferCodes dokümantasyonu (16.09.2026 eklendi).
  Future<void> _persistPendingTransferCodes() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pendingTransferCodes.isEmpty) {
      await prefs.remove(_pendingTransferCodesPrefsKey);
    } else {
      await prefs.setString(_pendingTransferCodesPrefsKey, jsonEncode(_pendingTransferCodes));
    }
  }

  /// Uygulama açılışında (bkz. _loadFromPrefs) VE Projelerim ekranı
  /// açıldığında/"↻ Yenile"ye basıldığında (bkz. projects_screen.dart >
  /// _loadLiveStats) çağrılır — 16.09.2026 eklendi (kanka isteği:
  /// "otomatik kota serbest bırakma" fix'i, bkz. _pendingTransferCodes
  /// dokümantasyonu). Cihazda kayıtlı HER bekleyen devir kodu için worker'a
  /// SESSİZCE (kodu TÜKETMEDEN, bkz. TransferService.status) durumunu sorar:
  ///   - 'claimed'  : site artık başka bir hesapta — proje kendi
  ///                  deleteProject'iyle yerel listeden düşürülür (worker'a
  ///                  giden unpublish denemesi zaten eski/geçersiz
  ///                  ownerToken yüzünden sessizce 403 alır — bkz.
  ///                  deleteProject dokümanı, MÜŞTERİNİN YAYINDAKİ sitesine
  ///                  HİÇBİR ŞEY OLMAZ), site/domain kotası OTOMATİK
  ///                  serbest kalır.
  ///   - 'expired'  : hiç kullanılmadan süresi dolmuş — proje YERİNDE
  ///                  KALIR (freelancer isterse yeniden "Devret"e basıp
  ///                  yeni kod üretebilir), sadece artık anlamsız hale
  ///                  gelen kayıt burada temizlenir.
  ///   - 'pending'/'unknown' : hiçbir şey yapılmaz — bir sonraki kontrolde
  ///                  tekrar sorulur.
  /// Ağ yoksa/worker'a ulaşılamazsa TransferService.status zaten sessizce
  /// 'unknown' döner — bu fonksiyon o durumda BEKLEMEYE devam eder, asla
  /// "emin olamadığı" bir projeyi silmez.
  Future<void> checkPendingTransferClaims() async {
    if (_pendingTransferCodes.isEmpty) return;
    var mapChanged = false;
    for (final siteId in List<String>.from(_pendingTransferCodes.keys)) {
      final entry = _pendingTransferCodes[siteId];
      final code = entry?['code'];
      if (code == null || code.isEmpty) {
        _pendingTransferCodes.remove(siteId);
        mapChanged = true;
        continue;
      }
      final result = await TransferService.status(code: code);
      switch (result.status) {
        case TransferCodeStatus.claimed:
          _pendingTransferCodes.remove(siteId);
          mapChanged = true;
          // deleteProject zaten kendi notifyListeners()/_persistProjects()'ini
          // çağırıyor — burada ekstra bir bildirim gerekmiyor. Proje bu
          // cihazdan başka bir yolla (ör. elle "Sil") zaten kaldırılmış
          // olabilir — projects.any kontrolü bu durumda deleteProject'in
          // gereksiz yere (zaten no-op ama yine de bir ağ isteği/persist
          // tetikleyecek unpublish denemesiyle) çağrılmasını önler.
          if (projects.any((p) => p.id == siteId)) {
            await deleteProject(siteId);
          }
          break;
        case TransferCodeStatus.expired:
          _pendingTransferCodes.remove(siteId);
          mapChanged = true;
          break;
        case TransferCodeStatus.pending:
        case TransferCodeStatus.unknown:
          break;
      }
    }
    if (mapChanged) {
      unawaited(_persistPendingTransferCodes());
    }
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
      _syncAnalyticsUserProperties();
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
  /// 20.09.2026 eklendi — analitik KULLANICI ÖZELLİKLERİ (bkz.
  /// AnalyticsService dokümanı): yayındaki/oluşturulan site sayısı kovaları
  /// ve abonelik planı. Esnaf (1 site, bırakıp giden) ile freelancer'ı
  /// (2+ site, düzenli kullanan) Firebase raporlarında ayırmak için.
  /// Değişmediyse Firebase'e tekrar gitmez (AnalyticsService önbelleği).
  void _syncAnalyticsUserProperties() {
    try {
      var plan = 'free';
      if (activeSubscriptionTier != null) {
        final id = activeSubscriptionProductId;
        if (id == kProductSubMini) {
          plan = 'mini';
        } else if (id == kProductSubFreelancer) {
          plan = 'freelancer';
        } else if (id == kProductSubFreelancerMax) {
          plan = 'freelancer_max';
        } else {
          plan = 'subscriber';
        }
      }
      unawaited(AnalyticsService.syncUserProperties(
        publishedSites: projects.where((p) => p.isPublished).length,
        createdSites: projects.length,
        plan: plan,
      ));
    } catch (_) {
      // Analitik ASLA uygulama akışını etkilememeli.
    }
  }

  Future<void> deleteProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    final wasPublished = idx != -1 && projects[idx].isPublished;
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
    AnalyticsService.logSiteDeleted(wasPublished: wasPublished);
    _syncAnalyticsUserProperties();
    // 16.09.2026 eklendi (kanka isteği — "otomatik kota serbest bırakma"
    // fix'i) — proje hangi yoldan silinirse silinsin (elle "Sil" ya da
    // checkPendingTransferClaims'in otomatik silmesi), bu sitenin artık
    // anlamı kalmayan bekleyen devir kaydı da (varsa) burada temizlenir.
    if (_pendingTransferCodes.remove(id) != null) {
      unawaited(_persistPendingTransferCodes());
    }
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
  /// 20.09.2026 eklendi (kanka isteği) — Google Search Console doğrulama kodunu
  /// worker'a kaydeder/kaldırır ve yerel kopyayı günceller (bkz.
  /// widgets/search_console_sheet.dart). [code] null/boş → bağlantıyı KES.
  /// Site yeniden yayınlanmaz — worker meta etiketini istek anında enjekte eder.
  /// Hata durumunda [GoogleVerificationException] fırlatır (yerel kayıt değişmez).
  Future<void> setGoogleVerification(String projectId, String? code) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    final trimmed = (code ?? '').trim();
    await GoogleVerificationService.setCode(
      siteId: projectId,
      code: trimmed.isEmpty ? null : trimmed,
      ownerToken: projects[idx].ownerToken,
    );
    // await sırasında liste değişmiş olabilir — indeksi yeniden bul.
    final i2 = projects.indexWhere((p) => p.id == projectId);
    if (i2 == -1) return;
    projects[i2] = trimmed.isEmpty
        ? projects[i2].copyWith(clearGoogleVerification: true, updatedAt: DateTime.now())
        : projects[i2].copyWith(googleVerificationCode: trimmed, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[i2]));
  }

  // ------------------------------------------------------------------
  // SUNUCUYLA YAYIN DURUMU UZLAŞTIRMA — 20.09.2026 eklendi (kanka isteği).
  //
  // SORUN: worker, ücretsiz katmanda 180 gündür yayınlanmayan siteyi R2+D1'den
  // SİLİYOR (bkz. worker > freeTierInactivitySweep) ama uygulama sunucuda site
  // var mı diye hiç bakmıyordu — kart sonsuza dek "Yayında" görünüyor, sayaç
  // eksiye düşüyordu. Artık Projelerim açıldığında/yenilendiğinde yayındaki
  // projeler tek toplu istekle (fetchStatsBatch — worker'da kaydı olmayan
  // siteyi listede DÖNDÜRMEZ) sorgulanır; sunucuda karşılığı olmayan proje
  // yerelde "yayında değil" olarak işaretlenir (içerik/form AYNEN durur,
  // kullanıcı tekrar yayınlayabilir).
  //
  // GÜVENLİK KURALLARI (yanlış pozitif = kullanıcının sitesini yanlışlıkla
  // "kalktı" göstermek olurdu):
  //  - herhangi bir parça isteği başarısız olursa HİÇBİR ŞEY değiştirilmez;
  //  - worker en fazla 50 id kabul edip fazlasını sessizce kırpıyor → 50'şerli
  //    parçalara bölünür (yoksa 51. ve sonrası "eksik" sanılırdı);
  //  - otomatik çağrılar en fazla [_serverReconcileMinInterval]'de bir çalışır
  //    (D1 okuma maliyeti); kullanıcı "Yenile"ye basınca [force] ile atlanır.
  // Dönen liste: yerelde yayından düşürülen projelerin adları (UI bilgi verir).
  // ------------------------------------------------------------------
  static const Duration _serverReconcileMinInterval = Duration(hours: 6);
  DateTime? _lastServerReconcileAt;
  bool _serverReconcileRunning = false;

  Future<List<String>> reconcilePublishedWithServer({bool force = false}) async {
    if (_serverReconcileRunning) return const [];
    if (!HostingConfig.isConfigured) return const [];
    final last = _lastServerReconcileAt;
    if (!force && last != null && DateTime.now().difference(last) < _serverReconcileMinInterval) {
      return const [];
    }
    final publishedIds = projects.where((p) => p.isPublished).map((p) => p.id).toList();
    if (publishedIds.isEmpty) return const [];

    _serverReconcileRunning = true;
    try {
      final found = <String>{};
      for (var i = 0; i < publishedIds.length; i += 50) {
        final chunk = publishedIds.sublist(i, min(i + 50, publishedIds.length));
        final stats = await HostingService.fetchStatsBatch(siteIds: chunk);
        found.addAll(stats.keys);
      }
      _lastServerReconcileAt = DateTime.now();

      final removedNames = <String>[];
      for (final id in publishedIds) {
        if (found.contains(id)) continue;
        final idx = projects.indexWhere((p) => p.id == id);
        // Sorgu sürerken proje silinmiş/yayından kaldırılmış olabilir.
        if (idx == -1 || !projects[idx].isPublished) continue;
        removedNames.add(projects[idx].name);
        // Sunucudaki kayıt yok → domain/kota bağlantıları da yok; yerel
        // kopyayı temiz "yayında değil" duruma getir. ownerToken BİLEREK
        // korunur (copyWith) — yeniden yayınlama akışı için (bkz. unpublish).
        projects[idx] = projects[idx].copyWith(
          unpublish: true,
          clearDomain: true,
          domainViaSubscription: false,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        await _persistProjects();
        unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
        // Yerelde kalan abonelik kota kaydı varsa (süresi dolmuş olabilir)
        // temizle — worker'da satır olmadığı için sunucu çağrısı best-effort.
        await unassignProjectFromSubscriptionQuota(id);
      }
      if (removedNames.isNotEmpty && !projects.any((pp) => pp.isPublished)) {
        try {
          await NotificationService.instance.cancelDailyVisitorCheckIn();
        } catch (_) {}
      }
      return removedNames;
    } catch (_) {
      // Ağ/sunucu hatası: hiçbir şey değiştirme, bir sonraki açılışta tekrar dene.
      return const [];
    } finally {
      _serverReconcileRunning = false;
    }
  }

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
  // PROJE KOPYALAMA — 14.09.2026 eklendi (kanka isteği: freelancer/ajans
  // modeli — aynı yapıyı farklı müşteriler için tekrar tekrar üretmenin
  // hızlandırılması, bkz. proje sohbeti).
  // ------------------------------------------------------------------

  /// [id]'li projeyi, TÜM form/kod/dosya içeriğini KORUYARAK ama yayın/
  /// domain/mini-paket/rozet/satın-alma durumunu SIFIRLAYARAK kopyalar.
  /// Kopya sıfırdan, hiç yayınlanmamış, free kademede YENİ bir SiteProject'tir
  /// — kendi (yeni, tahmin edilemez) id'sine ve (henüz null) ownerToken'ına
  /// sahiptir. Orijinalin publishedUrl/customDomain/watermarkRemoved/
  /// publishRightGranted/downloadPurchased gibi alanları BİLEREK kopyaya
  /// TAŞINMAZ — aksi halde kopya, worker'da orijinaliyle aynı subdomain/
  /// domain kaydına çakışır ya da parasını orijinal ödemişken kopya da
  /// "satın alınmış" görünürdü. Kısacası bu, "aynı içerikle YENİ bir proje
  /// başlat" demektir — "aynı siteyi ikinci bir yerde yayınla" DEĞİL.
  ///
  /// [id] bulunamazsa hiçbir şey yapmaz ve null döner (çağıran taraf bunu
  /// "proje artık yok" olarak yorumlayabilir).
  Future<SiteProject?> duplicateProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return null;
    final source = projects[idx];
    final now = DateTime.now();
    final copy = SiteProject(
      id: _generateSecureId(),
      name: '${source.name} (Kopya)',
      mode: source.mode,
      kind: source.kind,
      code: source.code,
      files: Map<String, String>.from(source.files),
      activeFileName: source.activeFileName,
      createdAt: now,
      updatedAt: now,
      formData: source.formData == null ? null : Map<String, dynamic>.from(source.formData!),
      editableInApp: source.editableInApp,
      // Aşağıdakilerin HİÇBİRİ verilmiyor — varsayılanlarıyla (yayınlanmamış,
      // domainsiz, mini paketsiz, rozetli, satın alma hakları tüketilmemiş)
      // kalıyorlar: publishedSubdomain/publishedUrl/publishedAt/ownerToken,
      // customDomain/domainStatus/domainConnectedAt, miniPackageActivatedAt,
      // watermarkRemoved*, publishRightGranted, downloadPurchased.
    );
    projects.insert(0, copy);
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(copy));
    return copy;
  }

  // ------------------------------------------------------------------
  // SİTEYİ DEVRET — 14.09.2026 eklendi (kanka isteği: freelancer bir siteyi
  // bitirdiği müşteriye TAM olarak teslim edebilsin — bkz.
  // lib/services/transfer_service.dart dokümantasyonu, orada akışın TAMAMI
  // adım adım anlatılıyor).
  // ------------------------------------------------------------------

  /// 1. adım (mevcut sahip tarafında): [id]'li proje için worker'dan bir
  /// devir kodu ister. Proje HİÇ yayınlanmamışsa (ownerToken null VE worker'da
  /// hiç kaydı yoksa) worker 404 döner — bu TransferException olarak
  /// yukarı fırlatılır, çağıran taraf (UI) kullanıcıya "önce yayınla" demeli.
  Future<TransferInitiateResult> initiateProjectTransfer(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) {
      throw TransferException('Proje bulunamadı.');
    }
    final project = projects[idx];
    // Worker'ın D1 (TEXT sütun) tarafına gidiyor — Firestore'a yazarken
    // uygulanan AYNI "gömülü base64 fotoğrafları çıkar" güvenlik payı burada
    // da uygulanıyor (bkz. UserDataService.stripImagesForExport dokümantasyonu).
    final snapshot = UserDataService.instance.stripImagesForExport(project.toJson());
    final result = await TransferService.initiate(
      siteId: project.id,
      ownerToken: project.ownerToken,
      projectSnapshot: snapshot,
    );
    // 16.09.2026 eklendi (kanka isteği — "otomatik kota serbest bırakma"
    // fix'i, bkz. _pendingTransferCodes/checkPendingTransferClaims
    // dokümantasyonu). ÖNCEDEN bu kod sadece bir dialogda GÖSTERİLİYOR,
    // hiçbir yere KAYDEDİLMİYORDU — bu satır olmadan checkPendingTransferClaims
    // hiçbir zaman kontrol edecek bir kod bulamazdı. Aynı site için
    // yukarıdaki TransferService.initiate'in kendisi worker tarafında ESKİ
    // kaydın (varsa) üzerine yazdığı için burada da AYNI şekilde üzerine
    // yazılıyor — bir siteye ait tek bir "en son" kod izlenir.
    _pendingTransferCodes[project.id] = {
      'code': result.code,
      'expiresAt': result.expiresAt.toIso8601String(),
    };
    unawaited(_persistPendingTransferCodes());
    return result;
  }

  /// 3. adım (yeni sahip / müşteri tarafında): [code]'u worker'a doğrulatır,
  /// dönen proje anlık görüntüsünü BU HESABIN Projelerim listesine YENİ bir
  /// kayıt olarak ekler. Snapshot'taki `id` (site'ın worker/D1/R2'deki
  /// KİMLİĞİ) BİLEREK KORUNUR — böylece ileride bu projede "Yayından
  /// Kaldır"/"Domain Bağla"/"Mini Paket" gibi işlemler AYNI worker kaydı
  /// üzerinden, sorunsuz çalışmaya devam eder. `ownerToken` İSE worker'ın bu
  /// çağrıda ÜRETTİĞİ YENİ token ile DEĞİŞTİRİLİR — eski sahibin cihazındaki
  /// token bu noktadan sonra worker tarafında zaten geçersizdir.
  ///
  /// Cihazda AYNI id'de bir proje zaten varsa (aynı hesap kendi sitesini
  /// tekrar claim etmeye çalışıyor gibi olağandışı bir durum) üzerine YAZILIR
  /// — bu akışın normal kullanımında pratikte hiç yaşanmaz.
  /// 16.09.2026 eklendi (kanka isteği — devir sonrası "sessiz watermark
  /// dönüşü" UX sorununu çözmek için). [premiumLost] true ise: bu site
  /// aylık abonelik kaynaklı premium'du VE devralan hesabın kendi aktif
  /// aboneliğine OTOMATİK oturtulamadı (aboneliği yok ya da kotası dolu) —
  /// yani watermark GERİ GELDİ ve ekran bunu kullanıcıya AÇIKÇA söylemeli.
  /// customDomain/miniPackage kaynaklı premium bu kapsamda DEĞİL (bkz.
  /// claimTransferredProject içindeki "BİLEREK dokunulmaz" notu) — o ikisi
  /// zaten hiç bozulmuyor, sadece abonelik kaynaklı olan bu riski taşıyor.
  Future<TransferClaimOutcome> claimTransferredProject(
    String code, {
    // 16.09.2026 eklendi (kanka isteği — "domain devirde kaybolmasın"
    // akışı). Çağıran taraf (_claimTransferCode) preview'da domainAtRisk
    // true dönerse, kullanıcıya sorup buradan iletir. İkisi de false ise
    // davranış ESKİSİ GİBİDİR — bkz. TransferService.claim dokümanı.
    bool claimDomainViaOwnSubscription = false,
    bool claimDomainViaPurchase = false,
    // 17.09.2026 eklendi (kanka isteği — "devir sırasında abonelik kaynaklı
    // premium siteler" bug fix'i). claimDomainViaOwnSubscription İLE AYNI
    // desen — çağıran taraf (_claimTransferCode) bu hesabın kendi aktif
    // aboneliğinde boş bir site kotası slotu olup olmadığına göre iletir.
    // False ise davranış ESKİSİ GİBİDİR (worker rozeti geri koyup fazla
    // sayfaları R2'den siler) — bkz. TransferService.claim dokümanı.
    bool claimQuotaViaOwnSubscription = false,
  }) async {
    // 16.09.2026 eklendi — "race condition" fix'i (bkz. proje sohbeti, kod
    // incelemesi bulgusu). _onAuthChanged, girişten sonra refreshSubscriptionStatus()'u
    // `unawaited` çağırıyor (bkz. o fonksiyon) — yeni sahip giriş yaptıktan
    // HEMEN sonra hızlıca devir kodu girerse, aşağıdaki hasActiveSubscription
    // kontrolü o unawaited çağrı bitmeden çalışabilir ve henüz eski/boş
    // önbellekten okuyabilir. Bu da aslında AKTİF bir aboneliği olan bir
    // hesap için otomatik kota ataması yanlışlıkla atlanıp premiumLost: true
    // dönmesine yol açar. Burada AYRICA (yeniden) await edilmesi bunu
    // sertleştirir — _onAuthChanged'daki unawaited çağrı zaten bitmişse bu
    // sadece gereksiz bir ağ isteği olur (SubscriptionService.fetchStatus
    // ucuzdur), bitmemişse ise burası doğru/güncel durumu garantiler.
    await refreshSubscriptionStatus();
    final user = AuthService.instance.currentUser;
    final result = await TransferService.claim(
      code: code,
      newOwnerUid: user?.uid,
      newOwnerEmail: user?.email,
      claimDomainViaOwnSubscription: claimDomainViaOwnSubscription,
      claimDomainViaPurchase: claimDomainViaPurchase,
      claimQuotaViaOwnSubscription: claimQuotaViaOwnSubscription,
    );
    final snapshot = Map<String, dynamic>.from(result.projectSnapshot);
    snapshot['ownerToken'] = result.ownerToken;
    // 20.09.2026: worker devirde Search Console kodunu siler (bkz. handleTransferClaim);
    // eski sahibin kodu yeni sahibin kaydında "bağlı" görünmesin.
    snapshot.remove('googleVerificationCode');
    var claimed = SiteProject.fromJson(snapshot).copyWith(updatedAt: DateTime.now());

    // 17.09.2026 eklendi (kanka isteği — "devir sırasında abonelik kaynaklı
    // premium siteler" bug fix'i, kod incelemesi bulgusu). ESKİDEN burada
    // wasSubscriptionPremium (frozen snapshot'taki bir TAHMİN) baz alınıp
    // subscriptionQuotaExpiresAt/watermarkRemovedBySubscription HER ZAMAN
    // sıfırlanıyordu — worker GERÇEKTE 'kept_via_subscription' dönse BİLE
    // (yani rozeti/fazla sayfaları HİÇ sökmemiş, siteyi doğrudan yeni
    // sahibin aboneliğine bağlamışsa) yerel kayıt yine "free'ye düştü"
    // gösteriyordu; sonra aşağıdaki eski "otomatik yeniden ata" denemesi
    // durumu SADECE D1'de telafi etmeye çalışıyordu ama R2'de zaten silinmiş
    // sayfaları asla geri getiremiyordu. ARTIK karar worker'ın GERÇEKTE ne
    // yaptığına (result.quotaOutcome) göre veriliyor — domainOutcome
    // switch'iyle BİREBİR AYNI desen.
    final wasSubscriptionPremium = claimed.watermarkRemovedBySubscription;
    switch (result.quotaOutcome) {
      case 'kept_via_subscription':
        // Worker subscription_quota_uid'i zaten yeni sahibin uid'ine
        // devretti VE R2'ye HİÇ dokunmadı (rozet/fazla sayfalar OLDUĞU
        // GİBİ kaldı) — kota süresi yeni sahibin KENDİ aboneliğinin bitiş
        // tarihine ayarlanır (eski sahibin tarihini taşımak yanlış olurdu).
        claimed = claimed.copyWith(
          subscriptionQuotaExpiresAt: activeSubscriptionExpiresAt,
          watermarkRemoved: true,
          watermarkRemovedBySubscription: true,
        );
        break;
      default:
        // 'stripped' ya da 'not_applicable' — worker zaten R2'de rozeti
        // geri koydu/fazla sayfaları sildi (bkz. handleTransferClaim), yerel
        // kaydı da BUNA göre temizle.
        if (claimed.subscriptionQuotaExpiresAt != null || wasSubscriptionPremium) {
          claimed = claimed.copyWith(
            subscriptionQuotaExpiresAt: null,
            watermarkRemoved: wasSubscriptionPremium ? false : claimed.watermarkRemoved,
            watermarkRemovedBySubscription: false,
            code: wasSubscriptionPremium
                ? WatermarkService.apply(claimed.code, isEnglish: isEnglish)
                : claimed.code,
            files: wasSubscriptionPremium
                ? WatermarkService.applyToFiles(claimed.files, isEnglish: isEnglish)
                : claimed.files,
          );
        }
    }

    // 16.09.2026 eklendi (kanka isteği — "domain devirde kaybolmasın"
    // akışı, bkz. proje sohbeti). PAID domain'in (kProductConnectDomain ile
    // satın alınmış) AKSİNE, abonelik kotasıyla ÜCRETSİZ bağlanmış bir
    // domain hiçbir zaman STANDALONE ödenmedi — bu yüzden VARSAYILAN
    // davranış hâlâ "eski sahibin aboneliğinden alıcıya kaynak sızdırma"
    // riskine karşı domain'i sökmektir. ESKİDEN bu KOŞULSUZDU
    // (domainViaSubscription true ise HER ZAMAN sökülürdü). ARTIK worker'ın
    // gerçekte ne yaptığına (result.domainOutcome, bkz. handleTransferClaim)
    // göre karar veriliyor — çünkü yeni sahip claim'den ÖNCE (bkz.
    // _claimTransferCode) ya kendi aboneliğinden bir domain kotası slotu
    // sundu ya da yıllık domain ücretini ödedi, worker bunu SUNUCU
    // TARAFINDA doğrulayıp domain'i GERÇEKTEN korudu — bu durumda yerelde
    // de domain alanlarını SİLMEK yanlış olurdu (worker'da domain hâlâ
    // bağlı, cihazda "bağlı değil" görünürdü).
    switch (result.domainOutcome) {
      case 'kept_via_subscription':
        // Worker subscription_domain_uid'i zaten yeni sahibin uid'ine
        // devretti — domain hâlâ bağlı, artık yeni sahibin abonelik
        // kotasının bir parçası. customDomain/domainStatus/domainConnectedAt
        // snapshot'tan (worker tarafından tazelendi) OLDUĞU GİBİ kalır.
        claimed = claimed.copyWith(domainViaSubscription: true);
        break;
      case 'kept_via_purchase':
        // Worker domain'i SİTEYE kalıcı (tek seferlik satın alınmış gibi)
        // bağladı, domain_connected_at'i bugüne sıfırladı — yerelde de
        // artık abonelik kaynaklı DEĞİL, kalıcı bir domain.
        claimed = claimed.copyWith(domainViaSubscription: false);
        break;
      default:
        // 'stripped' ya da 'not_applicable' — ESKİ davranışın AYNISI:
        // abonelik kaynaklıysa (frozen snapshot'ta domainViaSubscription
        // true) ve worker fiilen söktüyse, yerel kaydı da temizle.
        if (claimed.domainViaSubscription) {
          claimed = claimed.copyWith(
            domainViaSubscription: false,
            clearDomain: true,
          );
        }
    }

    final idx = projects.indexWhere((p) => p.id == claimed.id);
    if (idx == -1) {
      projects.insert(0, claimed);
    } else {
      projects[idx] = claimed;
    }
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(claimed));

    // 17.09.2026 eklendi (kanka isteği — "devir sırasında abonelik kaynaklı
    // premium siteler" bug fix'i). ESKİDEN burada KOŞULSUZ
    // SubscriptionQuotaSyncService.unassign çağrılırdı — bu, worker'ın
    // 'kept_via_subscription' ile ÖZENLE kurduğu subscription_quota_uid =
    // yeniSahip kaydını HEMEN ARDINDAN geri NULL'a çekip bozardı. Artık
    // SADECE worker GERÇEKTE bu alanı NULL'ladığı durumlarda ('stripped'/
    // 'not_applicable') çağrılıyor — bu da sadece bir EK güvence, atlansa
    // da worker tarafı zaten doğru kalır.
    if (result.quotaOutcome != 'kept_via_subscription') {
      unawaited(SubscriptionQuotaSyncService.unassign(siteId: claimed.id, ownerToken: claimed.ownerToken).catchError((_) {}));
    }

    // 17.09.2026 eklendi (kanka isteği — aynı fix'in devamı). worker
    // 'kept_via_subscription' dönmüşse zaten doğru atamayı yapmıştır —
    // burada TEKRAR assignProjectToSubscriptionQuota çağırmaya gerek yok.
    // SADECE 'stripped'/'not_applicable' durumunda (yani içerik R2'de
    // ZATEN sökülmüşken) hesabın BAŞKA bir slotu varsa diye eski "otomatik
    // yeniden ata" denemesi korunuyor — ama bu artık SADECE gelecekteki
    // kota/rozet bayrağı için bir iyileştirme, R2'de zaten silinmiş
    // sayfaları GERİ GETİRMEZ (kullanıcı elle yeniden yayınlamalı) — bu
    // yüzden premiumLost hesabı (aşağıda) buna bakılmaksızın DOĞRUDAN
    // result.quotaOutcome'a göre veriliyor, "reassigned" başarılı olsa bile
    // içerik kaybı GERÇEKTİ diye gizlenmiyor.
    if (result.quotaOutcome != 'kept_via_subscription' && hasActiveSubscription) {
      unawaited(assignProjectToSubscriptionQuota(claimed.id));
    }

    // 17.09.2026 eklendi (kanka isteği — aynı fix'in devamı). premiumLost
    // artık worker'ın GERÇEKTE ne yaptığına (result.quotaOutcome) göre
    // belirleniyor — 'kept_via_subscription' dışındaki HER durumda içerik
    // R2'de fiilen sökülmüştür, bu yüzden true (yukarıdaki "yeniden ata"
    // denemesi ileride başka bir slota otursa bile canlı sayfalar geri
    // gelmez, kullanıcı yeniden yayınlamalı — dialog bunu söylüyor).
    final premiumLost = wasSubscriptionPremium && result.quotaOutcome != 'kept_via_subscription';
    return TransferClaimOutcome(
      project: claimed,
      premiumLost: premiumLost,
      domainOutcome: result.domainOutcome,
    );
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
    bool viaSubscription = false,
  }) async {
    assert((viaDomain ? 1 : 0) + (viaMiniPackage ? 1 : 0) + (viaSubscription ? 1 : 0) <= 1);
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final project = projects[idx];
    if (project.watermarkRemoved) {
      // Zaten rozetsiz. Tek anlamlı durum: daha önce SADECE domain, mini
      // paket ya da abonelik kota slotuyla (geçici) kaldırılmıştı, şimdi
      // GERÇEK bir satın alma (üçü de false) geliyor — bu, kaldırmayı
      // KALICI hale getirir (süre dolsa bile artık rozet geri gelmez).
      // İçerik zaten rozetsiz olduğundan tekrar strip etmeye gerek yok.
      if (!viaDomain &&
          !viaMiniPackage &&
          !viaSubscription &&
          (project.watermarkRemovedByDomain ||
              project.watermarkRemovedByMiniPackage ||
              project.watermarkRemovedBySubscription)) {
        projects[idx] = project.copyWith(
          watermarkRemovedByDomain: false,
          watermarkRemovedByMiniPackage: false,
          watermarkRemovedBySubscription: false,
        );
        notifyListeners();
        await _persistProjects();
        unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
        // 06.09.2026 eklendi — worker'a da bildir ki premiumDowngradeSweep
        // bu siteye BİR DAHA rozet enjekte etmesin (bkz. WatermarkSyncService
        // dokümanı). Best-effort, satın alma akışını etkilemez.
        // 20.09.2026: kalıcı kuyruk + otomatik yeniden deneme (bkz. _queueWorkerActivation).
        unawaited(_queueWorkerActivation(PendingActivation.kindWatermark, id));
      }
      return; // diğer tüm durumlarda no-op
    }

    // 1) Projenin KENDİ kaydında zaten üretilmiş/kaydedilmiş içerikten
    // rozeti geriye dönük temizle (üretim anında gömüldüğü için).
    projects[idx] = project.copyWith(
      watermarkRemoved: true,
      watermarkRemovedByDomain: viaDomain,
      watermarkRemovedByMiniPackage: viaMiniPackage,
      watermarkRemovedBySubscription: viaSubscription,
      code: WatermarkService.strip(project.code),
      files: WatermarkService.stripFromFiles(project.files),
      updatedAt: DateTime.now(),
    );
    // 06.09.2026 eklendi — SADECE gerçek/kalıcı satın almada (domain/mini
    // paket/abonelik yan etkisi DEĞİL) worker'a bildir; üçü de BİLEREK
    // atlanır (geçici kaldırma, süresi dolunca sweep zaten geri ekleyecek —
    // bkz. WatermarkSyncService dokümanı).
    if (!viaDomain && !viaMiniPackage && !viaSubscription) {
      // 20.09.2026: kalıcı kuyruk + otomatik yeniden deneme (bkz. _queueWorkerActivation).
      unawaited(_queueWorkerActivation(PendingActivation.kindWatermark, id));
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
  // 28.08.2026 eklendi, 16.09.2026'da fiyat/akış revizyonuyla güncellendi.
  // kProductDownloadWatermarked (799.90) satın alındığında çağrılır — bu
  // projeyi tekrar tekrar, ücretsiz indirebilme HAKKINI verir (bkz.
  // widgets/download_purchase_sheet.dart). 16.09.2026'dan itibaren bu ürün
  // SADECE proje ZATEN rozetsizken (watermarkRemoved=true) sunuluyor —
  // rozetin kendisine burada DOKUNULMAZ, zaten kaldırılmış olduğu için
  // indirilen dosya rozetsiz iner. Yani watermarkRemoved TEK BAŞINA bu
  // metodun çağrılmasını GEREKSİZ KILMAZ: rozeti önceden kaldırmış bir
  // kullanıcı bile indirme hakkını AYRICA satın almalıdır (bkz.
  // canDownloadFreely).
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
  // 28.08.2026 eklendi, 16.09.2026'da fiyatı güncellendi. kProductDownloadNoWatermark
  // (999.90) satın alındığında çağrılır — TEK ödemede hem
  // removeWatermarkForProject'in hem de unlockDownloadForProject'in
  // yaptığını uygular: rozeti kalıcı olarak kaldırır VE indirme hakkını
  // verir. Proje henüz rozetsiz DEĞİLKEN (bkz. download_purchase_sheet.dart)
  // artık TEK seçenek budur — "Watermarklı İndir" (rozet kalarak ucuz
  // indirme) seçeneği 16.09.2026'da kaldırıldı. Savunma amaçlı burada da
  // idempotent tutulur.
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
  ///
  /// 16.09.2026 eklendi (kanka uyarısı — kod incelemesi bulgusu, "gerçek
  /// bug" fix'i). ÖNCEDEN burada SADECE downloadPurchased'a bakılıyordu —
  /// billing_constants.dart > kTierFreelancerMax.freeDownloads (Mağaza/
  /// abonelik ekranlarında AÇIKÇA reklamı yapılan "ücretsiz site indirme"
  /// hakkı) HİÇBİR YERDE okunmuyordu, yani bu paketi satın alan bir
  /// kullanıcı bile indirmek için AYRICA kProductDownloadWatermarked/
  /// kProductDownloadNoWatermark satın almak ZORUNDA kalıyordu — vaat
  /// edilen özellik fiilen çalışmıyordu. Çözüm: ROZET KURALIYLA (bkz. dosya
  /// başı "ROZET/KİLİT KURALI" kararı — abonelik SADECE kota DAHİLİNDEKİ
  /// siteler için ayrıcalık sağlar, hesaptaki TÜM siteler için DEĞİL) AYNI
  /// desen: activeSubscriptionTier.freeDownloads true VE bu proje O AN
  /// abonelik kotası içindeyse (subscriptionQuotaExpiresAt != null —
  /// assignProjectToSubscriptionQuota/_backfillSubscriptionQuota TEK doğru
  /// kaynak) true döner. Kota dışına düşen (aşım seçiminde elenen) bir site
  /// bu ayrıcalığı OTOMATİK kaybeder — removeWatermarkForProject(viaSubscription)
  /// ile AYNI kaynağa bağlı, tutarlı.
  /// 17.09.2026 GÜNCELLENDİ (kanka kararı — bkz. billing_constants.dart >
  /// kTierFreelancerMax'taki not) — Max paketin ÜCRETSİZ SINIRSIZ indirme
  /// hakkı KALDIRILDI (tek aylık ödemeyle abone olup kotadaki tüm siteleri
  /// indirip iptal etme açığı). Artık tüm SubscriptionTierInfo'larda
  /// freeDownloads hep false, bu yüzden aşağıdaki activeSubscriptionTier
  /// kontrolü PRATİKTE asla true dönmez — indirme hangi pakete/aboneliğe
  /// sahip olunursa olsun HER ZAMAN site başına ayrı satılan bir kilit.
  /// Kontrol BİLEREK silinmedi (kodu sökmek yerine veriyle kapatıldı) —
  /// ileride paket bazlı bir indirme ayrıcalığı tekrar gerekirse
  /// billing_constants.dart'ta tek satır değişiklikle geri açılabilir.
  bool canDownloadFreely(String? id) {
    if (id == null) return false;
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return false;
    final project = projects[idx];
    if (project.downloadPurchased) return true;
    if (activeSubscriptionTier?.freeDownloads == true &&
        project.subscriptionQuotaExpiresAt != null) {
      return true;
    }
    return false;
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
    // 15.09.2026 eklendi (kanka isteği) — publish_sheet.dart'ta seçilen
    // "Talepler nereye gelsin?" tercihi burada SiteProject'e kalıcı yazılır
    // (bkz. HostingService.publish > leadDelivery dokümanı ve
    // SiteProject.leadDelivery/leadEmail). 'box' + null verilirse (varsayılan
    // parametreler) davranış eskisiyle birebir aynı kalır.
    String leadDelivery = 'box',
    String? leadEmail,
  }) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(
      publishedSubdomain: subdomain,
      publishedUrl: url,
      publishedAt: DateTime.now(),
      ownerToken: ownerToken,
      leadDelivery: leadDelivery,
      leadEmail: leadEmail,
      updatedAt: DateTime.now(),
    );
    _syncAnalyticsUserProperties();
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
    // 20.09.2026 eklendi — site artık worker'da VAR: yayınlanmadan önce 404
    // ile bekleyen aktivasyonları (ör. yayından önce alınan rozet kaldırma)
    // şimdi dene. Yayınlama akışını BLOKLAMAZ.
    unawaited(_flushPendingActivations());
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
    // 20.09.2026: worker unpublish'te site satırını (dolayısıyla domain kaydını)
    // siliyor ve Cloudflare hostname'ini de söküyor — yerelde domain "bağlı"
    // kalırsa yeniden yayında istemci↔sunucu ayrışır. Temizle.
    projects[idx] = projects[idx].copyWith(
      unpublish: true,
      clearDomain: true,
      domainViaSubscription: false,
      updatedAt: DateTime.now(),
    );
    AnalyticsService.logSiteUnpublished(reason: 'user');
    _syncAnalyticsUserProperties();
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
    // 20.09.2026 (kanka isteği — "kota slotu yerelde dolu kalıyor mu?"): worker
    // site satırını silince D1'deki abonelik slotu zaten boşalıyordu ama YEREL
    // kayıtta subscriptionQuotaExpiresAt dolu kalıyordu. Sonuçları: (1) yayında
    // olmayan proje bir slotu işgal ediyor gibi sayılıyordu (subscriptionQuotaUsed
    // / canPublishProject → başka siteye slot verilmiyor, paywall çıkabiliyordu);
    // (2) aynı proje yeniden yayınlanınca grantPublishRight "zaten atanmış" diye
    // erken dönüyor, worker'daki YENİ satıra hiç assign gitmiyordu → sunucu bu
    // siteyi kotasız sanıp premiumDowngradeSweep ile premium'unu düşürebiliyordu.
    // Aynı davranış zaten reconcilePublishedWithServer ve
    // _forceUnpublishAndUnassignQuota'da vardı; buradaki tek eksik yoldu.
    // Yeniden yayınlamada grantPublishRight boş slot varsa yeniden atar. Slottan
    // çıkarma rozeti/kilitleri geri getirir (site zaten yayında değil). Sunucu
    // çağrısı best-effort (satır yok → no-op).
    await unassignProjectFromSubscriptionQuota(id);
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
    // 20.09.2026: artık kalıcı kuyruk + otomatik yeniden deneme (bkz.
    // _queueWorkerActivation) — ağ hatasıyla düşen istek sessizce kaybolmaz.
    unawaited(_queueWorkerActivation(PendingActivation.kindMini, id));

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
    final result = await DomainService.renew(siteId: id, ownerToken: projects[idx].ownerToken);
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
