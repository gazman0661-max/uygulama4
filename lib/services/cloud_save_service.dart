import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/services.dart' show PlatformException;
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/engage.dart';
import '../models/game_progress.dart';
import '../models/mb_missions.dart';
import '../models/planet_event.dart';
import '../models/piggy.dart';
import '../models/live_events.dart';
import '../models/team_race.dart';
import '../models/season.dart';
import '../models/weekly_event.dart';
import 'inbox_service.dart';
import 'merge_board_service.dart';
import 'save_merge.dart';

import 'log_service.dart';
/// Google Play Games girisi + OTOMATIK bulut kaydi (Kayitli Oyunlar).
///
/// IKI CIHAZ NASIL STABIL CALISIR?
///  Eski surum her seferinde TEK PARCA kaydi ustune yaziyordu ve acilistan
///  sonra bulutu bir daha okumuyordu. Yeni surum:
///   1) Her esitleme "oku -> birlestir -> yaz -> dogrula"dir (blind-write yok).
///   2) Birlestirme 3'lu (base/local/cloud): mucevher/coin harcama-kazanma
///      DELTA olarak eklenir, satin alinanlar/seviyeler asla geri gitmez
///      (bkz. save_merge.dart).
///   3) Arka plandan donuste ve on planda 60 sn'de bir bulut okunur; diger
///      cihazdaki degisiklik kisa surede bu cihaza gelir.
///   4) Yazdiktan sonra geri okuyup kendi yazimimizin kalip kalmadigina
///      bakilir; iki cihaz ayni anda yazdiysa kaybeden taraf tekrar birlestirir.
///   5) Cihaz kimligi + revizyon ("seen") ile ayni degisiklik iki kez
///      sayilmaz (uygulama yazma sirasinda kapansa bile).
///
/// SINIR: Play Games Kayitli Oyunlar sunucu tarafi islem (transaction)
/// sunmaz. Cok nadir bir yaris (iki cihaz ayni saniyede yazarsa) dogrulama +
/// yeniden birlestirme ile cozulur ama %100 atomik degildir. Gercek "sunucu
/// otoriteli" sistem icin bkz. oyun backend'i (Cloudflare Worker + D1).
class CloudSaveService {
  CloudSaveService._();
  static final CloudSaveService instance = CloudSaveService._();

  /// Play Games ACIK (uygulama kimligi games_ids.xml'de, manifest'te APP_ID var).
  static const bool enabled = true;

  static const String _slot = 'progress';
  static const String _backupKey = 'cloud_pre_restore_backup_v1';
  static const String _kDevice = 'cloud_device_id_v1';
  static const String _kBase = 'cloud_base_v1';
  static const String _kPending = 'cloud_pending_v1';
  // v235: bu yerel kaydin ait oldugu Play Games oyuncu kimligi (hesap degisimi korumasi).
  static const String _kPlayer = 'cloud_player_id_v1';
  // v235: hesap degisince eski hesabin yerel kaydinin yedegi ({player, at, stores}).
  static const String _kSwitchBackup = 'cloud_pre_switch_backup_v1';
  // v235: bulut kaydi okunamiyorsa: ilk gorulme zamani (ms) ve ham icerik yedegi.
  static const String _kCorruptSince = 'cloud_corrupt_since_v1';
  static const String _kCorruptRaw = 'cloud_corrupt_raw_v1';

  /// Bulut kaydi bu sure boyunca SUREKLI okunamazsa (ve yerelde gercek ilerleme varsa)
  /// bozuk kayit yedeklenip yerel kayit bulutun ustune yazilir. Kisa sureli/gecici
  /// okuma sorunlarinda bulut ASLA ezilmez.
  static const Duration corruptGrace = Duration(days: 3);

  bool signedIn = false;
  bool busy = false;
  String? lastError;

  bool _syncing = false;
  bool _again = false;
  bool _foreground = true;
  Timer? _uploadTimer;
  Timer? _pollTimer;

  final List<void Function()> _listeners = [];
  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  // ---------------------------------------------------------------- oturum

