import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// index.html'deki showAppPopup(message, icon) ile birebir aynı: ortada,
/// büyük bir ikon + mesaj + "Tamam" butonu olan kısa bilgilendirme popup'ı.
/// AI düzenleme sonuçları (başarı/kapsam-dışı red/güvenlik red/hata) için
/// SnackBar yerine bu kullanılır.
Future<void> showAppPopup(
  BuildContext context, {
  required String message,
  String icon = 'ℹ️',
}) {
  return showDialog<void>(
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
              t(ctx, message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t(ctx, 'Tamam'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Ekran görüntülerindeki (AI Kod Düzenleyici / AI Arka Plan Düzenleyici)
/// ile birebir aynı, EKRANIN ORTASINDA açılan AI istek popup'ı.
///
/// index.html'deki AI düzenleme bubble'ının Flutter karşılığıdır: yandan
/// süzülen bir sohbet paneli DEĞİL, kısa bir istek yazıp "Gönder ✨" ile
/// tek seferlik gönderilen ortalanmış bir kart.
///
/// Kullanıcı isteği yazıp gönderirse metni, iptal ederse null döner.
Future<String?> showAiEditDialog({
  required BuildContext context,
  required String icon,
  required String title,
  required String description,
  required String hint,
  Color accent = AppColors.accentCyan,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141821),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent, width: 1.4),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(ctx, title),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white54, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 14),
              Text(
                t(ctx, description),
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: t(ctx, hint),
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF29B6F6), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final v = controller.text.trim();
                      if (v.isEmpty) return;
                      Navigator.of(ctx).pop(v);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          t(ctx, 'Gönder ✨'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
