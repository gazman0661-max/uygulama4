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
import 'planet_event.dart' show PlanetReward;

/// Oyunun bildirdigi sayilabilir olaylar (metrikler). Bir etkinlik bunlardan BIRINI sayar.
/// Yeni metrik eklemek = burada bir sabit + oyunda ilgili yere tek satir
/// `LiveEvents.instance.report(EventMetric.xxx, 1)`.
class EventMetric {
  EventMetric._();
  static const String orderMod1 = 'order_mod1'; // Firlat modunda teslim edilen siparis (pratik hariç)
  static const String orderMod2 = 'order_mod2'; // Merge Tahtasi'nda tamamlanan siparis
  static const String mergeMod1 = 'merge_mod1'; // Firlat modunda birlestirme
  static const String comboMod1 = 'combo_mod1'; // Firlat modunda kombo (x-esigi asan)
  static const Set<String> all = {orderMod1, orderMod2, mergeMod1, comboMod1};
}

/// Bir hedef (kilometre tasi): [target] puana ulasinca [reward] alinir.
class EventGoal {
  final int target;
  final PlanetReward reward;
  const EventGoal(this.target, this.reward);
}

/// Botlu siralama ayari. [speeds] her botun UYANIKKEN saatlik ortalama puan hizi (bot sayisi = uzunluk).
///
/// Iki bicim: (1) [BotSpec] = elle yazilmis hiz listesi (az bot), (2) [BotSpec.spread] = [n] bot,
/// hizlari [minSpeed]..[maxSpeed] araligina `u^gamma` egrisiyle DOGAL dagitilir (gamma > 1: cok sayida
/// yavas/orta bot, az sayida cok hizli bot - gercek siralamalardaki gibi). 1000-3000 bot icin bunu kullan.
class BotSpec {
  final List<double> speeds;
  final int n;
  final double minSpeed;
  final double maxSpeed;
  final double gamma;
  final double awakeChance;
  final double burstChance;
  final double burstMul;
  const BotSpec(this.speeds, {this.awakeChance = 0.65, this.burstChance = 0.10, this.burstMul = 2.5})
      : n = 0,
        minSpeed = 0,
        maxSpeed = 0,
        gamma = 1;
  const BotSpec.spread(
    this.n, {
    required this.minSpeed,
    required this.maxSpeed,
    this.gamma = 3.0,
    this.awakeChance = 0.65,
    this.burstChance = 0.10,
    this.burstMul = 2.5,
  }) : speeds = const [];

  int get count => speeds.isNotEmpty ? speeds.length : n;

  /// [i]. botun taban hizi (puan/saat, uyanikken).
  double baseSpeed(int i) {
    if (speeds.isNotEmpty) return speeds[i];
    final u = (i + 0.5) / (n <= 0 ? 1 : n);
    return minSpeed + (maxSpeed - minSpeed) * math.pow(u, gamma).toDouble();
  }
}

/// Bir etkinligin TANIMI (veri). Kod yok: ayni motor tum etkinlikleri bu veriyle calistirir.
///
/// TAKVIM: hafta Pazartesi baslar. Etkinlik [startWeekday] gunu 00:00'da acilir, [days] gun surer.
/// [everyWeeks] > 1 ise yalnizca (hafta % everyWeeks == phase) haftalarda acilir (ornek: 2 haftada bir).
/// [days] en fazla 7*everyWeeks ve 14 olabilir (ayni etkinligin iki kosusu ust uste binmez).
///
/// ODUL: [goals] (hedefler, yarisin icinde "Al" ile) + [bots] varsa siralama ([rankRewards],
/// bitince otomatik). Botu olmayan etkinlik yalnizca hedeflerle calisir.
class EventDef {
  final String id; // kayit anahtari; yalniz [a-z0-9_] (1-32), nokta YOK
  final String titleKey; // AppStrings.lt anahtari (Ingilizce metin); titles bos/eksikse kullanilir
  final Map<String, String> titles; // dil kodu -> baslik (uzaktan gelen etkinlikler icin)
  final String metric;
  final int startWeekday; // 1 = Pzt ... 7 = Paz
  final int days;
  final int everyWeeks;
  final int phase;
  final List<EventGoal> goals;
  final BotSpec? bots;

  /// 1. sira, 2. sira ... Liste boyu kadar sira odul alir (ornek: 10 eleman = ilk 10).
  final List<PlanetReward> rankRewards;

  /// true: liste bitince SON eleman kalan tum siralara da verilir (eski davranis).
  /// false: listenin disindaki siralar siralama odulu ALMAZ (yalniz hedef odulleri).
  final bool restGetsLast;

  static const int maxBots = 3000;

  /// TEK SEFERLIK etkinlik: tam baslangic/bitis ani (yerel saat). Doluysa haftalik takvim
  /// ([startWeekday]/[days]/[everyWeeks]) YOK SAYILIR; etkinlik yalnizca [startAt, endAt) araliginda acik olur.
  /// Uzaktan: "startDate":"2026-11-01T18:00:00+03:00", "endDate":"2026-11-03T23:59:00+03:00"
  /// (saat dilimi ekini yazarsan her cihazda ayni an baslar). Ayni etkinligi tekrar acmak icin YENI id kullan.
  final DateTime? startAt;
  final DateTime? endAt;

  bool get isOneOff => startAt != null && endAt != null;

  /// Tek seferlik kosunun kimligi: baslangictan itibaren gecen saat (haftalik kimliklerle karismaz).
  int get _oneOffRun => startAt!.difference(DateTime(2024, 1, 1)).inHours;

  const EventDef({
    required this.id,
    this.titleKey = '',
    this.titles = const {},
    required this.metric,
    required this.startWeekday,
    required this.days,
    this.everyWeeks = 1,
    this.phase = 0,
    this.goals = const [],
    this.bots,
    this.rankRewards = const [],
    this.restGetsLast = false,
    this.startAt,
    this.endAt,
  });

