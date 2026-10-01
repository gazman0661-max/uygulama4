import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ServerTimeService {
  ServerTimeService._();

  static const _prefsKey = 'server_time_skew_ms';

  static Duration _skew = Duration.zero;
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefsKey);
      if (ms != null) _skew = Duration(milliseconds: ms);
    } catch (_) {
    }
  }

  static void updateFromResponse(http.Response response) {
    final dateHeader = response.headers['date'];
    if (dateHeader == null) return;
    try {
      final serverTime = HttpDate.parse(dateHeader);
      final deviceTime = DateTime.now();
      final newSkew = serverTime.difference(deviceTime);
      if (newSkew.abs() > const Duration(days: 366)) return;
      _skew = newSkew;
      unawaited(_persist());
    } catch (_) {
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, _skew.inMilliseconds);
    } catch (_) {
    }
  }

  static DateTime now() => DateTime.now().add(_skew);
}
