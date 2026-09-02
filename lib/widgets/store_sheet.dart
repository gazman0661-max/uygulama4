import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buy_points_sheet.dart';
import '../widgets/remove_watermark_sheet.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// Ana sayfadaki "Mağaza" butonunun açtığı sheet — mevcut üç satın alma
/// akışının (puan paketi, yayın hakkı, rozet kaldırma) tek bir yerden
/// tetiklenebildiği giriş noktası.
///
/// Puan paketi ve yayın hakkı zaten hesap genelinde geçerli olduğu için
/// direkt satın alınabiliyor. Rozet kaldırma SİTE BAZLI olduğu için
/// (bkz. remove_watermark_sheet.dart) burada önce bir proje seçtiriyoruz,
/// sonra mevcut showRemoveWatermarkSheet akışını aynen çağırıyoruz —
/// böylece asıl satın alma mantığı tek yerde (remove_watermark_sheet.dart)
/// kalıyor, burası sadece "hangi site" sorusunu ekliyor.
Future<void> showStoreSheet(BuildContext context) async {
  // Mağazadaki ÜÇ satın alma akışının (puan, yayın hakkı, rozet kaldırma)
  // tamamı hesaba bağlıdır — bu yüzden giriş kontrolü burada, sheet hiç
  // açılmadan önce yapılır (bkz. login_gate.dart > requireLogin). Zaten
  // giriş yapılmışsa hiçbir şey göstermeden anında devam eder.
  final ok = await requireLogin(context, feature: t(context, 'Mağaza'));
  if (!ok || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _StoreSheet(),
  );
}

class _StoreSheet extends StatefulWidget {
  const _StoreSheet();

  @override
  State<_StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends State<_StoreSheet> {
  bool _buyingPublishSlot = false;
  String? _error;

  Future<void> _buyPublishSlot() async {
    setState(() {
      _buyingPublishSlot = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductPublishSlot);
      if (!purchased) {
        // Kullanıcı mağaza ekranında vazgeçti — hata değil, sessizce dön.
        if (mounted) setState(() => _buyingPublishSlot = false);
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().addPurchasedPublishCredit();
      if (!mounted) return;
      setState(() => _buyingPublishSlot = false);
      final en = isEnglish(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(en ? 'Publish credit added ✅' : 'Yayın hakkı eklendi ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buyingPublishSlot = false;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _pickProjectForWatermark() async {
    final appState = context.read<AppState>();
    // Rozeti zaten kaldırılmış projeleri listeye koymuyoruz — tekrar
    // satın almaya gerek yok, AppState zaten watermarkRemoved'ı kalıcı
    // tutuyor.
    final eligible = appState.projects.where((p) => !p.watermarkRemoved).toList();
    final en = isEnglish(context);

    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(en
              ? 'No eligible sites — create a site first, or every site already has the badge removed.'
              : 'Uygun site yok — önce bir site oluşturman lazım, ya da tüm sitelerinde rozet zaten kaldırılmış.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<SiteProject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141821),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProjectPickerSheet(projects: eligible),
    );
    if (selected == null || !mounted) return;

    // Ana mağaza sheet'ini kapatmıyoruz — kullanıcı isterse rozet
    // kaldırma sheet'i kapandıktan sonra başka bir ürüne de bakabilsin.
    await showRemoveWatermarkSheet(context, project: selected);
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final publishPriceLabel =
        BillingService.instance.products[kProductPublishSlot]?.price ?? t(context, 'Fiyat alınamadı');
    // 19.08.2026 eklendi: "Rozet Kaldır" satırı fiyatı hiç göstermiyordu,
    // sağda hep sabit "Site Seç" yazıyordu. Kullanıcı site seçmeden ÖNCE
    // fiyatı görebilsin diye, diğer satırlarla (Puan, Yayın Hakkı) aynı
    // desenle mağazadan canlı fiyatı çekip alt açıklamanın içine ekliyoruz.
    final watermarkPriceLabel =
        BillingService.instance.products[kProductRemoveWatermark]?.price ?? t(context, 'Fiyat alınamadı');
    final appState = context.watch<AppState>();

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
            const Text('🛍️', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              t(context, 'Mağaza'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            _StoreRow(
              emoji: '⭐',
              title: t(context, 'Puan Satın Al'),
              subtitle: t(context, 'Form kotan bittiğinde otomatik kullanılır, ay sonunda sıfırlanmaz.'),
              trailingLabel: t(context, 'Paketleri Gör'),
              onTap: () {
                Navigator.of(context).pop();
                showBuyPointsSheet(context);
              },
            ),
            const SizedBox(height: 12),
            _StoreRow(
              emoji: '🚀',
              title: t(context, 'Ek Site Yayın Hakkı'),
              subtitle: en
                  ? 'You have ${appState.extraPublishCredits} unused credit(s). First site is free — every extra site needs one of these.'
                  : 'Elinde ${appState.extraPublishCredits} kullanılmamış hak var. İlk site ücretsiz — sonraki her yeni site için bir tane gerekir.',
              trailingLabel: _buyingPublishSlot ? t(context, 'İşleniyor...') : publishPriceLabel,
              onTap: _buyingPublishSlot ? null : _buyPublishSlot,
            ),
            const SizedBox(height: 12),
            _StoreRow(
              emoji: '🏷️',
              title: t(context, 'Rozet Kaldır'),
              subtitle: en
                  ? 'Site-specific — pick which site. Price: $watermarkPriceLabel'
                  : 'Site bazlıdır — hangi site için istediğini seçmen gerekir. Fiyat: $watermarkPriceLabel',
              trailingLabel: t(context, 'Site Seç'),
              onTap: _pickProjectForWatermark,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(context, 'Kapat'), style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback? onTap;

  const _StoreRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white60, fontFamily: 'monospace', fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailingLabel,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Rozet Kaldır" için hangi siteye uygulanacağını seçtiren basit liste
/// sheet'i. Sadece bir [SiteProject] döner (Navigator.pop(project)) — asıl
/// satın alma mantığına hiç dokunmaz.
class _ProjectPickerSheet extends StatelessWidget {
  final List<SiteProject> projects;
  const _ProjectPickerSheet({required this.projects});

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 22, bottom: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              en ? 'Which site?' : 'Hangi site?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = projects[i];
                  return Material(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.language, color: Colors.white54, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(en ? 'Cancel' : 'Vazgeç', style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}
