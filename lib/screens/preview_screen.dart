import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import '../theme/app_theme.dart';
import '../services/report_service.dart';
import '../services/download_service.dart';
import '../services/hosting_service.dart';
import '../services/watermark_service.dart';
import '../services/billing_service.dart';
import '../services/auth_service.dart';
import '../services/image_compress_service.dart';
import '../services/analytics_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/confirm_popup.dart';
import '../services/free_site_converter.dart';
import '../widgets/app_popup.dart';
import '../widgets/report_dialog.dart';
import '../widgets/login_gate.dart';
import '../widgets/publish_sheet.dart';
import '../widgets/publish_paywall_sheet.dart';
import '../widgets/download_purchase_sheet.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import 'form_screen_router.dart';
import 'free_site_form_screen.dart';
import 'subscription_plans_screen.dart';

class QuickToolsPreviewScreen extends StatelessWidget {
  const QuickToolsPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PreviewScreenCore();
  }
}

class _PreviewScreenCore extends StatefulWidget {
  const _PreviewScreenCore();

  @override
  State<_PreviewScreenCore> createState() => _PreviewScreenCoreState();
}

class _PreviewScreenCoreState extends State<_PreviewScreenCore> {
  late final WebViewController _controller;
  bool _loading = true;

  String? _previewDirPath;