  /// Uygulama acilisinda cagrilir; BEKLENMEZ, hata firlatmaz.
  Future<void> init() async {
    if (!enabled) return;
    try {
      signedIn = await GamesServices.isSignedIn;
      AppLog.i('cloud', 'init: isSignedIn=$signedIn');
    } catch (e) {
      AppLog.e('cloud_save_service.init', 'hata', e);
      lastError = '$e';
    }
    _startPolling();
    await syncNow();
    _notify();
  }

  static const String _kAutoTries = 'cloud_autosignin_tries_v1';

  /// Acilista kac kez otomatik giris penceresi acilir (oyuncu reddederse
  /// her acilista rahatsiz etmemek icin). Sonrasi: Ayarlar'daki dugme.
  static const int maxAutoSignInTries = 3;

  /// Acilista Play Games'e baglan (v128). Zaten bagliysa sayaci sifirlar;
  /// degilse en fazla [maxAutoSignInTries] acilista giris penceresini acar.
  /// Sartlar/izin onayindan SONRA cagrilir (LegalConsentService); BEKLENMEZ, hata firlatmaz.
  Future<void> autoSignIn() async {
    if (!enabled) return;
    try {
      signedIn = await GamesServices.isSignedIn;
      AppLog.i('cloud', 'autoSignIn: isSignedIn=$signedIn');
    } catch (e) {
      AppLog.e('cloud_save_service.autoSignIn', 'hata', e);
      lastError = '$e';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (signedIn) {
        await prefs.remove(_kAutoTries);
        return;
      }
      final tries = prefs.getInt(_kAutoTries) ?? 0;
      if (tries >= maxAutoSignInTries || busy) {
        AppLog.w('cloud', 'autoSignIn: atlandi tries=$tries/$maxAutoSignInTries busy=$busy');
        return;
      }
      await prefs.setInt(_kAutoTries, tries + 1);
    } catch (err) {
      AppLog.w('cloud_save_service.autoSignIn', 'yutulan hata', err);
      return;
    }
    await signIn(); // basarida syncNow() ile buluttan birlestirir (yeni cihazda geri yukleme)
  }

  /// Otomatik giris olmadiysa ayarlardaki tek dugmeyle elle giris.
  Future<bool> signIn() async {
    if (!enabled) return false;
    busy = true;
    lastError = null;
    _notify();
    try {
      AppLog.i('cloud', 'signIn: Play Games giris penceresi aciliyor');
      await GamesServices.signIn();
      signedIn = await GamesServices.isSignedIn;
      AppLog.i('cloud', 'signIn: sonuc isSignedIn=$signedIn');
    } catch (e) {
      AppLog.e('cloud_save_service.signIn', 'hata', e);
      lastError = '$e';
      signedIn = false;
    }
    await syncNow();
    busy = false;
    _notify();
    return signedIn;
  }

  // ------------------------------------------------------ yasam dongusu

  void onResumed() {
    if (!enabled) return;
    _foreground = true;
    _startPolling();
    syncNow();
  }

