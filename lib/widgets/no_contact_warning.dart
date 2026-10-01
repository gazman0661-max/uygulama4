import 'package:flutter/material.dart';
import 'confirm_popup.dart';

Future<bool> confirmNoContactWay(
  BuildContext context, {
  String? phone,
  String? whatsapp,
  String? instagram,
  String? googleReviewLink,
  required bool includeLeadForm,
}) async {
  bool has(String? v) => v != null && v.trim().isNotEmpty;
  if (has(phone) || has(whatsapp) || has(instagram) || has(googleReviewLink) || includeLeadForm) {
    return true;
  }
  return showConfirmPopup(
    context,
    title: 'İletişim yolu yok',
    message: 'Telefon, WhatsApp, Instagram ve talep formu boş/kapalı. Müşteriler sana ulaşamaz. Yine de devam edilsin mi?',
    icon: '📵',
    confirmLabel: 'Yine de devam',
    cancelLabel: 'Geri dön',
  );
}
