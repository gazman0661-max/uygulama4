import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../state/app_state.dart';
import 'premium_locked_popup.dart';

/// 05.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği,
/// madde 4: "Bizi Google'da Değerlendirin" butonu).
///
/// [LocationPickerField] / [LeadFormToggleField] ile BİREBİR AYNI kalıp:
/// free plan'da (bkz. AppState.qtCurrentIsPremium) bu alan TAMAMEN kilitli
/// — form doldururken Google yorum linki girilemiyor, kilitli bir
/// placeholder gösteriliyor (dokununca [showPremiumLockedPopup]). Bu
/// "girişte kilitli" olduğu için free kullanıcının controller'ında zaten
/// hiçbir zaman değer olmayacak; üretilen sitede butonun hiç çıkmaması
/// için AYRICA çıktı seviyesinde ikinci bir güvenlik ağı da var — bkz.
/// templates/html/shared_html_blocks.dart > googleReviewButtonHtml
/// (FreePlanRestrictionService.isPremiumGeneration kontrolü; TALEP FORMU
/// kilidiyle AYNI merkezi nokta).
class GoogleReviewLinkField extends StatelessWidget {
  const GoogleReviewLinkField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AppState>().qtCurrentIsPremium;
    if (!isPremium) {
      return _LockedGoogleReviewField(
        onTap: () => showPremiumLockedPopup(
          context,
          message: isEnglish(context)
              ? 'Adding a "Rate us on Google" button to your site is only available on the Premium (custom domain) plan.'
              : 'Sitene "Bizi Google\'da Değerlendirin" butonu eklemek sadece Premium (özel domain) planında.',
        ),
      );
    }
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: t(context, 'Google Yorum Linki (opsiyonel)'),
        hintText: 'https://g.page/r/.../review',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Free plan'da [GoogleReviewLinkField] yerine gösterilen kilitli
/// placeholder — bkz. widgets/location_picker_field.dart > _LockedLocationField
/// (AYNI görsel kalıp).
class _LockedGoogleReviewField extends StatelessWidget {
  const _LockedGoogleReviewField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade100,
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEnglish(context)
                    ? 'Google review button — Premium plan feature'
                    : 'Google yorum butonu — Premium plan özelliği',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
