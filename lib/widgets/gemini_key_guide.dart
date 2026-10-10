import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_strings.dart';

/// 06.10.2026 eklendi — "Gemini API anahtarı nasıl alınır?" rehberi.
///
/// Üç yerde AYNI içerik kullanılır: AI ayarları ekranı ([GeminiKeyGuideCard]),
/// Kılavuz (guide_dialog.dart, 14. adım) ve SSS. Anahtar sayfasının adresi tek yerde
/// ([kGeminiKeyUrl]); Google adresi değiştirirse sadece burayı güncelle.
///
/// Anahtar, kullanıcının KENDİ Google hesabıyla Google AI Studio'da oluşturulur;
/// Sitora anahtarı sunucuya göndermez (bkz. AiKeyStore).
const String kGeminiKeyUrl = 'https://aistudio.google.com/apikey';

/// Anahtar sayfasını tarayıcıda açar. Açılamazsa adresi panoya kopyalar.
Future<void> openGeminiKeyPage(BuildContext context) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(kGeminiKeyUrl), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (ok || !context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: kGeminiKeyUrl));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(t(context, 'Sayfa açılamadı. Adres panoya kopyalandı, tarayıcına yapıştır.'))),
  );
}

/// Adımlar (sade Türkçe; menü adları Google'ın arayüzündeki İngilizce hâliyle yazılır).
const List<String> _steps = [
  'Aşağıdaki düğmeye bas. Google AI Studio sayfası açılır.',
  'Google hesabınla giriş yap. İstenirse kullanım şartlarını kabul et.',
  '\"Create API key\" (API anahtarı oluştur) düğmesine bas. Proje sorarsa mevcut bir proje seç ya da yeni oluştur.',
  'Oluşan anahtarı kopyala. \"AIza\" ile başlayan uzun bir yazıdır.',
  'Sitora\'ya dön ve anahtarı aşağıdaki alana yapıştır. Kendiliğinden doğrulanır.',
];

class GeminiKeyGuideCard extends StatelessWidget {
  const GeminiKeyGuideCard({super.key, this.showTitle = true});
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (showTitle) ...[
          Row(children: [
            Icon(Icons.vpn_key_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t(context, 'API anahtarını nasıl alırım?'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: Text('${i + 1}', style: TextStyle(color: cs.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(t(context, _steps[i]), style: const TextStyle(fontSize: 13, height: 1.4))),
            ]),
          ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: () => openGeminiKeyPage(context),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(t(context, 'Anahtar alma sayfasını aç')),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t(context,
              'Bilmen gerekenler: Anahtar ücretsizdir; Google\'ın ücretsiz kotası çoğu site için yeterlidir (güncel limitleri Google\'ın sayfasından kontrol et). '
              'Anahtarı kimseyle paylaşma ve internette yayınlama; Sitora onu yalnızca bu cihazda saklar. '
              'Oluşturamıyorsan: kullanım şartlarını kabul etmemiş olabilirsin, ya da okul/iş hesabı kullanıyorsundur. Kişisel Google hesabınla dene.'),
          style: TextStyle(fontSize: 12, height: 1.4, color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}

/// Anahtar girilmişken (kart gizlendiğinde) rehberi alttan açılan pencerede göstermek için.
Future<void> showGeminiKeyGuideSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: const GeminiKeyGuideCard(),
      ),
    ),
  );
}
