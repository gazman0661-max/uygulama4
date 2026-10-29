import 'dart:convert';
import 'dart:math' as math;

import 'log_service.dart';
typedef Json = Map<String, dynamic>;
typedef Stores = Map<String, Json>;

/// IKI CIHAZ BIRLESTIRME MANTIGI (saf Dart, Flutter'a bagimli degil -> test edilebilir).
///
/// Eski sistem tum kaydi "hangi bolum ileride" diye karsilastirip TEK PARCA
/// uzerine yaziyordu: A cihazinda harcanan/kazanilan mucevher, B cihazindaki
/// eski kayitla ezilebiliyordu. Burada 3'lu birlestirme (three-way merge) var:
///
///   base  = bu cihazin bulutla son BASARILI esitlendigi hali
///   local = su anki yerel hal
///   cloud = bulutta duran hal
///
/// Alan turune gore kural:
///  - Para/sayac (coins, gems, booster, sezon puani...):  cloud + (local - base)
///    -> A'da 100 mucevher harcandi, B'de 50 kazanildi => ikisi de korunur.
///  - Yalnizca artan seviyeler (bolum, yukseltme, bina seviyesi): max
///  - Tek seferlik satin almalar / alinmis oduller: VEYA / birlesim (asla kapanmaz)
///  - Gunluk/haftalik/aylik gruplar: ayni donemse birlestir, degilse yeni donem kazanir
///  - Ses/muzik/titresim: cihaza ozel, hic senkronlanmaz
///  - Diger: son degistiren kazanir (base'e gore degisen taraf)
class SaveMerge {
  SaveMerge._();

  /// "Simdi" kaynagi. main.dart bunu TimeService.instance.now'a baglar (sunucuya bagli saat):
  /// reklam bekleme suresi gibi kontroller cihaz saati oynansa da ayni sonucu versin.
  /// Testte degistirilebilir; varsayilan cihaz saati (saf Dart kalir).
  static DateTime Function() clock = DateTime.now;

  static const String kProgress = 'game_progress_v1';
  static const String kSeason = 'season_v1';
  static const String kPiggy = 'piggy_v1';
  static const String kEvents = 'events_v1';
  static const String kEngage = 'engage_v1';
  static const String kInvite = 'invite_v1';
  // Mod 2 (Merge Tahtasi): MergeBoardService'in SharedPreferences anahtariyla AYNI olmali.
  static const String kMergeBoard = 'mb_state_v1';
  // Mod 2 gorevleri: MbMissions'in SharedPreferences anahtariyla AYNI olmali.
  static const String kMbMissions = 'mb_missions_v1';
  // Hafta sonu etkinligi (Gezegen Birlestir): PlanetEvent'in anahtariyla AYNI olmali.
  static const String kPlanetEvent = 'planet_event_v1';
  // Canli etkinlikler (botlu yaris vb.): LiveEvents'in anahtariyla AYNI olmali. DUZ yapi: '<id>.r/.s/.dr/.cl'.
  static const String kLiveEvents = 'live_events_v1';

  static const List<String> keys = [kProgress, kSeason, kPiggy, kEvents, kEngage, kInvite, kMergeBoard, kMbMissions, kPlanetEvent, kLiveEvents];
  static const List<String> otherKeys = [kSeason, kPiggy, kEvents, kEngage, kInvite, kMergeBoard, kMbMissions, kPlanetEvent, kLiveEvents];

  /// Toplamsal (delta ile birlestirilen) alanlar.
  static const Map<String, List<String>> additive = {
    kProgress: ['coins', 'gems', 'boosterAim', 'boosterJoker', 'boosterRevive', 'boosterHammer', 'boosterUpgrade', 'boosterFan'],
    kSeason: ['points'],
    kPiggy: ['gems'],
    kEvents: ['points'],
    kPlanetEvent: ['tm', 'g', 'ts'], // toplam birlestirme + oynanan oyun + toplam puan: delta ile toplanir
  };

  /// Cihaza ozel ayarlar: bulutla tasinmaz.
  static const List<String> deviceLocal = ['soundEnabled', 'musicEnabled', 'hapticsEnabled', 'screenFxEnabled'];

  // ------------------------------------------------------------ yardimcilar

  static int _n(Map? m, String k) {
    final v = m?[k];
    return v is num ? v.toInt() : 0;
  }

  static DateTime? _d(dynamic v) => v is String ? DateTime.tryParse(v) : null;

