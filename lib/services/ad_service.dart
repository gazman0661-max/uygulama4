import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../localization/app_strings.dart';
import '../widgets/rewarded_prompt.dart';
import '../widgets/ui_kit.dart';
import 'analytics_service.dart';
import 'remote_tuning.dart';
import 'music_service.dart';

import 'log_service.dart';
/// Odullu (rewarded) + gecis (interstitial) reklam servisi - Unity LevelPlay
/// (ironSource) mediation, Flutter eklentisi: unity_levelplay_mediation.
/// Eski Appodeal yapisinin yerine gecti; DISARIYA ACIK API AYNI KALDI
/// (watchRewardedAd, notifyChapterCompleted, isRewardedReady, ...).
///
/// KULLANIM:
///  - main()/onay sonrasi: [initializeSdk] (BEKLENMEZ, hata firlatmaz).
///  - Odullu: `final ok = await watchRewardedAd(context);` (true = odul ver).
///  - Gecis: bolum bitip oyuncu sonraki ekrana gecerken
///    `await AdService.instance.notifyChapterCompleted();`
///  - GDPR: AB/AEA/UK'de yasal pencerenin acik onay kutusu LevelPlay'e
///    `setGDPRConsent` ile iletilir. Ayarlardaki buton [openAdConsentForm]
///    onayi acip kapatir.
///
/// ID'LER BOS: asagidaki 3 sabiti LevelPlay panelinden alip doldurana kadar
/// reklam SDK'si hic baslamaz, odullu reklamlar eski "simulasyon" davranisini
/// gosterir (oyun calisir, reklam cikmaz).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ------------------------------------------------------------ KIMLIKLER (SONRA DOLDUR)

  /// LevelPlay panelindeki uygulama anahtari (App Key). Android icin.
  static const String levelPlayAppKey = '28faacafd';

  /// LevelPlay panelinde olusturulan "Rewarded" ad unit kimligi (rewarded_main).
  static const String rewardedAdUnitId = 'arctdjwo7w7b1lpn';

  /// LevelPlay panelinde olusturulan "Interstitial" ad unit kimligi (interstitial_main).
  static const String interstitialAdUnitId = '134p1mefcdem0uad';

  /// Hata ayiklama: true iken adaptor loglari acik olur ve entegrasyon
  /// dogrulamasi (validateIntegration) calisir. LevelPlay'de "test reklami"
  /// paneldeki Test Suite / test cihazi ekleme ile yapilir, kodda bayrak yok.
  /// Canliya cikmadan false olsun.
  static const bool testingMode = false;

  /// Reklam yuklenemediginde (doluluk yok / SDK hazir degil) odul VERILSIN mi?
  /// v216: HAYIR. Reklam yoksa odul yok; oyuncuya "Reklam bulunamadi, tekrar dene"
  /// popup'i gosterilir (eskiden bedava odul veriliyordu: reklam alanlarini engelleyen
  /// oyuncu her odulu bedava aliyordu ve gelir kaybediliyordu).
  static const bool rewardOnNoFill = false;

  /// Iki odullu reklam arasindaki bekleme (saniye, ayni yer icin). Remote Config: ad_cooldown_sec.
  /// Ana sayfa / magaza "bedava elmas" reklami HARIC (zaten 2 saatlik penceresi var).
  static int get cooldownSeconds => RemoteTuning.i('ad_cooldown_sec', 60);

  /// Bekleme uygulanmayan yerler.
  static const Set<String> _cooldownExempt = {'free_gems'};

  /// Ilk N bolum boyunca gecis reklami GOSTERILMEZ (yeni oyuncu ilk
  /// oturumda reklamla karsilasip kacmasin - eski oyundaki D1 duzeltmesi).
  static int get interstitialGraceChapters => RemoteTuning.i('inter_grace_chapters', 6);

  /// Grace bittikten sonra kac bolumde bir gecis reklami.
  static int get chaptersPerInterstitial => RemoteTuning.i('inter_every_chapters', 3);

  static const String _kLifetimeChapters = 'ad_lifetime_chapters_completed_v1';
  static const String _kGdprPref = 'legal_gdpr_consent_v1';

  static bool get _configured => levelPlayAppKey.isNotEmpty && !kIsWeb && Platform.isAndroid;
  static bool get _rewardedOn => _configured && rewardedAdUnitId.isNotEmpty;
  static bool get _interstitialOn => _configured && interstitialAdUnitId.isNotEmpty;

  /// Baslatma hatalari (bos = sorun yok). Teshis icin.
  List<String> lastInitErrors = const [];

  bool _sdkInitialized = false;
  bool get sdkInitialized => _sdkInitialized;
  bool _initStarted = false;

  LevelPlayRewardedAd? _rewardedAd;
  LevelPlayInterstitialAd? _interstitialAd;

  Completer<bool>? _pendingCompleter;
  Completer<void>? _pendingInterstitialCompleter;
  bool _adStartedShowing = false;
  bool _noFill = false; // son odullu istekte reklam bulunamadi / gosterilemedi (popup icin)
  bool _rewardGranted = false;
  Timer? _notShownWatchdog;
  int _chaptersSinceInterstitial = 0;
  int? _lifetimeCache;

  // Yukleme tekrar denemeleri (doluluk yoksa 15/30/60/120 sn aralikla).
  Timer? _rewardedRetry;
  Timer? _interstitialRetry;
  int _rewardedRetries = 0;
  int _interstitialRetries = 0;
  DateTime? _rewardedLoadAt;
  DateTime? _interstitialLoadAt;

  // ------------------------------------------------------------ baslatma

  /// LevelPlay'i kurar. BEKLENMEZ; hata olursa oyun etkilenmez.
  /// [gdprApplies]: cihaz AB/AEA/UK bolgesinde mi; [gdprConsent]: acik onay.
  Future<void> initializeSdk({bool gdprApplies = false, bool gdprConsent = false}) async {
    if (_initStarted || !_configured) return;
    _initStarted = true;
    try {
      AppLog.i('ads', 'LevelPlay.init basliyor');
      final debug = testingMode || !kReleaseMode;
      // Gizlilik ayarlari init'ten ONCE verilmelidir.
      if (gdprApplies) {
        try {
          await LevelPlayPrivacySettings.setGDPRConsent(gdprConsent);
        } catch (err) { AppLog.w('ad_service.initializeSdk', 'GDPR bayragi verilemedi', err); }
      }
      if (debug) {
        try {
          await LevelPlay.setAdaptersDebug(true);
          LevelPlay.validateIntegration(); // beklenmez; sonuc Logcat'te
        } catch (err) { AppLog.w('ad_service.initializeSdk', 'debug acilamadi', err); }
      }
      final request = LevelPlayInitRequest.builder(levelPlayAppKey).build();
      await LevelPlay.init(initRequest: request, initListener: _InitListener(this));
    } catch (err) {
      _initStarted = false;
      lastInitErrors = [err.toString()];
      AppLog.w('ad_service.initializeSdk', 'yutulan hata', err);
      // SDK baslamazsa oyun reklamsiz/simule calismaya devam eder.
    }
  }

  void _onInitSuccess() {
    AppLog.i('ads', 'LevelPlay init tamam');
    AnalyticsService.instance.log('ad_init_ok', {});
    lastInitErrors = const [];
    try {
      if (_rewardedOn) {
        _rewardedAd = LevelPlayRewardedAd(adUnitId: rewardedAdUnitId)
          ..setListener(_RewardedListener(this));
      }
      if (_interstitialOn) {
        _interstitialAd = LevelPlayInterstitialAd(adUnitId: interstitialAdUnitId)
          ..setListener(_InterstitialListener(this));
      }
    } catch (err) { AppLog.w('ad_service._onInitSuccess', 'reklam nesnesi kurulamadi', err); }
    _sdkInitialized = true;
    unawaited(preload());
    unawaited(preloadInterstitial());
  }

  void _onInitFailed(String error) {
    _initStarted = false; // sonraki acilista tekrar denenebilsin
    lastInitErrors = [error];
    debugPrint('AdService: LevelPlay init error: $error');
    AppLog.e('ads', 'LevelPlay init hatasi: $error');
    AnalyticsService.instance.log('ad_init_errors', {
      'count': 1,
      'first': error.length > 90 ? error.substring(0, 90) : error,
    });
  }

  /// Ayarlardaki "Reklam Rizasi" butonu: kisisellestirilmis reklam icin onayi
  /// acip kapatma penceresi. Secim saklanir ve LevelPlay'e iletilir.
  Future<void> openAdConsentForm(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getBool(_kGdprPref) ?? false;
      if (!context.mounted) return;
      final s = AppStrings.instance;
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => GameAlertDialog(
          title: Text(s.lt('Manage Ad Consent')),
          content: Text(s.lt(current
              ? 'Ad consent is currently ON. You can withdraw it here.'
              : 'Ad consent is currently OFF. You can allow it here.')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(!current),
              child: Text(s.lt(current ? 'Withdraw consent' : 'Allow')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(s.lt('Close')),
            ),
          ],
        ),
      );
      if (result == null) return;
      await prefs.setBool(_kGdprPref, result);
      if (_configured) {
        try {
          await LevelPlayPrivacySettings.setGDPRConsent(result);
        } catch (err) { AppLog.w('ad_service.openAdConsentForm', 'bayrak verilemedi', err); }
      }
      AnalyticsService.instance.log('ad_consent_changed', {'on': result ? 1 : 0});
    } catch (err) { AppLog.w('ad_service.openAdConsentForm', 'yutulan hata', err); }
  }

  // ------------------------------------------------------------ callback'ler

  String _curPlacement = 'none'; // su an gosterilen odullu reklamin yeri (analitik)

  // --- odullu
  void _onRewardedLoaded(LevelPlayAdInfo info) {
    _rewardedRetries = 0;
    _rewardedLoadAt = null;
    AppLog.i('ads', 'rewarded YUKLENDI $info');
  }

  void _onRewardedLoadFailed(LevelPlayAdError error) {
    _rewardedLoadAt = null;
    AppLog.w('ads', 'rewarded YUKLENEMEDI (doluluk yok / ag hatasi / SDK hatasi): $error');
    _scheduleRewardedReload();
  }

  void _onRewardedDisplayed(LevelPlayAdInfo info) {
    AppLog.i('ads', 'rewarded GOSTERILDI yer=$_curPlacement');
    AnalyticsService.instance.log('ad_rew_impression', {'placement': _curPlacement});
    _adStartedShowing = true;
    _notShownWatchdog?.cancel();
  }

  void _onRewardedDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo info) {
    AppLog.e('ads', 'rewarded GOSTERIM BASARISIZ yer=$_curPlacement: $error');
    // Gosterim hic baslayamadi: odul yok (rewardOnNoFill=false); popup _showRewardedNow'da cikar.
    AnalyticsService.instance.log('ad_rew_show_failed', {'placement': _curPlacement});
    _noFill = true;
    _finish(rewardOnNoFill);
    unawaited(preload());
  }

  void _onRewardedRewarded(LevelPlayReward reward, LevelPlayAdInfo info) {
    AppLog.i('ads', 'rewarded IZLENDI (odul hakki) yer=$_curPlacement odul=$reward');
    _rewardGranted = true;
    AnalyticsService.instance.log('ad_rew_completed', {'placement': _curPlacement});
    _finish(true);
  }

  void _onRewardedClosed(LevelPlayAdInfo info) {
    AppLog.i('ads', 'rewarded KAPANDI odulVerildi=$_rewardGranted yer=$_curPlacement');
    // Odul sadece reklam gercekten bittiyse verilir.
    if (!_rewardGranted) AnalyticsService.instance.log('ad_rew_skipped', {'placement': _curPlacement});
    _finish(_rewardGranted);
    unawaited(preload());
  }

  void _onRewardedClicked(LevelPlayAdInfo info) {
    AppLog.i('ads', 'rewarded TIKLANDI');
    AnalyticsService.instance.log('ad_rew_clicked', {'placement': _curPlacement});
  }

  // --- gecis
  void _onInterstitialLoaded(LevelPlayAdInfo info) {
    _interstitialRetries = 0;
    _interstitialLoadAt = null;
    AppLog.i('ads', 'interstitial YUKLENDI $info');
  }

  void _onInterstitialLoadFailed(LevelPlayAdError error) {
    _interstitialLoadAt = null;
    AppLog.w('ads', 'interstitial YUKLENEMEDI: $error');
    _scheduleInterstitialReload();
  }

  void _onInterstitialDisplayed(LevelPlayAdInfo info) {
    AppLog.i('ads', 'interstitial GOSTERILDI');
    AnalyticsService.instance.log('ad_inter_impression', {'chapters': _chaptersSinceInterstitial});
  }

  void _onInterstitialDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo info) {
    AppLog.e('ads', 'interstitial GOSTERIM BASARISIZ: $error');
    AnalyticsService.instance.log('ad_inter_show_failed');
    _finishInterstitial();
    unawaited(preloadInterstitial());
  }

  void _onInterstitialClosed(LevelPlayAdInfo info) {
    AppLog.i('ads', 'interstitial KAPANDI');
    _finishInterstitial();
    unawaited(preloadInterstitial());
  }

  void _onInterstitialClicked(LevelPlayAdInfo info) {
    AppLog.i('ads', 'interstitial TIKLANDI');
    AnalyticsService.instance.log('ad_inter_clicked');
  }

  void _finish(bool result) {
    _notShownWatchdog?.cancel();
    final c = _pendingCompleter;
    if (c != null && !c.isCompleted) c.complete(result);
  }

  void _finishInterstitial() {
    final c = _pendingInterstitialCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  // ------------------------------------------------------------ onbellek

  void _scheduleRewardedReload() {
    _rewardedRetry?.cancel();
    final step = _rewardedRetries > 3 ? 3 : _rewardedRetries;
    _rewardedRetries++;
    _rewardedRetry = Timer(Duration(seconds: 15 * (1 << step)), () => unawaited(preload()));
  }

  void _scheduleInterstitialReload() {
    _interstitialRetry?.cancel();
    final step = _interstitialRetries > 3 ? 3 : _interstitialRetries;
    _interstitialRetries++;
    _interstitialRetry = Timer(Duration(seconds: 15 * (1 << step)), () => unawaited(preloadInterstitial()));
  }

  static bool _recent(DateTime? t) => t != null && DateTime.now().difference(t).inSeconds < 25;

  Future<void> preload() async {
    final ad = _rewardedAd;
    if (!_sdkInitialized || ad == null) return;
    try {
      final loaded = await ad.isAdReady();
      AppLog.i('ads', 'preload rewarded: zatenYuklu=$loaded');
      if (loaded || _recent(_rewardedLoadAt)) return; // zaten yuklu ya da yukleme suruyor
      _rewardedLoadAt = DateTime.now();
      await ad.loadAd();
    } catch (err) { AppLog.w('ad_service.preload', 'yutulan hata', err); }
  }

  Future<void> preloadInterstitial() async {
    final ad = _interstitialAd;
    if (!_sdkInitialized || ad == null) return;
    try {
      final loaded = await ad.isAdReady();
      AppLog.i('ads', 'preload interstitial: zatenYuklu=$loaded');
      if (loaded || _recent(_interstitialLoadAt)) return;
      _interstitialLoadAt = DateTime.now();
      await ad.loadAd();
    } catch (err) { AppLog.w('ad_service.preloadInterstitial', 'yutulan hata', err); }
  }

  // ------------------------------------------------------------ gecis reklami

  Future<int> _lifetimeChapters() async {
    if (_lifetimeCache != null) return _lifetimeCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      return _lifetimeCache = prefs.getInt(_kLifetimeChapters) ?? 0;
    } catch (err) {
      AppLog.w('ad_service._lifetimeChapters', 'yutulan hata', err);
      return 0;
    }
  }

  Future<void> _bumpLifetimeChapters() async {
    final updated = (await _lifetimeChapters()) + 1;
    _lifetimeCache = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLifetimeChapters, updated);
    } catch (err) { AppLog.w('ad_service._bumpLifetimeChapters', 'yutulan hata', err); }
  }

  /// Oyuncu bolumu bitirip sonraki ekrana gecerken cagrilir. Grace bitince
  /// "N bolumde 1" gecis reklami gosterir ve KAPANANA kadar bekler (cagiran
  /// `await` etmeli). Reklam hazir degilse sessizce doner, sayac korunur.
  Future<void> notifyChapterCompleted() async {
    if (!_interstitialOn) return;
    await _bumpLifetimeChapters();
    final life = await _lifetimeChapters();
    AppLog.i('ads', 'notifyChapterCompleted: omurBolum=$life muaf<=${interstitialGraceChapters} sayac=$_chaptersSinceInterstitial/${chaptersPerInterstitial}');
    if (life <= interstitialGraceChapters) return;
    _chaptersSinceInterstitial++;
    if (_chaptersSinceInterstitial >= chaptersPerInterstitial) {
      await showInterstitialIfReady();
    }
  }

  Future<void> showInterstitialIfReady() async {
    final ad = _interstitialAd;
    if (!_sdkInitialized || ad == null) return;
    try {
      if (!await ad.isAdReady()) {
        AnalyticsService.instance.log('ad_inter_nofill'); // gosterilecekti ama reklam hazir degildi
        unawaited(preloadInterstitial());
        return; // sayac KORUNUR: hazir olunca sonraki firsatta gosterilir
      }
      _chaptersSinceInterstitial = 0;
      final c = Completer<void>();
      _pendingInterstitialCompleter = c;
      await MusicService.instance.suspendForAd();
      await ad.showAd();
      await c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    } catch (err) {
      AppLog.w('ad_service.showInterstitialIfReady', 'yutulan hata', err);
    } finally {
      unawaited(MusicService.instance.resumeAfterAd());
    }
  }

  // ------------------------------------------------------------ odullu reklam

  /// Cihaz GERCEKTEN internete cikabiliyor mu? (ucak modu ile bos donusten
  /// bedava odul almayi onlemek icin). Birkac domain denenir.
  Future<bool> _hasRealInternet() async {
    for (final host in const ['google.com', 'cloudflare.com', 'pub.dev']) {
      try {
        final r = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
        if (r.isNotEmpty && r.first.rawAddress.isNotEmpty) return true;
      } catch (err) { AppLog.w('ad_service._hasRealInternet', 'yutulan hata', err); }
    }
    return false;
  }

  /// Odullu reklam su an gosterilmeye hazir mi? (x2 coin butonu bunu kontrol eder;
  /// hazir degilse buton hic cikmaz.) ID girilmemisse (test) true doner.
  Future<bool> isRewardedReady() async {
    if (!_rewardedOn) return true;
    final ad = _rewardedAd;
    if (!_sdkInitialized || ad == null) return false;
    try {
      final ready = await ad.isAdReady();
      if (!ready) unawaited(preload());
      return ready;
    } catch (err) {
      AppLog.w('ad_service.isRewardedReady', 'yutulan hata', err);
      return false;
    }
  }

  /// Oyuncu istegiyle odullu reklam izledi: hemen ardindan gecis reklami
  /// gostermemek icin sayac sifirlanir.
  void resetInterstitialCounter() => _chaptersSinceInterstitial = 0;

  /// Reklami yukler/gosterir. true = odul verilmeli.
  ///
  /// [prompt] verilirse once ozel pencere (RewardedPrompt) cikar; oyuncu "Izle"ye
  /// basinca reklam acilir, "Vazgec" derse false doner (reklam hic acilmaz).
  Future<bool> showRewarded(BuildContext context, {bool strict = false, RewardedPrompt? prompt, String? placement}) async {
    final place = prompt?.placement ?? placement ?? 'generic';
    final key = _cooldownKey(place);
    final left = _cooldownLeft(key);
    if (left > 0) {
      AppLog.i('ads', 'showRewarded: BEKLEME yer=$place kalan=${left}sn');
      AnalyticsService.instance.log('ad_rew_cooldown', {'placement': place});
      if (context.mounted) {
        unawaited(showGamePopup(
          context,
          AppStrings.instance.lt('Please wait {0} seconds before watching another ad.', [left]),
          autoCloseMs: 0,
        ));
      }
      return false;
    }
    final ok = await _showRewardedInner(context, strict: strict, prompt: prompt, placement: placement);
    if (ok && key != null) _lastRewardedMs[key] = _mono.elapsedMilliseconds; // sayac reklam IZLENINCE baslar
    return ok;
  }

  // Bekleme sayaci: cihaz saatinden bagimsiz (monotonik) ve yer bazli.
  static final Stopwatch _mono = Stopwatch()..start();
  final Map<String, int> _lastRewardedMs = {};

  /// Bekleme anahtari; null = bu yerde bekleme yok. Ayni turden yerler (Salla/Degistir/Sil) tek sayac paylasir.
  String? _cooldownKey(String place) {
    if (_cooldownExempt.contains(place)) return null;
    if (place.startsWith('pe_power_')) return 'pe_power';
    return place;
  }

  /// [place] yeri icin odullu reklam beklemesinden kalan saniye (0 = hazir).
  /// Arayuz butonlarinda canli geri sayim gostermek icin.
  int cooldownLeftFor(String place) => _cooldownLeft(_cooldownKey(place));

  int _cooldownLeft(String? key) {
    if (key == null) return 0;
    final last = _lastRewardedMs[key];
    if (last == null) return 0;
    final passed = (_mono.elapsedMilliseconds - last) ~/ 1000;
    final left = cooldownSeconds - passed;
    return left > 0 ? left : 0;
  }

  Future<bool> _showRewardedInner(BuildContext context, {bool strict = false, RewardedPrompt? prompt, String? placement}) async {
    // placement: onay penceresi (prompt) olmadan da analitikte yer adi tutulsun (ornek: 'mb_energy').
    _curPlacement = prompt?.placement ?? placement ?? 'generic';
    AppLog.i('ads', 'showRewarded: yer=$_curPlacement strict=$strict sdkHazir=$_sdkInitialized initHata=${lastInitErrors.length}');
    if (prompt != null) {
      AnalyticsService.instance.log('ad_prompt_shown', {'placement': prompt.placement});
      final accepted = await showRewardedPrompt(context, prompt);
      if (!accepted || !context.mounted) {
        AnalyticsService.instance.log('ad_prompt_declined', {'placement': prompt.placement});
        return false;
      }
      AnalyticsService.instance.log('ad_prompt_accepted', {'placement': prompt.placement});
      final ok = await _showRewardedNow(context, strict: strict);
      AnalyticsService.instance.log(ok ? 'ad_rewarded_done' : 'ad_rewarded_fail', {'placement': prompt.placement});
      return ok;
    }
    return _showRewardedNow(context, strict: strict);
  }

  Future<bool> _showRewardedNow(BuildContext context, {bool strict = false}) async {
    if (!_rewardedOn) return _simulate(context);

    if (!await _hasRealInternet()) {
      AnalyticsService.instance.log('ad_rew_no_internet', {'placement': _curPlacement});
      if (context.mounted) {
        unawaited(showGamePopup(context, AppStrings.instance.t('ad_no_internet'), autoCloseMs: 2800));
      }
      return false;
    }
    if (!context.mounted) return false;

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AdLoadingDialog(),
    ));
    _noFill = false;
    final granted = await _loadAndShow(strict: strict);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!granted && _noFill && context.mounted) {
      // Reklam yok: odul verilmez, oyunun kendi popup'i "Tamam"a basilana kadar acik kalir.
      unawaited(showGamePopup(
        context,
        AppStrings.instance.lt('No ad found right now. Please try again.'),
        autoCloseMs: 0,
      ));
    }
    return granted;
  }

  Future<bool> _loadAndShow({bool strict = false}) async {
    // strict: reklam GERCEKTEN izlenmedikce odul yok (ornegin x2 coin). Doluluk yoksa false.
    final noFill = strict ? false : rewardOnNoFill;
    AppLog.i('ads', '_loadAndShow: strict=$strict nofillOdul=$noFill sdkHazir=$_sdkInitialized');
    final ad = _rewardedAd;
    if (!_sdkInitialized || ad == null) {
      AppLog.w('ads', '_loadAndShow: SDK HAZIR DEGIL -> odul=$noFill');
      _noFill = true;
      return noFill;
    }
    if (!await ad.isAdReady()) {
      _noFill = true;
      AnalyticsService.instance.log('ad_rew_nofill', {'placement': _curPlacement});
      AppLog.w('ads', '_loadAndShow: reklam HAZIR DEGIL (nofill) yer=$_curPlacement -> odul=$noFill');
      unawaited(preload());
      return noFill; // doluluk yok
    }
    _rewardGranted = false;
    _adStartedShowing = false;
    final completer = Completer<bool>();
    _pendingCompleter = completer;
    try {
      await MusicService.instance.suspendForAd();
      await ad.showAd();
    } catch (err) {
      AppLog.w('ad_service._loadAndShow', 'yutulan hata', err);
      _noFill = true;
      _finish(noFill);
    }
    // Guvenlik agi: 15 sn icinde "gosterildi" gelmezse takili kalma.
    // Reklam bir kez basladiysa bu zamanlayici iptal olur.
    _notShownWatchdog = Timer(const Duration(seconds: 15), () {
      if (!_adStartedShowing) {
        AppLog.e('ads', 'rewarded 15 sn icinde GOSTERILMEDI (watchdog) -> odul=$noFill');
        _noFill = true;
        _finish(noFill);
      }
    });
    try {
      return await completer.future;
    } finally {
      unawaited(MusicService.instance.resumeAfterAd());
    }
  }

  /// LevelPlay ID'leri girilene kadar eski test davranisi.
  Future<bool> _simulate(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AdLoadingDialog(),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();
    return true;
  }
}

