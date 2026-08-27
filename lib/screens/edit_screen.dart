import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/xml.dart' as hl_xml;
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:html/parser.dart' as html_parser;
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';
import '../services/ai_response_utils.dart';
import '../services/download_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/ai_edit_dialog.dart';
import '../widgets/ai_busy_popup.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import 'preview_screen.dart';

/// Basit bir düzenleme sorununu (unclosed / mismatched tag) temsil eder.
/// CodeMirror'daki "lint" gutter'ının basitleştirilmiş bir karşılığıdır.
class _LintIssue {
  final int line; // 1 tabanlı satır no
  final String message;
  final bool isWarning; // false = hata (kırmızı), true = uyarı (turuncu)
  _LintIssue(this.line, this.message, {this.isWarning = false});
}

// Kendi kendini kapatan (self-closing sayılan) HTML void elementleri.
// Bunlar için kapanış etiketi aranmaz.
const _voidTags = {
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
  'link', 'meta', 'param', 'source', 'track', 'wbr',
};

/// DÜZENLE ekranı.
///
/// index.html'deki CodeMirror tabanlı editörün Flutter karşılığı:
/// - Kod TAMAMEN elle düzenlenebilir (artık salt okunur değil)
/// - Cihazdan .html/.txt dosyası içe aktarılabilir (kod bilmeyen/bilen
///   fark etmeksizin, kendi hazırladığı dosyayı yükleyip üzerinde çalışabilir)
/// - Sözdizimi renklendirmesi (syntax highlighting) + basit hata/uyarı
///   denetimi (kapanmamış/uyuşmayan etiketler) CodeMirror'daki lint
///   panelinin sadeleştirilmiş bir karşılığı olarak sağlanır
/// - "✨ AI" popup'ı önceki gibi duruyor: kod bilmeyen kullanıcı için
///   tek seferlik istekle AI'ya TAM KODU güncelletme seçeneği
class EditScreen extends StatefulWidget {
  const EditScreen({super.key});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final CodeController _codeController;
  Timer? _lintDebounce;
  List<_LintIssue> _issues = [];
  bool _issuesPanelOpen = false;
  bool _aiBusy = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final code = _readCurrentCode(context.read<AppState>());
    _codeController = CodeController(
      text: code,
      language: hl_xml.xml, // HTML, highlight.js'de 'xml' modu ile renklendirilir
    );
    _codeController.addListener(_onCodeChanged);
    _relint(code);
  }

  /// A modunda generatedCode'u, B modunda editörde şu an açık olan aktif
  /// dosyanın (activeFileName) içeriğini döndürür.
  String _readCurrentCode(AppState appState) {
    if (appState.siteMode == SiteMode.multi) {
      final active = appState.activeFileName;
      return active != null ? (appState.generatedFiles[active] ?? '') : '';
    }
    return appState.generatedCode;
  }

  /// Yazılan kodu doğru yere kaydeder: A modunda generatedCode, B modunda
  /// sadece editörde açık olan dosyayı (diğer sayfalar etkilenmez).
  void _writeCurrentCode(AppState appState, String code) {
    if (appState.siteMode == SiteMode.multi) {
      appState.updateActiveFileContent(code);
    } else {
      appState.updateGeneratedCode(code);
    }
  }

  /// B modunda birden fazla dosya arasında geçiş (index.html, urunler.html...).
  void _switchActiveFile(AppState appState, String fileName) {
    // Ekrandaki değişiklikleri kaybetmeden önce mevcut dosyayı kaydet.
    _writeCurrentCode(appState, _codeController.text);
    appState.setActiveFile(fileName);
    final newCode = appState.generatedFiles[fileName] ?? '';
    _codeController.text = newCode;
    _relint(newCode);
  }

  @override
  void dispose() {
    _lintDebounce?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    _lintDebounce?.cancel();
    _lintDebounce = Timer(const Duration(milliseconds: 500), () {
      _relint(_codeController.text);
    });
  }

  /// index.html'deki CodeMirror "lint" addon'unun sadeleştirilmiş karşılığı.
  /// İki katmanlı denetim yapar:
  /// 1) package:html'in HTML5 ayrıştırıcısından gelen (çok ciddi bozuk
  ///    kodlarda oluşan) ayrıştırma hataları.
  /// 2) Etiket açma/kapama dengesini kontrol eden basit bir stack tabanlı
  ///    kontrol (kapanmamış / uyuşmayan etiketleri yakalar). package:html
  ///    tarayıcılar gibi çok toleranslı davrandığı için (neredeyse hiçbir
  ///    şeyde sert hata vermez), asıl faydalı uyarılar bu ikinci katmandan
  ///    gelir.
  void _relint(String code) {
    final issues = <_LintIssue>[];

    // Katman 1: package:html ayrıştırma hataları
    try {
      final parser = html_parser.HtmlParser(code, generateSpans: true);
      parser.parse();
      for (final e in parser.errors) {
        final line = (e.span?.start.line ?? 0) + 1;
        issues.add(_LintIssue(line, e.message));
      }
    } catch (_) {
      // Ayrıştırıcı çöktüyse sessizce geç, katman 2 zaten çalışacak.
    }

    // Katman 2: basit açma/kapama etiket dengesi kontrolü
    final tagRe = RegExp(r'<\s*(/?)\s*([a-zA-Z][a-zA-Z0-9-]*)([^<>]*)>');
    final stack = <MapEntry<String, int>>[]; // tagName -> satır no
    int line = 1;
    int lastEnd = 0;
    for (final m in tagRe.allMatches(code)) {
      line += '\n'.allMatches(code.substring(lastEnd, m.start)).length;
      lastEnd = m.start;
      final closing = m.group(1) == '/';
      final tag = m.group(2)!.toLowerCase();
      final attrs = m.group(3) ?? '';
      final selfClosing = attrs.trimRight().endsWith('/') || _voidTags.contains(tag);
      if (tag == 'script' || tag == 'style') {
        // içerikleri HTML etiketi gibi taranmasın (JS/CSS'de < > çok geçebilir)
        if (!closing && !selfClosing) stack.add(MapEntry(tag, line));
        if (closing && stack.isNotEmpty && stack.last.key == tag) stack.removeLast();
        continue;
      }
      if (selfClosing) continue;
      if (!closing) {
        stack.add(MapEntry(tag, line));
      } else {
        if (stack.isNotEmpty && stack.last.key == tag) {
          stack.removeLast();
        } else if (stack.any((e) => e.key == tag)) {
          // İç içe geçmiş yanlış sıralama
          issues.add(_LintIssue(line, "</$tag> beklenmedik yerde kapandı, sıralamayı kontrol et"));
          stack.removeWhere((e) => e.key == tag);
        } else {
          issues.add(_LintIssue(line, "</$tag> için açılış etiketi bulunamadı", isWarning: true));
        }
      }
    }
    for (final open in stack) {
      issues.add(_LintIssue(open.value, "<${open.key}> etiketi kapatılmamış"));
    }

    issues.sort((a, b) => a.line.compareTo(b.line));
    if (mounted) setState(() => _issues = issues);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      context.read<AppState>().addImage(File(file.path));
      showAppPopup(context, message: 'Görsel eklendi.', icon: '🖼️');
    }
  }

  /// Cihazdaki bir .html/.txt dosyasını doğrudan editöre yükler.
  /// Kod bilmeyen kullanıcı hazır bir HTML dosyasını içeri atıp AI ile
  /// düzenletebilir; kod bilen kullanıcı ise direkt elle üzerinde çalışabilir.
  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['html', 'htm', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      String? content;
      if (picked.bytes != null) {
        content = String.fromCharCodes(picked.bytes!);
      } else if (picked.path != null) {
        content = await File(picked.path!).readAsString();
      }
      if (content == null) return;
      if (!mounted) return;
      // Önce ekranda açık olan (varsa) proje kaybolmadan kaydedilir, sonra
      // içe aktarılan dosya AYRI/YENİ bir proje olarak başlatılır. Eskiden
      // içe aktarma doğrudan tek slota yazıyordu ve o an açık olan farklı
      // bir proje sessizce üzerine yazılıp kaybolabiliyordu — artık öyle
      // olmaz, her ikisi de Projelerim'de ayrı kayıtlar olarak durur.
      await context.read<AppState>().importCodeAsNewProject(
            content,
            sourceName: picked.name,
          );
      if (!mounted) return;
      _codeController.text = content;
      _relint(content);
      showAppPopup(context, message: isEnglish(context) ? '"${picked.name}" imported as a new project.' : '"${picked.name}" yeni bir proje olarak içeri aktarıldı.', icon: '📂');
    } catch (e) {
      if (!mounted) return;
      showAppPopup(context, message: '${isEnglish(context) ? 'Could not read file' : 'Dosya okunamadı'}: $e', icon: '⚠️');
    }
  }

  void _saveSilently() {
    _writeCurrentCode(context.read<AppState>(), _codeController.text);
  }

  /// Toolbar'daki "İNDİR": A modunda tek .html dosyasını, B modunda TÜM
  /// dosyaları .zip olarak cihaza yazıp paylaşım/kaydetme menüsünü açar.
  Future<void> _save() async {
    _saveSilently();
    if (_saving) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    try {
      if (appState.siteMode == SiteMode.multi) {
        if (appState.generatedFiles.isEmpty) {
          showAppPopup(context, message: 'Önce sohbetten bir site oluşturmanız gerekiyor.', icon: 'ℹ️');
          return;
        }
        final saved = await DownloadService.pickAndSaveZip(files: appState.generatedFiles);
        if (saved) await appState.markProjectExported();
        if (mounted && saved) showAppPopup(context, message: 'ZIP dosyası cihaza kaydedildi! 📦', icon: '✅');
      } else {
        if (appState.generatedCode.isEmpty) {
          showAppPopup(context, message: 'Önce sohbetten bir site oluşturmanız gerekiyor.', icon: 'ℹ️');
          return;
        }
        final saved = await DownloadService.pickAndSaveHtml(html: appState.generatedCode);
        if (saved) await appState.markProjectExported();
        if (mounted && saved) showAppPopup(context, message: 'HTML dosyası cihaza kaydedildi! 💾', icon: '✅');
      }
    } catch (e) {
      if (mounted) showAppPopup(context, message: '${isEnglish(context) ? 'Download failed' : 'İndirme başarısız'}: $e', icon: '⚠️');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openPreview() {
    _saveSilently();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PreviewScreen()),
    );
  }

  /// Toolbar'daki "✨ AI" butonu: kod bilmeyen kullanıcı için hâlâ burada,
  /// tek seferlik istek TAM KODA (manuel düzenlemeye ek olarak) uygulanır.
  Future<void> _openAiDialog() async {
    final request = await showAiEditDialog(
      context: context,
      icon: '✨',
      title: t(context, 'AI Kod Düzenleyici'),
      description:
          "Kodda ne değiştirmek veya eklemek istersiniz? Örn: 'Bu butonun rengini kırmızı yap' "
          "veya 'Sayfaya bir WhatsApp butonu ekle'. Sadece istediğiniz kısım değişir, geri kalanı aynı kalır.",
      hint: 'Örn: Bu bölümün arka planını mor yap, başlığı büyüt...',
      accent: AppColors.accentPurple,
    );
    if (request == null || request.isEmpty) return;
    await _sendAiEdit(request);
  }

  Future<void> _sendAiEdit(String request) async {
    if (_aiBusy) return;
    final appState = context.read<AppState>();

    // A ve B modu arasında farkeden tek şey hangi "currentCode"un
    // gönderildiği (A: generatedCode, B: editörde açık aktif dosya).
    // Gemini'ye "full_edit" tipi diff-tabanlı prompt gönderilir.
    setState(() => _aiBusy = true);
    try {
      final currentCode = _readCurrentCode(appState);
      final updated = await GeminiService.editFullCode(
        currentCode: currentCode,
        request: request,
      );
      _writeCurrentCode(appState, updated);
      if (!mounted) return;
      _codeController.text = updated;
      _relint(updated);
      showAppPopup(context, message: 'AI değişikliği uyguladı!', icon: '✨');
    } on GeminiNotConfiguredException catch (e) {
      if (!mounted) return;
      showAppPopup(context, message: e.message, icon: '⚙️');
    } on AiRejectedException catch (e) {
      if (!mounted) return;
      showAppPopup(context, message: e.message, icon: '🛠️');
    } on GeminiRateLimitException catch (_) {
      if (!mounted) return;
      await showAiBusyPopup(context);
    } catch (e) {
      if (!mounted) return;
      showAppPopup(context, message: '${isEnglish(context) ? 'Error' : 'Hata'}: $e', icon: '⚠️');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final errorCount = _issues.where((i) => !i.isWarning).length;
    final warningCount = _issues.where((i) => i.isWarning).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),
            _buildFileTabsIfMulti(),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CodeTheme(
                      data: CodeThemeData(styles: atomOneDarkTheme),
                      child: CodeField(
                        controller: _codeController,
                        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        background: const Color(0xFF0D0D0D),
                        wrap: false,
                      ),
                    ),
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
                            Text(t(context, '✨ AI kodu düzenliyor...'),
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildIssuesBar(errorCount, warningCount),
            if (_issuesPanelOpen) _buildIssuesPanel(),
          ],
        ),
      ),
    );
  }

  /// B modunda (çok sayfa) hangi dosyanın düzenlendiğini gösteren ve
  /// aralarında geçiş yapılan sekme satırı. A modunda hiç görünmez.
  Widget _buildFileTabsIfMulti() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.siteMode != SiteMode.multi || appState.generatedFiles.isEmpty) {
          return const SizedBox.shrink();
        }
        final fileNames = appState.generatedFiles.keys.toList();
        return Container(
          color: const Color(0xFF10151D),
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            itemCount: fileNames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final name = fileNames[i];
              final selected = appState.activeFileName == name;
              return GestureDetector(
                onTap: () => _switchActiveFile(appState, name),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accentCyan.withOpacity(0.18) : null,
                    border: Border.all(
                      color: selected ? AppColors.accentCyan : Colors.white24,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: selected ? AppColors.accentCyan : Colors.white60,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// CodeMirror'daki lint gutter'ının basit karşılığı: alt bilgi çubuğu +
  /// açılıp kapanan hata/uyarı listesi.
  Widget _buildIssuesBar(int errorCount, int warningCount) {
    final ok = _issues.isEmpty;
    return InkWell(
      onTap: _issues.isEmpty ? null : () => setState(() => _issuesPanelOpen = !_issuesPanelOpen),
      child: Container(
        width: double.infinity,
        color: const Color(0xFF141821),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: ok ? Colors.greenAccent : (errorCount > 0 ? AppColors.danger : Colors.orangeAccent),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ok
                    ? t(context, 'Etiket denetimi temiz')
                    : (isEnglish(context)
                        ? '$errorCount error(s), $warningCount warning(s) found'
                        : '$errorCount hata, $warningCount uyarı bulundu'),
                style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            if (!ok)
              Icon(_issuesPanelOpen ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      color: const Color(0xFF10151D),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _issues.length,
        itemBuilder: (context, i) {
          final issue = _issues[i];
          return ListTile(
            dense: true,
            leading: Icon(
              issue.isWarning ? Icons.warning_amber_rounded : Icons.close,
              size: 16,
              color: issue.isWarning ? Colors.orangeAccent : AppColors.danger,
            ),
            title: Text(
              issue.message,
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
            ),
            trailing: Text(
              isEnglish(context) ? 'line ${issue.line}' : 'satır ${issue.line}',
              style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11),
            ),
            onTap: () {
              // Tıklanan satıra imleci götür (yaklaşık konum).
              final lines = _codeController.text.split('\n');
              int offset = 0;
              for (var l = 0; l < issue.line - 1 && l < lines.length; l++) {
                offset += lines[l].length + 1;
              }
              _codeController.selection = TextSelection.collapsed(offset: offset.clamp(0, _codeController.text.length));
            },
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF141821),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(t(context, 'DÜZENLE'),
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.image_outlined, color: AppColors.accentPurple),
                onPressed: _pickImage,
                tooltip: t(context, 'Görsel Ekle'),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open, color: Colors.orangeAccent),
                onPressed: _importFile,
                tooltip: t(context, '.html / .txt Dosyası Aç'),
              ),
              // AppConfig.aiEditingEnabled false iken bu buton hiç
              // render edilmiyor (bkz. lib/config/app_config.dart) —
              // bu ekrana zaten normal şartlarda hiç girilemiyor, ama
              // burası ikinci bir güvenlik katmanı.
              if (AppConfig.aiEditingEnabled)
                PillButton(
                  label: t(context, 'AI'),
                  emoji: '✨',
                  borderColor: AppColors.accentPurple,
                  textColor: AppColors.accentPurple,
                  height: 34,
                  fontSize: 12.5,
                  onTap: _aiBusy ? null : _openAiDialog,
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _openPreview,
                child: Text(t(context, 'ÖN İZLEME'),
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.accentRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'monospace')),
              ),
              TextButton(
                onPressed: _save,
                child: Text(t(context, 'İNDİR'),
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'monospace')),
              ),
              TextButton(
                onPressed: () {
                  _saveSilently();
                  Navigator.of(context).pop();
                },
                child: Text(t(context, 'Kapat'),
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
