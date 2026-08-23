import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/worker_service.dart';
import '../services/ai_response_utils.dart';
import '../services/report_service.dart';
import '../services/download_service.dart';
import '../services/hosting_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../widgets/pill_button.dart';
import '../widgets/ai_edit_dialog.dart';
import '../widgets/report_dialog.dart';
import '../widgets/quota_limit_popup.dart';
import '../widgets/login_gate.dart';
import '../widgets/publish_sheet.dart';
import '../widgets/publish_paywall_sheet.dart';
import '../widgets/remove_watermark_sheet.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// AI Chat ile üretilen sitelerin ÖN İZLEME ekranı.
///
/// index.html'deki iki AI akışı burada uygulanır (kod gömülmeden, sadece
/// mantığı Dart/WebView'a taşınarak):
/// - Bölümlere ✨ butonu enjekte edilir; birine dokunulunca o bölümün
///   HTML'i AI'ya gönderilip SADECE o bölüm güncellenir (editSection).
/// - Üstteki AI butonu ile sayfanın arka planı (renk/tema/animasyon)
///   AI'ya tarif edilerek güncellenir (editBackground).
/// Manuel düzenleme yoktur; hepsi AI üzerinden yapılır.
///
/// Form ile (Hızlı Araçlar) üretilen sitelerin önizlemesi için bu ekranı
/// KULLANMA — onun için ayrı, AI düzenlemesi içermeyen QuickToolsPreviewScreen
/// var (aşağıda). İkisi de aynı ortak alt yapıyı (_PreviewScreenCore)
/// paylaşır, sadece hangi özelliklerin açık olduğu farklıdır.
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // enableAiEditing artık AppConfig.aiEditingEnabled'a bağlı (bkz.
    // lib/config/app_config.dart) — bu ekrana normal şartlarda zaten
    // home_screen.dart'taki AI Chat sekmesi kapalıyken hiç girilemiyor,
    // ama burası ikinci bir güvenlik katmanı: bayrak false iken bu ekrana
    // her nasılsa girilse bile ✨ butonları yine render edilmez.
    return const _PreviewScreenCore(isQuickTools: false, enableAiEditing: AppConfig.aiEditingEnabled);
  }
}

/// Hızlı Araçlar (form doldurup site oluşturma) akışının ÖN İZLEME ekranı.
///
/// KASITLI OLARAK AI düzenleme içermez: ne bölüm başına ✨ butonu enjekte
/// edilir, ne de üstte "AI ile arkaplan düzenle" butonu gösterilir. Bu
/// akışta site tamamen formdaki verilerden yerel olarak (AI'sız) üretildiği
/// için düzenleme de forma dönüp yeniden oluşturmak üzerinden yapılır.
/// Fotoğraf değiştirme (dokunup galeriden seçme) ve kopyalama koruması gibi
/// AI OLMAYAN özellikler burada da aktif kalır.
class QuickToolsPreviewScreen extends StatelessWidget {
  const QuickToolsPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PreviewScreenCore(isQuickTools: true, enableAiEditing: false);
  }
}

class _PreviewScreenCore extends StatefulWidget {
  /// true ise Hızlı Araçlar (form ile site oluşturma) slotunu gösterir;
  /// false ise AI Chat'in kendi slotunu gösterir. İkisi birbirinden
  /// tamamen bağımsızdır — bkz. AppState qtGeneratedCode/qtGeneratedFiles.
  final bool isQuickTools;

  /// false ise ✨ bölüm düzenleme ve üstteki "AI" arkaplan düzenleme
  /// butonu tamamen devre dışı kalır (Hızlı Araçlar akışı).
  final bool enableAiEditing;

  const _PreviewScreenCore({required this.isQuickTools, required this.enableAiEditing});

  @override
  State<_PreviewScreenCore> createState() => _PreviewScreenCoreState();
}