  /// Kimlikten kararli sayi (bot tohumu icin).
  int get seed {
    var h = 17;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  String titleFor(String lang) => titles[lang] ?? titles['en'] ?? '';

  // ------------------------------------------------------------ takvim (saf fonksiyonlar)
  /// Pazartesi baslangicli hafta numarasi (2024-01-01 bir Pazartesi).
  static int weekIdOf(DateTime n) =>
      DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2024, 1, 1)).inDays ~/ 7;

  bool runsInWeek(int w) => w >= 0 && (w - phase) % everyWeeks == 0;

  /// Kosu kimligi = acildigi haftanin numarasi (tek seferlikte: baslangictan gecen saat).
  DateTime startOfRun(int w) => isOneOff ? startAt! : DateTime(2024, 1, 1 + w * 7 + (startWeekday - 1));

  DateTime endOfRun(int w) {
    if (isOneOff) return endAt!;
    final s = startOfRun(w);
    return DateTime(s.year, s.month, s.day + days);
  }

  /// [n] aninda acik kosunun kimligi; acik degilse null.
  int? runIdAt(DateTime n) {
    if (isOneOff) return (!n.isBefore(startAt!) && n.isBefore(endAt!)) ? _oneOffRun : null;
    final w = weekIdOf(n);
    for (final c in [w, w - 1, w - 2]) {
      if (runsInWeek(c) && !n.isBefore(startOfRun(c)) && n.isBefore(endOfRun(c))) return c;
    }
    return null;
  }

  /// [n]'den SONRA baslayacak ilk kosunun kimligi (yoksa -1).
  int nextRunAfter(DateTime n) {
    if (isOneOff) return startAt!.isAfter(n) ? _oneOffRun : -1;
    final w = weekIdOf(n);
    for (var c = w; c <= w + everyWeeks + 2; c++) {
      if (runsInWeek(c) && startOfRun(c).isAfter(n)) return c;
    }
    return -1;
  }

  // ------------------------------------------------------------ uzaktan (JSON) tanim
  static const int maxCoins = 50000;
  static const int maxGems = 200;
  static const int maxEnergy = 200;
  static const int maxTarget = 100000;

  static PlanetReward _reward(Map j) {
    int n(String k, int hi) => ((j[k] as num?)?.toInt() ?? 0).clamp(0, hi).toInt();
    return PlanetReward(coins: n('c', maxCoins), gems: n('g', maxGems), energy: n('e', maxEnergy));
  }

  /// Uzaktan gelen tek etkinlik. Gecersizse null. Sayilar sinirlanir (yanlis yazilmis odul ekonomiyi bozmasin).
  static EventDef? fromJson(Map<String, dynamic> j) {
    try {
      final id = '${j['id'] ?? ''}'.toLowerCase();
      if (!RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(id)) return null;
      final metric = '${j['metric'] ?? ''}';
      if (!EventMetric.all.contains(metric)) return null;
      int n(String k, int d, int lo, int hi) => ((j[k] as num?)?.toInt() ?? d).clamp(lo, hi).toInt();
      // Tek seferlik tarih araligi (istege bagli). Gecersiz/yarim yazildiysa etkinlik REDDEDILIR.
      DateTime? startAt;
      DateTime? endAt;
      if (j['startDate'] != null || j['endDate'] != null) {
        startAt = DateTime.tryParse('${j['startDate'] ?? ''}')?.toLocal();
        endAt = DateTime.tryParse('${j['endDate'] ?? ''}')?.toLocal();
        if (startAt == null || endAt == null) return null;
        if (startAt.isBefore(DateTime(2024, 1, 1))) return null;
        final span = endAt.difference(startAt);
        if (span < const Duration(hours: 1) || span > const Duration(days: 14)) return null;
      }
      final everyWeeks = n('everyWeeks', 1, 1, 8);
      final days = n('days', 2, 1, math.min(14, 7 * everyWeeks));
      final startWeekday = n('startWeekday', 1, 1, 7);
      final phase = n('phase', 0, 0, everyWeeks - 1);

      final goals = <EventGoal>[];
      var last = 0;
      for (final g in (j['goals'] as List? ?? const [])) {
        if (g is! Map || goals.length >= 8) continue;
        final t = ((g['t'] as num?)?.toInt() ?? 0).clamp(1, maxTarget).toInt();
        if (t <= last) continue; // hedefler artan olmali
        last = t;
        goals.add(EventGoal(t, _reward(g)));
      }

      BotSpec? bots;
      final b = j['bots'];
      if (b is Map) {
        double dd(String k, double d, double lo, double hi) =>
            ((b[k] as num?)?.toDouble() ?? d).clamp(lo, hi).toDouble();
        final awake = dd('awake', 0.65, 0.05, 1.0);
        final burst = dd('burst', 0.10, 0.0, 0.5);
        final burstMul = dd('burstMul', 2.5, 1.0, 5.0);
        final sp = <double>[];
        for (final v in (b['speeds'] as List? ?? const [])) {
          if (v is num && sp.length < 64) sp.add(v.toDouble().clamp(0.01, 1000.0).toDouble());
        }
        if (sp.isNotEmpty) {
          bots = BotSpec(sp, awakeChance: awake, burstChance: burst, burstMul: burstMul);
        } else if (b['count'] is num) {
          // Uzaktan "bots": {"count": 1500, "minSpeed": 0.1, "maxSpeed": 4.5, "gamma": 3}
          final count = (b['count'] as num).toInt().clamp(1, maxBots).toInt();
          final lo = dd('minSpeed', 0.05, 0.01, 1000.0);
          final hi = dd('maxSpeed', 1.0, 0.01, 1000.0);
          bots = BotSpec.spread(
            count,
            minSpeed: math.min(lo, hi),
            maxSpeed: math.max(lo, hi),
            gamma: dd('gamma', 3.0, 1.0, 8.0),
            awakeChance: awake,
            burstChance: burst,
            burstMul: burstMul,
          );
        }
      }

      final ranks = <PlanetReward>[];
      for (final r in (j['ranks'] as List? ?? const [])) {
        if (r is Map && ranks.length < 20) ranks.add(_reward(r));
      }
      if (bots == null && goals.isEmpty) return null; // ne hedef ne siralama: bos etkinlik
      if (bots == null) ranks.clear();

      final titles = <String, String>{};
      final t = j['title'];
      if (t is Map) {
        t.forEach((k, v) {
          final s = '$v'.trim();
          if (s.isNotEmpty) titles['$k'] = s.length > 40 ? s.substring(0, 40) : s;
        });
      }
      return EventDef(
        id: id,
        titles: titles,
        metric: metric,
        startWeekday: startWeekday,
        days: days,
        everyWeeks: everyWeeks,
        phase: phase,
        goals: goals,
        bots: bots,
        rankRewards: ranks,
        // Uzaktan JSON'da varsayilan ESKI davranis (son odul kalanlara); kapatmak icin "restGetsLast": false.
        restGetsLast: j['restGetsLast'] != false,
        startAt: startAt,
        endAt: endAt,
      );
    } catch (err) {
      AppLog.w('events.fromJson', 'yutulan hata', err);
      return null;
    }
  }
}

