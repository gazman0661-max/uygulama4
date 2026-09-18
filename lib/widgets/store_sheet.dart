import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/remove_watermark_sheet.dart';
import '../widgets/login_gate.dart';
import '../widgets/quota_overflow_picker_sheet.dart';
import '../widgets/domain_quota_overflow_picker_sheet.dart';
import '../screens/domain_connect_screen.dart';
import '../screens/subscription_plans_screen.dart';
import '../localization/app_strings.dart';
import 'app_popup.dart';

/// Ana sayfadaki "Mağaza" butonunun açtığı sheet — mevcut satın alma
/// akışlarının (yayın hakkı, rozet kaldırma) tek bir yerden
/// tetiklenebildiği giriş noktası.
///
/// Yayın hakkı hesap genelinde geçerli olduğu için direkt satın
/// alınabiliyor. Rozet kaldırma SİTE BAZLI olduğu için
/// (bkz. remove_watermark_sheet.dart) burada önce bir proje seçtiriyoruz,
/// sonra mevcut showRemoveWatermarkSheet akışını aynen çağırıyoruz —
/// böylece asıl satın alma mantığı tek yerde (remove_watermark_sheet.dart)
/// kalıyor, burası sadece "hangi site" sorusunu ekliyor.
Future<void> showStoreSheet(BuildContext context) async {
  // Mağazadaki satın alma akışlarının (yayın hakkı, rozet kaldırma)
  // tamamı hesaba bağlıdır — bu yüzden giriş kontrolü burada, sheet hiç
  // açılmadan önce yapılır (bkz. login_gate.dart > requireLogin). Zaten
  // giriş yapılmışsa hiçbir şey göstermeden anında devam eder.
  final ok = await requireLogin(context, feature: t(context, 'Mağaza'));
  if (!ok || !context.mounted) return;

  // 18.09.2026 fix (kanka bug raporu — "uygulamada açık temada mağaza koyu
  // temada kalıyor") — bg buradaki showModalBottomSheet çağrısında SABİT
  // koyu renkti, uygulamanın açık/koyu tema tercihini hiç dinlemiyordu. Artık
  // transparent bırakılıp gerçek arkaplan _StoreSheet'in kendi build()'inde
  // ThemeController.isDark'a göre çiziliyor (bkz. aşağısı) — tıpkı
  // subscription_plans_screen.dart'ın yaptığı gibi.
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StoreSheet(),
  );
}

class _StoreSheet extends StatefulWidget {
  const _StoreSheet();

