import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import '../widgets/quota_limit_popup.dart';
import '../localization/app_strings.dart';
import 'analytics_service.dart';

/// QuickGenerationHelper'ın (Worker/quota tabanlı) yerini alan sürüm.
/// Uzak sunucu çağrısı, kota kontrolü, WorkerService YOKTUR —
/// [buildHtml] senkron/local bir fonksiyon çalıştırılıp doğrudan
/// appState'in Hızlı Araçlar'a AİT AYRI slotuna (qtGeneratedCode /
/// qtGeneratedFiles) yazılır.
///
/// Kullanım (örn. kuafor_form_screen.dart içinde):
///   await LocalGenerationHelper.generateSinglePage(
///     context: context,
///     projectNameHint: nameCtrl.text,
///     kind: ProjectKind.site,
///     buildHtml: () => generateBusinessSiteHtml(...),
///   );
///
/// 25.08.2026 eklendi — DÜZENLE AKIŞI: [isEditing] true ise:
///   - Maliyet costSinglePage/costMultiPage YERİNE sabit AppState.costEdit
///     (2 puan) kullanılır (tek/çok sayfa farketmez).
///   - detachQtSlotForNewProject() ÇAĞRILMAZ — böylece ekrandaki slot aynı
///     projeye bağlı kalır ve _touchQtProjectFromCurrent üretim sonrası
///     YENİ bir proje oluşturmak yerine VAR OLANI günceller.
/// [formData] verildiğinde (bkz. her form ekranının _captureFormData()'ı),
/// başarılı üretimden sonra AppState.qtFormData'ya yazılır ki bir sonraki
/// "Düzenle" bu formu dolu açabilsin.
class LocalGenerationHelper {
  static Future<bool> generateSinglePage({
    required BuildContext context,
    required String projectNameHint,
    required ProjectKind kind,
    required String Function() buildHtml,
    bool isEditing = false,
    Map<String, dynamic>? formData,
  }) async {
    final appState = context.read<AppState>();
    final cost = isEditing ? AppState.costEdit : AppState.costSinglePage;

    // FORM puan kotası kontrol edilir (tek sayfa üretim = 5 puan,
    // düzenleme = 2 puan).
    if (!await appState.ensureFormQuotaFor(cost)) {
      if (context.mounted) await showQuotaLimitPopup(context);
      return false;
    }

    // 29.08.2026 kaldırıldı — uygulama reklamsız modele geçti, "Siteyi
    // Oluştur" akışında artık interstitial reklam gösterilmiyor.

    // Düzenleme akışında slot AYNI projeye bağlı kalmalı — yeni bir
    // proje açılmaması için detach ATLANIR.
    if (!isEditing) {
      await appState.detachQtSlotForNewProject();
    }
    appState.setGenerating(true);
    try {
      final html = buildHtml();
      appState.updateQtGeneratedCode(html, projectName: projectNameHint, kind: kind);
      appState.setQtFormData(formData ?? {}, kind: kind);
      await appState.consumeFormQuota(cost);
      unawaited(AnalyticsService.logSiteGenerated(
        source: 'form',
        mode: 'single',
        kind: kind.name,
      ));
      return true;
    } catch (e) {
      if (context.mounted) {
        // Değişken ($e) içerdiği için t() map'i yerine isEnglish() ile
        // dallanıyor — 2026-08-24: eskiden bu metin İngilizce modda bile
        // hep Türkçe kalıyordu.
        final prefix = isEnglish(context) ? 'Failed to generate' : 'Oluşturulamadı';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$prefix: $e')));
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
  /// DOĞRULANDI: appState.updateQtGeneratedFiles(files, {projectName, kind,
  /// activeFileName}) imzası app_state.dart ile birebir eşleşiyor
  /// (bkz. state/app_state.dart). [isEditing]/[formData] bkz. yukarıdaki
  /// generateSinglePage dokümantasyonu — aynı kurallar burada da geçerli.
  static Future<bool> generateMultiPage({
    required BuildContext context,
    required String projectNameHint,
    required ProjectKind kind,
    required Map<String, String> Function() buildFiles,
    String? activeFileName,
    bool isEditing = false,
    Map<String, dynamic>? formData,
  }) async {
    final appState = context.read<AppState>();
    final cost = isEditing ? AppState.costEdit : AppState.costMultiPage;

    // FORM puan kotası kontrol edilir (çok sayfa üretim = 10 puan,
    // düzenleme = 2 puan).
    if (!await appState.ensureFormQuotaFor(cost)) {
      if (context.mounted) await showQuotaLimitPopup(context);
      return false;
    }

    // 29.08.2026 kaldırıldı — bkz. generateSinglePage'teki AYNI değişiklik.

    if (!isEditing) {
      await appState.detachQtSlotForNewProject();
    }
    appState.setGenerating(true);
    try {
      final files = buildFiles();
      appState.setQtSiteMode(SiteMode.multi);
      appState.updateQtGeneratedFiles(
        files,
        projectName: projectNameHint,
        kind: kind,
        activeFileName: activeFileName ?? files.keys.first,
      );
      appState.setQtFormData(formData ?? {}, kind: kind);
      await appState.consumeFormQuota(cost);
      unawaited(AnalyticsService.logSiteGenerated(
        source: 'form',
        mode: 'multi',
        kind: kind.name,
      ));
      return true;
    } catch (e) {
      if (context.mounted) {
        final prefix = isEnglish(context) ? 'Failed to generate' : 'Oluşturulamadı';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$prefix: $e')));
      }
      return false;
    } finally {
      appState.setGenerating(false);
    }
  }
}
