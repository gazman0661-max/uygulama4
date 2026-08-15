import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/pill_button.dart';

/// Gizlilik Politikası ve Kullanım Şartları sayfalarının canlı adresleri.
/// Ayarlar ekranındaki linkler ve açılış onay popup'ı bu adresleri kullanır.
const String kPrivacyPolicyUrl =
    'https://filinta01453-ui.github.io/sitora-ai-legal/Gizlilik_Politikasi.html';
const String kTermsOfUseUrl =
    'https://filinta01453-ui.github.io/sitora-ai-legal/Kullanim_Sartlari.html';

Future<void> openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDark;
    context.watch<LocaleController>();

    final bg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF0F2F5);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.accentCyan.withOpacity(0.6)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'Ayarlar'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentBlue,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                LanguageToggleButton(background: fieldBg, isDark: isDark),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _linkChip(t(context, 'Gizlilik Politikası'), subTextColor,
                    onTap: () => openLegalUrl(kPrivacyPolicyUrl)),
                _linkChip(t(context, 'Kullanım Şartları'), subTextColor,
                    onTap: () => openLegalUrl(kTermsOfUseUrl)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: subTextColor.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(t(context, 'Kapat'),
                    style: TextStyle(color: textColor, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkChip(String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontFamily: 'monospace')),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}
