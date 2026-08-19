import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/site_project.dart';
import 'worker_service.dart';
import 'ai_response_utils.dart';
import '../widgets/quota_limit_popup.dart';
import 'analytics_service.dart';

/// Biyo Link ve Dijital Kartvizit formları için ortak üretim akışı.
/// Chat ekranındaki (_sendMessage) MEVCUT kota mantığıyla BİREBİR aynı
/// kuralları kullanır — sadece kullanıcıdan chat yerine kısa bir form
/// alıp, o formdan tek bir zengin prompt üretir.
class QuickGenerationHelper {
  /// Başarılıysa true döner (çağıran taraf sonraki ekrana geçebilir).
  /// Başarısızsa (kota yetersiz / hata) kullanıcıya zaten popup/snackbar
  /// gösterilmiş olur, false döner.
  static Future<bool> generateSinglePage({
    required BuildContext context,
    required String prompt,
    required String projectNameHint,
    required ProjectKind kind,
  }) async {
    final appState = context.read<AppState>();

    if (!await appState.ensureAiQuotaFor(AppState.costSinglePage)) {
      await showQuotaLimitPopup(context);
      return false;
    }

    // Mevcut düzenleme oturumunu bozmadan yeni, ayrı bir proje başlat.
    await appState.detachSlotForNewProject();
    appState.setGenerating(true);

    try {
      final code = await WorkerService.generateSiteCode(prompt: prompt);
      appState.updateGeneratedCode(code, projectName: projectNameHint, kind: kind);
      await appState.consumeAiQuota(AppState.costSinglePage);
      unawaited(AnalyticsService.logSiteGenerated(
        source: 'quick_form',
        mode: 'single',
        kind: kind.name,
      ));
      return true;
    } on AiRejectedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } on WorkerRateLimitException catch (_) {
      if (context.mounted) {
        await showWorkerBusyPopup(context);
      }
      return false;
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
