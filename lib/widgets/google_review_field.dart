import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../state/app_state.dart';
import 'gbp_setup_wizard.dart';
import 'premium_locked_popup.dart';

// Formlar sadece bu dosyayı import ediyor; sihirbaza veri geçirmek için
// gereken GbpPrefill'in ayrı bir import gerektirmemesi için buradan dışa açılır.
export 'gbp_setup_wizard.dart' show GbpPrefill;

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
///
/// 20.09.2026 GÜNCELLENDİ (kanka isteği) — alanın altına "Google İşletme
/// Profili Kurulum Sihirbazı" eklendi (bkz. gbp_setup_wizard.dart). Kilit
/// kuralı DEĞİŞMEDİ ve sihirbaz için de AYNI: SADECE ücretsiz katmanda
/// kilitli; abonelik ya da özel domain paketi (SiteProject.isPremium) olan
/// projede hem yorum linki alanı hem sihirbaz açık.
///
/// [gbp]: sihirbaza taşınacak işletme bilgilerini (ad, telefon, adres,
/// saatler, kategori) TIKLANDIĞI ANDAKİ güncel form değerleriyle üretir.
/// Verilmezse sihirbaz boş bilgi kartıyla açılır (kullanıcı elle doldurur).
class GoogleReviewLinkField extends StatelessWidget {
  const GoogleReviewLinkField({super.key, required this.controller, this.gbp});

  final TextEditingController controller;
  final GbpPrefill Function()? gbp;

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AppState>().qtCurrentIsPremium;
    final en = isEnglish(context);
    if (!isPremium) {
      return _LockedGoogleReviewField(
        onTap: () => showPremiumLockedPopup(
          context,
          message: en
              ? 'The "Rate us on Google" button and the Google Business Profile Setup Wizard are available with a subscription or a custom-domain package. They are locked on the free plan.'
              : '"Bizi Google\'da Değerlendirin" butonu ve Google İşletme Profili Kurulum Sihirbazı abonelik veya özel domain paketinde açılır. Ücretsiz planda kilitlidir.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: t(context, 'Google Yorum Linki (opsiyonel)'),
            hintText: 'https://g.page/r/.../review',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showGbpSetupWizard(
            context,
            prefill: gbp?.call() ?? const GbpPrefill(),
            reviewController: controller,
          ),
          icon: const Icon(Icons.storefront_rounded, size: 18),
          label: Text(
            en ? 'Google Business Profile Setup Wizard' : 'Google İşletme Profili Kurulum Sihirbazı',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          en
              ? 'We don\'t create your profile — Google does, with your account. The wizard prepares your details, guides you, and connects the review link here.'
              : 'Profili biz açmıyoruz — Google senin hesabınla açar. Sihirbaz bilgilerini hazırlar, yönlendirir ve yorum linkini buraya bağlar.',
          style: const TextStyle(color: Colors.grey, fontSize: 11.5, height: 1.35),
        ),
      ],
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
                    ? 'Google review button + Business Profile Setup Wizard — subscription / custom-domain feature'
                    : 'Google yorum butonu + İşletme Profili Kurulum Sihirbazı — abonelik / domain paketi özelliği',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
