import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// "Sitora rozetini kaldır" akışının bottom sheet'i.
///
/// MODEL: site bazlı, tek seferlik satın alma. Sadece [project] için
/// geçerlidir — kullanıcının diğer projeleri bu satın almadan etkilenmez
/// (bkz. AppState.removeWatermarkForProject dokümantasyonu).
///
/// ÖDEME ENTEGRASYONU: kProductRemoveWatermark, Play Console'da CONSUMABLE
/// olarak tanımlanmalı (bkz. billing_constants.dart'taki açıklama) — aynı
/// ürün, kullanıcının farklı sitelerinde tekrar tekrar satın alınabilmeli.
/// BillingService.buyConsumable gerçek mağaza ödeme akışını açar ve
/// SONUÇLANANA kadar bekler; `true` dönerse (ödeme+tüketim tamam) SADECE O
/// ZAMAN AppState.removeWatermarkForProject çağrılır. Mağaza henüz
/// kurulmadıysa (BillingService.isAvailable false ya da ürün Play
/// Console'da yoksa) kullanıcıya net bir hata gösterilir, sessizce
/// rozet kaldırılmaz.
Future<void> showRemoveWatermarkSheet(
  BuildContext context, {
  required SiteProject project,
}) async {
  // SAVUNMA KATMANI: bu satın alma akışı her zaman preview_screen.dart
  // veya store_sheet.dart üzerinden, zaten bir requireLogin kontrolünden
  // GEÇMİŞ olarak çağrılır — ama "rozet kaldırma girişe bağlıdır" kuralının
  // İLERİDE eklenecek başka bir çağıran tarafından yanlışlıkla atlanmasını
  // önlemek için kontrol burada da tekrar yapılır. Zaten giriş yapılmışsa
  // requireLogin hiçbir şey göstermeden anında true döner (ek bir popup
  // YOK), yani mevcut çağıran taraflar için davranış değişmez.
  final ok = await requireLogin(context, feature: t(context, 'Rozeti Kaldır'));
  if (!ok || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RemoveWatermarkSheet(project: project),
  );
}

class _RemoveWatermarkSheet extends StatefulWidget {
  final SiteProject project;

  const _RemoveWatermarkSheet({required this.project});

  @override
  State<_RemoveWatermarkSheet> createState() => _RemoveWatermarkSheetState();
}

class _RemoveWatermarkSheetState extends State<_RemoveWatermarkSheet> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductRemoveWatermark);
      if (!purchased) {
        // Kullanıcı mağaza ekranında vazgeçti — sessizce geri dön, hata
        // gösterme (bu bir hata değil, bilinçli bir iptal).
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().removeWatermarkForProject(widget.project.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  /// Diğer satın alma sheet'leriyle (buy_points_sheet.dart, store_sheet.dart,
  /// publish_paywall_sheet.dart) AYNI desen: BillingService.products, Play
  /// Console'dan queryProductDetails ile canlı çekilen fiyatı (kullanıcının
  /// bölgesine göre otomatik lokalize/formatlanmış) tutar. Ürün henüz
  /// yüklenmediyse ya da mağaza kurulmadıysa (isAvailable false) '—' gösterir
  /// — buton yine de tıklanabilir, gerçek fiyat mağaza ekranında görünür.
  String _priceLabel() {
    final product = BillingService.instance.products[kProductRemoveWatermark];
    return product?.price ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    // Proje adı gibi dinamik veri içeren metinler t() ile değil, doğrudan
    // isEnglish() bayrağıyla dallanır (bkz. app_strings.dart açıklaması).
    final en = isEnglish(context);
    final name = widget.project.name;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 22,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_done ? '✅' : '🏷️', style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 10),
            Text(
              _done
                  ? t(context, 'Rozet kaldırıldı!')
                  : t(context, 'Sitora rozetini kaldır'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _done
                  ? (en
                      ? '"$name" will now publish without the "Made with Sitora" badge. This applies ONLY to this site.'
                      : '"$name" artık "Sitora ile üretildi" rozeti olmadan yayınlanır. Bu, SADECE bu site için geçerlidir.')
                  : (en
                      ? 'This purchase applies ONLY to "$name" — it\'s one-time and won\'t affect the other sites in your account. To remove the badge on other sites, you\'ll need to purchase separately for each.'
                      : 'Bu satın alma SADECE "$name" için geçerlidir — tek seferlik, hesabınızdaki diğer siteleri etkilemez. Diğer sitelerinizde rozeti kaldırmak isterseniz her biri için ayrı satın almanız gerekir.'),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            if (!_done)
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _busy
                      ? (en ? 'Processing...' : 'İşleniyor...')
                      : (en
                          ? 'Buy — For This Site (${_priceLabel()})'
                          : 'Satın Al — Bu Site İçin (${_priceLabel()})'),
                  emoji: _busy ? null : '💳',
                  borderColor: const Color(0xFF29B6F6),
                  textColor: Colors.white,
                  filled: true,
                  fillColor: const Color(0xFF29B6F6),
                  height: 46,
                  fontSize: 14,
                  onTap: _busy ? null : _purchase,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: 'Kapat',
                  borderColor: Colors.white24,
                  textColor: Colors.white,
                  height: 46,
                  fontSize: 14,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
