import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// 28.09.2026 eklendi (kanka isteği) — Güven Şeridi artık AÇIK/KAPALI
/// seçilebiliyor. Önceden hero'nun hemen altına her sitede kayıtsız
/// şartsız ekleniyordu (bkz. shared_html_blocks.dart > trustBarBlockHtml
/// dokümanı); artık [LeadFormToggleField] ile AYNI kalıp — sadece bu
/// premium kilitli DEĞİL (herkes serbestçe açıp kapatabilir, çeşitlilik
/// için).
///
/// Kullanım: her form ekranında `_showTrustBar` state'ine bağlanır,
/// capture/restore'a eklenir ve generator çağrısına
/// `showTrustBar: _showTrustBar` olarak geçirilir (bkz.
/// kuafor_form_screen.dart).
class TrustBarToggleField extends StatelessWidget {
  const TrustBarToggleField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
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
        title: Text(t(context, 'Güven Şeridi'), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isEnglish(context)
              ? 'Show a thin trust bar (services/photos/reviews) right under the hero.'
              : 'Hero\'nun hemen altında hizmet/fotoğraf/yorum sayısını gösteren ince bir şerit ekle.',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
