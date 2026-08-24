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
import '../widgets/store_sheet.dart';
import '../widgets/language_picker_popup.dart';
import '../widgets/legal_consent_popup.dart';
import '../localization/locale_controller.dart';
import '../localization/app_strings.dart';
import 'settings_sheet.dart';
import 'projects_screen.dart';
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
import 'builder_screen.dart';

/// "Puan Ver" butonunun açtığı Play Store mağaza sayfası.
/// market:// şeması, cihazda kurulu Play Store UYGULAMASINI doğrudan açar
/// (tarayıcıya hiç uğramadan). Play Store yüklü değilse (örn. emülatör)
/// [_openPlayStore] otomatik olarak normal https linkine düşer.
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
    // Play Store uygulaması kurulu değil ya da market:// desteklenmiyor —
    // aşağıdaki web linkine düşülür.
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

  @override
  void initState() {
    super.initState();
    // Uygulama ilk kez açıldığında gösterilmesi gereken zorunlu dil
    // seçimi ve KVKK/Kullanım Şartları onay popup'ları buradan tetikleniyor.
    _maybeShowLanguagePicker();
  }

  /// Uygulama daha önce hiç dil seçilmediyse (ilk açılış), kullanıcı bir
  /// dil seçene kadar ekranda kalan kapatılamaz bir popup gösterir.
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
        await showLanguagePickerPopup(context, dismissible: false);
      }
      if (mounted) {
        await _maybeShowLegalConsent();
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

  void _openProjectsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProjectsScreen()),
    );
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

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopPanel(isDark, chipBg, titleColor, themeController),
            const SizedBox(height: 8),
            _buildActionRow(appState),
            const SizedBox(height: 6),
            _buildBuilderProBanner(isDark),
            const SizedBox(height: 6),
            _buildSiteModeToggle(appState),
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

  /// Hızlı Araçlar (form ile site oluşturma) listesi.
  ///
  /// Üstteki "Tek Sayfa / Çok Sayfa" seçiciyle (appState.qtSiteMode)
  /// entegre: TEK SAYFA seçiliyken sadece tek sayfalık şablonlar, ÇOK
  /// SAYFA seçiliyken sadece çok sayfalı (şu an: Emlak Sitesi) şablonlar
  /// listelenir.
  Widget _buildHomeTab(AppState appState) {
    final allCards = <_HomeToolCardData>[
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🔳',
        title: t(context, 'QR Kod Oluştur'),
        subtitle:
            t(context, 'Bağlantı, wifi veya metin için QR kod üret (site oluşturmayla aynı puan kotasından düşer).'),
        builder: () => const QrGeneratorScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🔗',
        title: t(context, 'Biyo Link Sayfası'),
        subtitle:
            t(context, 'Instagram/TikTok bio\'na koyacağın, tüm bağlantılarını tek sayfada toplayan mini site.'),
        builder: () => const BioLinkFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🪪',
        title: t(context, 'Dijital Kartvizit'),
        subtitle: t(context, 'İsim, unvan, iletişim ve sosyal linklerinle şık bir dijital kartvizit sayfası.'),
        builder: () => const BusinessCardFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '☕',
        title: t(context, 'Kafe / Restoran Sitesi'),
        subtitle: t(context, 'Menü, çalışma saatleri ve konumuyla hazır bir kafe/restoran sitesi.'),
        builder: () => const KafeFormScreen(),
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
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '💅',
        title: t(context, 'Güzellik Salonu Sitesi'),
        subtitle: t(context, 'Öncesi/sonrası galerisiyle güzellik salonu tanıtım sitesi.'),
        builder: () => const BeautySalonFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏥',
        title: t(context, 'Klinik / Sağlık Sitesi'),
        subtitle: t(context, 'Branşlar, hekimler ve iletişim bilgileriyle klinik sitesi.'),
        builder: () => const ClinicFormScreen(),
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
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🚗',
        title: t(context, 'Oto Yıkama / Servis Sitesi'),
        subtitle: t(context, 'Hizmet paketleri ve iletişimle oto yıkama/servis sitesi.'),
        builder: () => const CarWashFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🏠',
        title: t(context, 'Emlak Sitesi'),
        subtitle: t(context, 'İlan listesi ve detay sayfalarıyla çok sayfalı emlak sitesi.'),
        builder: () => const RealEstateFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🎨',
        title: t(context, 'Portfolyo Sitesi'),
        subtitle: t(context, 'Projelerini/işlerini sergileyeceğin kişisel portfolyo sitesi.'),
        builder: () => const PortfolioFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🎨',
        title: t(context, 'Portfolyo Sitesi'),
        subtitle: t(context, 'Ana Sayfa + her iş örneği kendi detay sayfasında oluşturulan portfolyo sitesi.'),
        builder: () => const PortfolioFormScreen(initialMultiPage: true),
      ),
    ];

    final filteredCards =
        allCards.where((c) => c.mode == appState.qtSiteMode).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final card in filteredCards) ...[
          _HomeToolCard(
            emoji: card.emoji,
            title: card.title,
            subtitle: card.subtitle,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => card.builder())),
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

  /// Üst panel: başlık + ikon butonları tek satırda.
  ///
  /// Tüm blok [FittedBox] içine alınır: doğal genişliği ekrana sığmazsa
  /// (küçük telefonlarda) içerik oranlarını koruyarak bir bütün halinde
  /// küçülür, sığıyorsa (geniş ekran/tablet) olduğu boyutta solda kalır.
  /// Böylece hiçbir buton hiçbir cihazda taşmaz veya kırpılmaz.
  Widget _buildTopPanel(bool isDark, Color chipBg, Color titleColor,
      ThemeController themeController) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'SITORA',
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: titleColor,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 14),
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
                icon: Icons.folder_open,
                background: chipBg,
                iconColor: isDark ? Colors.white70 : Colors.black54,
                onTap: _openProjectsScreen,
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.storefront,
                background: chipBg,
                iconColor: isDark ? Colors.white70 : Colors.black54,
                onTap: () => showStoreSheet(context),
              ),
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
    );
  }

  /// Formlarla site oluşturmadan bağımsız, ikinci bir yol: boş bir canvas
  /// üzerinde sürükle-bırak ile sıfırdan tasarım. Eskiden bu konumda (Tek
  /// Sayfa/Çok Sayfa seçicisinin hemen üstünde) AI'ya geçiş yapan bir buton
  /// vardı; AI kaldırılınca yerine Builder Pro'ya geçiş kondu (2026-08-20).
  Widget _buildBuilderProBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BuilderScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentCyan.withOpacity(isDark ? 0.22 : 0.14),
                AppColors.accentBlue.withOpacity(isDark ? 0.22 : 0.14),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accentCyan.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Text('🎨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(context, 'Sürükle-Bırak ile Oluştur'),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTitleText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      t(context, 'Boş bir canvas üzerinde sıfırdan tasarla'),
                      style: TextStyle(
                        color: (isDark ? Colors.white : AppColors.lightTitleText)
                            .withOpacity(0.65),
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.accentCyan, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  /// "Tek Sayfa / Çok Sayfa" seçici — [_buildHomeTab]'daki şablon
  /// kartlarını filtreler.
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

  /// İkinci satır: Kılavuz / Puan Ver / elmas sayacı.
  ///
  /// Üst panelle aynı mantık: tüm satır [FittedBox] içinde tek blok olarak
  /// ele alınır. Ekrana sığmıyorsa kayma veya alt satıra geçme OLMAZ,
  /// bütün satır oranını koruyarak küçülür; sığıyorsa doğal boyutunda kalır.
  Widget _buildActionRow(AppState appState) {
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
              _buildCreditChip(appState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditChip(AppState appState) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.accentBlue, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, color: AppColors.accentBlue, size: 15),
          const SizedBox(width: 6),
          Text(
            '${appState.formCredits} /${AppState.maxFormPoints}',
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// [_buildHomeTab]'daki şablon kartlarının verisi — hangi site modunda
/// (Tek Sayfa/Çok Sayfa) gösterileceğini de taşır, filtreleme bu alana
/// göre yapılır.
class _HomeToolCardData {
  final SiteMode mode;
  final String emoji;
  final String title;
  final String subtitle;
  final Widget Function() builder;

  const _HomeToolCardData({
    required this.mode,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

class _HomeToolCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeToolCard({
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
