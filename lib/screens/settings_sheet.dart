import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/app_state.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/ai_edit_dialog.dart';
import '../widgets/pill_button.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// Gizlilik Politikası ve Kullanım Şartları sayfalarının canlı adresleri.
/// Ayarlar ekranındaki linkler ve açılış onay popup'ı bu adresleri kullanır.
const String kPrivacyPolicyUrl =
    'https://filinta01453-ui.github.io/sitora-ai-legal/Gizlilik_Politikasi.html';
const String kTermsOfUseUrl =
    'https://filinta01453-ui.github.io/sitora-ai-legal/Kullanim_Sartlari.html';

Future<void> openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _keyController;
  bool _obscureKey = true;
  bool _loadingModels = false;
  String? _selectedModelDropdown;
  List<String> _fetchedModels = [];

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _keyController = TextEditingController(text: appState.apiKey ?? '');
    _selectedModelDropdown = appState.selectedModel;
    _fetchedModels = appState.availableModels;
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      _showSnack('Önce bir API anahtarı girmelisiniz.', icon: '🔑');
      return;
    }
    setState(() => _loadingModels = true);
    try {
      final models = await GeminiService.fetchModels(key);
      setState(() {
        _fetchedModels = models.isNotEmpty ? models : _fetchedModels;
        if (!_fetchedModels.contains(_selectedModelDropdown)) {
          _selectedModelDropdown = _fetchedModels.first;
        }
      });
    } catch (e) {
      _showSnack('${isEnglish(context) ? 'Could not fetch models' : 'Modeller alınamadı'}: $e', icon: '⚠️');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _showSnack(String msg, {String icon = 'ℹ️'}) {
    showAppPopup(context, message: t(context, msg), icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDark;
    final appState = context.watch<AppState>();
    context.watch<LocaleController>();

    final bg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF0F2F5);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.accentCyan.withOpacity(0.6)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'API Ayarları'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentBlue,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                LanguageToggleButton(background: fieldBg, isDark: isDark),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _linkChip(t(context, 'Gizlilik Politikası'), subTextColor,
                    onTap: () => openLegalUrl(kPrivacyPolicyUrl)),
                _linkChip(t(context, 'Kullanım Şartları'), subTextColor,
                    onTap: () => openLegalUrl(kTermsOfUseUrl)),
              ],
            ),
            const SizedBox(height: 20),
            Text(t(context, 'Sağlayıcı Seçimi:'),
                style: TextStyle(color: subTextColor, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(t(context, 'Gemini (Google)'),
                  style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontFamily: 'monospace')),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(context, '🚀 Nasıl Gemini Key Alınır?'),
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  Text(t(context, '1. Google AI Studio adr. git.'),
                      style: TextStyle(color: subTextColor, fontFamily: 'monospace')),
                  Text(t(context, '2. "Create API Key" butonuna bas.'),
                      style: TextStyle(color: subTextColor, fontFamily: 'monospace')),
                  Text(t(context, '3. Kopyaladığın keyi kutuya yapıştır.'),
                      style: TextStyle(color: subTextColor, fontFamily: 'monospace')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _keyController,
                obscureText: _obscureKey,
                style: TextStyle(color: textColor, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: t(context, 'API Key...'),
                  hintStyle: TextStyle(color: subTextColor),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: subTextColor,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(t(context, 'Model Seçimi:'),
                style: TextStyle(color: subTextColor, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _fetchedModels.contains(_selectedModelDropdown)
                            ? _selectedModelDropdown
                            : null,
                        hint: Text(t(context, 'Model Seçiniz...'),
                            style: TextStyle(color: subTextColor, fontFamily: 'monospace')),
                        dropdownColor: fieldBg,
                        style: TextStyle(color: textColor, fontFamily: 'monospace'),
                        items: _fetchedModels
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedModelDropdown = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loadingModels ? null : _fetchModels,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accentBlue),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                  child: _loadingModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(t(context, 'Modelleri Getir'),
                          style: TextStyle(
                              color: AppColors.accentBlue, fontFamily: 'monospace')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final key = _keyController.text.trim();
                      if (key.isEmpty) {
                        _showSnack('API anahtarı boş olamaz.', icon: '⚠️');
                        return;
                      }
                      await appState.saveApiKey(key);
                      if (_selectedModelDropdown != null) {
                        await appState.setModel(_selectedModelDropdown!);
                      }
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      showAppPopup(context,
                          message: t(context, 'API anahtarınız kaydedildi! ✅'), icon: '✅');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(t(context, 'Kaydet'),
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await appState.deleteApiKey();
                      _keyController.clear();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(t(context, "Key'i Sil"),
                        style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: subTextColor.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(t(context, 'Kapat'),
                    style: TextStyle(color: textColor, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkChip(String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontFamily: 'monospace')),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}
