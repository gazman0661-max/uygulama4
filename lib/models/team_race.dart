import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/log_service.dart';
import '../services/merge_board_service.dart';
import '../services/remote_tuning.dart';
import '../services/time_service.dart';
import 'bot_identity.dart';
import 'game_progress.dart';
import 'live_events.dart' show BotSpec, LiveEvents;
import 'planet_event.dart' show PlanetReward;
import 'team_race_schedule.dart';

/// Takimin sabit kimligi (ad + emoji + renk). Takim adlari ozel isim (spor takimi gibi) oldugu icin cevrilmez.
class TeamInfo {
  final String emoji;
  final String name;
  final int color; // ARGB
  const TeamInfo(this.emoji, this.name, this.color);
}

/// Siralamadaki bir takim satiri.
class TeamStanding {
  final int team;
  final int score; // takimin teslim ettigi toplam siparis
  final int rank; // 1 tabanli
  final bool isMine;
  const TeamStanding(this.team, this.score, this.rank, this.isMine);
}

/// Takim uyesi satiri (bot ya da oyuncu).
class TeamMember {
  final String name;
  final int score;
  final bool isPlayer;
  final BotProfile? profile; // oyuncuda null
  const TeamMember(this.name, this.score, this.isPlayer, this.profile);
}

/// Biten takim yarisinin bildirimi (menuye donuste tek seferlik).
class TeamRaceNote {
  final int team;
  final int rank; // takimin sirasi (1..10)
  final int orders; // oyuncunun teslim ettigi siparis
  final PlanetReward reward; // bos = odul yok
  final bool qualified; // en az [TeamRace.minOrders] siparis
  const TeamRaceNote(this.team, this.rank, this.orders, this.reward, this.qualified);
}

/// TAKIM YARISI (botlu): 10 takim, her takimda 15 kisi. Oyuncu bir takim secer (secim kesin: degistirme / ayrilma yok); takimlarin toplam TESLIM EDILEN
/// SIPARIS sayisi yarisir (Firlat modu siparisleri). 1 hafta surer (Pzt 10:00 - Pzt 10:00); o hafta Merge/Firlat Yarisi ve
/// Hafta Sonu etkinligi YOKTUR (bkz. [TeamRaceSchedule]). Ilk 3 takimin uyeleri odul alir (oyuncu en az [minOrders] siparis
/// teslim ettiyse).
///
/// - Giris ENERJIYLE: en fazla 3 enerji (hepsi bedava), 45 dk'da 1 enerji dolar. Bir BOLUM (tur) 1 enerji harcar
///   (Firlat modundaki kural). Saatte 1 kez reklam izleyip enerjiyi tamamen doldurabilir.
/// - Botlar saklanmaz: (hafta, takim, uye) tohumundan deterministik uretilir; puanlari zamandan hesaplanir
///   (sunucusuz). Oyuncunun takimi 15. kisi olarak katilir: o takimdan en yavas bot cikar (14 bot + oyuncu).
/// - Durum `team_race_v1` anahtarinda saklanir ve Play Games bulut kaydina girer (SaveMerge.kTeamRace: takim secimi kesin, siparis delta,
///   enerji iki cihazda cogalmaz, odul tek sefer).
/// - KAYIT DONEMI: yarisin ilk [joinHours] (24) saati YALNIZ takim secme (kayit) donemidir; kimse oynayamaz, botlar puan toplamaz.
///   Sure dolunca (Sali 10:00) yaris HERKES icin ayni anda baslar ([hasStarted]); yarisin gercek suresi hafta - [joinHours] (6 gun).
///   Takima KATILMA yalniz bu pencerede; sonra takimsiz oyuncu siralamayi izler, katilim sonraki yarisa kalir.
/// Tum sayilar asagida ayarlanabilir.
class TeamRace {
  TeamRace._();
  static final TeamRace instance = TeamRace._();

  static const String _key = 'team_race_v1';
  static const String _noteKey = 'team_race_note_v1';

