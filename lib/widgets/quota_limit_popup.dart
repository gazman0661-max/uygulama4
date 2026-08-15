import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// Aylık ücretsiz puan kotası (FORM ya da AI havuzu) dolduğunda
/// gösterilen custom popup. Tek butonlu: "Tamam" (kapat).
Future<void> showQuotaLimitPopup(BuildContext context) {
  return _showLimitPopup(
    context,
    emoji: '🌙',
    title: t(context, 'Bu ayki limitiniz doldu'),
    message: 'Ücretsiz aylık krediniz bitti. Puanlarınız her ayın 1\'inde yenilenecek.',
  );
}

/// Worker'daki TÜM Gemini modelleri rate-limit'e (HTTP 429, çok fazla
/// eşzamanlı kullanıcı) takıldığında gösterilen custom popup. Kullanıcının
/// KENDİ aylık puanıyla ilgisi yoktur — sunucu genel olarak yoğundur.
Future<void> showWorkerBusyPopup(BuildContext context) {
  return _showLimitPopup(
    context,
    emoji: '⏳',
    title: t(context, 'Sunucumuz şu an çok yoğun'),
    message: 'Çok fazla kullanıcı aynı anda istek attığı için Gemini geçici olarak '
        'yanıt vermiyor. Birkaç dakika sonra tekrar deneyebilirsiniz.',
  );
}

Future<void> _showLimitPopup(
  BuildContext context, {
  required String emoji,
  required String title,
  required String message,
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