  SiteMode _slotSiteMode(AppState appState) => appState.qtSiteMode;
  String _slotCode(AppState appState) => appState.qtGeneratedCode;
  Map<String, String> _slotFiles(AppState appState) => appState.qtGeneratedFiles;
  String? _slotActiveFile(AppState appState) => appState.qtActiveFileName;
  void _slotSetActiveFile(AppState appState, String fileName) =>
      appState.setQtActiveFile(fileName);
  void _slotUpdateCode(AppState appState, String code) =>
      appState.updateQtGeneratedCode(code);
  void _slotUpdateActiveFileContent(AppState appState, String content) =>
      appState.updateQtActiveFileContent(content);

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AstroImagePicker',
        onMessageReceived: (msg) {
          final idx = int.tryParse(msg.message);
          if (idx != null) _pickImageForGallery(idx);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (_slotSiteMode(appState) == SiteMode.multi) {
              final name = url.split('/').isNotEmpty ? url.split('/').last : null;
              if (name != null &&
                  name.isNotEmpty &&
                  _slotFiles(appState).containsKey(name)) {
                _slotSetActiveFile(appState, name);
              }
            }
            await _injectPageScripts();
            if (mounted) setState(() => _loading = false);
          },
        ),
      );

    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setOnPlatformPermissionRequest(
        (request) => request.deny(),
      );
    }

    _loadInitialContent(appState);
  }

  Future<void> _loadInitialContent(AppState appState) async {
    if (_slotSiteMode(appState) == SiteMode.multi) {
      if (_slotFiles(appState).isEmpty) {
        await _controller.loadHtmlString(_placeholderHtml);
        return;
      }
      final fixedFiles = _ensureViewportMetaForFiles(_slotFiles(appState));
      final indexPath =
          await DownloadService.writeFilesForPreview(fixedFiles);
      _previewDirPath = File(indexPath).parent.path;
      await _controller.loadFile(indexPath);
    } else {
      final code = _slotCode(appState);
      if (code.isEmpty) {
        await _controller.loadHtmlString(_placeholderHtml);
        return;
      }
      final safeCode = _ensureViewportMeta(code);
      final indexPath =
          await DownloadService.writeFilesForPreview({'index.html': safeCode});
      _previewDirPath = File(indexPath).parent.path;
      await _controller.loadFile(indexPath);
    }
  }

  Future<void> _convertToFreeSite() async {
    final appState = context.read<AppState>();
    final data = convertSectorToFreeSiteData(appState.qtCurrentKind, appState.qtFormData);
    if (data == null) {
      showAppPopup(context, message: t(context, 'Bu site türü Serbest Siteye çevrilemiyor.'));
      return;
    }
    final ok = await showConfirmPopup(
      context,
      title: 'Serbest Siteye çevir',
      message: 'Sitenin bir KOPYASI Serbest Site olarak açılır; bu site aynen kalır. Menü, ilan, portfolyo işleri gibi sektöre özel bölümler taşınmaz.',
      icon: '🧩',
      confirmLabel: 'Kopyala ve aç',
      cancelLabel: 'Vazgeç',
      confirmColor: AppColors.accentBlue,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => FreeSiteFormScreen(initialData: data)),
    );
  }

  Future<void> _openEditForm() async {
    final appState = context.read<AppState>();
    if (!appState.qtCurrentEditableInApp) {
      showAppPopup(context, message: t(context, 'Bu site bu hesaba özel hazırlanmıştır ve uygulama içinden düzenlenemez.'));
      return;
    }
    final kind = appState.qtCurrentKind;
    if (kind == null) {
      showAppPopup(context, message: t(context, 'Bu site formdan düzenlenemiyor.'));
      return;
    }
    final screen = formScreenForKind(
      kind,
      initialData: appState.qtFormData,
      isEditing: true,
    );
    if (screen == null) {
      showAppPopup(context, message: t(context, 'Bu site türü için düzenleme ekranı yok.'));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadInitialContent(context.read<AppState>());
    if (mounted) setState(() => _loading = false);
  }

  String _ensureViewportMeta(String html) {
    if (html.toLowerCase().contains('name="viewport"') ||
        html.toLowerCase().contains("name='viewport'")) {
      return html;
    }
    const viewportTag =
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
    if (html.contains('<head>')) {
      return html.replaceFirst('<head>', '<head>\n$viewportTag');
    }
    final headOpenMatch = RegExp(r'<head[^>]*>').firstMatch(html);
    if (headOpenMatch != null) {
      final insertAt = headOpenMatch.end;
      return html.substring(0, insertAt) +
          '\n$viewportTag' +
          html.substring(insertAt);
    }
    if (html.contains('<html>')) {
      return html.replaceFirst('<html>', '<html>\n<head>$viewportTag</head>');
    }
    return html;
  }

  Map<String, String> _ensureViewportMetaForFiles(
      Map<String, String> files) {
    final fixed = <String, String>{};
    files.forEach((name, content) {
      fixed[name] = name.toLowerCase().endsWith('.html')
          ? _ensureViewportMeta(content)
          : content;
    });
    return fixed;
  }

  String _currentCode(AppState appState) {
    if (_slotSiteMode(appState) == SiteMode.multi) {
      final active = _slotActiveFile(appState);
      if (active == null) return '';
      return _slotFiles(appState)[active] ?? '';
    }
    return _slotCode(appState);
  }

  Future<void> _persistCode(AppState appState, String newCode) async {
    if (_slotSiteMode(appState) == SiteMode.multi) {
      _slotUpdateActiveFileContent(appState, newCode);
      final active = _slotActiveFile(appState);
      if (active != null && _previewDirPath != null) {
        await File('$_previewDirPath/$active').writeAsString(newCode);
      }
    } else {
      _slotUpdateCode(appState, newCode);
    }
  }

  String get _placeholderHtml {
    final msg = isEnglish(context)
        ? 'No site generated yet. Please go back and fill in the form first.'
        : 'Henüz üretilmiş bir site yok. Önce forma dönüp bilgileri doldurunuz.';
    return '''
  <html>
    <body style="background:#0D1117;color:#4FC3F7;font-family:monospace;
      display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
      <p>$msg</p>
    </body>
  </html>
  ''';
  }

  Future<void> _injectPageScripts() async {
    const js = r"""
(function(){
  if(!document.getElementById('astro-nocopy-style')){
    var ncs = document.createElement('style');
    ncs.id = 'astro-nocopy-style';
    ncs.textContent = '*{ -webkit-user-select:none !important; user-select:none !important; -webkit-touch-callout:none !important; }';
    document.head.appendChild(ncs);
    document.addEventListener('copy', function(e){ e.preventDefault(); }, true);
    document.addEventListener('contextmenu', function(e){ e.preventDefault(); }, true);
  }
  var imgs = Array.prototype.slice.call(document.querySelectorAll('img'));
  imgs.forEach(function(img, i){
    img.setAttribute('data-astro-img-idx', String(i));
    img.style.cursor = 'pointer';
    if(!img.getAttribute('data-astro-img-bound')){
      img.setAttribute('data-astro-img-bound', '1');
      img.addEventListener('click', function(ev){
        ev.stopPropagation();
        AstroImagePicker.postMessage(String(i));
      });
    }
  });
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
    } catch (e) {
      debugPrint('[preview] _injectPageScripts JS enjeksiyonu başarısız: $e');
    }
  }

  Future<void> _syncCodeFromWebView() async {
    const js = r"""
(function(){
  var clone = document.documentElement.cloneNode(true);
  var nocopyStyle = clone.querySelector('#astro-nocopy-style');
  if(nocopyStyle) nocopyStyle.remove();
  return '<!DOCTYPE html>\n' + clone.outerHTML;
})();
""";
    try {
      final result = await _controller.runJavaScriptReturningResult(js);
      final htmlStr = _decodeJsResult(result);
      if (htmlStr.isEmpty) {
        throw Exception('WebView boş HTML döndürdü');
      }
      if (mounted) {
        await _persistCode(context.read<AppState>(), htmlStr);
      }
    } catch (e, st) {
      debugPrint('[preview] _syncCodeFromWebView başarısız: $e\n$st');
      rethrow;
    }
  }

  String _decodeJsResult(Object? result) {
    if (result == null) return '';
    if (result is String) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is String) return decoded;
      } catch (_) {}
      return result;
    }
    return result.toString();
  }

  void _showMsg(String text, {String icon = 'ℹ️'}) {
    if (!mounted) return;
    showAppPopup(context, message: text, icon: icon);
  }

  Future<void> _pickImageForGallery(int idx) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (xfile == null) return;

      final rawBytes = await xfile.readAsBytes();
      final isPng = xfile.path.toLowerCase().endsWith('.png');
      final compressed = await ImageCompressService.compress(
        rawBytes,
        isPng: isPng,
      );
      final b64 = base64Encode(compressed.bytes);
      final dataUri = jsonEncode('data:${compressed.mime};base64,$b64');

      final js = '''
(function(){
  var el = document.querySelector('[data-astro-img-idx="$idx"]');
  if(!el) return false;
  el.src = $dataUri;
  el.removeAttribute('srcset');
  return true;
})();
''';
      await _controller.runJavaScript(js);
      await _syncCodeFromWebView();
      _showMsg('Fotoğraf güncellendi! 🖼️', icon: '🖼️');
    } catch (e) {
      _showMsg('${isEnglish(context) ? 'Could not add photo' : 'Fotoğraf eklenemedi'}: $e', icon: '⚠️');
    }
  }

  void _openReportSheet() {
    final siteCode = _currentCode(context.read<AppState>());
    showReportDialog(
      context: context,
      source: ReportSource.preview,
      siteCode: siteCode,
    );
  }

  Future<String?> _promptForContactEmail(BuildContext context, {String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final en = isEnglish(context);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(en ? 'Contact form email' : 'İletişim formu e-postası'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    en
                        ? 'Messages from the downloaded site\'s contact form will open a mailto: to this address.'
                        : 'İndirilen sitedeki iletişim formuna gelen mesajlar bu adrese mailto: ile açılacak.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: en ? 'business@example.com' : 'isletme@ornek.com',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(en ? 'Cancel' : 'Vazgeç'),
                ),
                TextButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                    if (!valid) {
                      setState(() => errorText = en ? 'Enter a valid email' : 'Geçerli bir e-posta gir');
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: Text(en ? 'Continue' : 'Devam Et'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadSite() async {
    final appState = context.read<AppState>();
    final multi = _slotSiteMode(appState) == SiteMode.multi;
    final filesForCheck = multi ? _slotFiles(appState) : null;
    final codeForCheck = multi ? null : _slotCode(appState);
    if ((multi && filesForCheck!.isEmpty) || (!multi && codeForCheck!.isEmpty)) {
      showAppPopup(context,
          message: t(context, 'Önce bir site oluşturmanız gerekiyor.'), icon: 'ℹ️');
      return;
    }

    final projectId = appState.qtCurrentProjectId;
    if (!appState.canDownloadFreely(projectId)) {
      SiteProject? project;
      if (projectId != null) {
        final idx = appState.projects.indexWhere((p) => p.id == projectId);
        if (idx != -1) project = appState.projects[idx];
      }
      if (project == null) {
        showAppPopup(context,
            message: t(context, 'Önce bir site oluşturmanız gerekiyor.'), icon: 'ℹ️');
        return;
      }
      final proceed = await showDownloadPurchaseSheet(context, project: project);
      if (!proceed || !mounted) return;
    }

    if (!mounted) return;
    final checkIdx = appState.projects.indexWhere((p) => p.id == projectId);
    final wantsWatermarkFree =
        checkIdx == -1 ? true : !appState.projects[checkIdx].watermarkRemoved;
    final allowed = await BillingService.instance.verifyDownloadEntitlement(
      projectId!,
      wantsWatermarkFree: wantsWatermarkFree,
    );
    if (!allowed) {
      if (mounted) {
        showAppPopup(context,
            message: isEnglish(context)
                ? 'We couldn\'t verify a purchase for this download. Please try again.'
                : 'Bu indirme için bir satın alma doğrulanamadı. Lütfen tekrar deneyin.',
            icon: '⚠️');
      }
      return;
    }

    final projectForEmail = checkIdx == -1 ? null : appState.projects[checkIdx];
    if (!mounted) return;
    final contactEmail = await _promptForContactEmail(
      context,
      initialValue: projectForEmail?.leadEmail,
    );
    if (contactEmail == null || !mounted) return;
    if (projectId != null) {
      await appState.setDownloadContactEmail(projectId, contactEmail);
    }
    final siteNameForMailto = projectForEmail?.name ?? '';
    final stripForDownload = projectForEmail?.downloadWatermarkFree ?? false;

    try {
      if (multi) {
        final rawFiles = stripForDownload
            ? WatermarkService.stripFromFiles(_slotFiles(appState))
            : _slotFiles(appState);
        final files = {
          for (final entry in rawFiles.entries)
            entry.key: entry.key.toLowerCase().endsWith('.html')
                ? HostingService.injectDownloadOnlyMailtoConfig(
                    html: entry.value,
                    siteName: siteNameForMailto,
                    contactEmail: contactEmail,
                  )
                : entry.value,
        };
        final saved = await DownloadService.pickAndSaveZip(
            files: files, isEnglish: isEnglish(context));
        if (saved) await appState.markProjectExported();
        if (mounted && saved) {
          showAppPopup(context, message: t(context, 'ZIP dosyası cihaza kaydedildi! 📦'), icon: '✅');
        }
      } else {
        final rawCode = stripForDownload
            ? WatermarkService.strip(_slotCode(appState))
            : _slotCode(appState);
        final code = HostingService.injectDownloadOnlyMailtoConfig(
          html: rawCode,
          siteName: siteNameForMailto,
          contactEmail: contactEmail,
        );
        final saved = await DownloadService.pickAndSaveHtml(
            html: code, isEnglish: isEnglish(context));
        if (saved) await appState.markProjectExported();
        if (mounted && saved) {
          showAppPopup(context, message: t(context, 'HTML dosyası cihaza kaydedildi! 💾'), icon: '✅');
        }
      }
    } catch (e) {
      if (mounted) {
        showAppPopup(context,
            message: '${isEnglish(context) ? 'Download failed' : 'İndirme başarısız'}: $e',
            icon: '⚠️');
      }
    }
  }

  Future<void> _publishSite() async {
    unawaited(AnalyticsService.logPublishTapped());
    final ok = await requireLogin(context, feature: t(context, 'Yayınlama'));
    if (!ok || !mounted) return;

    final appState = context.read<AppState>();
    final projectId = appState.qtCurrentProjectId;
    if (projectId == null) {
      showAppPopup(context,
          message: t(context, 'Önce bir site oluşturmanız gerekiyor.'), icon: 'ℹ️');
      return;
    }
    final projectIdx = appState.projects.indexWhere((p) => p.id == projectId);
    if (projectIdx == -1) {
      showAppPopup(context,
          message: t(context, 'Proje bulunamadı, lütfen tekrar deneyin.'), icon: '⚠️');
      return;
    }
    final project = appState.projects[projectIdx];

    if (!appState.canPublishProject(project)) {
      if (!mounted) return;
      final bought = await showPublishPaywallSheet(context, project: project);
      if (!bought || !mounted) return;
    }

    final Map<String, String> files;
    if (_slotSiteMode(appState) == SiteMode.multi) {
      files = _slotFiles(appState);
      if (files.isEmpty) {
        showAppPopup(context,
            message: t(context, 'Önce bir site oluşturmanız gerekiyor.'), icon: 'ℹ️');
        return;
      }
    } else {
      final code = _slotCode(appState);
      if (code.isEmpty) {
        showAppPopup(context,
            message: t(context, 'Önce bir site oluşturmanız gerekiyor.'), icon: 'ℹ️');
        return;
      }
      files = {'index.html': code};
    }

    if (!mounted) return;

    await showPublishSheet(
      context,
      project: project,
      files: files,
      ownerEmail: AuthService.instance.currentUser?.email,
      onPublished: (subdomain, url, ownerToken, leadDelivery, leadEmail) =>
          context.read<AppState>().markProjectPublished(
            id: project.id,
            subdomain: subdomain,
            url: url,
            ownerToken: ownerToken,
            leadDelivery: leadDelivery,
            leadEmail: leadEmail,
          ),
    );
  }

  Future<void> _openRemoveWatermarkSheet() async {
    await showSubscriptionPlansScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.accentCyan),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _showsBranding {
    final appState = context.read<AppState>();
    return appState.qtCurrentHasBranding;
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF141821),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t(context, 'Ön İzleme'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.flag_rounded,
                background: const Color(0xFF0D1117),
                iconColor: AppColors.accentRed,
                borderColor: AppColors.accentRed,
                size: 34,
                iconSize: 16,
                onTap: _openReportSheet,
              ),
              const SizedBox(width: 8),
              PillButton(
                label: t(context, 'Kapat'),
                borderColor: AppColors.accentRed,
                textColor: AppColors.accentRed,
                height: 34,
                fontSize: 12.5,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final actionButtons = <Widget>[
              if (context.watch<AppState>().qtCurrentEditableInApp)
                PillButton(
                  label: t(context, 'Düzenle'),
                  emoji: '✏️',
                  borderColor: AppColors.accentGreenLink,
                  textColor: AppColors.accentGreenLink,
                  height: 40,
                  fontSize: 13,
                  onTap: _openEditForm,
                ),
              if (context.watch<AppState>().qtCurrentEditableInApp &&
                  canConvertToFreeSite(context.watch<AppState>().qtCurrentKind))
                PillButton(
                  label: t(context, 'Serbest Siteye çevir'),
                  emoji: '🧩',
                  borderColor: AppColors.accentBlue,
                  textColor: AppColors.accentBlue,
                  height: 40,
                  fontSize: 13,
                  onTap: _convertToFreeSite,
                ),
              PillButton(
                label: t(context, 'Yayınla'),
                emoji: '🚀',
                borderColor: AppColors.accentBlue,
                textColor: AppColors.accentBlue,
                height: 40,
                fontSize: 13,
                onTap: _publishSite,
              ),
              PillButton(
                label: t(context, 'İndir'),
                emoji: '⬇️',
                borderColor: AppColors.accentGreenLink,
                textColor: AppColors.accentGreenLink,
                height: 40,
                fontSize: 13,
                onTap: _downloadSite,
              ),
              if (_showsBranding)
                PillButton(
                  label: t(context, 'Rozeti Kaldır'),
                  emoji: '🏷️',
                  borderColor: AppColors.accentOrange,
                  textColor: AppColors.accentOrange,
                  height: 40,
                  fontSize: 13,
                  onTap: _openRemoveWatermarkSheet,
                ),
            ];

            final rows = <Widget>[];
            for (var i = 0; i < actionButtons.length; i += 2) {
              final hasSecond = i + 1 < actionButtons.length;
              rows.add(
                Row(
                  children: [
                    Expanded(child: actionButtons[i]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: hasSecond
                          ? actionButtons[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
              if (i + 2 < actionButtons.length) {
                rows.add(const SizedBox(height: 8));
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            );
          }),
        ],
      ),
    );
  }
}