  // ------------------------------------------------------------ ayarlar
  static const int teamCount = 10;
  static const int teamSize = 15;
  static const int maxEnergy = 3;
  static const int regenMinutes = 45;
  static const int adCooldownMinutes = 60; // saatte 1 reklam hakki
  static const int rewardedTeams = 3;

  /// KAYIT DONEMI (saat): yarisin ilk N saati. Bu surede takim secilir ama yaris BASLAMAZ (oynanamaz, botlar puan toplamaz);
  /// sure dolunca yaris herkes icin ayni anda baslar. Sonra yeni takim secilemez (siralama yine izlenir, katilim bir sonraki
  /// yarisa kalir). Remote: `team_race_join_hours` (varsayilan 24; 1..48). Yarisin ortasinda DEGISTIRME.
  static int get joinHours => RemoteTuning.i('team_race_join_hours', 24).clamp(1, 48).toInt();

  /// [run] numarali yarisin gercek baslangic ani (hafta basi + kayit donemi).
  static DateTime raceStartOf(int run) => TeamRaceSchedule.startOfWeek(run).add(Duration(hours: joinHours));

  /// Odul icin oyuncunun en az teslim etmesi gereken siparis (takima yuk olmasin). Remote: `team_race_min_orders`.
  static int get minOrders => RemoteTuning.i('team_race_min_orders', 10).clamp(0, 10000).toInt();

  /// 1., 2., 3. takim odulleri (takimin her uyesine; oyuncu icin [minOrders] sarti).
  static const List<PlanetReward> rankRewards = [
    PlanetReward(coins: 6000, gems: 60, energy: 60),
    PlanetReward(coins: 4000, gems: 40, energy: 40),
    PlanetReward(coins: 2500, gems: 25, energy: 25),
  ];

  static const List<TeamInfo> teams = [
    TeamInfo('🐉', 'Dragons', 0xFFE53935),
    TeamInfo('🐺', 'Wolves', 0xFF546E7A),
    TeamInfo('🦅', 'Falcons', 0xFF1E88E5),
    TeamInfo('🦁', 'Lions', 0xFFFB8C00),
    TeamInfo('🔥', 'Phoenix', 0xFFD81B60),
    TeamInfo('🦈', 'Sharks', 0xFF00ACC1),
    TeamInfo('🐯', 'Tigers', 0xFFF4511E),
    TeamInfo('🐼', 'Pandas', 0xFF43A047),
    TeamInfo('☄️', 'Comets', 0xFF8E24AA),
    TeamInfo('🦊', 'Foxes', 0xFFEF6C00),
  ];

  /// Takim guc carpanlari (kosuya gore takimlara KARISTIRILIR). Haftada: guclu takimlar ~3500 siparis, zayiflar ~1400
  /// (botlar tek basina). Orta gucteki bir takimi ortalama bir oyuncu (haftada ~600 siparis) ilk 3'e tasiyabilir.
  /// Remote: `team_race_bot_pct` (100 = bu degerler; 120 = botlar %20 hizli).
  static const List<double> strengths = [1.9, 1.7, 1.5, 1.35, 1.2, 1.05, 0.95, 0.85, 0.8, 0.75];

  /// Bot taban hiz araligi (siparis/saat, uyanikken): u^2 egrisi ile 0.3 .. 2.2 (ortalama ~0.93).
  static const double _minSpeed = 0.3;
  static const double _maxSpeed = 2.2;

  static const BotSpec _botSpec = BotSpec([1.0], awakeChance: 0.7, burstChance: 0.1, burstMul: 2.5);

  // ------------------------------------------------------------ testte degistirilebilir baglantilar
  static DateTime Function() clock = () => TimeService.instance.now();
  static bool Function() unlocked = () => GameProgress.instance.eventUnlocked;
  static void Function(PlanetReward r, String source) deliver = _defaultDeliver;
  static void Function()? onSaved;

  static void _defaultDeliver(PlanetReward r, String source) {
    if (r.coins > 0 || r.gems > 0) {
      GameProgress.instance.grantReward(coins: r.coins, gems: r.gems);
    }
    if (r.energy > 0) MergeBoardService.instance.grantEnergy(r.energy, source: source);
  }

