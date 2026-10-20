import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'log_service.dart';
/// Hafif olay sayaci + "huni" olcumu.
///
/// Projede analitik SDK yok. Bu servis iki is yapar:
///  1) Her olayi cihazda SAYAR (`analytics_funnel_v1` anahtari, JSON). Ogretici
///     hunisini (hangi adimda kac kisi cikiyor) Ayarlar > "Nasil oynanir?"
///     dugmesine UZUN BASARAK gorebilirsin ([summary]).
///  2) [sink] verilirse her olayi oraya da iletir. PushService.init(), Firebase
///     hazir olunca sink'i Firebase Analytics'e baglar. Firebase hazir olana
///     kadar gelen olaylar (en cok [_maxPending]) tamponlanir ve sink baglaninca
///     sirayla iletilir; Firebase hic yapilandirilmadiysa yalnizca cihazda sayilir.
///
/// Olay adlari (huni sirasi):
///   tut_start, tut_step1_throw, tut_step2_merge, tut_step3_deliver,
///   tut_ch1_complete, tut_ch1_quit, tut_danger_hint, tut_combo_hint,
///   tut_first_full_card, tut_feat_shown_<ozellik>, tut_feat_tapped_<ozellik>,
///   tut_replay_start, tut_replay_done
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const String _prefsKey = 'analytics_funnel_v1';

  static const int _maxPending = 100;
  void Function(String name, Map<String, Object> params)? _sink;
  final List<MapEntry<String, Map<String, Object>>> _pending = [];

  /// Firebase vb. icin dis baglanti (opsiyonel). Ataninca tamponlanan olaylar iletilir.
  void Function(String name, Map<String, Object> params)? get sink => _sink;
  set sink(void Function(String name, Map<String, Object> params)? v) {
    _sink = v;
    if (v == null) return;
    final queued = List<MapEntry<String, Map<String, Object>>>.of(_pending);
    _pending.clear();
    for (final e in queued) {
      try {
        v(e.key, e.value);
      } catch (err) { AppLog.w('analytics_service.sink', 'yutulan hata', err); }
    }
  }

  final Map<String, int> _counts = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw);
      if (m is Map) {
        m.forEach((k, v) {
          if (v is num) _counts['$k'] = v.toInt();
        });
      }
    } catch (err) { AppLog.w('analytics_service.load', 'yutulan hata', err); }
  }

  /// Bir olay kaydeder. Asla hata firlatmaz, oyunu yavaslatmaz.
  void log(String name, [Map<String, Object> params = const {}]) {
    _counts[name] = (_counts[name] ?? 0) + 1;
    // Yer bazli kirilim (rewarded reklam vb.): 'ad_rew_completed@continue' gibi ek sayac.
    final pl = params['placement'];
    if (pl is String && pl.isNotEmpty && name.startsWith('ad_')) {
      final k = '$name@$pl';
      _counts[k] = (_counts[k] ?? 0) + 1;
    }
    if (kDebugMode) debugPrint('[analytics] $name $params');
    final s = _sink;
    if (s != null) {
      try {
        s(name, params);
      } catch (err) { AppLog.w('analytics_service.log', 'yutulan hata', err); }
    } else if (_pending.length < _maxPending) {
      _pending.add(MapEntry(name, params));
    }
    _scheduleSave();
  }

  bool _savePending = false;
  void _scheduleSave() {
    if (_savePending) return;
    _savePending = true;
    Future<void>.delayed(const Duration(seconds: 2), () async {
      _savePending = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(_counts));
      } catch (err) { AppLog.w('analytics_service._scheduleSave', 'yutulan hata', err); }
    });
  }

  int count(String name) => _counts[name] ?? 0;

  /// Huni ozeti (sadece gelistirici icin): her adimin sayisi ve bir onceki adima gore yuzdesi.
  String summary() {
    const order = [
      'tut_start',
      'tut_step1_throw',
      'tut_step2_merge',
      'tut_step3_deliver',
      'tut_ch1_complete',
    ];
    final b = StringBuffer();
    int? prev;
    for (final k in order) {
      final c = count(k);
      final pct = (prev == null || prev == 0) ? '' : '  (%${(c * 100 / prev).round()})';
      b.writeln('$k: $c$pct');
      prev = c;
    }
    b.writeln('');
    for (final k in const [
      'tut_ch1_quit',
      'tut_danger_hint',
      'tut_combo_hint',
      'tut_first_full_card',
      'tut_replay_start',
      'tut_replay_done',
    ]) {
      b.writeln('$k: ${count(k)}');
    }
    b.writeln('');
    b.writeln('--- BOLUM ---');
    for (final k in const ['chapter_start', 'chapter_complete', 'chapter_fail', 'continue_used', 'order_expired']) {
      b.writeln('$k: ${count(k)}');
    }
    b.writeln('');
    b.writeln('--- REKLAM ---');
    for (final k in const [
      'ad_prompt_shown',
      'ad_prompt_accepted',
      'ad_prompt_declined',
      'ad_rew_impression',
      'ad_rew_completed',
      'ad_rew_skipped',
      'ad_rew_nofill',
      'ad_rew_no_internet',
      'ad_inter_impression',
      'ad_inter_nofill',
      'ad_inter_show_failed',
    ]) {
      b.writeln('$k: ${count(k)}');
    }
    final byPl = _counts.keys.where((k) => k.startsWith('ad_rew_completed@')).toList()..sort();
    for (final k in byPl) {
      b.writeln('  ${k.substring('ad_rew_completed@'.length)}: ${_counts[k]}');
    }
    b.writeln('');
    b.writeln('--- PARA ---');
    for (final k in const ['iap_start', 'iap_purchase', 'iap_canceled', 'iap_error', 'gems_spent']) {
      b.writeln('$k: ${count(k)}');
    }
    final feats = _counts.keys.where((k) => k.startsWith('tut_feat_')).toList()..sort();
    if (feats.isNotEmpty) b.writeln('');
    for (final k in feats) {
      b.writeln('$k: ${_counts[k]}');
    }
    return b.toString().trimRight();
  }
}
