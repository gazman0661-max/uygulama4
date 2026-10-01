import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../templates/demo_templates.dart';
import '../widgets/pill_button.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/layout_style_picker_field.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

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
  late String _layoutStyle = widget.config.initialLayoutStyle;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _blockExternalLinks();
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _reload();
  }

  Future<void> _blockExternalLinks() async {
    const js = r"""
(function(){
  var anchors = Array.prototype.slice.call(document.querySelectorAll('a[href]'));
  anchors.forEach(function(a){
    if(a.getAttribute('data-astro-link-bound')) return;
    a.setAttribute('data-astro-link-bound', '1');
    a.addEventListener('click', function(ev){
      var href = (a.getAttribute('href') || '').trim();
      var isExternal = /^(https?:|tel:|mailto:|sms:|geo:|whatsapp:|market:|intent:)/i.test(href);
      if (isExternal) {
        ev.preventDefault();
        ev.stopPropagation();
      }
    }, true);
  });
})();
""";
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
    }
  }

  void _reload() {
    setState(() => _loading = true);
    final html = widget.config.buildHtml(
      themeId: _themeId,
      fontPackageId: _fontPackageId,
      density: _density,
      layoutStyle: _layoutStyle,
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
          layoutStyle: _layoutStyle,
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
                    if (widget.config.showLayoutStyle) ...[
                      const SizedBox(height: 16),
                      LayoutStylePickerField(
                        initialLayoutStyle: _layoutStyle,
                        onChanged: (v) {
                          _layoutStyle = v;
                          _reload();
                        },
                      ),
                    ],
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
