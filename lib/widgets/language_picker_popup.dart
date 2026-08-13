import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../localization/locale_controller.dart';

/// Uygulama ilk kez açıldığında (henüz bir dil seçilmemişse) gösterilen,
/// kapatılamayan dil seçim popup'ı. Kullanıcı TR veya EN seçene kadar
/// ekranda kalır; seçim yapılınca [LocaleController] güncellenir ve
/// tüm uygulama seçilen dile göre yeniden çizilir.
Future<void> showLanguagePickerPopup(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141821),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12, width: 1.2),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌐', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 12),
              const Text(
                'Dil Seçin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Select Language',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              _LanguageOptionButton(
                flag: '🇹🇷',
                label: 'Türkçe',
                onTap: () async {
                  await Provider.of<LocaleController>(ctx, listen: false)
                      .setLanguage(AppLanguage.tr);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 12),
              _LanguageOptionButton(
                flag: '🇬🇧',
                label: 'English',
                onTap: () async {
                  await Provider.of<LocaleController>(ctx, listen: false)
                      .setLanguage(AppLanguage.en);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LanguageOptionButton extends StatelessWidget {
  final String flag;
  final String label;
  final VoidCallback onTap;

  const _LanguageOptionButton({
    required this.flag,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentCyan.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
