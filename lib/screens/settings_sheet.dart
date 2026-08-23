import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/pill_button.dart';
import '../services/auth_service.dart';
import '../widgets/login_gate.dart';

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
            _AccountSection(
              fieldBg: fieldBg,
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            const SizedBox(height: 20),
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

/// "Ayarlar" içindeki Hesap bölümü — giriş durumunu gösterir.
///
/// Firebase henüz kurulmadıysa (AuthService.isAvailable == false, çok
/// eski bir build'de kalınmışsa) sessizce hiçbir şey göstermez. Aksi
/// halde: giriş yapılmışsa e-posta + "Çıkış Yap"; yapılmamışsa
/// "Google ile Giriş Yap" butonu (login_gate.dart'taki aynı akışı
/// tetikler, feature adı olarak "Hesap" verilir).
class _AccountSection extends StatefulWidget {
  final Color fieldBg;
  final Color textColor;
  final Color subTextColor;

  const _AccountSection({
    required this.fieldBg,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await requireLogin(context, feature: t(context, 'Hesap'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NOT: isAvailable AuthService'te 'static' tanımlı (AuthService.instance
    // üzerinden değil, doğrudan AuthService.isAvailable ile okunur —
    // currentUser/authStateChanges/signOut ise instance üyesi, onlar
    // .instance üzerinden çağrılmaya devam ediyor).
    if (!AuthService.isAvailable) return const SizedBox.shrink();

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.fieldBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: user != null
              ? Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accentCyan.withOpacity(0.2),
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? Icon(Icons.person, size: 18, color: widget.textColor)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user.email ?? t(context, 'Giriş yapıldı'),
                        style: TextStyle(color: widget.textColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _signOut,
                      child: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t(context, 'Çıkış Yap'),
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: widget.subTextColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t(context, 'Misafir modundasın'),
                        style: TextStyle(color: widget.subTextColor, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _signIn,
                      child: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t(context, 'Giriş Yap'),
                              style: const TextStyle(color: AppColors.accentBlue, fontSize: 13)),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
