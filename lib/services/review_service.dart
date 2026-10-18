import 'dart:async';

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'remote_tuning.dart';

/// Google Play uygulama ici puanlama penceresi (oyundan cikmadan yildiz verdirir).
/// Sadece iyi bir anda istenir: 3 yildizla biten bolum, yeterince ilerlemis oyuncu,
/// en fazla 3 kez ve en az 90 gun arayla. (Google ayrica kendi kotasini uygular.)
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const String _kLast = 'review_last_ms_v1';
  static const String _kCount = 'review_count_v1';
  static const int _maxAsks = 3;
  static const int _minGapDays = 90;

  bool _busy = false;

  /// Bolum bitis ekranindan haritaya donerken cagrilir. Hicbir hata oyunu etkilemez.
  Future<void> maybeAsk({required int stars, required int chapter}) async {
    if (_busy || stars < 3 || chapter < RemoteTuning.i('review_min_chapter', 8)) return;
    _busy = true;
    try {
      final p = await SharedPreferences.getInstance();
      final count = p.getInt(_kCount) ?? 0;
      if (count >= _maxAsks) return;
      final last = p.getInt(_kLast) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (last > 0 && now - last < _minGapDays * 86400000) return;
      final r = InAppReview.instance;
      if (!await r.isAvailable()) return;
      await p.setInt(_kLast, now);
      await p.setInt(_kCount, count + 1);
      AnalyticsService.instance.log('review_requested', {'chapter': chapter, 'n': count + 1});
      await Future<void>.delayed(const Duration(milliseconds: 1500)); // harita acilsin
      await r.requestReview();
    } catch (_) {
    } finally {
      _busy = false;
    }
  }
}
