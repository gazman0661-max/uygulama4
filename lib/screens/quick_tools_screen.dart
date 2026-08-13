import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/language_picker_popup.dart';
import '../widgets/legal_consent_popup.dart';
import '../localization/locale_controller.dart';
import 'home_screen.dart';
import 'qr_generator_screen.dart';
import 'bio_link_form_screen.dart';
import 'business_card_form_screen.dart';
import 'kuafor_form_screen.dart';
import 'kafe_form_screen.dart';
import 'beauty_salon_form_screen.dart';
import 'clinic_form_screen.dart';
import 'fitness_form_screen.dart';
import 'car_wash_form_screen.dart';
import 'real_estate_form_screen.dart';
import 'portfolio_form_screen.dart';

/// UYGULAMANIN YENİ ANA EKRANI (bkz. splash_screen.dart). Kullanıcı önce
/// hangi site türünü istediğini seçiyor; AI sohbet akışı (home_screen.dart)
/// artık buradan açılan, ayrı ve ileride PRO/ücretli olarak sunulabilecek
/// bir kısayol — en üstteki [_AiChatCard] bunu açar.
///
/// QR Kod, eski AI/Worker akışını kullandığı için diğer üretim
/// akışlarıyla aynı günlük ücretsiz puan kotasından düşer
/// (AppState.costGenerateSite / kendi API anahtarı olan kullanıcı için
/// sınırsız). Aşağıdaki sektörel site kartları (kafe, kuaför, ...) ise
/// LocalGenerationHelper üzerinden tamamen yerel/şablon tabanlı üretim
/// yapar — AI çağrısı ve kota tüketimi YOKTUR.
class QuickToolsScreen extends StatefulWidget {
  const QuickToolsScreen({super.key});

  @override
  State<QuickToolsScreen> createState() => _QuickToolsScreenState();
}

class _QuickToolsScreenState extends State<QuickToolsScreen> {
  static const _legalConsentPrefsKey = 'legal_terms_accepted_v1';

  @override
  void initState() {
    super.initState();
    // TAŞINDI (home_screen.dart'tan): Hızlı Araçlar artık splash'tan
    // sonra açılan ANA EKRAN olduğu için, uygulama ilk kez açıldığında
    // gösterilmesi gereken zorunlu dil seçimi ve KVKK/Kullanım Şartları
    // onay popup'ları buradan tetikleniyor.
    _maybeShowLanguagePicker();
  }

  /// Uygulama daha önce hiç dil seçilmediyse (ilk açılış), kullanıcı bir
  /// dil seçene kadar ekranda kalan kapatılamaz bir popup gösterir.
  Future<void> _maybeShowLanguagePicker() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final locale = Provider.of<LocaleController>(context, listen: false);
      // SharedPreferences'tan okuma henüz bitmediyse bir sonraki frame'i bekle.
      while (!locale.isLoaded) {
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted) return;
      }
      if (!locale.hasChosenLanguage && mounted) {
        await showLanguagePickerPopup(context);
      }
      await _maybeShowLegalConsent();
    });
  }

  /// Gizlilik Politikası / Kullanım Şartları daha önce onaylanmadıysa
  /// (ilk açılış), kullanıcı onaylayana kadar ekranda kalan, dışarı
  /// tıklayınca kapanmayan bir popup gösterir.
  Future<void> _maybeShowLegalConsent() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyAccepted = prefs.getBool(_legalConsentPrefsKey) ?? false;
    if (alreadyAccepted || !mounted) return;
    final accepted = await showLegalConsentPopup(context);
    if (accepted) {
      await prefs.setBool(_legalConsentPrefsKey, true);
    } else if (mounted) {
      // Kullanıcı kabul etmeden bir şekilde kapatırsa tekrar sor.
      await _maybeShowLegalConsent();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sitora AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AiChatCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          const SizedBox(height: 20),
          _ToolCard(
            emoji: '🔳',
            title: 'QR Kod Oluştur',
            subtitle: 'Bağlantı, wifi veya metin için QR kod üret (site oluşturmayla aynı puan kotasından düşer).',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrGeneratorScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🔗',
            title: 'Biyo Link Sayfası',
            subtitle: 'Instagram/TikTok bio\'na koyacağın, tüm bağlantılarını tek sayfada toplayan mini site.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BioLinkFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🪪',
            title: 'Dijital Kartvizit',
            subtitle: 'İsim, unvan, iletişim ve sosyal linklerinle şık bir dijital kartvizit sayfası.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BusinessCardFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '☕',
            title: 'Kafe / Restoran Sitesi',
            subtitle: 'Menü, çalışma saatleri ve konumuyla hazır bir kafe/restoran sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KafeFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '💈',
            title: 'Kuaför / Berber Sitesi',
            subtitle: 'Hizmetler, galeri ve randevu bilgileriyle kuaför/berber sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KuaforFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '💅',
            title: 'Güzellik Salonu Sitesi',
            subtitle: 'Öncesi/sonrası galerisiyle güzellik salonu tanıtım sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BeautySalonFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🏥',
            title: 'Klinik / Sağlık Sitesi',
            subtitle: 'Branşlar, hekimler ve iletişim bilgileriyle klinik sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClinicFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🏋️',
            title: 'Fitness Stüdyosu Sitesi',
            subtitle: 'Program, eğitmen ve ders saatleriyle fitness stüdyosu sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FitnessFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🚗',
            title: 'Oto Yıkama / Servis Sitesi',
            subtitle: 'Hizmet paketleri ve iletişimle oto yıkama/servis sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CarWashFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🏠',
            title: 'Emlak Sitesi',
            subtitle: 'İlan listesi ve detay sayfalarıyla çok sayfalı emlak sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RealEstateFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🎨',
            title: 'Portfolyo Sitesi',
            subtitle: 'Projelerini/işlerini sergileyeceğin kişisel portfolyo sitesi.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PortfolioFormScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üstteki vurgulu giriş kartı — AI sohbetiyle site oluşturma akışını açar
/// (home_screen.dart). Diğer kartlardan farklı, gradyanlı bir görünümü ve
/// "PRO" rozeti var: şu an herkes serbestçe kullanabiliyor, ama ileride
/// ücretli/PRO bir özellik olarak konumlandırılması planlanan akış bu.
class _AiChatCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AiChatCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accentCyan, AppColors.accentBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('✨', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'AI ile Sohbet Ederek Oluştur',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'İstediğini yaz, AI senin için siteyi tasarlasın.',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
