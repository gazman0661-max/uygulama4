import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/locale_controller.dart';
import '../localization/app_strings.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../widgets/app_popup.dart';
import '../widgets/quota_overflow_picker_sheet.dart';
import '../widgets/domain_quota_overflow_picker_sheet.dart';
import 'settings_sheet.dart' show openLegalUrl;

/// ============================================================================
/// AYLIK ABONELİK PLANLARI — paket karşılaştırma/satın alma ekranı.
/// 15.09.2026 eklendi (kanka isteği) — bkz. billing_constants.dart dosya
/// başındaki "AYLIK ABONELİK PAKETLERİ" bölümü, subscription_service.dart,
/// AppState.activeSubscriptionTier/hasSubscriptionQuotaOverflow.
/// ============================================================================
/// Bu ekran mağazadaki (store_sheet.dart) "Abonelik Planları" satırından
/// açılır. Görevi:
///   1) Hesabın o anki abonelik durumunu (paket adı, bitiş tarihi, kota
///      kullanımı) göstermek.
///   2) Üç paketi (Mini/Freelancer/Freelancer Max) yan yana karşılaştırmalı
///      kartlar olarak listelemek.
///   3) "Satın Al"/"Paketi Değiştir" butonlarıyla BillingService.buySubscription
///      akışını tetiklemek.
///   4) Kota aşımı varsa (hasSubscriptionQuotaOverflow) bunu belirgin bir
///      uyarı kartıyla göstermek ve quota_overflow_picker_sheet.dart'ı açan
///      bir buton sunmak.
///
/// PAKET DEĞİŞTİRME: kProductSubMini/Freelancer/FreelancerMax Play
/// Console'da AYNI "subscription group" altında üç ayrı ürün olarak
/// tanımlanacağı için (bkz. billing_constants.dart dosya başı), zaten
/// aktif bir abonelik varken farklı bir tier'i satın almaya çalışmak
/// Play Billing'in KENDİ "aboneliği değiştir" (orantılı fiyat farkı) akışını
/// otomatik tetikler — burada ayrıca özel bir "downgrade/upgrade" kodu
/// YAZILMASINA gerek yoktur, BillingService.buySubscription(productId) her
/// durumda (ilk satın alma ya da değiştirme) AYNI şekilde çağrılır.
Future<void> showSubscriptionPlansScreen(BuildContext context) async {
  final ok = await requireLogin(context, feature: t(context, 'Abonelik Planları'));
  if (!ok || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
  );
}

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  String? _buyingProductId;
  String? _error;

  Future<void> _buy(String productId) async {
    setState(() {
      _buyingProductId = productId;
      _error = null;
    });
    // 17.09.2026 eklendi (kanka isteği — "ödediği dönemi kullansın" fix'i,
    // devamı). BillingService.buySubscription artık düşürmede
    // ReplacementMode.deferred kullanıyor — yani mevcut (ödenmiş) dönem
    // BİTMEDEN hiçbir şey değişmez, kota/rozet AYNI kalır. Bunu SATIN
    // ALMADAN ÖNCEKİ aktif pakete göre burada (appState üzerinden) tespit
    // ediyoruz ki BillingService'in içine bakmadan doğru mesajı
    // gösterebilelim.
    final appState = context.read<AppState>();
    final oldProductId = appState.activeSubscriptionProductId;
    final oldIdx = kSubscriptionTiers.indexWhere((t) => t.productId == oldProductId);
    final newIdx = kSubscriptionTiers.indexWhere((t) => t.productId == productId);
    final isDowngrade = oldIdx != -1 && newIdx != -1 && newIdx < oldIdx;
    try {
      final purchased = await BillingService.instance.buySubscription(productId);
      if (!purchased) {
        // Kullanıcı mağaza ekranında vazgeçti — hata değil, sessizce dön.
        if (mounted) setState(() => _buyingProductId = null);
        return;
      }
      if (!mounted) return;
      // BillingService satın alma doğrulanır doğrulanmaz worker'a zaten
      // /api/verify-subscription ile yazmış olur (bkz. o dosyanın
      // dokümanı) — burada SADECE AppState'in yerel önbelleğini o
      // yazılmış duruma göre tazeliyoruz. DÜŞÜRMEDE (deferred) worker'ın
      // Google'dan okuyacağı "gerçek" aktif ürün HÂLÂ ESKİ pakettir (Play
      // değişikliği dönem sonuna erteler) — yani refreshSubscriptionStatus
      // sonrası activeSubscriptionProductId hâlâ eski paket olarak kalır,
      // bu BEKLENEN bir durumdur, hata değildir.
      await appState.refreshSubscriptionStatus();
      if (!mounted) return;
      setState(() => _buyingProductId = null);
      final en = isEnglish(context);
      await showAppPopup(
        context,
        icon: '✅',
        message: isDowngrade
            ? (en
                ? 'Change scheduled — your current plan stays active until this period ends.'
                : 'Değişiklik planlandı — mevcut paketin bu dönem bitene kadar aktif kalır.')
            : (en ? 'Subscription active ✅' : 'Abonelik aktif ✅'),
      );
      // 17.09.2026 eklendi (kanka isteği — "paket düşürdüğünde otomatik
      // açılsın" fix'i, 17.09.2026'da AYRICA güncellendi — "ödediği dönemi
      // kullansın" fix'i sonrası). Paket DEĞİŞTİRME (Play Billing'in kendi
      // "aboneliği değiştir" akışı) de AYNI buySubscription/_buy yolunu
      // kullanıyor (bkz. dosya başı dokümanı). YÜKSELTMEDE davranış AYNI:
      // refreshSubscriptionStatus SONRASI kota aşımı oluştuysa (teoride
      // yükseltmede olmaz, kota büyür) kullanıcı Ana Sayfa'ya dönmeyi
      // beklemeden TAM BURADA sheet açılır. DÜŞÜRMEDE ise artık (deferred
      // sayesinde) BU KONTROL bu anda hiç true DÖNMEZ — eski paket dönem
      // sonuna kadar geçerli olduğu için kota hâlâ eski (yüksek) tier'e
      // göre hesaplanır. Asıl aşım kontrolü, dönem gerçekten bittiğinde
      // (worker'ın günlük subscriptionQuotaOverflowSweep'i VEYA kullanıcı
      // o gün sonra uygulamayı açtığında refreshSubscriptionStatus/
      // home_screen.dart > _maybeAutoOpenQuotaOverflowSheets) devreye
      // girer — bkz. o dosyaların dokümanı. Yani bu blok artık pratikte
      // SADECE yükseltme sonrası (aşım olmasa bile no-op, güvenli) ve
      // yarış durumlarına karşı bir savunma katmanı.
      if (!mounted) return;
      if (appState.hasSubscriptionQuotaOverflow) {
        await showQuotaOverflowPickerSheet(context);
        if (!mounted) return;
      }
      if (appState.hasDomainQuotaOverflow) {
        await showDomainQuotaOverflowPickerSheet(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buyingProductId = null;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  /// Google Play'in kendi abonelik yönetimi sayfası — iptal/yenileme burada
  /// yönetilir, uygulama içinde AYRI bir "iptal et" akışı YOKTUR (Play
  /// Billing zaten bunu kendi UI'ında sunuyor).
  Future<void> _openManageSubscription(String? productId) async {
    const package = 'com.sitora.ai';
    final url = productId == null
        ? 'https://play.google.com/store/account/subscriptions?package=$package'
        : 'https://play.google.com/store/account/subscriptions?sku=$productId&package=$package';
    await openLegalUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final isDark = context.watch<ThemeController>().isDark;
    final en = isEnglish(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkBubbleBg : AppColors.lightBubbleBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(0.6);
    final appState = context.watch<AppState>();

    final activeTier = appState.activeSubscriptionTier;
    final hasSub = appState.hasActiveSubscription;
    final overflow = appState.hasSubscriptionQuotaOverflow;
    final domainOverflow = appState.hasDomainQuotaOverflow;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
        title: Text(
          en ? 'Subscription Plans' : 'Abonelik Planları',
          style: TextStyle(
            color: titleColor,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Genel açıklama kutusu.
              _InfoBox(
                text: en
                    ? 'Monthly, auto-renewing, ACCOUNT-wide subscriptions. Each tier gives you a site quota + custom-domain quota; sites within your quota get the badge removed and premium features unlocked automatically. Cancel anytime from Google Play — locks return automatically once the current period ends.'
                    : 'Aylık, otomatik yenilenen, HESAP genelinde geçerli abonelikler. Her paket bir site kotası + özel domain kotası verir; kota içindeki sitelerin rozeti otomatik kalkar ve premium özellikleri otomatik açılır. İstediğin zaman Google Play\'den iptal edebilirsin — mevcut dönem bitince kilitler otomatik geri gelir.',
              ),
              const SizedBox(height: 14),
              if (hasSub) ...[
                _CurrentPlanCard(
                  cardBg: cardBg,
                  titleColor: titleColor,
                  subtleColor: subtleColor,
                  tierName: activeTier != null
                      ? t(context, activeTier.displayNameTr)
                      : (en ? 'Active plan' : 'Aktif paket'),
                  expiresAt: appState.activeSubscriptionExpiresAt,
                  quotaUsed: appState.subscriptionQuotaUsed,
                  quotaTotal: activeTier?.siteQuota ?? 0,
                  domainQuotaUsed: appState.domainQuotaUsed,
                  domainQuotaTotal: activeTier?.domainQuota ?? 0,
                  formatDate: _formatDate,
                  onManage: () => _openManageSubscription(appState.activeSubscriptionProductId),
                ),
                const SizedBox(height: 14),
              ],
              if (overflow) ...[
                _OverflowWarningCard(
                  cardBg: cardBg,
                  onResolve: () => showQuotaOverflowPickerSheet(context),
                ),
                const SizedBox(height: 14),
              ],
              // 16.09.2026 eklendi (kanka isteği: "domain kota aşımı: UI
              // YOK" fix'i) — site/rozet kotası uyarı kartıyla AYNI yer,
              // domain kotası için (bkz. AppState.hasDomainQuotaOverflow).
              if (domainOverflow) ...[
                _DomainOverflowWarningCard(
                  cardBg: cardBg,
                  onResolve: () => showDomainQuotaOverflowPickerSheet(context),
                ),
                const SizedBox(height: 14),
              ],
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
              for (final tier in kSubscriptionTiers) ...[
                _TierCard(
                  tier: tier,
                  cardBg: cardBg,
                  titleColor: titleColor,
                  subtleColor: subtleColor,
                  isActive: hasSub && appState.activeSubscriptionProductId == tier.productId,
                  hasAnySubscription: hasSub,
                  busy: _buyingProductId == tier.productId,
                  anyBusy: _buyingProductId != null,
                  priceLabel: BillingService.instance.products[tier.productId]?.price ??
                      t(context, 'Fiyat alınamadı'),
                  onTap: () => _buy(tier.productId),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 6),
              if (hasSub)
                Center(
                  child: TextButton(
                    onPressed: () => _openManageSubscription(appState.activeSubscriptionProductId),
                    child: Text(
                      en ? 'Manage / cancel on Google Play' : 'Google Play\'de yönet / iptal et',
                      style: TextStyle(color: Colors.grey.shade500, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ℹ️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white60, fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final Color cardBg;
  final Color titleColor;
  final Color subtleColor;
  final String tierName;
  final DateTime? expiresAt;
  final int quotaUsed;
  final int quotaTotal;
  final int domainQuotaUsed;
  final int domainQuotaTotal;
  final String Function(DateTime) formatDate;
  final VoidCallback onManage;

  const _CurrentPlanCard({
    required this.cardBg,
    required this.titleColor,
    required this.subtleColor,
    required this.tierName,
    required this.expiresAt,
    required this.quotaUsed,
    required this.quotaTotal,
    required this.domainQuotaUsed,
    required this.domainQuotaTotal,
    required this.formatDate,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF66BB6A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🟢', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  en ? 'Active: $tierName' : 'Aktif: $tierName',
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (expiresAt != null)
            Text(
              en
                  ? 'Renews/expires: ${formatDate(expiresAt!)}'
                  : 'Yenileme/bitiş: ${formatDate(expiresAt!)}',
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12),
            ),
          const SizedBox(height: 4),
          Text(
            en
                ? 'Site quota in use: $quotaUsed / $quotaTotal'
                : 'Kullanılan site kotası: $quotaUsed / $quotaTotal',
            style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            en
                ? 'Domain quota in use: $domainQuotaUsed / $domainQuotaTotal'
                : 'Kullanılan domain kotası: $domainQuotaUsed / $domainQuotaTotal',
            style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onManage,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: Text(
                en ? 'Manage on Google Play →' : 'Google Play\'de yönet →',
                style: const TextStyle(color: AppColors.accentBlue, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowWarningCard extends StatelessWidget {
  final Color cardBg;
  final VoidCallback onResolve;
  const _OverflowWarningCard({required this.cardBg, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74D).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  en ? 'You have more sites than your quota allows' : 'Kotandan fazla siten var',
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            en
                ? 'Your plan changed or your subscription expired. Nothing was removed automatically — pick which site(s) should keep the badge-free/premium benefits.'
                : 'Paketin küçüldü ya da aboneliğin süresi doldu. Hiçbir şey otomatik kaldırılmadı — rozetsiz/premium avantajları hangi site(ler)in koruyacağını sen seç.',
            style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: en ? 'Choose sites' : 'Siteleri seç',
              emoji: '🗂️',
              borderColor: const Color(0xFFFFB74D),
              textColor: Colors.white,
              filled: true,
              fillColor: const Color(0xFFFFB74D),
              height: 42,
              fontSize: 13,
              onTap: onResolve,
            ),
          ),
        ],
      ),
    );
  }
}

/// 16.09.2026 eklendi (kanka isteği: "domain kota aşımı: UI YOK" fix'i) —
/// _OverflowWarningCard ile AYNI görünüm, domain kotası için. Metni
/// KASITLI olarak farklı: burada seçilmeyen domain'ler GERÇEKTEN sökülür
/// (bkz. domain_quota_overflow_picker_sheet.dart dosya başı dokümanı),
/// site/rozet kotasındaki gibi sadece rozet/kilit geri gelmesi DEĞİL.
class _DomainOverflowWarningCard extends StatelessWidget {
  final Color cardBg;
  final VoidCallback onResolve;
  const _DomainOverflowWarningCard({required this.cardBg, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  en ? 'You have more connected domains than your quota allows' : 'Domain kotandan fazla bağlı domain\'in var',
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            en
                ? 'Your plan changed or your subscription expired. Pick which domain(s) should stay connected — the rest will be REALLY disconnected (their sites keep working on their free subdomain).'
                : 'Paketin küçüldü ya da aboneliğin süresi doldu. Bağlı kalacak domain(ler)i sen seç — geri kalanlar GERÇEKTEN sökülür (siteleri kendi ücretsiz alt alan adında çalışmaya devam eder).',
            style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: en ? 'Choose domains' : 'Domain\'leri seç',
              emoji: '🌐',
              borderColor: const Color(0xFFEF5350),
              textColor: Colors.white,
              filled: true,
              fillColor: const Color(0xFFEF5350),
              height: 42,
              fontSize: 13,
              onTap: onResolve,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final SubscriptionTierInfo tier;
  final Color cardBg;
  final Color titleColor;
  final Color subtleColor;
  final bool isActive;
  final bool hasAnySubscription;
  final bool busy;
  final bool anyBusy;
  final String priceLabel;
  final VoidCallback onTap;

  const _TierCard({
    required this.tier,
    required this.cardBg,
    required this.titleColor,
    required this.subtleColor,
    required this.isActive,
    required this.hasAnySubscription,
    required this.busy,
    required this.anyBusy,
    required this.priceLabel,
    required this.onTap,
  });

  String _tierEmoji() {
    switch (tier.productId) {
      case kProductSubMini:
        return '🎟️';
      case kProductSubFreelancer:
        return '💼';
      case kProductSubFreelancerMax:
        return '🚀';
      default:
        return '📦';
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final borderColor = isActive ? const Color(0xFF66BB6A) : Colors.white24;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActive ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_tierEmoji(), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t(context, tier.displayNameTr),
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                priceLabel,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            en ? '/ month' : '/ ay',
            style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11),
          ),
          const SizedBox(height: 12),
          _FeatureLine(subtleColor: subtleColor, text: en ? '${tier.siteQuota} published site(s)' : '${tier.siteQuota} yayınlı site'),
          _FeatureLine(subtleColor: subtleColor, text: en ? '${tier.domainQuota} custom domain(s)' : '${tier.domainQuota} özel domain'),
          _FeatureLine(subtleColor: subtleColor, text: en ? 'Badge removed (within quota)' : 'Rozet kaldırılır (kota dahilinde)'),
          _FeatureLine(subtleColor: subtleColor, text: en ? 'Lead inbox, gallery, map, review button' : 'Talep Kutusu, galeri, harita, yorum butonu'),
          _FeatureLine(
            subtleColor: subtleColor,
            text: tier.freeDownloads
                ? (en ? 'Free downloads' : 'Ücretsiz indirme')
                : (en ? 'Downloads sold separately' : 'İndirme ayrı satılır'),
            muted: !tier.freeDownloads,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: busy
                  ? (en ? 'Processing...' : 'İşleniyor...')
                  : isActive
                      ? (en ? 'Active Plan ✓' : 'Aktif Paket ✓')
                      : hasAnySubscription
                          ? (en ? 'Switch to this plan' : 'Bu pakete geç')
                          : (en ? 'Subscribe' : 'Satın Al'),
              emoji: busy || isActive ? null : '💳',
              borderColor: isActive ? const Color(0xFF66BB6A) : AppColors.accentBlue,
              textColor: Colors.white,
              filled: !isActive,
              fillColor: AppColors.accentBlue,
              height: 44,
              fontSize: 13,
              onTap: isActive || anyBusy ? null : onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final Color subtleColor;
  final String text;
  final bool muted;
  const _FeatureLine({required this.subtleColor, required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(muted ? '·' : '✓', style: TextStyle(color: muted ? subtleColor : const Color(0xFF66BB6A), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: muted ? subtleColor : subtleColor, fontFamily: 'monospace', fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
