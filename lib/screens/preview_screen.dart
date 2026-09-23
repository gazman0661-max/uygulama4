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
import '../services/auth_service.dart';
import '../services/image_compress_service.dart';
import '../services/analytics_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/app_popup.dart';
import '../widgets/report_dialog.dart';
import '../widgets/login_gate.dart';
import '../widgets/publish_sheet.dart';
import '../widgets/publish_paywall_sheet.dart';
import '../widgets/remove_watermark_sheet.dart';
import '../widgets/download_purchase_sheet.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import 'form_screen_router.dart';

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

    // GÜVENLİK (20.09.2026 eklendi — düşük öncelik, "önizleme WebView'ında JS
    // kısıtsız, devir alınan içerik güvenilmez ama aynı WebView'da açılıyor"):
    // JS'i tamamen kapatmak bu ekranın asıl işlevini (canlı site önizleme +
    // resim seçme köprüsü) kırardı — bu yüzden JavaScriptMode kısıtlanmadı.
    // Ama bir site DEVİR alınarak (transfer/claim) gelmiş olabilir; o proje
    // dosyaları bu cihazın kullanıcısı tarafından yazılmamış olabilir. Bu
    // yüzden en azından bu WebView'ın kamera/mikrofon/konum gibi native
    // izinler İSTEYEBİLMESİNİ engelliyoruz — enjekte edilmiş/kötü niyetli JS
    // sessizce (kullanıcıya sormadan) bu izinleri talep edip cihaz
    // donanımına erişemesin.
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
      // 02.09.2026 düzeltildi — ÖNEMLİ ÇÖKME DÜZELTMESİ: loadHtmlString()
      // tüm HTML'i (galerideki fotoğraflar dahil, base64 olarak gömülü)
      // platform channel/Binder IPC üzerinden native tarafa TEK SEFERDE
      // gönderiyordu. Tek bir 1600px foto (ör. Biyo Link avatarı) genelde
      // sorun çıkarmıyor, ama BİRDEN FAZLA galeri fotoğrafı toplayan
      // formlarda (kafe, otel, restoran, emlak, kuaför vb. —
      // GalleryPickerField maxImages>1) toplam base64 boyutu Android'in
      // ~1MB Binder transaction limitini kolayca aşıyor ve Dart'ın
      // try/catch'inin YAKALAYAMADIĞI bir NATIVE çökmeye yol açıyordu —
      // "Site Oluştur'a basınca uygulamadan atıyor" şikayetinin kök nedeni
      // buydu. B modu (çok sayfa) zaten dosyaya yazıp loadFile ile
      // açıyordu (bkz. yukarısı, boyut sınırı YOK) — aynı deseni artık
      // tek sayfa moduna da uyguluyoruz.
      final indexPath =
          await DownloadService.writeFilesForPreview({'index.html': safeCode});
      _previewDirPath = File(indexPath).parent.path;
      await _controller.loadFile(indexPath);
    }
  }

  /// 25.08.2026 eklendi — "Düzenle" butonu: ekrandaki slotu üreten form
  /// türünü (AppState.qtCurrentKind) bulup o formu, daha önce kaydedilmiş
  /// alan değerleriyle (AppState.qtFormData) DOLU şekilde tekrar açar.
  /// Kullanıcı formda "Düzenlemeyi Bitir"e basıp geri döndüğünde (2 puan
  /// düşülerek), webview içeriği güncel siteyi göstermesi için yeniden
  /// yüklenir — geri tuşuyla (üretim yapmadan) dönülürse hiçbir şey
  /// değişmediğinden yeniden yükleme zararsızdır.
  Future<void> _openEditForm() async {
    final appState = context.read<AppState>();
    // 27.08.2026 eklendi — admin panelinden enjekte edilen projeler
    // (editableInApp=false) burada normalde HİÇ gösterilmeyen butona
    // erişemez (bkz. build() > editableInApp kontrolü), ama bu ikinci
    // bir güvenlik katmanı: buton her nasılsa tetiklenirse (ör. ileride
    // eklenecek başka bir çağıran taraf) yine de formu AÇMAZ.
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
  // 06.09.2026 eklendi (kanka isteği) — önizlemede DIŞ linkler (http/https,
  // tel, mailto, sms, whatsapp, harita/geo, market/intent) tıklanamasın;
  // sitenin KENDİ sayfaları arasındaki göreli linkler (ör. "urunler.html",
  // "#iletisim") ise DOKUNULMADAN aynen çalışmaya devam etsin — çok
  // sayfalı sitelerde önizlemede sayfa geçişi hâlâ bu linklerle yapılıyor.
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
      // 05.09.2026 eklendi — önceden sessizce yutuluyordu: enjeksiyon
      // başarısız olursa kullanıcı galerideki fotoğrafa dokunduğunda hiçbir
      // şey olmuyordu ve hiçbir yerde bunun sebebi görünmüyordu. Bu akış
      // kritik değil (site yine görüntülenebilir), o yüzden kullanıcıya
      // popup göstermiyoruz ama en azından debug log'da iz bırakıyoruz.
      debugPrint('[preview] _injectPageScripts JS enjeksiyonu başarısız: $e');
    }
  }

  /// Canlı WebView DOM'undan TAM HTML'i okuyup ilgili slotu günceller;
  /// böylece indirme/kaydetme her zaman en son seçilen fotoğrafı yansıtır.
  ///
  /// 05.09.2026 değiştirildi — ÖNCEDEN hata sessizce yutuluyordu ve metod
  /// her zaman başarılıymış gibi dönüyordu. Tek çağrı yeri olan
  /// `_pickImageForGallery`, bu sessizliğe güvenip HER ZAMAN "Fotoğraf
  /// güncellendi!" başarı mesajı gösteriyordu — yani DOM okuma veya diske
  /// yazma (`_persistCode`) patlasa bile kullanıcı fotoğrafın kaydedildiğini
  /// sanıyordu, oysa bir sonraki girişte/yayınlamada eski hâli görecekti.
  /// Artık hatayı fırlatıyoruz ki çağıran taraf gerçek sonucu görüp
  /// kullanıcıya doğru mesajı gösterebilsin.
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

  // ------------------------------------------------------------------
  // Galeri bölümü: bir <img>'e dokunulunca cihazdan fotoğraf seçtirip
  // görseli base64 data URI olarak DOM'daki elemanın yerine koyar, sonra
  // güncel kodu (qtGeneratedCode / qtGeneratedFiles) senkronlar ki
  // indirme her zaman en son seçilen fotoğrafı yansıtsın.
  // ------------------------------------------------------------------
  Future<void> _pickImageForGallery(int idx) async {
    try {
      final picker = ImagePicker();
      // NOT: imageQuality artık burada verilmiyor — asıl sıkıştırma
      // (WebP + kalite) aşağıda ImageCompressService ile yapılıyor.
      // 30.08.2026 eklendi — maxWidth YOKTU: tam çözünürlüklü (genelde
      // 8-12MP+) fotoğraflar base64'e çevrilip WebView'a runJavaScript
      // ile enjekte ediliyor, sonra _syncCodeFromWebView ile TÜM DOM
      // (bu dev base64 dahil) platform channel üzerinden geri okunup
      // projeye kaydediliyordu. Android'in Binder IPC transaction limiti
      // (~1MB) aşılınca native çökme oluyordu — Flutter'ın hata
      // yakalayıcıları (FlutterError.onError/runZonedGuarded) bunu
      // YAKALAYAMAZ, sessizce uygulama kapanır. gallery_picker_field.dart
      // ile AYNI sınır (1600px, native ön-limit olarak) uygulanarak
      // tutarlı hale getirildi. 06.09.2026 — WebP'ye geçişle birlikte
      // dosya boyutu ayrıca küçüldüğü için bu sınır artık ikinci bir
      // güvenlik katmanı (asıl küçültme ImageCompressService'te).
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
      // 05.09.2026 değiştirildi — _syncCodeFromWebView artık hatayı
      // yutmuyor, fırlatıyor (bkz. metodun kendi dokümantasyonu). Bu sayede
      // burada gerçekten kaydedilip kaydedilmediğini biliyoruz; önceden
      // sync patlasa bile aşağıdaki başarı mesajı hep gösteriliyordu.
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

  /// 28.08.2026 değiştirildi, 28.08.2026'da fiyat/akış revizyonuyla
  /// güncellendi — İNDİRME artık ücretsiz "reklam izle" akışı DEĞİL, HER
  /// ZAMAN ücretli bir kilit (bkz. widgets/download_purchase_sheet.dart).
  /// Proje zaten indirme hakkına (downloadPurchased) sahipse popup HİÇ
  /// gösterilmez, direkt indirilir — rozet kaldırılmış olması (watermarkRemoved)
  /// TEK BAŞINA bunu sağlamaz, aksi halde önce popup açılır (proje rozetsizse
  /// tek seçenekli, değilse iki seçenekli — bkz. download_purchase_sheet.dart),
  /// satın alma TAMAMLANMADAN indirme başlamaz.
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
      // Henüz kaydedilmemiş (yepyeni) bir slot indirme kilidine takılmamalı
      // — önce Projelerim'e kaydedilmesi lazım ki satın alma hangi projeye
      // uygulanacağını bilsin. Böyle bir durum burada normalde oluşmaz
      // (form akışı zaten üretim sırasında projeyi kaydeder), ama savunma
      // amaçlı net bir mesaj gösterilir.
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

    try {
      if (multi) {
        final files = _slotFiles(appState);
        final saved = await DownloadService.pickAndSaveZip(
            files: files, isEnglish: isEnglish(context));
        if (saved) await appState.markProjectExported();
        if (mounted && saved) {
          showAppPopup(context, message: t(context, 'ZIP dosyası cihaza kaydedildi! 📦'), icon: '✅');
        }
      } else {
        final code = _slotCode(appState);
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

  /// "Yayınla" — kararlaştırıldığı gibi SADECE e-posta ile giriş yapmış
  /// kullanıcılar için (bkz. login_gate.dart > requireLogin). Giriş yoksa
  /// burada bir bottom sheet açılıp kullanıcıdan giriş istenir; vazgeçerse
  /// akış burada durur, HostingService.publish'e hiç gidilmez.
  ///
  /// Worker henüz deploy edilmediyse (HostingConfig.baseUrl boş) publish
  /// sheet açılır ama içindeki istek [HostingNotConfiguredException]
  /// fırlatır — kullanıcıya net bir mesaj gösterilir, uygulama çökmez.
  Future<void> _publishSite() async {
    // 12.09.2026 eklendi (kanka isteği) — yayınlama huninin en üst adımı,
    // requireLogin/ödeme kontrolünden ÖNCE (bkz. analytics_service.dart).
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

    // 29.08.2026 kaldırıldı — uygulama reklamsız modele geçti, yayınlamadan
    // önce reklam izleme zorunluluğu yok. Yayın hakkı zaten ayrı bir satın
    // alma akışıyla (bkz. showPublishPaywallSheet) yönetiliyor.

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
    // 29.08.2026 düzeltildi — ESKİDEN tüm butonlar (Düzenle/Yayınla/İndir/
    // Rozeti Kaldır/Bildir/Kapat) TEK satıra sığdırılıyordu ve FittedBox
    // taşma olmasın diye HEPSİNİ birden küçültüyordu — 5-6 buton aynı anda
    // varken oran çok düşüp yazılar okunmaz hale geliyordu (kullanıcı geri
    // bildirimi). Artık iki katmanlı: üstte başlık+Kapat (hep aynı boyutta,
    // hep okunur), altta kalan butonlar bir Wrap içinde — ekrana sığmayan
    // butonlar KÜÇÜLMEK yerine ikinci bir satıra akıyor. Hiçbir buton asla
    // küçülmüyor, hiçbir zaman taşmıyor.
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
              // 29.08.2026 düzeltildi (v3) — Bildir (bayrak) butonu
              // önceden grid'in altında tek başına sağda duruyordu,
              // altında/yanında boş alan bırakıyordu ("çirkin"
              // kullanıcı geri bildirimi). Kapat butonunun zaten
              // fazladan boşluğu olan satırına taşındı.
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
          // 29.08.2026 düzeltildi (v2) — Wrap her butonu kendi satırına
          // düşürüyordu (2-3 buton kaldığında bile), bu da "abartılı"
          // (aşırı boşluklu, dev pilller) bir görünüme yol açıyordu.
          // Artık sabit 2 sütunlu grid: her satırda İKİ buton Expanded
          // ile eşit pay alıyor — ne eski tek-satır küçülmesi var
          // (font hep 13, hiç ölçeklenmiyor) ne de yeni tek-buton-tek-
          // satır israfı. Buton sayısı koşullu olarak değişse de
          // (Düzenle / Rozeti Kaldır bazen gizli) satırlar otomatik
          // ikişer ikişer diziliyor, tek kalan varsa yarım genişlikte
          // sola yaslı kalıyor.
          Builder(builder: (context) {
            final actionButtons = <Widget>[
              // 25.08.2026 eklendi: Ön izlemeden dönmeden, doğrudan
              // formu dolu şekilde tekrar açıp düzenleyebilme akışı
              // (bkz. _openEditForm).
              //
              // 27.08.2026 eklendi: admin panelinden enjekte edilen
              // (editableInApp=false) projelerde bu buton HİÇ
              // gösterilmez — elle hazırlanmış HTML'in kazara forma
              // göre yeniden üretilip üzerine yazılmasını önler (bkz.
              // AppState.qtCurrentEditableInApp).
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