  /// Uygulama arka plana alinirken: bekleyen her seyi hemen esitle.
  Future<void> flushUpload() async {
    if (!enabled) return;
    _foreground = false;
    _uploadTimer?.cancel();
    _pollTimer?.cancel();
    _pollTimer = null;
    await syncNow(); // calisan esitleme varsa onu bekler; bitince son degisiklikler icin bir tur daha doner
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_foreground) syncNow();
    });
  }

  /// Eski API: acilista/geri donuste esitleme.
  Future<void> syncIfNeeded() => syncNow();

  /// Yerel kayit her yazildiginda cagrilir; 45 sn'de bir tek esitleme yapar.
  void scheduleUpload() {
    if (!enabled) return;
    if (!signedIn) return;
    if (_uploadTimer?.isActive ?? false) return;
    _uploadTimer = Timer(const Duration(seconds: 45), () {
      syncNow();
    });
  }

  /// Satin alma sonrasi vb. hemen esitle (oku-birlestir-yaz).
  Future<bool> uploadNow() => syncNow();

  // ----------------------------------------------------------- esitleme

  bool _loggedNoSignIn = false;

  Future<bool>? _running;

  /// Calisan esitleme varsa ona KATILIR (ayni Future doner; bitince bir tur daha doner).
  /// Boylece flushUpload/uploadNow cagiranlar gercek sonucu bekleyebilir.
  Future<bool> syncNow() {
    if (!enabled) return Future<bool>.value(false);
    final r = _running;
    if (r != null) {
      _again = true;
      return r;
    }
    final f = _syncNowImpl().whenComplete(() => _running = null);
    _running = f;
    return f;
  }

  Future<bool> _syncNowImpl() async {
    // Oturum her turda yeniden kontrol edilir: oyuncu Play Games'ten disaridan cikis
    // yaptiysa bayrak bayat kalip bos yere hata uretmesin.
    final was = signedIn;
    try {
      signedIn = await GamesServices.isSignedIn;
    } catch (err) { AppLog.w('cloud_save_service.syncNow', 'yutulan hata', err); }
    if (was != signedIn) {
      AppLog.i('cloud', 'syncNow: oturum durumu degisti $was -> $signedIn');
      _notify();
    }
    if (!signedIn) {
      if (!_loggedNoSignIn) {
        _loggedNoSignIn = true;
        AppLog.w('cloud', 'syncNow: atlandi, Play Games girisi YOK (bulut kaydi calismaz)');
      }
      return false;
    }
    _loggedNoSignIn = false;
    _syncing = true;
    var ok = false;
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        _again = false;
        final r = await _syncOnce();
        ok = r;
        if (r && !_again) break;
        if (!r) await Future<void>.delayed(const Duration(milliseconds: 700)); // yaris: tekrar dene
      }
      if (ok) {
        lastError = null;
      } else {
        AppLog.w('cloud', 'syncNow: 4 deneme sonunda BASARISIZ (yaris/dogrulama)');
      }
    } on CloudUnreadableException catch (e) {
      lastError = 'Bulut kaydi okunamadi: ${e.reason}'; // _noteUnreadable zaten logladi; 60 sn'de bir log sismesin
      ok = false;
    } catch (e) {
      AppLog.e('cloud_save_service.syncNow', 'hata', e);
      lastError = '$e'; // internet yok vb.: sonra tekrar denenir
      ok = false;
    }
    _syncing = false;
    _notify();
    return ok;
  }

  Future<String> _deviceId(SharedPreferences prefs) async {
    var id = prefs.getString(_kDevice);
    if (id == null || id.isEmpty) {
      id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 30).toRadixString(36)}';
      await prefs.setString(_kDevice, id);
    }
    return id;
  }

  /// Bulut kaydini okur.
  ///  - null                      : bulutta GERCEKTEN kayit yok (ilk kayit yerelden olusabilir)
  ///  - [CloudUnreadableException]: kayit VAR ama cozumlenemedi -> hicbir sey yazilmaz
  ///  - diger istisna             : ag/Play Games hatasi -> hicbir sey yazilmaz
  Future<_Cloud?> _fetchCloud() async {
    String? raw;
    try {
      raw = await GamesServices.loadGame(name: _slot);
    } on PlatformException catch (e) {
      final m = '${e.code} ${e.message}';
      if (m.contains('SNAPSHOT_NOT_FOUND') || m.contains('26570')) {
        return null; // bulutta kayit yok = yerel ilk kayit olacak
      }
      rethrow;
    }
    if (raw == null || raw.isEmpty) return null;

    dynamic j;
    try {
      j = jsonDecode(raw);
    } catch (e) {
      throw CloudUnreadableException('JSON cozumlenemedi: $e', raw);
    }
    if (j is! Map) throw CloudUnreadableException('kayit Map degil (${j.runtimeType})', raw);

    // Eski/bilinmeyen bicim: 'data' yoksa eski tek parca kayit olabilir.
    var dataRaw = j['data'];
    var legacy = false;
    if (dataRaw is! Map) {
      final found = <String, dynamic>{};
      for (final k in SaveMerge.keys) {
        if (j[k] is Map || j[k] is String) found[k] = j[k];
      }
      if (found.isEmpty && (j['maxUnlockedChapter'] != null || j['coins'] != null)) {
        found[SaveMerge.kProgress] = Map<String, dynamic>.from(j); // dogrudan ilerleme JSON'u
      }
      if (found.isEmpty && j['progress'] is Map) {
        found[SaveMerge.kProgress] = j['progress'];
      }
      if (found.isEmpty) {
        throw CloudUnreadableException("'data' yok ve eski bicim taninmadi (anahtarlar: ${j.keys.take(8).join(",")})", raw);
      }
      dataRaw = found;
      legacy = true;
    }

    final data = <String, Map<String, dynamic>>{};
    final broken = <String>[];
    (dataRaw as Map).forEach((k, v) {
      try {
        final d = v is String ? jsonDecode(v) : v;
        if (d is Map) {
          data['$k'] = Map<String, dynamic>.from(d);
        } else {
          broken.add('$k');
        }
      } catch (err) {
        broken.add('$k');
        AppLog.w('cloud_save_service._fetchCloud', 'anahtar cozumlenemedi: $k', err);
      }
    });
    // Ilerleme (asil kayit) cozumlenemediyse bulut "bos" sayilamaz.
    if (dataRaw.containsKey(SaveMerge.kProgress) && !data.containsKey(SaveMerge.kProgress)) {
      throw CloudUnreadableException('ilerleme (${SaveMerge.kProgress}) cozumlenemedi', raw);
    }
    if (data.isEmpty && dataRaw.isNotEmpty) {
      throw CloudUnreadableException('hicbir depo cozumlenemedi (bozuk: ${broken.join(",")})', raw);
    }
    if (broken.isNotEmpty) {
      AppLog.w('cloud', '_fetchCloud: bazi depolar okunamadi (${broken.join(", ")}); bunlar icin yerel hal korunur');
    }
    if (legacy) AppLog.w('cloud', '_fetchCloud: ESKI BICIMLI bulut kaydi okundu (anahtar=${data.keys.join(",")})');

    final seen = <String, int>{};
    final sn = j['seen'];
    if (sn is Map) {
      sn.forEach((k, v) {
        if (v is num) seen['$k'] = v.toInt();
      });
    }
    return _Cloud((j['rev'] as num?)?.toInt() ?? 0, seen, data);
  }

  /// Bulut kaydi okunamadi. true = artik yerel kayit bulutun ustune yazilabilir
  /// (okunamama [corruptGrace] suresinden uzun suruyor VE yerelde gercek ilerleme var).
  /// Her durumda ham icerik bir kez yedeklenir.
  Future<bool> _noteUnreadable(SharedPreferences prefs, CloudUnreadableException e, bool localFresh) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var since = prefs.getInt(_kCorruptSince);
    if (since == null) {
      since = now;
      await prefs.setInt(_kCorruptSince, now);
      if (e.raw.length < 400000) await prefs.setString(_kCorruptRaw, e.raw);
      AppLog.e('cloud', 'BULUT KAYDI OKUNAMADI: ${e.reason} (ham kayit yedeklendi; yazma YAPILMADI)');
    }
    final waited = Duration(milliseconds: now - since);
    if (localFresh) return false; // yerel bos: buluta dokunma
    if (waited < corruptGrace) {
      AppLog.w('cloud', 'bulut kaydi hala okunamiyor (${waited.inHours} sa); ${corruptGrace.inHours} sa dolmadan ustune yazilmaz');
      return false;
    }
    AppLog.w('cloud', 'bulut kaydi ${waited.inDays} gundur okunamiyor: yerel kayit bulutun ustune yazilacak (ham kayit yerelde yedekte)');
    return true;
  }

  /// Yerel hal. Ilerleme bellekten (senkron) okunur; digerleri diske yazilip okunur.
  Future<Map<String, Map<String, dynamic>>> _snapshotLocal() async {
    final out = <String, Map<String, dynamic>>{};
    out[SaveMerge.kProgress] = _roundTrip(GameProgress.instance.toJson())..remove('wheelPending'); // yarim cark buluta gitmez
    await Future.wait([
      SeasonService.instance.save(),
      PiggyService.instance.save(),
      WeeklyEvent.instance.save(),
      EngageService.instance.save(),
      InboxService.instance.save(),
      MergeBoardService.instance.flush(),
      MbMissions.instance.flush(),
      PlanetEvent.instance.save(),
      LiveEvents.instance.save(),
      TeamRace.instance.save(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    for (final k in SaveMerge.otherKeys) {
      final raw = prefs.getString(k);
      if (raw == null || raw.isEmpty) continue;
      try {
        final d = jsonDecode(raw);
        if (d is Map) out[k] = Map<String, dynamic>.from(d);
      } catch (err) { AppLog.w('cloud_save_service._Cloud', 'yutulan hata', err); }
    }
    return out;
  }

  Map<String, dynamic> _roundTrip(Map<String, dynamic> m) => Map<String, dynamic>.from(jsonDecode(jsonEncode(m)) as Map);

  /// Hic oynanmamis (yeni kurulum) yerel kayit mi?
  bool _looksFresh(Map<String, dynamic>? p) {
    if (p == null) return true;
    final stars = p['chapterStars'];
    return ((p['maxUnlockedChapter'] as num?)?.toInt() ?? 1) <= 1 &&
        ((p['playerLevel'] as num?)?.toInt() ?? 1) <= 1 &&
        ((p['playerXp'] as num?)?.toInt() ?? 0) == 0 &&
        (stars is! Map || stars.isEmpty);
  }

  /// Giris yapmis Play Games oyuncusunun kimligi. Okunamazsa istisna: hesap
  /// dogrulanamadan hicbir sey birlestirilmez/yazilmaz (veri karismasin).
  Future<String> _currentPlayerId() async {
    final id = await GamesServices.getPlayerID();
    if (id == null || id.isEmpty) {
      throw StateError('Play Games oyuncu kimligi okunamadi');
    }
    return id;
  }

  /// true = tamam, false = yaris (tekrar dene). Ag hatasinda istisna firlatir.
  Future<bool> _syncOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final me = await _deviceId(prefs);
    final playerId = await _currentPlayerId(); // dogrulanamazsa istisna: hicbir sey yazilmaz
    final boundId = prefs.getString(_kPlayer);
    final switched = boundId != null && boundId != playerId;

    _Cloud? cloud;
    try {
      cloud = await _fetchCloud(); // ag hatasinda istisna: hicbir sey yazilmaz
      await prefs.remove(_kCorruptSince); // okunabildi: bozukluk sayaci sifirlanir
    } on CloudUnreadableException catch (e) {
      // Kayit VAR ama okunamadi: "bulut bos" DEGIL. Kosullu olarak ezilene dek hicbir sey yazilmaz.
      final fresh = _looksFresh(_roundTrip(GameProgress.instance.toJson()));
      if (switched || !await _noteUnreadable(prefs, e, fresh)) {
        lastError = 'Bulut kaydi okunamadi: ${e.reason}';
        throw e;
      }
      cloud = null; // sure doldu: yerel kayit ilk kayit gibi yazilir (ham kayit yedekte)
    }
    AppLog.i('cloud', '_syncOnce: bulut ${cloud == null ? "BOS (kayit yok)" : "rev=${cloud.rev} anahtar=${cloud.data.keys.length}"}');

    var base = SaveMerge.storesFrom(prefs.getString(_kBase));

    if (switched) {
      // HESAP DEGISTI: yerel kayit baska bir oyuncuya ait. Eski base/yarim kalan yazma
      // gecersiz; iki hesabin ilerlemesi KARISTIRILMAZ.
      AppLog.w('cloud', '_syncOnce: OYUNCU DEGISTI ($boundId -> $playerId): 3lu birlestirme yapilmayacak');
      base = null;
      await prefs.remove(_kBase);
      await prefs.remove(_kPending);
    }

    // Onceki turdan yarim kalan yazma var mi?
    final pendingRaw = switched ? null : prefs.getString(_kPending);
    if (pendingRaw != null) {
      try {
        final p = jsonDecode(pendingRaw) as Map;
        final pRev = (p['rev'] as num?)?.toInt() ?? 0;
        final landed = cloud != null && pRev > 0 && (cloud.seen[me] ?? 0) >= pRev;
        if (landed) {
          // Yazimimiz buluta ulasmis ama biz uygulayamadan kapanmisiz: simdi uygula.
          final m = SaveMerge.storesFrom(p['m']);
          final l1 = SaveMerge.storesFrom(p['l1']);
          if (m != null && l1 != null) {
            AppLog.i('cloud', '_syncOnce: yarim kalan yazma buluta ulasmis (rev=$pRev) -> simdi uygulaniyor');
            await _adopt(m, l1);
            base = m;
            await prefs.setString(_kBase, jsonEncode(m));
          }
        }
      } catch (err) { AppLog.w('cloud_save_service._adopt', 'yutulan hata', err); }
      await prefs.remove(_kPending);
    }

    final l1 = await _snapshotLocal();
    AppLog.i('cloud', '_syncOnce: yerel bolum=${l1[SaveMerge.kProgress]?["maxUnlockedChapter"]} taze=${_looksFresh(l1[SaveMerge.kProgress])} base=${base == null ? "yok" : "var"}');

    if (switched) {
      // Eski hesabin yerel halini yedekle (elle kurtarma icin).
      try {
        await prefs.setString(_kSwitchBackup, jsonEncode({'player': boundId, 'at': DateTime.now().millisecondsSinceEpoch, 'stores': l1}));
      } catch (err) { AppLog.w('cloud_save_service._syncOnce', 'hesap degisimi yedegi yazilamadi', err); }
    }

    Stores merged;
    if (switched && cloud != null) {
      merged = cloud.data; // yeni hesabin kaydi AYNEN gelir; eski hesabin yerel hali karismaz
      AppLog.i('cloud', '_syncOnce: karar=HESAP DEGISTI -> yeni hesabin bulutu aynen geliyor (eski yerel yedeklendi)');
    } else if (cloud == null) {
      merged = l1; // bulutta kayit yok: yerel ilk kayit olur
      AppLog.i('cloud', '_syncOnce: karar=YEREL ILK KAYIT OLACAK${switched ? " (yeni hesapta bulut kaydi yok, yerel korundu)" : ""}');
    } else if (base == null && _looksFresh(l1[SaveMerge.kProgress])) {
      merged = cloud.data; // yeni cihaz/yeniden kurulum: bulut aynen gelir
      AppLog.i('cloud', '_syncOnce: karar=BULUT AYNEN GELIYOR (yeni kurulum)');
    } else {
      merged = SaveMerge.all(base, l1, cloud.data);
      AppLog.i('cloud', '_syncOnce: karar=3LU BIRLESTIRME');
    }

    final needUpload = cloud == null || !SaveMerge.deepEq(merged, cloud.data);
    if (!needUpload) {
      await _adopt(merged, l1);
      await prefs.setString(_kPlayer, playerId); // _adopt biter bitmez hesaba bagla
      base = merged;
      await prefs.setString(_kBase, jsonEncode(merged));
      return true;
    }

    final rev = (cloud?.rev ?? 0) + 1;
    final seen = <String, int>{...?cloud?.seen, me: rev};
    // Yazmadan ONCE niyeti kaydet: yazma sirasinda kapanirsak sonra anlariz.
    await prefs.setString(_kPending, jsonEncode({'rev': rev, 'm': merged, 'l1': l1}));
    final payload = {
      'v': 2,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'rev': rev,
      'deviceId': me,
      'seen': seen,
      'chapter': (merged[SaveMerge.kProgress]?['maxUnlockedChapter'] as num?)?.toInt() ?? 1,
      'data': merged.map((k, v) => MapEntry(k, jsonEncode(v))),
    };
    final body = jsonEncode(payload);
    await GamesServices.saveGame(data: body, name: _slot);
    final mp = merged[SaveMerge.kProgress];
    final mb = merged[SaveMerge.kMergeBoard];
    AppLog.i('cloud',
        '_syncOnce: buluta yazildi rev=$rev boyut=${body.length}B anahtar=${merged.length} bolum=${mp?["maxUnlockedChapter"]} coin=${mp?["coins"]} elmas=${mp?["gems"]} mod2Bolum=${(mb?["b"] is Map) ? (mb!["b"] as Map)["ch"] : "-"} uretici=${mb?["pl"]}');

    // Dogrula: yazimimiz hala orada mi (baska cihaz arada yazmis olabilir)?
    final check = await _fetchCloud();
    if (check == null || (check.seen[me] ?? 0) < rev) {
      AppLog.w('cloud', '_syncOnce: dogrulama TUTMADI rev=$rev (baska cihaz yazdi ya da kayit okunamadi)');
      return false;
    }

    await _adopt(merged, l1);
    await prefs.setString(_kPlayer, playerId);
    await prefs.setString(_kBase, jsonEncode(merged));
    await prefs.remove(_kPending);
    await prefs.remove(_kCorruptSince); // yazimimiz dogrulandi: bulut artik saglam
    return true;
  }

  /// Birlestirilmis hali yerel servislere uygular. Agi beklerken oyuncu bir
  /// sey harcadi/kazandiysa ([l1] ile simdiki hal farki) onu ustune ekler.
  Future<void> _adopt(Map<String, Map<String, dynamic>> m, Map<String, Map<String, dynamic>> l1) async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Ilerleme: senkron bolum (arada oyuncu islemi araya giremez).
    final gp = GameProgress.instance;
    final mp = m[SaveMerge.kProgress];
    if (mp != null) {
      final l2 = _roundTrip(gp.toJson());
      final a = SaveMerge.rebase(SaveMerge.kProgress, mp, l1[SaveMerge.kProgress] ?? <String, dynamic>{}, l2);
      a.remove('wheelPending'); // yarim cark odulu tekrar verilmesin
      if (!SaveMerge.deepEq(_withoutWheel(a), _withoutWheel(l2))) {
        // Eski yerel hali yedekle (bir sorun cikarsa elde kalsin).
        // NOT: asagidaki iki cagri arasinda await YOK -> uygulama senkron kalir.
        prefs.setString(_backupKey, jsonEncode({'p': l2}));
        final f = gp.applyRemote(a);
        await f;
        AppLog.i('cloud',
            '_adopt: ilerleme buluttan UYGULANDI (yerel yedek alindi) coin ${l2["coins"]}->${a["coins"]} elmas ${l2["gems"]}->${a["gems"]} bolum ${l2["maxUnlockedChapter"]}->${a["maxUnlockedChapter"]}');
      }
    }

    // 2) Diger depolar.
    final changed = <String>[];
    await Future.wait([
      SeasonService.instance.save(),
      PiggyService.instance.save(),
      WeeklyEvent.instance.save(),
      EngageService.instance.save(),
      InboxService.instance.save(),
      MergeBoardService.instance.flush(),
      MbMissions.instance.flush(),
      PlanetEvent.instance.save(),
      LiveEvents.instance.save(),
      TeamRace.instance.save(),
    ]);
    for (final k in SaveMerge.otherKeys) {
      final mk = m[k];
      if (mk == null) continue;
      Map<String, dynamic> l2 = <String, dynamic>{};
      final raw = prefs.getString(k);
      if (raw != null && raw.isNotEmpty) {
        try {
          final d = jsonDecode(raw);
          if (d is Map) l2 = Map<String, dynamic>.from(d);
        } catch (err) { AppLog.w('cloud_save_service._adopt', 'yutulan hata', err); }
      }
      final a = SaveMerge.rebase(k, mk, l1[k] ?? <String, dynamic>{}, l2);
      if (!SaveMerge.deepEq(a, l2)) {
        await prefs.setString(k, jsonEncode(a));
        changed.add(k);
      }
    }
    if (changed.isNotEmpty) AppLog.i('cloud', '_adopt: buluttan guncellenen depolar: ${changed.join(", ")}');
    if (changed.contains(SaveMerge.kSeason)) await SeasonService.instance.load();
    if (changed.contains(SaveMerge.kPiggy)) await PiggyService.instance.load();
    if (changed.contains(SaveMerge.kEvents)) await WeeklyEvent.instance.load();
    if (changed.contains(SaveMerge.kEngage)) await EngageService.instance.load();
    if (changed.contains(SaveMerge.kInvite)) await InboxService.instance.reloadAfterCloudRestore();
    if (changed.contains(SaveMerge.kMergeBoard)) await MergeBoardService.instance.reloadAfterCloudRestore();
    if (changed.contains(SaveMerge.kPlanetEvent)) {
      AppLog.i('cloud', 'Hafta sonu etkinligi buluttan guncellendi');
      await PlanetEvent.instance.load();
    }
    if (changed.contains(SaveMerge.kLiveEvents)) {
      AppLog.i('cloud', 'Canli etkinlikler buluttan guncellendi');
      await LiveEvents.instance.load();
    }
    if (changed.contains(SaveMerge.kTeamRace)) {
      AppLog.i('cloud', 'Takim yarisi buluttan guncellendi');
      await TeamRace.instance.load();
    }
    if (changed.contains(SaveMerge.kMbMissions)) {
      AppLog.i('cloud', 'Mod 2 gorevleri buluttan guncellendi');
      await MbMissions.instance.load();
    }
  }

  /// Son buluttan-uygulama oncesi yerel ilerleme yedegi var mi?
  Future<bool> hasLocalBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_backupKey);
      if (raw == null || raw.isEmpty) return false;
      final j = jsonDecode(raw);
      return j is Map && j['p'] is Map;
    } catch (_) {
      return false;
    }
  }

  /// `cloud_pre_restore_backup_v1` yedegini (buluttan uygulamadan hemen onceki yerel
  /// ilerleme) geri yukler, sonra esitler. Yalniz ilerleme deposunu kapsar.
  /// NOT: bolum/seviye/satin alma gibi "asla geri gitmez" alanlar sonraki birlestirmede
  /// buluttaki degerle max alinir; geri yukleme asil olarak coin/elmas/sayac icindir.
  Future<bool> restoreLocalBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_backupKey);
      if (raw == null || raw.isEmpty) return false;
      final j = jsonDecode(raw);
      if (j is! Map || j['p'] is! Map) return false;
      final p = Map<String, dynamic>.from(j['p'] as Map);
      // Geri yuklemeden onceki hali de yedekle (geri alinabilsin).
      await prefs.setString('${_backupKey}_undo', jsonEncode({'p': _roundTrip(GameProgress.instance.toJson())}));
      p.remove('wheelPending');
      for (final k in SaveMerge.deviceLocal) {
        p[k] = GameProgress.instance.toJson()[k]; // ses/titresim ayarlari cihaza ozel kalir
      }
      await GameProgress.instance.applyRemote(p);
      AppLog.i('cloud', 'restoreLocalBackup: yerel yedek geri yuklendi');
      unawaited(syncNow());
      return true;
    } catch (e) {
      AppLog.e('cloud_save_service.restoreLocalBackup', 'hata', e);
      return false;
    }
  }

  Map<String, dynamic> _withoutWheel(Map<String, dynamic> m) {
    final c = Map<String, dynamic>.of(m);
    c.remove('wheelPending');
    return c;
  }
}

/// Bulutta kayit VAR ama cozumlenemedi (bozuk/taninmayan bicim). "Kayit yok"tan ayri tutulur.
class CloudUnreadableException implements Exception {
  final String reason;
  final String raw;
  CloudUnreadableException(this.reason, this.raw);
  @override
  String toString() => 'CloudUnreadableException: $reason';
}

class _Cloud {
  final int rev;
  final Map<String, int> seen;
  final Map<String, Map<String, dynamic>> data;
  _Cloud(this.rev, this.seen, this.data);
}
