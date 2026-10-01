library billing_constants;


const String kProductRemoveWatermark = 'sitora_remove_watermark';

const String kProductDownloadWatermarked = 'sitora_download_watermarked';

const String kProductDownloadNoWatermark = 'sitora_download_no_watermark';

const String kProductPublishSlot = 'sitora_publish_slot';

const String kProductConnectDomain = 'sitora_connect_domain';

const String kProductMiniPackage = 'sitora_mini_package_1ay';

const String kProductSubBaslangic = 'sitora_sub_baslangic_aylik';

const String kProductSubMini = 'sitora_sub_mini_aylik';

const String kProductSubFreelancer = 'sitora_sub_freelancer_aylik';

const String kProductSubFreelancerMax = 'sitora_sub_freelancer_max_aylik';

const Set<String> kAllSubscriptionProductIds = {
  kProductSubBaslangic,
  kProductSubMini,
  kProductSubFreelancer,
  kProductSubFreelancerMax,
};

class SubscriptionTierInfo {
  final String productId;
  final String displayNameTr;
  final int siteQuota;
  final int domainQuota;
  final bool freeDownloads;

  final int? maxTotalPages;

  const SubscriptionTierInfo({
    required this.productId,
    required this.displayNameTr,
    required this.siteQuota,
    required this.domainQuota,
    required this.freeDownloads,
    required this.maxTotalPages,
  });
}

const SubscriptionTierInfo kTierBaslangic = SubscriptionTierInfo(
  productId: kProductSubBaslangic,
  displayNameTr: 'Başlangıç Paket',
  siteQuota: 1,
  domainQuota: 0,
  freeDownloads: false,
  maxTotalPages: 5,
);

const SubscriptionTierInfo kTierMini = SubscriptionTierInfo(
  productId: kProductSubMini,
  displayNameTr: 'Mini Paket',
  siteQuota: 1,
  domainQuota: 1,
  freeDownloads: false,
  maxTotalPages: 15,
);

const SubscriptionTierInfo kTierFreelancer = SubscriptionTierInfo(
  productId: kProductSubFreelancer,
  displayNameTr: 'Freelancer Paket',
  siteQuota: 5,
  domainQuota: 5,
  freeDownloads: false,
  maxTotalPages: null,
);

const SubscriptionTierInfo kTierFreelancerMax = SubscriptionTierInfo(
  productId: kProductSubFreelancerMax,
  displayNameTr: 'Freelancer Max Paket',
  siteQuota: 10,
  domainQuota: 10,
  freeDownloads: false,
  maxTotalPages: null,
);

const List<SubscriptionTierInfo> kSubscriptionTiers = [
  kTierBaslangic,
  kTierMini,
  kTierFreelancer,
  kTierFreelancerMax,
];

final Map<String, SubscriptionTierInfo> kSubscriptionTierByProductId = {
  for (final t in kSubscriptionTiers) t.productId: t,
};

const Set<String> kAllProductIds = {
  kProductDownloadWatermarked,
  kProductDownloadNoWatermark,
  kProductPublishSlot,
  kProductConnectDomain,
  kProductSubBaslangic,
  kProductSubMini,
  kProductSubFreelancer,
  kProductSubFreelancerMax,
};
