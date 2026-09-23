import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../state/app_state.dart';
import 'premium_locked_popup.dart';

/// 05.09.2026 eklendi — kanka isteği (talep formu kilidi: harita/galeri ile
/// AYNI "girişte kilitli" kalıp).
///
/// [LocationPickerField]'dan YÖN FARKI: talep formunun (leadFormMarkup)
/// kullanıcının doldurduğu bir GİRİŞ ALANI yok — generator zaten her zaman
/// `includeLeadForm: true` varsayımıyla üretiyordu, kullanıcı bunu hiç
/// görmüyor/kontrol edemiyordu. Bu widget iki şeyi BİRDEN çözüyor:
/// 1) Free plan'da (bkz. AppState.qtCurrentIsPremium) harita/galeri ile
///    BİREBİR aynı kilitli placeholder — dokununca [showPremiumLockedPopup].
///    Üretim anındaki asıl kilit zaten
///    FreePlanRestrictionService.isPremiumGeneration'da var (bu widget
///    sadece o kilidi kullanıcıya GÖRÜNÜR kılıyor); yani free kullanıcı
///    switch'i "açık" bıraksa bile üretilen sitede form yine çıkmaz.
/// 2) Premium (domain bağlı proje) kullanıcıya artık gerçek bir seçenek
///    sunuyor: sitesine talep formu ekleyip eklememeyi kendisi seçebiliyor
///    (varsayılan açık — geriye dönük davranışla aynı).
///
/// Kullanım: her form ekranında [value]/[onChanged] ile `_includeLeadForm`
/// state'ine bağlanır, `_captureFormData`/`_restoreFromInitialData`'ya
/// eklenir ve generator çağrısına `includeLeadForm: _includeLeadForm`
/// olarak geçirilir (bkz. kuafor_form_screen.dart).
class LeadFormToggleField extends StatelessWidget {
  const LeadFormToggleField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AppState>().qtCurrentIsPremium;
    if (!isPremium) {
      return _LockedLeadFormField(
        onTap: () => showPremiumLockedPopup(
          context,
          message: isEnglish(context)
              ? 'Adding a request form for visitors to your site is available with a subscription or a custom-domain package (locked on the free plan).'
              : 'Ziyaretçilerin doldurabileceği talep formunu sitene eklemek abonelik veya özel domain paketinde açılır (ücretsiz planda kilitli).',
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: Text(t(context, 'Talep Formu'), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isEnglish(context)
              ? 'Let visitors send requests through a form on your site.'
              : 'Ziyaretçiler sitendeki formdan sana talep gönderebilsin.',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

/// Free plan'da [LeadFormToggleField] yerine gösterilen kilitli placeholder
/// — bkz. widgets/location_picker_field.dart > _LockedLocationField (AYNI
/// görsel kalıp).
class _LockedLeadFormField extends StatelessWidget {
  const _LockedLeadFormField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'Talep Formu'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
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
                        ? 'Request form — Premium plan feature'
                        : 'Talep formu — Premium plan özelliği',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
