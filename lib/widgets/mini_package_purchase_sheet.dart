import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// "1 Aylık Mini Paket" satın alma (paywall) sheet'i.
///
/// MODEL: site bazlı, 1 AYLIK, tek seferlik satın alma (bkz.
/// billing_constants.dart > kProductMiniPackage). domain_purchase_sheet.dart
/// ile AYNI desen — SADECE bu sheet ödemeyi alıp AppState.activateMiniPackage
/// çağırır, o metod hem rozeti kaldırır hem de 1 aylık premium süresini
/// başlatır (bkz. o metodun dokümantasyonu). Domain paketinden FARKI:
/// süre 1 yıl değil 1 aydır VE indirme hakkını hiç kapsamaz.
Future<void> showMiniPackagePurchaseSheet(
  BuildContext context, {
  required SiteProject project,
}) async {
  final ok = await requireLogin(context, feature: t(context, '1 Aylık Mini Paket'));
  if (!ok || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MiniPackagePurchaseSheet(project: project),
  );
}

class _MiniPackagePurchaseSheet extends StatefulWidget {
  final SiteProject project;
  const _MiniPackagePurchaseSheet({required this.project});

  @override
  State<_MiniPackagePurchaseSheet> createState() => _MiniPackagePurchaseSheetState();
}

class _MiniPackagePurchaseSheetState extends State<_MiniPackagePurchaseSheet> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductMiniPackage);
      if (!purchased) {
        // Kullanıcı mağaza ekranında vazgeçti — sessizce geri dön, hata
        // gösterme (bu bir hata değil, bilinçli bir iptal).
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().activateMiniPackage(widget.project.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
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
    final product = BillingService.instance.products[kProductMiniPackage];
    return product?.price ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final name = widget.project.name;
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
            Text(_done ? '✅' : '🎟️', style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 10),
            Text(
              _done
                  ? t(context, 'Mini paket aktif!')
                  : t(context, '1 Aylık Mini Paket'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _done
                  ? (en
                      ? '"$name" is badge-free and premium-unlocked for 1 month. This is a one-time purchase, NOT an auto-renewing subscription — it will NOT renew or charge you again by itself. If you don\'t come back and buy it again before it expires, the badge and locks come back automatically — this does NOT include download rights.'
                      : '"$name" 1 ay boyunca rozetsiz ve premium kilitleri açık. Bu tek seferlik bir satın almadır, OTOMATİK YENİLENEN bir abonelik DEĞİLDİR — kendiliğinden yenilenmez, tekrar ücret kesmez. Süresi dolmadan tekrar satın almazsan rozet ve kilitler otomatik geri gelir — bu paket indirme hakkını KAPSAMAZ.')
                  : (en
                      ? '"$name" gets the "Made with Sitora" badge removed AND other premium features unlocked (lead inbox, full gallery, map, lead form, Google review button, visitor stats) for 1 MONTH — one-time, applies ONLY to this site. This is a one-time purchase, NOT an auto-renewing subscription — it will NOT renew or charge you again by itself; you must come back and buy it again to extend. Just like the custom domain package, EXCEPT download rights are NOT included — downloading still needs a separate purchase. If you don\'t renew before the month ends, the badge and locks come back automatically.'
                      : '"$name" bu satın almayla 1 AY boyunca "Sitora ile üretildi" rozeti kalkar VE diğer premium özellikler (Talep Kutusu, tam galeri, harita, talep formu, Google yorum butonu, ziyaretçi sayısı) açılır — tek seferlik, SADECE bu site için geçerlidir. Bu tek seferlik bir satın almadır, OTOMATİK YENİLENEN bir abonelik DEĞİLDİR — kendiliğinden yenilenmez, tekrar ücret kesmez; süresi dolmadan uzatmak istersen tekrar senin satın alman gerekir. Özel domain paketiyle AYNI şekilde çalışır, TEK FARKI indirme hakkının DAHİL OLMAMASI — indirmek için ayrıca satın alma gerekir. Süresi dolmadan yenilemezsen rozet ve kilitler otomatik geri gelir.'),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            // 05.09.2026 eklendi (kanka isteği) — domain_purchase_sheet.dart
            // ile AYNI bilgi kutusu: kilidin açılması otomatik ama
            // özellikleri kullanmak için "Düzenle" akışından geçmek
            // gerektiği burada da açıkça yazılıyor.
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFAB47BC).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFAB47BC).withOpacity(0.35), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      en
                          ? 'Unlocked features activate right away, but to actually see/use them on "$name" you need to open it from My Projects and tap the "Edit" button to fill in or update the related fields (lead inbox, gallery, map, Google review link, etc.), then tap "Finish Editing".'
                          : '"$name" için kilidi açılan özellikler hemen aktif olur, ancak bunları görmek/kullanmak için siteyi Projelerim ekranından açıp "Düzenle" butonuna basman ve ilgili alanları (Talep Kutusu, galeri, harita, Google yorum linki vb.) doldurup/güncelleyip "Düzenlemeyi Bitir"e basman gerekir.',
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
            if (!_done)
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _busy
                      ? (en ? 'Processing...' : 'İşleniyor...')
                      : (en
                          ? 'Buy — 1 Month, For This Site (${_priceLabel()})'
                          : 'Satın Al — 1 Aylık, Bu Site İçin (${_priceLabel()})'),
                  emoji: _busy ? null : '💳',
                  borderColor: const Color(0xFFAB47BC),
                  textColor: Colors.white,
                  filled: true,
                  fillColor: const Color(0xFFAB47BC),
                  height: 46,
                  fontSize: 14,
                  onTap: _busy ? null : _purchase,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: t(context, 'Kapat'),
                  borderColor: Colors.white24,
                  textColor: Colors.white,
                  height: 46,
                  fontSize: 14,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
