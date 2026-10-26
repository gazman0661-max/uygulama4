import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_progress.dart';
import '../models/mb_missions.dart';
import '../models/merge_board.dart';
import '../models/season.dart';
import 'analytics_service.dart';
import 'log_service.dart';
import 'time_service.dart';

/// Bir bolum (ya da bir ekran oturumu) boyunca sayilan Mod 2 istatistikleri.
/// Bolum istatistigi diske yazilir ('mb_stats_v1'), boylece uygulama kapanip acilsa da
/// "bu bolum kac enerji / kac dakika surdu" olcumu bozulmaz. Oturum istatistigi bellekte.
class MbStats {
  int chapter;
  int startMs;
  int spawns = 0; // harcanan enerji (basarili uret)
  int merges = 0;
  int moves = 0;
  int swaps = 0;
  int items = 0; // teslim edilen kalem
  int orders = 0; // tamamlanan siparis
  int fullHits = 0; // "tahta dolu" uyarisi
  int noEnergyHits = 0; // "enerji bitti" penceresi
  int adEnergyCount = 0;
  int gemRefills = 0;
  int energyGained = 0; // bereket bolumu geri enerji

  MbStats(this.chapter, this.startMs);

  Map<String, dynamic> toJson() => {
        'ch': chapter,
        's': startMs,
        'sp': spawns,
        'mg': merges,
        'mv': moves,
        'sw': swaps,
        'it': items,
        'or': orders,
        'fh': fullHits,
        'ne': noEnergyHits,
        'ad': adEnergyCount,
        'gm': gemRefills,
        'eg': energyGained,
      };

  static MbStats? fromJson(Object? j) {
    if (j is! Map) return null;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    final st = MbStats(n('ch'), n('s'));
    st.spawns = n('sp');
    st.merges = n('mg');
    st.moves = n('mv');
    st.swaps = n('sw');
    st.items = n('it');
    st.orders = n('or');
    st.fullHits = n('fh');
    st.noEnergyHits = n('ne');
    st.adEnergyCount = n('ad');
    st.gemRefills = n('gm');
    st.energyGained = n('eg');
    return st;
  }

  String brief() =>
      'uret=$spawns birlesme=$merges tasima=$moves yerDegis=$swaps kalem=$items siparis=$orders '
      'dolu=$fullHits enerjiBitti=$noEnergyHits reklamEnerji=$adEnergyCount elmasDolum=$gemRefills geriEnerji=$energyGained';
}

/// MOD 2 (Merge Tahtasi) icin durum + kayit servisi.
/// Mantik: lib/models/merge_board.dart. Kayit: SharedPreferences ('mb_state_v1').
/// Coin, ana oyunun cuzdanina gider (GameProgress.addBonusCoins); gorev/sezon
/// ilerlemesine SAYILMAZ, boylece mod 1 ekonomisi bozulmaz.
class MergeBoardService extends ChangeNotifier {
  MergeBoardService._();
  static final MergeBoardService instance = MergeBoardService._();

  static const String _prefKey = 'mb_state_v1';
  static const String _statsKey = 'mb_stats_v1';
  static const String _tag = 'mod2';

  /// Kayit diske her yazildiginda cagrilir (main.dart: bulut esitlemesini zamanlar).
  static void Function()? onSaved;

  final math.Random _rng = math.Random();
  MbState state = MbState(board: MbBoard());
  bool _loaded = false;

  /// Son biten bolumun XP'si ve (varsa) seviye atlama odulleri (arayuz pop-up'i icin).
  int lastXp = 0;
  List<LevelUpReward> lastLevelUps = const <LevelUpReward>[];
  Timer? _debounce;

  /// Bolum bazli (kalici) ve ekran oturumu bazli (bellek) sayaclar.
  MbStats chapterStats = MbStats(1, 0);
  MbStats sessionStats = MbStats(1, 0);
  int _sessionStartMs = 0;
  int _saveCount = 0;

  bool get loaded => _loaded;
  MbBoard get board => state.board;
  int get worldIndex => state.worldIndex;

  int get nowMs => TimeService.instance.now().millisecondsSinceEpoch;