  static List<dynamic> _list(dynamic v) => v is List ? v : const <dynamic>[];

  static int _at(List<dynamic> l, int i) {
    if (i >= l.length) return 0;
    final v = l[i];
    return v is num ? v.toInt() : 0;
  }

  static dynamic _elem(List<dynamic> l, int i) => i < l.length ? l[i] : 0;

  /// Sirasiz derin esitlik.
  static bool deepEq(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Toplamsal alan: base varsa cloud + (local - base); yoksa max (hicbir sey kaybolmaz).
  static int _add(Json? b, Json l, Json c, String k) {
    final lv = _n(l, k);
    final cv = _n(c, k);
    final r = b == null ? math.max(lv, cv) : cv + (lv - _n(b, k));
    return r < 0 ? 0 : r;
  }

  static List<dynamic> _union(dynamic a, dynamic b) {
    final s = <dynamic>{..._list(a), ..._list(b)};
    return s.toList();
  }

  static dynamic _scalar(dynamic a, dynamic b) {
    if (a is bool || b is bool) return a == true || b == true;
    if (a is num && b is num) return math.max(a, b);
    if (a is List && b is List) {
      // Eleman eleman en buyuk (ornegin missionDayAddW: [x, y, z]).
      final n = math.max(a.length, b.length);
      return List<dynamic>.generate(n, (i) {
        final x = i < a.length ? a[i] : 0;
        final y = i < b.length ? b[i] : 0;
        return (x is num && y is num) ? math.max(x, y) : (y ?? x);
      });
    }
    return b ?? a;
  }

  /// Tarihli grup: tarih ayniysa alanlar birlestirilir (VEYA / max); farkliysa
  /// daha yeni tarihli taraf komple kazanir.
  static void _dated(Json out, Set<String> handled, Json l, Json c, String dateKey, List<String> fields) {
    final all = <String>[dateKey, ...fields];
    handled.addAll(all);
    final ld = _d(l[dateKey]);
    final cd = _d(c[dateKey]);
    if (ld != null && cd != null && ld.isAtSameMomentAs(cd)) {
      out[dateKey] = c[dateKey];
      for (final f in fields) {
        if (l.containsKey(f) || c.containsKey(f)) out[f] = _scalar(l[f], c[f]);
      }
      return;
    }
    final localWins = ld != null && (cd == null || ld.isAfter(cd));
    final s = localWins ? l : c;
    for (final k in all) {
      if (s.containsKey(k)) out[k] = s[k];
    }
  }

  /// Reklam hak sayaci (kullanilan hak + 3./5. izlemede baslayan bekleme sayaci).
  /// Sayac henuz baslamamisken (ornegin 1/3 izlendi) tarih ikisinde de null olur;
  /// eski _dated mantigi bu durumda bulutu kazandirip izlenen reklami SILIYORDU.
  /// Burada suresi dolmus taraf "0 kullanildi" sayilir.
  ///  - [b] (base) varsa ve iki taraf da base'in altina inmediyse: kullanilan hak DELTA ile toplanir
  ///    (iki cihazda birer reklam = 2 hak); yoksa cok kullanilan taraf kazanir.
  ///  - Toplam [cap]'e ulasir ve sayac yoksa, bekleme sayaci SIMDI baslar.
  /// Saat: [clock] (TimeService'e bagli) - cihaz saati degil.
  static void _quota(Json out, Set<String> handled, Json? b, Json l, Json c, String dateKey, String usedKey, Duration cooldown, int cap) {
    handled.addAll([dateKey, usedKey]);
    final now = clock();
    bool expired(DateTime d) => !d.isAfter(now) && now.difference(d) >= cooldown;
    int usedOf(Json j) {
      final d = _d(j[dateKey]);
      if (d != null && expired(d)) return 0; // suresi dolmus
      final u = j[usedKey];
      return u is num ? u.toInt() : 0;
    }

    DateTime? dateOf(Json j) {
      final d = _d(j[dateKey]);
      if (d == null || expired(d)) return null;
      return d;
    }

    final lu = usedOf(l);
    final cu = usedOf(c);
    final ld = dateOf(l);
    final cd = dateOf(c);
    var usedWins = lu >= cu ? lu : cu;
    if (b != null) {
      final bu = usedOf(b);
      if (lu >= bu && cu >= bu) usedWins = cu + (lu - bu); // iki taraf da gercekten artti: topla
    }
    if (usedWins > cap) usedWins = cap;
    DateTime? date;
    String? dateRaw;
    if (ld != null && cd != null) {
      date = ld.isBefore(cd) ? ld : cd; // en erken baslayan sayac
      dateRaw = (date == ld ? l[dateKey] : c[dateKey]) as String?;
    } else if (ld != null) {
      date = ld;
      dateRaw = l[dateKey] as String?;
    } else if (cd != null) {
      date = cd;
      dateRaw = c[dateKey] as String?;
    }
    if (date == null && usedWins >= cap) {
      dateRaw = now.toIso8601String(); // haklar bitti ama sayac yok: bekleme simdi baslar
    }
    out[usedKey] = usedWins;
    out[dateKey] = dateRaw;
  }

  /// "Gun anahtari" ('2026-10-29' gibi, GameProgress._todayKey) -> tarih. Cozulemezse null.
  static DateTime? _dayOf(dynamic v) {
    if (v is! String) return null;
    final p = v.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Gunluk sayac grubu: ayni gunse alanlar birlestirilir (sayi: max, harita: anahtar bazinda max);
  /// farkliysa DAHA YENI gunun tarafi komple kazanir. (Gun ile sayac ayri ayri
  /// birlesince tutarsiz oluyordu: gun bir cihazdan, sayac digerinden.)
  static void _dayGroup(Json out, Set<String> handled, Json l, Json c, String dayKey, List<String> fields) {
    final all = <String>[dayKey, ...fields];
    handled.addAll(all);
    final ld = _dayOf(l[dayKey]);
    final cd = _dayOf(c[dayKey]);
    if (ld != null && cd != null && ld == cd) {
      out[dayKey] = c[dayKey];
      for (final f in fields) {
        final lv = l[f];
        final cv = c[f];
        if (lv is Map || cv is Map) {
          final m = <String, dynamic>{};
          for (final src in [cv, lv]) {
            if (src is Map) {
              src.forEach((k, v) {
                final nv = v is num ? v.toInt() : 0;
                final old = m['$k'] is int ? m['$k'] as int : 0;
                m['$k'] = math.max(old, nv);
              });
            }
          }
          out[f] = m;
        } else if (l.containsKey(f) || c.containsKey(f)) {
          out[f] = math.max(_n(l, f), _n(c, f));
        }
      }
      return;
    }
    final localWins = ld != null && (cd == null || ld.isAfter(cd));
    final s = localWins ? l : c;
    for (final k in all) {
      if (s.containsKey(k)) out[k] = s[k];
    }
  }

  /// Son degistiren kazanir: base'e gore yerelde degisen grup yerelden, aksi halde buluttan.
  static void _lww(Json out, Set<String> handled, Json? b, Json l, Json c, List<String> ks) {
    handled.addAll(ks);
    final changed = b != null && ks.any((k) => !deepEq(b[k], l[k]));
    final s = changed ? l : c;
    for (final k in ks) {
      if (s.containsKey(k)) out[k] = s[k];
    }
  }

  // ------------------------------------------------------------ ana giris

  /// Tum depolari birlestirir. [base] null olabilir (bu cihaz hic esitlenmedi).
  static Stores all(Stores? base, Stores local, Stores cloud) {
    final out = <String, Json>{};
    for (final k in keys) {
      final Json? l = local[k];
      final Json? c = cloud[k];
      if (l == null && c == null) continue;
      if (c == null) {
        out[k] = l!;
        continue;
      }
      if (l == null) {
        out[k] = c;
        continue;
      }
      final Json? b = base?[k];
      switch (k) {
        case kProgress:
          out[k] = progress(b, l, c);
          break;
        case kSeason:
          out[k] = season(b, l, c);
          break;
        case kPiggy:
          out[k] = piggy(b, l, c);
          break;
        case kEvents:
          out[k] = events(b, l, c);
          break;
        case kInvite:
          out[k] = invite(b, l, c);
          break;
        case kMergeBoard:
          out[k] = mergeBoard(b, l, c);
          break;
        case kMbMissions:
          out[k] = mbMissions(l, c);
          break;
        case kPlanetEvent:
          out[k] = planetEvent(b, l, c);
          break;
        case kLiveEvents:
          out[k] = liveEvents(b, l, c);
          break;
        default:
          out[k] = engage(b, l, c);
      }
    }
    return out;
  }

  // ------------------------------------------------------------ ilerleme

  static Json progress(Json? b, Json l, Json c) {
    final out = <String, dynamic>{};
    final handled = <String>{};

    // Para / sayaclar: delta birlestirme.
    for (final k in additive[kProgress]!) {
      handled.add(k);
      if (l.containsKey(k) || c.containsKey(k)) out[k] = _add(b, l, c, k);
    }

    // Yalnizca artan seviyeler.
    for (final k in const [
      'maxUnlockedChapter',
      'throwCooldownLevel',
      'luckLevel',
      'extraOrderSlotLevel',
      'slotRefundV1',
      'townMilestoneIdx',
      'builders',
    ]) {
      handled.add(k);
      if (l.containsKey(k) || c.containsKey(k)) out[k] = math.max(_n(l, k), _n(c, k));
    }

    // Sureli baslangic teklifi: iki cihazdan EN ERKEN baslangic gecerli (sure sifirlanmasin).
    handled.add('starterOfferStart');
    final ls = l['starterOfferStart'] as String?;
    final cs = c['starterOfferStart'] as String?;
    if (ls != null && cs != null) {
      out['starterOfferStart'] = ls.compareTo(cs) <= 0 ? ls : cs;
    } else if (ls != null || cs != null) {
      out['starterOfferStart'] = ls ?? cs;
    }

    // Tek seferlik satin almalar / tamamlanan oduller: asla geri kapanmaz.
    for (final k in const ['starterPackBought', 'albumCompleteClaimed']) {
      handled.add(k);
      if (l.containsKey(k) || c.containsKey(k)) out[k] = l[k] == true || c[k] == true;
    }
    for (final k in const ['albumDiscovered', 'albumClaimedSets', 'tutSeen']) {
      handled.add(k);
      if (l.containsKey(k) || c.containsKey(k)) out[k] = _union(l[k], c[k]);
    }

    // Bolum yildizlari: bolum bazinda max.
    handled.add('chapterStars');
    final lStars = l['chapterStars'];
    final cStars = c['chapterStars'];
    if (lStars is Map || cStars is Map) {
      final m = <String, dynamic>{};
      for (final src in [cStars, lStars]) {
        if (src is Map) {
          src.forEach((key, v) {
            final kk = '$key';
            final nv = v is num ? v.toInt() : 0;
            final old = m[kk] is int ? m[kk] as int : 0;
            m[kk] = math.max(old, nv);
          });
        }
      }
      out['chapterStars'] = m;
    }

    // Oyuncu seviyesi + XP: daha ileri olan taraf.
    handled.addAll(const ['playerLevel', 'playerXp']);
    final ll = _n(l, 'playerLevel');
    final cl = _n(c, 'playerLevel');
    final localHigher = ll > cl || (ll == cl && _n(l, 'playerXp') >= _n(c, 'playerXp'));
    final lv = localHigher ? l : c;
    if (lv.containsKey('playerLevel')) out['playerLevel'] = lv['playerLevel'];
    if (lv.containsKey('playerXp')) out['playerXp'] = lv['playerXp'];

    // Kasaba: bina seviyesi max; uretim/insaat verisi seviyesi yuksek taraftan,
    // esitse son degistirenden.
    handled.addAll(const ['townLevels', 'townStored', 'townLastMs', 'townUpgradeEnd']);
    final lt = _list(l['townLevels']);
    final ct = _list(c['townLevels']);
    final len = math.max(lt.length, ct.length);
    out['townLevels'] = List<dynamic>.generate(len, (i) => math.max(_at(lt, i), _at(ct, i)));
    for (final k in const ['townStored', 'townLastMs', 'townUpgradeEnd']) {
      final la = _list(l[k]);
      final ca = _list(c[k]);
      final ba = _list(b?[k]);
      out[k] = List<dynamic>.generate(len, (i) {
        final lvl = _at(lt, i);
        final cvl = _at(ct, i);
        if (lvl > cvl) return _elem(la, i);
        if (cvl > lvl) return _elem(ca, i);
        final localChanged = b != null && !deepEq(_elem(ba, i), _elem(la, i));
        return localChanged ? _elem(la, i) : _elem(ca, i);
      });
    }

    // Gunluk odul / gorevler / cark / reklam sayaclari: donem bazli.
    _dated(out, handled, l, c, 'lastDailyRewardClaim', const ['dailyStreak']);
    _dated(out, handled, l, c, 'missionsResetDate', const [
      'missionDeliverProgress',
      'missionRefCh',
      'missionMergeProgress',
      'missionCoinsProgress',
      'missionDeliverClaimed',
      'missionMergeClaimed',
      'missionCoinsClaimed',
    ]);
    _dated(out, handled, l, c, 'weeklyMissionsResetDate', const [
      'missionWeeklyDeliverProgress',
      'missionWeeklyRefCh',
      'missionWeeklyMergeProgress',
      'missionWeeklyCoinsProgress',
      'missionWeeklyDeliverClaimed',
      'missionWeeklyMergeClaimed',
      'missionWeeklyCoinsClaimed',
      'missionDayAddW',
    ]);
    _dated(out, handled, l, c, 'monthlyMissionsResetDate', const [
      'missionMonthlyDeliverProgress',
      'missionMonthlyRefCh',
      'missionMonthlyMergeProgress',
      'missionMonthlyCoinsProgress',
      'missionMonthlyDeliverClaimed',
      'missionMonthlyMergeClaimed',
      'missionMonthlyCoinsClaimed',
      'missionDayAddM',
    ]);
    _dated(out, handled, l, c, 'wheelDay', const ['wheelFreeUsed', 'wheelAdUsed']);
    _dated(out, handled, l, c, 'wheelLastFreeDay', const ['wheelStreak']);
    _quota(out, handled, b, l, c, 'adGemsCooldownStart', 'adGemsUsed', const Duration(hours: 2), 3); // GameProgress.adGemsPerWindow
    _quota(out, handled, b, l, c, 'energyAdCooldownStart', 'energyAdWatchesUsed', const Duration(hours: 2), 5); // GameProgress.maxEnergyAdWatches
    _dayGroup(out, handled, l, c, 'boosterAdDay', const ['boosterAdCount']);
    _dayGroup(out, handled, l, c, 'adQuotaDay', const ['adQuota']);

    // Enerji: son degistiren kazanir.
    _lww(out, handled, b, l, c, const ['energy', 'energyRegenStart']);

    // Cihaza ozel ayarlar + yarim kalan cark: hep yerel.
    for (final k in [...deviceLocal, 'wheelPending']) {
      handled.add(k);
      if (l.containsKey(k)) out[k] = l[k];
    }

    // Bilinmeyen/yeni alanlar: son degistiren kazanir.
    for (final k in <String>{...l.keys, ...c.keys}) {
      if (!handled.contains(k)) _lww(out, handled, b, l, c, [k]);
    }
    return out;
  }

  // ------------------------------------------------------------ diger depolar

  static Json season(Json? b, Json l, Json c) {
    final ls = _n(l, 'season');
    final cs = _n(c, 'season');
    if (ls != cs) return Map<String, dynamic>.of(ls > cs ? l : c);
    final sameB = (b != null && _n(b, 'season') == ls) ? b : null;
    final out = Map<String, dynamic>.of(c);
    out['points'] = _add(sameB, l, c, 'points');
    out['premium'] = l['premium'] == true || c['premium'] == true;
    out['free'] = _union(l['free'], c['free']);
    out['prem'] = _union(l['prem'], c['prem']);
    return out;
  }

  static Json piggy(Json? b, Json l, Json c) {
    final out = Map<String, dynamic>.of(c);
    out['gems'] = _add(b, l, c, 'gems');
    return out;
  }

  static Json events(Json? b, Json l, Json c) {
    final lw = _n(l, 'week');
    final cw = _n(c, 'week');
    if (lw != cw) return Map<String, dynamic>.of(lw > cw ? l : c);
    final sameB = (b != null && _n(b, 'week') == lw) ? b : null;
    final out = Map<String, dynamic>.of(c);
    out['points'] = _add(sameB, l, c, 'points');
    out['claimed'] = _union(l['claimed'], c['claimed']);
    return out;
  }

  /// Hafta sonu etkinligi (Gezegen Birlestir). Ayni haftaysa: sayaclar toplamsal (delta) ya da max,
  /// alinan oduller birlesim (alinmis odul geri acilmaz), enerji = DUSUK olan taraf (iki cihazda
  /// ayni enerji iki kez harcanmasin). Haftalar farkliysa yeni hafta komple kazanir.
  static Json planetEvent(Json? b, Json l, Json c) {
    final lw = _n(l, 'w');
    final cw = _n(c, 'w');
    if (lw != cw) return Map<String, dynamic>.of(lw > cw ? l : c);
    final sameB = (b != null && _n(b, 'w') == lw) ? b : null;
    final out = Map<String, dynamic>.of(c);
    for (final k in const ['tm', 'g', 'ts']) {
      out[k] = _add(sameB, l, c, k);
    }
    for (final k in const ['bt', 'bs', 'c6', 'ar']) {
      out[k] = math.max(_n(l, k), _n(c, k));
    }
    out['cl'] = _union(l['cl'], c['cl']);
    out['gc'] = l['gc'] == true || c['gc'] == true;
    final le = l.containsKey('e') ? _n(l, 'e') : 1 << 20;
    final ce = c.containsKey('e') ? _n(c, 'e') : 1 << 20;
    final src = le <= ce ? l : c;
    if (src.containsKey('e')) out['e'] = src['e'];
    if (src.containsKey('rs')) out['rs'] = src['rs'];
    return out;
  }

  /// Canli etkinlikler (DUZ yapi): her etkinlik icin '<id>.r' kosu, '<id>.s' puan, '<id>.dr' odulu verilen
  /// son kosu, '<id>.cl' alinan hedefler. Etkinlikler BAGIMSIZ birlesir; her biri icin [liveEvent] kurali.
  static Json liveEvents(Json? b, Json l, Json c) {
    Set<String> ids(Json m) => {
          for (final k in m.keys)
            if (k.lastIndexOf('.') > 0) k.substring(0, k.lastIndexOf('.')),
        };
    Json sub(Json? m, String id) {
      final o = <String, dynamic>{};
      if (m == null) return o;
      for (final f in const ['r', 's', 'dr', 'cl']) {
        if (m.containsKey('$id.$f')) o[f] = m['$id.$f'];
      }
      return o;
    }

    final out = <String, dynamic>{};
    for (final id in {...ids(l), ...ids(c)}) {
      final sl = sub(l, id);
      final sc = sub(c, id);
      final Json merged;
      if (sl.isEmpty) {
        merged = sc;
      } else if (sc.isEmpty) {
        merged = sl;
      } else {
        merged = liveEvent(b == null ? null : sub(b, id), sl, sc);
      }
      merged.forEach((f, v) => out['$id.$f'] = v);
    }
    return out;
  }

  /// Tek etkinlik: 'r' kosu kimligi (-1: yok), 's' puan, 'dr' odulu verilen son kosu, 'cl' alinan hedefler.
  /// Ayni kosuysa puan toplamsal (delta), alinanlar birlesim. Farkli kosuysa DAHA YENI kosu kazanir.
  /// 'dr' HER DURUMDA max (biten kosunun odulu iki cihazda iki kez verilmesin).
  static Json liveEvent(Json? b, Json l, Json c) {
    final lr = l.containsKey('r') ? _n(l, 'r') : -1;
    final cr = c.containsKey('r') ? _n(c, 'r') : -1;
    final dr = math.max(l.containsKey('dr') ? _n(l, 'dr') : -1, c.containsKey('dr') ? _n(c, 'dr') : -1);
    Json out;
    if (lr != cr) {
      out = Map<String, dynamic>.of(lr > cr ? l : c);
    } else {
      final sameB = (b != null && b.isNotEmpty && (b.containsKey('r') ? _n(b, 'r') : -1) == lr) ? b : null;
      out = Map<String, dynamic>.of(c);
      out['s'] = _add(sameB, l, c, 's');
      out['cl'] = _union(l['cl'], c['cl']);
    }
    out['dr'] = dr;
    return out;
  }

  static Json engage(Json? b, Json l, Json c) {
    final out = Map<String, dynamic>.of(c);
    final ld = _d(l['lastSeen']);
    final cd = _d(c['lastSeen']);
    if (ld != null && (cd == null || ld.isAfter(cd))) out['lastSeen'] = l['lastSeen'];
    out['welcomeClaimed'] = l['welcomeClaimed'] == true || c['welcomeClaimed'] == true;
    out['pendingAwayDays'] = math.min(_n(l, 'pendingAwayDays'), _n(c, 'pendingAwayDays'));
    return out;
  }

  /// Mod 2 (Merge Tahtasi): tahta + siparisler + enerji TEK parca; hucreleri iki cihaz
  /// arasinda birlestirmek anlamsiz. Daha ILERI olan taraf komple kazanir:
  /// (bolum, bolumdeki teslim, toplam teslim) buyuk olan. Esitse, base'e gore yerelde
  /// degisiklik varsa yerel, yoksa bulut. Coinler zaten 'progress' icinde toplamsal
  /// birlestirildigi icin kaybolmaz.
  /// Mod 2 gorevleri ({p: {id: ilerleme}, c: [alinan idler], d/w/m: donem baslangici}).
  /// Her donem (gunluk 'd_', haftalik 'w_', aylik 'm_') BAGIMSIZ birlesir:
  ///  - ayni donemse: ilerleme = max, alinanlar = birlesim (alinmis odul geri acilmaz);
  ///  - donemler farkliysa: daha yeni donemin tarafi komple kazanir.
  static Json mbMissions(Json l, Json c) {
    final lp = l['p'] is Map ? l['p'] as Map : const {};
    final cp = c['p'] is Map ? c['p'] as Map : const {};
    final lc = _list(l['c']).map((e) => '$e').toSet();
    final cc = _list(c['c']).map((e) => '$e').toSet();
    final outP = <String, dynamic>{};
    final outC = <String>{};
    final out = <String, dynamic>{};
    const periods = [
      ['d_', 'd'],
      ['w_', 'w'],
      ['m_', 'm'],
    ];
    for (final pr in periods) {
      final prefix = pr[0];
      final dateKey = pr[1];
      final ld = _d(l[dateKey]);
      final cd = _d(c[dateKey]);
      final same = ld != null && cd != null && ld.isAtSameMomentAs(cd);
      final localWins = ld != null && (cd == null || ld.isAfter(cd));
      if (ld != null || cd != null) out[dateKey] = (localWins ? l[dateKey] : c[dateKey]) ?? l[dateKey] ?? c[dateKey];
      Iterable<String> ids(Map m) => m.keys.map((e) => '$e').where((e) => e.startsWith(prefix));
      if (same) {
        for (final id in {...ids(lp), ...ids(cp)}) {
          outP[id] = math.max(_n(lp, id), _n(cp, id));
        }
        outC.addAll(lc.where((e) => e.startsWith(prefix)));
        outC.addAll(cc.where((e) => e.startsWith(prefix)));
      } else {
        final wp = localWins ? lp : cp;
        final wc = localWins ? lc : cc;
        for (final id in ids(wp)) {
          outP[id] = _n(wp, id);
        }
        outC.addAll(wc.where((e) => e.startsWith(prefix)));
      }
    }
    out['p'] = outP;
    out['c'] = outC.toList()..sort();
    return out;
  }

  static Json mergeBoard(Json? b, Json l, Json c) {
    final lr = mergeBoardRank(l);
    final cr = mergeBoardRank(c);
    for (var i = 0; i < lr.length; i++) {
      if (lr[i] != cr[i]) return _withBestProducers(Map<String, dynamic>.of(lr[i] > cr[i] ? l : c), l, c);
    }
    final changed = b != null && !deepEq(b, l);
    final w = Map<String, dynamic>.of(changed ? l : c);
    return _withBestProducers(w, l, c);
  }

  /// Uretici seviyeleri ('pl', zincir basina) YALNIZCA ARTAR ve coin ile satin alinir
  /// (coin zaten toplamsal birlesiyor). Tahtasi geride kalan cihazin yukseltmesi kaybolmasin
  /// diye zincir bazinda max alinir.
  static Json _withBestProducers(Json w, Json l, Json c) {
    final lp = _list(l['pl']);
    final cp = _list(c['pl']);
    if (lp.isEmpty && cp.isEmpty) return w;
    final len = math.max(lp.length, cp.length);
    final best = List<dynamic>.generate(len, (i) => math.max(_at(lp, i), _at(cp, i)));
    if (!deepEq(best, w['pl'])) {
      AppLog.i('cloud', 'birlestirme: uretici seviyeleri korundu $lp + $cp -> $best');
    }
    w['pl'] = best;
    return w;
  }

  /// [bolum, bolumdeki teslim, toplam teslim]. Eski kayit (6 tahtali liste) en ilerisini alir.
  static List<int> mergeBoardRank(Json s) {
    List<int> one(dynamic m) {
      if (m is! Map) return const [0, 0, 0];
      final d = _n(m, 'd');
      var ch = _n(m, 'ch');
      final cp = _n(m, 'cp');
      if (ch < 1) ch = 1; // eski kayit: bolum yok
      return [ch, cp, d];
    }

    final b = s['b'];
    if (b is List) {
      var best = const <int>[0, 0, 0];
      for (final x in b) {
        final r = one(x);
        for (var i = 0; i < 3; i++) {
          if (r[i] != best[i]) {
            if (r[i] > best[i]) best = r;
            break;
          }
        }
      }
      return best;
    }
    return one(b);
  }

  /// Gelen kutusu / davet kimligi (playerId + token + davet kodu). Iki farkli kimlik varsa
  /// daha ESKI olan (ilk kurulumdaki) kazanir: yeniden kurulumda otomatik acilan yeni kimlik
  /// bulutta duran asil kimligi ezmez. "Islendi" listesi (verilmis oduller) birlesir.
  static Json invite(Json? b, Json l, Json c) {
    bool has(Json m) => m['playerId'] is String && m['token'] is String && _n(m, 'createdAt') > 0;
    final Json pick;
    if (has(l) && has(c)) {
      pick = _n(l, 'createdAt') <= _n(c, 'createdAt') ? l : c;
    } else if (has(c)) {
      pick = c;
    } else {
      pick = l;
    }
    final out = Map<String, dynamic>.of(pick);
    out['processed'] = _union(l['processed'], c['processed']);
    return out;
  }

  // ------------------------------------------------------------ yeniden dayama

  /// Birlestirme sirasinda (ag turu ~1 sn) oyuncu bir sey kazandi/harcadiysa
  /// bu degisikligi birlestirilmis sonucun ustune ekler. [l1] birlestirmeye
  /// girdigimiz yerel hal, [l2] uygulama anindaki yerel hal.
  static Json rebase(String store, Json m, Json l1, Json l2) {
    final out = Map<String, dynamic>.of(m);
    final add = additive[store] ?? const <String>[];
    for (final k in l2.keys) {
      if (store == kProgress && deviceLocal.contains(k)) {
        out[k] = l2[k];
        continue;
      }
      if (deepEq(l1[k], l2[k])) continue;
      if (store == kInvite && k == 'processed') {
        out[k] = _union(m[k], l2[k]); // verilmis oduller asla geri alinmaz
        continue;
      }
      // Alinmis oduller (liste/bayrak) eslesme sirasinda degistiyse geri alinmaz: birlesim.
      if ((store == kSeason && (k == 'free' || k == 'prem')) ||
          (store == kEvents && k == 'claimed') ||
          (store == kPlanetEvent && k == 'cl' && _n(m, 'w') == _n(l2, 'w'))) {
        out[k] = _union(m[k], l2[k]);
        continue;
      }
      if (store == kPlanetEvent && k == 'gc' && _n(m, 'w') == _n(l2, 'w')) {
        out[k] = m[k] == true || l2[k] == true;
        continue;
      }
      if (store == kLiveEvents) {
        out[k] = _rebaseLive(k, m, l1, l2);
        continue;
      }
      if (store == kMergeBoard && k == 'pl') {
        out[k] = _withBestProducers(<String, dynamic>{}, {'pl': m[k]}, {'pl': l2[k]})['pl']; // yukseltme geri gitmez
        continue;
      }
      if (add.contains(k)) {
        final r = _n(m, k) + _n(l2, k) - _n(l1, k);
        out[k] = r < 0 ? 0 : r;
      } else {
        out[k] = l2[k];
      }
    }
    return out;
  }

  /// Canli etkinlik anahtarlarinin yeniden dayamasi ('<id>.s' toplamsal, '.cl' birlesim, '.dr'/'.r' max).
  static dynamic _rebaseLive(String k, Json m, Json l1, Json l2) {
    final i = k.lastIndexOf('.');
    if (i <= 0) return l2[k];
    final p = k.substring(0, i);
    switch (k.substring(i + 1)) {
      case 's':
        if (_n(m, '$p.r') != _n(l2, '$p.r')) return l2[k];
        final r = _n(m, k) + _n(l2, k) - _n(l1, k);
        return r < 0 ? 0 : r;
      case 'cl':
        return _union(m[k], l2[k]);
      case 'dr':
      case 'r':
        return math.max(_n(m, k), _n(l2, k));
    }
    return l2[k];
  }

  // ------------------------------------------------------------ JSON yardimcilari

  static Stores? storesFrom(dynamic raw) {
    try {
      final dynamic j = raw is String ? jsonDecode(raw) : raw;
      if (j is! Map) return null;
      final out = <String, Json>{};
      j.forEach((k, v) {
        if (v is Map) out['$k'] = Map<String, dynamic>.from(v);
      });
      return out;
    } catch (err) {
      AppLog.w('save_merge.storesFrom', 'yutulan hata', err);
      return null;
    }
  }
}