  static DateTime _now() => clock();

  // ------------------------------------------------------------ durum (kalici)
  int _runId = -1; // takim yarisi haftasinin numarasi; -1 = yok
  int _team = -1; // secilen takim (0..9), -1 = secilmedi
  int _orders = 0; // oyuncunun bu yarista teslim ettigi siparis
  int _delivered = -1; // odulu teslim edilmis son yaris
  int _energy = maxEnergy;
  int _regenStartMs = 0;
  int _adAtMs = 0; // son odullu reklam dolumu (zaman damgasi, ms)
  Timer? _debounce;
  TeamRaceNote? _pendingNote; // bu oturumda biten yarisin bildirimi (diske de yazilir)
  Future<void> _noteWrite = Future<void>.value();

  int get team => _team;
  int get orders => _orders;
  bool get hasTeam => _team >= 0;

  /// Katilma penceresi acik mi? (yaris acik + takimsiz + yarisin ilk [joinHours] saati icinde)
  bool get canJoin => isActive && !hasTeam && elapsed < Duration(hours: joinHours);

  /// Yaris acik, oyuncu takimsiz ve katilma suresi dolmus (siralamayi izler, sonraki yarisa katilir).
  bool get joinClosed => isActive && !hasTeam && !canJoin;

  /// Katilma penceresinin kapanmasina kalan sure (kapaliysa / yaris disinda Duration.zero).
  Duration get joinTimeLeft {
    if (!canJoin) return Duration.zero;
    final left = Duration(hours: joinHours) - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Yaris fiilen basladi mi? (acik + kayit donemi bitti). Oncesinde oynanamaz, siparis sayilmaz, botlar 0'da.
  bool get hasStarted => isActive && elapsed >= Duration(hours: joinHours);

  /// Kayit donemi suruyor mu? (yaris haftasi acik ama yaris henuz baslamadi)
  bool get inRegistration => isActive && !hasStarted;

  /// Kayit doneminde: yarisin baslamasina kalan sure (aksi halde Duration.zero).
  Duration get startsIn {
    if (!inRegistration) return Duration.zero;
    final left = Duration(hours: joinHours) - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Yarisin gercek suresi: baslangictan itibaren gecen sure (kayit donemi haric; baslamadiysa sifir). Botlar bununla puanlanir.
  Duration get _raceElapsed {
    final left = elapsed - Duration(hours: joinHours);
    return left.isNegative ? Duration.zero : left;
  }

  // ------------------------------------------------------------ takvim
  /// Takim yarisi su an acik mi? (takim yarisi haftasi + etkinlikler acilmis)
  bool get isActive => isActiveAt(_now());

  static bool isActiveAt(DateTime n) => TeamRaceSchedule.isRaceWeekAt(n) && unlocked();

  int get currentRun => isActive ? TeamRaceSchedule.weekIdOf(_now()) : -1;

  /// Acikken: bitisine kalan; kapaliyken: sonraki yarisin baslamasina kalan (yoksa Duration.zero).
  Duration get timeLeft {
    final n = _now();
    if (TeamRaceSchedule.isRaceWeekAt(n)) return TeamRaceSchedule.endOfWeek(TeamRaceSchedule.weekIdOf(n)).difference(n);
    final w = TeamRaceSchedule.nextRaceWeekAfter(n);
    return w < 0 ? Duration.zero : TeamRaceSchedule.startOfWeek(w).difference(n);
  }

  Duration get elapsed {
    final n = _now();
    if (!TeamRaceSchedule.isRaceWeekAt(n)) return Duration.zero;
    return n.difference(TeamRaceSchedule.startOfWeek(TeamRaceSchedule.weekIdOf(n)));
  }

  /// Yaris degisimi: biten yarisin odulunu teslim eder ve durumu sifirlar; yeni yaris varsa baslatir.
  void _roll() {
    final n = _now();
    final cur = TeamRaceSchedule.isRaceWeekAt(n) ? TeamRaceSchedule.weekIdOf(n) : -1;
    if (_runId >= 0 && cur != _runId) {
      _finalize();
      _runId = -1;
      _team = -1;
      _orders = 0;
      _energy = maxEnergy;
      _regenStartMs = 0;
      _adAtMs = 0;
      save();
    }
    if (cur >= 0 && cur != _runId) {
      _runId = cur;
      _team = -1;
      _orders = 0;
      _energy = maxEnergy;
      _regenStartMs = 0;
      _adAtMs = 0;
      AppLog.i('team_race', 'YENI YARIS hafta=$cur');
      save();
    }
  }

  /// Biten yarisin sonucu: takimin sirasi + (ilk 3 ve sart saglandiysa) odul. Tek sefer ([_delivered]).
  void _finalize() {
    final run = _runId;
    if (run <= _delivered) return;
    _delivered = run;
    if (_team < 0) return; // takim secmedi: odul yok, bildirim yok
    final week = TeamRaceSchedule.endOfWeek(run).difference(TeamRaceSchedule.startOfWeek(run));
    final full = week - Duration(hours: joinHours); // kayit donemi puan toplamaz
    final st = _standingsAt(run, full.isNegative ? Duration.zero : full, _team, _orders);
    final mine = st.firstWhere((e) => e.team == _team);
    final qualified = _orders >= minOrders;
    var reward = const PlanetReward();
    if (mine.rank <= rewardedTeams && qualified) reward = rankRewards[mine.rank - 1];
    AppLog.i('team_race', 'YARIS BITTI hafta=$run takim=$_team sira=${mine.rank} siparis=$_orders sart=$qualified odul=${reward.coins}/${reward.gems}/${reward.energy}');
    AnalyticsService.instance.log('tr_finish', {'rank': mine.rank, 'orders': _orders, 'qualified': qualified});
    if (!reward.isEmpty) {
      try {
        deliver(reward, 'team_race');
      } catch (err) {
        AppLog.w('team_race._finalize', 'yutulan hata', err);
      }
    }
    final note = TeamRaceNote(_team, mine.rank, _orders, reward, qualified);
    _pendingNote = note;
    _noteWrite = _saveNote(note);
  }

  // ------------------------------------------------------------ takim secimi
  /// Takim sec. Yalniz yaris aciksa. Secim KESINDIR: yaris boyunca takim degistirilemez ve takimdan ayrilinamaz.
  bool chooseTeam(int t) {
    _roll();
    if (!isActive || t < 0 || t >= teamCount) return false;
    if (_team >= 0) return t == _team; // secim kesin: degistirme / ayrilma yok
    if (!canJoin) return false; // katilma suresi doldu: yalniz izleyebilir, sonraki yarisa katilir
    _team = t;
    AppLog.i('team_race', 'TAKIM SECILDI: $t (${teams[t].name})');
    AnalyticsService.instance.log('tr_join', {'team': t});
    _persist();
    return true;
  }

  // ------------------------------------------------------------ enerji
  int _nowMs() => _now().millisecondsSinceEpoch;

  int get energy {
    _roll();
    _regen();
    return _energy;
  }

  void _regen() {
    if (_energy >= maxEnergy) {
      _energy = maxEnergy;
      _regenStartMs = 0;
      return;
    }
    if (!TeamRaceSchedule.isRaceWeekAt(_now())) return; // yaris disinda yenilenme yok
    if (_regenStartMs == 0) return;
    const stepMs = regenMinutes * 60 * 1000;
    final gained = (_nowMs() - _regenStartMs) ~/ stepMs;
    if (gained <= 0) return;
    _energy = math.min(maxEnergy, _energy + gained);
    _regenStartMs = _energy >= maxEnergy ? 0 : _regenStartMs + gained * stepMs;
  }

  /// Siradaki enerjiye kalan sure (enerji doluysa null).
  Duration? get nextEnergyIn {
    if (energy >= maxEnergy || _regenStartMs == 0) return null;
    const stepMs = regenMinutes * 60 * 1000;
    final left = _regenStartMs + stepMs - _nowMs();
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  bool get canPlay => hasStarted && hasTeam && energy >= 1;

  /// Bir bolum (tur) 1 enerji harcar (Firlat modu kurali: kazanma / kayip / cikis). Enerji yoksa false.
  bool spendEnergy() {
    _roll();
    _regen();
    if (_energy < 1) return false;
    _energy--;
    if (_regenStartMs == 0) _regenStartMs = _nowMs();
    AppLog.i('team_race', 'ENERJI HARCANDI -> $_energy');
    _persist();
    return true;
  }

  /// Reklamla dolum: saatte 1 kez, enerji eksikse.
  Duration get adCooldownLeft {
    if (_adAtMs <= 0) return Duration.zero;
    final left = _adAtMs + adCooldownMinutes * 60 * 1000 - _nowMs();
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  bool get canAdRefill => isActive && energy < maxEnergy && adCooldownLeft == Duration.zero;

  /// Odullu reklam izlendikten SONRA cagrilir: tum enerjiyi doldurur ve 1 saatlik beklemeyi baslatir.
  bool refillAfterAd() {
    if (!canAdRefill) return false;
    _adAtMs = _nowMs();
    _energy = maxEnergy;
    _regenStartMs = 0;
    AppLog.i('team_race', 'REKLAMLA DOLUM');
    AnalyticsService.instance.log('tr_refill_ad');
    _persist();
    return true;
  }

  // ------------------------------------------------------------ puan
  /// Teslim edilen siparis (Firlat modu takim yarisi turlarinda). Takim secilmemis / yaris kapaliysa sayilmaz.
  void report(int n) {
    _roll();
    if (n <= 0 || !hasStarted || !hasTeam) return; // kayit doneminde siparis sayilmaz
    _orders += n;
    _persist();
  }

  bool get hasBadge => isActive && (hasTeam ? (hasStarted && energy >= 1) : canJoin);

  // ------------------------------------------------------------ botlar (saf, tohumdan)
  final Map<int, _RaceBots> _botCache = {};

  _RaceBots _botsFor(int run) {
    var b = _botCache[run];
    if (b == null) {
      if (_botCache.length >= 3) _botCache.clear();
      b = _RaceBots(run);
      _botCache[run] = b;
    }
    return b;
  }

  /// [elapsed] aninda 10 takimin siralamasi. [myTeam]/[myOrders]: oyuncunun takimi ve siparisi (yoksa -1).
  List<TeamStanding> _standingsAt(int run, Duration elapsed, int myTeam, int myOrders) {
    final bots = _botsFor(run);
    final pct = RemoteTuning.i('team_race_bot_pct', 100).clamp(10, 1000) / 100.0;
    final totals = <int>[];
    for (var t = 0; t < teamCount; t++) {
      var sum = 0;
      for (var i = 0; i < teamSize; i++) {
        if (t == myTeam && i == _RaceBots.droppedSlot) continue; // oyuncu bu kisinin yerine gecti
        sum += (bots.scoreAt(t, i, elapsed) * pct).floor();
      }
      if (t == myTeam) sum += myOrders;
      totals.add(sum);
    }
    final order = List<int>.generate(teamCount, (i) => i)
      ..sort((a, b) {
        final c = totals[b].compareTo(totals[a]);
        if (c != 0) return c;
        if (a == myTeam) return -1; // esitlikte oyuncunun takimi onde
        if (b == myTeam) return 1;
        return a.compareTo(b);
      });
    return [for (var r = 0; r < order.length; r++) TeamStanding(order[r], totals[order[r]], r + 1, order[r] == myTeam)];
  }

  /// Guncel takim siralamasi (yaris kapaliysa bos).
  List<TeamStanding> standings() {
    _roll();
    if (!isActive) return const [];
    return _standingsAt(_runId, _raceElapsed, _team, _orders);
  }

  int get myRank {
    if (!hasTeam) return 0;
    final st = standings();
    for (final e in st) {
      if (e.team == _team) return e.rank;
    }
    return 0;
  }

  /// Bir takimin uyeleri (puana gore, oyuncu dahil). [playerName] ekranda gorunen ad.
  List<TeamMember> members(int t, {String playerName = ''}) {
    _roll();
    if (!isActive || _runId < 0) return const [];
    final bots = _botsFor(_runId);
    final pct = RemoteTuning.i('team_race_bot_pct', 100).clamp(10, 1000) / 100.0;
    final out = <TeamMember>[];
    for (var i = 0; i < teamSize; i++) {
      if (t == _team && i == _RaceBots.droppedSlot) {
        out.add(TeamMember(playerName, _orders, true, null));
        continue;
      }
      out.add(TeamMember(bots.profile(t, i).name, (bots.scoreAt(t, i, _raceElapsed) * pct).floor(), false, bots.profile(t, i)));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  /// Takim yarisi bitince verilen odul (1..3. sira); disinda bos.
  static PlanetReward rewardForRank(int rank) =>
      rank >= 1 && rank <= rewardedTeams ? rankRewards[rank - 1] : const PlanetReward();

  // ------------------------------------------------------------ bildirim notu
  Future<void> _saveNote(TeamRaceNote n) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_noteKey, jsonEncode({
        't': n.team,
        'r': n.rank,
        'o': n.orders,
        'q': n.qualified,
        'c': n.reward.coins,
        'g': n.reward.gems,
        'e': n.reward.energy,
      }));
    } catch (err) {
      AppLog.w('team_race._saveNote', 'yutulan hata', err);
    }
  }

  /// Menuye donuste \"Takim Yarisi bitti\" bildirimi icin (tek seferlik).
  Future<TeamRaceNote?> takeNote() async {
    _roll();
    await _noteWrite; // bekleyen yazim bitsin (okuma/silme sirasi bozulmasin)
    final pending = _pendingNote;
    if (pending != null) {
      _pendingNote = null;
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove(_noteKey);
      } catch (_) {}
      return pending;
    }
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_noteKey);
      if (raw == null || raw.isEmpty) return null;
      await p.remove(_noteKey);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      int n(String k) => (j[k] as num?)?.toInt() ?? 0;
      return TeamRaceNote(n('t'), n('r'), n('o'), PlanetReward(coins: n('c'), gems: n('g'), energy: n('e')), j['q'] == true);
    } catch (err) {
      AppLog.w('team_race.takeNote', 'yutulan hata', err);
      return null;
    }
  }

