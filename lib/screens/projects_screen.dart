import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import '../services/hosting_service.dart';
import '../services/transfer_service.dart';
import '../services/billing_service.dart';
import '../constants/billing_constants.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/confirm_popup.dart';
import '../widgets/app_popup.dart';
import '../widgets/premium_locked_popup.dart';
import '../widgets/search_console_sheet.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import 'domain_connect_screen.dart';
import 'preview_screen.dart';
import 'subscription_plans_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const ProjectsScreen({super.key, this.onBackToHome});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Map<String, SiteStats> _liveStats = {};
  bool _loadingLiveStats = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLiveStats);
    Future.microtask(() {
      if (mounted) context.read<AppState>().revertExpiredDomainWatermarks();
    });
  }

  Future<void> _reconcileWithServer({required bool force}) async {
    final removed = await context.read<AppState>().reconcilePublishedWithServer(force: force);
    if (!mounted || removed.isEmpty) return;
    final en = isEnglish(context);
    final names = removed.map((n) => '"$n"').join(', ');
    await showAppPopup(
      context,
      icon: 'ℹ️',
      message: en
          ? '$names is no longer live on our servers (sites on the free plan that are not republished for 6 months are removed automatically). Your project is still on your device — you can publish it again anytime.'
          : '$names artık sunucuda yayında değil (ücretsiz planda 6 ay boyunca yeniden yayınlanmayan siteler otomatik kaldırılır). Projen cihazında duruyor — istediğin zaman tekrar yayınlayabilirsin.',
    );
  }

  Future<void> _loadLiveStats({bool manual = false}) async {
    if (!mounted) return;
    unawaited(_reconcileWithServer(force: manual));
    unawaited(context.read<AppState>().checkPendingTransferClaims());
    final publishedIds = context
        .read<AppState>()
        .projects
        .where((p) => p.isPublished && p.isPremium)
        .map((p) => p.id)
        .toList();
    if (publishedIds.isEmpty) return;
    setState(() => _loadingLiveStats = true);
    try {
      final stats = await HostingService.fetchStatsBatch(siteIds: publishedIds);
      if (mounted) setState(() => _liveStats = stats);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingLiveStats = false);
    }
  }

  void _shareProject(SiteProject project) {
    final url = project.publishedUrl;
    if (url == null || url.trim().isEmpty) return;
    final english = isEnglish(context);
    final message = english
        ? 'Check out ${project.name} — I really recommend it:\n$url'
        : '${project.name} sayfasına göz at, tavsiye ederim:\n$url';
    Share.share(message, subject: project.name);
  }

  Future<void> _openProject(SiteProject project) async {
    final appState = context.read<AppState>();
    await appState.openQtProject(project.id);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()),
    );
  }

  Future<void> _renameProject(SiteProject project) async {
    final newName = await showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _RenameDialog(initialName: project.name),
    );
    if (newName == null || newName.trim().isEmpty) return;
    if (!mounted) return;
    await context.read<AppState>().renameProject(project.id, newName.trim());
    if (mounted) {
      showAppPopup(context, message: t(context, 'Proje adı güncellendi.'), icon: '✏️');
    }
  }

  Future<void> _deleteProject(SiteProject project) async {
    final confirmed = await showConfirmPopup(
      context,
      title: t(context, 'Projeyi Sil'),
      message: '"${project.name}" ' +
          t(context, 'kalıcı olarak silinecek. Bu işlem geri alınamaz. Silmek istediğinizden emin misiniz?') +
          (project.isPublished
              ? '\n\n${t(context, "Bu proje şu anda YAYINDA — silince canlı sitesi de kaldırılacak.")}'
              : ''),
      icon: '🗑️',
      confirmLabel: t(context, 'Evet, Sil'),
      cancelLabel: t(context, 'Vazgeç'),
    );
    if (!confirmed) return;
    if (!mounted) return;
    await context.read<AppState>().deleteProject(project.id);
    if (mounted) {
      showAppPopup(context, message: t(context, 'Proje silindi.'), icon: '🗑️');
    }
  }

  Future<void> _unpublishProject(SiteProject project) async {
    final confirmed = await showConfirmPopup(
      context,
      title: t(context, 'Yayından Kaldır'),
      message: '"${project.name}" ' +
          t(context, 'yayından kaldırılacak, site adresi artık açılmayacak. Proje silinmez, istediğinde tekrar yayınlayabilirsin.') +
          (project.isDomainConnected
              ? (isEnglish(context)
                  ? '\n\nYour connected domain is disconnected too, and the domain right you paid for is not restored.'
                  : '\n\nBağlı domain bağlantın da kaldırılır ve satın aldığın domain hakkı geri gelmez.')
              : '') +
          (project.subscriptionQuotaExpiresAt != null
              ? (isEnglish(context)
                  ? '\n\nThis site frees its subscription slot. If you publish it again, it takes a free slot if one is available.'
                  : '\n\nBu site abonelik kotandaki yerini boşaltır. Tekrar yayınlarsan, boş slot varsa yeniden kullanılır.')
              : ''),
      icon: '📴',
      confirmLabel: t(context, 'Evet, Kaldır'),
      cancelLabel: t(context, 'Vazgeç'),
    );
    if (!confirmed) return;
    if (!mounted) return;
    try {
      await HostingService.unpublish(siteId: project.id, ownerToken: project.ownerToken);
      if (!mounted) return;
      await context.read<AppState>().markProjectUnpublished(project.id);
      if (!mounted) return;
      showAppPopup(context, message: t(context, 'Yayından kaldırıldı.'), icon: '📴');
    } catch (e) {
      if (!mounted) return;
      showAppPopup(context, message: t(context, e.toString()), icon: '⚠️');
    }
  }

  void _openDomainConnect(SiteProject project) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DomainConnectScreen(project: project)),
    );
  }

  Future<void> _duplicateProject(SiteProject project) async {
    final copy = await context.read<AppState>().duplicateProject(project.id);
    if (!mounted || copy == null) return;
    showAppPopup(context, message: t(context, 'Proje kopyalandı.'), icon: '🧬');
  }

  Future<void> _transferProject(SiteProject project) async {
    final confirmed = await showConfirmPopup(
      context,
      title: t(context, 'Siteyi Devret'),
      message: '"${project.name}" ' +
          t(context, 'için bir devir kodu üretilecek. Bu kodu müşterine WhatsApp\'tan iletebilirsin; kodu kullandığı an site TAMAMEN onun hesabına geçer (sen artık düzenleyemez/yayından kaldıramazsın). Devam edilsin mi?') +
          '\n\n' +
          t(context, 'Not: Sitedeki fotoğraflar da yeni sahibe aktarılır. Bunun için henüz yayınlanmamış fotoğraflar sunucuya yüklenir.'),
      icon: '🤝',
      confirmLabel: t(context, 'Kod Üret'),
      cancelLabel: t(context, 'Vazgeç'),
    );
    if (!confirmed) return;
    if (!mounted) return;
    try {
      final result = await context.read<AppState>().initiateProjectTransfer(project.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _TransferCodeDialog(code: result.code, expiresAt: result.expiresAt),
      );
    } catch (e) {
      if (!mounted) return;
      showAppPopup(context, message: t(context, e.toString()), icon: '⚠️');
    }
  }

  Future<void> _claimTransferCode() async {
    final code = await showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => const _ClaimTransferDialog(),
    );
    if (code == null || code.trim().isEmpty) return;
    if (!mounted) return;

    final appState = context.read<AppState>();
    final preview = await TransferService.preview(code: code.trim());
    if (!mounted) return;
    if (preview != null && preview.subscriptionPremium && !appState.hasActiveSubscription) {
      final proceed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141821),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            t(ctx, 'Devretmeden önce bilmen gereken bir şey var'),
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          content: Text(
            t(ctx,
                'Bu site bir aylık abonelik kapsamında rozetsizdi ve birden fazla sayfası olabilirdi. Kendi aboneliğin olmadığı için devraldığında rozet geri gelecek VE fazla sayfalar canlı siteden kaldırılacak — dilersen önce bir paket seçebilir, sonra AYNI kodla devralabilirsin.'),
            style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t(ctx, 'Yine de Devral'), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan),
              onPressed: () {
                Navigator.of(ctx).pop(false);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
                );
              },
              child: Text(t(ctx, 'Önce Paketleri Gör'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    var claimDomainViaOwnSubscription = false;
    var claimDomainViaPurchase = false;
    if (preview != null && preview.domainAtRisk) {
      bool hasOwnDomainRoom() {
        final tier = appState.activeSubscriptionTier;
        return appState.hasActiveSubscription && tier != null && appState.domainQuotaUsed < tier.domainQuota;
      }

      if (hasOwnDomainRoom()) {
        claimDomainViaOwnSubscription = true;
      } else {
        while (true) {
          final choice = await showDialog<String>(
            context: context,
            barrierColor: Colors.black87,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF141821),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(
                t(ctx, 'Bu site bir domainle geliyor'),
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
              content: Text(
                t(ctx,
                    'Domain, eski sahibin aylık aboneliğinden ücretsiz bağlanmış. Kendi aboneliğinde boş bir domain hakkın olmadığı için, devraldığında bu domain otomatik olarak sökülür. Domain kotası olan bir abonelik paketine geçersen (Mini/Freelancer/Freelancer Max — Başlangıç Paket\'te domain kotası yoktur) domain otomatik korunur; istersen bunun yerine yıllık domain bağlama ücretini tek seferlik ödeyip domaini siteyle birlikte kalıcı olarak da devralabilirsin.'),
                style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13),
              ),
              actionsOverflowDirection: VerticalDirection.down,
              actionsOverflowButtonSpacing: 4,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('cancel'),
                  child: Text(t(ctx, 'Vazgeç'), style: const TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('without_domain'),
                  child: Text(t(ctx, 'Domainsiz Devral'), style: const TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('buy_domain_once'),
                  child: Text(t(ctx, 'Tek Seferlik Yıllık Domain Öde'), style: const TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan),
                  onPressed: () => Navigator.of(ctx).pop('subscribe'),
                  child: Text(t(ctx, 'Abonelik Satın Al'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (choice == null || choice == 'cancel') return;
          if (!mounted) return;
          if (choice == 'subscribe') {
            await showSubscriptionPlansScreen(context);
            if (!mounted) return;
            if (hasOwnDomainRoom()) {
              claimDomainViaOwnSubscription = true;
              break;
            }
            continue;
          }
          if (choice == 'buy_domain_once') {
            try {
              final purchased = await BillingService.instance.buyConsumable(kProductConnectDomain);
              if (!mounted) return;
              if (!purchased) {
                return;
              }
              try {
                await appState.addPurchasedPublishCredit();
              } catch (_) {}
              claimDomainViaPurchase = true;
            } catch (e) {
              if (!mounted) return;
              showAppPopup(context, message: t(context, e.toString()), icon: '⚠️');
              return;
            }
          }
          break;
        }
      }
    }

    final claimQuotaViaOwnSubscription = appState.hasActiveSubscription &&
        appState.activeSubscriptionTier != null &&
        appState.subscriptionQuotaUsed < appState.activeSubscriptionTier!.siteQuota;

    try {
      final outcome = await appState.claimTransferredProject(
        code.trim(),
        claimDomainViaOwnSubscription: claimDomainViaOwnSubscription,
        claimDomainViaPurchase: claimDomainViaPurchase,
        claimQuotaViaOwnSubscription: claimQuotaViaOwnSubscription,
      );
      if (!mounted) return;
      final claimed = outcome.project;
      if (outcome.premiumLost) {
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black87,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF141821),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              '"${claimed.name}" ${t(ctx, 'artık senin!')}',
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            content: Text(
              t(ctx,
                  'Bu site bir aylık abonelik kapsamında rozetsizdi ve birden fazla sayfası olabilirdi. Kendi aboneliğin olmadığı için rozet geri geldi VE fazla sayfalar canlı siteden kaldırıldı. Bir paket seçtikten sonra bile bunların geri gelmesi için siteyi projeler ekranından bir kez yeniden yayınlaman gerekiyor.'),
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t(ctx, 'Şimdi değil'), style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
                  );
                },
                child: Text(t(ctx, 'Paketleri Gör'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else if (claimDomainViaOwnSubscription && outcome.domainOutcome == 'stripped') {
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black87,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF141821),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              '"${claimed.name}" ${t(ctx, 'artık senin!')}',
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            content: Text(
              t(ctx,
                  'Domain kotanda o an boş slot kalmamış olabilir — bu site şu an domainsiz devralındı. Dilersen yıllık domain ücretini ödeyip yeniden bağlayabilirsin.'),
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t(ctx, 'Tamam'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else if (outcome.domainOutcome == 'kept_via_subscription' || outcome.domainOutcome == 'kept_via_purchase') {
        showAppPopup(
          context,
          message: '"${claimed.name}" ${t(context, 'artık senin — domain dahil, Projelerim listende görünüyor.')}',
          icon: '🎉',
        );
      } else {
        showAppPopup(
          context,
          message: '"${claimed.name}" ${t(context, 'artık senin — Projelerim listende görünüyor.')}',
          icon: '🎉',
        );
      }
      if (mounted && outcome.missingImages > 0) {
        showAppPopup(
          context,
          message: '${outcome.missingImages} ' +
              t(context, 'fotoğraf indirilemedi ve boş kaldı. Yayınlamadan önce bu fotoğrafları yeniden yükle; yoksa canlı sitedeki görseller silinebilir.'),
          icon: '🖼️',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppPopup(context, message: t(context, e.toString()), icon: '⚠️');
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final isDark = context.watch<ThemeController>().isDark;
    final appState = context.watch<AppState>();
    final projects = appState.projectsByRecency;
    final publishedProjects = projects.where((p) => p.isPublished).toList();

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkBubbleBg : AppColors.lightBubbleBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(0.55);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: titleColor),
                    onPressed: () {
                      if (widget.onBackToHome != null) {
                        widget.onBackToHome!();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  Text(
                    t(context, 'Projelerim'),
                    style: TextStyle(
                      color: titleColor,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.key_outlined, size: 21, color: subtleColor),
                    tooltip: t(context, 'Kodla Site Devral'),
                    onPressed: _claimTransferCode,
                  ),
                  if (projects.isNotEmpty)
                    Text(
                      '${projects.length}',
                      style: TextStyle(
                        color: subtleColor,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.6),
            if (publishedProjects.isNotEmpty)
              _LiveSitesStrip(
                projects: publishedProjects,
                stats: _liveStats,
                loading: _loadingLiveStats,
                isDark: isDark,
                titleColor: titleColor,
                subtleColor: subtleColor,
                onRefresh: () => _loadLiveStats(manual: true),
                onTap: _openProject,
              ),
            Expanded(
              child: projects.isEmpty
                  ? _buildEmptyState(subtleColor)
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = projects[index];
                        final isOpen = p.id == appState.qtCurrentProjectId;
                        return _ProjectCard(
                          project: p,
                          isOpen: isOpen,
                          cardBg: cardBg,
                          titleColor: titleColor,
                          subtleColor: subtleColor,
                          dateLabel: _formatDate(p.updatedAt),
                          onTap: () => _openProject(p),
                          onRename: () => _renameProject(p),
                          onDelete: () => _deleteProject(p),
                          onDuplicate: () => _duplicateProject(p),
                          onDomain: p.isPublished ? () => _openDomainConnect(p) : null,
                          onShare: p.isPublished ? () => _shareProject(p) : null,
                          onUnpublish: p.isPublished ? () => _unpublishProject(p) : null,
                          onTransfer: p.isPublished ? () => _transferProject(p) : null,
                          onSearchConsole: p.isPublished ? () => showSearchConsoleSheet(context, p) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subtleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: subtleColor),
            const SizedBox(height: 12),
            Text(
              t(context, 'Henüz bir projen yok.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              t(context, 'Bir form doldurduğunda veya Sürükle-Bırak ile oluşturduğunda burada listelenecek.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSitesStrip extends StatelessWidget {
  final List<SiteProject> projects;
  final Map<String, SiteStats> stats;
  final bool loading;
  final bool isDark;
  final Color titleColor;
  final Color subtleColor;
  final VoidCallback onRefresh;
  final void Function(SiteProject) onTap;

  const _LiveSitesStrip({
    required this.projects,
    required this.stats,
    required this.loading,
    required this.isDark,
    required this.titleColor,
    required this.subtleColor,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: subtleColor.withOpacity(0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text('🌐 ', style: const TextStyle(fontSize: 13)),
                Text(
                  t(context, 'Yayında olan siteler'),
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: loading ? null : onRefresh,
                  child: loading
                      ? SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6, color: subtleColor),
                        )
                      : Text(
                          t(context, '↻ Yenile'),
                          style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final p = projects[index];
                final s = stats[p.id];
                return _LiveSiteChip(
                  project: p,
                  stats: s,
                  isDark: isDark,
                  titleColor: titleColor,
                  subtleColor: subtleColor,
                  onTap: () => onTap(p),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _LiveSiteChip extends StatelessWidget {
  final SiteProject project;
  final SiteStats? stats;
  final bool isDark;
  final Color titleColor;
  final Color subtleColor;
  final VoidCallback onTap;

  const _LiveSiteChip({
    required this.project,
    required this.stats,
    required this.isDark,
    required this.titleColor,
    required this.subtleColor,
    required this.onTap,
  });

  static ({String emoji, String text, bool emphasize}) _buildFomoLine(
      BuildContext context, SiteStats? stats) {
    final monthly = stats?.monthlyVisitCount ?? 0;
    if (monthly > 0) {
      return (
        emoji: '🎯 ',
        text: '$monthly ${t(context, "kişi bu ay ulaştı")}',
        emphasize: true,
      );
    }
    final total = stats?.visitCount;
    if (total != null && total > 0) {
      return (emoji: '👁 ', text: '$total ${t(context, "toplam")}', emphasize: false);
    }
    return (emoji: '👁 ', text: '—', emphasize: false);
  }

  @override
  Widget build(BuildContext context) {
    final locked = !project.isPremium;
    final todayCount = stats?.todayVisitCount;
    final fomo = _buildFomoLine(context, stats);
    return Material(
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 148,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              if (locked)
                _LockedVisitorStats(subtleColor: subtleColor)
              else ...[
                Row(
                  children: [
                    Text(fomo.emoji, style: const TextStyle(fontSize: 11)),
                    Expanded(
                      child: Text(
                        fomo.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fomo.emphasize ? AppColors.accentGreenLink : subtleColor,
                          fontFamily: 'monospace',
                          fontWeight: fomo.emphasize ? FontWeight.bold : FontWeight.normal,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (todayCount != null && todayCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '🔥 $todayCount ${t(context, 'bugün')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.accentGreenLink, fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedVisitorStats extends StatelessWidget {
  const _LockedVisitorStats({required this.subtleColor});

  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showPremiumLockedPopup(
        context,
        message: isEnglish(context)
            ? 'Seeing the visitor count for your published site is available with a subscription or a custom-domain package (locked on the free plan).'
            : 'Yayındaki sitenin ziyaretçi sayısını görmek abonelik veya özel domain paketinde açılır (ücretsiz planda kilitli).',
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 11, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              t(context, 'Ziyaretçi sayısı — Premium'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final SiteProject project;
  final bool isOpen;
  final Color cardBg;
  final Color titleColor;
  final Color subtleColor;
  final String dateLabel;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDomain;
  final VoidCallback? onShare;
  final VoidCallback? onUnpublish;
  final VoidCallback? onTransfer;
  final VoidCallback? onSearchConsole;

  const _ProjectCard({
    required this.project,
    required this.isOpen,
    required this.cardBg,
    required this.titleColor,
    required this.subtleColor,
    required this.dateLabel,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    this.onDuplicate,
    this.onDomain,
    this.onShare,
    this.onUnpublish,
    this.onTransfer,
    this.onSearchConsole,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = project.mode == SiteMode.multi
        ? t(context, 'Çok Sayfa')
        : t(context, 'Tek Sayfa');
    final modeColor = project.mode == SiteMode.multi ? AppColors.accentBlue : AppColors.accentCyan;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isOpen ? Border.all(color: AppColors.accentCyan, width: 1.4) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: modeColor, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (project.kind != ProjectKind.site) ...[
                              Text(project.kind.emoji, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.kind == ProjectKind.site
                              ? '$modeLabel · ${project.summary(isEnglish(context))} · $dateLabel'
                              : '$modeLabel · ${project.kind.label(isEnglish(context))} · $dateLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (onShare != null)
                    IconButton(
                      icon: Icon(Icons.share_outlined, size: 19, color: AppColors.accentGreenLink),
                      onPressed: onShare,
                      tooltip: t(context, 'İşletmeyi Öner'),
                    ),
                  if (onDuplicate != null)
                    IconButton(
                      icon: Icon(Icons.copy_outlined, size: 19, color: subtleColor),
                      onPressed: onDuplicate,
                      tooltip: t(context, 'Kopyala'),
                    ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 19, color: subtleColor),
                    onPressed: onRename,
                    tooltip: t(context, 'Adını Değiştir'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.danger),
                    onPressed: onDelete,
                    tooltip: t(context, 'Sil'),
                  ),
                ],
              ),
              if (onDomain != null || onUnpublish != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (onDomain != null)
                      Expanded(
                        child: _CardActionChip(
                          icon: project.isDomainConnected ? Icons.language : Icons.dns_outlined,
                          label: t(context, project.isDomainConnected ? 'Domain Bağlı' : 'Domain Bağla'),
                          color: project.isDomainConnected ? AppColors.accentGreenLink : subtleColor,
                          onTap: onDomain!,
                        ),
                      ),
                    if (onDomain != null && onUnpublish != null) const SizedBox(width: 8),
                    if (onUnpublish != null)
                      Expanded(
                        child: _CardActionChip(
                          icon: Icons.cloud_off_outlined,
                          label: t(context, 'Yayından Kaldır'),
                          color: AppColors.danger,
                          onTap: onUnpublish!,
                        ),
                      ),
                  ],
                ),
              ],
              if (onTransfer != null || onSearchConsole != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (onSearchConsole != null)
                      Expanded(
                        child: _CardActionChip(
                          icon: Icons.travel_explore,
                          label: project.googleVerificationCode != null
                              ? 'Search Console ✓'
                              : 'Search Console',
                          color: project.googleVerificationCode != null
                              ? AppColors.accentGreenLink
                              : subtleColor,
                          onTap: onSearchConsole!,
                        ),
                      ),
                    if (onSearchConsole != null && onTransfer != null) const SizedBox(width: 8),
                    if (onTransfer != null)
                      Expanded(
                        child: _CardActionChip(
                          icon: Icons.handshake_outlined,
                          label: t(context, 'Siteyi Devret'),
                          color: subtleColor,
                          onTap: onTransfer!,
                        ),
                      ),
                  ],
                ),
              ],
              if ((project.isDomainConnected && !project.isDomainExpired && project.domainExpiresAt != null) ||
                  project.isMiniPackageActive ||
                  (project.isPublished && !project.isPremium && project.freeTierPublishExpiresAt != null)) ...[
                const SizedBox(height: 6),
                if (project.isDomainConnected && !project.isDomainExpired && project.domainExpiresAt != null)
                  _RemainingTimeRow(
                    icon: Icons.language,
                    label: t(context, 'Domain'),
                    expiresAt: project.domainExpiresAt!,
                    color: AppColors.accentGreenLink,
                  ),
                if (project.isMiniPackageActive) ...[
                  if (project.isDomainConnected && !project.isDomainExpired && project.domainExpiresAt != null)
                    const SizedBox(height: 4),
                  _RemainingTimeRow(
                    icon: Icons.confirmation_number_outlined,
                    label: t(context, '1 Aylık Mini Paket'),
                    expiresAt: project.miniPackageExpiresAt!,
                    color: const Color(0xFFAB47BC),
                  ),
                ],
                if (project.isPublished && !project.isPremium && project.freeTierPublishExpiresAt != null)
                  _RemainingTimeRow(
                    icon: Icons.hourglass_bottom_outlined,
                    label: t(context, 'Ücretsiz Yayın'),
                    expiresAt: project.freeTierPublishExpiresAt!,
                    color: AppColors.accentOrange,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CardActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemainingTimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime expiresAt;
  final Color color;

  const _RemainingTimeRow({
    required this.icon,
    required this.label,
    required this.expiresAt,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final diff = expiresAt.difference(DateTime.now());
    final String remainingText;
    if (diff.isNegative) {
      remainingText = en ? 'Expired' : 'Süresi doldu';
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      remainingText = en
          ? '$days day${days == 1 ? '' : 's'} $hours hour${hours == 1 ? '' : 's'} left'
          : '$days gün $hours saat kaldı';
    }

    return Row(
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.85)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$label: $remainingText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withOpacity(0.85),
              fontFamily: 'monospace',
              fontSize: 10.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initialName;
  const _RenameDialog({required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(context, 'Proje Adını Değiştir'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t(context, 'Vazgeç'),
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(_controller.text),
                    child: Text(t(context, 'Kaydet'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferCodeDialog extends StatelessWidget {
  final String code;
  final DateTime expiresAt;
  const _TransferCodeDialog({required this.code, required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final dd = expiresAt.day.toString().padLeft(2, '0');
    final mm = expiresAt.month.toString().padLeft(2, '0');
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(context, 'Devir Kodu Hazır'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t(context, 'Bu kodu müşterine ilet — Sitora hesabıyla "Kodla Site Devral"dan girince site tamamen ona geçer.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${t(context, "Son geçerlilik")}: $dd.$mm.${expiresAt.year}',
              style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t(context, 'Kapat'),
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      showAppPopup(context, message: t(context, 'Kod kopyalandı.'), icon: '📋');
                    },
                    child: Text(t(context, 'Kopyala'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimTransferDialog extends StatefulWidget {
  const _ClaimTransferDialog();

  @override
  State<_ClaimTransferDialog> createState() => _ClaimTransferDialogState();
}

class _ClaimTransferDialogState extends State<_ClaimTransferDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(context, 'Kodla Site Devral'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t(context, 'Sana iletilen devir kodunu gir — site Projelerim listene eklenecek.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 1,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'AB3XK9QZ',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 3),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t(context, 'Vazgeç'),
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(_controller.text),
                    child: Text(t(context, 'Devral'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
