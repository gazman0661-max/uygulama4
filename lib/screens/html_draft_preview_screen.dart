import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../localization/app_strings.dart';

class HtmlDraftPreviewScreen extends StatefulWidget {
  final String html;
  const HtmlDraftPreviewScreen({super.key, required this.html});

  @override
  State<HtmlDraftPreviewScreen> createState() => _HtmlDraftPreviewScreenState();
}

class _HtmlDraftPreviewScreenState extends State<HtmlDraftPreviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (!request.isMainFrame || url.startsWith('about:') || url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'Önizleme'))),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
