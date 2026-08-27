import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/pill_button.dart';
import '../services/ai_settings_service.dart';
import '../services/gemini_service.dart';

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

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDark;
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
                    t(context, 'Ayarlar'),
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
            const SizedBox(height: 16),
            _AiSettingsSection(
              fieldBg: fieldBg,
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 24),
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

/// "Ayarlar" içindeki AI bölümü — kullanıcının kendi Gemini API anahtarını
/// girdiği alan, altında hangi modelin seçili olduğunu gösteren liste, ve
/// yanında Google'ın o anki güncel model listesini çeken "Modelleri Çek"
/// butonu. Uygulama artık kişisel kullanım için olduğundan bu bilgiler
/// SADECE cihazda saklanır (bkz. ai_settings_service.dart), hiçbir sunucuya
/// gönderilmez.
class _AiSettingsSection extends StatefulWidget {
  final Color fieldBg;
  final Color textColor;
  final Color subTextColor;

  const _AiSettingsSection({
    required this.fieldBg,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  State<_AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends State<_AiSettingsSection> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _fetchingModels = false;
  List<String> _models = [];
  String? _selectedModel;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final key = await AiSettingsService.instance.getApiKey();
    final model = await AiSettingsService.instance.getModel();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = key ?? '';
      _selectedModel = model;
      if (model != null && model.isNotEmpty) _models = [model];
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey(String value) async {
    await AiSettingsService.instance.setApiKey(value);
  }

  Future<void> _fetchModels() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _fetchError = t(context, 'Önce bir Gemini API anahtarı girin.'));
      return;
    }
    await _saveApiKey(apiKey);
    setState(() {
      _fetchingModels = true;
      _fetchError = null;
    });
    try {
      final models = await GeminiService.fetchAvailableModels(apiKey);
      if (!mounted) return;
      setState(() {
        _models = models;
        // Daha önce seçilmiş bir model listede hâlâ varsa onu koru,
        // yoksa hiçbir şey otomatik seçilmez — kullanıcı kendisi seçsin.
        if (_selectedModel != null && !models.contains(_selectedModel)) {
          _selectedModel = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _fetchError = e.toString());
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _selectModel(String model) async {
    setState(() => _selectedModel = model);
    await AiSettingsService.instance.setModel(model);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: widget.fieldBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, 'Gemini API Anahtarı'),
            style: TextStyle(
              color: widget.textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            style: TextStyle(color: widget.textColor, fontFamily: 'monospace', fontSize: 13),
            onChanged: _saveApiKey,
            decoration: InputDecoration(
              hintText: 'AIza...',
              hintStyle: TextStyle(color: widget.subTextColor.withOpacity(0.6)),
              filled: true,
              fillColor: Colors.black12,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: widget.subTextColor,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  t(context, 'Model Listesi'),
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              PillButton(
                label: _fetchingModels ? t(context, 'Çekiliyor...') : t(context, 'Modelleri Çek'),
                emoji: '🔄',
                borderColor: AppColors.accentCyan,
                textColor: AppColors.accentCyan,
                height: 34,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onTap: _fetchingModels ? null : _fetchModels,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_fetchError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _fetchError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (_models.isEmpty)
            Text(
              t(context, 'Henüz model listesi çekilmedi.'),
              style: TextStyle(color: widget.subTextColor, fontSize: 12),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _models.length,
                itemBuilder: (context, i) {
                  final m = _models[i];
                  final selected = m == _selectedModel;
                  return ListTile(
                    dense: true,
                    title: Text(
                      m,
                      style: TextStyle(
                        color: selected ? AppColors.accentCyan : widget.textColor,
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: AppColors.accentCyan, size: 18)
                        : null,
                    onTap: () => _selectModel(m),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
