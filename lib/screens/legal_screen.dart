import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../localization/app_strings.dart';
import '../widgets/ui_kit.dart';

enum LegalKind { terms, privacy }

/// Yayinlanan hukuki sayfalarin adresleri (GitHub Pages).
/// Sayfa adresi degisirse SADECE burayi guncelle. Play Console'daki gizlilik
/// politikasi alani ve Google Cloud > Branding ayni adresleri kullanmali.
class LegalLinks {
  LegalLinks._();
  static const String host = 'filinta01453-ui.github.io';
  static const String privacy = 'https://filinta01453-ui.github.io/world-merge-legal/privacy-policy.html';
  static const String terms = 'https://filinta01453-ui.github.io/world-merge-legal/terms-of-service.html';

  static String of(LegalKind k) => k == LegalKind.terms ? terms : privacy;
}

/// Kullanim Sartlari / Gizlilik Politikasi ekrani: yayindaki web sayfasini
/// uygulamanin ICINDE (WebView) acar. Baglanti yoksa tekrar dene butonu gosterir.
class LegalScreen extends StatefulWidget {
  final LegalKind kind;
  const LegalScreen({super.key, required this.kind});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;
  bool _canGoBack = false;

  bool get _tr => AppStrings.instance.language == AppLanguage.tr;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // Sayfalar statik HTML; JavaScript'e gerek yok (daha guvenli).
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0xFFFFF3E0))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) async {
            final back = await _controller.canGoBack();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _canGoBack = back;
            });
          },
          onWebResourceError: (e) {
            // Sadece ana sayfa yuklenemezse hata ekrani goster.
            if (e.isForMainFrame == false) return;
            if (!mounted) return;
            setState(() {
              _failed = true;
              _loading = false;
            });
          },
          // Yalnizca https baglantilari uygulama icinde acilir (mailto vb. engellenir).
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            if (uri != null && uri.scheme == 'https') return NavigationDecision.navigate;
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(LegalLinks.of(widget.kind)));
  }

  void _retry() {
    setState(() {
      _failed = false;
      _loading = true;
    });
    _controller.loadRequest(Uri.parse(LegalLinks.of(widget.kind)));
  }

  @override
  Widget build(BuildContext context) {
    final isTerms = widget.kind == LegalKind.terms;
    final title = isTerms ? (_tr ? 'Kullanım Şartları' : 'Terms of Use') : (_tr ? 'Gizlilik Politikası' : 'Privacy Policy');
    return PopScope(
      // Sayfa icinde geri gidilebiliyorsa once oraya don, yoksa ekrandan cik.
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: GameScaffold(
        title: title,
        showCurrency: false,
        body: Stack(
          children: [
            if (!_failed) WebViewWidget(controller: _controller),
            if (_loading && !_failed) const Center(child: CircularProgressIndicator()),
            if (_failed)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 52, color: Color(0xFF4A2C0A)),
                      const SizedBox(height: 14),
                      Text(
                        _tr
                            ? 'Sayfa yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.'
                            : 'The page could not be loaded. Check your internet connection and try again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.35, color: Color(0xFF4A2C0A), fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),
                      CandyButton(
                        style: CandyStyle.orange,
                        height: 50,
                        fontSize: 17,
                        label: _tr ? 'Tekrar dene' : 'Try again',
                        onTap: _retry,
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
