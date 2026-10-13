import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/constants/billing_constants.dart';
import 'package:sitora_ai/models/site_project.dart';
import 'package:sitora_ai/state/app_state.dart' show SiteMode;
import 'package:sitora_ai/services/free_plan_page_limit_service.dart';

SiteProject _project({bool domain = false, bool domainViaSubscription = false}) {
  final now = DateTime.now();
  return SiteProject(
    id: 'p1',
    name: 'Test',
    mode: SiteMode.multi,
    code: '',
    files: const {},
    activeFileName: 'index.html',
    createdAt: now,
    updatedAt: now,
    customDomain: domain ? 'ornek.com' : null,
    domainStatus: domain ? 'active' : null,
    domainConnectedAt: domain ? now : null,
    domainViaSubscription: domainViaSubscription,
  );
}

void main() {
  const cap = FreePlanPageLimitService.domainPurchaseMaxPages;

  test('paket sayfa sınırları: Başlangıç 3 / Mini 5 / Freelancer 10 / Max 15', () {
    expect(kTierBaslangic.maxPages, 3);
    expect(kTierMini.maxPages, 5);
    expect(kTierFreelancer.maxPages, 10);
    expect(kTierFreelancerMax.maxPages, 15);
    expect(cap, 15);
  });

  test('ücretsiz: çok sayfa kilitli, tek sayfa', () {
    expect(FreePlanPageLimitService.canUseMultiPage(null), false);
    expect(FreePlanPageLimitService.maxTotalPagesFor(null), 1);
  });

  test('ücretsiz + Emlak istisnası: 2 sayfa', () {
    expect(FreePlanPageLimitService.canUseMultiPage(null, alwaysMultiPage: true), true);
    expect(FreePlanPageLimitService.maxTotalPagesFor(null, alwaysMultiPage: true), 2);
  });

  test('abonelik paketi çok sayfayı pakete göre açar', () {
    for (final tier in kSubscriptionTiers) {
      expect(FreePlanPageLimitService.canUseMultiPage(null, tier: tier), true);
      expect(FreePlanPageLimitService.maxTotalPagesFor(null, tier: tier), tier.maxPages);
    }
  });

  test('abonelik sınırı Emlak ücretsiz sınırından düşük olamaz', () {
    expect(
      FreePlanPageLimitService.maxTotalPagesFor(null, alwaysMultiPage: true, tier: kTierBaslangic),
      3,
    );
  });

  test('satın alınmış tek seferlik domain: 15 sayfa (sınırsız değil)', () {
    final p = _project(domain: true);
    expect(FreePlanPageLimitService.canUseMultiPage(p), true);
    expect(FreePlanPageLimitService.maxTotalPagesFor(p), 15);
  });

  test('satın alınmış domain + düşük paket: büyük olan (15) geçerli', () {
    final p = _project(domain: true);
    expect(FreePlanPageLimitService.maxTotalPagesFor(p, tier: kTierBaslangic), 15);
  });

  test('abonelikten verilen domain ayrıca hak vermez: paket sınırı geçerli', () {
    final p = _project(domain: true, domainViaSubscription: true);
    expect(FreePlanPageLimitService.maxTotalPagesFor(p, tier: kTierMini), 5);
    expect(FreePlanPageLimitService.canUseMultiPage(p), false);
  });
}
