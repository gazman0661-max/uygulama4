import 'progress_mirror.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, warn, error }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final String? stack;
  const LogEntry(this.time, this.level, this.tag, this.message, this.stack);

  static String _two(int n) => n.toString().padLeft(2, '0');

  String format() {
    final t = time;
    final ts = '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    final lv = level == LogLevel.error ? 'ERR ' : (level == LogLevel.warn ? 'WARN' : 'INFO');
    final b = StringBuffer('$ts $lv [$tag] $message');
    if (stack != null && stack!.isNotEmpty) {
      b.write('\n    ');
      b.write(stack!.replaceAll('\n', '\n    '));
    }
    return b.toString();
  }
}

/// OYUN ICI HATA GUNLUGU (kopyala-yapistir ile paylasilir).
///
///  - Her hata/uyari/bilgi bellekte (son [_max] kayit) VE diskte tutulur.
///  - Flutter hatalari, yakalanmamis async hatalar ve debugPrint otomatik yakalanir.
///  - Disk kaydi uygulama kapanip acilsa da kalir: "Onceki oturumlar" sekmesi.
///  - Ayarlar > "Hata Kayitlari" ekrani: gor, kopyala, paylas, temizle.
///  - [storageDiagnostics]: kayit (SharedPreferences) gercekten kalici mi, olcer.
class AppLog {
  AppLog._();
  static final AppLog instance = AppLog._();

  static const String build = 'v163-mod2tut';
  static const int _max = 6000;
  static const int _maxFileChars = 500000;

  final List<LogEntry> entries = <LogEntry>[];
  final ValueNotifier<int> changed = ValueNotifier<int>(0);

  /// Hata Kayitlari ekrani acikken true: o ekranin kendi yeniden cizimi yavas kare uretip
  /// log'a satir ekliyor, o da ekrani yeniden cizdiriyordu (geri besleme dongusu). Bu sirada jank yazilmaz.
  bool suppressJank = false;
  String previousSessions = '';
  int errorCount = 0;
  int warnCount = 0;
  bool _inited = false;
  bool _handlersInstalled = false;
  Timer? _beatTimer;
  File? _file;
  File? _prevFile;
  File? _countFile;
  int fileLaunchCount = 0;
  String fileStatus = 'baslamadi';

  // ---------------------------------------------------------- kisayollar

  static void i(String tag, String msg) => instance._add(LogLevel.info, tag, msg, null);
  static void w(String tag, String msg, [Object? err]) => instance._add(LogLevel.warn, tag, err == null ? msg : '$msg | $err', null);
  static void e(String tag, String msg, [Object? err, StackTrace? st]) {
    final m = err == null ? msg : '$msg | $err';
    instance._add(LogLevel.error, tag, m, st?.toString());
  }

  // ------------------------------------------------------------ baslatma

  /// main() icinde, en basta cagrilir (runApp'tan once).
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final dir = Directory('${Directory.systemTemp.path}/wm_logs');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _file = File('${dir.path}/session.log');
      _prevFile = File('${dir.path}/previous.log');
      _countFile = File('${dir.path}/launch_count.txt');

      // Onceki oturumun kaydini "onceki oturumlar" dosyasina ekle.
      var prev = '';
      if (_prevFile!.existsSync()) prev = _prevFile!.readAsStringSync();
      if (_file!.existsSync()) {
        final last = _file!.readAsStringSync();
        if (last.trim().isNotEmpty) {
          prev = '$prev\n$last';
        }
      }
      if (prev.length > _maxFileChars) prev = prev.substring(prev.length - _maxFileChars);
      _prevFile!.writeAsStringSync(prev, flush: true);
      previousSessions = prev;
      _file!.writeAsStringSync('', flush: true);

