import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// 04.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği).
///
/// Free plan kullanıcısı premium'a özel bir özelliğe (Talep Kutusu, harita/
/// talep formu, "Bizi Google'de değerlendirin" butonu, ziyaretçi sayısı,
/// galeri limiti üstü fotoğraf vb.) dokunduğunda gösterilen ORTAK kilit
/// popup'ı. Sade bir kalıp kullanır (emoji + başlık + mesaj + tek buton).
///
/// Domain bağlama/premium satın alma akışı henüz UI'a bağlanmadığı için
/// (bkz. SiteProject.isPremium yorumu) burada ŞİMDİLİK bir "satın al"
/// butonu YOK — sadece bilgilendirip kapatıyor. O akış açıldığında bu
/// popup'a bir CTA butonu eklemek yeterli olacak.
Future<void> showPremiumLockedPopup(
  BuildContext context, {
  String? message,
}) async {
  AnalyticsService.logPaywallShown(trigger: 'premium_locked');
  final en = isEnglish(context);
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text(
              en ? 'Premium feature' : 'Premium özellik',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  (en
                      ? 'This feature is available with a subscription or a custom-domain package (locked on the free plan).'
                      : 'Bu özellik abonelik veya özel domain paketinde açılır (ücretsiz planda kilitli).'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  t(ctx, 'Tamam'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
