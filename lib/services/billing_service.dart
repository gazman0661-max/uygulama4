import 'analytics_service.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_strings.dart';
import '../models/game_progress.dart';
import '../widgets/ui_kit.dart';
import '../models/piggy.dart';
import '../models/season.dart';
import 'cloud_save_service.dart';

import 'log_service.dart';
/// Mücevher paketi (Play Console'daki ürün ID'si + verilecek mücevher).
/// Fiyat KODDA TUTULMAZ: Play Billing'den (ProductDetails.price) gelir.
class GemPack {
  final String id;
  final int gems;
  final bool best;
  const GemPack(this.id, this.gems, {this.best = false});
}

/// Başlangıç paketi: tek seferlik. İçeriği GameProgress.grantStarterPack.
const GemPack kStarterPack = GemPack('starter_pack', 150);

const List<GemPack> kGemPacks = [
  GemPack('gems_80', 80),
  GemPack('gems_550', 550, best: true),
  GemPack('gems_1200', 1200),
  GemPack('gems_7000', 7000),
];

enum _Kind { consumable, oneTime }

class _Item {
  final _Kind kind;
  final void Function() grant;
  const _Item(this.kind, this.grant);
}

/// GOOGLE PLAY BILLING (in_app_purchase).
///
/// PLAY CONSOLE'DA OLUŞTURULACAK ÜRÜNLER (Monetize > Products > In-app products):
///   gems_80, gems_550, gems_1200, gems_7000,
///   starter_pack, piggy_bank, season_pass_premium
/// (ID'ler birebir aynı olmalı; hepsi "Aktif" olmalı.)
///
/// TÜKETİLEBİLİR: mücevher paketleri, kumbara, sezon premium (her ay yeniden
/// alınır). TEK SEFERLİK: başlangıç paketi (satın alınca bir daha alınamaz).
///
/// GÜVENLİK/SAĞLAMLIK:
///  * Ürün oyuncuya STREAM'den teslim edilir (uygulama satın alma sırasında
///    kapansa bile bir sonraki açılışta [restorePurchases] ile teslim edilir).
///  * Sıra: önce VER -> sonra TÜKET/ONAYLA. Aynı sipariş (orderId) iki kez
///    verilmez ([_kProcessed]).
///  * Henüz sunucu tarafı makbuz doğrulaması YOK (istemci tarafı). İleride
///    Cloudflare Worker ile purchaseToken doğrulaması eklenebilir.
class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const String _kProcessed = 'iap_processed_orders_v1';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;
  bool _hadPending = false;
  Map<String, ProductDetails> _products = {};

  Completer<bool>? _userCompleter;
  String? _userProductId;
  bool _userSawPending = false;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  late final Map<String, _Item> _catalog = {
    for (final p in kGemPacks) p.id: _Item(_Kind.consumable, () => GameProgress.instance.addGems(p.gems)),
    kStarterPack.id: _Item(_Kind.oneTime, () => GameProgress.instance.grantStarterPack(kStarterPack.gems)),
    PiggyService.productId: _Item(_Kind.consumable, _grantPiggy),
    SeasonService.premiumProductId: _Item(_Kind.consumable, () => SeasonService.instance.unlockPremium()),
  };

  void _grantPiggy() {
    final n = PiggyService.instance.breakOpen();
    // Kumbara bu arada boşalmışsa (ör. satın alma sonradan teslim edildi)
    // oyuncu mağdur olmasın: en az kırma miktarı verilir.
    if (n == 0) GameProgress.instance.addGems(PiggyService.minToBreak);
  }

  // ------------------------------------------------------------ fiyatlar

  /// Butonda gösterilecek fiyat (Play'den, yerel para biriminde). Ürün
  /// Play'den henüz yüklenmediyse kilit simgesi.
  String priceOf(String productId) => _products[productId]?.price ?? '🔒';

  bool isPurchasable(String productId) => _available && _products.containsKey(productId);

  // ------------------------------------------------------------ başlatma

  Future<void> init() async {
    if (!_isAndroid || _sub != null) return;
    try {
      _available = await _iap.isAvailable();
      AppLog.i('billing', 'init: isAvailable=$_available');
      if (!_available) return;
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        AppLog.e('billing', 'purchaseStream HATASI', e);
      });
      await _loadProducts();
      // Teslim edilmemiş / yarım kalmış / geri yüklenecek satın almalar.
      unawaited(_iap.restorePurchases());
    } catch (err) { AppLog.w('billing_service._loadProducts', 'yutulan hata', err); }
  }

  Future<void> _loadProducts() async {
    try {
      final resp = await _iap.queryProductDetails(_catalog.keys.toSet());
      _products = {for (final d in resp.productDetails) d.id: d};
      AppLog.i('billing', 'urunler: bulunan=${_products.keys.toList()} bulunamayan=${resp.notFoundIDs} hata=${resp.error?.message}');
      for (final d in resp.productDetails) {
        AppLog.i('billing', '  ${d.id} fiyat=${d.price} (${d.currencyCode})');
      }
      notifyListeners();
    } catch (err) { AppLog.w('billing_service._loadProducts', 'yutulan hata', err); }
  }

  /// Uygulama öne dönünce: ürünler yüklenmediyse tekrar dene; bekleyen
  /// (pending) ödeme varsa sonucunu yeniden sor.
  Future<void> onResumed() async {
    if (!_isAndroid) return;
    try {
      if (_sub == null) {
        await init();
        return;
      }
      if (_products.isEmpty) await _loadProducts();
      if (_hadPending) unawaited(_iap.restorePurchases());
    } catch (err) { AppLog.w('billing_service.init', 'yutulan hata', err); }
  }

  // ------------------------------------------------------------ satın alma

  /// Satın alma akışını başlatır. true = ödeme başarılı VE ürün verildi.
  /// Mesajları (yakında/kullanılamıyor/bekliyor/hata) kendisi gösterir.
  Future<bool> buy(BuildContext context, String productId) async {
    AnalyticsService.instance.log('iap_start', {'product': productId});
    final item = _catalog[productId];
    final details = _products[productId];
    AppLog.i('billing', 'buy: $productId katalog=${item != null} musait=$_available detay=${details != null}');
    if (item == null || !_available || details == null) {
      AppLog.w('billing', 'buy: $productId KULLANILAMIYOR (Play Console urunu/aktiflik/yayin kontrol et)');
      _toast(context, 'iap_unavailable');
      return false;
    }
    if (_userCompleter != null && !_userCompleter!.isCompleted) return false;

    final c = Completer<bool>();
    _userCompleter = c;
    _userProductId = productId;
    _userSawPending = false;
    final param = PurchaseParam(productDetails: details);
    try {
      final started = item.kind == _Kind.consumable
          ? await _iap.buyConsumable(purchaseParam: param, autoConsume: false)
          : await _iap.buyNonConsumable(purchaseParam: param);
      AppLog.i('billing', 'buy: akis baslatildi=$started');
      if (!started && !c.isCompleted) c.complete(false);
    } catch (err) {
      AppLog.w('billing_service.buy', 'yutulan hata', err);
      if (!c.isCompleted) c.complete(false);
    }
    final ok = await c.future.timeout(const Duration(minutes: 10), onTimeout: () => false);
    _userCompleter = null;
    _userProductId = null;
    if (!ok && _userSawPending && context.mounted) _toast(context, 'iap_pending');
    return ok;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      AppLog.i('billing', 'purchaseStream: urun=${p.productID} durum=${p.status.name} id=${p.purchaseID} bekleyenOnay=${p.pendingCompletePurchase} hata=${p.error?.code}/${p.error?.message}');
      switch (p.status) {
        case PurchaseStatus.pending:
          _hadPending = true;
          if (p.productID == _userProductId) {
            _userSawPending = true;
            _completeUser(p.productID, false);
          }
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          AnalyticsService.instance.log(
              p.status == PurchaseStatus.canceled ? 'iap_canceled' : 'iap_error', {'product': p.productID});
          if (p.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(p);
            } catch (err) { AppLog.w('billing_service._onPurchases', 'yutulan hata', err); }
          }
          _completeUser(p.productID, false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(p);
          break;
      }
    }
  }

  Future<void> _deliver(PurchaseDetails p) async {
    final item = _catalog[p.productID];
    if (item == null) return;
    _hadPending = false;

    final orderId = (p.purchaseID != null && p.purchaseID!.isNotEmpty)
        ? p.purchaseID!
        : '${p.productID}:${p.transactionDate ?? ''}';
    final done = await _processedOrders();
    AppLog.i('billing', 'deliver: ${p.productID} siparis=$orderId zatenIslendi=${done.contains(orderId)}');
    if (!done.contains(orderId)) {
      AnalyticsService.instance.log('iap_purchase', {
        'product': p.productID,
        'restored': p.status == PurchaseStatus.restored ? 1 : 0,
      });
      item.grant();
      AppLog.i('billing', 'deliver: ${p.productID} oyuncuya VERILDI');
      done.add(orderId);
      await _saveProcessed(done);
      CloudSaveService.instance.uploadNow();
    }

    // Önce verildi, SONRA tüket/onayla.
    try {
      if (item.kind == _Kind.consumable) {
        final add = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await add.consumePurchase(p as GooglePlayPurchaseDetails);
      } else if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    } catch (err) {
      AppLog.w('billing_service._saveProcessed', 'yutulan hata', err);
      // Tüketilemezse bir sonraki açılışta tekrar gelir; orderId kayıtlı
      // olduğu için ikinci kez VERİLMEZ.
    }
    _completeUser(p.productID, true);
    notifyListeners();
  }

  void _completeUser(String productId, bool ok) {
    final c = _userCompleter;
    if (c != null && !c.isCompleted && _userProductId == productId) c.complete(ok);
  }

  // ------------------------------------------------------------ yardımcılar

  Future<Set<String>> _processedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_kProcessed) ?? const <String>[]).toSet();
    } catch (err) {
      AppLog.w('billing_service._completeUser', 'yutulan hata', err);
      return <String>{};
    }
  }

  Future<void> _saveProcessed(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = ids.toList();
      final trimmed = list.length > 300 ? list.sublist(list.length - 300) : list;
      await prefs.setStringList(_kProcessed, trimmed);
    } catch (err) { AppLog.w('billing_service._saveProcessed', 'yutulan hata', err); }
  }

  void _toast(BuildContext context, String key) {
    if (!context.mounted) return;
    showGamePopup(context, AppStrings.instance.t(key));
  }
}