      // Dosya tabanli acilis sayaci (SharedPreferences'tan BAGIMSIZ).
      var n = 0;
      if (_countFile!.existsSync()) n = int.tryParse(_countFile!.readAsStringSync().trim()) ?? 0;
      fileLaunchCount = n + 1;
      _countFile!.writeAsStringSync('$fileLaunchCount', flush: true);
      fileStatus = 'ok (${dir.path})';
    } catch (err) {
      fileStatus = 'HATA: $err';
    }
    final mode = kReleaseMode ? 'RELEASE' : (kProfileMode ? 'PROFILE' : 'DEBUG');
    i('boot', '=== YENI OTURUM === build=$build mod=$mode dosyaAcilis=#$fileLaunchCount log=$fileStatus');
    try {
      i('boot', 'os=${Platform.operatingSystemVersion} locale=${ui.PlatformDispatcher.instance.locale} cpu=${Platform.numberOfProcessors}');
    } catch (_) {}
  }

  /// Flutter + yakalanmamis async hatalari + debugPrint'i gunluge baglar.
  void installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      e('flutter', d.exceptionAsString(), null, d.stack);
      prevFlutter?.call(d);
    };

    final prevPlatform = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (Object err, StackTrace st) {
      e('async', 'Yakalanmamis hata', err, st);
      return prevPlatform?.call(err, st) ?? false;
    };

    // JANK: 120 ms'den uzun surmus kareler (donma/takilma tespiti).
    try {
      SchedulerBinding.instance.addTimingsCallback((List<ui.FrameTiming> timings) {
        for (final t in timings) {
          final build = t.buildDuration.inMilliseconds;
          final raster = t.rasterDuration.inMilliseconds;
          final total = t.totalSpan.inMilliseconds;
          if (!suppressJank && (total >= 120 || build >= 60 || raster >= 60)) {
            _add(LogLevel.warn, 'jank', 'yavas kare: toplam=${total}ms build=${build}ms raster=${raster}ms', null);
          }
        }
      });
    } catch (_) {}

    // NABIZ: 20 sn'de bir bellek/oturum ozeti.
    _beatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      try {
        final rss = (ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(0);
        final max = (ProcessInfo.maxRss / (1024 * 1024)).toStringAsFixed(0);
        i('nabiz', 'bellek=${rss}MB (tepe ${max}MB) log=${entries.length} hata=$errorCount uyari=$warnCount');
      } catch (_) {}
    });

    final origPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) _add(LogLevel.info, 'print', message, null);
      origPrint(message, wrapWidth: wrapWidth);
    };
  }

  // ------------------------------------------------------------- yazma

  final StringBuffer _pending = StringBuffer();
  Timer? _flushTimer;
  Timer? _notifyTimer;

  void _add(LogLevel level, String tag, String msg, String? stack) {
    // Tek bir hata mesaji (ic ice Suppressed izleri) MB'larca yer kaplamasin.
    if (msg.length > 1500) msg = '${msg.substring(0, 1500)}... (${msg.length - 1500} karakter kesildi)';
    String? st = stack;
    if (st != null) {
      final lines = st.split('\n');
      if (lines.length > 12) st = '${lines.take(12).join('\n')}\n... (${lines.length - 12} satir daha)';
    }
    final entry = LogEntry(DateTime.now(), level, tag, msg, st);
    entries.add(entry);
    if (entries.length > _max) entries.removeRange(0, entries.length - _max);
    if (level == LogLevel.error) errorCount++;
    if (level == LogLevel.warn) warnCount++;
    // Cok sik log yazilinca her satirda disk yazmasi oyunu yavaslatir:
    // satirlar tamponlanir, 700 ms'de bir toplu yazilir (hata satirinda hemen).
    _pending.writeln(entry.format());
    if (level == LogLevel.error) {
      flush();
    } else {
      _flushTimer ??= Timer(const Duration(milliseconds: 700), flush);
    }
    // Log ekrani acikken saniyede en fazla ~4 yenileme.
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      changed.value++;
    });
  }

  /// Tamponu diske yazar. Arka plana alinirken/kapanirken de cagrilir.
  void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return;
    final text = _pending.toString();
    _pending.clear();
    try {
      _file?.writeAsStringSync(text, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  // ------------------------------------------------------------ cikti

  String header() {
    final mode = kReleaseMode ? 'RELEASE' : (kProfileMode ? 'PROFILE' : 'DEBUG');
    return 'Worlds Merge hata gunlugu | build=$build | mod=$mode | hata=$errorCount uyari=$warnCount | dosyaAcilis=#$fileLaunchCount';
  }

  String currentText({bool errorsOnly = false}) {
    final b = StringBuffer(header())..writeln();
    for (final en in entries) {
      if (errorsOnly && en.level == LogLevel.info) continue;
      b.writeln(en.format());
    }
    return b.toString();
  }

  String previousText() {
    if (previousSessions.trim().isEmpty) return '(onceki oturum kaydi yok)';
    return previousSessions;
  }

  Future<void> clear() async {
    _pending.clear();
    entries.clear();
    errorCount = 0;
    warnCount = 0;
    previousSessions = '';
    try {
      _prevFile?.writeAsStringSync('', flush: true);
      _file?.writeAsStringSync('', flush: true);
    } catch (_) {}
    i('log', 'Gunluk temizlendi');
  }

  // ------------------------------------------------------ depolama testi

  /// Kayit gercekten kalici mi? Her acilista cagrilir. Okunan seyler:
  ///  - SharedPreferences acilis sayaci ile DOSYA acilis sayaci karsilastirilir.
  ///    Dosya sayaci artip prefs sayaci hep 1 kaliyorsa => prefs her acilista siliniyor.
  ///  - Onay (legal_consent_version_v1) ve ilerleme (game_progress_v1) boyutu.
  Future<void> storageDiagnostics(String stage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final consent = prefs.getInt('legal_consent_version_v1');
      final gp = prefs.getString('game_progress_v1');
      final prevCanary = prefs.getString('_log_canary_v1');
      final prefLaunch = prefs.getInt('_log_launch_count_v1') ?? 0;
      var chap = '-';
      if (gp != null && gp.isNotEmpty) {
        final m = RegExp('"maxUnlockedChapter":(\\d+)').firstMatch(gp);
        if (m != null) chap = m.group(1)!;
      }
      i('storage', '[$stage] dosya: ${await ProgressMirror.diagnose()}');
      i('storage',
          '[$stage] prefsAnahtar=${keys.length} onay=$consent ilerlemeBoyut=${gp?.length ?? 0} bolum=$chap '
          'prefsAcilis=$prefLaunch dosyaAcilis=$fileLaunchCount canaryOncekindenKalmis=${prevCanary != null}');

      if (stage == 'acilis') {
        if (fileLaunchCount > 1 && prefLaunch == 0) {
          e('storage', 'KRITIK: Bu ${fileLaunchCount}. acilis ama SharedPreferences bos/sifirlanmis. Yerel kayit KALICI DEGIL.');
        } else if (fileLaunchCount > 1 && prefLaunch > 0) {
          i('storage', 'Kayit kalici gorunuyor (prefs onceki acilistan kalmis).');
        }
        final okA = await prefs.setInt('_log_launch_count_v1', prefLaunch + 1);
        final okB = await prefs.setString('_log_canary_v1', DateTime.now().toIso8601String());
        final back = prefs.getString('_log_canary_v1');
        if (!okA || !okB || back == null) {
          e('storage', 'Yazma testi BASARISIZ: setInt=$okA setString=$okB geriOkunan=$back');
        } else {
          i('storage', 'Yazma testi tamam (setInt=$okA setString=$okB).');
        }
      }
    } catch (err, st) {
      e('storage', '[$stage] SharedPreferences ERISILEMEDI', err, st);
    }
  }
}
