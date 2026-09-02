import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/mailbox_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// Eskiden [showMailboxSheet] ile alttan açılan bir sheet'ti — artık
/// TAM EKRAN olarak açılıyor (bkz. main_shell.dart alt gezinme çubuğu
/// "Kutu" sekmesi). Giriş şartı aynı [requireLogin] ile, sheet mi ekran
/// mı olduğu bu kontrolü değiştirmiyor.
Future<void> openMailboxScreen(BuildContext context) async {
  final ok = await requireLogin(context, feature: t(context, 'Gelen Kutusu'));
  if (!ok || !context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const MailboxScreen()),
  );
}

class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  // Aynı anda sadece TEK bir mesaj teslim alınabilir — çift dokunmayla iki
  // ayrı transaction'ın yarışmasını önlemek için.
  String? _claimingId;

  Future<void> _claim(MailItem mail) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _claimingId = mail.id);
    try {
      await MailboxService.instance.claim(uid, mail.id);
      if (!mounted) return;
      final appState = context.read<AppState>();
      switch (mail.giftType) {
        case 'points':
          await appState.addPurchasedPoints(mail.giftAmount);
          break;
        case 'publishCredit':
          for (var i = 0; i < mail.giftAmount; i++) {
            await appState.addPurchasedPublishCredit();
          }
          break;
      }
      if (!mounted) return;
      final en = isEnglish(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(en ? 'Gift claimed 🎁' : 'Hediye teslim alındı 🎁')),
      );
    } on MailAlreadyClaimedException {
      // Başka bir cihazdan zaten alınmış — sessizce yut.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish(context)
              ? 'Something went wrong, please try again.'
              : 'Bir şeyler ters gitti, lütfen tekrar dene.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

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
          t(context, 'Gelen Kutusu'),
          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: uid == null
              ? const SizedBox.shrink()
              : StreamBuilder<List<MailItem>>(
                  stream: MailboxService.instance.watchInbox(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          en ? 'You have no messages yet.' : 'Henüz bir mesajın yok.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _MailTile(
                        mail: items[i],
                        busy: _claimingId == items[i].id,
                        onClaim: () => _claim(items[i]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _MailTile extends StatelessWidget {
  final MailItem mail;
  final bool busy;
  final VoidCallback onClaim;

  const _MailTile({required this.mail, required this.busy, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final title = en ? mail.titleEn : mail.title;
    final body = en ? mail.bodyEn : mail.body;
    final giftLabel = mail.giftType == 'points'
        ? (en ? '+${mail.giftAmount} points' : '+${mail.giftAmount} puan')
        : mail.giftType == 'publishCredit'
            ? (en ? '+${mail.giftAmount} publish credit' : '+${mail.giftAmount} yayın hakkı')
            : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (giftLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    giftLabel,
                    style: const TextStyle(color: AppColors.accentBlue, fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12.5, height: 1.35)),
          ],
          if (mail.hasGift) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: mail.claimed
                    ? (en ? 'Claimed ✅' : 'Teslim alındı ✅')
                    : busy
                        ? t(context, 'İşleniyor...')
                        : (en ? 'Claim' : 'Teslim Al'),
                emoji: mail.claimed || busy ? null : '🎁',
                borderColor: AppColors.accentBlue,
                textColor: Colors.white,
                filled: !mail.claimed,
                fillColor: AppColors.accentBlue,
                height: 40,
                fontSize: 13,
                onTap: mail.claimed || busy ? null : onClaim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
