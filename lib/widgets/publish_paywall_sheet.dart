import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../localization/app_strings.dart';

/// İlk site yayını ücretsizdir; bu sheet SADECE AppState.canPublishProject
/// false döndüğünde (yani ikinci ve sonraki bir YENİ site yayınlanmak
/// istendiğinde ve elde satın alınmış bir yayın kredisi de yoksa) açılır
/// (bkz. preview_screen.dart > _publishSite).
///
/// Satın alma (kProductPublishSlot) tamamlandığında SADECE
/// AppState.addPurchasedPublishCredit() çağrılır — krediyi asıl "harcayıp"
/// projeye kalıcı olarak bağlayan adım (AppState.grantPublishRight),
/// kullanıcı gerçekten Yayınla'ya bastığında markProjectPublished
/// içinden otomatik tetiklenir. Bu sheet başarıyla kapandığında çağıran
/// taraf normal showPublishSheet akışına devam etmelidir.
///
/// Dönüş değeri: satın alma başarıyla tamamlanıp kredi eklendiyse `true`,
/// kullanıcı vazgeçtiyse/hata olduysa `false`.
Future<bool> showPublishPaywallSheet(
  BuildContext context, {
  required SiteProject project,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PublishPaywallSheet(project: project),
  );
  return result ?? false;
}

class _PublishPaywallSheet extends StatefulWidget {
  final SiteProject project;
  const _PublishPaywallSheet({required this.project});

  @override
  State<_PublishPaywallSheet> createState() => _PublishPaywallSheetState();
}

class _PublishPaywallSheetState extends State<_PublishPaywallSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductPublishSlot);
      if (!purchased) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().addPurchasedPublishCredit();
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final priceLabel = BillingService.instance.products[kProductPublishSlot]?.price ??
        t(context, 'Fiyat alınamadı');
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
            const Text('🚀', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              t(context, 'Ücretsiz yayın hakkın doldu'),
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
              en
                  ? 'You already published your one free site. Publishing "${widget.project.name}" as a new site costs $priceLabel — every additional site after the first is the same price.'
                  : '"${widget.project.name}" adlı bu siteyi yayınlamak için bir yayın hakkı satın almalısın — ücretsiz hakkını zaten kullandın. İkinci ve sonraki her yeni site aynı fiyattan: $priceLabel.',
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: _busy ? t(context, 'İşleniyor...') : '${t(context, 'Satın Al')} — $priceLabel',
                emoji: _busy ? null : '💳',
                borderColor: AppColors.accentBlue,
                textColor: Colors.white,
                filled: true,
                fillColor: AppColors.accentBlue,
                height: 46,
                fontSize: 14,
                onTap: _busy ? null : _purchase,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: Text(t(context, 'Vazgeç'), style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}