class _PreviewScreenCoreState extends State<_PreviewScreenCore> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _aiBusy = false;

  /// Sadece B modunda (çok sayfa) kullanılır: dosyaların diskte yazıldığı
  /// geçici klasör. Sayfa içi <a href="urunler.html"> linkleri buradan
  /// gerçek dosya olarak açılır.
  String? _previewDirPath;

  bool get _isMulti => _slotSiteMode(context.read<AppState>()) == SiteMode.multi;

  // --- Slot erişimi: isQuickTools'a göre AI Chat ya da Hızlı Araçlar
  // slotunu okur/yazar. Bu ekranın geri kalanı SADECE bu yardımcıları
  // kullanmalı, appState.generatedCode/generatedFiles/activeFileName/
  // siteMode'a doğrudan erişmemeli.
  SiteMode _slotSiteMode(AppState appState) =>
      widget.isQuickTools ? appState.qtSiteMode : appState.siteMode;
  String _slotCode(AppState appState) =>
      widget.isQuickTools ? appState.qtGeneratedCode : appState.generatedCode;
  Map<String, String> _slotFiles(AppState appState) =>
      widget.isQuickTools ? appState.qtGeneratedFiles : appState.generatedFiles;
  String? _slotActiveFile(AppState appState) =>
      widget.isQuickTools ? appState.qtActiveFileName : appState.activeFileName;
  void _slotSetActiveFile(AppState appState, String fileName) => widget.isQuickTools
      ? appState.setQtActiveFile(fileName)
      : appState.setActiveFile(fileName);
  void _slotUpdateCode(AppState appState, String code) => widget.isQuickTools
      ? appState.updateQtGeneratedCode(code)
      : appState.updateGeneratedCode(code);
  void _slotUpdateActiveFileContent(AppState appState, String content) => widget.isQuickTools
      ? appState.updateQtActiveFileContent(content)
      : appState.updateActiveFileContent(content);

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AstroBridge',
        onMessageReceived: (msg) {
          try {
            final data = jsonDecode(msg.message) as Map<String, dynamic>;
            final idx = data['idx'];
            final html = data['html'] as String? ?? '';
            if (html.isNotEmpty) _openSectionEditSheet(idx, html);
          } catch (_) {}
        },
      )
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
            // çıkarıp aktif slotun activeFileName'ini güncelliyoruz ki AI
            // düzenlemeleri (bölüm/arkaplan) doğru dosyaya yazılsın.
            if (_slotSiteMode(appState) == SiteMode.multi) {
              final name = url.split('/').isNotEmpty ? url.split('/').last : null;
              if (name != null &&
                  name.isNotEmpty &&
                  _slotFiles(appState).containsKey(name)) {
                _slotSetActiveFile(appState, name);
              }
            }
            await _injectWandEditing();
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

  /// AI bazen <meta name="viewport"> etiketini eklemeyi unutuyor; bu durumda
  /// mobil tarayıcı sayfayı ~980px genişlikte varsayıp küçültür ve site
  /// "masaüstü gibi" görünür. Bu son-işlem, prompt kuralına ek bir GÜVENCE
  /// olarak, eksikse etiketi otomatik ekler (AI'nin ürettiği koda dokunmadan,
  /// sadece bu tek satırı garanti eder).
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

  /// AI ile üretilen yeni içeriği doğru yere yazar: A modunda ilgili slotun
  /// generatedCode'una, B modunda generatedFiles[activeFileName] + diskteki
  /// önizleme dosyasına (linkler bozulmasın diye diğer dosyalara dokunulmaz).
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
        ? 'No site generated yet. Please send a request from the chat first.'
        : 'Henüz üretilmiş bir site yok. Önce sohbetten bir istek gönderiniz.';
    return '''
  <html>
    <body style="background:#0D1117;color:#4FC3F7;font-family:monospace;
      display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
      <p>$msg</p>
    </body>
  </html>
  ''';
  }

  /// Sayfanın en üst düzey (body'nin doğrudan çocuğu) bölümlerine, üzerine
  /// dokunulunca o bölümü AI'ya gönderen küçük bir ✨ butonu enjekte eder.
  /// Hızlı Araçlar akışında (enableAiEditing=false) bu ✨ butonları hiç
  /// eklenmez — sadece AI OLMAYAN kısımlar (kopyalama koruması, fotoğraf
  /// değiştirme) aktif kalır.
  Future<void> _injectWandEditing() async {
    final wandJs = widget.enableAiEditing
        ? r"""
  var kids = Array.prototype.slice.call(document.body.children).filter(function(el){
    return el.tagName !== 'SCRIPT' && el.tagName !== 'STYLE' && el.id !== 'astro-ai-bg-style';
  });
  kids.forEach(function(el, idx){
    el.setAttribute('data-astro-idx', String(idx));
    if(getComputedStyle(el).position === 'static'){ el.style.position = 'relative'; }
    var old = el.querySelector(':scope > .astro-wand-btn');
    if(old) old.remove();
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'astro-wand-btn';
    btn.innerText = '✨';
    btn.addEventListener('click', function(ev){
      ev.stopPropagation();
      var clone = el.cloneNode(true);
      var cb = clone.querySelector('.astro-wand-btn');
      if(cb) cb.remove();
      AstroBridge.postMessage(JSON.stringify({idx: idx, html: clone.outerHTML}));
    });
    el.appendChild(btn);
  });
"""
        : '';
    final js = """
(function(){
  var s = document.getElementById('astro-wand-style');
  if(!s){
    s = document.createElement('style');
    s.id = 'astro-wand-style';
    s.textContent = '.astro-wand-btn{position:absolute;top:6px;right:6px;z-index:999999;background:#26C6DA;color:#fff;border:none;border-radius:50%;width:32px;height:32px;font-size:15px;line-height:32px;text-align:center;padding:0;box-shadow:0 2px 8px rgba(0,0,0,.35);}';
    document.head.appendChild(s);
  }
  // Not: uygulamada kopyala/yapıştır kapalı; üretilen sitenin içeriği de
  // kopyalanamasın diye (referans index.html'deki iframe koruma mantığı).
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
$wandJs
})();
""";
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  /// Canlı WebView DOM'undan (wand butonları çıkarılmış hâliyle) TAM HTML'i
  /// okuyup appState.generatedCode'u günceller; böylece indirme/kaydetme
  /// her zaman en son AI düzenlemesini yansıtır.
  Future<void> _syncCodeFromWebView() async {
    const js = r"""
(function(){
  var clone = document.documentElement.cloneNode(true);
  var btns = clone.querySelectorAll('.astro-wand-btn');
  btns.forEach(function(b){ b.remove(); });
  var wandStyle = clone.querySelector('#astro-wand-style');
  if(wandStyle) wandStyle.remove();
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
  // güncel kodu (appState.generatedCode / generatedFiles) senkronlar ki
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

  /// AI puan kotası (havuzu) kontrol edilir (1 düzenleme = 2 puan).
  /// Yetersizse custom popup'ı gösterir ve false döner.
  Future<bool> _checkQuotaOrShowPopup() async {
    final appState = context.read<AppState>();
    if (await appState.ensureAiQuotaFor(AppState.costEdit)) return true;
    await showQuotaLimitPopup(context);
    return false;
  }

  // ------------------------------------------------------------------
  // Bölüm bazlı AI düzenleme (✨ butonu -> bottom sheet -> editSection).
  // ------------------------------------------------------------------
  void _openSectionEditSheet(dynamic idx, String sectionHtml) {
    showAiEditDialog(
      context: context,
      icon: '✨',
      title: t(context, 'AI Bölüm Düzenleyici'),
      description: 'Bu bölümden ne değiştirmek istersin? Örn: başlığı değiştir, butonun rengini kırmızı yap.',
      hint: 'Örn: Bu bölümün arka planını mor yap, başlığı büyüt...',
      accent: AppColors.accentCyan,
    ).then((request) {
      if (request == null || request.isEmpty) return;
      _applySectionEdit(idx, sectionHtml, request);
    });
  }

  Future<void> _applySectionEdit(dynamic idx, String sectionHtml, String request) async {
    if (!await _checkQuotaOrShowPopup()) return;
    final appState = context.read<AppState>();

    setState(() => _aiBusy = true);
    try {
      final updatedHtml = await WorkerService.editSection(
        sectionHtml: sectionHtml,
        request: request,
      );
      await appState.consumeAiQuota(AppState.costEdit);

      final encoded = jsonEncode(updatedHtml);
      final js = '''
(function(){
  var el = document.querySelector('[data-astro-idx="$idx"]');
  if(!el) return false;
  var tmp = document.createElement('div');
  tmp.innerHTML = $encoded;
  var newEl = tmp.firstElementChild;
  if(!newEl) return false;
  el.replaceWith(newEl);
  return true;
})();
''';
      await _controller.runJavaScript(js);
      await _injectWandEditing();
      await _syncCodeFromWebView();
      _showMsg('Bölüm güncellendi!', icon: '✨');
    } on AiRejectedException catch (e) {
      _showMsg(e.message, icon: '🛠️');
    } on WorkerRateLimitException catch (_) {
      if (!mounted) return;
      await showWorkerBusyPopup(context);
    } catch (e) {
      _showMsg('${isEnglish(context) ? 'Error' : 'Hata'}: $e', icon: '⚠️');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ------------------------------------------------------------------
  // Üst AI butonu: sayfa arka planını AI ile düzenleme (editBackground).
  // ------------------------------------------------------------------
  Future<void> _openBackgroundEditDialog() async {
    final request = await showAiEditDialog(
      context: context,
      icon: '🎨',
      title: t(context, 'AI Arka Plan Düzenleyici'),
      description: 'Sayfanın arka planı için ne istersin? (Örn: koyu mor gradient, animasyonlu neon vb.)',
      hint: 'Örn: Bu bölümün arka planını mor yap, başlığı büyüt...',
      accent: AppColors.accentCyan,
    );
    if (request == null || request.isEmpty) return;
    await _applyBackgroundEdit(request);
  }

  void _openReportSheet() {
    // index.html > _reportContext === 'preview': üretilen sitenin TAM HTML
    // kodu (sonKod) kırpılmadan mail içeriğine ekleniyor.
    final siteCode = _currentCode(context.read<AppState>());
    showReportDialog(
      context: context,
      source: ReportSource.preview,
      siteCode: siteCode,
    );
  }

  Future<void> _applyBackgroundEdit(String request) async {
    if (!await _checkQuotaOrShowPopup()) return;
    final appState = context.read<AppState>();

    setState(() => _aiBusy = true);
    try {
      // AI'ya site kodunun tamamı DEĞİL, sadece mevcut arkaplan bloğunun
      // içeriği gönderiliyor (varsa) — worker.js'in "bg_edit" tipi bu
      // sayede "rengi koru, animasyon ekle" gibi istekleri kör tahmin
      // yerine gerçek mevcut değere bakarak yanıtlıyor.
      final currentBgCss = _extractCurrentBackgroundCss(_currentCode(appState));
      final css = await WorkerService.editBackground(
        request: request,
        currentBackgroundCss: currentBgCss,
      );
      final newCode = _ensureViewportMeta(_mergeBackgroundCss(_currentCode(appState), css));
      await appState.consumeAiQuota(AppState.costEdit);
      await _persistCode(appState, newCode);
      setState(() => _loading = true);
      if (_slotSiteMode(appState) == SiteMode.multi && _previewDirPath != null) {
        // Diğer sayfalardaki linkler bozulmasın diye sadece aktif dosyayı
        // yeniden yüklüyoruz (writeFilesForPreview ile tam klasör yeniden
        // oluşturulmuyor, tek dosya üstüne yazıldı).
        final active = _slotActiveFile(appState) ?? 'index.html';
        await _controller.loadFile('$_previewDirPath/$active');
      } else {
        await _controller.loadHtmlString(newCode);
      }
      _showMsg('Arkaplan güncellendi!', icon: '✨');
    } on AiRejectedException catch (e) {
      _showMsg(e.message, icon: '🎨');
    } on WorkerRateLimitException catch (_) {
      if (!mounted) return;
      await showWorkerBusyPopup(context);
    } catch (e) {
      _showMsg('${isEnglish(context) ? 'Error' : 'Hata'}: $e', icon: '⚠️');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  /// Tam site kodundan SADECE mevcut "astro-ai-bg-style" bloğunun içeriğini
  /// (etiketler hariç, saf CSS) ayıklar. Yoksa null döner — AI'ya "mevcut
  /// arkaplan yok" olarak bildirilir, yine de tüm site kodu gönderilmez.
  String? _extractCurrentBackgroundCss(String code) {
    final regex = RegExp(r'<style id="astro-ai-bg-style">([\s\S]*?)</style>');
    final match = regex.firstMatch(code);
    return match?.group(1)?.trim();
  }

  String _mergeBackgroundCss(String code, String css) {
    final block = '<style id="astro-ai-bg-style">\n$css\n</style>';
    final regex = RegExp(r'<style id="astro-ai-bg-style">[\s\S]*?</style>');
    if (regex.hasMatch(code)) {
      return code.replaceFirst(regex, block);
    }
    // </head> varsa oraya ekle (en doğru yer).
    if (code.contains('</head>')) {
      return code.replaceFirst('</head>', '$block\n</head>');
    }
    // <head> açık etiketi varsa (nadiren kapanmamış olabilir) onun hemen
    // ardına ekle.
    final headOpenMatch = RegExp(r'<head[^>]*>').firstMatch(code);
    if (headOpenMatch != null) {
      final insertAt = headOpenMatch.end;
      return code.substring(0, insertAt) +
          '\n$block' +
          code.substring(insertAt);
    }
    // <body> varsa (head hiç yoksa) body'nin İÇİNE, en başına ekle —
    // <style> tarayıcıda body içinde de geçerlidir, HİÇBİR ZAMAN <html>'in
    // dışına/en başa düz metin gibi kaçmasın (aksi halde CSS kodu sayfada
    // yazı olarak görünür).
    final bodyOpenMatch = RegExp(r'<body[^>]*>').firstMatch(code);
    if (bodyOpenMatch != null) {
      final insertAt = bodyOpenMatch.end;
      return code.substring(0, insertAt) +
          '\n$block' +
          code.substring(insertAt);
    }
    // Hiçbir yapısal etiket yoksa (tek başına bir HTML parçası): en güvenli
    // seçenek CSS'i yine de <style> içinde, kodun EN BAŞINA koymak —
    // düz metin olarak asla bırakma.
    return '$block\n$code';
  }

  /// Ön izlemedeki aktif slotu (AI Chat ya da Hızlı Araçlar, _slot* yardımcıları
  /// üzerinden) cihaza indirir. home_screen.dart'taki _downloadSite ile BİREBİR
  /// aynı mantık — sadece appState.generatedCode/generatedFiles yerine ilgili
  /// slotu (_slotCode/_slotFiles) kullanır, bu yüzden Hızlı Araçlar önizlemesinde
  /// de doğru (qt) slotu indirir.
  Future<void> _downloadSite() async {
    final appState = context.read<AppState>();
    try {
      if (_slotSiteMode(appState) == SiteMode.multi) {
        final files = _slotFiles(appState);
        if (files.isEmpty) {
          if (mounted) {
            showAppPopup(context,
                message: t(context, 'Önce sohbetten bir site oluşturmanız gerekiyor.'),
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
                message: t(context, 'Önce sohbetten bir site oluşturmanız gerekiyor.'),
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

  /// "Yayınla" — kararlaştırıldığı gibi SADECE Google ile giriş yapmış
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
    final projectId =
        widget.isQuickTools ? appState.qtCurrentProjectId : appState.currentProjectId;
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

  /// "Rozeti Kaldır" — site bazlı, tek seferlik satın alma sheet'ini açar.
  /// Ekrandaki hangi slot açıksa (AI Chat ya da Hızlı Araçlar) o slotun
  /// bağlı olduğu SiteProject bulunur; henüz hiçbir projeye kaydedilmemiş
  /// (proje yok) bir slot için gösterilecek bir şey yoktur.
  /// "Rozeti Kaldır" — kararlaştırıldığı gibi SATIN ALMA akışı da
  /// Yayınlama gibi Google ile giriş ister (bkz. login_gate.dart >
  /// requireLogin). Giriş yoksa burada bottom sheet açılır, kullanıcı
  /// vazgeçerse showRemoveWatermarkSheet'e hiç gidilmez.
  Future<void> _openRemoveWatermarkSheet() async {
    final ok = await requireLogin(context, feature: t(context, 'Rozeti Kaldır'));
    if (!ok || !mounted) return;

    final appState = context.read<AppState>();
    final projectId =
        widget.isQuickTools ? appState.qtCurrentProjectId : appState.currentProjectId;
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
                  if (_aiBusy)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.accentCyan),
                            const SizedBox(height: 12),
                            Text(t(context, '✨ AI düzenliyor...'),
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
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
  /// edilir — AppState.currentHasBranding/qtCurrentHasBranding ile aynı
  /// mantık.
  bool get _showsBranding {
    final appState = context.read<AppState>();
    return widget.isQuickTools ? appState.qtCurrentHasBranding : appState.currentHasBranding;
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
                  if (widget.enableAiEditing) ...[
                    PillButton(
                      label: t(context, 'AI'),
                      emoji: '🎨',
                      borderColor: AppColors.accentCyan,
                      textColor: AppColors.accentCyan,
                      height: 34,
                      fontSize: 12.5,
                      onTap: _aiBusy ? null : _openBackgroundEditDialog,
                    ),
                    const SizedBox(width: 8),
                  ],
                  PillButton(
                    label: t(context, 'Yayınla'),
                    emoji: '🚀',
                    borderColor: AppColors.accentBlue,
                    textColor: AppColors.accentBlue,
                    height: 34,
                    fontSize: 12.5,
                    onTap: _aiBusy ? null : _publishSite,
                  ),
                  const SizedBox(width: 8),
                  PillButton(
                    label: t(context, 'İndir'),
                    emoji: '⬇️',
                    borderColor: AppColors.accentGreenLink,
                    textColor: AppColors.accentGreenLink,
                    height: 34,
                    fontSize: 12.5,
                    onTap: _aiBusy ? null : _downloadSite,
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
                      onTap: _aiBusy ? null : _openRemoveWatermarkSheet,
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
