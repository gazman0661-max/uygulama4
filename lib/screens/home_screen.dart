import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../state/app_state.dart';
import '../services/report_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/report_dialog.dart';
import '../widgets/guide_dialog.dart';
import '../widgets/language_picker_popup.dart';
import '../widgets/legal_consent_popup.dart';
import '../localization/locale_controller.dart';
import '../localization/app_strings.dart';
import 'subscription_plans_screen.dart';
import 'settings_sheet.dart';
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
import 'tailor_form_screen.dart';
import 'florist_form_screen.dart';
import 'massage_spa_form_screen.dart';
import 'driving_school_form_screen.dart';
import 'dentist_form_screen.dart';
import 'veterinarian_form_screen.dart';
import 'dietitian_form_screen.dart';
import 'lawyer_form_screen.dart';
import 'photographer_form_screen.dart';
import 'makeup_artist_form_screen.dart';
import 'musician_dj_form_screen.dart';
import 'personal_trainer_form_screen.dart';
import 'cleaning_company_form_screen.dart';
import 'moving_company_form_screen.dart';
import 'handyman_form_screen.dart';
import 'pet_grooming_form_screen.dart';
import 'generic_business_form_screen.dart';
import 'free_site_form_screen.dart';
import 'auto_repair_form_screen.dart';
import 'bakery_form_screen.dart';
import 'electrician_form_screen.dart';
import 'kindergarten_form_screen.dart';
import 'boutique_hotel_form_screen.dart';
import 'restaurant_form_screen.dart';
import 'furniture_decor_form_screen.dart';
import 'template_preview_screen.dart';
import '../templates/demo_templates.dart';
import '../widgets/quota_overflow_picker_sheet.dart';
import '../widgets/domain_quota_overflow_picker_sheet.dart';

const String _playStorePackage = 'com.sitora.ai';
const String _playStoreMarketUri = 'market://details?id=$_playStorePackage';
const String _playStoreWebUrl =
    'https://play.google.com/store/apps/details?id=$_playStorePackage';