/// Siralamadaki bir satir (oyuncu ya da bot).
class RaceStanding {
  final String name;
  final int score;
  final bool isPlayer;
  final int botIndex; // oyuncuda -1
  final BotProfile? profile; // botta avatar/seviye; oyuncuda null
  const RaceStanding(this.name, this.score, this.isPlayer, this.botIndex, {this.profile});
}

/// Biten etkinligin bildirimi (menuye donuste tek seferlik). [rank] 0 = siralamasiz etkinlik.
class EventNote {
  final String eventId;
  final int rank;
  final PlanetReward reward;
  const EventNote(this.eventId, this.rank, this.reward);
}

/// Bir kosunun bot tahtasi. Kimlikler ve hizlar kosu boyunca sabit; puanlar dakikada bir yeniden hesaplanir.
/// Saatlik toplamlar saklanir, yani her dakika yalnizca O SAATIN kismi hesaplanir (1500 bot x 1 Random).
/// Sonuc, [LiveEvents.botScoreAt] ile BIREBIR aynidir.
class _BotBoard {
  final List<double> speeds;
  final List<BotProfile> profiles;
  final int seed;
  final BotSpec spec;
  final int startHour; // kosunun basladigi saat (0-23): botlarin gun ritmi icin
  late final List<int> _tz; // botun saat dilimi kaymasi (LiveEvents.tzShiftFor)

  late List<double> _base;
  int _hoursDone = 0;
  int _minute = -1;

  List<int> scores = const []; // bot indeksine gore puan
  List<int> order = const []; // bot indeksleri, puan buyukten kucuge (esitlikte kucuk indeks once)
  List<int> sorted = const []; // order sirasindaki puanlar (azalan)

  _BotBoard(this.speeds, this.profiles, this.seed, this.spec, {this.startHour = 0}) {
    _base = List<double>.filled(spec.count, 0.0);
    _tz = [for (var i = 0; i < spec.count; i++) LiveEvents.tzShiftFor(seed, i)];
  }

  int get count => spec.count;

  void update(int minute) {
    if (minute == _minute) return;
    _minute = minute;
    final n = spec.count;
    final full = minute <= 0 ? 0 : minute ~/ 60;
    final rem = minute <= 0 ? 0.0 : (minute % 60) / 60.0;
    if (full < _hoursDone) {
      _base = List<double>.filled(n, 0.0); // saat geri gitti (test/saat degisikligi): bastan hesapla
      _hoursDone = 0;
    }
    while (_hoursDone < full) {
      for (var i = 0; i < n; i++) {
        _base[i] += LiveEvents.hourAmount(seed, i, _hoursDone, speeds[i], spec,
            awakeAdj: profiles[i].awakeAdj, startHour: startHour, tz: _tz[i]);
      }
      _hoursDone++;
    }
    final sc = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      var t = _base[i];
      if (minute > 0 && rem > 0) {
        t += LiveEvents.hourAmount(seed, i, full, speeds[i], spec,
            awakeAdj: profiles[i].awakeAdj, startHour: startHour, tz: _tz[i], part: rem);
      }
      sc[i] = t.floor();
    }
    final ord = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final x = sc[b].compareTo(sc[a]);
        return x != 0 ? x : a.compareTo(b);
      });
    scores = sc;
    order = ord;
    sorted = [for (final i in ord) sc[i]];
  }

  /// Oyuncunun sirasi (1 tabanli). Esit puanda oyuncu onde; puani 0 ise en sonda (henuz yarismiyor).
  int rankOf(int playerScore) {
    if (playerScore <= 0) return sorted.length + 1;
    var lo = 0;
    var hi = sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (sorted[mid] > playerScore) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo + 1;
  }

  int? pointsToNext(int playerScore) {
    final r = rankOf(playerScore);
    if (r <= 1) return null;
    final need = sorted[r - 2] - (playerScore < 0 ? 0 : playerScore);
    return need < 1 ? 1 : need;
  }

  int? pointsToEnter(int playerScore, int top) {
    if (top < 1 || rankOf(playerScore) <= top) return null;
    if (top > sorted.length) return null;
    final need = sorted[top - 1] - (playerScore < 0 ? 0 : playerScore);
    return need < 1 ? 1 : need;
  }

  List<RaceStanding> rows(int playerScore, String playerName, int? limit) {
    final rank = rankOf(playerScore);
    final total = order.length + 1;
    final cap = limit == null ? total : (limit < total ? limit : total);
    final out = <RaceStanding>[];
    var bi = 0;
    for (var pos = 1; pos <= cap; pos++) {
      if (pos == rank) {
        out.add(RaceStanding(playerName, playerScore, true, -1));
      } else {
        final bot = order[bi++];
        out.add(RaceStanding(profiles[bot].name, scores[bot], false, bot, profile: profiles[bot]));
      }
    }
    return out;
  }
}