  // ------------------------------------------------------------ kalicilik
  Map<String, dynamic> toJson() => {
        'r': _runId,
        't': _team,
        'o': _orders,
        'd': _delivered,
        'e': _energy,
        'rs': _regenStartMs,
        'ad': _adAtMs,
      };

  void applyJson(Map<String, dynamic> j) {
    int n(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    _runId = n('r', -1);
    _team = n('t', -1);
    if (_team >= teamCount) _team = -1;
    _orders = n('o', 0);
    _delivered = n('d', -1);
    _energy = n('e', maxEnergy).clamp(0, maxEnergy).toInt();
    _regenStartMs = n('rs', 0);
    _adAtMs = n('ad', 0);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) applyJson(jsonDecode(raw) as Map<String, dynamic>);
      AppLog.i('team_race.load', 'yuklendi yaris=$_runId takim=$_team siparis=$_orders enerji=$_energy');
    } catch (err) {
      AppLog.w('team_race.load', 'yutulan hata', err);
    }
    _roll();
  }

  Future<void> save() async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (err) {
      AppLog.w('team_race.save', 'yutulan hata', err);
    }
  }

  void _persist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      await save();
      onSaved?.call();
    });
  }

  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      await save();
      onSaved?.call();
    }
  }

  void resetForTest() {
    _debounce?.cancel();
    _runId = -1;
    _team = -1;
    _orders = 0;
    _delivered = -1;
    _energy = maxEnergy;
    _regenStartMs = 0;
    _adAtMs = 0;
    _pendingNote = null;
    _botCache.clear();
  }
}

