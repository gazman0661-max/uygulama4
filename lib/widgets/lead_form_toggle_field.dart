import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../state/app_state.dart';
import 'premium_locked_popup.dart';

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
