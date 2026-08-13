import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/settings_sheet.dart';
import '../localization/app_strings.dart';

/// Günlük ücretsiz puan kotası dolduğunda gösterilen custom popup.
/// İki butonlu: "Tamam, Beklerim" (kapat) / "API Anahtarı Gir" (Ayarlar).
Future<void> showQuotaLimitPopup(BuildContext context) {
  return _showLimitPopup(
    context,
    emoji: '🌙',
    title: 'Bugünlük limitimiz doldu',
    message: 'Ücretsiz günlük krediniz bitti. Puanlarınız UTC 00:00\'da yenilenecek.\n\n'
        'Beklemek istemiyorsanız kendi Gemini API anahtarınızı girerek '
        'sınırsız kullanmaya devam edebilirsiniz.',
  );
}

/// Worker'daki TÜM Gemini modelleri rate-limit'e (HTTP 429, çok fazla
/// eşzamanlı kullanıcı) takıldığında gösterilen custom popup. Kullanıcının
/// KENDİ günlük puanıyla ilgisi yoktur — sunucu genel olarak yoğundur.
Future<void> showWorkerBusyPopup(BuildContext context) {
  return _showLimitPopup(
    context,
    emoji: '⏳',
    title: 'Sunucumuz şu an çok yoğun',
    message: 'Çok fazla kullanıcı aynı anda istek attığı için Gemini geçici olarak '
        'yanıt vermiyor. Birkaç dakika sonra tekrar deneyebilirsiniz.\n\n'
        'Beklemek istemiyorsanız kendi Gemini API anahtarınızı girerek '
        'hemen devam edebilirsiniz.',
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      t(ctx, 'Tamam, Beklerim'),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const SettingsSheet(),
                      );
                    },
                    child: Text(
                      t(ctx, 'API Anahtarı Gir'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