/// Bir yarisin (hafta) 150 botu: kimlik + hiz + saat saat birikimli puan onbellegi. Saf tohum: ayni hafta = ayni botlar.
class _RaceBots {
  /// Oyuncu takima katilinca yerine gectigi uye (en yavas bot = 0. sira).
  static const int droppedSlot = 0;

  final int run;
  late final int seed;
  late final List<double> _factor; // takim carpani
  late final List<List<BotProfile>> _profiles;
  late final List<List<double>> _speeds;
  late final List<List<int>> _tz;
  final Map<int, List<double>> _cum = {}; // bot anahtari -> [0 saat, 1 saat, ...] birikimli (tam saatler)

  _RaceBots(this.run) {
    seed = (run * 7919 + 4421 + LiveEvents.botSalt) & 0x7fffffff;
    final r = math.Random(seed);
    // Guc carpanlarini takimlara karistir: her hafta guclu takimlar degisir.
    final perm = List<int>.generate(TeamRace.teamCount, (i) => i)..shuffle(r);
    _factor = [
      for (var t = 0; t < TeamRace.teamCount; t++) TeamRace.strengths[perm[t]] * (0.92 + 0.16 * r.nextDouble()),
    ];
    final used = <String>{};
    _profiles = [];
    _speeds = [];
    _tz = [];
    for (var t = 0; t < TeamRace.teamCount; t++) {
      final ps = <BotProfile>[];
      final sp = <double>[];
      final tz = <int>[];
      for (var i = 0; i < TeamRace.teamSize; i++) {
        final u = (i + 0.5) / TeamRace.teamSize;
        final base = TeamRace._minSpeed + (TeamRace._maxSpeed - TeamRace._minSpeed) * u * u;
        sp.add(base * _factor[t] * (0.85 + 0.30 * r.nextDouble()));
        ps.add(BotIdentity.make(r, used, fast01: u));
        tz.add(LiveEvents.tzShiftFor(seed, t * TeamRace.teamSize + i));
      }
      _profiles.add(ps);
      _speeds.add(sp);
      _tz.add(tz);
    }
  }

