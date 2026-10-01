import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import '../constants/billing_constants.dart';
import 'auth_service.dart';
import 'crash_service.dart';
import 'analytics_service.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool isAvailable = false;

  final Map<String, ProductDetails> products = {};

  Set<String> notFoundProductIds = {};

  final Map<String, Completer<bool>> _pending = {};

  GooglePlayPurchaseDetails? _ownedSubscriptionPurchase;

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
      return _pending[productId]!.future;
    }
    final completer = Completer<bool>();
    _pending[productId] = completer;
    AnalyticsService.logPurchaseStarted(productId: productId);

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: false);
    } catch (e) {
      _pending.remove(productId);
      AnalyticsService.logPurchaseFailed(productId: productId, reason: 'store_error');
      rethrow;
    }
    return completer.future;
  }

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
    AnalyticsService.logPurchaseStarted(productId: productId);

    final owned = _ownedSubscriptionPurchase;
    final isSwitchingPlan = owned != null && owned.productID != productId;

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
      AnalyticsService.logPurchaseFailed(productId: productId, reason: 'store_error');
      rethrow;
    }
    return completer.future;
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final completer = _pending[purchase.productID];
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;

        case PurchaseStatus.error:
          _pending.remove(purchase.productID);
          AnalyticsService.logPurchaseFailed(
            productId: purchase.productID,
            reason: purchase.error?.code ?? 'error',
          );
          completer?.completeError(
            StateError(purchase.error?.message ?? 'Satın alma başarısız.'),
          );
          break;

        case PurchaseStatus.canceled:
          _pending.remove(purchase.productID);
          AnalyticsService.logPurchaseCancelled(productId: purchase.productID);
          completer?.complete(false);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            final isSubscription =
                kAllSubscriptionProductIds.contains(purchase.productID);
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
              } else {
                final androidAddition = _iap.getPlatformAddition<
                    InAppPurchaseAndroidPlatformAddition>();
                await androidAddition.consumePurchase(purchase);
              }
              if (purchase.status == PurchaseStatus.purchased) {
                final product = products[purchase.productID];
                unawaited(AnalyticsService.logPurchase(
                  productId: purchase.productID,
                  value: product?.rawPrice,
                  currency: product?.currencyCode,
                ));
              }
            } else if (purchase.status == PurchaseStatus.purchased) {
              AnalyticsService.logPurchaseFailed(
                productId: purchase.productID,
                reason: 'verify_failed',
              );
            }
            _pending.remove(purchase.productID);
            completer?.complete(verified);
          } catch (e, st) {
            _pending.remove(purchase.productID);
            CrashService.record(e, st, context: 'BillingService._onPurchaseUpdate');
            AnalyticsService.logPurchaseFailed(
              productId: purchase.productID,
              reason: 'exception',
            );
            completer?.completeError(e);
          }
          break;
      }
    }
  }

  Future<bool> _verifyPurchaseServerSide(PurchaseDetails purchase) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      debugPrint('Billing: satın alma doğrulaması için giriş yapılmamış — reddediliyor.');
      return false;
    }
    try {
      final idToken = await user.getIdToken();
      final res = await http
          .post(
            Uri.parse('${HostingConfig.baseUrl}/api/verify-purchase'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
            }),
          )
          .timeout(const Duration(seconds: 15));
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

  Future<bool> _verifySubscriptionServerSide(PurchaseDetails purchase) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('Billing: abonelik doğrulaması için giriş yapılmamış — reddediliyor.');
      return false;
    }
    try {
      final idToken = await AuthService.instance.currentUser?.getIdToken();
      if (idToken == null) return false;
      final res = await http
          .post(
            Uri.parse('${HostingConfig.baseUrl}/api/verify-subscription'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
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

  Future<bool> verifyDownloadEntitlement(
    String projectId, {
    required bool wantsWatermarkFree,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      debugPrint('Billing: indirme doğrulaması için giriş yapılmamış — reddediliyor.');
      return false;
    }
    try {
      final idToken = await user.getIdToken();
      final res = await http
          .post(
            Uri.parse('${HostingConfig.baseUrl}/api/downloads/$projectId/check'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'wantsWatermarkFree': wantsWatermarkFree}),
          )
          .timeout(const Duration(seconds: 15));
      ServerTimeService.updateFromResponse(res);
      if (res.statusCode != 200) {
        debugPrint('Billing: indirme doğrulama isteği ${res.statusCode} döndü — reddediliyor.');
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['allowed'] == true;
    } catch (e, st) {
      CrashService.record(e, st, context: 'BillingService.verifyDownloadEntitlement');
      debugPrint('Billing: indirme sunucu doğrulaması başarısız (ağ/format hatası) — reddediliyor: $e');
      return false;
    }
  }
}
