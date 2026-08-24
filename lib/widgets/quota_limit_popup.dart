import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';
import 'buy_points_sheet.dart';

/// Aylık ücretsiz puan kotası dolduğunda gösterilen custom popup.
/// "Puan Satın Al" ile satın alma sheet'ine yönlendirilebilir, ya da
/// "Tamam" ile kapatılabilir.
Future<void> showQuotaLimitPopup(BuildContext context) {
  return _showLimitPopup(
    context,
    emoji: '🌙',
    title: t(context, 'Bu ayki limitiniz doldu'),
    message: 'Ücretsiz aylık krediniz bitti. Puanlarınız her ayın 1\'inde yenilenecek.',
    showBuyPointsButton: true,
  );
}

Future<void> _showLimitPopup(
  BuildContext context, {
  required String emoji,
  required String title,
  required String message,
  bool showBuyPointsButton = false,
}) async {
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
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text(
              t(ctx, title),
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
              t(ctx, message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (showBuyPointsButton) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    showBuyPointsSheet(context);
                  },
                  child: Text(
                    '⭐ ${t(ctx, 'Puan Satın Al')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: showBuyPointsButton
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        t(ctx, 'Tamam'),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                    )
                  : ElevatedButton(
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