  // ── Log yardimcilari ────────────────────────────────────────
  /// Tahtadaki objelerin seviye dagilimi: "Lv1x5 Lv2x3 Lv4x1" (bos ise "bos").
  String boardHist() {
    final c = List<int>.filled(MbBoard.maxLevel + 1, 0);
    for (final v in board.cells) {
      if (MbBoard.validItem(v)) c[MbBoard.lv(v)]++;
    }
    final parts = <String>[];
    for (var l = 1; l <= MbBoard.maxLevel; l++) {
      if (c[l] > 0) parts.add('Lv${l}x${c[l]}');
    }
    return parts.isEmpty ? 'bos' : parts.join(' ');
  }

  int get filledCount => board.cells.where((l) => l > 0).length;

  /// Siparisler: "#12[2,3+] #13[4]" (+ = o kalem teslim edilmis).
  String ordersText() {
    if (board.orders.isEmpty) return '-';
    return board.orders.map((o) {
      // Birden cok uretici: "3@1" = 2. ureticinin (slot 1) Lv3 objesi.
      final items = <String>[
        for (var i = 0; i < o.levels.length; i++)
          '${MbBoard.lv(o.levels[i])}${MbBoard.slotOf(o.levels[i]) > 0 ? '@${MbBoard.slotOf(o.levels[i])}' : ''}${o.filled[i] ? '+' : ''}'
      ];
      return '#${o.id}[${items.join(',')}]';
    }).join(' ');
  }

  String _snap() =>
      'bolum=${board.chapter} ilerleme=${board.chapterProgress}/${board.chapterCfg.goal} dunya=$worldIndex '
      'enerji=${state.energy}/${MbState.maxEnergy} dolu=$filledCount/${MbBoard.size} obje=[${boardHist()}] siparis=${ordersText()}';

  Map<String, Object> _chParams([Map<String, Object> extra = const {}]) => <String, Object>{
        'chapter': board.chapter,
        'world': worldIndex,
        'rule': board.chapterCfg.rule.name,
        ...extra,
      };

