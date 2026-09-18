import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../services/auth_service.dart';
import '../services/lead_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/login_gate.dart';
import '../widgets/confirm_popup.dart';
import '../localization/app_strings.dart';
import '../widgets/app_popup.dart';
import '../widgets/premium_locked_popup.dart';

/// Eskiden [showLeadInboxSheet] ile alttan açılan bir sheet'ti — artık
/// TAM EKRAN olarak açılıyor (bkz. main_shell.dart alt gezinme çubuğu
/// "Talepler" sekmesi).
///
/// 04.09.2026 eklendi — Talep Kutusu artık PREMİUM (özel domain planı)
/// özelliği (bkz. AppState.hasPremiumProject). Tek giriş noktası burası
/// (main_shell.dart "Talepler" sekmesi de bu fonksiyonu çağırıyor), bu
/// yüzden kilit kontrolü SADECE burada yapılıyor.
Future<void> openLeadInboxScreen(BuildContext context) async {
  final ok = await requireLogin(context, feature: t(context, 'Gelen Talepler'));
  if (!ok || !context.mounted) return;
  final hasPremium = context.read<AppState>().hasPremiumProject;
  if (!hasPremium) {
    final en = isEnglish(context);
    await showPremiumLockedPopup(
      context,
      message: en
          ? 'Requests from your site\'s contact form are only available on the Premium (custom domain) plan.'
          : 'Sitenin talep formundan gelen talepleri görebilmek sadece Premium (özel domain) planında.',
    );
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LeadInboxScreen()),
  );
}

