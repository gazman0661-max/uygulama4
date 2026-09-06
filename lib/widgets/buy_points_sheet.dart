import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';
import 'app_popup.dart';

/// Puan paketi satın alma bottom sheet'i — 15/30/50/100 puanlık dört sabit
/// consumable paket (bkz. billing_constants.dart > kPointsPackageAmounts).
///
/// Satın alınan puanlar AppState.purchasedPoints'e eklenir: aylık ücretsiz
/// FORM kotasının aksine ayın 1'inde SIFIRLANMAZ, iki havuz da bittiğinde
/// otomatik devreye girer (bkz. AppState._spendFromPool).
///
/// Fiyatlar BillingService.products üzerinden mağazadan dinamik okunur —
/// Play Console'da ürünler henüz tanımlanmadıysa (iskelet aşaması) o paket
/// için "Fiyat alınamadı" gösterilir ama buton yine de dokunulabilir kalır
/// (dokunulduğunda BillingService zaten anlamlı bir hata fırlatıp
/// yakalanacak).
Future<void> showBuyPointsSheet(BuildContext context) async {
  // Uygulama içi satın alma e-posta girişi şartına bağlı (bkz.
  // login_gate.dart > requireLogin) — puanlar hesaba bağlı kalıcı bir
  // bakiyedir, giriş yapılmadan satın alınamaz. Zaten giriş yapılmışsa
  // requireLogin hiçbir şey göstermeden anında true döner.
  final ok = await requireLogin(context, feature: t(context, 'Puan Satın Al'));
  if (!ok || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _BuyPointsSheet(),
  );
}

class _BuyPointsSheet extends StatefulWidget {
  const _BuyPointsSheet();

  @override
  State<_BuyPointsSheet> createState() => _BuyPointsSheetState();
}

class _BuyPointsSheetState extends State<_BuyPointsSheet> {
  // Şu an satın alınmakta olan paketin ürün kimliği — sadece o paketin
  // butonunda yükleniyor göstergesi çıksın diye (diğer üç paket tıklanabilir
  // kalır ama BillingService zaten aynı anda tek akışı destekler, bkz.
  // BillingService._pending).
  String? _buyingProductId;
  String? _error;

  Future<void> _buy(String productId, int amount) async {
    setState(() {
      _buyingProductId = productId;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(productId);
      if (!purchased) {
        if (mounted) setState(() => _buyingProductId = null);
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().addPurchasedPoints(amount);
      if (!mounted) return;
      setState(() => _buyingProductId = null);
      Navigator.of(context).pop();
      final en = isEnglish(context);
      showAppPopup(context, message: en ? '$amount points added ✅' : '$amount puan eklendi ✅', icon: '✅');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buyingProductId = null;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  String _priceLabel(String productId) {
    final product = BillingService.instance.products[productId];
    return product?.price ?? t(context, 'Fiyat alınamadı');
  }

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              t(context, 'Puan Satın Al'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(context,
                  'Satın aldığın puanlar ayın sonunda sıfırlanmaz; aylık ücretsiz kotan bittiğinde otomatik kullanılır.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            for (final entry in kPointsPackageAmounts.entries) ...[
              _PointsPackageTile(
                label: isEnglish(context) ? '${entry.value} points' : '${entry.value} puan',
                priceLabel: _priceLabel(entry.key),
                busy: _buyingProductId == entry.key,
                onTap: _buyingProductId != null ? null : () => _buy(entry.key, entry.value),
              ),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: _buyingProductId != null ? null : () => Navigator.of(context).pop(),
              child: Text(t(context, 'Vazgeç'), style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsPackageTile extends StatelessWidget {
  final String label;
  final String priceLabel;
  final bool busy;
  final VoidCallback? onTap;

  const _PointsPackageTile({
    required this.label,
    required this.priceLabel,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PillButton(
        label: busy ? t(context, 'İşleniyor...') : '$label — $priceLabel',
        emoji: busy ? null : '💳',
        borderColor: AppColors.accentBlue,
        textColor: Colors.white,
        filled: true,
        fillColor: AppColors.accentBlue,
        height: 46,
        fontSize: 14,
        onTap: onTap,
      ),
    );
  }
}