  // ── Yukleme / kayit ─────────────────────────────────────────
  /// Ana sayfa ust cubugu ile Mod 2 ekrani ayni anda load() cagirabilir: tek bir yukleme calissin.
  Future<void>? _loading;

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _doLoad().whenComplete(() => _loading = null);
  }

  Future<void> _doLoad() async {
    if (_loaded) return;
    final t0 = DateTime.now();
    var source = 'yeni';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        state = MbState.fromJson(jsonDecode(raw), _rng);
        source = 'kayit(${raw.length}B)';
      } else {
        state = MbState.fresh(_rng);
      }
      chapterStats = MbStats.fromJson(_decode(prefs.getString(_statsKey))) ?? MbStats(board.chapter, nowMs);
    } catch (err, st) {
      AppLog.e(_tag, 'YUKLEME HATASI -> yeni tahta ile baslaniyor', err, st);
      state = MbState.fresh(_rng);
      source = 'hata->yeni';
      chapterStats = MbStats(board.chapter, nowMs);
    }
    if (chapterStats.chapter != board.chapter) {
      AppLog.w(_tag, 'bolum istatistigi eski (stat=${chapterStats.chapter} tahta=${board.chapter}) -> sifirlandi');
      chapterStats = MbStats(board.chapter, nowMs);
    }
    if (chapterStats.startMs == 0) chapterStats.startMs = nowMs;
    final energyRaw = state.energy;
    state.regen(nowMs);
    _loaded = true;
    if (_pendingGrant > 0) {
      // Yukleme bitmeden verilen enerji (ornegin cark odulu): simdi uygula ve kaydet.
      state.addEnergy(_pendingGrant);
      AppLog.i(_tag, 'BEKLEYEN ENERJI uygulandi: +$_pendingGrant -> ${state.energy}');
      _pendingGrant = 0;
      _persist();
    }
    AppLog.i(_tag,
        'YUKLENDI: kaynak=$source sure=${DateTime.now().difference(t0).inMilliseconds}ms cevrimdisiEnerji=+${state.energy - energyRaw} ${_snap()}');
    AppLog.i(_tag, 'bolum istatistigi (onceki oturumlardan): ${chapterStats.brief()}');
    notifyListeners();
  }

  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  void _persist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(state.toJson());
      await prefs.setString(_prefKey, data);
      await prefs.setString(_statsKey, jsonEncode(chapterStats.toJson()));
      _saveCount++;
      AppLog.i(_tag, 'kayit #$_saveCount tamam boyut=${data.length}B bolum=${board.chapter} ilerleme=${board.chapterProgress} enerji=${state.energy}');
      onSaved?.call();
    } catch (err, st) {
      AppLog.e(_tag, 'KAYIT HATASI (Mod 2 ilerlemesi yazilamadi)', err, st);
    }
  }

  /// Bulut birlestirmesi 'mb_state_v1' anahtarini diske yazdiktan sonra cagrilir:
  /// bellekteki durumu diskteki (birlestirilmis) halle degistirir.
  /// Servis henuz yuklenmediyse bir sey yapmaz; load() zaten yeni degeri okur.
  Future<void> reloadAfterCloudRestore() async {
    if (!_loaded) {
      AppLog.i(_tag, 'bulut geri yukleme: servis henuz yuklenmedi, load() yeni degeri okuyacak');
      return;
    }
    _debounce?.cancel();
    final before = 'bolum=${board.chapter} ilerleme=${board.chapterProgress} teslim=${board.delivered} enerji=${state.energy}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) {
        AppLog.w(_tag, 'bulut geri yukleme: diskte Mod 2 kaydi yok, bellek korundu');
        return;
      }
      state = MbState.fromJson(jsonDecode(raw), _rng);
      state.regen(nowMs);
      if (chapterStats.chapter != board.chapter) chapterStats = MbStats(board.chapter, nowMs);
    } catch (err, st) {
      AppLog.e(_tag, 'BULUT GERI YUKLEME HATASI', err, st);
      return;
    }
    AppLog.i(_tag, 'BULUT GERI YUKLEME: once[$before] -> sonra[bolum=${board.chapter} ilerleme=${board.chapterProgress} teslim=${board.delivered} enerji=${state.energy}]');
    AnalyticsService.instance.log('mb_cloud_restore', {'chapter': board.chapter});
    notifyListeners();
  }

  /// Ekrandan cikarken / uygulama arka plana giderken bekleyen kaydi hemen yazar.
  Future<void> flush() async {
    final pending = _debounce?.isActive ?? false;
    _debounce?.cancel();
    if (_loaded) {
      if (pending) AppLog.i(_tag, 'flush: bekleyen kayit hemen yaziliyor');
      await _save();
    }
  }

  // ── Ekran oturumu ───────────────────────────────────────────
  /// Ekran acildiginda cagrilir (yukleme bittikten sonra).
  void sessionStart() {
    sessionStats = MbStats(board.chapter, nowMs);
    _sessionStartMs = nowMs;
    AppLog.i(_tag, 'EKRAN ACILDI: ${_snap()}');
    AnalyticsService.instance.log('mb_open', _chParams({'energy': state.energy}));
  }

  /// Ekran kapanirken cagrilir.
  void sessionEnd() {
    if (!_loaded || _sessionStartMs == 0) return;
    final secs = ((nowMs - _sessionStartMs) / 1000).round();
    _sessionStartMs = 0;
    final s = sessionStats;
    AppLog.i(_tag, 'EKRAN KAPANDI: sure=${secs}s ${s.brief()} | ${_snap()}');
    AnalyticsService.instance.log('mb_close', _chParams({
      'secs': secs,
      'spawns': s.spawns,
      'merges': s.merges,
      'orders': s.orders,
      'energy': state.energy,
    }));
  }

  /// Su anki enerji (pasif dolum hesaba katilir).
  int get energy {
    state.regen(nowMs);
    return state.energy;
  }

  int get secondsToNextEnergy => state.secondsToNext(nowMs);

  /// [slot]: hangi ureticiye dokunuldu (0 = ana uretici).
  MbSpawnResult spawn({int slot = 0}) {
    final before = state.energy;
    final r = state.trySpawn(_rng, nowMs, slot: slot);
    switch (r) {
      case MbSpawnResult.ok:
        final free = state.lastSpawnFree; // uretici seviyesinden bedava dokunus: enerji harcanmadi
        if (!free) {
          chapterStats.spawns++;
          sessionStats.spawns++;
          MbMissions.instance.report(MbMetric.energy, 1); // her harcanan uretim 1 ⚡
        }
        final idx = state.lastSpawnIndex;
        final v = (idx >= 0 && idx < MbBoard.size) ? board.cells[idx] : 0;
        final lvl = MbBoard.validItem(v) ? MbBoard.lv(v) : 0;
        AppLog.i(_tag,
            'URET: uretici=$slot(zincir ${state.chainOfSlot(slot)} Lv${state.producerLevel(state.chainOfSlot(slot))}) hucre=$idx Lv$lvl${free ? ' BEDAVA' : ''} '
            'enerji $before -> ${state.energy} dolu=$filledCount/${MbBoard.size} obje=[${boardHist()}] bolumUret=${chapterStats.spawns}');
        _persist();
        notifyListeners();
        break;
      case MbSpawnResult.full:
        chapterStats.fullHits++;
        sessionStats.fullHits++;
        AppLog.w(_tag, 'URET REDDEDILDI: tahta dolu (${board.cells.length} hucre) obje=[${boardHist()}] siparis=${ordersText()}');
        AnalyticsService.instance.log('mb_board_full', _chParams({'orders_open': board.orders.length}));
        break;
      case MbSpawnResult.noEnergy:
        chapterStats.noEnergyHits++;
        sessionStats.noEnergyHits++;
        AppLog.w(_tag, 'URET REDDEDILDI: enerji yok (sonrakiEnerji=${state.secondsToNext(nowMs)}s) bolumUret=${chapterStats.spawns}');
        AnalyticsService.instance.log('mb_energy_empty', _chParams({'spawns_in_chapter': chapterStats.spawns}));
        break;
    }
    return r;
  }

  MbMove move(int from, int to) {
    final a0 = (from >= 0 && from < MbBoard.size) ? board.cells[from] : -1;
    final b0 = (to >= 0 && to < MbBoard.size) ? board.cells[to] : -1;
    final a = a0 > 0 ? MbBoard.lv(a0) : a0; // log/gorev icin yalniz seviye (zincir bilgisi olmadan)
    final b = b0 > 0 ? MbBoard.lv(b0) : b0;
    final r = board.move(from, to);
    switch (r) {
      case MbMove.merged:
        chapterStats.merges++;
        sessionStats.merges++;
        AppLog.i(_tag, 'BIRLESME: hucre $from + $to Lv$a + Lv$b -> Lv${a + 1}${a + 1 >= MbBoard.maxLevel ? ' (MAX)' : ''} dolu=$filledCount obje=[${boardHist()}]');
        if (a + 1 >= MbMissions.bigMergeLevel) MbMissions.instance.report(MbMetric.bigMerges, 1);
        if (a + 1 >= MbBoard.maxLevel) {
          MbMissions.instance.report(MbMetric.maxItems, 1);
          AnalyticsService.instance.log('mb_merge_max', _chParams());
        }
        break;
      case MbMove.moved:
        chapterStats.moves++;
        sessionStats.moves++;
        AppLog.i(_tag, 'TASI: hucre $from -> $to (Lv$a)');
        break;
      case MbMove.swapped:
        chapterStats.swaps++;
        sessionStats.swaps++;
        AppLog.i(_tag, 'YER DEGISTIR: hucre $from (Lv$a) <-> $to (Lv$b)');
        break;
      case MbMove.none:
        AppLog.w(_tag, 'HAMLE GECERSIZ: hucre $from -> $to (Lv$a / Lv$b)');
        break;
    }
    if (r != MbMove.none) {
      _persist();
      notifyListeners();
    }
    return r;
  }

  /// Teslim sonucu; siparis tamamlandiysa coin cuzdana eklenir.
  /// Bolum bittiyse bolum odulu de eklenir.
  /// Siparis/bolum tamamlaninca kayit BEKLEMEDEN yazilir (cikista ilerleme kaybolmasin).
  MbDeliverResult deliver(int cellIndex, int orderIndex) {
    final lvRaw = (cellIndex >= 0 && cellIndex < MbBoard.size) ? board.cells[cellIndex] : 0;
    final lvl = lvRaw > 0 ? MbBoard.lv(lvRaw) : 0;
    final oid = (orderIndex >= 0 && orderIndex < board.orders.length) ? board.orders[orderIndex].id : -1;
    final chapterBefore = board.chapter;
    final cfgBefore = board.chapterCfg;
    final coinsBefore = GameProgress.instance.coins;
    final energyBefore = state.energy;
    final r = board.deliver(cellIndex, orderIndex, _rng);
    if (!r.ok) {
      AppLog.w(_tag, 'TESLIM REDDEDILDI: hucre=$cellIndex Lv$lvl siparis=$orderIndex (#$oid) siparisler=${ordersText()}');
      return r;
    }
    chapterStats.items++;
    sessionStats.items++;
    if (lvRaw > 0 && MbBoard.slotOf(lvRaw) > 0) MbMissions.instance.report(MbMetric.chainItems, 1); // 2./3. ureticiden kalem
    if (!r.completed) {
      AppLog.i(_tag, 'KALEM TESLIM: hucre=$cellIndex Lv$lvl -> siparis #$oid | siparisler=${ordersText()}');
      _persist();
      notifyListeners();
      return r;
    }
    chapterStats.orders++;
    sessionStats.orders++;
    MbMissions.instance.report(MbMetric.orders, 1);
    SeasonService.instance.addPoints(SeasonService.spOrder);
    final coins = r.reward + r.chapterBonus;
    if (coins > 0) GameProgress.instance.addBonusCoins(coins);
    if (r.energyBonus > 0) {
      state.addEnergy(r.energyBonus);
      chapterStats.energyGained += r.energyBonus;
      sessionStats.energyGained += r.energyBonus;
    }
    AppLog.i(_tag,
        'SIPARIS TAMAM: #$oid son kalem=Lv$lvl odul=${r.reward} bolumBonus=${r.chapterBonus} geriEnerji=${r.energyBonus} '
        'coin $coinsBefore -> ${GameProgress.instance.coins} enerji $energyBefore -> ${state.energy} '
        'toplamTeslim=${board.delivered} bolumIlerleme=${board.chapterProgress}/${board.chapterCfg.goal}');
    AnalyticsService.instance.log('mb_order_done', {
      'chapter': cfgBefore.number,
      'world': MbState.worldOfChapter(cfgBefore.number),
      'rule': cfgBefore.rule.name,
      'reward': r.reward,
      'energy_back': r.energyBonus,
    });
    if (r.newProducer) {
      AppLog.i(_tag, 'YENI URETICI ACILDI: bolum=${board.chapter} acikUretici=${board.producerCount}');
      AnalyticsService.instance.log('mb_producer_unlock', {'chapter': board.chapter, 'world': worldIndex, 'count': board.producerCount});
    }
    if (r.chapterCompleted) {
      lastXp = MbChapter.of(r.finishedChapter).xpReward;
      MbMissions.instance.report(MbMetric.chapters, 1);
      final finCfg = MbChapter.of(r.finishedChapter);
      if (finCfg.isRule) MbMissions.instance.report(MbMetric.ruleChapters, 1);
      if (finCfg.isSpecial) MbMissions.instance.report(MbMetric.specialChapters, 1);
      SeasonService.instance.addPoints(SeasonService.spMbChapter);
      if (r.worldCompleted) {
        MbMissions.instance.report(MbMetric.worlds, 1);
        SeasonService.instance.addPoints(SeasonService.spMbWorld);
      }
      final lvBefore = GameProgress.instance.playerLevel;
      lastLevelUps = GameProgress.instance.addXp(lastXp);
      // "Seviye atladin, enerji doldu" mesaji Mod 2 enerjisi icin de dogru olsun
      // (addXp yalniz Mod 1 enerjisini dolduruyordu).
      if (lastLevelUps.isNotEmpty) {
        final before = state.energy;
        if (state.refillFull(nowMs)) {
          AppLog.i(_tag, 'SEVIYE ATLAMA: Mod 2 enerjisi dolduruldu $before -> ${state.energy}');
        }
      }
      _logChapterDone(r, cfgBefore, chapterBefore, lvBefore);
    }
    _debounce?.cancel();
    _save();
    notifyListeners();
    return r;
  }

  void _logChapterDone(MbDeliverResult r, MbChapter cfg, int chapterBefore, int levelBefore) {
    final st = chapterStats;
    final mins = st.startMs == 0 ? 0 : ((nowMs - st.startMs) / 60000).round();
    AppLog.i(_tag,
        'BOLUM BITTI: bolum=${r.finishedChapter} kural=${cfg.rule.name} hedef=${cfg.goal} bonus=${r.chapterBonus} xp=$lastXp '
        'oyuncuSeviye $levelBefore -> ${GameProgress.instance.playerLevel} seviyeAtlama=${lastLevelUps.length} sure~${mins}dk | ${st.brief()}');
    AnalyticsService.instance.log('mb_chapter_done', {
      'chapter': r.finishedChapter,
      'world': MbState.worldOfChapter(r.finishedChapter),
      'rule': cfg.rule.name,
      'goal': cfg.goal,
      'spawns': st.spawns, // = bu bolume harcanan enerji (denge icin ana olcu)
      'merges': st.merges,
      'orders': st.orders,
      'items': st.items,
      'energy_back': st.energyGained,
      'ad_energy': st.adEnergyCount,
      'gem_refills': st.gemRefills,
      'no_energy_hits': st.noEnergyHits,
      'full_hits': st.fullHits,
      'minutes': mins,
      'coins': r.chapterBonus,
      'xp': lastXp,
    });
    if (lastLevelUps.isNotEmpty) {
      AnalyticsService.instance.log('mb_player_level_up', {'level': GameProgress.instance.playerLevel, 'chapter': r.finishedChapter});
    }
    if (r.worldCompleted) {
      AppLog.i(_tag, 'DUNYA TAMAMLANDI: dunya=${MbState.worldOfChapter(r.finishedChapter)} -> yeni dunya=$worldIndex');
      AnalyticsService.instance.log('mb_world_done', {'world': MbState.worldOfChapter(r.finishedChapter), 'next_world': worldIndex});
    }
    // Yeni bolum icin sayaclar sifirlanir.
    chapterStats = MbStats(board.chapter, nowMs);
    sessionStats.chapter = board.chapter;
    final next = board.chapterCfg;
    AppLog.i(_tag, 'YENI BOLUM: bolum=${next.number} kural=${next.rule.name} hedef=${next.goal} Lv${next.minLevel}-${next.maxLevel} '
        'ureteciMax=Lv${next.maxSpawnLevel} odulYuzde=${next.rewardPercent} geriEnerji=${next.energyPerOrder}');
  }

  // ── Uretici yukseltme (v185) ────────────────────────────────
  int producerLevel(int chain) => state.producerLevel(chain);

  /// Zincirin ureticisinin sonraki seviye bedeli (coin); en ust seviyede null.
  int? producerUpgradeCost(int chain) => MbWorlds.upgradeCost(state.producerLevel(chain));

  /// Zincirin ureticisini coinle bir seviye yukseltir. Coin yetmezse/en ust seviyedeyse hicbir sey harcanmaz.
  MbUpgradeResult upgradeProducer(int chain) {
    final lvl = state.producerLevel(chain);
    final cost = MbWorlds.upgradeCost(lvl);
    if (cost == null) return MbUpgradeResult.maxed;
    if (!GameProgress.instance.spendCoins(cost, 'mb_producer')) {
      AppLog.w(_tag, 'URETICI YUKSELTME REDDEDILDI: zincir=$chain Lv$lvl coin yetmiyor (${GameProgress.instance.coins}/$cost)');
      return MbUpgradeResult.noCoins;
    }
    state.bumpProducer(chain);
    AppLog.i(_tag, 'URETICI YUKSELDI: zincir=$chain Lv$lvl -> Lv${state.producerLevel(chain)} bedel=$cost kalanCoin=${GameProgress.instance.coins}');
    AnalyticsService.instance.log('mb_producer_upgrade', _chParams({'chain': chain, 'level': state.producerLevel(chain), 'cost': cost}));
    _debounce?.cancel();
    _save();
    notifyListeners();
    return MbUpgradeResult.ok;
  }

  /// Elmasla tam dolum (MbState.refillGemCost). Bar zaten doluysa ya da elmas yetmiyorsa
  /// false doner ve elmas harcanmaz.
  bool refillWithGems() {
    state.regen(nowMs);
    if (state.energy >= MbState.maxEnergy) {
      AppLog.w(_tag, 'ELMAS DOLUM REDDEDILDI: bar zaten dolu (${state.energy})');
      return false;
    }
    final gemsBefore = GameProgress.instance.gems;
    final energyBefore = state.energy;
    if (!GameProgress.instance.spendGems(MbState.refillGemCost, 'mb_energy')) {
      AppLog.w(_tag, 'ELMAS DOLUM REDDEDILDI: elmas yetmiyor (${GameProgress.instance.gems}/${MbState.refillGemCost})');
      AnalyticsService.instance.log('mb_gem_refill_short', _chParams({'gems': gemsBefore}));
      return false;
    }
    state.refillFull(nowMs);
    chapterStats.gemRefills++;
    sessionStats.gemRefills++;
    AppLog.i(_tag, 'ELMAS DOLUM: -${MbState.refillGemCost} elmas ($gemsBefore -> ${GameProgress.instance.gems}) enerji $energyBefore -> ${state.energy}');
    AnalyticsService.instance.log('mb_gem_refill', _chParams({'gems_left': GameProgress.instance.gems, 'energy_before': energyBefore}));
    _persist();
    notifyListeners();
    return true;
  }

  /// "Daha Fazla Enerji?" paketi: MbState.gemPackCost 💎 -> MbState.gemPackEnergy ⚡
  /// (MbState.energyCap'e kadar). Enerji zaten tavandaysa ya da elmas yetmiyorsa elmas HARCANMAZ.
  MbBuyResult buyEnergyPack() {
    state.regen(nowMs);
    if (state.energy >= MbState.energyCap) {
      AppLog.w(_tag, 'ENERJI PAKETI REDDEDILDI: enerji tavanda (${state.energy}/${MbState.energyCap})');
      return MbBuyResult.full;
    }
    final gemsBefore = GameProgress.instance.gems;
    final energyBefore = state.energy;
    if (!GameProgress.instance.spendGems(MbState.gemPackCost, 'mb_energy_pack')) {
      AppLog.w(_tag, 'ENERJI PAKETI REDDEDILDI: elmas yetmiyor ($gemsBefore/${MbState.gemPackCost})');
      AnalyticsService.instance.log('mb_gem_pack_short', _chParams({'gems': gemsBefore}));
      return MbBuyResult.noGems;
    }
    state.addEnergy(MbState.gemPackEnergy);
    chapterStats.gemRefills++;
    sessionStats.gemRefills++;
    AppLog.i(_tag,
        'ENERJI PAKETI: -${MbState.gemPackCost} elmas ($gemsBefore -> ${GameProgress.instance.gems}) enerji $energyBefore -> ${state.energy}');
    AnalyticsService.instance.log('mb_gem_pack', _chParams({'gems_left': GameProgress.instance.gems, 'energy_before': energyBefore}));
    _persist();
    notifyListeners();
    return MbBuyResult.ok;
  }

  int _pendingGrant = 0;

  /// Disaridan (cark gibi) Mod 2 enerjisi ekler. Servis henuz yuklenmediyse yukleme bitince uygulanir.
  void grantEnergy(int n, {String source = 'grant'}) {
    if (n <= 0) return;
    if (!_loaded) {
      _pendingGrant += n;
      AppLog.i(_tag, 'ENERJI BEKLEMEYE ALINDI ($source): +$n (servis henuz yuklenmedi)');
      return;
    }
    final before = state.energy;
    state.addEnergy(n);
    AppLog.i(_tag, 'ENERJI EKLENDI ($source): +$n enerji $before -> ${state.energy}');
    _persist();
    notifyListeners();
  }

  /// Odullu reklam sonrasi enerji.
  void addAdEnergy() {
    final before = state.energy;
    state.addEnergy(MbState.adEnergy);
    chapterStats.adEnergyCount++;
    sessionStats.adEnergyCount++;
    AppLog.i(_tag, 'REKLAM ENERJISI: +${MbState.adEnergy} enerji $before -> ${state.energy} (tavan ${MbState.energyCap})');
    AnalyticsService.instance.log('mb_ad_energy', _chParams({'energy_before': before, 'energy_after': state.energy}));
    _persist();
    notifyListeners();
  }
}