  BotProfile profile(int t, int i) => _profiles[t][i];

  /// Botun yarisin BASLANGICINDAN ([elapsed] = kayit donemi haric gecen sure) sonraki birikimli siparisi (azalmaz).
  /// Saat numaralari hafta basindan sayilir ([TeamRace.joinHours] kadar kaydirilir): uyku/uyanik saat deseni takvimle uyumlu kalir.
  int scoreAt(int t, int i, Duration elapsed) {
    final off = TeamRace.joinHours;
    final totalMin = TeamRaceSchedule.endOfWeek(run).difference(TeamRaceSchedule.startOfWeek(run)).inMinutes - off * 60;
    final mins = elapsed.inMinutes.clamp(0, totalMin < 0 ? 0 : totalMin).toInt();
    if (mins <= 0) return 0;
    final full = mins ~/ 60;
    final rem = (mins % 60) / 60.0;
    final key = off * 1000 + t * TeamRace.teamSize + i; // kayit suresi degisirse onbellek karismasin
    final cum = _cum.putIfAbsent(key, () => <double>[0.0]);
    while (cum.length <= full) {
      final h = cum.length - 1; // eklenecek saat (yaris saati)
      cum.add(cum.last + _hour(t, i, h + off, 1.0));
    }
    var total = cum[full];
    if (rem > 0) total += _hour(t, i, full + off, rem);
    return total.floor();
  }

  double _hour(int t, int i, int hour, double part) => LiveEvents.hourAmount(
        seed,
        t * TeamRace.teamSize + i,
        hour,
        _speeds[t][i],
        TeamRace._botSpec,
        awakeAdj: _profiles[t][i].awakeAdj,
        startHour: TeamRaceSchedule.startHour,
        tz: _tz[t][i],
        part: part,
      );
}
