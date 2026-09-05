import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../templates/demo_templates.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// 27.08.2026 eklendi — "Ön izleme" ekranı: kullanıcı bir şablonun (bkz.
/// home_screen.dart'taki göz ikonu) forma HİÇ girmeden nasıl göründüğünü
/// görebilir. Sabit örnek verilerle (bkz. templates/demo_templates.dart)
/// tam bir site üretilir; kullanıcı burada tema/tipografi/yoğunluğu da
/// CANLI deneyebilir — her seçim değişiminde HTML yerel olarak (ağa hiç
/// gitmeden) yeniden üretilip WebView'a yeniden yüklenir.
///
/// Alttaki "Bu şablonla oluştur" butonuna basınca, seçtiği tema/font/
/// yoğunlukla ÖNCEDEN DOLU şekilde gerçek form ekranı açılır (bkz.
/// TemplateDemoConfig.openForm) — kullanıcı burada beğendiği görsel
/// kimliği forma taşımış olur, sıfırdan seçmesi gerekmez.
///
/// Bu ekran salt-okunurdur: fotoğraf değiştirme, düzenleme, yayınlama,
/// rozet vb. HİÇBİRİ yok — sadece "nasıl görünür" sorusuna cevap verir.
class TemplatePreviewScreen extends StatefulWidget {
  const TemplatePreviewScreen({super.key, required this.config});

  final TemplateDemoConfig config;

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  String _themeId = ThemePickerField.options.first['id']!;
  String _fontPackageId = TypographyPickerField.fontPackageOptions.first['id']!;
  String _density = 'normal';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // 27.08.2026 düzeltildi — üretilen sitelerin çoğu, içerik
      // bölümlerini scroll'da göstermek için IntersectionObserver
      // kullanıyor (bkz. shared_html_blocks.dart > '.section, .reveal
      // { opacity: 0; }' + '.in-view' sınıfı JS ile ekleniyor). JS
      // KAPALIYSA bu sınıf hiç eklenmiyor ve neredeyse TÜM içerik
      // opacity:0'da kalıp "boş sayfa" gibi görünüyor — sadece sabit
      // (JS'siz) konumlanan WhatsApp ikonu görünür kalıyor. Bu yüzden
      // gerçek preview_screen.dart ile aynı şekilde JS açık olmalı.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _reload();
  }

  void _reload() {
    setState(() => _loading = true);
    final html = widget.config.buildHtml(
      themeId: _themeId,
      fontPackageId: _fontPackageId,
      density: _density,
    );
    _controller.loadHtmlString(html);
  }

  void _openRealForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.config.openForm(
          themeId: _themeId,
          fontPackageId: _fontPackageId,
          density: _density,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${t(context, widget.config.title)} • ${t(context, 'Ön İzleme')}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.config.showTypography
                          ? t(context, 'Bu, örnek verilerle oluşturulmuş bir gösterimdir. Aşağıdan tema ve tipografiyi değiştirip nasıl göründüğünü deneyebilirsin.')
                          : t(context, 'Bu, örnek verilerle oluşturulmuş bir gösterimdir. Aşağıdan temayı değiştirip nasıl göründüğünü deneyebilirsin.'),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                    const SizedBox(height: 16),
                    ThemePickerField(
                      initialThemeId: _themeId,
                      onChanged: (v) {
                        _themeId = v;
                        _reload();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (widget.config.showTypography) ...[
                      TypographyPickerField(
                        initialFontPackageId: _fontPackageId,
                        initialDensity: _density,
                        onFontPackageChanged: (v) {
                          _fontPackageId = v;
                          _reload();
                        },
                        onDensityChanged: (v) {
                          _density = v;
                          _reload();
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    PillButton(
                      label: t(context, 'Bu şablonla oluştur'),
                      borderColor: AppTheme.accentBlue,
                      textColor: AppTheme.accentBlue,
                      onTap: _openRealForm,
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
}