Future<void> _openPlayStore() async {
  final marketUri = Uri.parse(_playStoreMarketUri);
  try {
    final launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (_) {
  }
  await openLegalUrl(_playStoreWebUrl);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _legalConsentPrefsKey = 'legal_terms_accepted_v1';

  static const _guideShownPrefsKey = 'guide_dialog_shown_v1';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _autoOpeningOverflowSheet = false;

  @override
  void initState() {
    super.initState();
    _maybeShowLanguagePicker();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  Future<void> _maybeAutoOpenQuotaOverflowSheets(AppState appState) async {
    if (_autoOpeningOverflowSheet || !mounted) return;
    if (appState.hasSubscriptionQuotaOverflow) {
      _autoOpeningOverflowSheet = true;
      await showQuotaOverflowPickerSheet(context);
      _autoOpeningOverflowSheet = false;
      if (!mounted) return;
    }
    if (appState.hasDomainQuotaOverflow) {
      _autoOpeningOverflowSheet = true;
      await showDomainQuotaOverflowPickerSheet(context);
      _autoOpeningOverflowSheet = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _normalizeTr(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  Future<void> _maybeShowLanguagePicker() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final locale = Provider.of<LocaleController>(context, listen: false);
      while (!locale.isLoaded) {
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted) return;
      }
      if (!mounted) return;
      if (!locale.hasChosenLanguage) {
        await showLanguagePickerPopup(context);
      }
      if (mounted) {
        await _maybeShowLegalConsent();
      }
      if (mounted) {
        await _maybeShowGuide();
      }
    });
  }

  Future<void> _maybeShowLegalConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_legalConsentPrefsKey) ?? false;
    if (accepted || !mounted) return;
    final ok = await showLegalConsentPopup(context);
    if (ok == true) {
      await prefs.setBool(_legalConsentPrefsKey, true);
    }
  }

  Future<void> _maybeShowGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_guideShownPrefsKey) ?? false;
    if (shown || !mounted) return;
    await prefs.setBool(_guideShownPrefsKey, true);
    if (!mounted) return;
    await showGuideDialog(context);
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  void _openReportSheet() {
    showReportDialog(
      context: context,
      source: ReportSource.general,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final appState = context.watch<AppState>();
    context.watch<LocaleController>();
    final isDark = themeController.isDark;

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final chipBg = isDark ? AppColors.darkIconChipBg : AppColors.lightIconChipBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;

    if (appState.hasSubscriptionQuotaOverflow || appState.hasDomainQuotaOverflow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoOpenQuotaOverflowSheets(appState));
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopPanel(isDark, chipBg, titleColor, themeController),
            const SizedBox(height: 8),
            if (appState.hasSubscriptionQuotaOverflow) ...[
              _buildSubscriptionQuotaOverflowBanner(),
              const SizedBox(height: 6),
            ],
            if (appState.hasDomainQuotaOverflow) ...[
              _buildDomainQuotaOverflowBanner(),
              const SizedBox(height: 6),
            ],
            _buildActionRow(appState),
            const SizedBox(height: 6),
            _buildSiteModeToggle(appState),
            const SizedBox(height: 10),
            _buildSearchField(isDark),
            const Divider(height: 16, thickness: 0.6),
            Expanded(child: _buildHomeTab(appState)),
            const SizedBox(height: 6),
            Center(
              child: Container(
                width: 120,
                height: 4,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(AppState appState) {
    final allCards = <_HomeToolCardData>[
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🧩',
        title: t(context, 'Serbest Site'),
        subtitle: t(context, 'Sektör seçmeden, ana sayfa ve ek sayfaları bloklarla kendin kur — kapak, yazı, görsel, galeri, video, çalışma saatleri, harita, yorumlar, iletişim, liste ve butonlar.'),
        builder: () => const FreeSiteFormScreen(initialMultiPage: true),
        id: 'free_site_multi',
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🧩',
        title: t(context, 'Serbest Site'),
        subtitle: t(context, 'Sektör seçmeden, tek sayfalık siteni bloklarla kendin kur — kapak, yazı, görsel, galeri, video, çalışma saatleri, harita, yorumlar, iletişim, liste ve butonlar.'),
        builder: () => const FreeSiteFormScreen(),
        id: 'free_site',
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🏢',
        title: t(context, 'Genel İşletme Sitesi'),
        subtitle: t(context, 'Ana Sayfa + istediğin kadar ek sayfa (Hakkımızda, Fiyatlar, SSS vb.) — her sayfa yazı, görsel, galeri, video, liste ve butonlardan oluşur.'),
        builder: () => const GenericBusinessFormScreen(initialMultiPage: true),
        id: 'generic_business_multi',
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🔳',
        title: t(context, 'QR Kod Oluştur'),
        subtitle:
            t(context, 'Bağlantı, wifi veya metin için QR kod üret.'),
        builder: () => const QrGeneratorScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🔗',
        title: t(context, 'Biyo Link Sayfası'),
        subtitle:
            t(context, 'Instagram/TikTok bio\'na koyacağın, tüm bağlantılarını tek sayfada toplayan mini site.'),
        builder: () => const BioLinkFormScreen(),
        demo: demoBioLink,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🪪',
        title: t(context, 'Dijital Kartvizit'),
        subtitle: t(context, 'İsim, unvan, iletişim ve sosyal linklerinle şık bir dijital kartvizit sayfası.'),
        builder: () => const BusinessCardFormScreen(),
        demo: demoBusinessCard,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏢',
        title: t(context, 'Genel İşletme Sitesi'),
        subtitle: t(context, 'Herhangi bir işletme için hizmetler, hakkında ve iletişim bilgileriyle genel amaçlı tanıtım sitesi.'),
        builder: () => const GenericBusinessFormScreen(),
        id: 'generic_business',
        demo: demoGenericBusiness,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '☕',
        title: t(context, 'Kafe / Restoran Sitesi'),
        subtitle: t(context, 'Menü, çalışma saatleri ve konumuyla hazır bir kafe/restoran sitesi.'),
        builder: () => const KafeFormScreen(),
        demo: demoKafe,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '☕',
        title: t(context, 'Kafe / Restoran Sitesi'),
        subtitle: t(context, 'Ana Sayfa + Menü + Galeri ayrı sayfalar olarak oluşturulan kafe/restoran sitesi.'),
        builder: () => const KafeFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '💈',
        title: t(context, 'Kuaför / Berber Sitesi'),
        subtitle: t(context, 'Hizmetler, galeri ve randevu bilgileriyle kuaför/berber sitesi.'),
        builder: () => const KuaforFormScreen(),
        demo: demoKuafor,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '💅',
        title: t(context, 'Güzellik Salonu Sitesi'),
        subtitle: t(context, 'Öncesi/sonrası galerisiyle güzellik salonu tanıtım sitesi.'),
        builder: () => const BeautySalonFormScreen(),
        demo: demoBeautySalon,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏥',
        title: t(context, 'Klinik / Sağlık Sitesi'),
        subtitle: t(context, 'Branşlar, hekimler ve iletişim bilgileriyle klinik sitesi.'),
        builder: () => const ClinicFormScreen(),
        demo: demoKlinik,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🏥',
        title: t(context, 'Klinik / Sağlık Sitesi'),
        subtitle: t(context, 'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan klinik sitesi.'),
        builder: () => const ClinicFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏋️',
        title: t(context, 'Fitness Stüdyosu Sitesi'),
        subtitle: t(context, 'Program, eğitmen ve ders saatleriyle fitness stüdyosu sitesi.'),
        builder: () => const FitnessFormScreen(),
        demo: demoFitness,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🚗',
        title: t(context, 'Oto Yıkama / Servis Sitesi'),
        subtitle: t(context, 'Hizmet paketleri ve iletişimle oto yıkama/servis sitesi.'),
        builder: () => const CarWashFormScreen(),
        demo: demoCarWash,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🏠',
        title: t(context, 'Emlak Sitesi'),
        subtitle: t(context, 'İlan listesi ve detay sayfalarıyla çok sayfalı emlak sitesi.'),
        builder: () => const RealEstateFormScreen(),
        demo: demoRealEstate,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🎨',
        title: t(context, 'Portfolyo Sitesi'),
        subtitle: t(context, 'Projelerini/işlerini sergileyeceğin kişisel portfolyo sitesi.'),
        builder: () => const PortfolioFormScreen(),
        demo: demoPortfolio,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🎨',
        title: t(context, 'Portfolyo Sitesi'),
        subtitle: t(context, 'Ana Sayfa + her iş örneği kendi detay sayfasında oluşturulan portfolyo sitesi.'),
        builder: () => const PortfolioFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '✂️',
        title: t(context, 'Terzi Sitesi'),
        subtitle: t(context, 'Hizmetler, ölçü/randevu ve iletişim bilgileriyle terzi tanıtım sitesi.'),
        builder: () => const TailorFormScreen(),
        demo: demoTailor,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '💐',
        title: t(context, 'Çiçekçi Sitesi'),
        subtitle: t(context, 'Ürün galerisi, teslimat ve sipariş bilgileriyle çiçekçi sitesi.'),
        builder: () => const FloristFormScreen(),
        demo: demoFlorist,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🧖',
        title: t(context, 'Masaj / Spa Sitesi'),
        subtitle: t(context, 'Hizmet paketleri ve randevu bilgileriyle masaj/spa merkezi sitesi.'),
        builder: () => const MassageSpaFormScreen(),
        demo: demoMassageSpa,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🚦',
        title: t(context, 'Sürücü Kursu Sitesi'),
        subtitle: t(context, 'Ehliyet sınıfları, eğitmenler ve kayıt bilgileriyle sürücü kursu sitesi.'),
        builder: () => const DrivingSchoolFormScreen(),
        demo: demoDrivingSchool,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🦷',
        title: t(context, 'Diş Hekimi Sitesi'),
        subtitle: t(context, 'Tedaviler, hekimler ve randevu bilgileriyle diş hekimi/klinik sitesi.'),
        builder: () => const DentistFormScreen(),
        demo: demoDentist,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🦷',
        title: t(context, 'Diş Hekimi Sitesi'),
        subtitle: t(context, 'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan diş hekimi sitesi.'),
        builder: () => const DentistFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🐾',
        title: t(context, 'Veteriner Sitesi'),
        subtitle: t(context, 'Branşlar, hekimler ve randevu bilgileriyle veteriner kliniği sitesi.'),
        builder: () => const VeterinarianFormScreen(),
        demo: demoVeterinarian,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🐾',
        title: t(context, 'Veteriner Sitesi'),
        subtitle: t(context, 'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan veteriner sitesi.'),
        builder: () => const VeterinarianFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🥗',
        title: t(context, 'Diyetisyen Sitesi'),
        subtitle: t(context, 'Programlar, danışmanlık ve randevu bilgileriyle diyetisyen sitesi.'),
        builder: () => const DietitianFormScreen(),
        demo: demoDietitian,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🥗',
        title: t(context, 'Diyetisyen Sitesi'),
        subtitle: t(context, 'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan diyetisyen sitesi.'),
        builder: () => const DietitianFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '⚖️',
        title: t(context, 'Avukat / Hukuk Bürosu Sitesi'),
        subtitle: t(context, 'Uzmanlık alanları, ekip ve iletişim bilgileriyle hukuk bürosu sitesi.'),
        builder: () => const LawyerFormScreen(),
        demo: demoLawyer,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '⚖️',
        title: t(context, 'Avukat / Hukuk Bürosu Sitesi'),
        subtitle: t(context, 'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan hukuk bürosu sitesi.'),
        builder: () => const LawyerFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '📷',
        title: t(context, 'Fotoğrafçı Sitesi'),
        subtitle: t(context, 'Galeri, çekim paketleri ve iletişimle fotoğrafçı portfolyo sitesi.'),
        builder: () => const PhotographerFormScreen(),
        demo: demoPhotographer,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '📷',
        title: t(context, 'Fotoğrafçı Sitesi'),
        subtitle: t(context, 'Ana Sayfa + iş örnekleri ayrı sayfalar olarak oluşturulan fotoğrafçı sitesi.'),
        builder: () => const PhotographerFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '💄',
        title: t(context, 'Makyaj Sanatçısı Sitesi'),
        subtitle: t(context, 'Galeri, hizmet paketleri ve randevu bilgileriyle makyaj sanatçısı sitesi.'),
        builder: () => const MakeupArtistFormScreen(),
        demo: demoMakeupArtist,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '💄',
        title: t(context, 'Makyaj Sanatçısı Sitesi'),
        subtitle: t(context, 'Ana Sayfa + iş örnekleri ayrı sayfalar olarak oluşturulan makyaj sanatçısı sitesi.'),
        builder: () => const MakeupArtistFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🎧',
        title: t(context, 'Müzisyen / DJ Sitesi'),
        subtitle: t(context, 'Galeri, performans/etkinlik bilgileri ve iletişimle müzisyen/DJ sitesi.'),
        builder: () => const MusicianDjFormScreen(),
        demo: demoMusicianDj,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🎧',
        title: t(context, 'Müzisyen / DJ Sitesi'),
        subtitle: t(context, 'Ana Sayfa + iş örnekleri ayrı sayfalar olarak oluşturulan müzisyen/DJ sitesi.'),
        builder: () => const MusicianDjFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏃',
        title: t(context, 'Kişisel Antrenör Sitesi'),
        subtitle: t(context, 'Programlar, başarı hikayeleri ve randevu bilgileriyle kişisel antrenör sitesi.'),
        builder: () => const PersonalTrainerFormScreen(),
        demo: demoPersonalTrainer,
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🏃',
        title: t(context, 'Kişisel Antrenör Sitesi'),
        subtitle: t(context, 'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan kişisel antrenör sitesi.'),
        builder: () => const PersonalTrainerFormScreen(initialMultiPage: true),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🧹',
        title: t(context, 'Temizlik Şirketi Sitesi'),
        subtitle: t(context, 'Hizmet paketleri, bölgeler ve teklif alma bilgileriyle temizlik şirketi sitesi.'),
        builder: () => const CleaningCompanyFormScreen(),
        demo: demoCleaningCompany,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '📦',
        title: t(context, 'Nakliyat Sitesi'),
        subtitle: t(context, 'Hizmet bölgeleri, araç filosu ve teklif alma bilgileriyle nakliyat sitesi.'),
        builder: () => const MovingCompanyFormScreen(),
        demo: demoMovingCompany,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🔨',
        title: t(context, 'Tadilatçı Sitesi'),
        subtitle: t(context, 'Öncesi/sonrası galerisi ve teklif alma bilgileriyle tadilat/tamirat sitesi.'),
        builder: () => const HandymanFormScreen(),
        demo: demoHandyman,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🐶',
        title: t(context, 'Pet Kuaförü Sitesi'),
        subtitle: t(context, 'Hizmet paketleri, galeri ve randevu bilgileriyle pet kuaförü sitesi.'),
        builder: () => const PetGroomingFormScreen(),
        demo: demoPetGrooming,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🛞',
        title: t(context, 'Oto Tamirci / Lastikçi Sitesi'),
        subtitle: t(context, 'Bakım/onarım hizmetleri, galeri ve randevu bilgileriyle oto tamirci/lastikçi sitesi.'),
        builder: () => const AutoRepairFormScreen(),
        demo: demoAutoRepair,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🥐',
        title: t(context, 'Fırın / Pastane Sitesi'),
        subtitle: t(context, 'Ürün kategorileri, galeri ve sipariş bilgileriyle fırın/pastane sitesi.'),
        builder: () => const BakeryFormScreen(),
        demo: demoBakery,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '⚡',
        title: t(context, 'Elektrikçi Sitesi'),
        subtitle: t(context, 'Hizmetler, galeri ve hızlı iletişim bilgileriyle elektrikçi/tesisatçı sitesi.'),
        builder: () => const ElectricianFormScreen(),
        demo: demoElectrician,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🧸',
        title: t(context, 'Anaokulu / Kreş Sitesi'),
        subtitle: t(context, 'Programlar, galeri ve kayıt bilgileriyle anaokulu/kreş sitesi.'),
        builder: () => const KindergartenFormScreen(),
        demo: demoKindergarten,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏨',
        title: t(context, 'Butik Otel / Pansiyon Sitesi'),
        subtitle: t(context, 'Oda tipleri, galeri ve rezervasyon bilgileriyle butik otel/pansiyon sitesi.'),
        builder: () => const BoutiqueHotelFormScreen(),
        demo: demoBoutiqueHotel,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🍽️',
        title: t(context, 'Restoran / Lokanta Sitesi'),
        subtitle: t(context, 'Menü, galeri ve rezervasyon bilgileriyle tam hizmet restoran sitesi.'),
        builder: () => const RestaurantFormScreen(),
        demo: demoRestaurant,
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🛋️',
        title: t(context, 'Mobilyacı / Dekorasyon Sitesi'),
        subtitle: t(context, 'Ürün kategorileri, galeri ve teklif alma bilgileriyle mobilyacı/dekorasyon sitesi.'),
        builder: () => const FurnitureDecorFormScreen(),
        demo: demoFurnitureDecor,
      ),
    ];

    final modeCards = allCards.where((c) => c.mode == appState.qtSiteMode).toList();

    final query = _normalizeTr(_searchQuery.trim());
    List<_HomeToolCardData> filteredCards;
    bool showingFallback = false;
    if (query.isEmpty) {
      filteredCards = modeCards;
    } else {
      filteredCards = modeCards
          .where((c) =>
              _normalizeTr(c.title).contains(query) ||
              _normalizeTr(c.subtitle).contains(query))
          .toList();
      if (filteredCards.isEmpty) {
        final fallbackId = appState.qtSiteMode == SiteMode.multi
            ? 'generic_business_multi'
            : 'generic_business';
        final fallback = allCards.firstWhere(
          (c) => c.id == fallbackId,
          orElse: () => allCards.first,
        );
        filteredCards = [fallback];
        showingFallback = true;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (showingFallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '"$_searchQuery" ${t(context, "için tam eşleşme yok, sana en uygun genel şablonu önerdik:")}',
              style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.85)),
            ),
          ),
        for (final card in filteredCards) ...[
          _HomeToolCard(
            emoji: card.emoji,
            title: card.title,
            subtitle: card.subtitle,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => card.builder())),
            onPreviewTap: card.demo == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TemplatePreviewScreen(config: card.demo!),
                      ),
                    ),
          ),
          const SizedBox(height: 12),
        ],
        if (filteredCards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              t(context, 'Bu modda henüz şablon yok.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.withOpacity(0.8)),
            ),
          ),
      ],
    );
  }

  Widget _buildTopPanel(bool isDark, Color chipBg, Color titleColor,
      ThemeController themeController) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'MySitora',
              maxLines: 1,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: titleColor,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleIconButton(
                      icon: isDark ? Icons.dark_mode : Icons.wb_sunny,
                      background: chipBg,
                      iconColor: isDark ? Colors.white70 : Colors.orange,
                      onTap: () => themeController.toggleTheme(),
                    ),
                    const SizedBox(width: 8),
                    LanguageToggleButton(background: chipBg, isDark: isDark),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: Icons.settings,
                      background: chipBg,
                      iconColor: isDark ? Colors.white70 : Colors.black54,
                      onTap: _openSettingsSheet,
                    ),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: Icons.flag_rounded,
                      background: chipBg,
                      iconColor: AppColors.accentRed,
                      borderColor: AppColors.accentRed,
                      onTap: _openReportSheet,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteModeToggle(AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _siteModeChip(
              currentMode: appState.qtSiteMode,
              onChanged: appState.setQtSiteMode,
              mode: SiteMode.single,
              title: t(context, 'Tek Sayfa'),
              subtitle: t(context, 'Tek sayfalık şablonlar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _siteModeChip(
              currentMode: appState.qtSiteMode,
              onChanged: appState.setQtSiteMode,
              mode: SiteMode.multi,
              title: t(context, 'Çok Sayfa'),
              subtitle: t(context, 'Çok sayfalı şablonlar (Emlak)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    final fieldBg = isDark ? AppColors.darkIconChipBg : AppColors.lightIconChipBg;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search, size: 19, color: Colors.grey.withOpacity(0.85)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: t(context, 'Sektörünü yaz... (ör. kuaför, restoran)'),
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.withOpacity(0.8)),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey.withOpacity(0.85)),
                splashRadius: 18,
                onPressed: () => _searchController.clear(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _siteModeChip({
    required SiteMode currentMode,
    required ValueChanged<SiteMode> onChanged,
    required SiteMode mode,
    required String title,
    required String subtitle,
  }) {
    final selected = currentMode == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentCyan.withOpacity(0.12) : null,
          border: Border.all(
            color: selected ? AppColors.accentCyan : Colors.grey.withOpacity(0.35),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(context, title),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.accentCyan : Colors.grey,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              t(context, subtitle),
              style: TextStyle(fontSize: 9.5, color: Colors.grey.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionQuotaOverflowBanner() {
    final en = isEnglish(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: const Color(0xFFFFB74D).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showQuotaOverflowPickerSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5), width: 1),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    en
                        ? 'You have more sites than your subscription quota — tap to choose which ones stay premium.'
                        : 'Abonelik kotandan fazla siten var — premium kalacak siteleri seçmek için dokun.',
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11.5, height: 1.3),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDomainQuotaOverflowBanner() {
    final en = isEnglish(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: const Color(0xFFEF5350).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDomainQuotaOverflowPickerSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.5), width: 1),
            ),
            child: Row(
              children: [
                const Text('🌐', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    en
                        ? 'You have more connected domains than your subscription quota — tap to choose which ones stay connected.'
                        : 'Abonelik domain kotandan fazla bağlı domain\'in var — bağlı kalacakları seçmek için dokun.',
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11.5, height: 1.3),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(AppState appState) {
    final bool subscribed = appState.hasActiveSubscription;
    final String planLabel = subscribed
        ? (appState.activeSubscriptionTier?.displayNameTr ?? t(context, 'Ücretsiz Plan'))
        : t(context, 'Ücretsiz Plan');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PillButton(
                label: t(context, 'Kılavuz'),
                emoji: '📖',
                borderColor: AppColors.accentGreenLink,
                textColor: AppColors.accentGreenLink,
                height: 38,
                fontSize: 12.5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: () => showGuideDialog(context),
              ),
              const SizedBox(width: 10),
              PillButton(
                label: t(context, 'Puan Ver'),
                emoji: '⭐',
                borderColor: AppColors.accentOrange,
                textColor: AppColors.accentOrange,
                height: 38,
                fontSize: 12.5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: _openPlayStore,
              ),
              const SizedBox(width: 10),
              PillButton(
                label: planLabel,
                emoji: subscribed ? '👑' : '🔓',
                borderColor: AppColors.accentPurple,
                textColor: AppColors.accentPurple,
                height: 38,
                fontSize: 12.5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: () => showSubscriptionPlansScreen(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeToolCardData {
  final SiteMode mode;
  final String emoji;
  final String title;
  final String subtitle;
  final Widget Function() builder;
  final String? id;
  final TemplateDemoConfig? demo;

  const _HomeToolCardData({
    required this.mode,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.id,
    this.demo,
  });
}

class _HomeToolCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPreviewTap;

  const _HomeToolCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onPreviewTap,
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
              if (onPreviewTap != null)
                IconButton(
                  tooltip: t(context, 'Şablonu önizle'),
                  icon: const Icon(Icons.remove_red_eye_outlined),
                  onPressed: onPreviewTap,
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
