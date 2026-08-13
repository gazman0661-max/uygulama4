import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';

/// QuickGenerationHelper'ın (Gemini/quota tabanlı) yerini alan sürüm.
/// AI çağrısı, kota kontrolü, WorkerService/GeminiService YOKTUR —
/// [buildHtml] senkron/local bir fonksiyon çalıştırılıp doğrudan
/// appState.updateGeneratedCode ile sonuca yazılır.
///
/// Kullanım (örn. kuafor_form_screen.dart içinde):
///   await LocalGenerationHelper.generateSinglePage(
///     context: context,
///     projectNameHint: nameCtrl.text,
///     kind: ProjectKind.site,
///     buildHtml: () => generateBusinessSiteHtml(...),
///   );
class LocalGenerationHelper {
  static Future<bool> generateSinglePage({
    required BuildContext context,
    required String projectNameHint,
    required ProjectKind kind,
    required String Function() buildHtml,
  }) async {
    final appState = context.read<AppState>();

    await appState.detachSlotForNewProject();
    appState.setGenerating(true);
    try {
      final html = buildHtml();
      appState.updateGeneratedCode(html, projectName: projectNameHint, kind: kind);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Oluşturulamadı: $e')));
      }
      return false;
    } finally {
      appState.setGenerating(false);
    }
  }

  /// Çok Sayfa (B) modu için — real_estate_html_generator.dart gibi tek
  /// seferde `Map<String, String>` (dosya adı -> html) döndüren
  /// generator'larla kullanılır (bkz. real_estate_form_screen.dart).
  ///
  /// DOĞRULANDI: appState.updateGeneratedFiles(files, {projectName, kind,
  /// activeFileName}) imzası app_state.dart ile birebir eşleşiyor
  /// (bkz. state/app_state.dart).
  static Future<bool> generateMultiPage({
    required BuildContext context,
    required String projectNameHint,
    required ProjectKind kind,
    required Map<String, String> Function() buildFiles,
    String? activeFileName,
  }) async {
    final appState = context.read<AppState>();

    await appState.detachSlotForNewProject();
    appState.setGenerating(true);
    try {
      final files = buildFiles();
      appState.updateGeneratedFiles(
        files,
        projectName: projectNameHint,
        kind: kind,
        activeFileName: activeFileName ?? files.keys.first,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Oluşturulamadı: $e')));
      }
      return false;
    } finally {
      appState.setGenerating(false);
    }
  }
}
