import 'dart:async';
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
import '../services/ai_response_utils.dart';
import '../services/download_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/ai_edit_dialog.dart' show showAppPopup;
import '../widgets/confirm_popup.dart';
import '../widgets/ai_busy_popup.dart';
import '../widgets/language_picker_popup.dart';
import '../widgets/legal_consent_popup.dart';
import '../localization/locale_controller.dart';
import '../localization/app_strings.dart';
import 'settings_sheet.dart';
import 'edit_screen.dart';
import 'preview_screen.dart';
import 'projects_screen.dart';

// NOT: Bu dosya, orijinal Sitora projesindeki lib/screens/home_screen.dart
// dosyasından türetildi. Ana uygulamada tek bir HomeScreen içinde iki
// sekme (ANA SAYFA / Hızlı Araçlar formları ve AI SOHBET) bulunuyordu.
// Bu proje SADECE "AI SOHBET" tarafını içerir: form/şablon ekranları,
// bunlara özel yerel HTML üretim yardımcıları ve alan (field) widget'ları
// bilinçli olarak çıkarıldı. Aşağıdaki mantık orijinaliyle birebir aynı;
// sadece ANA SAYFA sekmesi ve aralarındaki geçiş butonu kaldırıldı — bu
// ekran artık uygulamanın TEK ana ekranı.

class ChatMessage {
  final String text;
  final bool isBot;
  ChatMessage({required this.text, required this.isBot});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = [];

  static const _legalConsentPrefsKey = 'legal_terms_accepted_v1';

  // Uygulama kapatılıp açıldığında sohbet ekranındakiler silinmesin diye
  // mesajlar SharedPreferences'ta saklanır; kullanıcı sadece 🗑️ SİL
  // butonuna basıp onaylarsa temizlenir.
  static const _chatPrefsKey = 'chat_messages_v1';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Uygulama ilk kez açıldığında gösterilmesi gereken zorunlu dil
    // seçimi ve KVKK/Kullanım Şartları onay popup'ları buradan tetiklenir.
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

    setState(() {
      _messages.add(ChatMessage(text: text, isBot: false));
      _inputController.clear();
    });

    appState.setGenerating(true);
    setState(() {
      _messages.add(ChatMessage(text: t(context, 'Siteniz oluşturuluyor... ⏳'), isBot: true));
    });

    try {
      // Tüm istekler artık doğrudan Gemini'ye (kendi API anahtarınla) gider.
      if (appState.siteMode == SiteMode.single) {
        final code = await GeminiService.generateSiteCode(
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
        final files = await GeminiService.generateMultiPageSite(
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
    } on GeminiNotConfiguredException catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: e.message, isBot: true));
      });
    } on AiRejectedException catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: e.message, isBot: true));
      });
    } on GeminiRateLimitException catch (_) {
      setState(() => _messages.removeLast());
      if (!mounted) return;
      await showAiBusyPopup(context);
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
      title: t(context, 'Sohbeti ve Siteyi Sil'),
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
            _buildSiteModeToggle(appState),
            const Divider(height: 16, thickness: 0.6),
            Expanded(
              child: ListView.builder(
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
            if (appState.pickedImages.isNotEmpty) _buildImageStrip(appState),
            _buildBottomToolbar(),
            _buildInputBar(inputBg, isDark, appState.isGenerating),
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
            ],
          ),
        ),
      ),
    );
  }

  /// "Tek Sayfa (Biolink) / Çok Sayfa (Zip)" — A/B modu seçici. Sadece
  /// görünüm/etiket değişmiyor: bu seçime göre _sendMessage() farklı bir
  /// GeminiService fonksiyonunu (generateSiteCode / generateMultiPageSite)
  /// çağırır ve İNDİR butonu farklı bir çıktı (html / zip) üretir.
  Widget _buildSiteModeToggle(AppState appState) {
    final currentMode = appState.siteMode;
    final onChanged = appState.setSiteMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _siteModeChip(
              currentMode: currentMode,
              onChanged: onChanged,
              mode: SiteMode.single,
              title: t(context, 'Tek Sayfa'),
              subtitle: t(context, 'Biolink / kartvizit — HTML indir'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _siteModeChip(
              currentMode: currentMode,
              onChanged: onChanged,
              mode: SiteMode.multi,
              title: t(context, 'Çok Sayfa'),
              subtitle: t(context, 'Bağlantılı sayfalar — ZIP indir'),
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
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.accentCyan : Colors.grey,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.withOpacity(0.85)),
            ),
          ],
        ),
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
              label: t(context, 'ÖN İZLEME'),
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
              label: t(context, 'DÜZENLE'),
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
              label: t(context, 'İNDİR'),
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
