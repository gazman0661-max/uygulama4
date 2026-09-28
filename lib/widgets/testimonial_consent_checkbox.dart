import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// ============================================================================
/// MÜŞTERİ YORUMLARI — GERÇEKLİK ONAYI. 26.09.2026 eklendi (kanka kararı).
/// ============================================================================
/// AMAÇ: "Müşteri Yorumları" alanı MANUEL — işletme sahibi elle
/// istediğini yazabilir. Bu widget o riski ortadan KALDIRMIYOR (kaldıramaz,
/// hiçbir platform kaldıramaz) ama sorumluluğu AÇIKÇA ve EYLEMLE (aktif
/// tıklama) işletme sahibine yüklüyor — tıpkı legal_consent_popup.dart'taki
/// "okudum, kabul ediyorum" kalıbı gibi, sadece inline ve tek alana özel.
///
/// KULLANIM: her formda Müşteri Yorumları TextField'ının hemen altına:
///   TestimonialConsentCheckbox(
///     value: _testimonialsConsent,
///     onChanged: (v) => setState(() => _testimonialsConsent = v),
///   )
///
/// ZORUNLULUK: yorum metni DOLUYKEN checkbox işaretli değilse _generate()
/// üretimi durdurup kullanıcıyı uyarır (bkz. her form ekranındaki
/// _generate() başındaki kontrol) — sessizce yorumları atmak yerine kasıtlı
/// olarak durdurup soruyoruz, kullanıcı ne olduğunu anlasın istiyoruz.
class TestimonialConsentCheckbox extends StatelessWidget {
  const TestimonialConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.scale(
              scale: 0.9,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  t(context, 'Girdiğim yorumların gerçek müşterilerime ait olduğunu onaylıyorum.'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
