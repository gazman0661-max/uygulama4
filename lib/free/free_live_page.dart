import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/free_plan_restriction_service.dart';
import '../templates/html/free_builder_html_generator.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import 'free_live_preview.dart';
import 'free_model.dart';

/// Canlı Önizleme AYRI bir sayfa olarak açılır (Navigator.push): geri tuşu bu sayfayı
/// kapatıp editöre, KALDIĞIN YERDEN döner — editör hiç yok edilmez.
///
/// Sağ üstteki tema düğmesi, TÜM siteye (bütün sayfalara) uygulanan site temasını ve
/// yazı tipini değiştirir; seçim kapanınca önizleme yeniden üretilir.
class FreeLivePage extends StatefulWidget {
  final FreeSite site; // editörle AYNI nesne: değişiklik editöre de yansır
  final String startFile;
  final bool premium;
  final VoidCallback onSiteChanged;

  const FreeLivePage({
    super.key,
    required this.site,
    required this.startFile,
    required this.premium,
    required this.onSiteChanged,
  });

  @override
  State<FreeLivePage> createState() => _FreeLivePageState();
}

class _FreeLivePageState extends State<FreeLivePage> {
  Map<String, String>? _files;
  String? _error;
  int _key = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    try {
      _files = FreePlanRestrictionService.runGeneration(
        widget.premium,
        () => generateFreeBuilderSite(widget.site),
      );
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    _key++;
  }

  Future<void> _openTheme() async {
    final site = widget.site;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ThemePickerField(
            initialThemeId: site.themeId,
            initialCustomTheme: site.customTheme,
            onChanged: (v) => site.themeId = v,
            onCustomThemeChanged: (v) => site.customTheme = v,
          ),
          const SizedBox(height: 16),
          TypographyPickerField(
            initialFontPackageId: site.fontPackageId,
            initialCustomFontPackage: site.customFontPackage,
            initialDensity: site.density,
            onFontPackageChanged: (v) => site.fontPackageId = v,
            onCustomFontPackageChanged: (v) => site.customFontPackage = v,
            onDensityChanged: (v) => site.density = v,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t(context, 'Tamam'))),
        ]),
      ),
    );
    if (!mounted) return;
    setState(_generate);
    widget.onSiteChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'Canlı önizleme')),
        actions: [
          IconButton(
            tooltip: t(context, 'Tema ve yazı tipi'),
            icon: const Icon(Icons.palette_outlined),
            onPressed: _openTheme,
          ),
        ],
      ),
      body: _files == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${t(context, 'Önizleme hazırlanamadı')}: ${_error ?? ''}'),
              ),
            )
          : FreeLivePreview(key: ValueKey(_key), files: _files!, startFile: widget.startFile),
    );
  }
}
