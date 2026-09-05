import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import 'free_plan_restriction_service.dart';
import '../widgets/quota_limit_popup.dart';
import '../localization/app_strings.dart';
import 'analytics_service.dart';
import '../widgets/app_popup.dart';

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

    // 02.09.2026 düzeltildi — ÖNEMLİ DONMA DÜZELTMESİ: ensureFormQuotaFor
    // ve detachQtSlotForNewProject çağrıları eskiden bu try bloğunun
    // DIŞINDAYDI. Biri hata fırlatırsa (ör. SharedPreferences erişim
    // sorunu), hata YAKALANMADAN çağıran form ekranına (bkz. örn.
    // bio_link_form_screen.dart _generate()) kadar yayılıyordu — o ekran
    // da bunu yakalamadığı için setState(() => _generating = false) SATIRI
    // HİÇ ÇALIŞMIYOR ve buton sonsuza dek "Oluşturuluyor..." yazılı
    // kalıyordu (Biyo Link'te bildirilen "donuyor" şikayetinin kök nedeni
    // buydu). Artık TÜM akış tek bir try/catch/finally içinde; hangi
    // adımda hata olursa olsun appState.setGenerating(false) ÇAĞRILACAK
    // ve çağıran ekran await'ten (hatasız ya da hatalı) MUTLAKA dönecek.
    appState.setGenerating(true);
    try {
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
      // 05.09.2026 eklendi (kanka isteği) — talep formu artık ÇIKTI
      // temizliği yerine ÜRETİM ANINDA engelleniyor: contactBlockHtml
      // (shared_html_blocks.dart) bu flag'i okuyup free plan'da leadForm'u
      // hiç yazmıyor. buildHtml() SENKRON çalıştığı için flag'in doğru
      // değeri okuduğundan emin olmak için tam burada, çağrıdan HEMEN önce
      // set ediliyor.
      FreePlanRestrictionService.isPremiumGeneration = appState.qtCurrentIsPremium;
      final html = buildHtml();
      FreePlanRestrictionService.isPremiumGeneration = true;
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
        showAppPopup(context, message: '$prefix: $e', icon: '⚠️');
      }
      return false;
    } finally {
      appState.setGenerating(false);
      // 05.09.2026 eklendi — hata fırlatılsa bile (yukarıdaki catch), flag'i
      // TRUE'a geri döndür ki bir sonraki üretim (ör. demo şablon
      // önizlemesi) yanlışlıkla free-plan kısıtlamasını miras almasın.
      FreePlanRestrictionService.isPremiumGeneration = true;
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

    // 02.09.2026 düzeltildi — bkz. generateSinglePage'teki AYNI donma
    // düzeltmesi: ensureFormQuotaFor/detachQtSlotForNewProject artık
    // try/finally İÇİNDE, böylece bu ikisinden biri hata fırlatsa bile
    // appState.setGenerating(false) MUTLAKA çağrılır ve buton sonsuza dek
    // "Oluşturuluyor..." yazılı takılı kalmaz.
    appState.setGenerating(true);
    try {
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
      // 05.09.2026 eklendi (kanka isteği) — bkz. generateSinglePage'teki
      // AYNI açıklama; çok sayfalı modda her dosya AYNI buildFiles() çağrısı
      // içinde üretildiği için flag tek seferde set edilmesi yeterli.
      FreePlanRestrictionService.isPremiumGeneration = appState.qtCurrentIsPremium;
      final files = buildFiles();
      FreePlanRestrictionService.isPremiumGeneration = true;
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
        showAppPopup(context, message: '$prefix: $e', icon: '⚠️');
      }
      return false;
    } finally {
      appState.setGenerating(false);
      // 05.09.2026 eklendi — bkz. generateSinglePage'teki AYNI güvenlik ağı.
      FreePlanRestrictionService.isPremiumGeneration = true;
    }
  }
}
