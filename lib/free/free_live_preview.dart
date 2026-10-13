import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/download_service.dart';

/// Editör içi "Canlı Önizleme": sayfanın GERÇEK HTML çıktısını (wrapPageHtml)
/// tek bir WebView'da gösterir. Yeni ekran açmaz.
///
/// preview_screen.dart ile aynı kural: HTML ASLA loadHtmlString ile gönderilmez
/// (base64 görseller Binder limitini aşıp native çökmeye yol açıyordu) —
/// dosyaya yazılıp loadFile ile açılır.
class FreeLivePreview extends StatefulWidget {
  /// dosya adı -> html (generateFreeBuilderSite çıktısı)
  final Map<String, String> files;
  final String startFile;
  const FreeLivePreview({super.key, required this.files, required this.startFile});

  @override
  State<FreeLivePreview> createState() => _FreeLivePreviewState();
}

class _FreeLivePreviewState extends State<FreeLivePreview> {
  late final WebViewController _c;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
    // Önizleme sayfası kamera/mikrofon/konum izni isteyemesin.
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      p.setOnPlatformPermissionRequest((r) => r.deny());
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final files = _withViewport(widget.files);
      final index = await DownloadService.writeFilesForPreview(files);
      final dir = File(index).parent.path;
      final target = files.containsKey(widget.startFile) ? '$dir/${widget.startFile}' : index;
      await _c.loadFile(target);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Map<String, String> _withViewport(Map<String, String> files) {
    const tag = '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
    return files.map((k, v) {
      final low = v.toLowerCase();
      if (low.contains('name="viewport"') || low.contains("name='viewport'")) return MapEntry(k, v);
      return MapEntry(k, v.replaceFirst('<head>', '<head>\n$tag'));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    return Stack(children: [
      WebViewWidget(controller: _c),
      if (_loading) const Center(child: CircularProgressIndicator()),
    ]);
  }
}
