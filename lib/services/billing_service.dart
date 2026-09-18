import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
// consumePurchase() bu pakette DEĞİL, Android'e özel eklenti paketinde —
// in_app_purchase'ın kendi bağımlılığı olarak zaten pub-cache'te geliyor,
// pubspec.yaml'a AYRICA eklemeye gerek yok (transitive dependency).
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
// `ReplacementMode` (ve billing_client_wrappers'taki diğer düşük seviyeli
// tipler) `in_app_purchase_android.dart` barrel'ından export EDİLMİYOR —
// resmi dokümantasyon bu tipler için ayrıca bu import'u istiyor:
// https://pub.dev/documentation/in_app_purchase_android/latest/billing_client_wrappers/
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import '../constants/billing_constants.dart';
import 'auth_service.dart';
import 'crash_service.dart';
import 'analytics_service.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// SITORA UYGULAMA İÇİ SATIN ALMA — İSKELET
/// ============================================================================
/// `AuthService`/`UserDataService`deki "İSKELET" dosyalarla AYNI desen:
/// mağaza tarafı (Play Console ürünleri, imzalı APK/AAB ile iç test) henüz
/// tam kurulmadan da uygulama ÇÖKMEDEN çalışsın diye her adım try/catch
/// ile sarmalanmış, [isAvailable] false olduğunda satın alma butonları
/// "şu an kullanılamıyor" gösterir ama uygulamanın geri kalanını
/// engellemez.
///
/// AKIŞ (bir satın alma nasıl tamamlanır):
///   1) Çağıran taraf (örn. remove_watermark_sheet.dart) `buyConsumable`'ı
///      bekler (await).
///   2) `buyConsumable` mağaza UI'ını açar (Google Play'in kendi ödeme
///      ekranı) ve DÖNMEDEN önce `_purchaseStream` üzerinden gelecek
///      sonucu bir [Completer] ile bekler.
///   3) Kullanıcı ödemeyi tamamlar/iptal eder → `_onPurchaseUpdate`
///      tetiklenir → ilgili Completer'ı çözer (satın alma tamamlandıysa
///      `true`, iptal/hata ise `false` veya exception).
///   4) `_onPurchaseUpdate` AYRICA consumable ürünü `consumePurchase` ile
///      "tüketir" — bu adım YAPILMAZSA Play Store aynı ürünü bir daha
///      satın almaya İZİN VERMEZ (pending/owned durumunda takılı kalır).
///
/// HANGİ PROJEYE/NEYE UYGULANACAĞI mağazanın bilmediği bir bilgidir — bu
/// yüzden `buyConsumable` sonucu SADECE "ödeme başarılı mı" bilgisini
/// döner; çağıran taraf (AppState) bu `true` sonucunu KENDİ bağlamına
/// (hangi proje, hangi ürün) göre yorumlayıp asıl işlemi
/// (removeWatermarkForProject / grantPublishRight)
/// kendisi yapar. Bu sayede aynı anda sadece TEK BİR satın alma akışı
/// desteklenir (kullanıcı bir sheet'i kapatmadan başka bir satın alma
/// başlatamaz) — MVP için yeterli, UI zaten modal bottom sheet'lerle tek
/// seferde tek akış açık tutuyor.
///
/// SUNUCU TARAFI MAKBUZ DOĞRULAMASI (2026-08-20 tamamlandı):
/// `_verifyPurchaseServerSide`, makbuzu (`purchase.verificationData
/// .serverVerificationData`) worker'daki POST /api/verify-purchase ucuna
/// gönderir; worker bunu Google Play Developer API'ye sorup gerçek
/// "purchased" durumunu döner. KURULUM GEREKİYOR: worker tarafında
/// `wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON` ile bir Google Cloud
/// servis hesabı anahtarı tanımlanmalı VE bu servis hesabına Play
/// Console'da (Kullanıcılar ve izinler) finansal veri görüntüleme izni
/// verilmeli — yapılmazsa worker güvenli tarafta kalıp HER satın almayı
/// `valid:false` ile reddeder (sessizce kabul ETMEZ).
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Mağaza bu cihazda kullanılabilir mi (Play Store yüklü/oturum açık mı,
  /// ürünler Play Console'da tanımlı mı). false ise satın alma butonları
  /// devre dışı bırakılıp kullanıcıya bilgi verilmeli.
  bool isAvailable = false;

  /// queryProductDetails sonucu mağazadan dönen ürünler — id'ye göre
  /// erişim için Map'e çevrilmiş halde tutulur (fiyat/başlık UI'da
  /// gösterilecekse buradan okunur).
  final Map<String, ProductDetails> products = {};

  /// Mağazada TANIMLANMAMIŞ ürün kimlikleri (henüz Play Console'da
  /// oluşturulmadıysa burada birikir) — sadece debug/log amaçlı.
  Set<String> notFoundProductIds = {};

  /// Aynı anda tek bir satın alma bekleniyor olabilir (bkz. dosya başı
  /// açıklaması) — productId -> Completer eşlemesi.
  final Map<String, Completer<bool>> _pending = {};

  /// 16.09.2026 eklendi (kanka isteği — "gerçek sorun #1" fix'i, bkz. proje
  /// sohbeti) — hesabın O AN sahip olduğu abonelik satın alması
  /// (GooglePlayPurchaseDetails). ESKİDEN buySubscription her zaman DÜZ
  /// bir [PurchaseParam] ile `_iap.buyNonConsumable` çağırıyordu — bu,
  /// kullanıcı hesabında ZATEN aktif bir abonelik VARKEN (ör. Mini'den
  /// Freelancer'a geçmek istediğinde) YANLIŞTIR: Play Billing bir hesapta
  /// aynı subscription group'taki başka bir ürünü "sıfırdan" satın almaya
  /// izin VERMEZ (ya hata döner ya da "zaten sahipsin" durumuna düşer) —
  /// gerçek bir yükseltme/düşürme için Play'e `ChangeSubscriptionParam`
  /// ile HANGİ eski satın almadan geçildiğini AÇIKÇA bildirmek gerekir
  /// (bkz. buySubscription). Bu alan [init] içindeki `restorePurchases()`
  /// ile VE her yeni satın alma/restore sonrası `_onPurchaseUpdate` ile
  /// güncel tutulur — worker'a HİÇBİR ŞEY göndermez, sadece Play'in kendi
  /// API'sine "eski satın alma buydu" demek için yerel bir önbellektir.
  GooglePlayPurchaseDetails? _ownedSubscriptionPurchase;

  /// main.dart açılışında Firebase.initializeApp() ile AYNI yerde,
  /// try/catch içinde çağrılmalı. Mağaza kullanılamıyorsa (örn. emülatörde
  /// Play Store yok, ya da Play Console kurulumu bitmedi) [isAvailable]
  /// false kalır, uygulama normal çalışmaya devam eder.
  Future<void> init() async {
    try {
      isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        debugPrint('Billing: mağaza kullanılamıyor (Play Store yok/oturum yok).');
        return;
      }
      _sub = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (Object e, StackTrace st) {
          CrashService.record(e, st, context: 'BillingService.purchaseStream');
        },
      );
      await _queryProducts();
      // 16.09.2026 eklendi (kanka isteği — "gerçek sorun #1" fix'i, devamı)
      // — ESKİDEN bu satır hiç YOKTU: uygulama açılışında Play'in hesapta
      // ZATEN sahip olduğu satın almaları (ör. daha önce başka bir cihazda/
      // oturumda alınmış bir abonelik) bildirmesi için bir şey İSTENMİYORDU.
      // Bunun DÖRT sonucu vardı: (1) [_ownedSubscriptionPurchase] hiç
      // dolmadığı için buySubscription paket değiştirmeyi HİÇBİR ZAMAN
      // gerçek bir "değiştir" akışı olarak yapamıyordu (bkz. yukarısı), (2)
      // uygulamayı silip yeniden yükleyen/başka cihaza geçen bir kullanıcı
      // zaten ödediği tek seferlik ürünleri (rozet kaldırma vb. — bunlar
      // consumable olduğu için restorePurchases zaten pratikte pek bir şey
      // döndürmez ama abonelikler NON-consumable/subscription olduğu için
      // BU özellikle onları etkiliyordu) bir daha hiç "sahip" görünmüyordu.
      // Hata burada YUTULUR (best-effort) — Play Store yoksa/ilk kurulumda
      // hiç geçmiş satın alma yoksa zaten sessizce boş döner, uygulamanın
      // geri kalanını ENGELLEMEMESİ gerekir.
      try {
        await _iap.restorePurchases();
      } catch (e) {
        debugPrint('Billing: restorePurchases başarısız (yok sayılıyor): $e');
      }
    } catch (e, st) {
      isAvailable = false;
      CrashService.record(e, st, context: 'BillingService.init');
      debugPrint('Billing: init başarısız, satın alma özellikleri kapalı: $e');
    }
  }

  Future<void> _queryProducts() async {
    final response = await _iap.queryProductDetails(kAllProductIds);
    if (response.error != null) {
      debugPrint('Billing: ürün sorgusu hata döndü: ${response.error}');
    }
    notFoundProductIds = response.notFoundIDs.toSet();
    if (notFoundProductIds.isNotEmpty) {
      // Beklenen bir durum: Play Console'da ürünler henüz oluşturulmadıysa
      // (iskelet aşaması) TÜM id'ler burada listelenir — uygulama yine de
      // açılır, sadece fiyat gösterilemez.
      debugPrint('Billing: Play Console\'da bulunamayan ürünler: $notFoundProductIds');
    }
    products.clear();
    for (final p in response.productDetails) {
      products[p.id] = p;
    }
  }

  void dispose() {
    _sub?.cancel();
  }

  /// Bir consumable ürünü satın alma akışını başlatır ve SONUÇLANANA kadar
  /// (satın alma tamamlanana/iptal/hata) bekler.
  ///
  /// Dönen `true`: satın alma başarıyla tamamlandı VE tüketildi — çağıran
  /// taraf artık asıl işlemi (kredi/hak ekleme) uygulayabilir.
  /// Dönen `false`: kullanıcı vazgeçti (iptal) — sessizce geri dönülmeli.
  /// Exception fırlatırsa: gerçek bir hata oluştu (ağ, mağaza hatası vb.) —
  /// çağıran taraf kullanıcıya bir hata mesajı göstermeli.
  Future<bool> buyConsumable(String productId) async {
    if (!isAvailable) {
      throw StateError('Mağaza şu an kullanılamıyor.');
    }
    final product = products[productId];
    if (product == null) {
      throw StateError(
          'Ürün mağazada bulunamadı ($productId) — Play Console kurulumu tamamlanmamış olabilir.');
    }
    if (_pending.containsKey(productId)) {
      // Aynı ürün için zaten bekleyen bir satın alma varsa (örn. kullanıcı
      // butona art arda bastı) yeni bir akış BAŞLATMIYORUZ — mevcut
      // Completer'ın sonucunu bekleriz, mağazada iki kez ödeme ekranı
      // açılmasını önler.
      return _pending[productId]!.future;
    }
    final completer = Completer<bool>();
    _pending[productId] = completer;

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: false);
    } catch (e) {
      _pending.remove(productId);
      rethrow;
    }
    return completer.future;
  }

  /// Bir ABONELİK (subscription) ürünü satın alma akışını başlatır —
  /// buyConsumable'dan FARKI: Play Billing'de abonelikler buyNonConsumable
  /// ile satın alınır (ayrı bir "buySubscription" metodu YOKTUR, ürünün
  /// Play Console'da "subscription" olarak tanımlanmış olması yeterlidir)
  /// VE satın alma sonrası consumePurchase ÇAĞRILMAZ (bkz.
  /// _onPurchaseUpdate'teki isSubscription dallanması).
  ///
  /// HESAP BAZLI olduğu için giriş yapılmamışsa satın alma BAŞLATILMAZ —
  /// çağıran taraf (UI) bundan önce login_gate ile giriş zorunlu kılmalı,
  /// burada AYRICA kontrol edilir (savunma amaçlı — worker tarafı zaten
  /// uid olmadan doğrulama yapamaz).
  Future<bool> buySubscription(String productId) async {
    if (!isAvailable) {
      throw StateError('Mağaza şu an kullanılamıyor.');
    }
    if (AuthService.instance.currentUser == null) {
      throw StateError('Abonelik satın almak için önce giriş yapmalısın.');
    }
    final product = products[productId];
    if (product == null) {
      throw StateError(
          'Ürün mağazada bulunamadı ($productId) — Play Console kurulumu tamamlanmamış olabilir.');
    }
    if (_pending.containsKey(productId)) {
      return _pending[productId]!.future;
    }
    final completer = Completer<bool>();
    _pending[productId] = completer;

    // 16.09.2026 eklendi (kanka isteği — "gerçek sorun #1" fix'i) — hesap
    // ZATEN BAŞKA bir abonelik ürününe sahipse (bkz. _ownedSubscriptionPurchase,
    // [init]'teki restorePurchases + _onPurchaseUpdate ile doldurulur) DÜZ
    // bir PurchaseParam yerine Play'e "bu, şu eski satın almanın YERİNE
    // geçiyor" diyen [GooglePlayPurchaseParam.changeSubscriptionParam]
    // kullanılır — ESKİDEN üçü de AYNI subscription group'ta olduğu için
    // Play'in "kendiliğinden" değiştir akışının devreye gireceği
    // VARSAYILMIŞTI, bu YANLIŞTI (bkz. dosya başı açıklaması): bu param
    // AÇIKÇA verilmeden Play bunu yeni/bağımsız bir satın alma dener ve
    // reddeder ya da "zaten sahipsin" durumuna düşer. Aynı ürüne (paket
    // değişmiyor, ör. sadece yenileme/tekrar deneme) tekrar basılırsa
    // [isSwitchingPlan] false kalır, düz akış kullanılır — bu durumda zaten
    // Play kendi normal "owned" hata mesajını verir, bu BEKLENEN bir
    // davranıştır.
    final owned = _ownedSubscriptionPurchase;
    final isSwitchingPlan = owned != null && owned.productID != productId;

    // 17.09.2026 eklendi (kanka isteği — "ödediği dönemi kullansın" fix'i).
    // ESKİDEN paket değişimi YÖN FARK ETMEKSİZİN withTimeProration
    // kullanıyordu — bu YÜKSELTME için doğru (kullanıcı hemen daha fazla
    // kota ister, aradaki farkı orantılı öder, hemen aktif olur) ama
    // DÜŞÜRME için YANLIŞ: kullanıcı o ayki ÜST paketi zaten tam ödemişken
    // withTimeProration onu ANINDA alt pakete düşürüp kalan günler için
    // iade/orantı hesaplıyordu — yani parasını verdiği kotayı hemen
    // kaybediyordu (bkz. _buy'daki "downgrade sonrası kota aşımı" akışı,
    // subscription_plans_screen.dart — bu sheet'in anında açılması da
    // ANINDA düşmenin bir sonucuydu). ARTIK yön hesaplanıyor:
    // kSubscriptionTiers'daki (düşükten yükseğe sıralı) index'e göre yeni
    // paket eskisinden DÜŞÜKSE ReplacementMode.deferred kullanılır — Play
    // bu durumda değişikliği HEMEN uygulamaz, kullanıcı mevcut (ödenmiş)
    // dönemin SONUNA kadar eski paketin kotasını kullanmaya devam eder,
    // yeni dönem başladığında otomatik olarak yeni (düşük) pakete geçer.
    // Yükseltmede davranış AYNI kalır (withTimeProration, anında + orantılı
    // fark). Eski/yeni ürün id'si kSubscriptionTierByProductId'de
    // bulunamazsa (beklenmez, savunma amaçlı) GÜVENLİ TARAF: eski davranış
    // (withTimeProration) korunur.
    ReplacementMode replacementMode = ReplacementMode.withTimeProration;
    if (isSwitchingPlan) {
      final oldIdx = kSubscriptionTiers.indexWhere((t) => t.productId == owned.productID);
      final newIdx = kSubscriptionTiers.indexWhere((t) => t.productId == productId);
      final isDowngrade = oldIdx != -1 && newIdx != -1 && newIdx < oldIdx;
      if (isDowngrade) {
        replacementMode = ReplacementMode.deferred;
      }
    }
    final purchaseParam = isSwitchingPlan
        ? GooglePlayPurchaseParam(
            productDetails: product,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: owned,
              replacementMode: replacementMode,
            ),
          )
        : PurchaseParam(productDetails: product);
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _pending.remove(productId);
      rethrow;
    }
    return completer.future;
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final completer = _pending[purchase.productID];
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Mağaza UI'ı hâlâ açık/işleniyor — burada yapılacak bir şey yok,
          // bir sonraki status güncellemesi beklenir.
          break;

        case PurchaseStatus.error:
          _pending.remove(purchase.productID);
          completer?.completeError(
            StateError(purchase.error?.message ?? 'Satın alma başarısız.'),
          );
          break;

        case PurchaseStatus.canceled:
          _pending.remove(purchase.productID);
          completer?.complete(false);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            final isSubscription =
                kAllSubscriptionProductIds.contains(purchase.productID);
            // 16.09.2026 eklendi (kanka isteği — "gerçek sorun #1" fix'i) —
            // GÜVENLİK KAYGISI YOK: bu sadece Play'e "eski satın alma
            // buydu" demek için yerel bir önbellek, worker'a hiçbir şey
            // GÖNDERMEZ/AÇMAZ — bu yüzden aşağıdaki `verified` kontrolünden
            // ÖNCE, doğrulama sonucundan BAĞIMSIZ olarak güncellenir (Play
            // zaten purchaseStream'e SADECE kendi gerçekten bildiği satın
            // almaları/restore'ları koyar).
            if (isSubscription && purchase is GooglePlayPurchaseDetails) {
              _ownedSubscriptionPurchase = purchase;
            }
            final verified = isSubscription
                ? await _verifySubscriptionServerSide(purchase)
                : await _verifyPurchaseServerSide(purchase);
            if (verified) {
              if (purchase.pendingCompletePurchase) {
                await _iap.completePurchase(purchase);
              }
              if (isSubscription) {
                // Abonelikler TÜKETİLMEZ (consumePurchase ÇAĞRILMAZ) —
                // Play Billing'de bu ürünler auto-renewing olarak
                // Google tarafında yönetilir, "tüketme" kavramı bir
                // subscription'a UYGULANMAZ (bkz. buySubscription'daki
                // buyNonConsumable notu).
              } else {
                // NOT: 'consumePurchase' InAppPurchase sınıfında DEĞİL,
                // Android'e özel platform eklentisinde tanımlı — bu yüzden
                // getPlatformAddition ile alınması gerekiyor (in_app_purchase
                // paketinin doğru kullanımı budur, doğrudan _iap.consumePurchase
                // diye bir metod yok).
                final androidAddition = _iap.getPlatformAddition<
                    InAppPurchaseAndroidPlatformAddition>();
                await androidAddition.consumePurchase(purchase);
              }
              // Analitik: 'purchase' — SADECE doğrulanıp tüketildikten
              // SONRA loglanır (iptal/hata durumunda hiç loglanmaz).
              // Fiyat/para birimi queryProductDetails'ten gelen ProductDetails
              // üzerinden alınır — mağaza tarafından gerçek/güncel değer.
              final product = products[purchase.productID];
              unawaited(AnalyticsService.logPurchase(
                productId: purchase.productID,
                value: product?.rawPrice,
                currency: product?.currencyCode,
              ));
            }
            _pending.remove(purchase.productID);
            completer?.complete(verified);
          } catch (e, st) {
            _pending.remove(purchase.productID);
            CrashService.record(e, st, context: 'BillingService._onPurchaseUpdate');
            completer?.completeError(e);
          }
          break;
      }
    }
  }

  /// Worker'daki /api/verify-purchase ucuna makbuzu (purchaseToken) POST
  /// eder; Worker bunu Google Play Developer API'ye sorup gerçek
  /// "purchased" durumunu döner. Ağ hatası / worker'da servis hesabı henüz
  /// kurulmadıysa (GOOGLE_SERVICE_ACCOUNT_JSON eksikse) GÜVENLİ TARAF:
  /// `false` — yani şüpheli durumda satın alma REDDEDİLİR, sessizce kabul
  /// EDİLMEZ. (bkz. cloudflare/worker/src/index.mjs > handleVerifyPurchase)
  Future<bool> _verifyPurchaseServerSide(PurchaseDetails purchase) async {
    try {
      final res = await http
          .post(
            Uri.parse('${HostingConfig.baseUrl}/api/verify-purchase'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
            }),
          )
          .timeout(const Duration(seconds: 15));
      // 06.09.2026 eklendi — bkz. server_time_service.dart: satın alma
      // doğrulaması zaten sık tetiklenen bir worker çağrısı olduğu için
      // clock-skew'i tazelemek için iyi bir fırsat.
      ServerTimeService.updateFromResponse(res);
      if (res.statusCode != 200) {
        debugPrint('Billing: doğrulama isteği ${res.statusCode} döndü — reddediliyor.');
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['valid'] == true;
    } catch (e, st) {
      CrashService.record(e, st, context: 'BillingService._verifyPurchaseServerSide');
      debugPrint('Billing: sunucu doğrulaması başarısız (ağ/format hatası) — reddediliyor: $e');
      return false;
    }
  }

  /// Worker'daki /api/verify-subscription ucuna makbuzu POST eder —
  /// _verifyPurchaseServerSide ile AYNI gerekçe (istemci tarafının
  /// "purchased" dediğine tek başına GÜVENİLMEZ), TEK FARK: abonelik
  /// HESAP BAZLI olduğu için productId yerine uid gönderilir (worker
  /// gerçek productId'yi zaten Google'ın kendi yanıtından okur — bkz.
  /// cloudflare/worker/src/index.mjs > handleVerifySubscription,
  /// schema.sql > subscriptions tablosu uid PRIMARY KEY).
  Future<bool> _verifySubscriptionServerSide(PurchaseDetails purchase) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      // buySubscription başında zaten engellenmiş olmalı — buraya
      // düşülmesi beklenmez, savunma amaçlı GÜVENLİ TARAF: reddet.
      debugPrint('Billing: abonelik doğrulaması için giriş yapılmamış — reddediliyor.');
      return false;
    }
    try {
      final res = await http
          .post(
            Uri.parse('${HostingConfig.baseUrl}/api/verify-subscription'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'purchaseToken': purchase.verificationData.serverVerificationData,
            }),
          )
          .timeout(const Duration(seconds: 15));
      ServerTimeService.updateFromResponse(res);
      if (res.statusCode != 200) {
        debugPrint('Billing: abonelik doğrulama isteği ${res.statusCode} döndü — reddediliyor.');
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['valid'] == true;
    } catch (e, st) {
      CrashService.record(e, st, context: 'BillingService._verifySubscriptionServerSide');
      debugPrint('Billing: abonelik sunucu doğrulaması başarısız (ağ/format hatası) — reddediliyor: $e');
      return false;
    }
  }
}
