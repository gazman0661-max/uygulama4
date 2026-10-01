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
import '../services/transfer_images.dart';
import '../services/publish_image_service.dart';
import '../services/image_compress_service.dart';
import '../services/auth_header.dart';
import 'package:http/http.dart' as http;
import '../services/activation_retry.dart';
import '../services/mini_package_service.dart';
import '../services/subscription_service.dart';
import '../services/subscription_quota_sync_service.dart';
import '../services/watermark_sync_service.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import '../services/server_time_service.dart';
import '../constants/billing_constants.dart';

enum SiteMode { single, multi }

class TransferClaimOutcome {
  final SiteProject project;
  final bool premiumLost;

  final String domainOutcome;

  final int missingImages;

  const TransferClaimOutcome({
    required this.project,
    required this.premiumLost,
    this.domainOutcome = 'not_applicable',
    this.missingImages = 0,
  });
}

class AppState extends ChangeNotifier {
  bool get qtCurrentHasBranding => !_isWatermarkRemoved(qtCurrentProjectId);

  bool _isWatermarkRemoved(String? projectId) {
    if (projectId == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].watermarkRemoved;
  }

  bool get qtCurrentEditableInApp {
    final projectId = qtCurrentProjectId;
    if (projectId == null) return true;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return true;
    return projects[idx].editableInApp;
  }

  bool get qtCurrentIsPremium {
    final projectId = qtCurrentProjectId;
    if (projectId != null) {
      final idx = projects.indexWhere((p) => p.id == projectId);
      if (idx != -1 && projects[idx].isPremium) return true;
    }
    final tier = activeSubscriptionTier;
    if (tier != null && subscriptionQuotaUsed < tier.siteQuota) return true;
    return false;
  }

  SiteProject? get qtCurrentProject {
    final projectId = qtCurrentProjectId;
    if (projectId == null) return null;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return null;
    return projects[idx];
  }

  bool isEnglish = false;

  void syncLanguage(bool isEnglish) {
    this.isEnglish = isEnglish;
  }

  static const _qtGeneratedCodePrefsKey = 'qt_generated_code';
  static const _qtGeneratedFilesPrefsKey = 'qt_generated_files';
  static const _qtActiveFilePrefsKey = 'qt_active_file_name';
  static const _qtSiteModePrefsKey = 'qt_site_mode';
  static const _qtCurrentProjectIdPrefsKey = 'qt_current_project_id';
  static const _qtFormDataPrefsKey = 'qt_form_data';
  static const _qtCurrentKindPrefsKey = 'qt_current_kind';

  static const _projectsPrefsKey = 'saved_projects_v1';

  static const _pendingProjectSyncPrefsKey = 'pending_project_cloud_sync_ids';
  final Set<String> _pendingProjectSync = {};

  static const _pendingActivationsPrefsKey = 'pending_worker_activations_v1';

  static const Duration _activationMaxAge = Duration(days: 30);