class _Ev {
  int run = -1;
  int score = 0;
  int delivered = -1; // odulu verilen en son kosu (cift teslimi onler)
  final Set<int> claimed = {};
}

/// CANLI ETKINLIK MOTORU: tanimlara ([EventDef]) gore tum zamanli etkinlikleri yurutur.
///
/// - Tanimlar [defaultDefs] + Remote Config 'events_json' (VERI, kod degil). JSON bicimi icin
///   README'deki "Uzaktan etkinlik" bolumune bak. Gecersiz JSON yok sayilir, varsayilanlar calisir.
/// - Puan: oyun `report(metric, adet)` der; o metrigi sayan ACIK etkinliklerin hepsine eklenir.
/// - Botlar: puanlari SAKLANMAZ, (etkinlik, kosu, saat) tohumundan HESAPLANIR (sunucusuz, deterministik).
/// - Kosu bitince: siralama odulu + alinmamis hedefler OTOMATIK hesaba eklenir (puani 0 olana verilmez).
/// - Kayit: tek anahtar 'live_events_v1', DUZ yapi: '<id>.r' kosu, '<id>.s' puan, '<id>.dr' odulu verilen
///   son kosu, '<id>.cl' alinan hedefler. Bulut: SaveMerge.liveEvents.
///
/// NOT: WeeklyEvent ve PlanetEvent bu motora TASINMADI (yayindaki kayitlari bozmamak icin).
class LiveEvents {
  LiveEvents._();
  static final LiveEvents instance = LiveEvents._();

  static const String _key = 'live_events_v1';
  static const String _noteKey = 'live_events_note_v1'; // cihaza ozel, buluta gitmez
  static const String remoteKey = 'events_json';

  /// Varsayilan etkinlikler. Pzt-Sal: Merge Tahtasi siparis yarisi, Car-Per: Firlat siparis yarisi.
  /// BASLANGIC TAHMINI sayilar: Mod 2'de siparis yavas (bolum basina 3-6), Mod 1'de hizli (15-50).
  static const List<EventDef> defaultDefs = [
    EventDef(
      id: 'race_mod2',
      titleKey: 'Merge Board Race',
      metric: EventMetric.orderMod2,
      startWeekday: DateTime.monday,
      days: 2,
      goals: [
        EventGoal(5, PlanetReward(coins: 300, energy: 10)),
        EventGoal(12, PlanetReward(coins: 600, gems: 5, energy: 15)),
        EventGoal(24, PlanetReward(coins: 1000, gems: 10, energy: 20)),
        EventGoal(40, PlanetReward(coins: 1500, gems: 15, energy: 30)),
      ],
      // v219: botlar guclendirildi (aktif insan botlardan 3-5 kat fazla puan yapiyordu).
      // 1500 bot: ilk 1 ~52, ilk 10 ~42, 100. ~30, ortanca ~5 siparis / 48 saat (simulasyonla olculdu).
      // Gunde 3 oturum + 8 reklam ~5. siraya, gunde 5 oturum + 8 reklam 1. siraya cikarir.
      bots: BotSpec.spread(1500, minSpeed: 0.042, maxSpeed: 1.05),
      rankRewards: [
        PlanetReward(coins: 2500, gems: 30, energy: 50), // 1
        PlanetReward(coins: 1500, gems: 20, energy: 30), // 2
        PlanetReward(coins: 1000, gems: 10, energy: 20), // 3
        PlanetReward(coins: 600, gems: 5, energy: 10), // 4
        PlanetReward(coins: 600, gems: 5, energy: 10), // 5
        PlanetReward(coins: 300, energy: 5), // 6
        PlanetReward(coins: 300, energy: 5), // 7
        PlanetReward(coins: 300, energy: 5), // 8
        PlanetReward(coins: 300, energy: 5), // 9
        PlanetReward(coins: 300, energy: 5), // 10
      ],
    ),
    EventDef(
      id: 'race_mod1',
      titleKey: 'Throw Race',
      metric: EventMetric.orderMod1,
      startWeekday: DateTime.wednesday,
      days: 2,
      goals: [
        EventGoal(30, PlanetReward(coins: 400)),
        EventGoal(70, PlanetReward(coins: 800, gems: 5)),
        EventGoal(120, PlanetReward(coins: 1500, gems: 10)),
        EventGoal(200, PlanetReward(coins: 2500, gems: 15)),
      ],
      // v219: botlar ~3,5 kat guclendirildi (aktif insan botlardan 3-5 kat fazla puan yapiyordu).
      // 1500 bot: ilk 1 ~1040, ilk 10 ~860, 100. ~600, 300. ~380, ortanca ~100 siparis / 48 saat (simulasyonla olculdu).
      // Ust uc yuksek tutuldu: yogun oyuncu (gunde 3 oturum + 3 reklam) birinciligi botlarla yarisir.
      bots: BotSpec.spread(1500, minSpeed: 0.35, maxSpeed: 21.0),
      rankRewards: [
        PlanetReward(coins: 4000, gems: 30), // 1
        PlanetReward(coins: 2500, gems: 20), // 2
        PlanetReward(coins: 1500, gems: 10), // 3
        PlanetReward(coins: 1000, gems: 8), // 4
        PlanetReward(coins: 1000, gems: 8), // 5
        PlanetReward(coins: 600, gems: 5), // 6
        PlanetReward(coins: 600, gems: 5), // 7
        PlanetReward(coins: 600, gems: 5), // 8
        PlanetReward(coins: 600, gems: 5), // 9
        PlanetReward(coins: 600, gems: 5), // 10
      ],
    ),
  ];

  // ------------------------------------------------------- test icin enjeksiyon
  /// "Simdi" kaynagi (testte degistirilir).
  static DateTime Function() clock = () => TimeService.instance.now();

  /// Seviye kilidi (testte degistirilir). Varsayilan: haftalik etkinlikle ayni.
  static bool Function() unlocked = () => GameProgress.instance.eventUnlocked;

  /// Odul verme (testte degistirilir).
  static void Function(PlanetReward r, String source) deliver = _defaultDeliver;

