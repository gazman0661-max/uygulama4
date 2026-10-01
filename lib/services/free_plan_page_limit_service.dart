import '../constants/billing_constants.dart';
import '../models/site_project.dart';

class FreePlanPageLimitService {
  FreePlanPageLimitService._();

  static const int miniPackageMaxExtraPages = 3;

  static const int miniPackageMaxTotalPages = miniPackageMaxExtraPages + 1;

  static const int freeAlwaysMultiPageMaxTotalPages = 2;

  static bool _isDomainPremium(SiteProject? project) =>
      project != null && project.isDomainConnected && !project.isDomainExpired;

  static bool _isMiniPackagePremium(SiteProject? project) =>
      project != null && project.isMiniPackageActive;

  static bool _isSubscriptionPremium(
    SiteProject? project,
    SubscriptionTierInfo? accountTier,
    bool hasSlot,
  ) =>
      (accountTier != null && hasSlot) ||
      (project != null && project.isSubscriptionQuotaActive);

  static int? _subscriptionLimit(SubscriptionTierInfo? accountTier) =>
      (accountTier ?? kTierBaslangic).maxTotalPages;

  static bool canUseMultiPage(
    SiteProject? project, {
    bool alwaysMultiPage = false,
    SubscriptionTierInfo? accountTier,
    bool hasSubscriptionSlot = false,
  }) {
    if (alwaysMultiPage) return true;
    return _isDomainPremium(project) ||
        _isMiniPackagePremium(project) ||
        _isSubscriptionPremium(project, accountTier, hasSubscriptionSlot);
  }

  static int? maxTotalPagesFor(
    SiteProject? project, {
    bool alwaysMultiPage = false,
    SubscriptionTierInfo? accountTier,
    bool hasSubscriptionSlot = false,
  }) {
    if (_isDomainPremium(project)) return null;
    final limits = <int>[];
    if (_isSubscriptionPremium(project, accountTier, hasSubscriptionSlot)) {
      final l = _subscriptionLimit(accountTier);
      if (l == null) return null;
      limits.add(l);
    }
    if (_isMiniPackagePremium(project)) limits.add(miniPackageMaxTotalPages);
    if (alwaysMultiPage) limits.add(freeAlwaysMultiPageMaxTotalPages);
    if (limits.isEmpty) return 1;
    return limits.reduce((a, b) => a > b ? a : b);
  }

  static String lockedMessage(bool isEnglish, {required bool alwaysMultiPage}) {
    if (alwaysMultiPage) {
      return isEnglish
          ? 'This site type needs multiple listing pages. On the free plan you can publish up to $freeAlwaysMultiPageMaxTotalPages pages for this site — connect a custom domain or buy the Mini Package on this project to unlock more.'
          : 'Bu site türü birden fazla ilan sayfası gerektirir. Ücretsiz planda bu site için en fazla $freeAlwaysMultiPageMaxTotalPages sayfa yayınlayabilirsin — daha fazlası için bu projeye özel domain bağla ya da Mini Paket satın al.';
    }
    return isEnglish
        ? 'Multi-page sites are a premium feature. Subscribe to a monthly plan (Başlangıç 5 pages, Mini 15, Freelancer and above unlimited), connect a custom domain for unlimited pages, or buy the Mini Package for up to $miniPackageMaxExtraPages extra pages.'
        : 'Çok sayfalı site premium bir özellik. Aylık abonelik al (Başlangıç 5 sayfa, Mini 15, Freelancer ve üstü sınırsız) ya da bu projeye özel domain bağla, sayfa sayısı sınırsız olur; Mini Paket alırsan $miniPackageMaxExtraPages ek sayfaya kadar üretebilirsin.';
  }

  static String tooManyPagesMessage(bool isEnglish, int maxTotalPages) {
    return isEnglish
        ? 'Your plan allows up to $maxTotalPages pages per site. Remove some pages, or upgrade your plan (Freelancer and above: unlimited pages).'
        : 'Paketin site başına en fazla $maxTotalPages sayfaya izin veriyor. Birkaç sayfa çıkar ya da paketini yükselt (Freelancer ve üstü: sınırsız sayfa).';
  }
}
