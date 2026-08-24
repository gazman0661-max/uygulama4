import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/report_service.dart';
import '../services/download_service.dart';
import '../services/auth_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/app_popup.dart';
import '../widgets/report_dialog.dart';
import '../widgets/login_gate.dart';
import '../widgets/publish_sheet.dart';
import '../widgets/publish_paywall_sheet.dart';
import '../widgets/remove_watermark_sheet.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// Hızlı Araçlar (form doldurup site oluşturma) akışının ÖN İZLEME ekranı.
///
/// Fotoğraf değiştirme (dokunup galeriden seçme) ve kopyalama koruması
/// aktiftir; içerik düzenleme forma dönüp yeniden oluşturmak üzerinden
/// yapılır.
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

  /// Sadece B modunda (çok sayfa) kullanılır: dosyaların diskte yazıldığı
  /// geçici klasör. Sayfa içi <a href="urunler.html"> linkleri buradan
  /// gerçek dosya olarak açılır.
  String? _previewDirPath;

  // --- Slot erişimi: Hızlı Araçlar slotunu (qtGeneratedCode/qtGeneratedFiles)
  // okur/yazar. Bu ekranın geri kalanı SADECE bu yardımcıları kullanır.
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
            // B modunda gezinme (index.html -> urunler.html gibi) gerçek
            // dosya değişikliğidir; hangi dosyanın açık olduğunu URL'den
            // çıkarıp aktif slotun activeFileName'ini güncelliyoruz.
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
      final safeCode =
          code.isNotEmpty ? _ensureViewportMeta(code) : _placeholderHtml;
      await _controller.loadHtmlString(safeCode);
    }
  }

  /// Bazı üretici fonksiyonlar <meta name="viewport"> etiketini eklemeyi
  /// unutabilir; bu durumda mobil tarayıcı sayfayı ~980px genişlikte
  /// varsayıp küçültür ve site "masaüstü gibi" görünür. Bu son-işlem,
  /// eksikse etiketi otomatik ekler.
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
    // Yapısal etiket hiç yoksa dokunma; nadiren fragment olabilir.
    return html;
  }

  /// Çok sayfa modunda TÜM .html dosyalarına viewport garantisini uygular.
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

  /// Şu an ekranda olan dosyanın ham içeriğini döndürür (mod farketmeksizin).
  String _currentCode(AppState appState) {
    if (_slotSiteMode(appState) == SiteMode.multi) {
      final active = _slotActiveFile(appState);
      if (active == null) return '';
      return _slotFiles(appState)[active] ?? '';
    }
    return _slotCode(appState);
  }

  /// Yeni içeriği doğru yere yazar: A modunda ilgili slotun
  /// qtGeneratedCode'una, B modunda qtGeneratedFiles[activeFileName] +
  /// diskteki önizleme dosyasına (linkler bozulmasın diye diğer dosyalara
  /// dokunulmaz).
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

  /// Sayfaya kopyalama koruması ve fotoğraf değiştirme davranışını enjekte
  /// eder.
  Future<void> _injectPageScripts() async {
    const js = r"""
(function(){
  // Not: uygulamada kopyala/yapıştır kapalı; üretilen sitenin içeriği de
  // kopyalanamasın diye.
  if(!document.getElementById('astro-nocopy-style')){
    var ncs = document.createElement('style');
    ncs.id = 'astro-nocopy-style';
    ncs.textContent = '*{ -webkit-user-select:none !important; user-select:none !important; -webkit-touch-callout:none !important; }';
    document.head.appendChild(ncs);
    document.addEventListener('copy', function(e){ e.preventDefault(); }, true);
    document.addEventListener('contextmenu', function(e){ e.preventDefault(); }, true);
  }
  // Not: galeri/foto bölümündeki <img> etiketlerine dokununca cihazdan
  // fotoğraf seçilip o görselin yerine konabilsin diye tıklama dinleyicisi
  // ekliyoruz. Aynı görsele iki kez enjeksiyon yapılırsa dinleyici tekrar
  // bağlanmasın diye data-astro-img-bound işaretliyoruz.
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
})();
""";
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  /// Canlı WebView DOM'undan TAM HTML'i okuyup ilgili slotu günceller;
  /// böylece indirme/kaydetme her zaman en son seçilen fotoğrafı yansıtır.
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
      if (htmlStr.isNotEmpty && mounted) {
        await _persistCode(context.read<AppState>(), htmlStr);
      }
    } catch (_) {}
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

  // ------------------------------------------------------------------
  // Galeri bölümü: bir <img>'e dokunulunca cihazdan fotoğraf seçtirip
  // görseli base64 data URI olarak DOM'daki elemanın yerine koyar, sonra
  // güncel kodu (qtGeneratedCode / qtGeneratedFiles) senkronlar ki
  // indirme her zaman en son seçilen fotoğrafı yansıtsın.
  // ------------------------------------------------------------------
  Future<void> _pickImageForGallery(int idx) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      final b64 = base64Encode(bytes);
      final ext = xfile.path.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final dataUri = jsonEncode('data:$mime;base64,$b64');

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

  /// home_screen.dart'taki _downloadSite ile BİREBİR aynı mantık — sadece
  /// ilgili slotu (_slotCode/_slotFiles) kullanır.
  Future<void> _downloadSite() async {
    final appState = context.read<AppState>();
    try {
      if (_slotSiteMode(appState) == SiteMode.multi) {
        final files = _slotFiles(appState);
        if (files.isEmpty) {
          if (mounted) {
            showAppPopup(context,
                message: t(context, 'Önce bir site oluşturmanız gerekiyor.'),
                icon: 'ℹ️');
          }
          return;
        }
        final saved = await DownloadService.pickAndSaveZip(files: files);
        if (saved) await appState.markProjectExported();
        if (mounted && saved) {
          showAppPopup(context, message: t(context, 'ZIP dosyası cihaza kaydedildi! 📦'), icon: '✅');
        }
      } else {
        final code = _slotCode(appState);
        if (code.isEmpty) {
          if (mounted) {
            showAppPopup(context,
                message: t(context, 'Önce bir site oluşturmanız gerekiyor.'),
                icon: 'ℹ️');
          }
          return;
        }
        final saved = await DownloadService.pickAndSaveHtml(html: code);
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

  /// "Yayınla" — kararlaştırıldığı gibi SADECE e-posta ile giriş yapmış
  /// kullanıcılar için (bkz. login_gate.dart > requireLogin). Giriş yoksa
  /// burada bir bottom sheet açılıp kullanıcıdan giriş istenir; vazgeçerse
  /// akış burada durur, HostingService.publish'e hiç gidilmez.
  ///
  /// Worker henüz deploy edilmediyse (HostingConfig.baseUrl boş) publish
  /// sheet açılır ama içindeki istek [HostingNotConfiguredException]
  /// fırlatır — kullanıcıya net bir mesaj gösterilir, uygulama çökmez.
  Future<void> _publishSite() async {
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

    // Ücretlendirme kontrolü: ilk site yayını ücretsiz, ikinci ve sonraki
    // her YENİ site (ve elde satın alınmış bir yayın kredisi yoksa) için
    // önce bir "yayın hakkı" satın alınmalı. Bu proje daha önce zaten
    // yayınlanmışsa (publishRightGranted true) canPublishProject direkt
    // true döner, hiçbir şey sormadan devam edilir.
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
      onPublished: (subdomain, url) => context.read<AppState>().markProjectPublished(
            id: project.id,
            subdomain: subdomain,
            url: url,
          ),
    );
  }

  /// "Rozeti Kaldır" — açık slotun bağlı olduğu SiteProject bulunur; henüz
  /// hiçbir projeye kaydedilmemiş (proje yok) bir slot için gösterilecek
  /// bir şey yoktur.
  /// "Rozeti Kaldır" — kararlaştırıldığı gibi SATIN ALMA akışı da
  /// Yayınlama gibi e-posta ile giriş ister (bkz. login_gate.dart >
  /// requireLogin). Giriş yoksa burada bottom sheet açılır, kullanıcı
  /// vazgeçerse showRemoveWatermarkSheet'e hiç gidilmez.
  Future<void> _openRemoveWatermarkSheet() async {
    final ok = await requireLogin(context, feature: t(context, 'Rozeti Kaldır'));
    if (!ok || !mounted) return;

    final appState = context.read<AppState>();
    final projectId = appState.qtCurrentProjectId;
    if (projectId == null) return;
    final idx = appState.projects.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    if (!mounted) return;
    await showRemoveWatermarkSheet(context, project: appState.projects[idx]);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    // removeWatermarkForProject sonrası "Rozeti Kaldır" butonunun anında
    // kaybolması için (bkz. _buildToolbar) burayı dinlemek gerekiyor.
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

  /// O an ekranda açık slotun bağlı olduğu projede rozet hâlâ var mı.
  /// Proje henüz kaydedilmediyse (id yok) varsayılan olarak rozetli kabul
  /// edilir — AppState.qtCurrentHasBranding ile aynı mantık.
  bool get _showsBranding {
    final appState = context.read<AppState>();
    return appState.qtCurrentHasBranding;
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF141821),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 34,
        child: Row(
          children: [
            Text(t(context, 'Ön İzleme'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'monospace')),
            const SizedBox(width: 8),
            // 19.08.2026 düzeltmesi: FittedBox daha önce Expanded/Flexible
            // OLMADAN doğrudan Row içindeydi. Row, esnek olmayan (non-flex)
            // çocuklarına sınırsız (unbounded) genişlik verir; FittedBox da
            // bu durumda kendi boyutunu çocuğunun doğal boyutuna eşitler —
            // yani küçültecek bir "kutu" sınırı hiç oluşmuyordu, bu yüzden
            // BoxFit.scaleDown hiçbir zaman devreye girmiyordu ve butonlar
            // ekrandan taşıyordu ("OVERFLOWED BY ... PIXELS"). Şimdi
            // Expanded ile sarılınca FittedBox gerçek/sınırlı bir genişlik
            // alıyor ve gerektiğinde butonları küçültüp sığdırabiliyor.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PillButton(
                    label: t(context, 'Yayınla'),
                    emoji: '🚀',
                    borderColor: AppColors.accentBlue,
                    textColor: AppColors.accentBlue,
                    height: 34,
                    fontSize: 12.5,
                    onTap: _publishSite,
                  ),
                  const SizedBox(width: 8),
                  PillButton(
                    label: t(context, 'İndir'),
                    emoji: '⬇️',
                    borderColor: AppColors.accentGreenLink,
                    textColor: AppColors.accentGreenLink,
                    height: 34,
                    fontSize: 12.5,
                    onTap: _downloadSite,
                  ),
                  if (_showsBranding) ...[
                    const SizedBox(width: 8),
                    PillButton(
                      label: t(context, 'Rozeti Kaldır'),
                      emoji: '🏷️',
                      borderColor: AppColors.accentOrange,
                      textColor: AppColors.accentOrange,
                      height: 34,
                      fontSize: 12.5,
                      onTap: _openRemoveWatermarkSheet,
                    ),
                  ],
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: Icons.flag_rounded,
                    background: const Color(0xFF141821),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
