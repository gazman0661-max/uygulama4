import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// Ekran görüntülerindeki "Sitora Kullanım Kılavuzu" popup'ının birebir
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
    emoji: '⭐',
    accent: AppColors.accentOrange,
    title: '1. Form ile Site Oluştur',
    description:
        'Formu doldurup \'Oluştur\'a bastığınızda siteniz anında üretilir — '
        'istediğiniz kadar deneyip beğendiğiniz sonuca ulaşana kadar '
        'tekrar tekrar oluşturabilirsiniz.',
  ),
  _GuideStep(
    emoji: '💻',
    accent: AppColors.accentOrange,
    title: '2. Önizleme',
    description:
        'Form gönderildiğinde siteniz otomatik olarak önizleme ekranında '
        'açılır; burada nasıl görüneceğini anında test edebilirsiniz.',
  ),
  _GuideStep(
    emoji: '🚀',
    accent: AppColors.accentBlue,
    title: '3. Yayınlama',
    description:
        'Önizleme ekranındaki \'YAYINLA\' butonuyla siteniz kendi alt alan '
        'adınızda (veya bağladığınız domainde) canlıya alınır.',
  ),
  _GuideStep(
    emoji: '✏️',
    accent: AppColors.accentGreenLink,
    title: '4. Düzenleme',
    description:
        'Önizleme ekranındaki \'DÜZENLE\' butonuyla formunuz, daha önce '
        'girdiğiniz bilgilerle DOLU şekilde tekrar açılır. Değişikliklerinizi '
        'yapıp \'DÜZENLEMEYİ BİTİR\'e bastığınızda site güncellenir ve '
        'önizlemeye dönersiniz.',
  ),
  _GuideStep(
    emoji: '💾',
    accent: AppColors.accentGreenLink,
    title: '5. İndirme & Kaydetme',
    description:
        '\'İNDİR\' butonuna bastığınızda, site rozetliyse önce rozet '
        'kaldırma + indirme hakkını birlikte veren bir satın alma '
        'sunulur; rozet zaten kalkmışsa doğrudan indirme satın alınır. '
        'Satın alındıktan sonra o proje sınırsız tekrar indirilebilir; '
        'cihazınızın kayıt penceresinden dosya adını ve konumu siz '
        'seçersiniz.',
  ),
  // 17.09.2026 güncellendi (kanka isteği) — kılavuz artık güncel ürün
  // yapısını (tek seferlik "1 Aylık Mini Paket" KALDIRILDI, yerini
  // abonelik paketleri aldı) yansıtıyor.
  _GuideStep(
    emoji: '🔓',
    accent: AppColors.accentPurple,
    title: '6. Abonelik Paketleri',
    description:
        'Mağaza > Abonelik Planları\'ndan Mini/Freelancer/Freelancer Max '
        'paketlerinden birine abone olarak kota dahilindeki sitelerinizde '
        'rozeti kaldırabilir, Talep Kutusu, tam galeri, harita, talep '
        'formu, Google yorum butonu ve ziyaretçi sayısını açabilirsiniz. '
        'Her paketin kaç site ve kaç özel domain kotası verdiği paket '
        'kartında yazar. İndirme bu paketlerin dışındadır — hangi '
        'pakete/aboneliğe sahip olunursa olsun her zaman site başına '
        'ayrı satılan bir kilittir (bkz. adım 5).',
  ),
  _GuideStep(
    emoji: '🌐',
    accent: AppColors.accentPurple,
    title: '7. Kendi Domainimi Bağla',
    description:
        'Zaten sahip olduğunuz bir alan adını (domain'
        ') Projelerim\'deki 🌐 ikonuyla sitenize bağlayabilirsiniz — bu, '
        'domain satın almak DEĞİL, elinizdeki domaini hosting\'imize '
        'yönlendirmektir. Abonelik kotanız varsa dahildir, yoksa site '
        'başına 1 yıllık ayrı satın alınır; süre dolunca uzatmak '
        'yeniden satın alma gerektirir.',
  ),
  _GuideStep(
    emoji: '📋',
    accent: AppColors.accentBlue,
    title: '8. Proje Kopyalama',
    description:
        'Bir siteyi Projelerim\'den kopyalayarak aynı içerikle sıfırdan '
        'yeni, yayınlanmamış bir proje oluşturabilirsiniz — yayın, '
        'domain ve satın alma durumları kopyaya taşınmaz. Aynı şablonu '
        'farklı müşterileriniz için tekrar tekrar kullanmak isteyenler '
        '(ör. freelancer\'lar) için pratiktir.',
  ),
  _GuideStep(
    emoji: '🤝',
    accent: AppColors.accentBlue,
    title: '9. Siteyi Devretme',
    description:
        'Bir siteyi (bağlıysa domaini dahil) \'Siteyi Devret\'le başka '
        'bir hesaba aktarabilirsiniz — sistem bir kod üretir, karşı '
        'taraf bu kodu kendi hesabında girerek siteyi devralır. Bir '
        'siteyi müşteriniz için kurup işi bitince kendi hesabına teslim '
        'etmek isteyenler için düşünülmüştür.',
  ),
  _GuideStep(
    emoji: '📬',
    accent: AppColors.accentGreenLink,
    title: '10. Talep Kutusu & Bildirimler',
    description:
        'Yayınlanan sitenizdeki iletişim formundan gelen talepler '
        'Talep Kutusu\'na düşer ve anlık bildirim olarak telefonunuza '
        'gelir — ziyaretçi formu doldurduğu anda haberiniz olur, siteyi '
        'sürekli açık tutmanız gerekmez.',
  ),
];

/// 18.09.2026 eklendi (kanka isteği) — kılavuzun EN ÜSTÜNDE, adım
/// kartlarından ayrı, dikkat çekici bir uyarı kutusu: ücretsiz planda
/// yayınlanan bir sitenin 6 ay güncellenmezse (tekrar yayınlanmazsa)
/// otomatik yayından kalkacağı bilgisi. Bilerek numaralı bir "adım" olarak
/// DEĞİL, ayrı/sabit (ListView'in dışında, kaydırılmayan) bir banner olarak
/// eklendi — hem her zaman ilk görülen şey olsun hem de "nasıl yapılır"
/// adımlarıyla karışıp sıradan bir madde gibi atlanmasın diye.
///
/// Kartta gösterilen kalan süre sayacı için bkz.
/// [SiteProject.freeTierPublishExpiresAt] ve projects_screen.dart
/// > _ProjectCard'daki "Ücretsiz Yayın" satırı.
class _GuideWarningBanner extends StatelessWidget {
  const _GuideWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentOrange.withOpacity(0.5), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t(
                  context,
                  'Ücretsiz planda yayınlanan siteler 6 ay boyunca güncellenmezse '
                  '(tekrar yayınlanmazsa) otomatik olarak yayından kaldırılır. '
                  'Sitenizin yayında kalması için süresi dolmadan Projelerim '
                  'kısmından siteyi açıp tekrar yayınlayın.',
                ),
                style: const TextStyle(
                  color: AppColors.accentOrange,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            const _GuideWarningBanner(),
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
              t(context, 'Sitora Kullanım Kılavuzu'),
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