// ---------------------------------------------------------------- dinleyiciler
// LevelPlay her reklam turu icin ayri dinleyici ister; hepsi AdService'e yonlendirir.

class _InitListener with LevelPlayInitListener {
  _InitListener(this._s);
  final AdService _s;

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) => _s._onInitSuccess();

  @override
  void onInitFailed(LevelPlayInitError error) => _s._onInitFailed(error.toString());
}

class _RewardedListener with LevelPlayRewardedAdListener {
  _RewardedListener(this._s);
  final AdService _s;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _s._onRewardedLoaded(adInfo);

  @override
  void onAdLoadFailed(LevelPlayAdError error) => _s._onRewardedLoadFailed(error);

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => _s._onRewardedDisplayed(adInfo);

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) => _s._onRewardedDisplayFailed(error, adInfo);

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) => _s._onRewardedClicked(adInfo);

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _s._onRewardedClosed(adInfo);

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) => _s._onRewardedRewarded(reward, adInfo);
}

class _InterstitialListener with LevelPlayInterstitialAdListener {
  _InterstitialListener(this._s);
  final AdService _s;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _s._onInterstitialLoaded(adInfo);

  @override
  void onAdLoadFailed(LevelPlayAdError error) => _s._onInterstitialLoadFailed(error);

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => _s._onInterstitialDisplayed(adInfo);

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) => _s._onInterstitialDisplayFailed(error, adInfo);

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) => _s._onInterstitialClicked(adInfo);

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _s._onInterstitialClosed(adInfo);

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}

/// Tum cagri noktalarinin kullandigi tek fonksiyon (eski watchMockRewardedAd'in yerine).
/// Her zaman once ozel "Izle" penceresi cikar ([prompt] verilmezse genel pencere).
Future<bool> watchRewardedAd(BuildContext context, {RewardedPrompt? prompt}) =>
    AdService.instance.showRewarded(
      context,
      prompt: prompt ?? const RewardedPrompt(reward: '🎁', placement: 'generic'),
    );

class _AdLoadingDialog extends StatelessWidget {
  const _AdLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GameAlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(child: Text(AppStrings.instance.t('ad_loading'))),
          ],
        ),
      ),
    );
  }
}