class LeadInboxScreen extends StatelessWidget {
  const LeadInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    final en = isEnglish(context);
    final isDark = context.watch<ThemeController>().isDark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(0.55);
    final faintColor = (isDark ? Colors.white : Colors.black).withOpacity(0.38);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: titleColor,
        elevation: 0,
        title: Text(
          t(context, 'Gelen Talepler'),
          style: TextStyle(color: titleColor, fontFamily: 'monospace', fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                en
                    ? 'Requests sent from your published sites\' contact forms.'
                    : 'Yayınladığın sitelerin iletişim formundan gelen talepler.',
                textAlign: TextAlign.center,
                style: TextStyle(color: faintColor, fontFamily: 'monospace', fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: uid == null
                    ? const SizedBox.shrink()
                    : StreamBuilder<List<Lead>>(
                        stream: LeadService.instance.watchLeads(uid),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            // DÜZELTME (02.09.2026): eskiden hata hiç
                            // kontrol edilmiyordu, `snap.data ?? const []`
                            // hatayı da boş liste gibi gösterip "Henüz talep
                            // yok" yazıyordu — talep gerçekten gelmiş olsa
                            // bile bir okuma hatası varsa fark edilmiyordu.
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  en
                                      ? 'Could not load your requests. Please check your connection and try again.'
                                      : 'Talepler yüklenemedi. Bağlantını kontrol edip tekrar dene.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 13),
                                ),
                              ),
                            );
                          }
                          final leads = snap.data ?? const [];
                          if (leads.isEmpty) {
                            return Center(
                              child: Text(
                                en
                                    ? 'No requests yet. They\'ll show up here as soon as a visitor fills out a contact form on one of your sites.'
                                    : 'Henüz talep yok. Sitelerinden biri üzerinden bir ziyaretçi iletişim formunu doldurduğunda burada görünecek.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 13),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: leads.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final lead = leads[i];
                              return Dismissible(
                                key: ValueKey(lead.id),
                                direction: DismissDirection.endToStart,
                                background: const SizedBox.shrink(),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF5350).withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.delete_outline, color: Colors.white),
                                ),
                                confirmDismiss: (_) => _confirmDeleteLead(context),
                                onDismissed: (_) => _deleteLead(context, lead.id),
                                child: _LeadTile(
                                  lead: lead,
                                  isDark: isDark,
                                  onDelete: () async {
                                    if (await _confirmDeleteLead(context)) {
                                      await _deleteLead(context, lead.id);
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 03.09.2026 eklendi — kanka "talep kutusuna da silme seçeneği ekle" dedi.
/// [LeadService.delete] koddan zaten VARDI (`leads/{leadId}` için Firestore
/// kuralı da `allow delete: if ownerId == kendi uid'i` ile açık, bkz.
/// FIREBASE_SETUP.md) ama hiçbir ekran çağırmıyordu — burada UI'a bağlanıyor.
/// Mailbox'tan farkı: burada GERÇEK silme yapılıyor (mailbox'taki gibi
/// "gizle" değil), çünkü her `leads/{leadId}` zaten TEK bir kullanıcıya
/// (ownerId) ait, başka kimseyi etkilemiyor.
Future<bool> _confirmDeleteLead(BuildContext context) {
  final en = isEnglish(context);
  return showConfirmPopup(
    context,
    icon: '🗑️',
    title: en ? 'Delete request?' : 'Talebi sil?',
    message: en
        ? 'This request will be permanently deleted.'
        : 'Bu talep kalıcı olarak silinecek.',
    confirmLabel: en ? 'Yes, delete' : 'Evet, Sil',
    cancelLabel: en ? 'Cancel' : 'Vazgeç',
  );
}

Future<void> _deleteLead(BuildContext context, String leadId) async {
  try {
    await LeadService.instance.delete(leadId);
  } catch (_) {
    if (!context.mounted) return;
    showAppPopup(context, message: isEnglish(context)
            ? 'Could not delete the request, please try again.'
            : 'Talep silinemedi, lütfen tekrar dene.', icon: '⚠️');
  }
}

class _LeadTile extends StatefulWidget {
  final Lead lead;
  final bool isDark;
  final VoidCallback onDelete;
  const _LeadTile({required this.lead, required this.isDark, required this.onDelete});

  @override
  State<_LeadTile> createState() => _LeadTileState();
}

class _LeadTileState extends State<_LeadTile> {
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    // Ekranda göründüğü an "okundu" işaretle — mailbox'taki gibi ayrı bir
    // dokunma gerektirmiyor, zaten kullanıcı listeyi açıp görmüş oluyor.
    if (!widget.lead.read) {
      _markedRead = true;
      LeadService.instance.markRead(widget.lead.id);
    }
  }

  String _timeAgo(DateTime? dt, bool en) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return en ? 'just now' : 'az önce';
    if (diff.inMinutes < 60) return en ? '${diff.inMinutes}m ago' : '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return en ? '${diff.inHours}h ago' : '${diff.inHours} sa önce';
    return en ? '${diff.inDays}d ago' : '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final lead = widget.lead;
    final isUnread = !lead.read && !_markedRead;
    final isDark = widget.isDark;
    final cardBg = isDark ? AppColors.darkBubbleBg : AppColors.lightBubbleBg;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(0.08);
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(0.55);
    final faintColor = (isDark ? Colors.white : Colors.black).withOpacity(0.38);
    final buttonFg = isDark ? Colors.white : Colors.black87;
    final buttonBorder = (isDark ? Colors.white : Colors.black).withOpacity(0.2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread ? AppColors.accentBlue.withOpacity(0.5) : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isUnread)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle),
                ),
              Expanded(
                child: Text(
                  lead.name.isEmpty ? (en ? 'Unknown' : 'İsimsiz') : lead.name,
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _timeAgo(lead.createdAt, en),
                style: TextStyle(color: faintColor, fontFamily: 'monospace', fontSize: 11),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: widget.onDelete,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, color: faintColor, size: 19),
                ),
              ),
            ],
          ),
          if (lead.siteName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              lead.siteName,
              style: const TextStyle(color: AppColors.accentBlue, fontFamily: 'monospace', fontSize: 11.5),
            ),
          ],
          if (lead.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              lead.message,
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12.5, height: 1.35),
            ),
          ],
          if (lead.phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:${lead.phone}')),
                    icon: const Icon(Icons.call, size: 16),
                    label: Text(en ? 'Call' : 'Ara', style: const TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: buttonFg,
                      side: BorderSide(color: buttonBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://wa.me/${lead.phone.replaceAll(RegExp(r'[^0-9]'), '')}'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // 05.09.2026 eklendi (kanka isteği) — talep formuna e-posta alanı
          // eklendi, telefon artık opsiyonel; ziyaretçi sadece e-posta
          // bırakmışsa işletme sahibinin buradan doğrudan mail atabilmesi
          // için ayrı bir buton.
          if (lead.email.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('mailto:${lead.email}')),
                icon: const Icon(Icons.email_outlined, size: 16),
                label: Text(
                  lead.email,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: buttonFg,
                  side: BorderSide(color: buttonBorder),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
