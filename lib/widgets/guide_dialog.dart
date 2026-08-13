import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// Ekran görüntülerindeki "Sitora AI Kullanım Kılavuzu" popup'ının birebir
/// Flutter karşılığı: üstte ikon+başlık+kapat (X), altında kaydırılabilir
/// adım kartları (ikon kutusu + başlık + açıklama), en altta "Kapat" butonu.
///
/// Ana panelin "📖 Kılavuz" butonuna bağlanır.
class _GuideStep {
  final String emoji;
  final Color accent;
  final String title;
  final String description;

  const _GuideStep({
    required this.emoji,
    required this.accent,
    required this.title,
    required this.description,
  });
}

const List<_GuideStep> _guideSteps = [
  _GuideStep(
    emoji: '⚙️',
    accent: AppColors.accentBlue,
    title: '1. API Key Kurulumu (opsiyonel)',
    description:
        'Kendi Gemini API anahtarınızı girmek isterseniz sağ üstteki Ayarlar '
        '(⚙️) simgesine dokunun, sağlayıcıyı seçip linkten ücretsiz API Key '
        'alıp yapıştırın. Anahtar girerseniz kullanımınız sınırsız olur.',
  ),
  _GuideStep(
    emoji: '⭐',
    accent: AppColors.accentOrange,
    title: '2. Günlük Ücretsiz Puanlar',
    description:
        'API anahtarı girmeseniz de her gün ücretsiz 15 puanla başlarsınız. '
        'Puanlarınız her gün UTC 00:00\'da 15\'e YENİLENİR (biriktirmez, gün '
        'içinde kullanmazsanız ertesi güne taşınmaz). 1 site oluşturma 5 '
        'puan, her AI düzenlemesi (tam kod, bölüm veya arkaplan) 2 puan '
        'düşer. Puanınız biterse kendi API anahtarınızı girip sınırsız devam '
        'edebilirsiniz.',
  ),
  _GuideStep(
    emoji: '💬',
    accent: AppColors.accentCyan,
    title: '3. Sitenizi Hayal Edin',
    description:
        'Yapay zekaya nasıl bir site istediğinizi anlatın. Dilerseniz '
        'galeriden görseller ekleyerek tasarıma dahil edebilirsiniz.',
  ),
  _GuideStep(
    emoji: '💻',
    accent: AppColors.accentOrange,
    title: '4. Düzenleme & Önizleme',
    description:
        'Üretilen sitenin kodunu \'DÜZENLE\' butonuyla canlı CodeMirror '
        'editöründe değiştirebilir veya \'ÖN İZLEME\' ile anında test '
        'edebilirsiniz.',
  ),
  _GuideStep(
    emoji: '🧱',
    accent: AppColors.accentRed,
    title: '5. Builder Pro (Sürükle-Bırak)',
    description:
        'Üstteki tablardan \'BUILDER PRO\'ya geçerek; şablonlar, hazır '
        'bölümler, akıllı neon/glass CTA butonlar ve geometrik şekiller '
        'ekleyip sürükleyerek görsel tasarım yapın.',
  ),
  _GuideStep(
    emoji: '📐',
    accent: AppColors.accentPurple,
    title: '6. Özelleştirilebilir Şekiller',
    description:
        'Kare, daire, üçgen, yıldız, ampul, bulut veya kendi çizdiğiniz '
        'şekilleri ekleyin! İçine URL/Galeri görseli yerleştirin ve '
        'gidilecek linkleri ayarlayın.',
  ),
  _GuideStep(
    emoji: '💾',
    accent: AppColors.accentGreenLink,
    title: '7. İndirme & Kaydetme',
    description:
        '\'İNDİR\' butonuna bastığınızda cihazınızın kayıt penceresi '
        'açılır; dosya adını değiştirebilir ve kaydedilecek konumu '
        'kendiniz seçebilirsiniz.',
  ),
];

Future<void> showGuideDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFF141821),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentBlue.withOpacity(0.55), width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GuideHeader(onClose: () => Navigator.of(ctx).pop()),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                itemCount: _guideSteps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _GuideStepCard(step: _guideSteps[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    t(ctx, 'Kapat'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuideHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _GuideHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        children: [
          const Text('📖', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(context, 'Sitora AI Kullanım Kılavuzu'),
              style: const TextStyle(
                color: AppColors.accentBlue,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, color: Colors.white70, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  final _GuideStep step;
  const _GuideStepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: step.accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(step.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, step.title),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(context, step.description),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
