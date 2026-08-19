import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/confirm_popup.dart';
import '../widgets/ai_edit_dialog.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import 'preview_screen.dart';
import 'domain_connect_screen.dart';

/// PROJELERİM ekranı.
///
/// Kullanıcının bugüne kadar sohbetten ürettiği veya cihazdan içe
/// aktardığı TÜM siteleri listeler (AppState.projects). Her satırdan:
/// - dokununca proje ilgili slota yüklenir ve ÖN İZLEME ekranı açılır
///   (kaynağına göre: AI Chat kökenli projeler AI bölüm-düzenlemeli
///   PreviewScreen'de, form/Hızlı Araçlar kökenli projeler ise AI
///   düzenlemesi içermeyen QuickToolsPreviewScreen'de — bkz. _openProject),
/// - kalem ikonuyla adı değiştirilebilir,
/// - çöp ikonuyla kalıcı olarak silinebilir.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  /// Projeyi doğru slota yükler ve doğru önizleme ekranını açar.
  ///
  /// kind == ProjectKind.site → proje AI Chat sohbetinden üretilmiştir;
  /// AppState.openProject (AI Chat slotu) + PreviewScreen (bölüm bazlı ✨
  /// AI düzenlemesi açık) kullanılır.
  ///
  /// kind != ProjectKind.site → proje bir Hızlı Araçlar formundan
  /// (Kuaför, Kafe, Emlak vb.) üretilmiştir; AppState.openQtProject
  /// (Hızlı Araçlar slotu) + QuickToolsPreviewScreen (AI düzenlemesi
  /// KAPALI — bu akışta düzenleme forma dönüp yeniden oluşturmak
  /// üzerinden yapılır) kullanılır. Böylece proje, ilk oluşturulduğunda
  /// gördüğü ekranın AYNISINDA açılır; Projelerim'den tekrar açmak farklı
  /// bir deneyime düşürmez.
  /// "Kendi domainimi bağla" ekranını açar. Sadece yayınlanmış (isPublished)
  /// projeler için gösterilir — Worker tarafında henüz bir siteId kaydı
  /// olmayan bir projeye domain bağlanamaz (bkz. handleDomainConnect > 404).
  void _openDomainConnect(SiteProject project) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DomainConnectScreen(project: project)),
    );
  }

  Future<void> _openProject(SiteProject project) async {
    final appState = context.read<AppState>();
    final isAiChatProject = project.kind == ProjectKind.site;
    if (isAiChatProject) {
      await appState.openProject(project.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PreviewScreen()),
      );
    } else {
      await appState.openQtProject(project.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()),
      );
    }
  }

  Future<void> _renameProject(SiteProject project) async {
    final controller = TextEditingController(text: project.name);
    final newName = await showDialog<String>(
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
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(ctx, 'Proje Adını Değiştir'),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
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
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(t(ctx, 'Vazgeç'),
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
                      onPressed: () => Navigator.of(ctx).pop(controller.text),
                      child: Text(t(ctx, 'Kaydet'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
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
      message: '"${project.name}" kalıcı olarak silinecek. Bu işlem geri alınamaz. '
          'Silmek istediğinizden emin misiniz?',
      icon: '🗑️',
      confirmLabel: 'Evet, Sil',
      cancelLabel: 'Vazgeç',
    );
    if (!confirmed) return;
    if (!mounted) return;
    await context.read<AppState>().deleteProject(project.id);
    if (mounted) {
      showAppPopup(context, message: t(context, 'Proje silindi.'), icon: '🗑️');
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
                    onPressed: () => Navigator.of(context).pop(),
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
            Expanded(
              child: projects.isEmpty
                  ? _buildEmptyState(subtleColor)
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = projects[index];
                        final isOpen = p.id == appState.currentProjectId;
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
              t(context, 'Sohbetten bir site oluşturduğunda burada listelenecek.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12.5),
            ),
          ],
        ),
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
          child: Row(
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
              if (onDomain != null)
                IconButton(
                  icon: Icon(
                    project.isDomainConnected ? Icons.language : Icons.dns_outlined,
                    size: 19,
                    color: project.isDomainConnected ? AppColors.accentGreenLink : subtleColor,
                  ),
                  onPressed: onDomain,
                  tooltip: t(context, 'Kendi Domainimi Bağla'),
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
        ),
      ),
    );
  }
}