  @override
  State<_StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends State<_StoreSheet> {
  bool _buyingPublishSlot = false;
  String? _error;

  Future<void> _buyPublishSlot() async {
    setState(() {
      _buyingPublishSlot = true;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(kProductPublishSlot);
      if (!purchased) {
        // Kullanıcı mağaza ekranında vazgeçti — hata değil, sessizce dön.
        if (mounted) setState(() => _buyingPublishSlot = false);
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().addPurchasedPublishCredit();
      if (!mounted) return;
      setState(() => _buyingPublishSlot = false);
      final en = isEnglish(context);
      showAppPopup(context, message: en ? 'Publish credit added ✅' : 'Yayın hakkı eklendi ✅', icon: '✅');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buyingPublishSlot = false;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _pickProjectForWatermark() async {
    final appState = context.read<AppState>();
    // Rozeti zaten kaldırılmış projeleri listeye koymuyoruz — tekrar
    // satın almaya gerek yok, AppState zaten watermarkRemoved'ı kalıcı
    // tutuyor.
    final eligible = appState.projects.where((p) => !p.watermarkRemoved).toList();
    final en = isEnglish(context);

    if (eligible.isEmpty) {
      showAppPopup(context, message: en
              ? 'No eligible sites — create a site first, or every site already has the badge removed.'
              : 'Uygun site yok — önce bir site oluşturman lazım, ya da tüm sitelerinde rozet zaten kaldırılmış.');
      return;
    }

    final selected = await showModalBottomSheet<SiteProject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectPickerSheet(projects: eligible),
    );
    if (selected == null || !mounted) return;

    // Ana mağaza sheet'ini kapatmıyoruz — kullanıcı isterse rozet
    // kaldırma sheet'i kapandıktan sonra başka bir ürüne de bakabilsin.
    await showRemoveWatermarkSheet(context, project: selected);
  }

  /// 05.09.2026 eklendi (kanka isteği) — mağazaya "Kendi Domain Bağla"
  /// satırı: rozet kaldırma/mini paketten FARKI, domain bağlama tek bir
  /// satın alma sheet'i değil, TAM EKRAN bir akış (domain adı girme, CNAME
  /// gösterme, durum takibi — bkz. domain_connect_screen.dart). Bu yüzden
  /// proje seçildikten SONRA mağaza sheet'i kapatılıp DomainConnectScreen
  /// push ediliyor; ilk bağlamadaki gerçek satın alma sheet'i (satın alma
  /// akışı) o ekranın kendi "Bağla" butonuna basıldığında zaten devreye
  /// giriyor (bkz. showDomainPurchaseSheet çağrısı orada). Eligible listesi
  /// mini paketle AYNI mantıkla TÜM projeler — zaten bağlı bir sitede de bu
  /// ekran "Uzat"/durum gösterimi olarak anlamlı.
  Future<void> _pickProjectForDomain() async {
    final appState = context.read<AppState>();
    final eligible = appState.projects.toList();
    final en = isEnglish(context);

    if (eligible.isEmpty) {
      showAppPopup(context, message: en
              ? 'No eligible sites — create a site first.'
              : 'Uygun site yok — önce bir site oluşturman lazım.');
      return;
    }

    final selected = await showModalBottomSheet<SiteProject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectPickerSheet(projects: eligible),
    );
    if (selected == null || !mounted) return;

    // Domain akışı tam ekran olduğu için (diğer satırların aksine) burada
    // mağaza sheet'ini kapatıyoruz.
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DomainConnectScreen(project: selected)),
    );
  }

  /// 15.09.2026 eklendi (kanka isteği) — "Abonelik Planları" satırı: diğer
  /// satırların aksine (site bazlı tek seferlik ürünler) bu HESAP bazlı bir
  /// akış, proje seçtirmeye gerek yok. Domain satırıyla AYNI desen: tam
  /// ekran bir akış olduğu için önce mağaza sheet'i kapatılır, sonra
  /// SubscriptionPlansScreen push edilir (bkz. showSubscriptionPlansScreen,
  /// kendi içinde AYRICA requireLogin çağırıyor — burada tekrar gerek yok
  /// ama zararsız, çünkü showStoreSheet zaten girişi bu sheet açılmadan ÖNCE
  /// zorunlu kılıyor).
  Future<void> _openSubscriptionPlans() async {
    Navigator.of(context).pop();
    await showSubscriptionPlansScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final publishPriceLabel =
        BillingService.instance.products[kProductPublishSlot]?.price ?? t(context, 'Fiyat alınamadı');
    // 19.08.2026 eklendi: "Rozet Kaldır" satırı fiyatı hiç göstermiyordu,
    // sağda hep sabit "Site Seç" yazıyordu. Kullanıcı site seçmeden ÖNCE
    // fiyatı görebilsin diye, diğer satırlarla (Yayın Hakkı) aynı
    // desenle mağazadan canlı fiyatı çekip alt açıklamanın içine ekliyoruz.
    final watermarkPriceLabel =
        BillingService.instance.products[kProductRemoveWatermark]?.price ?? t(context, 'Fiyat alınamadı');
    // 05.09.2026 eklendi — "Kendi Domain Bağla" satırı için, diğerleriyle
    // AYNI desen.
    final domainPriceLabel =
        BillingService.instance.products[kProductConnectDomain]?.price ?? t(context, 'Fiyat alınamadı');
    final appState = context.watch<AppState>();

    // 18.09.2026 fix (kanka bug raporu — "mağaza her zaman koyu kalıyor") —
    // subscription_plans_screen.dart ile AYNI desen: ThemeController.isDark'a
    // göre bg/kart/başlık/alt metin renklerini seçiyoruz, artık uygulama
    // açık temadayken mağaza da açık, koyu temadayken koyu görünüyor.
    final isDark = context.watch<ThemeController>().isDark;
    final sheetBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final rowBg = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.035);
    final infoBoxBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final infoBoxBorder = isDark ? Colors.white24 : Colors.black12;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.6 : 0.65);
    final closeColor = isDark ? Colors.grey.shade500 : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
        // 05.09.2026 eklendi — KRİTİK DÜZELTME: "1 Aylık Mini Paket" satırı
        // eklenince (5. satır) toplam içerik ekran boyunu aştı ve taşan
        // kısım (Mini Paket + Kapat butonu) hiç görünmüyordu ("BOTTOM
        // OVERFLOWED" hatası). Önceden bu Column doğrudan Padding'in
        // altındaydı, kaydırma imkanı yoktu — artık SingleChildScrollView
        // içinde, sığmayan içerik kaydırılarak görülebiliyor.
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
            const Text('🛍️', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              t(context, 'Mağaza'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            // 05.09.2026 eklendi (kanka isteği) — hangi özelliklerin
            // açıldığı ve bunların NASIL kullanılacağı bilgisi mağzada da
            // açıkça yazsın (satın alma sheet'lerindeki bilgi kutusuyla AYNI
            // metin, sadece burada tek bir genel özet olarak).
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoBoxBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: infoBoxBorder, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      en
                          ? 'Connecting a domain removes the badge AND unlocks: lead inbox, full gallery, map, lead form, Google review button, visitor stats. To use these, open the relevant site from My Projects and update it via the "Edit" button.'
                          : 'Domain bağlama, rozeti kaldırmanın YANI SIRA şunları da açar: Talep Kutusu, tam galeri, harita, talep formu, Google yorum butonu, ziyaretçi sayısı. Bunları kullanmak için ilgili siteyi Projelerim ekranından açıp "Düzenle" butonuyla güncellemen gerekir.',
                      style: TextStyle(
                        color: subtleColor,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _StoreRow(
              emoji: '🚀',
              title: t(context, 'Ek Site Yayın Hakkı'),
              subtitle: en
                  ? 'You have ${appState.extraPublishCredits + appState.giftPublishCredits} unused credit(s). First site is free — every extra site needs one of these.'
                  : 'Elinde ${appState.extraPublishCredits + appState.giftPublishCredits} kullanılmamış hak var. İlk site ücretsiz — sonraki her yeni site için bir tane gerekir.',
              trailingLabel: _buyingPublishSlot ? t(context, 'İşleniyor...') : publishPriceLabel,
              onTap: _buyingPublishSlot ? null : _buyPublishSlot,
              rowBg: rowBg,
              titleColor: titleColor,
              subtitleColor: subtleColor,
            ),
            const SizedBox(height: 12),
            _StoreRow(
              emoji: '🏷️',
              title: t(context, 'Rozet Kaldır'),
              subtitle: en
                  ? 'Site-specific — pick which site. Price: $watermarkPriceLabel'
                  : 'Site bazlıdır — hangi site için istediğini seçmen gerekir. Fiyat: $watermarkPriceLabel',
              trailingLabel: t(context, 'Site Seç'),
              onTap: _pickProjectForWatermark,
              rowBg: rowBg,
              titleColor: titleColor,
              subtitleColor: subtleColor,
            ),
            const SizedBox(height: 12),
            _StoreRow(
              emoji: '🌐',
              title: t(context, 'Kendi Domainimi Bağla'),
              subtitle: en
                  ? 'Site-specific, 1 year — connects your own domain, permanently removes the badge, AND unlocks other premium features (download not included, sold separately). One-time purchase, does NOT auto-renew. Extending before it expires requires the same purchase again. Price: $domainPriceLabel'
                  : 'Site bazlıdır, 1 yıllık — kendi alan adına bağlanır, rozeti kalıcı olarak kaldırır VE diğer premium özellikleri açar (indirme dahil değildir, ayrı satılır). Tek seferlik satın almadır, OTOMATİK YENİLENMEZ. Süresi dolmadan uzatmak aynı satın almayı gerektirir. Fiyat: $domainPriceLabel',
              trailingLabel: t(context, 'Site Seç'),
              onTap: _pickProjectForDomain,
              rowBg: rowBg,
              titleColor: titleColor,
              subtitleColor: subtleColor,
            ),
            const SizedBox(height: 12),
            // 15.09.2026 eklendi (kanka isteği) — "Abonelik Planları" satırı:
            // Mini/Freelancer/Freelancer Max karşılaştırma+satın alma
            // ekranını açar (bkz. subscription_plans_screen.dart).
            _StoreRow(
              emoji: '📅',
              title: t(context, 'Abonelik Planları'),
              subtitle: en
                  ? 'Account-wide, auto-renewing monthly plans — bundles a site quota + custom-domain quota with the badge/lock unlocks above. See plan comparison and pricing.'
                  : 'Hesap genelinde, otomatik yenilenen aylık paketler — yukarıdaki rozet/kilit açımlarını bir site kotası + domain kotasıyla paketler. Paket karşılaştırması ve fiyatları gör.',
              trailingLabel: appState.hasActiveSubscription
                  ? t(context, 'Yönet')
                  : (en ? 'Compare' : 'Karşılaştır'),
              onTap: _openSubscriptionPlans,
              rowBg: rowBg,
              titleColor: titleColor,
              subtitleColor: subtleColor,
            ),
            if (appState.hasSubscriptionQuotaOverflow) ...[
              const SizedBox(height: 12),
              _StoreRow(
                emoji: '⚠️',
                title: en ? 'Quota overflow — pick sites' : 'Kota aşımı — site seç',
                subtitle: en
                    ? 'You have more sites than your current plan allows. Choose which ones keep their premium benefits.'
                    : 'Şu anki paketinin izin verdiğinden fazla siten var. Hangilerinin premium avantajları koruyacağını seç.',
                trailingLabel: en ? 'Choose' : 'Seç',
                onTap: () => showQuotaOverflowPickerSheet(context),
                rowBg: rowBg,
                titleColor: titleColor,
                subtitleColor: subtleColor,
              ),
            ],
            if (appState.hasDomainQuotaOverflow) ...[
              const SizedBox(height: 12),
              _StoreRow(
                emoji: '🌐',
                title: en ? 'Domain quota overflow — pick domains' : 'Domain kota aşımı — domain seç',
                subtitle: en
                    ? 'You have more connected domains than your current plan allows. Choose which ones stay connected — the rest will be disconnected.'
                    : 'Şu anki paketinin izin verdiğinden fazla bağlı domain\'in var. Hangilerinin bağlı kalacağını seç — geri kalanlar söktürülür.',
                trailingLabel: en ? 'Choose' : 'Seç',
                onTap: () => showDomainQuotaOverflowPickerSheet(context),
                rowBg: rowBg,
                titleColor: titleColor,
                subtitleColor: subtleColor,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(context, 'Kapat'), style: TextStyle(color: closeColor)),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback? onTap;
  // 18.09.2026 eklendi (kanka bug raporu fix'i) — önceden Colors.white'a
  // sabitliydi, artık çağıran (_StoreSheetState) açık/koyu temaya göre
  // hesaplanmış renkleri buraya geçiyor.
  final Color rowBg;
  final Color titleColor;
  final Color subtitleColor;

  const _StoreRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
    required this.rowBg,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: rowBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: subtitleColor, fontFamily: 'monospace', fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailingLabel,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Rozet Kaldır" için hangi siteye uygulanacağını seçtiren basit liste
/// sheet'i. Sadece bir [SiteProject] döner (Navigator.pop(project)) — asıl
/// satın alma mantığına hiç dokunmaz.
class _ProjectPickerSheet extends StatelessWidget {
  final List<SiteProject> projects;
  const _ProjectPickerSheet({required this.projects});

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    // 18.09.2026 fix (kanka bug raporu) — bu alt-sheet de mağazayla AYNI
    // sabit-koyu sorununu yaşıyordu; artık ThemeController.isDark'a göre
    // kendi arkaplanını çiziyor (showStoreSheet artık transparent açıyor).
    final isDark = context.watch<ThemeController>().isDark;
    final sheetBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final rowBg = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.035);
    final iconColor = isDark ? Colors.white54 : Colors.black45;
    final closeColor = isDark ? Colors.grey.shade500 : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 22, bottom: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              en ? 'Which site?' : 'Hangi site?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = projects[i];
                  return Material(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.language, color: iconColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: titleColor, fontFamily: 'monospace', fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(en ? 'Cancel' : 'Vazgeç', style: TextStyle(color: closeColor)),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
