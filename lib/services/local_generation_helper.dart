import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import 'free_plan_restriction_service.dart';
import 'free_plan_page_limit_service.dart';
import '../widgets/quota_limit_popup.dart';
import '../widgets/premium_locked_popup.dart';
import '../localization/app_strings.dart';
import 'analytics_service.dart';
import '../widgets/app_popup.dart';
import '../templates/html/shared_html_blocks.dart' show isPremiumTheme, isPremiumLayoutStyle;

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
  /// 06.09.2026 eklendi (kanka isteği) — "Profesyonel görünümlü premium
  /// tema/hero düzeni" özelliği. [FreePlanPageLimitService.canUseMultiPage]
  /// gate'iyle AYNI desen: seçim aşamasında (ThemePickerField/
  /// LayoutStylePickerField) HİÇBİR ŞEY kilitlenmez — kanka kararı "şablon
  /// tamamen açık görünsün" — kısıtlama SADECE "Oluştur"a basıldığı bu
  /// noktada uygulanır. Free kullanıcı premium bir tema/düzen seçip
  /// Oluştur'a basarsa üretim İPTAL edilir (puan HARCANMAZ, proje
  /// KAYDEDİLMEZ) ve bilgilendirici kilit popup'ı gösterilir — kullanıcı
  /// ya ücretsiz bir seçeneğe döner ya da (ileride) premium'a geçer.
  static bool _isPremiumChoiceLocked({
    required bool isPremiumAccount,
    String? selectedThemeId,
    String? selectedLayoutStyle,
  }) {
    if (isPremiumAccount) return false;
    return isPremiumTheme(selectedThemeId) || isPremiumLayoutStyle(selectedLayoutStyle);
  }

  static Future<bool> _showPremiumChoiceLockedPopup(BuildContext context) {
    return showPremiumLockedPopup(
      context,
      message: isEnglish(context)
          ? 'This theme/layout is part of the Premium collection. Pick a free theme or layout to continue — or unlock Premium after creating your site.'
          : 'Bu tema/düzen Premium koleksiyonuna ait. Devam etmek için ücretsiz bir tema/düzen seç — istersen siteni oluşturduktan sonra Premium\'a geçip bunu kullanabilirsin.',
    ).then((_) => false);
  }

  static Future<bool> generateSinglePage({
    required BuildContext context,
    required String projectNameHint,
    required ProjectKind kind,
    required String Function() buildHtml,
    bool isEditing = false,
    Map<String, dynamic>? formData,
    // 06.09.2026 eklendi — bkz. [_isPremiumChoiceLocked] dokümanı. Formun
    // o an seçili tema/hero düzeni id'lerini geçirmek yeterli, geri kalanı
    // (gate + popup) burada merkezi olarak yönetilir.
    String? selectedThemeId,
    String? selectedLayoutStyle,
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
      // 06.09.2026 eklendi — bkz. [_isPremiumChoiceLocked] dokümanı. Puan
      // kotası kontrolünden ÖNCE yapılır ki kilitli seçimde puan hiç
      // harcanmasın (FreePlanPageLimitService gate'iyle AYNI sıralama).
      if (_isPremiumChoiceLocked(
        isPremiumAccount: appState.qtCurrentIsPremium,
        selectedThemeId: selectedThemeId,
        selectedLayoutStyle: selectedLayoutStyle,
      )) {
        if (context.mounted) await _showPremiumChoiceLockedPopup(context);
        return false;
      }

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
      // 06.09.2026 DÜZELTİLDİ (kanka bulgusu — kod incelemesi) — flag artık
      // elle set/reset edilmiyor, FreePlanRestrictionService.runGeneration
      // save/restore deseniyle yönetiyor (bkz. o metodun dokümanı: hata
      // olsa bile ÖNCEKİ değere döner, sabit `true`'ya değil).
      final html = FreePlanRestrictionService.runGeneration(
        appState.qtCurrentIsPremium,
        buildHtml,
      );
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
      // 06.09.2026 DÜZELTİLDİ — flag'in geri yüklenmesi artık YUKARIDAKİ
      // FreePlanRestrictionService.runGeneration'ın kendi try/finally'si
      // içinde (save/restore ile) yapılıyor; burada AYRICA sabit `true`'ya
      // zorlamaya gerek yok (bkz. o metodun "neden sabit true değil" notu).
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
    // 06.09.2026 eklendi — bkz. generateSinglePage'teki AYNI parametreler
    // ve [_isPremiumChoiceLocked] dokümanı.
    String? selectedThemeId,
    String? selectedLayoutStyle,
    // 06.09.2026 eklendi (kanka isteği) — Emlak (real_estate_form_screen.dart)
    // gibi tek sayfa alternatifi OLMAYAN sektörler için true geçilir; bkz.
    // FreePlanPageLimitService sınıf dokümanındaki NOT. Diğer TÜM
    // çağıranlarda (kafe/klinik/portfolyo/genel işletme vb. — hepsinde
    // zaten bir Tek Sayfa/Çok Sayfa anahtarı var) varsayılan false kalır.
    bool alwaysMultiPage = false,
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
      // 06.09.2026 eklendi — bkz. generateSinglePage'teki AYNI gate,
      // buradaki sıralama da diğer TÜM kilitlerden (çok sayfa limiti,
      // puan kotası) ÖNCE — kilitli seçimde ne sayfa limiti hesaplanır ne
      // puan harcanır.
      if (_isPremiumChoiceLocked(
        isPremiumAccount: appState.qtCurrentIsPremium,
        selectedThemeId: selectedThemeId,
        selectedLayoutStyle: selectedLayoutStyle,
      )) {
        if (context.mounted) await _showPremiumChoiceLockedPopup(context);
        return false;
      }

      // 06.09.2026 eklendi (kanka isteği) — ÇOK SAYFA KISITLAMASI (bkz.
      // FreePlanPageLimitService dokümanı). "Hangi proje?" sorusu isEditing'e
      // göre cevaplanır: isEditing=false ise bu HER ZAMAN yepyeni bir proje
      // üretimidir (detachQtSlotForNewProject birazdan qtCurrentProjectId'i
      // null'a çekecek) — domain/mini paket sadece VAR OLAN, yayınlanmış bir
      // projeye satın alınabildiği için (bkz. DomainService/MiniPackageService)
      // yepyeni bir proje ASLA premium olamaz, o yüzden qtCurrentProject'e hiç
      // bakmadan null geçiyoruz. isEditing=true ise qtCurrentProjectId zaten
      // düzenlenen projeyi gösteriyor (detach bu durumda ÇAĞRILMAZ).
      final gateProject = isEditing ? appState.qtCurrentProject : null;
      if (!FreePlanPageLimitService.canUseMultiPage(gateProject, alwaysMultiPage: alwaysMultiPage)) {
        if (context.mounted) {
          await showPremiumLockedPopup(
            context,
            message: FreePlanPageLimitService.lockedMessage(
              isEnglish(context),
              alwaysMultiPage: alwaysMultiPage,
            ),
          );
        }
        return false;
      }
      final maxTotalPages = FreePlanPageLimitService.maxTotalPagesFor(
        gateProject,
        alwaysMultiPage: alwaysMultiPage,
      );

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
      // 06.09.2026 DÜZELTİLDİ — bkz. generateSinglePage'teki AYNI
      // runGeneration açıklaması (save/restore, sabit `true` değil).
      final files = FreePlanRestrictionService.runGeneration(
        appState.qtCurrentIsPremium,
        buildFiles,
      );

      // 06.09.2026 eklendi (kanka isteği) — buildFiles() ÇAĞRILDIKTAN SONRA
      // gerçek sayfa (dosya) sayısı [maxTotalPages] sınırını aşıyorsa üretim
      // BURADA reddedilir — henüz consumeFormQuota/updateQtGeneratedFiles
      // ÇAĞRILMADIĞI için ne puan harcanır ne proje kaydedilir/üzerine
      // yazılır (varsa ÖNCEKİ kayıtlı hâli olduğu gibi kalır).
      if (maxTotalPages != null && files.length > maxTotalPages) {
        if (context.mounted) {
          await showPremiumLockedPopup(
            context,
            message: FreePlanPageLimitService.tooManyPagesMessage(
              isEnglish(context),
              maxTotalPages,
            ),
          );
        }
        return false;
      }
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
      // 06.09.2026 DÜZELTİLDİ — bkz. generateSinglePage'teki AYNI açıklama:
      // restore artık runGeneration içinde yapılıyor.
    }
  }
}
