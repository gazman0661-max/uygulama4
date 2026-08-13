import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../state/app_state.dart';
import '../services/gemini_service.dart';
import '../services/worker_service.dart';
import '../services/report_service.dart';
import '../services/download_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/report_dialog.dart';
import '../widgets/ai_edit_dialog.dart';
import '../widgets/confirm_popup.dart';
import '../widgets/guide_dialog.dart';
import '../widgets/quota_limit_popup.dart';
import '../widgets/language_picker_popup.dart';
import '../widgets/legal_consent_popup.dart';
import '../localization/locale_controller.dart';
import '../localization/app_strings.dart';
import 'settings_sheet.dart';
import 'edit_screen.dart';
import 'preview_screen.dart';
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

class ChatMessage {
  final String text;
  final bool isBot;
  ChatMessage({required this.text, required this.isBot});
}

/// Üst paneldeki geçiş butonunun iki sekmesi: eskiden "AI CHAT / BUILDER
/// PRO" olan yer artık mevcut sisteme göre "ANA SAYFA / AI SOHBET"
/// sekmelerine dönüştürüldü. Ekran arası navigasyon yerine tek ekran
/// içinde, buton ile anlık geçiş yapılıyor.
enum _MainTab { home, chat }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = [];

  // Üst panel artık gerçek bir sekme geçişi: ANA SAYFA (Hızlı Araçlar
  // listesi) / AI SOHBET (eski home_screen sohbet akışı). Uygulama
  // varsayılan olarak Ana Sayfa'da açılır (splash sonrası eski davranışla
  // aynı).
  _MainTab _activeTab = _MainTab.home;

  static const _legalConsentPrefsKey = 'legal_terms_accepted_v1';

  // Uygulama kapatılıp açıldığında sohbet ekranındakiler silinmesin diye
  // mesajlar SharedPreferences'ta saklanır; kullanıcı sadece 🗑️ SİL
  // butonuna basıp onaylarsa temizlenir.
  static const _chatPrefsKey = 'chat_messages_v1';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // TAŞINDI (quick_tools_screen.dart'tan): Hızlı Araçlar artık ayrı bir
    // ekran değil, bu ekranın "Ana Sayfa" sekmesi. Uygulama ilk kez
    // açıldığında gösterilmesi gereken zorunlu dil seçimi ve KVKK/Kullanım
    // Şartları onay popup'ları buradan tetikleniyor.
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
      await _maybeShowLegalConsent();
    }
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      final restored = list
          .map((m) => ChatMessage(
                text: m['text'] as String,
                isBot: m['isBot'] as bool,
              ))
          .toList();
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(restored);
        });
      }
    } catch (_) {
      // Bozuk/okunamayan bir kayıt varsa sessizce yok say; sohbet boş başlar.
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      _messages.map((m) => {'text': m.text, 'isBot': m.isBot}).toList(),
    );
    await prefs.setString(_chatPrefsKey, raw);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();

    // Kendi API anahtarı olan kullanıcı sınırsızdır. Olmayan kullanıcı için
    // günlük ücretsiz puan kotası kontrol edilir (1 site oluşturma = 5 puan).
    if (!await appState.ensureQuotaFor(AppState.costGenerateSite)) {
      await showQuotaLimitPopup(context);
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isBot: false));
      _inputController.clear();
    });

    appState.setGenerating(true);
    setState(() {
      _messages.add(ChatMessage(text: t(context, 'Siteniz oluşturuluyor... ⏳'), isBot: true));
    });

    try {
      if (appState.usesFreeQuota) {
        // Ücretsiz/anahtarsız akış: Worker üzerinden, own-key akışıyla
        // BİREBİR AYNI promptlarla (bkz. worker.js) — hem A hem B modu.
        if (appState.siteMode == SiteMode.single) {
          final code = await WorkerService.generateSiteCode(
            prompt: text,
            images: appState.pickedImages,
            previousCode: appState.generatedCode,
          );
          appState.updateGeneratedCode(code, projectName: text);
          await appState.consumeQuota(AppState.costGenerateSite);
          setState(() {
            _messages.removeLast();
            _messages.add(ChatMessage(
              text: t(context,
                  'Siteniz hazır! 🚀 DÜZENLE\'den kodu görebilir, ÖN İZLEME\'den siteyi canlı izleyebilirsiniz.'),
              isBot: true,
            ));
          });
        } else {
          final files = await WorkerService.generateMultiPageSite(
            prompt: text,
            images: appState.pickedImages,
            previousFiles: appState.generatedFiles,
          );
          appState.updateGeneratedFiles(files, projectName: text);
          await appState.consumeQuota(AppState.costGenerateSite);
          setState(() {
            _messages.removeLast();
            _messages.add(ChatMessage(
              text: isEnglish(context)
                  ? 'Your site is ready! 🚀 ${files.length} pages generated (${files.keys.join(', ')}). '
                      'You can view the active page from EDIT, or get them all as a ZIP from DOWNLOAD.'
                  : 'Siteniz hazır! 🚀 ${files.length} sayfa üretildi (${files.keys.join(', ')}). '
                      'DÜZENLE\'den aktif sayfayı görebilir, İNDİR\'den hepsini ZIP olarak alabilirsiniz.',
              isBot: true,
            ));
          });
        }
      } else if (appState.siteMode == SiteMode.single) {
        // A modu: tek HTML, mevcut akışın aynısı.
        final code = await GeminiService.generateSiteCode(
          apiKey: appState.effectiveApiKey!,
          model: appState.selectedModel,
          prompt: text,
          images: appState.pickedImages,
          previousCode: appState.generatedCode,
        );
        appState.updateGeneratedCode(code, projectName: text);
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(
            text: t(context,
                'Siteniz hazır! 🚀 DÜZENLE\'den kodu görebilir, ÖN İZLEME\'den siteyi canlı izleyebilirsiniz.'),
            isBot: true,
          ));
        });
      } else {
        // B modu: çok sayfa — dosya haritası döner, ZIP olarak indirilecek.
        final files = await GeminiService.generateMultiPageSite(
          apiKey: appState.effectiveApiKey!,
          model: appState.selectedModel,
          prompt: text,
          images: appState.pickedImages,
          previousFiles: appState.generatedFiles,
        );
        appState.updateGeneratedFiles(files, projectName: text);
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(
            text: isEnglish(context)
                ? 'Your site is ready! 🚀 ${files.length} pages generated (${files.keys.join(', ')}). '
                    'You can view the active page from EDIT, or get them all as a ZIP from DOWNLOAD.'
                : 'Siteniz hazır! 🚀 ${files.length} sayfa üretildi (${files.keys.join(', ')}). '
                    'DÜZENLE\'den aktif sayfayı görebilir, İNDİR\'den hepsini ZIP olarak alabilirsiniz.',
            isBot: true,
          ));
        });
      }
    } on AiRejectedException catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: e.message, isBot: true));
      });
    } on WorkerRateLimitException catch (_) {
      setState(() => _messages.removeLast());
      if (!mounted) return;
      await showWorkerBusyPopup(context);
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: '${isEnglish(context) ? 'An error occurred' : 'Bir hata oluştu'}: $e', isBot: true));
      });
    } finally {
      appState.setGenerating(false);
      _saveMessages();
    }
  }

  Future<void> _clearChat() async {
    if (_messages.isEmpty &&
        context.read<AppState>().generatedCode.isEmpty &&
        context.read<AppState>().generatedFiles.isEmpty) {
      showAppPopup(context, message: 'Silinecek bir şey yok.', icon: 'ℹ️');
      return;
    }
    final confirmed = await showConfirmPopup(
      context,
      title: 'Sohbeti ve Siteyi Sil',
      message: 'Sohbet geçmişi ve üretilmiş site silinecek. Bu işlem geri '
          'alınamaz. Silmek istediğinizden emin misiniz?',
      icon: '🗑️',
      confirmLabel: 'Evet, Sil',
      cancelLabel: 'Vazgeç',
    );
    if (!confirmed) return;
    setState(() {
      _messages.clear();
    });
    await _saveMessages();
    if (mounted) {
      await context.read<AppState>().clearGeneratedSite();
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;
    final appState = context.read<AppState>();
    for (final f in files) {
      appState.addImage(File(f.path));
    }
    if (mounted) {
      showAppPopup(context, message: isEnglish(context) ? '${files.length} image(s) added.' : '${files.length} görsel eklendi.', icon: '🖼️');
    }
  }

  void _openProjectsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProjectsScreen()),
    );
  }

  /// Ana Sayfa artık ayrı bir ekran değil, bu ekranın bir sekmesi;
  /// üst panelin 🏠 ikonu artık navigasyon yerine sekme değiştiriyor.
  void _openQuickTools() {
    if (_activeTab != _MainTab.home) {
      setState(() => _activeTab = _MainTab.home);
    }
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  void _openEditScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditScreen()),
    );
  }

  void _openPreviewScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PreviewScreen()),
    );
  }

  Future<void> _downloadSite() async {
    final appState = context.read<AppState>();
    try {
      if (appState.siteMode == SiteMode.multi) {
        if (appState.generatedFiles.isEmpty) {
          if (mounted) {
            showAppPopup(context,
                message: 'Önce sohbetten bir site oluşturmanız gerekiyor.', icon: 'ℹ️');
          }
          return;
        }
        final saved = await DownloadService.pickAndSaveZip(
            files: appState.generatedFiles);
        if (saved) await appState.markProjectExported();
        if (mounted && saved) {
          showAppPopup(context, message: 'ZIP dosyası cihaza kaydedildi! 📦', icon: '✅');
        }
      } else {
        if (appState.generatedCode.isEmpty) {
          if (mounted) {
            showAppPopup(context,
                message: 'Önce sohbetten bir site oluşturmanız gerekiyor.', icon: 'ℹ️');
          }
          return;
        }
        final saved = await DownloadService.pickAndSaveHtml(
            html: appState.generatedCode);
        if (saved) await appState.markProjectExported();
        if (mounted && saved) {
          showAppPopup(context, message: 'HTML dosyası cihaza kaydedildi! 💾', icon: '✅');
        }
      }
    } catch (e) {
      if (mounted) {
        showAppPopup(context, message: '${isEnglish(context) ? 'Download failed' : 'İndirme başarısız'}: $e', icon: '⚠️');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final appState = context.watch<AppState>();
    context.watch<LocaleController>();
    final isDark = themeController.isDark;

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final bubbleBg = isDark ? AppColors.darkBubbleBg : AppColors.lightBubbleBg;
    final bubbleText =
        isDark ? AppColors.darkBubbleText : AppColors.lightBubbleText;
    final inputBg = isDark ? AppColors.darkInputBg : AppColors.lightInputBg;
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
            _activeTab == _MainTab.home
                ? _buildHomeSiteModeToggle(appState)
                : _buildChatSiteModeToggle(appState),
            const Divider(height: 16, thickness: 0.6),
            Expanded(
              child: _activeTab == _MainTab.home
                  ? _buildHomeTab(appState)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _ChatBubble(
                          message: msg,
                          bubbleBg: bubbleBg,
                          textColor: bubbleText,
                        );
                      },
                    ),
            ),
            if (_activeTab == _MainTab.chat) ...[
              if (appState.pickedImages.isNotEmpty) _buildImageStrip(appState),
              _buildBottomToolbar(),
              _buildInputBar(inputBg, isDark, appState.isGenerating),
            ],
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

  /// "ANA SAYFA" sekmesi: eskiden ayrı bir ekran olan Hızlı Araçlar
  /// (quick_tools_screen.dart) listesi, artık burada gösteriliyor.
  ///
  /// Üstteki "Tek Sayfa / Çok Sayfa" seçiciyle (appState.qtSiteMode, AI
  /// Sohbet'in appState.siteMode'undan bağımsız) entegre: TEK SAYFA
  /// seçiliyken sadece tek sayfalık şablonlar, ÇOK SAYFA seçiliyken sadece
  /// çok sayfalı (şu an: Emlak Sitesi) şablonlar
  /// listelenir. AI Sohbet kartı her zaman en üstte görünür.
  Widget _buildHomeTab(AppState appState) {
    final allCards = <_HomeToolCardData>[
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🔳',
        title: 'QR Kod Oluştur',
        subtitle:
            'Bağlantı, wifi veya metin için QR kod üret (site oluşturmayla aynı puan kotasından düşer).',
        builder: () => const QrGeneratorScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🔗',
        title: 'Biyo Link Sayfası',
        subtitle:
            'Instagram/TikTok bio\'na koyacağın, tüm bağlantılarını tek sayfada toplayan mini site.',
        builder: () => const BioLinkFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🪪',
        title: 'Dijital Kartvizit',
        subtitle: 'İsim, unvan, iletişim ve sosyal linklerinle şık bir dijital kartvizit sayfası.',
        builder: () => const BusinessCardFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '☕',
        title: 'Kafe / Restoran Sitesi',
        subtitle: 'Menü, çalışma saatleri ve konumuyla hazır bir kafe/restoran sitesi.',
        builder: () => const KafeFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '💈',
        title: 'Kuaför / Berber Sitesi',
        subtitle: 'Hizmetler, galeri ve randevu bilgileriyle kuaför/berber sitesi.',
        builder: () => const KuaforFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '💅',
        title: 'Güzellik Salonu Sitesi',
        subtitle: 'Öncesi/sonrası galerisiyle güzellik salonu tanıtım sitesi.',
        builder: () => const BeautySalonFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏥',
        title: 'Klinik / Sağlık Sitesi',
        subtitle: 'Branşlar, hekimler ve iletişim bilgileriyle klinik sitesi.',
        builder: () => const ClinicFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🏋️',
        title: 'Fitness Stüdyosu Sitesi',
        subtitle: 'Program, eğitmen ve ders saatleriyle fitness stüdyosu sitesi.',
        builder: () => const FitnessFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🚗',
        title: 'Oto Yıkama / Servis Sitesi',
        subtitle: 'Hizmet paketleri ve iletişimle oto yıkama/servis sitesi.',
        builder: () => const CarWashFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.multi,
        emoji: '🏠',
        title: 'Emlak Sitesi',
        subtitle: 'İlan listesi ve detay sayfalarıyla çok sayfalı emlak sitesi.',
        builder: () => const RealEstateFormScreen(),
      ),
      _HomeToolCardData(
        mode: SiteMode.single,
        emoji: '🎨',
        title: 'Portfolyo Sitesi',
        subtitle: 'Projelerini/işlerini sergileyeceğin kişisel portfolyo sitesi.',
        builder: () => const PortfolioFormScreen(),
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

  /// Üst panel: başlık + ANA SAYFA/AI SOHBET geçiş butonu + ikon butonları
  /// tek satırda.
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
                'SITORA AI',
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: titleColor,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 14),
              _buildModeToggle(isDark),
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
                icon: Icons.home_outlined,
                background: chipBg,
                iconColor: isDark ? Colors.white70 : Colors.black54,
                onTap: _openQuickTools,
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
                icon: Icons.delete_outline,
                background: AppColors.danger,
                iconColor: Colors.white,
                onTap: _clearChat,
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

  void _openReportSheet() {
    // index.html > collectChatReportContext(): son kullanıcı isteği + son
    // AI cevabını kısa bir bağlam olarak toplayıp mail'e ekliyoruz.
    String? ctx;
    final lastUser = _messages.lastWhere(
      (m) => !m.isBot,
      orElse: () => ChatMessage(text: '', isBot: false),
    );
    final lastBot = _messages.lastWhere(
      (m) => m.isBot,
      orElse: () => ChatMessage(text: '', isBot: true),
    );
    final parts = <String>[];
    if (lastUser.text.isNotEmpty) {
      parts.add('Son kullanıcı isteği: ${lastUser.text.substring(0, lastUser.text.length.clamp(0, 500))}');
    }
    if (lastBot.text.isNotEmpty) {
      parts.add('Son AI cevabı: ${lastBot.text.substring(0, lastBot.text.length.clamp(0, 500))}');
    }
    if (parts.isNotEmpty) ctx = parts.join('\n');

    showReportDialog(
      context: context,
      source: ReportSource.chat,
      chatContext: ctx,
    );
  }

  /// Eskiden "AI CHAT / BUILDER PRO" sekmeli geçiş butonuydu; Builder Pro
  /// kaldırıldığı için artık mevcut sisteme göre yeniden kuruldu:
  /// "ANA SAYFA" (Hızlı Araçlar) ve "AI SOHBET" arasında, aynı buton
  /// mantığıyla (dokununca aktif sekme değişir) geçiş yapılıyor.
  Widget _buildModeToggle(bool isDark) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeSegment(
            label: 'ANA SAYFA',
            tab: _MainTab.home,
            isDark: isDark,
          ),
          _modeSegment(
            label: 'AI SOHBET',
            tab: _MainTab.chat,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _modeSegment({
    required String label,
    required _MainTab tab,
    required bool isDark,
  }) {
    final selected = _activeTab == tab;
    return GestureDetector(
      onTap: () {
        if (_activeTab != tab) setState(() => _activeTab = tab);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            t(context, label),
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white54 : Colors.black54),
              fontWeight: FontWeight.bold,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  /// Ana Sayfa sekmesindeki "Tek Sayfa / Çok Sayfa" seçici — sadece
  /// [_buildHomeTab]'daki şablon kartlarını filtreler. appState.qtSiteMode'u
  /// kullanır; AI Sohbet'in üretim moduyla (appState.siteMode) TAMAMEN AYRI
  /// bir state'tir, birbirini etkilemez.
  Widget _buildHomeSiteModeToggle(AppState appState) {
    return _siteModeToggleRow(
      currentMode: appState.qtSiteMode,
      onChanged: appState.setQtSiteMode,
      singleSubtitle: 'Tek sayfalık şablonlar',
      multiSubtitle: 'Çok sayfalı şablonlar (Emlak)',
    );
  }

  /// AI Sohbet sekmesindeki "Tek Sayfa (Biolink) / Çok Sayfa (Zip)" — A/B
  /// modu seçici. Sadece görünüm/etiket değişmiyor: bu seçime göre
  /// _sendMessage() farklı bir GeminiService fonksiyonunu (generateSiteCode /
  /// generateMultiPageSite) çağırır ve İNDİR butonu farklı bir çıktı
  /// (html / zip) üretir. appState.siteMode kullanır; Ana Sayfa'nın şablon
  /// filtresiyle (appState.qtSiteMode) TAMAMEN AYRI bir state'tir.
  Widget _buildChatSiteModeToggle(AppState appState) {
    return _siteModeToggleRow(
      currentMode: appState.siteMode,
      onChanged: appState.setSiteMode,
      singleSubtitle: 'Biolink / kartvizit — HTML indir',
      multiSubtitle: 'Bağlantılı sayfalar — ZIP indir',
    );
  }

  Widget _siteModeToggleRow({
    required SiteMode currentMode,
    required ValueChanged<SiteMode> onChanged,
    required String singleSubtitle,
    required String multiSubtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _siteModeChip(
              currentMode: currentMode,
              onChanged: onChanged,
              mode: SiteMode.single,
              title: 'Tek Sayfa',
              subtitle: singleSubtitle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _siteModeChip(
              currentMode: currentMode,
              onChanged: onChanged,
              mode: SiteMode.multi,
              title: 'Çok Sayfa',
              subtitle: multiSubtitle,
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
                label: 'Kılavuz',
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
                label: 'Puan Ver',
                emoji: '⭐',
                borderColor: AppColors.accentOrange,
                textColor: AppColors.accentOrange,
                height: 38,
                fontSize: 12.5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: () {},
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
            '${appState.credits} /${appState.maxCredits}',
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

  Widget _buildImageStrip(AppState appState) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: appState.pickedImages.length,
        itemBuilder: (context, index) {
          final file = appState.pickedImages[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file, width: 60, height: 60, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => appState.removeImage(file),
                    child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.danger,
                      child: Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomToolbar() {
    const double toolbarHeight = 44;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: PillButton(
              label: 'ÖN İZLEME',
              borderColor: AppColors.accentRed,
              textColor: AppColors.accentRed,
              height: toolbarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onTap: _openPreviewScreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PillButton(
              label: 'DÜZENLE',
              borderColor: AppColors.accentOrange,
              textColor: AppColors.accentOrange,
              height: toolbarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onTap: _openEditScreen,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _pickImages,
              child: Container(
                width: 52,
                height: toolbarHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.accentPurple, width: 1.4),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.accentPurple),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PillButton(
              label: 'İNDİR',
              borderColor: AppColors.accentBlue,
              textColor: AppColors.accentBlue,
              height: toolbarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onTap: _downloadSite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(Color inputBg, bool isDark, bool isGenerating) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.only(left: 18, right: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _inputController,
                  enabled: !isGenerating,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: t(context, 'Hayalindeki Siteyi Anlat...'),
                    hintStyle: TextStyle(
                      color: (isDark ? Colors.white : Colors.black54)
                          .withOpacity(0.5),
                      fontFamily: 'monospace',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: isGenerating
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accentCyan),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: AppColors.accentCyan),
                      onPressed: _sendMessage,
                    ),
            ),
          ],
        ),
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

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Color bubbleBg;
  final Color textColor;

  const _ChatBubble({
    required this.message,
    required this.bubbleBg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isBot ? 4 : 20),
            bottomRight: Radius.circular(message.isBot ? 20 : 4),
          ),
          border: message.isBot
              ? Border(left: BorderSide(color: AppColors.accentBlue, width: 3))
              : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontFamily: 'monospace',
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
