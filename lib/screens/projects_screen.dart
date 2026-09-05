import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import '../services/hosting_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/confirm_popup.dart';
import '../widgets/app_popup.dart';
import '../widgets/premium_locked_popup.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import 'preview_screen.dart';

/// PROJELERİM ekranı.
///
/// Kullanıcının Hızlı Araçlar (form) ile ürettiği veya cihazdan içe
/// aktardığı TÜM siteleri listeler (AppState.projects). Her satırdan:
/// - dokununca proje Hızlı Araçlar slotuna yüklenir ve ÖN İZLEME ekranı
///   (QuickToolsPreviewScreen) açılır (bkz. _openProject),
/// - kalem ikonuyla adı değiştirilebilir,
/// - çöp ikonuyla kalıcı olarak silinebilir.
class ProjectsScreen extends StatefulWidget {
  /// 02.09.2026 eklendi — ÖNEMLİ ÇÖKME/SİYAH EKRAN DÜZELTMESİ: Bu ekran
  /// bir Navigator sayfası olarak PUSH EDİLMİYOR — MainShell içindeki
  /// IndexedStack'te sabit duran bir SEKME. MainShell de SplashScreen
  /// tarafından pushReplacement ile açıldığı için navigasyon yığınındaki
  /// TEK sayfa. Eskiden üstteki geri oku "Navigator.of(context).pop()"
  /// çağırıyordu; geri dönülecek bir sayfa olmadığından bu, uygulamanın
  /// tek kalan sayfasını yığından silip ekranı SİYAH bırakıyordu
  /// ("Projelerim'deyken geri okuna basınca siyah ekran" şikayeti).
  /// Artık MainShell, bu callback ile "Ana Sayfa" sekmesine dönmeyi
  /// sağlıyor — gerçek bir Navigator pop'u hiç gerekmiyor.
  final VoidCallback? onBackToHome;

  const ProjectsScreen({super.key, this.onBackToHome});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  /// Yayındaki projelerin ziyaretçi istatistikleri (siteId -> SiteStats).
  /// Ekran her açıldığında TEK bir toplu istekle doldurulur (bkz.
  /// HostingService.fetchStatsBatch) — her kart için ayrı sorgu YOK.
  Map<String, SiteStats> _liveStats = {};
  bool _loadingLiveStats = false;

  @override
  void initState() {
    super.initState();
    // build() içinde context.read çağırmak yerine ilk frame'den hemen
    // sonra tetikleniyor — Provider ağacı bu noktada zaten hazır, ama
    // initState sırasında context.read kullanmak bazı Provider
    // sürümlerinde "widget henüz ağaçta değil" uyarısına yol açabiliyor,
    // o yüzden bilinçli olarak bir mikro-task'a erteleniyor.
    Future.microtask(_loadLiveStats);
    // 05.09.2026 eklendi — Projelerim açıldığında, süresi dolmuş bir domain
    // paketi varsa o projenin rozetini geri getir (kanka kararı: kullanıcı
    // uygulamayı yeniden açmadan sadece bu listeye bakınca bile durum
    // güncel olsun). bkz. AppState.revertExpiredDomainWatermarks.
    Future.microtask(() {
      if (mounted) context.read<AppState>().revertExpiredDomainWatermarks();
    });
  }

