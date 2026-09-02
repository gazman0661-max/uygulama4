import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../services/auth_service.dart';
import '../services/lead_service.dart';
import '../theme/app_theme.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// Eskiden [showLeadInboxSheet] ile alttan açılan bir sheet'ti — artık
/// TAM EKRAN olarak açılıyor (bkz. main_shell.dart alt gezinme çubuğu
/// "Talepler" sekmesi).
Future<void> openLeadInboxScreen(BuildContext context) async {
  final ok = await requireLogin(context, feature: t(context, 'Gelen Talepler'));
  if (!ok || !context.mounted) return;
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
    return Scaffold(
      backgroundColor: const Color(0xFF141821),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141821),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          t(context, 'Gelen Talepler'),
          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
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
                style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11.5),
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
                                  style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13),
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
                                style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: leads.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _LeadTile(lead: leads[i]),
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

class _LeadTile extends StatefulWidget {
  final Lead lead;
  const _LeadTile({required this.lead});

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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread ? AppColors.accentBlue.withOpacity(0.5) : Colors.white.withOpacity(0.08),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _timeAgo(lead.createdAt, en),
                style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11),
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
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12.5, height: 1.35),
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
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
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
        ],
      ),
    );
  }
}
