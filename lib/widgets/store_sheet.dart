import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/login_gate.dart';
import '../widgets/quota_overflow_picker_sheet.dart';
import '../widgets/domain_quota_overflow_picker_sheet.dart';
import '../screens/domain_connect_screen.dart';
import '../screens/subscription_plans_screen.dart';
import '../localization/app_strings.dart';
import 'app_popup.dart';

Future<void> showStoreSheet(BuildContext context) async {
  final ok = await requireLogin(context, feature: t(context, 'Mağaza'));
  if (!ok || !context.mounted) return;
  AnalyticsService.logPaywallShown(trigger: 'store');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StoreSheet(),
  );
}

class _StoreSheet extends StatefulWidget {
  const _StoreSheet();

  @override
  State<_StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends State<_StoreSheet> {
  bool _buyingPublishSlot = false;
  String? _error;

  Future<void> _buyPublishSlot() async {
    setState(() {
      _buyingPublishSlot = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductPublishSlot);
      if (!purchased) {
        if (mounted) setState(() => _buyingPublishSlot = false);
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().addPurchasedPublishCredit();
      if (!mounted) return;
      setState(() => _buyingPublishSlot = false);
      final en = isEnglish(context);
      showAppPopup(context, message: en ? 'Publish credit added ✅' : 'Yayın hakkı eklendi ✅', icon: '✅');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buyingPublishSlot = false;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _pickProjectForDomain() async {
    final appState = context.read<AppState>();
    final eligible = appState.projects.toList();
    final en = isEnglish(context);

    if (eligible.isEmpty) {
      showAppPopup(context, message: en
              ? 'No eligible sites — create a site first.'
              : 'Uygun site yok — önce bir site oluşturman lazım.');
      return;
    }

    final selected = await showModalBottomSheet<SiteProject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectPickerSheet(projects: eligible),
    );
    if (selected == null || !mounted) return;

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DomainConnectScreen(project: selected)),
    );
  }

  Future<void> _openSubscriptionPlans() async {
    Navigator.of(context).pop();
    await showSubscriptionPlansScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final publishPriceLabel =
        BillingService.instance.products[kProductPublishSlot]?.price ?? t(context, 'Fiyat alınamadı');
    final domainPriceLabel =
        BillingService.instance.products[kProductConnectDomain]?.price ?? t(context, 'Fiyat alınamadı');
    final appState = context.watch<AppState>();

    final isDark = context.watch<ThemeController>().isDark;
    final sheetBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final rowBg = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.035);
    final infoBoxBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final infoBoxBorder = isDark ? Colors.white24 : Colors.black12;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.6 : 0.65);
    final closeColor = isDark ? Colors.grey.shade500 : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 22,
            bottom: MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Text('🛍️', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              t(context, 'Mağaza'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoBoxBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: infoBoxBorder, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      en
                          ? 'A subscription OR connecting your own domain removes the badge AND unlocks: lead inbox, map, lead form, Google review button + Google Business Profile Setup Wizard, visitor stats, Google Search Console connection. These are locked only on the free plan. To use them, open the relevant site from My Projects and update it via the "Edit" button; the Search Console connection is set from the "Search Console" button on the site\'s card in My Projects (no republish needed). The wizard does not create your Google profile — Google does, with your account; it prepares your details, guides you through Google\'s free sign-up and connects your review link to your site.'
                          : 'Abonelik VEYA kendi domainini bağlamak, rozeti kaldırmanın YANI SIRA şunları da açar: Talep Kutusu, harita, talep formu, Google yorum butonu + Google İşletme Profili Kurulum Sihirbazı, ziyaretçi sayısı, Google Search Console bağlantısı. Bunlar sadece ücretsiz planda kilitlidir. Kullanmak için ilgili siteyi Projelerim ekranından açıp "Düzenle" butonuyla güncellemen gerekir; Search Console bağlantısı ise Projelerim\'deki site kartında bulunan "Search Console" butonundan yapılır (yeniden yayınlamak gerekmez). Sihirbaz Google profilini senin yerine açmaz — profili Google senin hesabınla açar; sihirbaz bilgilerini hazırlar, Google\'ın ücretsiz kayıt ekranına yönlendirir ve yorum linkini sitene bağlar.',
                      style: TextStyle(
                        color: subtleColor,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _StoreRow(
              emoji: '🚀',
              title: t(context, 'Ek Site Yayın Hakkı'),
              subtitle: en
                  ? 'You have ${appState.extraPublishCredits + appState.giftPublishCredits} unused credit(s). First site is free — every extra site needs one of these.'
                  : 'Elinde ${appState.extraPublishCredits + appState.giftPublishCredits} kullanılmamış hak var. İlk site ücretsiz — sonraki her yeni site için bir tane gerekir.',
              trailingLabel: _buyingPublishSlot ? t(context, 'İşleniyor...') : publishPriceLabel,
              onTap: _buyingPublishSlot ? null : _buyPublishSlot,
              rowBg: rowBg,
              titleColor: titleColor,
              subtitleColor: subtleColor,
            ),
            const SizedBox(height: 12),
            _StoreRow(
              emoji: '🌐',
              title: t(context, 'Kendi Domainimi Bağla'),
              subtitle: en
                  ? 'Site-specific, 1 year — connects your own domain, removes the badge while the domain is active (if it expires, the badge comes back), AND unlocks other premium features, including the Google Business Profile Setup Wizard and the Google Search Console connection (download not included, sold separately). Also adds +1 extra site publish right to your account. One-time purchase, does NOT auto-renew. Extending before it expires requires the same purchase again. Price: $domainPriceLabel'
                  : 'Site bazlıdır, 1 yıllık — kendi alan adına bağlanır, rozeti domain aktif olduğu sürece kaldırır (süre dolarsa rozet geri gelir) VE diğer premium özellikleri açar; Google İşletme Profili Kurulum Sihirbazı ve Google Search Console bağlantısı dahil (indirme dahil değildir, ayrı satılır). Ayrıca hesabına +1 ek site yayın hakkı ekler. Tek seferlik satın almadır, OTOMATİK YENİLENMEZ. Süresi dolmadan uzatmak aynı satın almayı gerektirir. Fiyat: $domainPriceLabel',
              trailingLabel: t(context, 'Site Seç'),
              onTap: _pickProjectForDomain,
              rowBg: rowBg,
              titleColor: titleColor,
              subtitleColor: subtleColor,
            ),
            const SizedBox(height: 12),
            _StoreRow(
              emoji: '📅',
              title: t(context, 'Abonelik Planları'),
              subtitle: en
                  ? 'Account-wide, auto-renewing monthly plans — bundles a site quota with the badge/lock unlocks above, including the Google Business Profile Setup Wizard and the Google Search Console connection. Pages per site: Başlangıç 5, Mini 15, Freelancer and Freelancer Max unlimited. Custom-domain quota is included on Mini, Freelancer, and Freelancer Max; the entry-level Başlangıç Paket does not include a domain quota. See plan comparison and pricing.'
                  : 'Hesap genelinde, otomatik yenilenen aylık paketler — yukarıdaki rozet/kilit açımlarını (Google İşletme Profili Kurulum Sihirbazı ve Google Search Console bağlantısı dahil) bir site kotasıyla paketler. Site başına sayfa sayısı: Başlangıç 5, Mini 15, Freelancer ve Freelancer Max sınırsız. Domain kotası Mini, Freelancer ve Freelancer Max\'ta vardır; en giriş seviyesi Başlangıç Paket domain bağlama hakkı içermez. Paket karşılaştırması ve fiyatları gör.',
              trailingLabel: appState.hasActiveSubscription
                  ? t(context, 'Yönet')
                  : (en ? 'Compare' : 'Karşılaştır'),
              onTap: _openSubscriptionPlans,
              rowBg: rowBg,
              titleColor: titleColor,
              subtitleColor: subtleColor,
            ),
            if (appState.hasSubscriptionQuotaOverflow) ...[
              const SizedBox(height: 12),
              _StoreRow(
                emoji: '⚠️',
                title: en ? 'Quota overflow — pick sites' : 'Kota aşımı — site seç',
                subtitle: en
                    ? 'You have more sites than your current plan allows. Choose which ones keep their premium benefits.'
                    : 'Şu anki paketinin izin verdiğinden fazla siten var. Hangilerinin premium avantajları koruyacağını seç.',
                trailingLabel: en ? 'Choose' : 'Seç',
                onTap: () => showQuotaOverflowPickerSheet(context),
                rowBg: rowBg,
                titleColor: titleColor,
                subtitleColor: subtleColor,
              ),
            ],
            if (appState.hasDomainQuotaOverflow) ...[
              const SizedBox(height: 12),
              _StoreRow(
                emoji: '🌐',
                title: en ? 'Domain quota overflow — pick domains' : 'Domain kota aşımı — domain seç',
                subtitle: en
                    ? 'You have more connected domains than your current plan allows. Choose which ones stay connected — the rest will be disconnected.'
                    : 'Şu anki paketinin izin verdiğinden fazla bağlı domain\'in var. Hangilerinin bağlı kalacağını seç — geri kalanlar söktürülür.',
                trailingLabel: en ? 'Choose' : 'Seç',
                onTap: () => showDomainQuotaOverflowPickerSheet(context),
                rowBg: rowBg,
                titleColor: titleColor,
                subtitleColor: subtleColor,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(context, 'Kapat'), style: TextStyle(color: closeColor)),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback? onTap;
  final Color rowBg;
  final Color titleColor;
  final Color subtitleColor;

  const _StoreRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
    required this.rowBg,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: rowBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: subtitleColor, fontFamily: 'monospace', fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailingLabel,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectPickerSheet extends StatelessWidget {
  final List<SiteProject> projects;
  const _ProjectPickerSheet({required this.projects});

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final isDark = context.watch<ThemeController>().isDark;
    final sheetBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final rowBg = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.035);
    final iconColor = isDark ? Colors.white54 : Colors.black45;
    final closeColor = isDark ? Colors.grey.shade500 : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 22, bottom: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              en ? 'Which site?' : 'Hangi site?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = projects[i];
                  return Material(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.language, color: iconColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: titleColor, fontFamily: 'monospace', fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(en ? 'Cancel' : 'Vazgeç', style: TextStyle(color: closeColor)),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
