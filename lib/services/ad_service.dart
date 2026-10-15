import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

import '../localization/app_strings.dart';
import '../widgets/ui_kit.dart';
import 'music_service.dart';

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
  static const int interstitialGraceChapters = 6;

  /// Grace bittikten sonra kac bolumde bir gecis reklami.
  static const int chaptersPerInterstitial = 3;

  static const String _kLifetimeChapters = 'ad_lifetime_chapters_completed_v1';

  static bool get _configured => appodealAppKey.isNotEmpty && !kIsWeb;

  bool _sdkInitialized = false;
  bool get sdkInitialized => _sdkInitialized;

  // ------------------------------------------------------------ TESHIS (gecici)
  // Ayarlar > "Reklam Teshisi" ekrani bunlari gosterir. Sorun cozulunce
  // ekran ve bu bolum kaldirilabilir.
  static const String _kDebugTesting = 'ad_debug_testing_v1';
  final List<String> debugLog = <String>[];
  bool _testingOverride = false;
  String initResult = 'henuz baslatilmadi';

  bool get testingActive => testingMode || _testingOverride;
  bool get configured => _configured;
  String get appKeyMasked => appodealAppKey.length < 12
      ? '(bos/kisa)'
      : '${appodealAppKey.substring(0, 6)}...${appodealAppKey.substring(appodealAppKey.length - 4)}';

  void _log(String m) {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    debugLog.add('${two(t.hour)}:${two(t.minute)}:${two(t.second)}  $m');
    if (debugLog.length > 150) debugLog.removeAt(0);
  }

  Future<void> setDebugTesting(bool v) async {
    _testingOverride = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDebugTesting, v);
      _log('Test modu ${v ? "ACIK" : "kapali"} (etkili olmasi icin uygulamayi tamamen kapat-ac)');
    } catch (_) {}
  }

  Future<bool> debugHasInternet() => _hasRealInternet();

  Future<bool> debugIsLoaded(bool rewarded) async {
    if (!_sdkInitialized) return false;
    try {
      return await Appodeal.isLoaded(rewarded ? AppodealAdType.RewardedVideo : AppodealAdType.Interstitial);
    } catch (e) {
      _log('isLoaded hatasi: $e');
      return false;
    }
  }

  Future<void> debugReinit() async {
    _log('SDK yeniden baslatma istendi');
    await initializeSdk();
  }

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
    if (_sdkInitialized || !_configured) {
      _log('initializeSdk atlandi (zaten basladi=$_sdkInitialized, yapilandirildi=$_configured)');
      return;
    }
    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        _testingOverride = prefs.getBool(_kDebugTesting) ?? false;
      } catch (_) {}
      _log('SDK baslatiliyor... key=$appKeyMasked test=$testingActive');
      Appodeal.setTesting(testingActive);
      Appodeal.setLogLevel(testingActive ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone);
      _bindRewardedCallbacks();
      _bindInterstitialCallbacks();
      await Appodeal.initialize(
        appKey: appodealAppKey,
        adTypes: [AppodealAdType.RewardedVideo, AppodealAdType.Interstitial],
        onInitializationFinished: (errors) {
          if (errors == null || (errors is List && errors.isEmpty)) {
            initResult = 'BASARILI (hata yok)';
            _log('Appodeal init BITTI: hata yok');
          } else {
            initResult = 'HATALI: $errors';
            _log('Appodeal init BITTI - HATA: $errors');
          }
        },
      );
      _sdkInitialized = true;
      _log('Appodeal.initialize cagrisi dondu');
      try {
        // NOT: 'void' doner (Future degil) -> await YOK; sonuc callback'te.
        Appodeal.ConsentForm.loadAndShowIfRequired(
          appKey: appodealAppKey,
          onConsentFormDismissed: (error) {
            _log('Riza formu kapandi (hata: $error)');
            unawaited(preload());
            unawaited(preloadInterstitial());
          },
        );
      } catch (e) {
        _log('Riza formu hatasi: $e');
      }
      unawaited(preload());
      unawaited(preloadInterstitial());
    } catch (e) {
      // SDK baslamazsa oyun reklamsiz/simule calismaya devam eder.
      initResult = 'ISTISNA: $e';
      _log('SDK BASLATMA ISTISNASI: $e');
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
    } catch (_) {}
  }

  // ------------------------------------------------------------ callback'ler

  void _bindRewardedCallbacks() {
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) {
        _log('Odullu: YUKLENDI');
      },
      onRewardedVideoFailedToLoad: () {
        _log('Odullu: YUKLENEMEDI (doluluk yok / ag / ayar sorunu)');
      },
      onRewardedVideoShown: () {
        _log('Odullu: GOSTERILDI');
        _adStartedShowing = true;
        _notShownWatchdog?.cancel();
      },
      onRewardedVideoShowFailed: () {
        _log('Odullu: GOSTERIM BASARISIZ');
        // Gosterim hic baslayamadi: kullanici magdur olmasin.
        _finish(rewardOnNoFill);
        unawaited(preload());
      },
      onRewardedVideoFinished: (amount, reward) {
        _log('Odullu: IZLENDI (odul hakki)');
        _rewardGranted = true;
        _finish(true);
      },
      onRewardedVideoClosed: (isFinished) {
        _log('Odullu: KAPANDI (bitti=$isFinished)');
        // Odul sadece reklam gercekten bittiyse verilir.
        _finish(_rewardGranted);
        unawaited(preload());
      },
      onRewardedVideoExpired: () {},
      onRewardedVideoClicked: () {},
    );
  }

  void _bindInterstitialCallbacks() {
    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) {
        _log('Gecis: YUKLENDI');
      },
      onInterstitialFailedToLoad: () {
        _log('Gecis: YUKLENEMEDI');
      },
      onInterstitialShown: () {
        _log('Gecis: GOSTERILDI');
      },
      onInterstitialShowFailed: () {
        _log('Gecis: GOSTERIM BASARISIZ');
        _finishInterstitial();
        unawaited(preloadInterstitial());
      },
      onInterstitialClosed: () {
        _finishInterstitial();
        unawaited(preloadInterstitial());
      },
      onInterstitialClicked: () {},
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
    if (!_sdkInitialized) {
      _log('Odullu cache atlandi: SDK hazir degil');
      return;
    }
    try {
      if (!await Appodeal.isLoaded(AppodealAdType.RewardedVideo)) {
        _log('Odullu cache istegi gonderildi');
        Appodeal.cache(AppodealAdType.RewardedVideo);
      }
    } catch (e) {
      _log('Odullu cache hatasi: $e');
    }
  }

  Future<void> preloadInterstitial() async {
    if (!_sdkInitialized) {
      _log('Gecis cache atlandi: SDK hazir degil');
      return;
    }
    try {
      if (!await Appodeal.isLoaded(AppodealAdType.Interstitial)) {
        _log('Gecis cache istegi gonderildi');
        Appodeal.cache(AppodealAdType.Interstitial);
      }
    } catch (e) {
      _log('Gecis cache hatasi: $e');
    }
  }

  // ------------------------------------------------------------ gecis reklami

  Future<int> _lifetimeChapters() async {
    if (_lifetimeCache != null) return _lifetimeCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      return _lifetimeCache = prefs.getInt(_kLifetimeChapters) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _bumpLifetimeChapters() async {
    final updated = (await _lifetimeChapters()) + 1;
    _lifetimeCache = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLifetimeChapters, updated);
    } catch (_) {}
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
        unawaited(preloadInterstitial());
        return; // sayac KORUNUR: hazir olunca sonraki firsatta gosterilir
      }
      _chaptersSinceInterstitial = 0;
      final c = Completer<void>();
      _pendingInterstitialCompleter = c;
      await MusicService.instance.suspendForAd();
      Appodeal.show(AppodealAdType.Interstitial);
      await c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    } catch (_) {
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
      } catch (_) {}
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
    } catch (_) {
      return false;
    }
  }

  /// Oyuncu istegiyle odullu reklam izledi: hemen ardindan gecis reklami
  /// gostermemek icin sayac sifirlanir.
  void resetInterstitialCounter() => _chaptersSinceInterstitial = 0;

  /// Reklami yukler/gosterir. true = odul verilmeli.
  Future<bool> showRewarded(BuildContext context, {bool strict = false}) async {
    if (!_configured) return _simulate(context);

    if (!await _hasRealInternet()) {
      _log('Odullu istendi: INTERNET YOK');
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
    if (!_sdkInitialized) {
      _log('Odullu istendi: SDK HAZIR DEGIL -> reklamsiz sonuc=$noFill');
      return noFill; // SDK hazir degil: kullanici magdur olmasin
    }
    if (!await Appodeal.isLoaded(AppodealAdType.RewardedVideo)) {
      _log('Odullu istendi: REKLAM YUKLU DEGIL (doluluk yok) -> reklamsiz sonuc=$noFill');
      unawaited(preload());
      return noFill; // doluluk yok
    }
    _log('Odullu istendi: reklam gosteriliyor');
    _rewardGranted = false;
    _adStartedShowing = false;
    final completer = Completer<bool>();
    _pendingCompleter = completer;
    try {
      await MusicService.instance.suspendForAd();
      Appodeal.show(AppodealAdType.RewardedVideo);
    } catch (_) {
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
Future<bool> watchRewardedAd(BuildContext context) => AdService.instance.showRewarded(context);

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