  /// Kayit sonrasi bulut yuklemesini tetikler (main.dart baglar). save() BILEREK tetiklemez.
  static void Function()? onSaved;

  static void _defaultDeliver(PlanetReward r, String source) {
    if (r.coins > 0 || r.gems > 0) {
      GameProgress.instance.grantReward(coins: r.coins, gems: r.gems);
    }
    if (r.energy > 0) MergeBoardService.instance.grantEnergy(r.energy, source: source);
  }

  // ------------------------------------------------------------ tanimlar (varsayilan + uzaktan)
  /// Uzaktan JSON: {"events":[{...}, ...]}  ya da dogrudan [{...}]. Ayni id varsayilani EZER,
  /// {"id":"race_mod1","off":true} varsayilani KAPATIR, yeni id eklenir (en fazla 12 etkinlik).
  static List<EventDef> mergeRemote(List<EventDef> base, String raw) {
    if (raw.trim().isEmpty) return base;
    try {
      final j = jsonDecode(raw);
      final list = j is Map ? j['events'] : j;
      if (list is! List) return base;
      final out = List<EventDef>.of(base);
      for (final e in list) {
        if (e is! Map) continue;
        final id = '${e['id'] ?? ''}'.toLowerCase();
        if (e['off'] == true) {
          out.removeWhere((d) => d.id == id);
          continue;
        }
        final d = EventDef.fromJson(Map<String, dynamic>.from(e));
        if (d == null) continue;
        final i = out.indexWhere((x) => x.id == d.id);
        if (i >= 0) {
          out[i] = d;
        } else if (out.length < 12) {
          out.add(d);
        }
      }
      return out;
    } catch (err) {
      AppLog.w('events.mergeRemote', 'gecersiz JSON yok sayildi', err);
      return base;
    }
  }

  String? _rawCached;
  List<EventDef> _defsCached = defaultDefs;

  List<EventDef> get defs {
    final raw = RemoteTuning.s(remoteKey);
    if (raw != _rawCached) {
      _rawCached = raw;
      _defsCached = mergeRemote(defaultDefs, raw);
    }
    return _defsCached;
  }

  EventDef? byId(String id) {
    for (final d in defs) {
      if (d.id == id) return d;
    }
    return null;
  }

  // ------------------------------------------------------------ durum
  final Map<String, _Ev> _st = {};
  final List<EventNote> _pending = [];
  Timer? _debounce;

  _Ev _ev(String id) => _st.putIfAbsent(id, () => _Ev());

  static DateTime _now() => clock();

  // ------------------------------------------------------------ kosu degisimi
  void _roll(EventDef d) {
    final n = _now();
    final st = _ev(d.id);
    if (st.run >= 0 && !n.isBefore(d.endOfRun(st.run))) {
      _finalize(d, st);
      st.run = -1;
      st.score = 0;
      st.claimed.clear();
      unawaited(save());
    }
    final cur = d.runIdAt(n);
    if (cur != null && cur != st.run) {
      st.run = cur;
      st.score = 0;
      st.claimed.clear();
      AppLog.i('events', 'YENI KOSU id=${d.id} kosu=$cur');
      unawaited(save());
    }
  }

  void _rollAll() {
    for (final d in defs) {
      _roll(d);
    }
  }

  /// Biten kosunun siralama odulunu ve alinmamis hedef odullerini hesaba ekler.
  void _finalize(EventDef d, _Ev st) {
    final run = st.run;
    if (run <= st.delivered) {
      AppLog.i('events', 'finalize atlandi: ${d.id} kosu=$run zaten teslim edildi');
      return;
    }
    st.delivered = run;
    if (st.score <= 0) {
      AppLog.i('events', '${d.id} kosu=$run bitti: puan 0, odul yok');
      return;
    }
    var total = const PlanetReward();
    var rank = 0;
    if (d.bots != null) {
      final span = d.endOfRun(run).difference(d.startOfRun(run));
      rank = _boardAt(d, run, span).rankOf(st.score);
      total = rankReward(d, rank);
    }
    for (var i = 0; i < d.goals.length; i++) {
      if (st.score >= d.goals[i].target && !st.claimed.contains(i)) total = total + d.goals[i].reward;
    }
    if (total.isEmpty && rank == 0) return;
    try {
      deliver(total, 'event_auto');
      AppLog.i('events', 'KOSU BITTI ${d.id} kosu=$run puan=${st.score} sira=$rank coin=${total.coins} elmas=${total.gems} enerji=${total.energy}');
      AnalyticsService.instance.log('event_end', {'id': d.id, 'rank': rank, 'score': st.score});
      _pending.add(EventNote(d.id, rank, total));
      unawaited(_saveNotes());
    } catch (err) {
      AppLog.w('events._finalize', 'yutulan hata', err);
    }
  }

