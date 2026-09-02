import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/mailbox_service.dart';
import '../services/lead_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/locale_controller.dart';
import '../localization/app_strings.dart';
import '../widgets/store_sheet.dart';
import 'home_screen.dart';
import 'projects_screen.dart';
import 'mailbox_screen.dart';
import 'lead_inbox_screen.dart';

/// Uygulamanın gerçek "kök" ekranı — [SplashScreen] artık [HomeScreen]
/// yerine buraya yönlendiriyor.
///
/// 01.09.2026 eklendi — daha önce Projeler/Mağaza/Kutu/Talepler ikonları
/// HomeScreen'in ÜST panelindeydi. Artık hepsi burada, EKRANIN ALTINDA
/// sabit duran tek bir gezinme çubuğunda toplanıyor:
///
///  - "Ana Sayfa" ve "Projeler": [IndexedStack] içinde birer SEKME —
///    aralarında geçiş yaparken ekran her seferinde yeniden kurulmaz,
///    sadece görünür/gizli olur.
///  - "Mağaza": sekme DEĞİL — dokununca eskisi gibi bir sheet açılır
///    (showStoreSheet), seçili sekme değişmez. Satın alma akışı zaten
///    hızlı bir sheet'e uygun, tam ekrana çevirmeye gerek yok.
///  - "Kutu" ve "Talepler": artık YENİ BİR EKRAN olarak PUSH ediliyor
///    (bkz. mailbox_screen.dart / lead_inbox_screen.dart) — geri tuşuyla
///    kapanıyorlar, alt çubuğun ÜSTÜNE biner (normal sayfa davranışı).
///
/// Not: Hızlı Araçlar'daki bir forma girildiğinde (örn. QR oluşturma) o
/// ekran da yine PUSH ile açılıyor ve alt çubuğu geçici olarak kaplıyor —
/// bu, WhatsApp/Instagram gibi çoğu uygulamadaki standart davranışla
/// aynı: sabit çubuk sadece ANA sekmelerde görünür, bir detay/form
/// ekranına girildiğinde o ekran tüm alanı kaplar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  List<Widget> get _tabs => [
        const HomeScreen(),
        ProjectsScreen(onBackToHome: () => setState(() => _tabIndex = 0)),
      ];

  Future<void> _onNavTap(int navIndex) async {
    switch (navIndex) {
      case 0:
        setState(() => _tabIndex = 0);
        break;
      case 1:
        setState(() => _tabIndex = 1);
        break;
      case 2:
        await showStoreSheet(context);
        break;
      case 3:
        await openMailboxScreen(context);
        break;
      case 4:
        await openLeadInboxScreen(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    context.watch<LocaleController>();
    final isDark = themeController.isDark;
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: _BottomNavBar(
        isDark: isDark,
        currentIndex: _tabIndex,
        uid: uid,
        onTap: _onNavTap,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final bool isDark;
  final int currentIndex;
  final String? uid;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.isDark,
    required this.currentIndex,
    required this.uid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkIconChipBg : Colors.white;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(0.08);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: t(context, 'Ana Sayfa'),
              selected: currentIndex == 0,
              isDark: isDark,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.folder_rounded,
              label: t(context, 'Projeler'),
              selected: currentIndex == 1,
              isDark: isDark,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.storefront_rounded,
              label: t(context, 'Mağaza'),
              selected: false,
              isDark: isDark,
              onTap: () => onTap(2),
            ),
            _NavBadgeItem(
              icon: Icons.mail_rounded,
              label: t(context, 'Kutu'),
              isDark: isDark,
              onTap: () => onTap(3),
              countStream: uid == null ? null : MailboxService.instance.watchUnclaimedCount(uid!),
            ),
            _NavBadgeItem(
              icon: Icons.move_to_inbox_rounded,
              label: t(context, 'Talepler'),
              isDark: isDark,
              onTap: () => onTap(4),
              countStream: uid == null ? null : LeadService.instance.watchUnreadCount(uid!),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.accentBlue;
    final inactiveColor = isDark ? Colors.white60 : Colors.black54;
    final color = selected ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBadgeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final Stream<int>? countStream;

  const _NavBadgeItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    required this.countStream,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? Colors.white60 : Colors.black54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: inactiveColor),
                if (countStream != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: StreamBuilder<int>(
                      stream: countStream,
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        if (count <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 14),
                          decoration: const BoxDecoration(
                            color: AppColors.accentRed,
                            borderRadius: BorderRadius.all(Radius.circular(7)),
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: inactiveColor),
            ),
          ],
        ),
      ),
    );
  }
}
