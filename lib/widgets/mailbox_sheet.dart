import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/mailbox_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// Ana ekrandaki zarf ikonuna dokununca açılan gelen kutusu. Giriş şartı
/// [requireLogin] ile aranıyor çünkü mailbox tamamen users/{uid} altındaki
/// kimliğe (hem hedefleme hem "zaten teslim alındı" kilidi için) bağlı —
/// bkz. mailbox_service.dart dosya başı açıklaması.
Future<void> showMailboxSheet(BuildContext context) async {
  final ok = await requireLogin(context, feature: t(context, 'Gelen Kutusu'));
  if (!ok || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _MailboxSheet(),
  );
}

class _MailboxSheet extends StatefulWidget {
  const _MailboxSheet();

  @override
  State<_MailboxSheet> createState() => _MailboxSheetState();
}

class _MailboxSheetState extends State<_MailboxSheet> {
  // Aynı anda sadece TEK bir mesaj teslim alınabilir — çift dokunmayla iki
  // ayrı transaction'ın yarışmasını (ve iki kez "işleniyor" göstermesini)
  // önlemek için.
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
      // Başka bir cihazdan zaten alınmış — sessizce yut, liste bir sonraki
      // snapshot'ta zaten "alındı" gösterecek.
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
    return SafeArea(
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
            const Text('✉️', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              t(context, 'Gelen Kutusu'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<MailItem>>(
                      stream: MailboxService.instance.watchInbox(uid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final items = snap.data ?? const [];
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              en ? 'You have no messages yet.' : 'Henüz bir mesajın yok.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(context, 'Kapat'), style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
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
