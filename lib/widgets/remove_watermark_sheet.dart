import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

Future<void> showRemoveWatermarkSheet(
  BuildContext context, {
  required SiteProject project,
}) async {
  final ok = await requireLogin(context, feature: t(context, 'Rozeti Kaldır'));
  if (!ok || !context.mounted) return;
  AnalyticsService.logPaywallShown(trigger: 'remove_watermark');

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

  Future<void> _redeemGift() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<AppState>().redeemGiftWatermarkRemoval(widget.project.id);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductRemoveWatermark);
      if (!purchased) {
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

  String _priceLabel() {
    final product = BillingService.instance.products[kProductRemoveWatermark];
    return product?.price ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final name = widget.project.name;
    final giftCredits = context.watch<AppState>().giftWatermarkRemovalCredits;
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
                      ? '"$name" will now publish without the "Made with MySitora" badge. This applies ONLY to this site.'
                      : '"$name" artık "MySitora ile üretildi" rozeti olmadan yayınlanır. Bu, SADECE bu site için geçerlidir.')
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
            if (!_done && giftCredits > 0) ...[
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _busy
                      ? (en ? 'Processing...' : 'İşleniyor...')
                      : (en
                          ? 'Use gift credit ($giftCredits left)'
                          : 'Hediye hakkını kullan ($giftCredits adet)'),
                  emoji: _busy ? null : '🎁',
                  borderColor: const Color(0xFF66BB6A),
                  textColor: Colors.white,
                  filled: true,
                  fillColor: const Color(0xFF66BB6A),
                  height: 46,
                  fontSize: 14,
                  onTap: _busy ? null : _redeemGift,
                ),
              ),
              const SizedBox(height: 10),
            ],
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
