import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/gemini_key_guide.dart';

/// ============================================================================
/// Sık Sorulan Sorular ekranı. 06.09.2026 eklendi (kanka isteği — "tek
/// başımayım, destek talepleri artarsa yetişemem").
///
/// BİLEREK AI/chatbot DEĞİL: sabit soru-cevap listesi, hiçbir API çağrısı
/// yapmaz, maliyeti yoktur. Amaç en sık gelen destek sorularını kullanıcı
/// mesaj atmadan ÖNCE burada cevaplamak. Yeni bir soru sık gelmeye başlarsa
/// buraya yeni bir [_FaqItem] eklemek yeterli — kod değişikliği gerektirmez,
/// sadece bu dosyadaki liste güncellenir.
/// ============================================================================
class _FaqItem {
  final String question;
  final String answer;
  // true ise cevabın altında "Anahtar alma sayfasını aç" düğmesi çıkar.
  final bool geminiKeyLink;
  const _FaqItem(this.question, this.answer, {this.geminiKeyLink = false});
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static List<_FaqItem> _items(BuildContext context) => [
        _FaqItem(
          t(context, 'Domainimi bağladım ama site açılmıyor, neden?'),
          t(
            context,
            'En sık sebep: domaini yeni aldıysan, kayıt firmasının sana attığı "e-posta doğrulama" mailini onaylamamış olabilirsin — onaylanmadan domain askıda kalır, CNAME doğru olsa bile çalışmaz. Ayrıca DNS kaydının yayılması bazı sağlayıcılarda 24 saate kadar sürebilir, hemen açılmaması normal olabilir.',
          ),
        ),
        _FaqItem(
          t(context, 'CNAME kaydını nereye ekleyeceğimi bulamıyorum'),
          t(
            context,
            'Domain bağlama ekranındaki "Domainin nereden alındı? Adım adım göster" bölümünü aç — Natro, İsimtescil, Turhost, GoDaddy ve Namecheap için ayrı ayrı adımlar ve o firmanın resmi yardım sayfasına giden bir link var.',
          ),
        ),
        _FaqItem(
          t(context, '"MySitora ile üretildi" rozeti neden geri geldi?'),
          t(
            context,
            'Rozeti domain bağlayarak kaldırdıysan, bu kaldırma o satın almanın SÜRESİNE bağlıdır — süre dolup yenilenmezse rozet otomatik geri gelir.',
          ),
        ),
        _FaqItem(
          t(context, 'Domain süresi dolunca ne oluyor?'),
          t(
            context,
            'Süre dolduğunda site otomatik olarak ücretsiz katmana iner: fazla sayfalar kaldırılır, harita/talep formu gibi premium özellikler kapanır ve rozet geri gelir. Bunun için uygulamayı açmana gerek yok, sunucu tarafında günlük olarak otomatik kontrol edilir.',
          ),
        ),
        _FaqItem(
          t(context, 'Satın alma yaptım ama özellik açılmadı'),
          t(
            context,
            'Önce Play Store\'daki satın alma geçmişinden ödemenin gerçekten tamamlandığını kontrol et. Tamamlandıysa uygulamayı tamamen kapatıp yeniden aç — bazen satın alma onayı birkaç dakika gecikebilir.',
          ),
        ),
        _FaqItem(
          t(context, 'Domainimi yanlış girdim, düzeltebilir miyim?'),
          t(
            context,
            'Domain bağlama tek seferlik bir satın almadır ve bir domaine bağlanır. Yanlış girdiysen destek ile iletişime geçmen gerekir, kendi başına değiştiremezsin.',
          ),
        ),
        _FaqItem(
          t(context, 'Domain otomatik yenileniyor mu, tekrar ücret keser mi?'),
          t(
            context,
            'Hayır. Tek seferlik satın almadır, otomatik yenilenen bir abonelik DEĞİLDİR. Süre dolduğunda kendiliğinden yenilenmez ve tekrar ücret kesmez — uzatmak istersen tekrar senin satın alman gerekir.',
          ),
        ),
        _FaqItem(
          t(context, 'Yapay zekâ için API anahtarını nasıl alırım?'),
          t(
            context,
            'Yapay zekâ özellikleri kendi Google Gemini anahtarınla çalışır ve ücretsizdir. 1) Aşağıdaki düğmeyle Google AI Studio sayfasını aç, Google hesabınla giriş yap. 2) \"Create API key\" (API anahtarı oluştur) düğmesine bas; proje sorarsa mevcut birini seç ya da yeni oluştur. 3) \"AIza\" ile başlayan anahtarı kopyala. 4) Sitora\'da yapay zekâ ayarlarına gidip anahtarı yapıştır; kendiliğinden doğrulanır. Anahtarı kimseyle paylaşma; yalnızca bu cihazda saklanır.',
          ),
          geminiKeyLink: true,
        ),
        _FaqItem(
          t(context, 'Yayınladığım site kaç dilde olabilir?'),
          t(
            context,
            'Siteyi yayınladığın anda o anki uygulama dilinde (Türkçe veya İngilizce) yayınlanır. Dili değiştirip tekrar yayınlarsan yeni dilde güncellenir.',
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDark;
    context.watch<LocaleController>();
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkBubbleBg : AppColors.lightBubbleBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(0.55);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
        title: Text(
          t(context, 'Sık Sorulan Sorular'),
          style: TextStyle(
            color: titleColor,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items(context).length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final item = _items(context)[i];
            return Container(
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  iconColor: subtleColor,
                  collapsedIconColor: subtleColor,
                  title: Text(
                    item.question,
                    style: TextStyle(
                      color: titleColor,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.answer,
                        style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12, height: 1.5),
                      ),
                    ),
                    if (item.geminiKeyLink)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: OutlinedButton.icon(
                            onPressed: () => openGeminiKeyPage(context),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(t(context, 'Anahtar alma sayfasını aç')),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
