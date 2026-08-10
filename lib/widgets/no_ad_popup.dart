import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// "🎬 Reklam İzle" butonuna basılıp gösterilecek reklam bulunamadığında
/// (no-fill / yükleme hatası) açılan custom popup. Bu durumda PUAN
/// EKLENMEZ — popup sadece bilgilendirir.
Future<void> showNoAdPopup(BuildContext context) async {
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
            const Text('📭', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text(
              t(ctx, 'Reklam Bulunamadı'),
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
              t(
                ctx,
                'Şu anda gösterilecek bir reklam bulunamadı, bu yüzden puan '
                'eklenmedi.\n\nLütfen birkaç dakika sonra tekrar deneyin.',
              ),
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
                  backgroundColor: AppColors.accentPurple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  t(ctx, 'Tamam'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
