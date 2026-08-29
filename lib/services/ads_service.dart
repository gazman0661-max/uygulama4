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
/// AstroFelyx (oyun) projesindeki ÇALIŞAN yaklaşımla AYNI: Appodeal.canShow()
/// ile placement eşleştirmesi YAPILMIYOR — panelde ayrı bir placement
/// oluşturup "Active" duruma getirmek GEREKMİYOR. Bunun yerine doğrudan
/// Appodeal.isLoaded(adType) ile reklamın önbellekte hazır olup olmadığına
/// bakılıyor; hazırsa Appodeal.show(adType) çağrılıyor.
///
/// GDPR/UK RIZASI: init() içinde, SDK başlatıldıktan hemen sonra Appodeal'in
/// kendi resmi onay ekranı (Google UMP tabanlı Stack Consent Manager)
/// tetikleniyor. Bu form SADECE AB/AEA/İsviçre/UK bölgesindeki kullanıcılara
/// OTOMATİK gösterilir — Türkiye dahil GDPR kapsamı dışındaki ülkelerde
/// hiçbir şey göstermez, uygulama normal açılışına devam eder. Bölge
/// tespiti Appodeal SDK'sı tarafından yapılır.
///
/// ŞİMDİLİK TEST MODU: [_testMode] true — Appodeal.setTesting(true) ile
/// gerçek harcama yapmadan test reklamları gösterilir. Yayına alırken:
///   1) [_testMode]'u false yap.
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

  static const String _appKey = '25e3a1ee8cebab96c7f75381406f8d9a56466cbdc1fc781f';
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

      // GDPR/UK rıza formu — AstroFelyx'teki AYNI yaklaşım: Appodeal'in
      // kendi resmi onay ekranı (Google UMP tabanlı Stack Consent Manager).
      // Appodeal SDK 3.0+'dan itibaren bu formu SADECE kullanıcı AB/AEA/
      // İsviçre/UK (GDPR) bölgesindeyse OTOMATİK gösterir — Türkiye ve
      // GDPR kapsamı dışındaki ülkelerde bu çağrı hiçbir şey yapmaz,
      // uygulama sessizce normal akışına devam eder. Bölge tespiti tamamen
      // Appodeal SDK'sı tarafından (cihazın konum/IP bilgisiyle) yapılır,
      // burada AYRICA bir ülke kontrolü yazmaya gerek YOK.
      try {
        Appodeal.ConsentForm.loadAndShowIfRequired(
          appKey: _appKey,
          onConsentFormDismissed: (error) {
            // Kullanıcı rıza formunu (varsa) kapattı — önbellekteki
            // reklamı yeni rızaya göre tazelemek için init akışını
            // etkilemeyecek şekilde burada ekstra bir şey yapmaya gerek
            // yok, SDK zaten bir sonraki reklam isteğinde yeni rızayı
            // kullanır.
          },
        );
      } catch (e) {
        // Form yüklenemezse (ör. internet yok) sessizce yut — reklamlar
        // bölgeye göre varsayılan davranışla çalışmaya devam eder.
        debugPrint('Appodeal rıza formu yüklenemedi: $e');
      }
    } catch (e, st) {
      isAvailable = false;
      CrashService.record(e, st, context: 'AdsService.init', fatal: false);
      debugPrint('Appodeal henüz kurulmadı, reklamsız devam ediliyor: $e');
    }
  }

  /// "Siteyi Oluştur" akışında üretim BAŞARILI olduktan sonra çağrılır.
  /// Reklam yüklü değilse/isAvailable false ise sessizce hiçbir şey yapmaz —
  /// site oluşturma akışını ASLA bloklamaz veya geciktirmez.
  ///
  /// AstroFelyx'teki gibi placement eşleştirmesi (canShow) YOK — sadece
  /// önbellekte reklam hazır mı diye bakılıyor.
  Future<void> showInterstitial({String placement = 'site_create'}) async {
    if (!isAvailable) return;
    try {
      final loaded = await Appodeal.isLoaded(AppodealAdType.Interstitial);
      if (!loaded) return;
      await Appodeal.show(AppodealAdType.Interstitial);
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
  ///
  /// AstroFelyx'teki gibi placement eşleştirmesi (canShow) YOK — sadece
  /// önbellekte reklam hazır mı diye bakılıyor.
  Future<bool> showRewardedAd({String placement = 'download_publish'}) async {
    if (!isAvailable) return true;
    try {
      final loaded = await Appodeal.isLoaded(AppodealAdType.RewardedVideo);
      if (!loaded) return true;

      _rewardedCompleter = Completer<bool>();
      final shown = await Appodeal.show(AppodealAdType.RewardedVideo);
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