  /// 05.09.2026 değişti (kanka isteği, madde 8'in devamı — maliyet
  /// optimizasyonu): önceden BURADA tüm yayındaki projeler (premium+free)
  /// worker'a batch istek olarak gidiyor, kilit sadece EKRANDA (bkz.
  /// _LiveSiteChip > _LockedVisitorStats) uygulanıyordu — yani free bir
  /// hesapta bile her ekran açılışında/"↻ Yenile"ye basıldığında worker'a
  /// gereksiz sorgu (D1 SELECT/SUM maliyeti) gidiyordu, sonuç sadece
  /// gösterilmiyordu. Artık `p.isPremium` DEĞİLSE siteId listeye hiç
  /// girmiyor: free-only bir hesapta bu fonksiyon artık ağa hiç çıkmıyor
  /// (aşağıdaki `if (publishedIds.isEmpty) return;` early-return'ü
  /// tetikleniyor) — "↻ Yenile" dahil, hiçbir tetikleyici free proje için
  /// worker'a istek atmıyor. Karma bir hesapta (bazı siteleri premium)
  /// sadece premium olanlar için sorgu gidiyor.
  Future<void> _loadLiveStats() async {
    if (!mounted) return;
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
      // Sessizce yutulur: worker henüz kurulmamış olabilir (test aşaması)
      // ya da geçici bir ağ hatası — bu durumda kartlar sadece istatistik
      // rozetini GÖSTERMEZ, "Yayında olan siteler" bölümü yine de listeyi
      // (URL/tarih) gösterir. Kritik hiçbir akışı bloklamaz.
    } finally {
      if (mounted) setState(() => _loadingLiveStats = false);
    }
  }

  /// "İşletmeyi Öner" viral paylaşım butonu. Sadece yayınlanmış
  /// (isPublished) projelerde gösterilir — publishedUrl olmadan
  /// paylaşılacak bir link yok. share_plus zaten projede mevcut
  /// (download_service.dart'ta dosya paylaşımı için kullanılıyor);
  /// burada ekstra maliyetsiz metin paylaşımı (Share.share) kullanılıyor
  /// — WhatsApp/Instagram/SMS gibi cihazdaki ne varsa onunla açılır.
  /// "Ustayı öner" değil bilinçli olarak "İşletmeyi öner" denildi çünkü
  /// uygulama sadece esnaf/usta değil restoran, klinik, emlak, kırtasiye
  /// gibi çok geniş bir işletme yelpazesini de kapsıyor.
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

  /// "Yayından Kaldır" — projeyi SİLMEDEN sadece canlı sitesini indirir.
  /// Proje Projelerim'de kalmaya devam eder (düzenlenebilir, istenirse
  /// tekrar yayınlanabilir) — bkz. AppState.markProjectUnpublished:
  /// ownerToken BİLEREK korunur ki yeniden yayınlamada aynı sahiplik
  /// devam etsin. Silme akışından (deleteProject) FARKI budur.
  Future<void> _unpublishProject(SiteProject project) async {
    final confirmed = await showConfirmPopup(
      context,
      title: t(context, 'Yayından Kaldır'),
      message: '"${project.name}" ' +
          t(context, 'yayından kaldırılacak, site adresi artık açılmayacak. Proje silinmez, istediğinde tekrar yayınlayabilirsin.'),
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

  /// Kendi domain bağlama özelliği worker/Cloudflare for SaaS tarafında
  /// henüz canlıya alınmadı (bkz. sohbet — "şu anda aktif değil"). Gerçek
  /// akış (DomainConnectScreen) hazır bekliyor; canlıya alınınca burası
  /// tekrar `Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
  /// DomainConnectScreen(project: project)))` olarak değiştirilecek —
  /// şimdilik kullanıcının kafası karışmasın diye net bir "yakında" popup'ı
  /// gösteriyor.
  void _openDomainConnect(SiteProject project) {
    showAppPopup(
      context,
      message: t(context,
          'Kendi domainini bağlama özelliği şu anda aktif değil. Çok yakında burada kendi alan adını (örn. isletmem.com) bağlayabileceksin.'),
      icon: '🌐',
    );
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
                    // Bu ekran bir sekme olduğu için önce Ana Sayfa'ya
                    // dönme callback'i denenir; o yoksa (ör. ileride bu
                    // ekran gerçekten push edilerek açılırsa) ve gerçekten
                    // pop edilebiliyorsa normal pop yapılır. Hiçbiri
                    // mümkün değilse HİÇBİR ŞEY yapılmaz — boş yığın
                    // bırakıp siyah ekrana düşülmez.
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
                onRefresh: _loadLiveStats,
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
                          onDomain: p.isPublished ? () => _openDomainConnect(p) : null,
                          onShare: p.isPublished ? () => _shareProject(p) : null,
                          onUnpublish: p.isPublished ? () => _unpublishProject(p) : null,
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
              // NOT: Eskiden burada "Sohbetten bir site oluşturduğunda..."
              // yazıyordu — AI/sohbet ile site oluşturma özelliği kaldırıldığı
              // için (bkz. home_screen.dart'taki _buildBuilderProBanner yorumu)
              // bu metin artık var olmayan bir özelliği anlatıyordu, güncel
              // oluşturma yollarına (Form / Sürükle-Bırak) göre düzeltildi.
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

/// "Yayında olan siteler" şeridi — Projelerim ekranının en üstünde,
/// yatay kaydırmalı, sadece isPublished projeleri gösteren kompakt
/// kartlar. Amaç: kullanıcının siteleri kurup unuttuğu bir "kur-unut"
/// aracı yerine, düzenli açıp ziyaretçi sayısına baktığı bir panele
/// dönüşmesi (bkz. HostingService.fetchStatsBatch). Ana proje listesi
/// (aşağıdaki _ProjectCard listesi) TÜM projeleri göstermeye devam
/// eder — bu şerit bilinçli olarak sadece yayındakilerin bir "vitrin"i.
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

  /// Ham sayıyı ("visitCount") esnafın doğrudan hissedeceği somut bir
  /// cümleye çevirir — bkz. rakip analizi (FOMO mesajı): "Bu ay 42 kişi
  /// ..." tarzı duygusal çerçeveleme, ham istatistik yerine. Veri zaten
  /// mevcut (fetchStatsBatch → monthlyVisitCount, worker tarafında
  /// SADECE bir SELECT/SUM — yazma kotasını etkilemez), burada sadece
  /// sunum değişiyor. monthlyVisitCount henüz deploy edilmemiş eski bir
  /// worker'dan 0/null gelirse (ya da bu ay hiç ziyaret yoksa) toplam
  /// sayaca sessizce geri düşer.
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

  /// 05.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği,
  /// son madde): free plan'daki (bkz. [SiteProject.isPremium] — bu şeritteki
  /// AppState.qtCurrentIsPremium DEĞİL, çünkü burada listelenen HER proje
  /// kendi domain bağlantı durumuna göre ayrı ayrı değerlendiriliyor, o
  /// yüzden proje bazlı getter kullanılıyor) yayındaki bir sitenin
  /// ziyaretçi sayısı (FOMO satırı + "bugün" rozeti) TAMAMEN kilitli —
  /// rakam yerine [_LockedVisitorStats] gösteriliyor, dokununca diğer
  /// kilitlerle AYNI [showPremiumLockedPopup]. Site adı/kart kendisi
  /// (dolayısıyla projeye dokununca açılması) ETKİLENMEDİ — sadece rakam
  /// gizleniyor.
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

/// Free plan'da [_LiveSiteChip] içinde ziyaretçi rakamı yerine gösterilen
/// kilitli satır — diğer kilitli placeholder'larla (bkz.
/// widgets/location_picker_field.dart > _LockedLocationField) AYNI 🔒
/// görsel dili, ama kart zaten küçük olduğu için tek satıra sıkıştırılmış
/// kompakt bir varyant. Dokununca AYNI [showPremiumLockedPopup].
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
            ? 'Seeing the visitor count for your published site is only available on the Premium (custom domain) plan.'
            : 'Yayındaki sitenin ziyaretçi sayısını görmek sadece Premium (özel domain) planında.',
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
  final VoidCallback? onDomain;
  final VoidCallback? onShare;
  final VoidCallback? onUnpublish;

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
    this.onDomain,
    this.onShare,
    this.onUnpublish,
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
              // Sadece YAYINDAKİ projelerde görünür — bkz. onDomain/onUnpublish
              // sadece p.isPublished ise dolduruluyor (çağıran taraf).
              // Bilerek KÜÇÜK bir ikon yerine metinli buton: eski halinde
              // domain ikonu (dns/language) tek başına ne işe yaradığı
              // anlaşılmayan bir simgeydi — burada ne olduğu açıkça yazıyor.
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
              // 05.09.2026 eklendi (kanka isteği) — özel domain ve/veya mini
              // paket satın alınmışsa, kartta kalan süre "X gün Y saat
              // kaldı" şeklinde gösterilir. İkisi BİRBİRİNDEN BAĞIMSIZ
              // olduğu için (bir projede aynı anda ikisi de aktif olabilir,
              // bkz. SiteProject.isPremium) her biri KENDİ satırında ayrı
              // gösteriliyor.
              if ((project.isDomainConnected && !project.isDomainExpired && project.domainExpiresAt != null) ||
                  project.isMiniPackageActive) ...[
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Yayında olan bir projede kart içinde gösterilen, metinli/ikonlu küçük
/// aksiyon butonu (bkz. _ProjectCard > "Domain Bağla" / "Yayından Kaldır").
/// Salt ikon butonların aksine ne işe yaradığı her zaman açık — bu widget
/// tam olarak o belirsizliği gidermek için eklendi (2026-09-02).
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

/// 05.09.2026 eklendi (kanka isteği) — özel domain / mini paket satın alan
/// bir projede kart içinde kalan süreyi "X gün Y saat kaldı" şeklinde
/// gösteren küçük satır. `_CardActionChip` gibi tıklanabilir bir buton
/// DEĞİL, sadece bilgilendirme amaçlı — bu yüzden ayrı, daha sade bir
/// widget olarak tutuluyor.
///
/// Süre HESAPLAMASI burada, build() anında `DateTime.now()` ile yapılır —
/// [SiteProject] üzerindeki `domainDaysRemaining`/`miniPackageDaysRemaining`
/// getter'ları saati YUVARLADIĞI için (`Duration.inDays`) burada saat
/// bilgisini de göstermek adına `expiresAt`'ten kalan [Duration] doğrudan
/// kullanılıyor.
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
      // Normalde bu satır zaten sadece süre dolmamışken gösteriliyor
      // (bkz. _ProjectCard > isDomainExpired/isMiniPackageActive kontrolü),
      // ama build ile kontrol arasındaki milisaniyelik farkı da güvenceye
      // almak için burada da bir yedek metin var.
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

/// Proje adı değiştirme dialogu.
///
/// Ayrı bir StatefulWidget olarak tutulur ki TextEditingController ve
/// FocusNode'un yaşam döngüsü dialog'un kendi Element'iyle birebir
/// senkron olsun. Önceki sürümde bu controller dışarıda oluşturulup
/// autofocus:true ile açılıyor, dialog kapanır kapanmaz elle dispose
/// ediliyordu — bu, controller/focus ömrünün dialog'un pop animasyonuyla
/// senkron olmamasına yol açıp "Vazgeç"e basınca framework'ün
/// '_dependents.isEmpty' assertion'ını tetikliyordu. Bu yapıda hem
/// dispose hem de focus isteği State'in kendi yaşam döngüsüne bağlı.
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
    // Autofocus'u ilk frame çizildikten SONRA veriyoruz; dialog açılış
    // animasyonuyla aynı anda focus istemek de bu bug'ı tetikleyen
    // etkenlerden biriydi.
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
