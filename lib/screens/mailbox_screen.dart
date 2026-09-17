import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/mailbox_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../widgets/confirm_popup.dart';
import '../localization/app_strings.dart';
import '../widgets/app_popup.dart';

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
        case 'publishCredit':
          for (var i = 0; i < mail.giftAmount; i++) {
            await appState.addGiftPublishCredit();
          }
          break;
        case 'watermarkRemoval':
          await appState.addGiftWatermarkRemovalCredit(mail.giftAmount);
          break;
        case 'downloadWatermarked':
          await appState.addGiftDownloadWatermarkedCredit(mail.giftAmount);
          break;
        case 'downloadClean':
          await appState.addGiftDownloadCleanCredit(mail.giftAmount);
          break;
        case 'domainConnect':
          await appState.addGiftDomainConnectCredit(mail.giftAmount);
          break;
        case 'miniPackage':
          await appState.addGiftMiniPackageCredit(mail.giftAmount);
          break;
      }
      if (!mounted) return;
      final en = isEnglish(context);
      showAppPopup(context, message: en ? 'Gift claimed 🎁' : 'Hediye teslim alındı 🎁');
    } on MailAlreadyClaimedException {
      // Başka bir cihazdan zaten alınmış — sessizce yut.
    } catch (_) {
      if (!mounted) return;
      showAppPopup(context, message: isEnglish(context)
              ? 'Something went wrong, please try again.'
              : 'Bir şeyler ters gitti, lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  /// 03.09.2026 eklendi — mesajı silmeden önce onay ister; hediyesi olup
  /// henüz teslim alınmamışsa kullanıcıyı ayrıca uyarır (silince hediyeye
  /// bir daha ulaşamaz). Onaylanırsa [MailboxService.dismiss] çağrılır.
  Future<bool> _confirmDismiss(MailItem mail) async {
    final en = isEnglish(context);
    final hasUnclaimedGift = mail.hasGift && !mail.claimed;
    return showConfirmPopup(
      context,
      icon: '🗑️',
      title: en ? 'Delete message?' : 'Mesajı sil?',
      message: hasUnclaimedGift
          ? (en
              ? 'This message has an unclaimed gift. If you delete it, you will lose the gift.'
              : 'Bu mesajın teslim alınmamış bir hediyesi var. Silersen hediyeyi kaybedersin.')
          : (en
              ? 'This message will be removed from your inbox.'
              : 'Bu mesaj gelen kutundan kaldırılacak.'),
      confirmLabel: en ? 'Yes, delete' : 'Evet, Sil',
      cancelLabel: en ? 'Cancel' : 'Vazgeç',
    );
  }

  Future<void> _dismiss(MailItem mail) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await MailboxService.instance.dismiss(uid, mail.id);
    } catch (_) {
      if (!mounted) return;
      showAppPopup(context, message: isEnglish(context)
              ? 'Could not delete the message, please try again.'
              : 'Mesaj silinemedi, lütfen tekrar dene.', icon: '⚠️');
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
                    if (snap.hasError) {
                      // DÜZELTME (02.09.2026): eskiden buradaki hata hiç
                      // kontrol edilmiyordu, `snap.data ?? const []` ile
                      // hata da boş liste gibi davranıp "Henüz bir mesajın
                      // yok" gösteriyordu — gerçekte gönderilmiş bir mesaj
                      // varken bile. Artık gerçek hata görünür.
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            en
                                ? 'Could not load your inbox. Please check your connection and try again.'
                                : 'Gelen kutusu yüklenemedi. Bağlantını kontrol edip tekrar dene.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13),
                          ),
                        ),
                      );
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
                      itemBuilder: (context, i) {
                        final mail = items[i];
                        return Dismissible(
                          key: ValueKey(mail.id),
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
                          confirmDismiss: (_) => _confirmDismiss(mail),
                          onDismissed: (_) => _dismiss(mail),
                          child: _MailTile(
                            mail: mail,
                            busy: _claimingId == mail.id,
                            onClaim: () => _claim(mail),
                            onDelete: () async {
                              if (await _confirmDismiss(mail)) await _dismiss(mail);
                            },
                          ),
                        );
                      },
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
  final VoidCallback onDelete;

  const _MailTile({
    required this.mail,
    required this.busy,
    required this.onClaim,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final title = en ? mail.titleEn : mail.title;
    final body = en ? mail.bodyEn : mail.body;
    final giftLabel = mail.giftType == 'publishCredit'
            ? (en ? '+${mail.giftAmount} publish credit' : '+${mail.giftAmount} yayın hakkı')
            : mail.giftType == 'watermarkRemoval'
                ? (en ? '+${mail.giftAmount} watermark removal' : '+${mail.giftAmount} watermark kaldırma hakkı')
                : mail.giftType == 'downloadWatermarked'
                    ? (en ? '+${mail.giftAmount} watermarked download' : '+${mail.giftAmount} watermarklı indirme hakkı')
                    : mail.giftType == 'downloadClean'
                        ? (en ? '+${mail.giftAmount} clean download' : '+${mail.giftAmount} watermarksız indirme hakkı')
                        : mail.giftType == 'domainConnect'
                            ? (en ? '+${mail.giftAmount} custom domain credit' : '+${mail.giftAmount} özel domain hakkı')
                            : mail.giftType == 'miniPackage'
                                ? (en ? '+${mail.giftAmount} mini package credit' : '+${mail.giftAmount} mini paket hakkı')
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
              const SizedBox(width: 4),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, color: Colors.white38, size: 19),
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
