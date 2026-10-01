import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

Future<bool> showDomainPurchaseSheet(
  BuildContext context, {
  required SiteProject project,
  bool isRenewal = false,
}) async {
  final ok = await requireLogin(
    context,
    feature: t(context, isRenewal ? 'Bağlantıyı 1 Yıl Uzat' : 'Kendi Domainimi Bağla'),
  );
  if (!ok || !context.mounted) return false;
  AnalyticsService.logPaywallShown(trigger: 'domain');

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DomainPurchaseSheet(project: project, isRenewal: isRenewal),
  );
  return result ?? false;
}

class _DomainPurchaseSheet extends StatefulWidget {
  final SiteProject project;
  final bool isRenewal;
  const _DomainPurchaseSheet({required this.project, this.isRenewal = false});

  @override
  State<_DomainPurchaseSheet> createState() => _DomainPurchaseSheetState();
}

class _DomainPurchaseSheetState extends State<_DomainPurchaseSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _redeemGift() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<AppState>().redeemGiftDomainConnect();
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _purchase() async {
    final appState = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductConnectDomain);
      if (!purchased) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      try {
        await appState.addPurchasedPublishCredit();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  String _priceLabel() {
    final product = BillingService.instance.products[kProductConnectDomain];
    return product?.price ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final name = widget.project.name;
    final isRenewal = widget.isRenewal;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🌐', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 10),
            Text(
              t(context, isRenewal ? 'Bağlantıyı 1 Yıl Uzat' : 'Kendi domainimi bağla'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRenewal
                  ? (en
                      ? '"$name" keeps its custom domain, badge-free status, and all unlocked premium features for 1 MORE YEAR with this purchase — one-time, applies ONLY to this site. This is a one-time purchase, NOT an auto-renewing subscription — it will NOT renew or charge you again by itself. If it lapses again without you manually renewing, the connection is fully released after 7 days and reconnecting will require this purchase again. This purchase also adds +1 extra site publish right to your account.'
                      : '"$name" bu satın almayla özel domainini, rozetsiz durumunu ve açık olan tüm premium özelliklerini 1 YIL DAHA korur — tek seferlik, SADECE bu site için geçerlidir. Bu tek seferlik bir satın almadır, OTOMATİK YENİLENEN bir abonelik DEĞİLDİR — kendiliğinden yenilenmez ve tekrar ücret kesmez. Sen elle yenilemezsen ve süresi tekrar dolarsa bağlantı 7 gün sonra tamamen sökülür ve yeniden bağlamak için bu satın almayı tekrar yapman gerekir. Bu satın alma ayrıca hesabına +1 ek site yayın hakkı ekler.')
                  : (en
                      ? '"$name" gets its own domain for 1 year with this purchase — one-time, applies ONLY to this site. This is a one-time purchase, NOT an auto-renewing subscription — it will NOT renew or charge you again by itself; you must come back and buy it again to extend. The "Made with MySitora" badge is removed for as long as the domain stays connected — if the domain lapses and isn\'t renewed, the badge comes back automatically (this is not a permanent removal). Other premium features (lead inbox, map, lead form, Google review button + Google Business Profile Setup Wizard, visitor stats) unlock for as long as the domain stays connected — extending before it expires requires this SAME purchase again, and if it lapses for more than 7 days the connection is fully released and this purchase must be made again to reconnect. This purchase also adds +1 extra site publish right to your account (usable for any new site).'
                      : '"$name" bu satın almayla 1 yıllığına kendi domainine kavuşur — tek seferlik, SADECE bu site için geçerlidir. Bu tek seferlik bir satın almadır, OTOMATİK YENİLENEN bir abonelik DEĞİLDİR — kendiliğinden yenilenmez, tekrar ücret kesmez; süresi dolmadan uzatmak istersen tekrar senin satın alman gerekir. "MySitora ile üretildi" rozeti domain bağlı kaldığı sürece kaldırılır — domain süresi dolup yenilenmezse rozet OTOMATİK GERİ GELİR (kalıcı bir kaldırma değildir). Diğer premium özellikler (Talep Kutusu, harita, talep formu, Google yorum butonu + Google İşletme Profili Kurulum Sihirbazı, ziyaretçi sayısı) domain bağlı kaldığı sürece açık kalır — süresi dolmadan uzatmak için AYNI satın almayı tekrar yapman gerekir, 7 günden fazla yenilenmezse bağlantı tamamen sökülür ve tekrar bağlamak için bu satın almayı yeniden yapman gerekir. Bu satın alma ayrıca hesabına +1 ek site yayın hakkı ekler (herhangi bir yeni site için kullanabilirsin).'),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF29B6F6).withOpacity(0.35), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      en
                          ? 'Unlocked features activate right away, but to actually see/use them on "$name" you need to open it from My Projects and tap the "Edit" button to fill in or update the related fields (lead inbox, gallery, map, Google review link / Google Business Profile Setup Wizard, etc.), then tap "Finish Editing".'
                          : '"$name" için kilidi açılan özellikler hemen aktif olur, ancak bunları görmek/kullanmak için siteyi Projelerim ekranından açıp "Düzenle" butonuna basman ve ilgili alanları (Talep Kutusu, galeri, harita, Google yorum linki / Google İşletme Profili Kurulum Sihirbazı vb.) doldurup/güncelleyip "Düzenlemeyi Bitir"e basman gerekir.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            if (context.watch<AppState>().giftDomainConnectCredits > 0) ...[
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _busy
                      ? (en ? 'Processing...' : 'İşleniyor...')
                      : (en
                          ? 'Use gift credit (${context.watch<AppState>().giftDomainConnectCredits} left)'
                          : 'Hediye hakkını kullan (${context.watch<AppState>().giftDomainConnectCredits} adet)'),
                  emoji: _busy ? null : '🎁',
                  borderColor: const Color(0xFF66BB6A),
                  textColor: Colors.white,
                  filled: true,
                  fillColor: const Color(0xFF66BB6A),
                  height: 46,
                  fontSize: 14,
                  onTap: _busy ? null : _redeemGift,
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: _busy
                    ? (en ? 'Processing...' : 'İşleniyor...')
                    : (en
                        ? (isRenewal
                            ? 'Renew — 1 More Year, For This Site (${_priceLabel()})'
                            : 'Buy — 1 Year, For This Site (${_priceLabel()})')
                        : (isRenewal
                            ? 'Uzat — 1 Yıl Daha, Bu Site İçin (${_priceLabel()})'
                            : 'Satın Al — 1 Yıllık, Bu Site İçin (${_priceLabel()})')),
                emoji: _busy ? null : '💳',
                borderColor: const Color(0xFF29B6F6),
                textColor: Colors.white,
                filled: true,
                fillColor: const Color(0xFF29B6F6),
                height: 46,
                fontSize: 14,
                onTap: _busy ? null : _purchase,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
