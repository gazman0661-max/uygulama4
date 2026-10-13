import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// showAppPopup ile aynı görsel dile sahip, iki butonlu (Onayla/Vazgeç)
/// custom uyarı popup'ı. Silme gibi geri alınamaz işlemler öncesi
/// kullanıcıdan onay almak için kullanılır.
///
/// Kullanıcı onaylarsa true, vazgeçerse veya popup'ı dışarı tıklayıp
/// kapatırsa false/null döner.
Future<bool> showConfirmPopup(
  BuildContext context, {
  required String title,
  required String message,
  String icon = '⚠️',
  String confirmLabel = 'Evet, Sil',
  String cancelLabel = 'Vazgeç',
  Color confirmColor = const Color(0xFFEF5350),
}) async {
  final result = await showDialog<bool>(
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
            Text(icon, style: const TextStyle(fontSize: 34)),
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
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(t(ctx, cancelLabel),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(t(ctx, confirmLabel),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
