import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

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
    title: '1. Form ile Site Oluşturma',
    description:
        'Formu doldurup \'Oluştur\' butonuna bastığınızda siteniz anında '
        'üretilir. Beğendiğiniz sonuca ulaşana kadar siteyi dilediğiniz '
        'sayıda yeniden oluşturabilirsiniz.',
  ),
  _GuideStep(
    emoji: '💻',
    accent: AppColors.accentOrange,
    title: '2. Önizleme',
    description:
        'Form gönderildiğinde siteniz otomatik olarak önizleme '
        'ekranında açılır. Bu ekranda sitenizin yayınlandığında nasıl '
        'görüneceğini anında inceleyebilirsiniz.',
  ),
  _GuideStep(
    emoji: '🚀',
    accent: AppColors.accentBlue,
    title: '3. Yayınlama',
    description:
        'Önizleme ekranındaki \'YAYINLA\' butonu ile siteniz kendi alt '
        'alan adınızda (veya bağladığınız alan adında) yayına alınır.',
  ),
  _GuideStep(
    emoji: '✏️',
    accent: AppColors.accentGreenLink,
    title: '4. Düzenleme',
    description:
        'Önizleme ekranındaki \'DÜZENLE\' butonuna bastığınızda form, '
        'daha önce girdiğiniz bilgilerle dolu olarak yeniden açılır. '
        'Değişikliklerinizi yaptıktan sonra \'DÜZENLEMEYİ BİTİR\' '
        'butonuna bastığınızda site güncellenir ve önizleme ekranına '
        'dönersiniz.',
  ),
  _GuideStep(
    emoji: '💾',
    accent: AppColors.accentGreenLink,
    title: '5. İndirme ve Kaydetme',
    description:
        '\'İNDİR\' butonuna bastığınızda, sitede rozet bulunuyorsa rozet '
        'kaldırma ve indirme hakkını birlikte sunan tek bir satın alma '
        'seçeneği gösterilir; rozet daha önce kaldırılmışsa yalnızca '
        'indirme hakkı satın alınır. Satın alma sonrasında ilgili proje '
        'sınırsız sayıda indirilebilir; dosya adını ve konumunu '
        'cihazınızın kayıt penceresinden belirlersiniz.',
  ),
  _GuideStep(
    emoji: '🔓',
    accent: AppColors.accentPurple,
    title: '6. Abonelik Paketleri',
    description:
        'Mağaza > Abonelik Planları bölümünden Başlangıç Paket, Mini, '
        'Freelancer veya Freelancer Max paketlerinden birine abone '
        'olduğunuzda, kota dahilindeki sitelerinizde rozet kaldırılır; '
        'Talep Kutusu, harita, talep formu, Google yorum butonu, Google '
        'İşletme Profili Kurulum Sihirbazı, ziyaretçi sayısı ve Search '
        'Console bağlantısı kullanıma açılır. Bu özellikler yalnızca '
        'ücretsiz planda kilitlidir. Her paketin site ve özel alan adı '
        'kotası paket kartında belirtilir; alan adı kotası Mini, '
        'Freelancer ve Freelancer Max paketlerinde bulunur, Başlangıç '
        'Paket alan adı kotası içermez. Site başına sayfa sayısı: '
        'Başlangıç 5, Mini 15, Freelancer ve Freelancer Max sınırsız. '
        'İndirme abonelik kapsamı '
        'dışındadır; hangi pakete sahip olunursa olsun her site için '
        'ayrıca satın alınır (bkz. adım 5).',
  ),
  _GuideStep(
    emoji: '🌐',
    accent: AppColors.accentPurple,
    title: '7. Kendi Domainimi Bağla',
    description:
        'Sahip olduğunuz bir alan adını (domain), Projelerim '
        'ekranındaki 🌐 simgesi aracılığıyla sitenize bağlayabilirsiniz. '
        'Bu işlem alan adı satın alma değildir; mevcut alan adınız '
        'hosting altyapımıza yönlendirilir. Abonelik kotanız varsa '
        'bağlantı kota kapsamındadır, aksi halde site başına 1 yıllık '
        'ayrı bir satın alma yapılır; süre dolduğunda uzatma için '
        'yeniden satın alma gerekir. Bu satın alma hesabınıza ayrıca 1 '
        'ek site yayın hakkı ekler. Alan adı paketi de aynı premium '
        'özellikleri (Google İşletme Profili Kurulum Sihirbazı dahil) '
        'kullanıma açar.',
  ),
  _GuideStep(
    emoji: '📋',
    accent: AppColors.accentBlue,
    title: '8. Proje Kopyalama',
    description:
        'Projelerim ekranından bir siteyi kopyalayarak aynı içeriğe '
        'sahip, yayınlanmamış yeni bir proje oluşturabilirsiniz. Yayın, '
        'alan adı ve satın alma durumları kopyaya aktarılmaz. Bu '
        'özellik, aynı şablonu farklı müşteriler için yeniden kullanmak '
        'isteyen kullanıcılar (ör. freelancer\'lar) için uygundur.',
  ),
  _GuideStep(
    emoji: '🤝',
    accent: AppColors.accentBlue,
    title: '9. Siteyi Devretme',
    description:
        'Bir siteyi (bağlıysa alan adıyla birlikte) \'Siteyi Devret\' '
        'seçeneğiyle başka bir hesaba aktarabilirsiniz. Sistem bir kod '
        'üretir; karşı taraf bu kodu kendi hesabında girerek siteyi '
        'devralır. Bu özellik, müşteri için hazırlanan siteyi iş '
        'tamamlandığında müşterinin hesabına teslim etmek isteyen '
        'kullanıcılar için tasarlanmıştır.',
  ),
  _GuideStep(
    emoji: '📬',
    accent: AppColors.accentGreenLink,
    title: '10. Talep Kutusu ve Bildirimler',
    description:
        'Yayınlanan sitenizdeki iletişim formundan gelen talepler Talep '
        'Kutusu\'na düşer ve anlık bildirim olarak telefonunuza '
        'iletilir. Ziyaretçi formu gönderdiği anda '
        'bilgilendirilirsiniz; siteyi sürekli açık tutmanız gerekmez.',
  ),
  _GuideStep(
    emoji: '📍',
    accent: AppColors.accentGreenLink,
    title: '11. Google İşletme Profili Sihirbazı',
    description:
        'Abonelik veya özel alan adı paketi bulunan sitelerde (ücretsiz '
        'planda kilitlidir) formdaki "Google Yorum Linki" alanının '
        'altında bir sihirbaz açılır. Sihirbaz, Google işletme '
        'profilinizi sizin adınıza oluşturmaz; profil, sizin Google '
        'hesabınızla Google tarafından açılır. Sihirbaz, forma '
        'girdiğiniz bilgilerden kopyalamaya hazır bir bilgi kartı '
        'hazırlar, sizi Google\'ın ücretsiz kayıt ekranına yönlendirir '
        've profilinizin yorum bağlantısını sitenizdeki "Bizi Google\'da '
        'Değerlendirin" butonuna bağlar.',
  ),
  _GuideStep(
    emoji: '🗺️',
    accent: AppColors.accentGreenLink,
    title: '12. Sitenizin Google Tarafından Bulunabilir Olması (Ücretsiz)',
    description:
        'Ücretsiz plan dahil, yayınladığınız her site otomatik olarak '
        'sitemap.xml ve robots.txt dosyalarıyla birlikte gelir. Bu '
        'teknik dosyalar Google\'a sitenizin hangi sayfalardan '
        'oluştuğunu bildirir ve sizden herhangi bir işlem gerektirmeden '
        'kendiliğinden çalışır. Sayfa ekleyip siteyi yeniden '
        'yayınladığınızda dosyalar da otomatik olarak güncellenir.',
  ),
  _GuideStep(
    emoji: '✅',
    accent: AppColors.accentPurple,
    title: '13. Google Search Console Bağlantısı',
    description:
        'Abonelik veya özel alan adı paketi bulunan sitelerde (ücretsiz '
        'planda kilitlidir), Google\'ın verdiği doğrulama kodunu girerek '
        'sitenin sahibi olduğunuzu Google\'a doğrulayabilirsiniz. Bu '
        'adım sitenin Google\'da yer alması için zorunlu değildir '
        '(sitemap yeterlidir); ancak Google Search Console panelinden '
        'sitenizin hangi aramalarda göründüğünü izlemenize ve yeni '
        'sayfaların daha hızlı taranmasını doğrudan Google\'dan talep '
        'etmenize olanak tanır. Kod kaydedildikten sonra siteyi yeniden '
        'yayınlamanız gerekmez; birkaç dakika içinde otomatik olarak '
        'devreye girer. Uygulama adımları: Projelerim ekranında '
        'yayındaki sitenin kartında yer alan "Search Console" butonuna '
        'basın, Google\'ın verdiği kodu yapıştırın ve kaydedin.',
  ),
  _GuideStep(
    emoji: '🖼️',
    accent: AppColors.accentOrange,
    title: '14. Fotoğraf ve Boyut Sınırları',
    description:
        'Galeri bölümüne en fazla 12 fotoğraf eklenebilir. Fotoğraflar '
        'sayfanın içine gömüldüğü için yayınlama sırasında dosya boyutu '
        'sınırları uygulanır: bir sayfa dosyası (ör. ana sayfa) en '
        'fazla 8 MB, sitenin tüm dosyalarının toplamı ise en fazla 40 '
        'MB olabilir. Bu sınırlar tüm planlar için geçerlidir. Eklenen '
        'görseller otomatik olarak sıkıştırılır ve galerinin altında '
        'toplam boyut görüntülenir. Sınırların aşılması halinde '
        'yayınlama tamamlanmaz; bu durumda fotoğraf sayısını azaltmanız '
        'veya daha küçük boyutlu görseller kullanmanız gerekmektedir.',
  ),
];

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
