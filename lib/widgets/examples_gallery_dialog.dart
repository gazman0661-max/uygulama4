import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// "Örnekler" galerisi: boş sohbet kutusuna bakıp "ne yazsam" diye
/// düşünen kullanıcı için hazır, sektör bazlı örnek prompt'lar.
/// Karta dokunununca metin AI Chat kutusuna yazılır (otomatik gönderilmez,
/// kullanıcı isterse düzenleyip kendi göndersin — puanı boşuna harcamasın).
class _ExampleItem {
  final String emoji;
  final Color accent;
  final String title;
  final String prompt;

  const _ExampleItem({
    required this.emoji,
    required this.accent,
    required this.title,
    required this.prompt,
  });
}

const List<_ExampleItem> _examples = [
  _ExampleItem(
    emoji: '☕',
    accent: AppColors.accentOrange,
    title: 'Kafe / Kahveci',
    prompt:
        'Kadıköy\'de sıcak, samimi bir üçüncü nesil kahveci için tek sayfalık bir '
        'web sitesi oluştur. Menü bölümü (filtre kahve, espresso bazlı içecekler, '
        'tatlılar), açılış saatleri, konum ve Instagram linki olsun. Sıcak, kahverengi '
        've krem tonlarında, ahşap dokulu bir tasarım istiyorum.',
  ),
  _ExampleItem(
    emoji: '💇',
    accent: AppColors.accentCyan,
    title: 'Kuaför / Berber',
    prompt:
        'Erkek berber salonu için modern, koyu temalı (siyah-altın) bir tek sayfa site '
        'yap. Hizmetler ve fiyat listesi (saç kesimi, sakal tıraşı, cilt bakımı), '
        'WhatsApp\'tan randevu butonu, önce-sonra galeri bölümü olsun.',
  ),
  _ExampleItem(
    emoji: '🏋️',
    accent: AppColors.accentGreenLink,
    title: 'Spor Salonu',
    prompt:
        'Enerjik, motivasyon veren bir fitness/spor salonu web sitesi oluştur. '
        'Üyelik paketleri (aylık/yıllık), eğitmen kadrosu, salon fotoğraf galerisi '
        've "Ücretsiz Deneme Dersi" için WhatsApp CTA butonu olsun. Kırmızı-siyah, '
        'güçlü kontrastlı bir tasarım istiyorum.',
  ),
  _ExampleItem(
    emoji: '🏠',
    accent: AppColors.accentBlue,
    title: 'Emlak Danışmanı',
    prompt:
        'Bireysel bir emlak danışmanı için güven veren, kurumsal bir tanıtım sitesi '
        'yap. Hakkımda bölümü, hizmet verdiğim bölgeler, iletişim ve WhatsApp\'tan '
        'hızlı ulaşım butonu olsun. Lacivert-beyaz, sade ve profesyonel bir tasarım.',
  ),
  _ExampleItem(
    emoji: '🎨',
    accent: AppColors.accentOrange,
    title: 'Portföy / Serbest Çalışan',
    prompt:
        'Bir grafik tasarımcının kişisel portföy sitesini oluştur. Kısa bir hakkımda '
        'yazısı, öne çıkan proje kartları (görsel + başlık), kullandığım yazılımlar '
        've iletişim bölümü olsun. Minimal, beyaz zeminli, tipografi odaklı bir tasarım.',
  ),
  _ExampleItem(
    emoji: '🍽️',
    accent: AppColors.accentCyan,
    title: 'Restoran',
    prompt:
        'Aile işletmesi bir restoran için sıcak ve davetkar bir web sitesi oluştur. '
        'Kategorilere ayrılmış menü (başlangıçlar, ana yemekler, tatlılar, içecekler), '
        'rezervasyon için telefon/WhatsApp butonu ve konum haritası olsun.',
  ),
];

Future<void> showExamplesGalleryDialog(
  BuildContext context, {
  required void Function(String prompt) onPick,
}) {
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
          border: Border.all(color: AppColors.accentOrange.withOpacity(0.55), width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExamplesHeader(onClose: () => Navigator.of(ctx).pop()),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                itemCount: _examples.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _ExampleCard(
                  item: _examples[i],
                  onTap: () {
                    onPick(_examples[i].prompt);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                t(ctx, 'Bir örneğe dokunun, sohbet kutusuna yazılsın — dilerseniz '
                    'göndermeden önce düzenleyebilirsiniz.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExamplesHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _ExamplesHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        children: [
          const Text('🎨', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(context, 'Örnekler'),
              style: const TextStyle(
                color: AppColors.accentOrange,
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

class _ExampleCard extends StatelessWidget {
  final _ExampleItem item;
  final VoidCallback onTap;
  const _ExampleCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
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
                color: item.accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(item.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, item.title),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t(context, item.prompt),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
