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
import 'cleaning_company_form_screen.dart';
import 'moving_company_form_screen.dart';
import 'handyman_form_screen.dart';
import 'tailor_form_screen.dart';
import 'florist_form_screen.dart';
import 'massage_spa_form_screen.dart';
import 'pet_grooming_form_screen.dart';
import 'driving_school_form_screen.dart';
import 'dentist_form_screen.dart';
import 'veterinarian_form_screen.dart';
import 'dietitian_form_screen.dart';
import 'lawyer_form_screen.dart';
import 'photographer_form_screen.dart';
import 'makeup_artist_form_screen.dart';
import 'musician_dj_form_screen.dart';
import 'personal_trainer_form_screen.dart';
import '../localization/app_strings.dart';

/// UYGULAMANIN YENİ ANA EKRANI (bkz. splash_screen.dart). Kullanıcı önce
/// hangi site türünü istediğini seçiyor; AI sohbet akışı (home_screen.dart)
/// artık buradan açılan, ayrı ve ileride PRO/ücretli olarak sunulabilecek
/// bir kısayol — en üstteki [_AiChatCard] bunu açar.
///
/// QR Kod tamamen yerel üretildiği (AI çağrısı YOKTUR) için, aşağıdaki
/// sektörel site kartlarıyla (kafe, kuaför, ...) AYNI FORM puan
/// havuzundan düşer (AppState.costSinglePage = 5 puan, aylık 30 puan
/// tavan). AI havuzunu hiç etkilemez.
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
      appBar: AppBar(title: Text(t(context, 'Sitora AI'))),
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
            title: t(context, 'QR Kod Oluştur'),
            subtitle: t(context, 'Bağlantı, wifi veya metin için QR kod üret (site oluşturmayla aynı puan kotasından düşer).'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrGeneratorScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🔗',
            title: t(context, 'Biyo Link Sayfası'),
            subtitle: t(context, 'Instagram/TikTok bio\'na koyacağın, tüm bağlantılarını tek sayfada toplayan mini site.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BioLinkFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🪪',
            title: t(context, 'Dijital Kartvizit'),
            subtitle: t(context, 'İsim, unvan, iletişim ve sosyal linklerinle şık bir dijital kartvizit sayfası.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BusinessCardFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '☕',
            title: t(context, 'Kafe / Restoran Sitesi'),
            subtitle: t(context, 'Menü, çalışma saatleri ve konumuyla hazır bir kafe/restoran sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KafeFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '💈',
            title: t(context, 'Kuaför / Berber Sitesi'),
            subtitle: t(context, 'Hizmetler, galeri ve randevu bilgileriyle kuaför/berber sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KuaforFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '💅',
            title: t(context, 'Güzellik Salonu Sitesi'),
            subtitle: t(context, 'Öncesi/sonrası galerisiyle güzellik salonu tanıtım sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BeautySalonFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🏥',
            title: t(context, 'Klinik / Sağlık Sitesi'),
            subtitle: t(context, 'Branşlar, hekimler ve iletişim bilgileriyle klinik sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClinicFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🏋️',
            title: t(context, 'Fitness Stüdyosu Sitesi'),
            subtitle: t(context, 'Program, eğitmen ve ders saatleriyle fitness stüdyosu sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FitnessFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🚗',
            title: t(context, 'Oto Yıkama / Servis Sitesi'),
            subtitle: t(context, 'Hizmet paketleri ve iletişimle oto yıkama/servis sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CarWashFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🏠',
            title: t(context, 'Emlak Sitesi'),
            subtitle: t(context, 'İlan listesi ve detay sayfalarıyla çok sayfalı emlak sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RealEstateFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🎨',
            title: t(context, 'Portfolyo Sitesi'),
            subtitle: t(context, 'Projelerini/işlerini sergileyeceğin kişisel portfolyo sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PortfolioFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🧹',
            title: t(context, 'Temizlik Şirketi Sitesi'),
            subtitle: t(context, 'Hizmetler, çalışma saatleri ve konumuyla temizlik şirketi tanıtım sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CleaningCompanyFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🚚',
            title: t(context, 'Nakliyat Sitesi'),
            subtitle: t(context, 'Hizmetler ve iletişim bilgileriyle nakliyat/evden eve nakliyat sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MovingCompanyFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🔧',
            title: t(context, 'Usta Hizmetleri Sitesi'),
            subtitle: t(context, 'Elektrikçi, tesisatçı veya tamirci için hizmet ve iletişim sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HandymanFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🧵',
            title: t(context, 'Terzi Sitesi'),
            subtitle: t(context, 'Hizmetler, galeri ve randevu bilgileriyle terzi tanıtım sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TailorFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '💐',
            title: t(context, 'Çiçekçi Sitesi'),
            subtitle: t(context, 'Ürünler, galeri ve sipariş bilgileriyle çiçekçi sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FloristFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🧖',
            title: t(context, 'Masaj / SPA Sitesi'),
            subtitle: t(context, 'Öncesi/sonrası galerisiyle masaj/SPA salonu tanıtım sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MassageSpaFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🐾',
            title: t(context, 'Pet Kuaförü / Pet Shop Sitesi'),
            subtitle: t(context, 'Hizmetler, galeri ve randevu bilgileriyle pet kuaförü/pet shop sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PetGroomingFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🚦',
            title: t(context, 'Sürücü Kursu Sitesi'),
            subtitle: t(context, 'Kurs paketleri ve iletişim bilgileriyle sürücü kursu sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DrivingSchoolFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🦷',
            title: t(context, 'Diş Hekimi Sitesi'),
            subtitle: t(context, 'Unvan, uzmanlık alanları ve randevu bilgileriyle diş hekimi sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DentistFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🐶',
            title: t(context, 'Veteriner Kliniği Sitesi'),
            subtitle: t(context, 'Hizmetler ve randevu bilgileriyle veteriner kliniği sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VeterinarianFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🥗',
            title: t(context, 'Diyetisyen Sitesi'),
            subtitle: t(context, 'Hizmet alanları ve randevu bilgileriyle diyetisyen tanıtım sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DietitianFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '⚖️',
            title: t(context, 'Avukat / Hukuk Bürosu Sitesi'),
            subtitle: t(context, 'Uzmanlık alanları ve iletişim bilgileriyle avukat/hukuk bürosu sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LawyerFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '📸',
            title: t(context, 'Fotoğrafçı Sitesi'),
            subtitle: t(context, 'Fotoğraf örnekleri ve deneyimle fotoğrafçı portfolyo sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PhotographerFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '💄',
            title: t(context, 'Makyaj Sanatçısı Sitesi'),
            subtitle: t(context, 'Çalışma örnekleri ve deneyimle makyaj sanatçısı portfolyo sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MakeupArtistFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🎧',
            title: t(context, 'Müzisyen / DJ Sitesi'),
            subtitle: t(context, 'Performans örnekleri ve deneyimle müzisyen/DJ portfolyo sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MusicianDjFormScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            emoji: '🏃',
            title: t(context, 'Kişisel Antrenör Sitesi'),
            subtitle: t(context, 'Çalışma örnekleri ve deneyimle kişisel antrenör portfolyo sitesi.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PersonalTrainerFormScreen()),
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
                        Flexible(
                          child: Text(
                            t(context, 'AI ile Sohbet Ederek Oluştur'),
                            style: const TextStyle(
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
                      t(context, 'İstediğini yaz, AI senin için siteyi tasarlasın.'),
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
