import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// "Kendi domainimi bağla" / "Bağlantıyı 1 Yıl Uzat" satın alma (paywall)
/// sheet'i — İKİSİ DE AYNI ürünü (kProductConnectDomain) kullanır, sadece
/// metin/başlık farklıdır (bkz. [isRenewal]).
///
/// MODEL: site bazlı, 1 yıllık, tek seferlik satın alma (bkz.
/// billing_constants.dart > kProductConnectDomain). İLK BAĞLAMA akışında
/// domain_connect_screen.dart > _connect, domain hiç bağlı değilken
/// (!_isConnectedNow) "Bağla"ya basıldığında açılır. 05.09.2026 GÜNCELLENDİ
/// (kanka kararı) — artık YENİLEME akışında da (domain_connect_screen.dart
/// > _renew, "Bağlantıyı 1 Yıl Uzat"a basıldığında) `isRenewal: true` ile
/// açılıyor: publish_paywall_sheet.dart ile AYNI desen: bu sheet SADECE
/// ödemeyi alır, asıl işi (worker'a DomainService.connect/renew çağrısı)
/// YAPMAZ. Çağıran taraf bu sheet `true` döndürdüğünde ilgili akışa devam
/// etmelidir.
///
/// Dönüş değeri: satın alma başarıyla tamamlandıysa `true`, kullanıcı
/// vazgeçtiyse/hata olduysa `false`.
Future<bool> showDomainPurchaseSheet(
  BuildContext context, {
  required SiteProject project,
  bool isRenewal = false,
}) async {
  // SAVUNMA KATMANI: domain_connect_screen.dart bu ekrana zaten girişi
  // gerektiren bir akıştan (Projelerim > proje > 🌐) geliyor olabilir ama
  // "domain bağlama girişe bağlıdır" kuralının ileride başka bir çağıran
  // tarafından atlanmasını önlemek için kontrol burada da tekrarlanır.
  // Giriş zaten yapılmışsa requireLogin hiçbir şey göstermeden anında
  // true döner.
  final ok = await requireLogin(
    context,
    feature: t(context, isRenewal ? 'Bağlantıyı 1 Yıl Uzat' : 'Kendi Domainimi Bağla'),
  );
  if (!ok || !context.mounted) return false;

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

  /// 05.09.2026 eklendi (kanka isteği) — kullanıcının Kutu'dan (hediye)
  /// biriktirdiği "özel domain bağlama hakkı" bakiyesi varsa ödeme yerine
  /// bunu harcar. remove_watermark_sheet.dart'taki _redeemGift ile AYNI
  /// desen: SADECE ödemeyi atlar, asıl `true` dönüşü _purchase ile
  /// BİREBİR aynı — çağıran taraf (domain_connect_screen.dart) gerçek
  /// satın almadan sonra yaptığı bağlanma/yenileme isteğini burada da
  /// aynen atar, redeemGiftDomainConnect bunu bilmez/karışmaz.
  Future<void> _redeemGift() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<AppState>().redeemGiftDomainConnect();
    if (!mounted) return;
    if (!ok) {
      // Aradaki süre içinde bakiye tükenmiş olabilir (ör. başka bir cihaz) —
      // sessizce normal ödeme akışına düş, hata gösterme.
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductConnectDomain);
      if (!purchased) {
        // Kullanıcı mağaza ekranında vazgeçti — sessizce geri dön, hata
        // gösterme (bu bir hata değil, bilinçli bir iptal).
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      // NOT: burada AppState'e yazılacak bir "satın alındı" bayrağı YOK —
      // bkz. billing_constants.dart > kProductConnectDomain dokümantasyonu.
      // Asıl hakkı çağıran taraf (İLK bağlamada domain_connect_screen.dart
      // > _connect, YENİLEMEDE _renew) bu sheet'ten `true` aldıktan HEMEN
      // SONRA sırasıyla markDomainConnectPurchased/markDomainRenewPurchased
      // + DomainService.connect/renew'i çağırarak kullanır.
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

  /// Diğer satın alma sheet'leriyle (remove_watermark_sheet.dart,
  /// publish_paywall_sheet.dart, buy_points_sheet.dart) AYNI desen.
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
                      ? '"$name" keeps its custom domain, badge-free status, and all unlocked premium features for 1 MORE YEAR with this purchase — one-time, applies ONLY to this site. This is a one-time purchase, NOT an auto-renewing subscription — it will NOT renew or charge you again by itself. If it lapses again without you manually renewing, the connection is fully released after 7 days and reconnecting will require this purchase again.'
                      : '"$name" bu satın almayla özel domainini, rozetsiz durumunu ve açık olan tüm premium özelliklerini 1 YIL DAHA korur — tek seferlik, SADECE bu site için geçerlidir. Bu tek seferlik bir satın almadır, OTOMATİK YENİLENEN bir abonelik DEĞİLDİR — kendiliğinden yenilenmez ve tekrar ücret kesmez. Sen elle yenilemezsen ve süresi tekrar dolarsa bağlantı 7 gün sonra tamamen sökülür ve yeniden bağlamak için bu satın almayı tekrar yapman gerekir.')
                  : (en
                      ? '"$name" gets its own domain for 1 year with this purchase — one-time, applies ONLY to this site. This is a one-time purchase, NOT an auto-renewing subscription — it will NOT renew or charge you again by itself; you must come back and buy it again to extend. The "Made with MySitora" badge is removed for as long as the domain stays connected — if the domain lapses and isn\'t renewed, the badge comes back automatically (this is not a permanent removal). Other premium features (lead inbox, full gallery, map, lead form, Google review button, visitor stats) unlock for as long as the domain stays connected — extending before it expires requires this SAME purchase again, and if it lapses for more than 7 days the connection is fully released and this purchase must be made again to reconnect.'
                      : '"$name" bu satın almayla 1 yıllığına kendi domainine kavuşur — tek seferlik, SADECE bu site için geçerlidir. Bu tek seferlik bir satın almadır, OTOMATİK YENİLENEN bir abonelik DEĞİLDİR — kendiliğinden yenilenmez, tekrar ücret kesmez; süresi dolmadan uzatmak istersen tekrar senin satın alman gerekir. "MySitora ile üretildi" rozeti domain bağlı kaldığı sürece kaldırılır — domain süresi dolup yenilenmezse rozet OTOMATİK GERİ GELİR (kalıcı bir kaldırma değildir). Diğer premium özellikler (Talep Kutusu, tam galeri, harita, talep formu, Google yorum butonu, ziyaretçi sayısı) domain bağlı kaldığı sürece açık kalır — süresi dolmadan uzatmak için AYNI satın almayı tekrar yapman gerekir, 7 günden fazla yenilenmezse bağlantı tamamen sökülür ve tekrar bağlamak için bu satın almayı yeniden yapman gerekir.'),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            // 05.09.2026 eklendi (kanka isteği) — kilidi açılan özelliklerin
            // NASIL kullanılacağı bilgisi satın alma ekranında da açıkça
            // yazsın: kilit açılması otomatiktir ama özellikleri GÖRMEK/
            // KULLANMAK için kullanıcının siteyi ayrıca "Düzenle" akışından
            // güncellemesi gerekir — bu adım satın almanın kendisiyle
            // karıştırılmasın diye ayrı bir bilgi kutusunda vurgulanıyor.
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