  Future<void> _saveNotes() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = [
        for (final n in _pending) {'i': n.eventId, 'k': n.rank, 'c': n.reward.coins, 'g': n.reward.gems, 'e': n.reward.energy},
      ];
      await p.setString(_noteKey, jsonEncode(l));
    } catch (err) {
      AppLog.w('events._saveNotes', 'yutulan hata', err);
    }
  }

  /// Menuye donuste biten etkinlik bildirimleri (tek seferlik; bos olabilir).
  Future<List<EventNote>> takeNotes() async {
    _rollAll();
    final mem = List<EventNote>.of(_pending);
    _pending.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_noteKey);
      if (raw != null) await p.remove(_noteKey);
      if (mem.isNotEmpty) return mem;
      if (raw == null || raw.isEmpty) return const [];
      final out = <EventNote>[];
      for (final e in (jsonDecode(raw) as List)) {
        if (e is! Map) continue;
        int n(String k) => (e[k] as num?)?.toInt() ?? 0;
        out.add(EventNote('${e['i'] ?? ''}', n('k'), PlanetReward(coins: n('c'), gems: n('g'), energy: n('e'))));
      }
      return out;
    } catch (err) {
      AppLog.w('events.takeNotes', 'yutulan hata', err);
      return mem;
    }
  }

  // ------------------------------------------------------------ botlar
  static int _mix(int a, int bot, int hour) =>
      ((a * 1000003) ^ (bot * 7919) ^ (hour * 104729) ^ 0x5bd1e995) & 0x7fffffff;

  // Gun ritmi: saat (0-23) basina uyanik olma carpani; ortalamasi 1.0'a normalize edilir
  // (ekonomi/siralama dagilimi degismesin). Gece 2-5 arasi cok dusuk, aksam 19-22 en yogun.
  static const List<double> _diurnalRaw = [
    0.45, 0.30, 0.20, 0.18, 0.18, 0.28, 0.55, 0.85, 1.00, 1.05, 1.05, 1.10,
    1.10, 1.05, 1.00, 1.00, 1.05, 1.10, 1.20, 1.30, 1.35, 1.30, 1.15, 0.75,
  ];
  static final List<double> _diurnal = _normDiurnal();
  static List<double> _normDiurnal() {
    var sum = 0.0;
    for (final v in _diurnalRaw) {
      sum += v;
    }
    final mean = sum / _diurnalRaw.length;
    return [for (final v in _diurnalRaw) v / mean];
  }

  /// Botun saat dilimi kaymasi (saat): cogu oyuncu yakin saat diliminde (-2..+2), kalani dunyanin her yerinde.
  /// Saf fonksiyon (tohum + bot indeksi).
  static int tzShiftFor(int seed, int bot) {
    final r = math.Random(_mix(seed ^ 0x7A11, bot, 5));
    return r.nextDouble() < 0.82 ? r.nextInt(5) - 2 : r.nextInt(24);
  }

  /// Bir botun bu saatteki hizi (puan/saat). Saf fonksiyon: ayni girdi = ayni sonuc.
  /// [awakeAdj]: botun kisiligi (uyanik olma olasiligina eklenir; varsayilan 0 = eski davranis).
  /// [startHour]: kosunun basladigi saat (0-23); [tz]: botun saat dilimi kaymasi (null = tohumdan hesaplanir).
  /// v218: uyanik olma olasiligi GUN RITMINE bagli (gece az, aksam cok) ve OTURUM KUMELI:
  /// 3 saatlik blok acik degilse o blokta oynamaz, aciksa saatler yine tek tek secilir. Toplam
  /// olasilik hala (awakeChance + awakeAdj) ile ayni (gun ritmi ortalamasi 1.0).
  static double hourRate(int seed, int bot, int hour, double speed, BotSpec b,
      {double awakeAdj = 0.0, int startHour = 0, int? tz}) {
    final shift = tz ?? tzShiftFor(seed, bot);
    final hod = (hour + startHour + shift) % 24; // Dart: % her zaman >= 0
    final p = ((b.awakeChance + awakeAdj) * _diurnal[hod]).clamp(0.05, 1.0).toDouble();
    final pBlock = math.min(1.0, p * 1.4);
    final pHour = p / pBlock;
    final rb = math.Random(_mix(seed ^ 0x51ED27, bot, hour ~/ 3)).nextDouble();
    final r = math.Random(_mix(seed, bot, hour));
    final rh = r.nextDouble();
    final burst = r.nextDouble() < b.burstChance ? b.burstMul : 1.0;
    final tempo = 0.5 + r.nextDouble(); // 0.5 .. 1.5
    final awake = rb < pBlock && rh < pHour;
    return awake ? speed * burst * tempo : 0.0;
  }

  /// Saatin [part] (0..1) kadarlik kismi icin birikmis oran 0..1. Saat 4 ceyrege bolunur, ceyreklerden
  /// bazilari "bos" kalir: puan dakika dakika duz akmaz, oyuncudaki gibi kumeler halinde artar.
  /// Azalmaz; part >= 1 icin tam 1.0.
  static double _withinHour(int seed, int bot, int hour, double part) {
    if (part >= 1.0) return 1.0;
    if (part <= 0.0) return 0.0;
    final r = math.Random(_mix(seed ^ 0x2545F4, bot, hour));
    final w = List<double>.generate(4, (_) => r.nextDouble() < 0.6 ? 0.4 + r.nextDouble() : 0.0);
    var sum = w[0] + w[1] + w[2] + w[3];
    if (sum <= 0.0) {
      w[r.nextInt(4)] = 1.0;
      sum = 1.0;
    }
    final x = part * 4.0;
    var acc = 0.0;
    for (var q = 0; q < 4; q++) {
      acc += w[q] * (x - q).clamp(0.0, 1.0).toDouble();
    }
    return acc / sum;
  }

  /// Bir saatin [part] kadarlik kismindaki puan. part >= 1 icin TAM [hourRate] (tahta ve [botScoreAt] ayni sonucu verir).
  static double hourAmount(int seed, int bot, int hour, double speed, BotSpec b,
      {double awakeAdj = 0.0, int startHour = 0, int? tz, double part = 1.0}) {
    final rate = hourRate(seed, bot, hour, speed, b, awakeAdj: awakeAdj, startHour: startHour, tz: tz);
    if (rate <= 0.0 || part >= 1.0) return part <= 0.0 ? 0.0 : rate;
    return rate * _withinHour(seed, bot, hour, part);
  }

  /// Botun, kosunun basindan [elapsed] sure sonraki puani (azalmaz).
  static int botScoreAt(int seed, int bot, double speed, Duration elapsed, BotSpec b,
      {double awakeAdj = 0.0, int startHour = 0}) {
    final mins = elapsed.inMinutes;
    if (mins <= 0) return 0;
    final full = mins ~/ 60;
    final rem = (mins % 60) / 60.0;
    final tz = tzShiftFor(seed, bot);
    var total = 0.0;
    for (var h = 0; h <= full; h++) {
      final part = h < full ? 1.0 : rem;
      if (part <= 0) continue;
      total += hourAmount(seed, bot, h, speed, b, awakeAdj: awakeAdj, startHour: startHour, tz: tz, part: part);
    }
    return total.floor();
  }

  /// Bu cihazin bot tohumu (kurulumda bir kez uretilir, kalici). 0 = tohum yok (testler / henuz yuklenmedi).
  /// Farkli cihazlar ayni isim/puan listesini GORMEZ (ekran goruntusu karsilastirinca bot oldugu anlasilmasin).
  static int botSalt = 0;
  static const String _kBotSalt = 'bot_salt_v1';

  /// Uygulama acilisinda [load]'dan ONCE cagrilir.
  static Future<void> initBotSalt() async {
    try {
      final p = await SharedPreferences.getInstance();
      var v = p.getInt(_kBotSalt);
      if (v == null || v <= 0) {
        v = 1 + math.Random().nextInt(0x3fffffff);
        await p.setInt(_kBotSalt, v);
      }
      botSalt = v;
    } catch (e) {
      AppLog.w('events', 'bot tohumu okunamadi/yazilamadi: $e');
    }
  }

  static int _runSeed(EventDef d, int run) => (d.seed * 31 + run + botSalt) & 0x7fffffff;

  /// Bu kosunun bot hizlari: tabloya kosuya ozgu +-%15 oynama + Remote Config yuzdesi
  /// (anahtar: ev_<id>_bot_pct, 100 = varsayilan).
  static List<double> botSpeedsFor(EventDef d, int run) {
    final b = d.bots;
    if (b == null) return const [];
    final mul = RemoteTuning.i('ev_${d.id}_bot_pct', 100) / 100.0;
    final r = math.Random(_mix(_runSeed(d, run), 99, 0));
    return [for (var i = 0; i < b.count; i++) b.baseSpeed(i) * (0.85 + r.nextDouble() * 0.30) * mul];
  }

  /// Bu kosunun bot kimlikleri: isim (karisik dil/stil), avatar, seviye, kisilik. Tohumlu, tekrarsiz.
  static List<BotProfile> botProfilesFor(EventDef d, int run) {
    final b = d.bots;
    if (b == null) return const [];
    final seed = _runSeed(d, run);
    final used = <String>{};
    final n = b.count;
    // Hiz sirasi (0 = en yavas .. 1 = en hizli): seviye hizla birlikte artsin.
    final byFast = List<int>.generate(n, (i) => i)..sort((x, y) => b.baseSpeed(x).compareTo(b.baseSpeed(y)));
    final fast01 = List<double>.filled(n, 1.0);
    for (var pos = 0; pos < n; pos++) {
      fast01[byFast[pos]] = n <= 1 ? 1.0 : pos / (n - 1);
    }
    return [
      for (var i = 0; i < n; i++)
        BotIdentity.make(math.Random(_mix(seed, 77, i + 1)), used,
            minLevel: GameProgress.eventUnlockLevel, fast01: fast01[i]),
    ];
  }

  /// Bu kosunun bot isimleri (tohumlu, tekrarsiz).
  static List<String> botNamesFor(EventDef d, int run) => [for (final p in botProfilesFor(d, run)) p.name];

  // Kosu basina bir tahta: kimlik/hiz bir kez uretilir, puanlar DAKIKADA bir yenilenir (1500 bot icin sart).
  final Map<String, _BotBoard> _boards = {};

  _BotBoard _boardAt(EventDef d, int run, Duration elapsed) {
    final b = d.bots!;
    final pct = RemoteTuning.i('ev_${d.id}_bot_pct', 100);
    final key = '${d.id}|$run|$pct|${identityHashCode(b)}';
    var board = _boards[key];
    if (board == null) {
      if (_boards.length >= 4) _boards.clear();
      board = _BotBoard(botSpeedsFor(d, run), botProfilesFor(d, run), _runSeed(d, run), b,
          startHour: d.startOfRun(run).hour);
      _boards[key] = board;
    }
    board.update(elapsed.inMinutes);
    return board;
  }

  /// Acik kosunun bot tahtasi (botsuz / kapali / oyuncu kosusu henuz yoksa null).
  _BotBoard? _currentBoard(EventDef d) {
    _roll(d);
    final st = _ev(d.id);
    final run = d.runIdAt(_now());
    if (d.bots == null || run == null || st.run != run) return null;
    final span = d.endOfRun(run).difference(d.startOfRun(run));
    final elapsed = _now().difference(d.startOfRun(run));
    return _boardAt(d, run, elapsed > span ? span : elapsed);
  }

  // ------------------------------------------------------------ sorgular
  bool isActive(EventDef d) => d.runIdAt(_now()) != null;

  List<EventDef> get activeDefs => [for (final d in defs) if (isActive(d)) d];

  /// Acik olmayan etkinliklerden en yakin baslayacak olan (yoksa null).
  EventDef? get nextUpcoming {
    final n = _now();
    EventDef? best;
    DateTime? bestStart;
    for (final d in defs) {
      if (isActive(d)) continue;
      final r = d.nextRunAfter(n);
      if (r < 0) continue;
      final s = d.startOfRun(r);
      if (bestStart == null || s.isBefore(bestStart)) {
        best = d;
        bestStart = s;
      }
    }
    return best;
  }

  /// Acikken: bitisine kalan; kapaliyken: baslamasina kalan.
  Duration timeLeft(EventDef d) {
    final n = _now();
    final run = d.runIdAt(n);
    if (run != null) return d.endOfRun(run).difference(n);
    final next = d.nextRunAfter(n);
    return next < 0 ? Duration.zero : d.startOfRun(next).difference(n);
  }

  int score(EventDef d) {
    _roll(d);
    return _ev(d.id).score;
  }

  /// Acik etkinligin guncel siralamasi (botsuz ya da kapaliysa bos). [playerName] ekranda "Sen" icin.
  /// [limit] verilirse yalnizca ilk [limit] satir doner (1500 satirin hepsini her saniye uretme!).
  /// Oyuncu ilk [limit] icinde degilse listede YOK; onun sirasi icin [rank] kullan.
  List<RaceStanding> standings(EventDef d, {String playerName = '', int? limit}) {
    final board = _currentBoard(d);
    if (board == null) return const [];
    return board.rows(_ev(d.id).score, playerName, limit);
  }

  /// Oyuncunun sirasi (1 tabanli). Puani 0 ise en sonda (bot sayisi + 1). Etkinlik yoksa 0.
  int rank(EventDef d) {
    final board = _currentBoard(d);
    return board == null ? 0 : board.rankOf(_ev(d.id).score);
  }

  /// Siralamadaki toplam kisi (botlar + oyuncu); etkinlik yoksa 0.
  int totalRacers(EventDef d) {
    final board = _currentBoard(d);
    return board == null ? 0 : board.count + 1;
  }

  /// Bir ust siraya gecmek icin gereken puan (1. isen ya da etkinlik yoksa null).
  int? pointsToNextRank(EventDef d) {
    final board = _currentBoard(d);
    if (board == null) return null;
    return board.pointsToNext(_ev(d.id).score);
  }

  /// Ilk [top] icine girmek icin gereken puan (zaten iceridesen ya da etkinlik yoksa null).
  int? pointsToEnter(EventDef d, int top) {
    final board = _currentBoard(d);
    if (board == null) return null;
    return board.pointsToEnter(_ev(d.id).score, top);
  }

  // ------------------------------------------------------------ ilerleme
  /// Oyun bir olay bildirdiginde cagrilir. O metrigi sayan, su an ACIK tum etkinliklere eklenir.
  void report(String metric, int amount) {
    if (amount <= 0 || !unlocked()) return;
    var changed = false;
    for (final d in defs) {
      if (d.metric != metric) continue;
      _roll(d);
      if (!isActive(d)) continue;
      final st = _ev(d.id);
      if (st.run < 0) continue;
      st.score += amount;
      changed = true;
    }
    if (changed) _persist();
  }

  // ------------------------------------------------------------ hedefler
  bool isClaimed(EventDef d, int i) {
    _roll(d);
    return _ev(d.id).claimed.contains(i);
  }

  bool canClaim(EventDef d, int i) {
    _roll(d);
    final st = _ev(d.id);
    if (!isActive(d) || st.run < 0) return false;
    return i >= 0 && i < d.goals.length && st.score >= d.goals[i].target && !st.claimed.contains(i);
  }

  bool hasClaimable(EventDef d) {
    for (var i = 0; i < d.goals.length; i++) {
      if (canClaim(d, i)) return true;
    }
    return false;
  }

  /// Menudeki ikonda rozet: herhangi bir acik etkinlikte alinacak hedef odulu var.
  bool get hasBadge {
    if (!unlocked()) return false;
    for (final d in defs) {
      if (hasClaimable(d)) return true;
    }
    return false;
  }

  PlanetReward? claim(EventDef d, int i) {
    if (!canClaim(d, i)) return null;
    final st = _ev(d.id);
    st.claimed.add(i);
    final r = d.goals[i].reward;
    deliver(r, 'event_goal');
    AppLog.i('events', 'HEDEF ODULU ${d.id} hedef=${d.goals[i].target} coin=${r.coins} elmas=${r.gems} enerji=${r.energy}');
    AnalyticsService.instance.log('event_claim', {'id': d.id, 'i': i});
    unawaited(save());
    onSaved?.call();
    return r;
  }

  /// Siralama odulu (ekranda gostermek icin). [rank] 1 tabanli.
  /// Liste disindaki sira: [EventDef.restGetsLast] ise son odul, degilse odul yok.
  static PlanetReward rankReward(EventDef d, int rank) {
    if (d.rankRewards.isEmpty) return const PlanetReward();
    final r = rank < 1 ? 1 : rank;
    if (r > d.rankRewards.length) return d.restGetsLast ? d.rankRewards.last : const PlanetReward();
    return d.rankRewards[r - 1];
  }

  // ------------------------------------------------------------ kalicilik
  /// DUZ yapi: '<id>.r', '<id>.s', '<id>.dr', '<id>.cl' (bkz. SaveMerge.liveEvents).
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    _st.forEach((id, st) {
      if (st.run < 0 && st.delivered < 0) return;
      out['$id.r'] = st.run;
      out['$id.s'] = st.score;
      out['$id.dr'] = st.delivered;
      out['$id.cl'] = st.claimed.toList()..sort();
    });
    return out;
  }

  void applyJson(Map<String, dynamic> j) {
    _st.clear();
    j.forEach((k, v) {
      final dot = k.lastIndexOf('.');
      if (dot <= 0) return;
      final id = k.substring(0, dot);
      final f = k.substring(dot + 1);
      final st = _ev(id);
      switch (f) {
        case 'r':
          st.run = (v as num?)?.toInt() ?? -1;
          break;
        case 's':
          st.score = (v as num?)?.toInt() ?? 0;
          break;
        case 'dr':
          st.delivered = (v as num?)?.toInt() ?? -1;
          break;
        case 'cl':
          st.claimed
            ..clear()
            ..addAll((v as List? ?? const []).whereType<num>().map((e) => e.toInt()));
          break;
      }
    });
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        applyJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      AppLog.i('events.load', 'yuklendi etkinlik=${_st.length}');
    } catch (err) {
      AppLog.w('events.load', 'yutulan hata', err);
    }
    _rollAll();
  }

  /// Bulut esitlemesinin icinden de cagrilir: bu yuzden onSaved TETIKLEMEZ.
  Future<void> save() async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (err) {
      AppLog.w('events.save', 'yutulan hata', err);
    }
  }

  /// Oyun akisindan gelen degisiklikler: kisa gecikmeyle yazar ve buluta yuklemeyi tetikler.
  void _persist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      await save();
      onSaved?.call();
    });
  }

  /// Ekrandan cikarken bekleyen yazimi hemen yap.
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      await save();
      onSaved?.call();
    }
  }

  /// Test: durumu sifirla.
  void resetForTest() {
    _debounce?.cancel();
    _st.clear();
    _pending.clear();
    _rawCached = null;
    _defsCached = defaultDefs;
  }
}
