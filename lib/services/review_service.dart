import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crash_service.dart';

class ReviewService {
  ReviewService._();

  static final InAppReview _inAppReview = InAppReview.instance;

  static const _requestCountPrefsKey = 'review_request_count';
  static const _lastRequestAtPrefsKey = 'review_last_requested_at_ms';

  static const int _maxLifetimeRequests = 3;

  static const Duration _minGapBetweenRequests = Duration(days: 30);

  static Future<void> maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_requestCountPrefsKey) ?? 0;
      if (count >= _maxLifetimeRequests) return;

      final lastMs = prefs.getInt(_lastRequestAtPrefsKey);
      if (lastMs != null) {
        final elapsed = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastMs),
        );
        if (elapsed < _minGapBetweenRequests) return;
      }

      final available = await _inAppReview.isAvailable();
      if (!available) return;

      await prefs.setInt(_requestCountPrefsKey, count + 1);
      await prefs.setInt(
        _lastRequestAtPrefsKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      await _inAppReview.requestReview();
    } catch (e, st) {
      CrashService.record(e, st, context: 'ReviewService.maybeRequestReview');
    }
  }
}
