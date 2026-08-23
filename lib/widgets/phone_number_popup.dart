import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// WhatsApp elemanı eklenirken/düzenlenirken telefon numarası isteyen
/// custom popup. Kullanıcı yalnızca rakam girer (başında ülke koduyla,
/// örn. 905xxxxxxxxx); popup bunu otomatik olarak bir wa.me bağlantısına
/// çevirir. Vazgeçilirse null döner.
Future<String?> showWhatsAppPhonePopup(
  BuildContext context, {
  String? initialPhone,
}) async {
  final controller = TextEditingController(text: initialPhone ?? '');
  String? errorText;

  return showDialog<String>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
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
              const Text('📱', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 10),
              Text(
                t(ctx, 'WhatsApp Telefon Numarası'),
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
                t(ctx, 'Ülke kodu ile birlikte, boşluksuz giriniz.\nÖrn: 905551112233'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: t(context, '905551112233'),
                  hintStyle: const TextStyle(color: Colors.white38),
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: Text(t(ctx, 'Vazgeç'),
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
                        backgroundColor: AppColors.accentCyan,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final digits = controller.text.trim();
                        if (digits.length < 8) {
                          setState(() =>
                              errorText = t(ctx, 'Lütfen geçerli bir telefon numarası giriniz.'));
                          return;
                        }
                        Navigator.of(ctx).pop(digits);
                      },
                      child: Text(t(ctx, 'Ekle'),
                          style: const TextStyle(
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
    ),
  );
}
