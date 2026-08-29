import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'crash_service.dart';

/// ============================================================================
/// APPODEAL REKLAM SERVİSİ
/// ============================================================================
/// BillingService/AuthService'teki "İSKELET" desenin AYNISI: init() try/catch
/// içinde — Appodeal App Key henüz Play Console/App Store tarafında tam
/// kurulmadıysa ya da cihazda ağ/SDK sorunu olursa [isAvailable] false kalır,
/// uygulama ÇÖKMEDEN reklamsız çalışmaya devam eder.
///
/// ŞİMDİLİK TEST MODU: [_testMode] true — Appodeal.setTesting(true) ile
/// gerçek harcama yapmadan test reklamları gösterilir. Yayına alırken:
///   1) [_appKey]'i Appodeal Dashboard'daki GERÇEK app key ile değiştir.
///   2) [_testMode]'u false yap.
///
/// KULLANIM YERLERİ:
///   - "Siteyi Oluştur" butonları -> [showInterstitial] (bkz.
///     services/local_generation_helper.dart).
///   - "İndir" / "Yayınla" butonları -> önce widgets/rewarded_ad_popup.dart
///     üzerinden özel bir onay sheet'i açılır, kullanıcı "Tamam" derse
///     [showRewardedAd] çağrılır.
///   - Alt banner -> widgets/banner_ad_bar.dart (main.dart > MaterialApp
///     builder içinde TÜM ekranların altına sabitlenir).
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // TODO(yayın öncesi): Appodeal Dashboard'dan alınan GERÇEK app key ile
  // değiştir. Bu placeholder ile SDK başlatma başarısız olabilir; başarısız
  // olursa [isAvailable] false kalır, uygulama normal çalışmaya devam eder.
  static const String _appKey = 'YOUR_APPODEAL_APP_KEY';
  static const bool _testMode = true; // yayına alırken false yapılacak

  bool isAvailable = false;
  bool _rewardedLoaded = false;
  bool _interstitialLoaded = false;

  /// Aktif bir rewarded gösterimin sonucunu bekleyen completer — aynı anda
  /// yalnızca TEK bir rewarded akışı desteklenir (uygulamada zaten aynı anda
  /// birden fazla indir/yayınla popup'ı açılamıyor).
  Completer<bool>? _rewardedCompleter;

  Future<void> init() async {
    try {
      Appodeal.setTesting(_testMode);
      Appodeal.setRewardedVideoCallbacks(
        onRewardedVideoLoaded: (isPrecache) => _rewardedLoaded = true,
        onRewardedVideoFailedToLoad: () => _rewardedLoaded = false,
        onRewardedVideoShown: () {},
        onRewardedVideoShowFailed: () {
          _rewardedCompleter?.complete(false);
          _rewardedCompleter = null;
        },
        onRewardedVideoClicked: () {},
        onRewardedVideoFinished: (amount, reward) {
          // Ödül kazanıldı — kapanış (onRewardedVideoClosed) AYRICA gelir,
          // asıl "başarılı" sinyali burası (bkz. showRewardedAd).
          if (_rewardedCompleter != null && !_rewardedCompleter!.isCompleted) {
            _rewardedCompleter?.complete(true);
            _rewardedCompleter = null;
          }
        },
        onRewardedVideoClosed: (isFinished) {
          // Kullanıcı videoyu bitirmeden kapattıysa onRewardedVideoFinished
          // hiç tetiklenmemiş olur — completer hâlâ açıksa burada false ile
          // çözülür (ör. reklam açılır açılmaz geri tuşuna basıldıysa).
          if (_rewardedCompleter != null && !_rewardedCompleter!.isCompleted) {
            _rewardedCompleter?.complete(false);
            _rewardedCompleter = null;
          }
        },
        onRewardedVideoExpired: () => _rewardedLoaded = false,
      );
      Appodeal.setInterstitialCallbacks(
        onInterstitialLoaded: (isPrecache) => _interstitialLoaded = true,
        onInterstitialFailedToLoad: () => _interstitialLoaded = false,
        onInterstitialShown: () {},
        onInterstitialShowFailed: () {},
        onInterstitialClicked: () {},
        onInterstitialClosed: () {},
        onInterstitialExpired: () => _interstitialLoaded = false,
      );

      await Appodeal.initialize(
        appKey: _appKey,
        adTypes: [
          AppodealAdType.Interstitial,
          AppodealAdType.RewardedVideo,
          AppodealAdType.Banner,
        ],
        onInitializationFinished: (errors) {
          isAvailable = errors == null || errors.isEmpty;
        },
      );
    } catch (e, st) {
      isAvailable = false;
      CrashService.record(e, st, context: 'AdsService.init', fatal: false);
      debugPrint('Appodeal henüz kurulmadı, reklamsız devam ediliyor: $e');
    }
  }

  /// "Siteyi Oluştur" akışında üretim BAŞARILI olduktan sonra çağrılır.
  /// Reklam yüklü değilse/isAvailable false ise sessizce hiçbir şey yapmaz —
  /// site oluşturma akışını ASLA bloklamaz veya geciktirmez.
  Future<void> showInterstitial({String placement = 'site_create'}) async {
    if (!isAvailable) return;
    try {
      final canShow = await Appodeal.canShow(AppodealAdType.Interstitial, placement);
      if (!canShow) return;
      await Appodeal.show(AppodealAdType.Interstitial, placement);
    } catch (e) {
      debugPrint('Interstitial gösterilemedi: $e');
    }
  }

  /// İndir/Yayınla akışında kullanıcı özel popup'ta "Tamam"a bastıktan sonra
  /// çağrılır. Döner: kullanıcı ödülü (videoyu sonuna kadar) aldıysa true,
  /// videoyu yarıda kapattıysa/gösterim başarısız olduysa false.
  ///
  /// Reklam SDK'sı kullanılamıyorsa (henüz kurulmadı/yüklenmediyse) true
  /// döner — reklam altyapısındaki bir aksaklık kullanıcının indirme/yayınlama
  /// işlemini TAMAMEN engellememeli (bkz. çağıran taraf: rewarded_ad_popup.dart).
  Future<bool> showRewardedAd({String placement = 'download_publish'}) async {
    if (!isAvailable) return true;
    try {
      final canShow = await Appodeal.canShow(AppodealAdType.RewardedVideo, placement);
      if (!canShow) return true;

      _rewardedCompleter = Completer<bool>();
      final shown = await Appodeal.show(AppodealAdType.RewardedVideo, placement);
      if (!shown) {
        _rewardedCompleter = null;
        return true;
      }
      return await _rewardedCompleter!.future;
    } catch (e) {
      debugPrint('Rewarded reklam gösterilemedi: $e');
      _rewardedCompleter = null;
      return true;
    }
  }

  bool get isRewardedReady => _rewardedLoaded;
  bool get isInterstitialReady => _interstitialLoaded;
}
