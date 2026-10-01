import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crash_service.dart';

class AnalyticsService {
  AnalyticsService._();

  static bool isAvailable = false;

  static FirebaseAnalytics get _instance => FirebaseAnalytics.instance;

  static Future<void> _safeLog(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!isAvailable) return;
    try {
      await _instance.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.$name');
    }
  }

  static Future<void> logSiteGenerated({
    required String source,
    required String mode,
    String? kind,
  }) {
    return _safeLog('site_generated', parameters: {
      'source': source,
      'mode': mode,
      if (kind != null) 'kind': kind,
    });
  }

  static Future<void> logSitePublished({
    required String subdomain,
    bool isFirstPublish = false,
  }) {
    return _safeLog('site_published', parameters: {
      'subdomain': subdomain,
      'is_first_publish': isFirstPublish ? 1 : 0,
    });
  }

  static Future<void> logPurchase({
    required String productId,
    double? value,
    String? currency,
  }) async {
    if (!isAvailable) return;
    try {
      await _instance.logPurchase(
        currency: currency,
        value: value,
        items: [AnalyticsEventItem(itemId: productId, itemName: productId)],
      );
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.logPurchase');
    }
  }

  static Future<void> logLogin({String method = 'password'}) async {
    if (!isAvailable) return;
    try {
      await _instance.logLogin(loginMethod: method);
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.logLogin');
    }
  }

  static Future<void> logPublishTapped() => _safeLog('publish_tapped');

  static Future<void> logLoginGateShown({required String feature}) {
    return _safeLog('login_gate_shown', parameters: {'feature': feature});
  }

  static Future<void> logSignUpCompleted() => _safeLog('signup_completed');

  static void logPublishFailed({required String reason}) {
    unawaited(_safeLog('publish_failed', parameters: {'reason': reason}));
  }

  static void logPaywallShown({required String trigger}) {
    unawaited(_safeLog('paywall_shown', parameters: {'trigger': trigger}));
  }

  static void logPurchaseStarted({required String productId}) {
    unawaited(_safeLog('purchase_started', parameters: {'product_id': productId}));
  }

  static void logPurchaseCancelled({required String productId}) {
    unawaited(_safeLog('purchase_cancelled', parameters: {'product_id': productId}));
  }

  static void logPurchaseFailed({required String productId, required String reason}) {
    unawaited(_safeLog('purchase_failed', parameters: {
      'product_id': productId,
      'reason': reason,
    }));
  }

  static const String _notifPermPrefsKey = 'analytics_notif_permission_v1';

  static Future<void> logNotificationPermission(String status) async {
    if (!isAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_notifPermPrefsKey) == status) return;
      await prefs.setString(_notifPermPrefsKey, status);
      await _instance.logEvent(
        name: 'notification_permission',
        parameters: {'status': status},
      );
      await _instance.setUserProperty(name: 'notif_permission', value: status);
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.logNotificationPermission');
    }
  }

  static void logPushOpened({required String type, bool coldStart = false}) {
    unawaited(_safeLog('push_opened', parameters: {
      'type': type,
      'cold_start': coldStart ? 1 : 0,
    }));
  }

  static void logLeadInboxOpened({required bool locked}) {
    unawaited(_safeLog('lead_inbox_opened', parameters: {'locked': locked ? 1 : 0}));
  }

  static void logSiteUnpublished({required String reason}) {
    unawaited(_safeLog('site_unpublished', parameters: {'reason': reason}));
  }

  static void logSiteDeleted({required bool wasPublished}) {
    unawaited(_safeLog('site_deleted', parameters: {'was_published': wasPublished ? 1 : 0}));
  }

  static String? _lastPublishedBucket;
  static String? _lastCreatedBucket;
  static String? _lastPlan;

  static String _bucket(int n) {
    if (n <= 0) return '0';
    if (n == 1) return '1';
    if (n <= 4) return '2_4';
    return '5_plus';
  }

  static Future<void> syncUserProperties({
    required int publishedSites,
    required int createdSites,
    required String plan,
  }) async {
    if (!isAvailable) return;
    try {
      final pub = _bucket(publishedSites);
      final cre = _bucket(createdSites);
      if (pub != _lastPublishedBucket) {
        await _instance.setUserProperty(name: 'published_sites', value: pub);
        _lastPublishedBucket = pub;
      }
      if (cre != _lastCreatedBucket) {
        await _instance.setUserProperty(name: 'created_sites', value: cre);
        _lastCreatedBucket = cre;
      }
      if (plan != _lastPlan) {
        await _instance.setUserProperty(name: 'sub_plan', value: plan);
        _lastPlan = plan;
      }
    } catch (e, st) {
      CrashService.record(e, st, context: 'AnalyticsService.syncUserProperties');
    }
  }
}
