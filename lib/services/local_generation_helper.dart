import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import 'free_plan_restriction_service.dart';
import 'free_plan_page_limit_service.dart';
import '../widgets/premium_locked_popup.dart';
import '../localization/app_strings.dart';
import 'analytics_service.dart';
import '../widgets/app_popup.dart';
import '../templates/html/shared_html_blocks.dart' show isPremiumTheme, isPremiumLayoutStyle, isPremiumFontPackage;
import '../templates/html/text_styling.dart';

class LocalGenerationHelper {
  static bool _isPremiumChoiceLocked({
    required bool isPremiumAccount,
    String? selectedThemeId,
    String? selectedLayoutStyle,
    String? selectedFontPackageId,
  }) {
    if (isPremiumAccount) return false;
    return isPremiumTheme(selectedThemeId) ||
        isPremiumLayoutStyle(selectedLayoutStyle) ||
        isPremiumFontPackage(selectedFontPackageId);
  }

  static Future<bool> _showPremiumChoiceLockedPopup(BuildContext context) {
    return showPremiumLockedPopup(
      context,
      message: isEnglish(context)
          ? 'This theme/layout/font is part of the Premium collection. Pick a free option to continue — or unlock Premium after creating your site.'
          : 'Bu tema/düzen/font Premium koleksiyonuna ait. Devam etmek için ücretsiz bir seçenek seç — istersen siteni oluşturduktan sonra Premium\'a geçip bunu kullanabilirsin.',
    ).then((_) => false);
  }

  static bool _textStylingLocked({
    required bool isPremiumAccount,
    required String Function() buildHtml,
    Map<String, String> Function()? buildFiles,
    Map<String, dynamic>? textStyling,
  }) {
    if (isPremiumAccount) return false;
    if (buildFiles != null) {
      final files = FreePlanRestrictionService.runGeneration(false, buildFiles);
      return TextStyling.filesNeedPremium(files, textStyling);
    }
    final html = FreePlanRestrictionService.runGeneration(false, buildHtml);
    final composed = TextStyling.compose(html, textStyling, isPremium: true);
    return TextStyling.needsPremium(composed, textStyling);
  }

  static Future<bool> _showTextStylingLockedPopup(BuildContext context) {
    return showPremiumLockedPopup(
      context,
      message: isEnglish(context)
          ? 'Per-word color, size and highlight, custom colors and more than 2 custom sections are Premium. Remove those styles to continue — or unlock Premium after creating your site.'
          : 'Kelime bazlı renk/boyut/vurgu, serbest renk ve 2\'den fazla özel bölüm Premium\'a ait. Devam etmek için bu stilleri kaldır — istersen siteni oluşturduktan sonra Premium\'a geçip kullanabilirsin.',
    ).then((_) => false);
  }

  static Map<String, dynamic> _withTextStyling(
    Map<String, dynamic>? formData,
    Map<String, dynamic>? textStyling,
  ) {
    final out = <String, dynamic>{...?formData};
    if (textStyling != null && !TextStyling.isEmptyData(textStyling)) {
      out['textStyling'] = textStyling;
    } else {
      out.remove('textStyling');
    }
    return out;
  }

  static Future<bool> generateSinglePage({
    required BuildContext context,
    required String projectNameHint,
    required ProjectKind kind,
    required String Function() buildHtml,
    bool isEditing = false,
    Map<String, dynamic>? formData,
    String? selectedThemeId,
    String? selectedLayoutStyle,
    String? selectedFontPackageId,
    Map<String, dynamic>? textStyling,
  }) async {
    final appState = context.read<AppState>();

    appState.setGenerating(true);
    try {
      if (_isPremiumChoiceLocked(
        isPremiumAccount: appState.qtCurrentIsPremium,
        selectedThemeId: selectedThemeId,
        selectedLayoutStyle: selectedLayoutStyle,
        selectedFontPackageId: selectedFontPackageId,
      )) {
        if (context.mounted) await _showPremiumChoiceLockedPopup(context);
        return false;
      }
      if (_textStylingLocked(
        isPremiumAccount: appState.qtCurrentIsPremium,
        buildHtml: buildHtml,
        textStyling: textStyling,
      )) {
        if (context.mounted) await _showTextStylingLockedPopup(context);
        return false;
      }

      if (!isEditing) {
        await appState.detachQtSlotForNewProject();
      }
      final rawHtml = FreePlanRestrictionService.runGeneration(
        appState.qtCurrentIsPremium,
        buildHtml,
      );
      final html = TextStyling.apply(
        rawHtml,
        textStyling,
        isPremium: appState.qtCurrentIsPremium,
      );
      appState.updateQtGeneratedCode(html, projectName: projectNameHint, kind: kind);
      appState.setQtFormData(_withTextStyling(formData, textStyling), kind: kind);
      unawaited(AnalyticsService.logSiteGenerated(
        source: 'form',
        mode: 'single',
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
    }
  }

  static Future<bool> generateMultiPage({
    required BuildContext context,
    required String projectNameHint,
    required ProjectKind kind,
    required Map<String, String> Function() buildFiles,
    String? activeFileName,
    bool isEditing = false,
    Map<String, dynamic>? formData,
    String? selectedThemeId,
    String? selectedLayoutStyle,
    String? selectedFontPackageId,
    Map<String, dynamic>? textStyling,
    bool alwaysMultiPage = false,
  }) async {
    final appState = context.read<AppState>();

    appState.setGenerating(true);
    try {
      if (_isPremiumChoiceLocked(
        isPremiumAccount: appState.qtCurrentIsPremium,
        selectedThemeId: selectedThemeId,
        selectedLayoutStyle: selectedLayoutStyle,
        selectedFontPackageId: selectedFontPackageId,
      )) {
        if (context.mounted) await _showPremiumChoiceLockedPopup(context);
        return false;
      }
      if (_textStylingLocked(
        isPremiumAccount: appState.qtCurrentIsPremium,
        buildHtml: () => '',
        buildFiles: buildFiles,
        textStyling: textStyling,
      )) {
        if (context.mounted) await _showTextStylingLockedPopup(context);
        return false;
      }

      final gateProject = isEditing ? appState.qtCurrentProject : null;
      final subTier = appState.activeSubscriptionTier;
      final hasSubscriptionSlot =
          subTier != null && appState.subscriptionQuotaUsed < subTier.siteQuota;
      if (!FreePlanPageLimitService.canUseMultiPage(
        gateProject,
        alwaysMultiPage: alwaysMultiPage,
        accountTier: subTier,
        hasSubscriptionSlot: hasSubscriptionSlot,
      )) {
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
        accountTier: subTier,
        hasSubscriptionSlot: hasSubscriptionSlot,
      );

      if (!isEditing) {
        await appState.detachQtSlotForNewProject();
      }
      final rawFiles = FreePlanRestrictionService.runGeneration(
        appState.qtCurrentIsPremium,
        buildFiles,
      );
      final files = TextStyling.applyToFiles(
        rawFiles,
        textStyling,
        isPremium: appState.qtCurrentIsPremium,
      );

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
      appState.setQtFormData(_withTextStyling(formData, textStyling), kind: kind);
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
    }
  }
}
