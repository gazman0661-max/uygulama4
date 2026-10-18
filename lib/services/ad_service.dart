import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

import '../localization/app_strings.dart';
import '../widgets/rewarded_prompt.dart';
import '../widgets/ui_kit.dart';
import 'analytics_service.dart';
import 'remote_tuning.dart';
import 'music_service.dart';

import 'log_service.dart';
/// Odullu (rewarded) + gecis (interstitial) reklam servisi - Appodeal Mobile
/// Ads Flutter SDK (stack_appodeal_flutter). Eski oyundaki (AstroFelyx)
/// calisan yapidan tasindi; Worlds Merge'e uyarlandi.
///
/// KULLANIM:
///  - main(): [initializeSdk] (BEKLENMEZ, hata firlatmaz).
///  - Odullu: `final ok = await watchRewardedAd(context);` (true = odul ver).
///  - Gecis: bolum bitip oyuncu sonraki ekrana gecerken
///    `await AdService.instance.notifyChapterCompleted();`
///  - GDPR / AB rizasi: Appodeal'in KENDI resmi formu (Google UMP tabanli)
///    SDK baslayinca bolgeye gore OTOMATIK gosterilir; ayarlardaki buton
///    [openAdConsentForm] ile yeniden acar.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  /// Appodeal panelindeki App Key. Anahtar paket adina bagli: bu oyun artik
  /// com.sitora.ai paket adini kullanir. Anahtar eski paket (AstroFelyx) icindi,
  /// Appodeal panelinde com.sitora.ai icin YENI anahtar alip buraya yaz.
  static const String appodealAppKey = 'd2fe86eb918e83e44e5a04419ca4ea3b588b8a01f4a19940';

  /// TEST MODU: true iken Appodeal'in test reklamlari gelir (para kazanilmaz
  /// ama hesap da riske girmez). Play kapali testi sirasinda TEST kullanicilari
  /// gercek reklama tiklarsa "gecersiz trafik" sayilabilir -> test boyunca
  /// true kalsin. !!! CANLIYA CIKMADAN ONCE false YAP !!!
  static const bool testingMode = false;

  /// Reklam yuklenemediginde (doluluk yok) ama cihaz internetteyse odul
  /// verilsin mi? Eski oyundaki kural: kullanici "izle"ye bastiysa magdur
  /// olmasin. Elmas ekonomisini korumak istersen false yap.
  static const bool rewardOnNoFill = true;

  /// Ilk N bolum boyunca gecis reklami GOSTERILMEZ (yeni oyuncu ilk
  /// oturumda reklamla karsilasip kacmasin - eski oyundaki D1 duzeltmesi).
  static int get interstitialGraceChapters => RemoteTuning.i('inter_grace_chapters', 6);

  /// Grace bittikten sonra kac bolumde bir gecis reklami.
  static int get chaptersPerInterstitial => RemoteTuning.i('inter_every_chapters', 3);

  static const String _kLifetimeChapters = 'ad_lifetime_chapters_completed_v1';

  static bool get _configured => appodealAppKey.isNotEmpty && !kIsWeb;

  /// Appodeal baslatma hatalari (bos = sorun yok). Teshis icin.
  List<String> lastInitErrors = const [];

  bool _sdkInitialized = false;
  bool get sdkInitialized => _sdkInitialized;

  Completer<bool>? _pendingCompleter;
  Completer<void>? _pendingInterstitialCompleter;
  bool _adStartedShowing = false;
  bool _rewardGranted = false;
  Timer? _notShownWatchdog;
  int _chaptersSinceInterstitial = 0;
  int? _lifetimeCache;

  // ------------------------------------------------------------ baslatma

  /// Appodeal'i kurar, callback'leri baglar ve (AB/AEA/UK/CCPA ise) resmi
  /// riza formunu tetikler. BEKLENMEZ; hata olursa oyun etkilenmez.
  Future<void> initializeSdk() async {
    if (_sdkInitialized || !_configured) return;
    try {
      AppLog.i('ads', 'Appodeal.initialize basliyor');
      Appodeal.setTesting(testingMode);
      Appodeal.setLogLevel(testingMode ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone);
      _bindRewardedCallbacks();
      _bindInterstitialCallbacks();
      await Appodeal.initialize(
        appKey: appodealAppKey,
        adTypes: [AppodealAdType.RewardedVideo, AppodealAdType.Interstitial],
        onInitializationFinished: (errors) {
          // Baslatma hatalarini gorunur kil (Logcat 'AdService' + analitik).
          final list = errors ?? const <ApdInitializationError>[];
          lastInitErrors = list.map((e) => e.description).toList();
          if (list.isNotEmpty) {
            debugPrint('AdService: Appodeal init errors: $lastInitErrors');
            AppLog.e('ads', 'Appodeal init hatalari: $lastInitErrors');
            AnalyticsService.instance.log('ad_init_errors', {
              'count': list.length,
              'first': lastInitErrors.first.length > 90 ? lastInitErrors.first.substring(0, 90) : lastInitErrors.first,
            });
          } else {
            AnalyticsService.instance.log('ad_init_ok', {});
            AppLog.i('ads', 'Appodeal init tamam');
          }
        },
      );
      _sdkInitialized = true;
      try {
        // NOT: 'void' doner (Future degil) -> await YOK; sonuc callback'te.
        Appodeal.ConsentForm.loadAndShowIfRequired(
          appKey: appodealAppKey,
          onConsentFormDismissed: (error) {
            unawaited(preload());
            unawaited(preloadInterstitial());
          },
        );
      } catch (err) { AppLog.w('ad_service.initializeSdk', 'yutulan hata', err); }
      unawaited(preload());
      unawaited(preloadInterstitial());
    } catch (err) {
      AppLog.w('ad_service.initializeSdk', 'yutulan hata', err);
      // SDK baslamazsa oyun reklamsiz/simule calismaya devam eder.
    }
  }

  /// Ayarlardaki "Reklam Rizasi" butonu: resmi formu tekrar acar.
  Future<void> openAdConsentForm() async {
    if (!_configured) return;
    try {
      Appodeal.ConsentForm.load(
        appKey: appodealAppKey,
        onConsentFormLoadSuccess: (status) {
          Appodeal.ConsentForm.show(
            onConsentFormDismissed: (error) {
              // Onbellekteki reklam eski rizayla alinmisti; yenile.
              unawaited(preload());
              unawaited(preloadInterstitial());
            },
          );
        },
        onConsentFormLoadFailure: (error) {},
      );
    } catch (err) { AppLog.w('ad_service.openAdConsentForm', 'yutulan hata', err); }
  }

  // ------------------------------------------------------------ callback'ler

  String _curPlacement = 'none'; // su an gosterilen odullu reklamin yeri (analitik)

  void _bindRewardedCallbacks() {
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) {},
      onRewardedVideoFailedToLoad: () {},
      onRewardedVideoShown: () {
        AnalyticsService.instance.log('ad_rew_impression', {'placement': _curPlacement});
        _adStartedShowing = true;
        _notShownWatchdog?.cancel();
      },
      onRewardedVideoShowFailed: () {
        // Gosterim hic baslayamadi: kullanici magdur olmasin.
        AnalyticsService.instance.log('ad_rew_show_failed', {'placement': _curPlacement});
        _finish(rewardOnNoFill);
        unawaited(preload());
      },
      onRewardedVideoFinished: (amount, reward) {
        _rewardGranted = true;
        AnalyticsService.instance.log('ad_rew_completed', {'placement': _curPlacement});
        _finish(true);
      },
      onRewardedVideoClosed: (isFinished) {
        // Odul sadece reklam gercekten bittiyse verilir.
        if (!_rewardGranted) AnalyticsService.instance.log('ad_rew_skipped', {'placement': _curPlacement});
        _finish(_rewardGranted);
        unawaited(preload());
      },
      onRewardedVideoExpired: () {},
      onRewardedVideoClicked: () {
        AnalyticsService.instance.log('ad_rew_clicked', {'placement': _curPlacement});
      },
    );
  }

  void _bindInterstitialCallbacks() {
    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) {},
      onInterstitialFailedToLoad: () {},
      onInterstitialShown: () {
        AnalyticsService.instance.log('ad_inter_impression', {'chapters': _chaptersSinceInterstitial});
      },
      onInterstitialShowFailed: () {
        AnalyticsService.instance.log('ad_inter_show_failed');
        _finishInterstitial();
        unawaited(preloadInterstitial());
      },
      onInterstitialClosed: () {
        _finishInterstitial();
        unawaited(preloadInterstitial());
      },
      onInterstitialClicked: () {
        AnalyticsService.instance.log('ad_inter_clicked');
      },
      onInterstitialExpired: () {
        unawaited(preloadInterstitial());
      },
    );
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

  Future<void> preload() async {
    if (!_sdkInitialized) return;
    try {
      if (!await Appodeal.isLoaded(AppodealAdType.RewardedVideo)) {
        Appodeal.cache(AppodealAdType.RewardedVideo);
      }
    } catch (err) { AppLog.w('ad_service.preload', 'yutulan hata', err); }
  }

  Future<void> preloadInterstitial() async {
    if (!_sdkInitialized) return;
    try {
      if (!await Appodeal.isLoaded(AppodealAdType.Interstitial)) {
        Appodeal.cache(AppodealAdType.Interstitial);
      }
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
    if (!_configured) return;
    await _bumpLifetimeChapters();
    if ((await _lifetimeChapters()) <= interstitialGraceChapters) return;
    _chaptersSinceInterstitial++;
    if (_chaptersSinceInterstitial >= chaptersPerInterstitial) {
      await showInterstitialIfReady();
    }
  }

  Future<void> showInterstitialIfReady() async {
    if (!_sdkInitialized) return;
    try {
      if (!await Appodeal.isLoaded(AppodealAdType.Interstitial)) {
        AnalyticsService.instance.log('ad_inter_nofill'); // gosterilecekti ama reklam hazir degildi
        unawaited(preloadInterstitial());
        return; // sayac KORUNUR: hazir olunca sonraki firsatta gosterilir
      }
      _chaptersSinceInterstitial = 0;
      final c = Completer<void>();
      _pendingInterstitialCompleter = c;
      await MusicService.instance.suspendForAd();
      Appodeal.show(AppodealAdType.Interstitial);
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
  /// hazir degilse buton hic cikmaz.) Anahtar girilmemisse (test) true doner.
  Future<bool> isRewardedReady() async {
    if (!_configured) return true;
    if (!_sdkInitialized) return false;
    try {
      final ready = await Appodeal.isLoaded(AppodealAdType.RewardedVideo);
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
  Future<bool> showRewarded(BuildContext context, {bool strict = false, RewardedPrompt? prompt}) async {
    _curPlacement = prompt?.placement ?? 'generic';
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
    if (!_configured) return _simulate(context);

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
    final granted = await _loadAndShow(strict: strict);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return granted;
  }

  Future<bool> _loadAndShow({bool strict = false}) async {
    // strict: reklam GERCEKTEN izlenmedikce odul yok (ornegin x2 coin). Doluluk yoksa false.
    final noFill = strict ? false : rewardOnNoFill;
    if (!_sdkInitialized) return noFill; // SDK hazir degil: kullanici magdur olmasin
    if (!await Appodeal.isLoaded(AppodealAdType.RewardedVideo)) {
      AnalyticsService.instance.log('ad_rew_nofill', {'placement': _curPlacement});
      unawaited(preload());
      return noFill; // doluluk yok
    }
    _rewardGranted = false;
    _adStartedShowing = false;
    final completer = Completer<bool>();
    _pendingCompleter = completer;
    try {
      await MusicService.instance.suspendForAd();
      Appodeal.show(AppodealAdType.RewardedVideo);
    } catch (err) {
      AppLog.w('ad_service._loadAndShow', 'yutulan hata', err);
      _finish(noFill);
    }
    // Guvenlik agi: 15 sn icinde "gosterildi" gelmezse takili kalma.
    // Reklam bir kez basladiysa bu zamanlayici iptal olur.
    _notShownWatchdog = Timer(const Duration(seconds: 15), () {
      if (!_adStartedShowing) _finish(noFill);
    });
    try {
      return await completer.future;
    } finally {
      unawaited(MusicService.instance.resumeAfterAd());
    }
  }

  /// Appodeal anahtari girilene kadar eski test davranisi.
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