  static const List<Duration> _activationRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 20),
    Duration(seconds: 60),
    Duration(seconds: 180),
  ];

  final Map<String, PendingActivation> _pendingActivations = {};
  bool _flushingActivations = false;
  bool _activationFlushRequested = false;

  static const _pendingTransferCodesPrefsKey = 'pending_transfer_codes_v1';
  final Map<String, Map<String, String>> _pendingTransferCodes = {};

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

  Future<void> _writeLargeData(String name, String content) async {
    try {
      final dir = await _largeDataDir();
      final tmp = File('${dir.path}/$name.tmp');
      await tmp.writeAsString(content, flush: true);
      await tmp.rename('${dir.path}/$name');
    } catch (_) {
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
    }
  }

  Future<void> _migrateLegacyPrefValue(
    SharedPreferences prefs,
    String prefsKey,
    String fileName,
  ) async {
    final dir = await _largeDataDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return;
    final legacy = prefs.getString(prefsKey);
    if (legacy == null) return;
    await _writeLargeData(fileName, legacy);
    await prefs.remove(prefsKey);
  }

  List<SiteProject> projects = [];

  List<SiteProject> get projectsByRecency {
    final list = List<SiteProject>.from(projects);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  bool get hasPremiumProject => projects.any((p) => p.isPremium);

  final List<File> pickedImages = [];

  String qtGeneratedCode = '';
  Map<String, String> qtGeneratedFiles = {};
  String? qtActiveFileName;
  SiteMode qtSiteMode = SiteMode.single;
  String? qtCurrentProjectId;

  ProjectKind? qtCurrentKind;

  Map<String, dynamic> qtFormData = {};

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

  void setQtSiteMode(SiteMode mode) {
    qtSiteMode = mode;
    notifyListeners();
    _savePrefString(_qtSiteModePrefsKey, mode.name);
  }

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

  static const _freeSitePublishUsedPrefsKey = 'free_site_publish_used';
  static const _extraPublishCreditsPrefsKey = 'extra_publish_credits';
  bool freeSitePublishUsed = false;
  int extraPublishCredits = 0;

  static const _giftPublishCreditsPrefsKey = 'gift_publish_credits';
  int giftPublishCredits = 0;

  Future<void> addGiftPublishCredit() async {
    giftPublishCredits += 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftPublishCreditsPrefsKey, giftPublishCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  static const _giftWatermarkRemovalCreditsPrefsKey = 'gift_watermark_removal_credits';
  static const _giftDownloadWatermarkedCreditsPrefsKey = 'gift_download_watermarked_credits';
  static const _giftDownloadCleanCreditsPrefsKey = 'gift_download_clean_credits';
  int giftWatermarkRemovalCredits = 0;
  int giftDownloadWatermarkedCredits = 0;
  int giftDownloadCleanCredits = 0;

  static const _giftDomainConnectCreditsPrefsKey = 'gift_domain_connect_credits';
  static const _giftMiniPackageCreditsPrefsKey = 'gift_mini_package_credits';
  int giftDomainConnectCredits = 0;
  int giftMiniPackageCredits = 0;

  Future<void> addGiftWatermarkRemovalCredit(int amount) async {
    if (amount <= 0) return;
    giftWatermarkRemovalCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftWatermarkRemovalCreditsPrefsKey, giftWatermarkRemovalCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  Future<void> addGiftDownloadWatermarkedCredit(int amount) async {
    if (amount <= 0) return;
    giftDownloadWatermarkedCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDownloadWatermarkedCreditsPrefsKey, giftDownloadWatermarkedCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  Future<void> addGiftDownloadCleanCredit(int amount) async {
    if (amount <= 0) return;
    giftDownloadCleanCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDownloadCleanCreditsPrefsKey, giftDownloadCleanCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  Future<void> addGiftDomainConnectCredit(int amount) async {
    if (amount <= 0) return;
    giftDomainConnectCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDomainConnectCreditsPrefsKey, giftDomainConnectCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  Future<void> addGiftMiniPackageCredit(int amount) async {
    if (amount <= 0) return;
    giftMiniPackageCredits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftMiniPackageCreditsPrefsKey, giftMiniPackageCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  Future<bool> redeemGiftWatermarkRemoval(String projectId) async {
    if (giftWatermarkRemovalCredits <= 0) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx != -1 && projects[idx].watermarkRemoved) return true;

    giftWatermarkRemovalCredits -= 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftWatermarkRemovalCreditsPrefsKey, giftWatermarkRemovalCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());

    await removeWatermarkForProject(projectId);
    return true;
  }

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

  Future<bool> redeemGiftDownloadClean(String projectId) async {
    if (giftDownloadCleanCredits <= 0) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx != -1 &&
        projects[idx].downloadPurchased &&
        (projects[idx].watermarkRemoved || projects[idx].downloadWatermarkFree)) {
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

  Future<bool> redeemGiftDomainConnect() async {
    if (giftDomainConnectCredits <= 0) return false;
    giftDomainConnectCredits -= 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_giftDomainConnectCreditsPrefsKey, giftDomainConnectCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
    return true;
  }

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

  bool canPublishProject(SiteProject project) {
    if (project.publishRightGranted) return true;
    if (project.subscriptionQuotaExpiresAt != null) return true;
    final tier = activeSubscriptionTier;
    if (tier != null && subscriptionQuotaUsed < tier.siteQuota) return true;
    if (!freeSitePublishUsed) return true;
    return (giftPublishCredits + extraPublishCredits) > 0;
  }

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

  Future<void> addPurchasedPublishCredit() async {
    extraPublishCredits += 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_extraPublishCreditsPrefsKey, extraPublishCredits);
    unawaited(_syncAccountStateToCloudIfSignedIn());
  }

  static const _activeSubscriptionProductIdPrefsKey = 'active_subscription_product_id';
  static const _activeSubscriptionExpiresAtPrefsKey = 'active_subscription_expires_at';
  String? activeSubscriptionProductId;
  DateTime? activeSubscriptionExpiresAt;

  SubscriptionTierInfo? get activeSubscriptionTier {
    if (!hasActiveSubscription) return null;
    return kSubscriptionTierByProductId[activeSubscriptionProductId];
  }

  bool get hasActiveSubscription =>
      activeSubscriptionProductId != null &&
      activeSubscriptionExpiresAt != null &&
      ServerTimeService.now().isBefore(activeSubscriptionExpiresAt!);

  List<SiteProject> get subscriptionQuotaProjects =>
      projects.where((p) => p.subscriptionQuotaExpiresAt != null).toList();

  int get subscriptionQuotaUsed => subscriptionQuotaProjects.length;

  bool get hasSubscriptionQuotaOverflow =>
      subscriptionQuotaUsed > (activeSubscriptionTier?.siteQuota ?? 0);

  List<SiteProject> get domainQuotaProjects =>
      projects.where((p) => p.domainViaSubscription).toList();

  int get domainQuotaUsed => domainQuotaProjects.length;

  bool get hasDomainQuotaOverflow =>
      domainQuotaUsed > (activeSubscriptionTier?.domainQuota ?? 0);

  bool canConnectDomainViaSubscription(SiteProject project) {
    if (project.domainViaSubscription) return true;
    final tier = activeSubscriptionTier;
    if (tier == null) return false;
    return domainQuotaUsed < tier.domainQuota;
  }

  Future<bool> assignDomainQuota(String projectId) async {
    final tier = activeSubscriptionTier;
    if (tier == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    if (projects[idx].domainViaSubscription) return true;
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
      }
      await clearProjectDomain(projectId);
    }
  }

  Future<List<String>> autoResolveDomainQuotaOverflow() async {
    final allowed = activeSubscriptionTier?.domainQuota ?? 0;
    final quota = domainQuotaProjects;
    if (quota.length <= allowed) return const [];

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

  Future<void> refreshSubscriptionStatus() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final status = await SubscriptionService.fetchStatus(uid);
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

  Future<bool> assignProjectToSubscriptionQuota(String projectId) async {
    final tier = activeSubscriptionTier;
    if (tier == null) return false;
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    if (projects[idx].subscriptionQuotaExpiresAt != null) return true;
    if (subscriptionQuotaUsed >= tier.siteQuota) return false;

    projects[idx] = projects[idx].copyWith(
      subscriptionQuotaExpiresAt: activeSubscriptionExpiresAt,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));

    await removeWatermarkForProject(projectId, viaSubscription: true);

    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(
        SubscriptionQuotaSyncService.assign(siteId: projectId, uid: uid, ownerToken: projects[idx].ownerToken).catchError((_) {}),
      );
    }
    return true;
  }

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

  Future<List<String>> autoResolveSubscriptionQuotaOverflow() async {
    final allowed = activeSubscriptionTier?.siteQuota ?? 0;
    final quota = subscriptionQuotaProjects;
    if (quota.length <= allowed) return const [];

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

  Future<void> _forceUnpublishAndUnassignQuota(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    final p = projects[idx];
    if (p.isPublished) {
      try {
        await HostingService.unpublish(siteId: projectId, ownerToken: p.ownerToken);
      } catch (_) {
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

  Future<void> _reconcileSubscriptionQuota() async {
    if (!hasActiveSubscription) return;
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
    await _backfillSubscriptionQuota();
  }

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

  StreamSubscription<User?>? _authSub;

  String? _lastKnownUid;
  bool _authListenerFired = false;

  AppState() {
    unawaited(_loadFromPrefs().then((_) => _syncAnalyticsUserProperties()));
    _authSub = AuthService.instance.authStateChanges.listen(_onAuthChanged);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthChanged(User? user) async {
    final previousUid = _lastKnownUid;
    final isFirstEmission = !_authListenerFired;
    _authListenerFired = true;
    _lastKnownUid = user?.uid;

    if (user == null) {
      if (!isFirstEmission && previousUid != null) {
        await _resetToGuestDefaults();
      }
      return;
    }

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

      final cloudProjects = await UserDataService.instance.fetchProjects(user.uid);
      final toReupload = _mergeCloudProjects(cloudProjects);

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

      for (final project in toReupload) {
        unawaited(_syncProjectToCloudIfSignedIn(project));
      }

      unawaited(_flushPendingProjectSyncs());

      unawaited(refreshSubscriptionStatus());
    } catch (_) {
    }

    unawaited(_flushPendingActivations());
  }

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
    _pendingActivations.clear();
    await prefs.remove(_pendingActivationsPrefsKey);
  }

  List<SiteProject> _mergeCloudProjects(List<Map<String, dynamic>> cloudProjects) {
    final cloudById = <String, SiteProject>{};
    for (final raw in cloudProjects) {
      try {
        final p = SiteProject.fromJson(raw);
        cloudById[p.id] = p;
      } catch (_) {
      }
    }

    final merged = <String, SiteProject>{};
    final reupload = <SiteProject>[];

    for (final local in projects) {
      final cloud = cloudById.remove(local.id);
      if (cloud == null) {
        merged[local.id] = local;
        reupload.add(local);
      } else if (local.updatedAt.isAfter(cloud.updatedAt)) {
        merged[local.id] = local;
        reupload.add(local);
      } else {
        merged[local.id] = cloud;
      }
    }
    for (final cloud in cloudById.values) {
      merged[cloud.id] = cloud;
    }

    projects = merged.values.toList();
    return reupload;
  }

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
    }
  }

  Future<bool> _syncProjectToCloudIfSignedIn(SiteProject project) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return true;

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
      return false;
    }
  }

  Future<void> _flushPendingProjectSyncs() async {
    if (_pendingProjectSync.isEmpty) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    for (final id in List<String>.from(_pendingProjectSync)) {
      final idx = projects.indexWhere((p) => p.id == id);
      if (idx == -1) {
        _pendingProjectSync.remove(id);
        unawaited(_persistPendingProjectSync());
        continue;
      }
      await _syncProjectToCloudIfSignedIn(projects[idx]);
    }
  }

  Future<void> _deleteProjectFromCloudIfSignedIn(String projectId) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await UserDataService.instance.deleteProject(
        uid: user.uid,
        projectId: projectId,
      );
    } catch (_) {
    }
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await _migrateLegacyPrefValue(prefs, _qtGeneratedCodePrefsKey, _qtGeneratedCodeFile);
    await _migrateLegacyPrefValue(prefs, _qtGeneratedFilesPrefsKey, _qtGeneratedFilesFile);
    await _migrateLegacyPrefValue(prefs, _qtFormDataPrefsKey, _qtFormDataFile);
    await _migrateLegacyPrefValue(prefs, _projectsPrefsKey, _projectsFile);

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

    _pendingProjectSync
      ..clear()
      ..addAll(prefs.getStringList(_pendingProjectSyncPrefsKey) ?? const []);

    _pendingActivations.clear();
    for (final raw in prefs.getStringList(_pendingActivationsPrefsKey) ?? const <String>[]) {
      final entry = PendingActivation.tryParse(raw);
      if (entry != null) _pendingActivations[entry.key] = entry;
    }

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

    unawaited(revertExpiredDomainWatermarks());
    unawaited(revertExpiredMiniPackages());
    unawaited(revertExpiredSubscriptionQuota());
    unawaited(refreshSubscriptionStatus());
    unawaited(checkPendingTransferClaims());
    unawaited(_flushPendingActivations());
  }

  Future<void> _persistPendingProjectSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingProjectSyncPrefsKey, _pendingProjectSync.toList());
  }

  Future<void> _queueWorkerActivation(String kind, String siteId) async {
    final entry = PendingActivation(kind, siteId, DateTime.now());
    _pendingActivations[entry.key] = entry;
    try {
      await _persistPendingActivations();
    } catch (_) {
    }
    await _flushPendingActivations();
  }

  Future<void> _flushPendingActivations() async {
    if (_pendingActivations.isEmpty) return;
    if (_flushingActivations) {
      _activationFlushRequested = true;
      return;
    }
    _flushingActivations = true;
    try {
      var round = 0;
      Set<String>? onlyKeys;
      while (true) {
        _activationFlushRequested = false;
        final soonKeys = await _flushActivationsOnce(onlyKeys);
        if (_activationFlushRequested) {
          round = 0;
          onlyKeys = null;
          continue;
        }
        if (soonKeys.isEmpty || round >= _activationRetryDelays.length) break;
        await Future<void>.delayed(_activationRetryDelays[round]);
        round++;
        onlyKeys = _activationFlushRequested ? null : soonKeys;
      }
    } catch (_) {
    } finally {
      _flushingActivations = false;
    }
  }

  Future<Set<String>> _flushActivationsOnce(Set<String>? onlyKeys) async {
    final soonKeys = <String>{};
    for (final entry in List<PendingActivation>.from(_pendingActivations.values)) {
      if (onlyKeys != null && !onlyKeys.contains(entry.key)) continue;

      final idx = projects.indexWhere((p) => p.id == entry.siteId);
      if (idx == -1 || DateTime.now().difference(entry.queuedAt) > _activationMaxAge) {
        await _dropActivation(entry);
        continue;
      }
      final project = projects[idx];
      if (entry.kind == PendingActivation.kindMini && project.isMiniPackageExpired) {
        await _dropActivation(entry);
        continue;
      }

      final retry = await _attemptActivation(entry, project);
      if (retry == null || retry == SyncRetry.never) {
        await _dropActivation(entry);
      } else if (retry == SyncRetry.soon) {
        soonKeys.add(entry.key);
      }
    }
    return soonKeys;
  }

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
          return SyncRetry.never;
      }
    } on MiniPackageException catch (e) {
      return e.retry;
    } on WatermarkSyncException catch (e) {
      return e.retry;
    } on HostingNotConfiguredException {
      return SyncRetry.never;
    } catch (_) {
      return SyncRetry.later;
    }
  }

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

  Future<void> _persistPendingTransferCodes() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pendingTransferCodes.isEmpty) {
      await prefs.remove(_pendingTransferCodesPrefsKey);
    } else {
      await prefs.setString(_pendingTransferCodesPrefsKey, jsonEncode(_pendingTransferCodes));
    }
  }

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

  void _syncAnalyticsUserProperties() {
    try {
      var plan = 'free';
      if (activeSubscriptionTier != null) {
        final id = activeSubscriptionProductId;
        if (id == kProductSubBaslangic) {
          plan = 'baslangic';
        } else if (id == kProductSubMini) {
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
    }
  }

  Future<void> deleteProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    final wasPublished = idx != -1 && projects[idx].isPublished;
    if (idx != -1 && projects[idx].isPublished) {
      try {
        await HostingService.unpublish(siteId: id, ownerToken: projects[idx].ownerToken);
      } catch (_) {
      }
    }
    projects.removeWhere((p) => p.id == id);
    AnalyticsService.logSiteDeleted(wasPublished: wasPublished);
    _syncAnalyticsUserProperties();
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

  Future<void> setGoogleVerification(String projectId, String? code) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    final trimmed = (code ?? '').trim();
    await GoogleVerificationService.setCode(
      siteId: projectId,
      code: trimmed.isEmpty ? null : trimmed,
      ownerToken: projects[idx].ownerToken,
    );
    final i2 = projects.indexWhere((p) => p.id == projectId);
    if (i2 == -1) return;
    projects[i2] = trimmed.isEmpty
        ? projects[i2].copyWith(clearGoogleVerification: true, updatedAt: DateTime.now())
        : projects[i2].copyWith(googleVerificationCode: trimmed, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[i2]));
  }

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
        if (idx == -1 || !projects[idx].isPublished) continue;
        removedNames.add(projects[idx].name);
        projects[idx] = projects[idx].copyWith(
          unpublish: true,
          clearDomain: true,
          domainViaSubscription: false,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        await _persistProjects();
        unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
        await unassignProjectFromSubscriptionQuota(id);
      }
      if (removedNames.isNotEmpty && !projects.any((pp) => pp.isPublished)) {
        try {
          await NotificationService.instance.cancelDailyVisitorCheckIn();
        } catch (_) {}
      }
      return removedNames;
    } catch (_) {
      return const [];
    } finally {
      _serverReconcileRunning = false;
    }
  }

  Future<void> setDownloadContactEmail(String id, String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(leadEmail: trimmed, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
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
    );
    projects.insert(0, copy);
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(copy));
    return copy;
  }

  Future<TransferInitiateResult> initiateProjectTransfer(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) {
      throw TransferException('Proje bulunamadı.');
    }
    final project = projects[idx];
    final authHeaders = await authHeaderIfSignedIn();
    final prep = await TransferImages.prepareSnapshot(
      project.toJson(),
      upload: (dataUri) => PublishImageService.uploadOne(
        dataUri: dataUri,
        endpoint: Uri.parse('${HostingConfig.baseUrl}/api/publish-image'),
        siteId: project.id,
        ownerToken: project.ownerToken,
        authHeaders: authHeaders,
      ),
      stripAll: UserDataService.instance.stripImagesForExport,
      optimize: ImageCompressService.optimizeEmbeddedImages,
    );
    final snapshot = prep.snapshot;
    final result = await TransferService.initiate(
      siteId: project.id,
      ownerToken: project.ownerToken,
      projectSnapshot: snapshot,
    );
    _pendingTransferCodes[project.id] = {
      'code': result.code,
      'expiresAt': result.expiresAt.toIso8601String(),
    };
    unawaited(_persistPendingTransferCodes());
    return result;
  }

  Future<TransferClaimOutcome> claimTransferredProject(
    String code, {
    bool claimDomainViaOwnSubscription = false,
    bool claimDomainViaPurchase = false,
    bool claimQuotaViaOwnSubscription = false,
  }) async {
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
    var snapshot = Map<String, dynamic>.from(result.projectSnapshot);
    final imageRestore = await TransferImages.restore(
      snapshot,
      siteBase: TransferImages.trustedSiteBase(
        workerBaseUrl: HostingConfig.baseUrl,
        slug: snapshot['publishedSubdomain'] as String?,
      ),
      download: (url) async {
        final res = await http.get(url).timeout(const Duration(seconds: 30));
        return res.statusCode == 200 ? res.bodyBytes : null;
      },
    );
    snapshot = Map<String, dynamic>.from(imageRestore.snapshot);
    snapshot['ownerToken'] = result.ownerToken;
    snapshot.remove('googleVerificationCode');
    var claimed = SiteProject.fromJson(snapshot).copyWith(updatedAt: DateTime.now());

    final wasSubscriptionPremium = claimed.watermarkRemovedBySubscription;
    switch (result.quotaOutcome) {
      case 'kept_via_subscription':
        claimed = claimed.copyWith(
          subscriptionQuotaExpiresAt: activeSubscriptionExpiresAt,
          watermarkRemoved: true,
          watermarkRemovedBySubscription: true,
        );
        break;
      default:
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

    switch (result.domainOutcome) {
      case 'kept_via_subscription':
        claimed = claimed.copyWith(domainViaSubscription: true);
        break;
      case 'kept_via_purchase':
        claimed = claimed.copyWith(domainViaSubscription: false);
        break;
      default:
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

    if (result.quotaOutcome != 'kept_via_subscription') {
      unawaited(SubscriptionQuotaSyncService.unassign(siteId: claimed.id, ownerToken: claimed.ownerToken).catchError((_) {}));
    }

    if (result.quotaOutcome != 'kept_via_subscription' && hasActiveSubscription) {
      unawaited(assignProjectToSubscriptionQuota(claimed.id));
    }

    final premiumLost = wasSubscriptionPremium && result.quotaOutcome != 'kept_via_subscription';
    return TransferClaimOutcome(
      project: claimed,
      premiumLost: premiumLost,
      domainOutcome: result.domainOutcome,
      missingImages: imageRestore.missing,
    );
  }

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
        unawaited(_queueWorkerActivation(PendingActivation.kindWatermark, id));
      }
      return;
    }

    projects[idx] = project.copyWith(
      watermarkRemoved: true,
      watermarkRemovedByDomain: viaDomain,
      watermarkRemovedByMiniPackage: viaMiniPackage,
      watermarkRemovedBySubscription: viaSubscription,
      code: WatermarkService.strip(project.code),
      files: WatermarkService.stripFromFiles(project.files),
      updatedAt: DateTime.now(),
    );
    if (!viaDomain && !viaMiniPackage && !viaSubscription) {
      unawaited(_queueWorkerActivation(PendingActivation.kindWatermark, id));
    }

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

  Future<void> unlockDownloadForProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final project = projects[idx];
    if (project.downloadPurchased) return;

    projects[idx] = project.copyWith(
      downloadPurchased: true,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

  Future<void> unlockDownloadWithoutWatermark(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final project = projects[idx];
    if (project.downloadPurchased &&
        (project.watermarkRemoved || project.downloadWatermarkFree)) {
      return;
    }

    projects[idx] = project.copyWith(
      downloadPurchased: true,
      downloadWatermarkFree: true,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

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


  Future<void> markProjectPublished({
    required String id,
    required String subdomain,
    required String url,
    String? ownerToken,
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
    await _syncProjectToCloudIfSignedIn(projects[idx]);
    await grantPublishRight(id);
    unawaited(_flushPendingActivations());
    try {
      await NotificationService.instance.scheduleDailyVisitorCheckIn();
    } catch (_) {}
  }

  Future<void> markProjectUnpublished(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
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
    await unassignProjectFromSubscriptionQuota(id);
    if (!projects.any((p) => p.isPublished)) {
      try {
        await NotificationService.instance.cancelDailyVisitorCheckIn();
      } catch (_) {}
    }
  }

  Future<void> markDomainConnectPurchased(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(domainConnectPurchasePending: true);
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

  bool hasPendingDomainConnectPurchase(String projectId) {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].domainConnectPurchasePending;
  }

  Future<void> markDomainRenewPurchased(String projectId) async {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(domainRenewPurchasePending: true);
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

  bool hasPendingDomainRenewPurchase(String projectId) {
    final idx = projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return false;
    return projects[idx].domainRenewPurchasePending;
  }

  Future<void> markProjectDomainStatus({
    required String id,
    required String domain,
    required String status,
  }) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final existing = projects[idx];
    final isNewActivation = status == 'active' &&
        (existing.domainConnectedAt == null ||
            existing.customDomain != domain ||
            existing.domainStatus != 'active');
    projects[idx] = existing.copyWith(
      customDomain: domain,
      domainStatus: status,
      domainConnectedAt: isNewActivation ? DateTime.now() : null,
      domainConnectPurchasePending: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));

    if (isNewActivation) {
      await removeWatermarkForProject(id, viaDomain: true);
    }
  }

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

    unawaited(_queueWorkerActivation(PendingActivation.kindMini, id));

    try {
      final expiresAt = projects[idx].miniPackageExpiresAt;
      if (expiresAt != null) {
        await NotificationService.instance.scheduleMiniPackageExpiryReminder(
          projectId: id,
          expiresAt: expiresAt,
        );
      }
    } catch (_) {
    }

    await removeWatermarkForProject(id, viaMiniPackage: true);
  }

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

  Future<void> renewProjectDomain(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final result = await DomainService.renew(siteId: id, ownerToken: projects[idx].ownerToken);
    final refreshedIdx = projects.indexWhere((p) => p.id == id);
    if (refreshedIdx == -1) return;
    projects[refreshedIdx] = projects[refreshedIdx].copyWith(
      domainConnectedAt: result.domainConnectedAt,
      domainRenewPurchasePending: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[refreshedIdx]));
  }

  Future<void> clearProjectDomain(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    projects[idx] = projects[idx].copyWith(clearDomain: true, updatedAt: DateTime.now());
    notifyListeners();
    await _persistProjects();
    unawaited(_syncProjectToCloudIfSignedIn(projects[idx]));
  }

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

  Future<void> markProjectExported({String? projectNameOverride}) async {
    if (qtCurrentProjectId == null) return;
    final idx = projects.indexWhere((p) => p.id == qtCurrentProjectId);
    if (idx == -1) return;
    final project = projects[idx];
    try {
      await NotificationService.instance.scheduleProjectUpdateReminder(
        projectId: project.id,
        projectName: projectNameOverride ?? project.name,
      );
    } catch (_) {
    }
  }
}
