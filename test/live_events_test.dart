import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/models/live_events.dart';
import 'package:fastfood_merge/models/planet_event.dart' show PlanetReward;
import 'package:fastfood_merge/services/remote_tuning.dart';
import 'package:fastfood_merge/services/save_merge.dart';

// 2026-10-26 = Pazartesi, 27 Sali, 28 Carsamba, 29 Persembe, 30 Cuma, 31 Cumartesi, 11-01 Pazar, 11-02 Pazartesi.
final DateTime _mon = DateTime(2026, 10, 26, 10, 0);
final DateTime _tue = DateTime(2026, 10, 27, 23, 59);
final DateTime _wed = DateTime(2026, 10, 28, 12, 0);
final DateTime _thu = DateTime(2026, 10, 29, 23, 59);
final DateTime _fri = DateTime(2026, 10, 30, 9, 0);
final DateTime _sat = DateTime(2026, 10, 31, 9, 0);

EventDef get _mod2 => LiveEvents.defaultDefs[0]; // race_mod2: Pzt-Sal
EventDef get _mod1 => LiveEvents.defaultDefs[1]; // race_mod1: Car-Per

int _sum(PlanetReward r) => r.coins * 10000 + r.gems * 100 + r.energy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Takvim', () {
    test('varsayilan: Pzt-Sal Mod 2, Car-Per Mod 1, Cuma-Pazar yok', () {
      expect(_mod2.id, 'race_mod2');
      expect(_mod1.id, 'race_mod1');
      final w = EventDef.weekIdOf(_mon);
      expect(_mod2.runIdAt(_mon), w);
      expect(_mod2.runIdAt(_tue), w);
      expect(_mod2.runIdAt(_wed), isNull);
      expect(_mod1.runIdAt(_wed), w);
      expect(_mod1.runIdAt(_thu), w);
      expect(_mod1.runIdAt(_mon), isNull);
      expect(_mod2.runIdAt(_fri), isNull);
      expect(_mod1.runIdAt(_fri), isNull);
      expect(_mod2.runIdAt(_sat), isNull);
    });

    test('baslangic/bitis ve siradaki kosu', () {
      final w = EventDef.weekIdOf(_mon);
      expect(_mod2.startOfRun(w), DateTime(2026, 10, 26));
      expect(_mod2.endOfRun(w), DateTime(2026, 10, 28));
      expect(_mod1.startOfRun(w), DateTime(2026, 10, 28));
      expect(_mod1.endOfRun(w), DateTime(2026, 10, 30));
      expect(_mod1.nextRunAfter(_tue), w); // Sali iken Car-Per bu hafta
      expect(_mod1.nextRunAfter(_thu), w + 1); // Persembe sonu: gelecek hafta
      final n = _mod2.nextRunAfter(_fri);
      expect(_mod2.startOfRun(n), DateTime(2026, 11, 2));
    });

    test('haftalar arasina tasan etkinlik (Cmt 3 gun) Pazartesi de acik', () {
      const d = EventDef(id: 'weekend3', metric: EventMetric.orderMod1, startWeekday: DateTime.saturday, days: 3);
      final w = EventDef.weekIdOf(_mon);
      expect(d.runIdAt(_mon), w - 1); // gecen haftanin Cumartesi'sinde acildi
      expect(d.runIdAt(DateTime(2026, 10, 27, 0, 1)), isNull); // Sali 00:01: bitti
      expect(d.runIdAt(_sat), w);
    });

    test('tek seferlik tarih araligi: tam anda acilir/kapanir, haftalik takvim yok sayilir', () {
      final d = EventDef.fromJson({
        'id': 'bayram',
        'metric': 'order_mod1',
        'startDate': '2026-11-01T18:00:00',
        'endDate': '2026-11-03T23:59:00',
        'goals': [
          {'t': 5, 'c': 100}
        ],
      })!;
      expect(d.isOneOff, isTrue);
      final s0 = DateTime(2026, 11, 1, 18, 0);
      expect(d.runIdAt(s0.subtract(const Duration(minutes: 1))), isNull);
      expect(d.runIdAt(s0), isNotNull);
      expect(d.runIdAt(DateTime(2026, 11, 3, 23, 58)), d.runIdAt(s0)); // ayni kosu
      expect(d.runIdAt(DateTime(2026, 11, 3, 23, 59)), isNull); // bitis dahil degil
      expect(d.startOfRun(0), s0);
      expect(d.endOfRun(0), DateTime(2026, 11, 3, 23, 59));
      expect(d.nextRunAfter(DateTime(2026, 10, 30)), d.runIdAt(s0));
      expect(d.nextRunAfter(DateTime(2026, 11, 2)), -1); // baslamis/bitmis: tekrar yok
    });

    test('tek seferlik: gecersiz tarihler reddedilir', () {
      Map<String, dynamic> m(Object? a, Object? b) =>
          {'id': 'x', 'metric': 'order_mod1', 'goals': [{'t': 1}], 'startDate': a, 'endDate': b};
      expect(EventDef.fromJson(m('2026-11-01T18:00:00', null)), isNull); // yarim
      expect(EventDef.fromJson(m('bozuk', '2026-11-02T18:00:00')), isNull);
      expect(EventDef.fromJson(m('2026-11-02T18:00:00', '2026-11-01T18:00:00')), isNull); // bitis < baslangic
      expect(EventDef.fromJson(m('2026-11-01T18:00:00', '2026-11-01T18:10:00')), isNull); // 1 saatten kisa
      expect(EventDef.fromJson(m('2026-11-01T00:00:00', '2026-12-01T00:00:00')), isNull); // 14 gunden uzun
    });

    test('2 haftada bir (everyWeeks=2)', () {
      const d = EventDef(id: 'biweekly', metric: EventMetric.orderMod1, startWeekday: DateTime.monday, days: 3, everyWeeks: 2);
      final w = EventDef.weekIdOf(_mon); // 147 (tek)
      expect(d.runIdAt(_mon), isNull);
      expect(d.runIdAt(DateTime(2026, 11, 2, 12)), w + 1);
      expect(d.runIdAt(DateTime(2026, 11, 9, 12)), isNull);
      expect(d.nextRunAfter(_mon), w + 1);
    });
  });

  group('Uzaktan tanim (JSON)', () {
    test('gecerli tanim okunur, sayilar sinirlanir', () {
      final d = EventDef.fromJson({
        'id': 'Test_Event',
        'metric': 'merge_mod1',
        'startWeekday': 9, // 7'ye sinirlanir
        'days': 99, // 14'e sinirlanir
        'goals': [
          {'t': 10, 'c': 999999, 'g': 999, 'e': 999},
          {'t': 5, 'c': 1}, // artan degil -> atlanir
          {'t': 20, 'c': 100},
        ],
        'title': {'en': 'Merge Fest', 'tr': 'Birlestirme Senligi'},
      })!;
      expect(d.id, 'test_event');
      expect(d.startWeekday, 7);
      expect(d.days, 7); // everyWeeks=1 -> en fazla 7
      expect(d.goals.length, 2);
      expect(d.goals[0].reward.coins, EventDef.maxCoins);
      expect(d.goals[0].reward.gems, EventDef.maxGems);
      expect(d.goals[0].reward.energy, EventDef.maxEnergy);
      expect(d.goals[1].target, 20);
      expect(d.titleFor('tr'), 'Birlestirme Senligi');
      expect(d.titleFor('de'), 'Merge Fest'); // dil yoksa en
      expect(d.bots, isNull);
    });

    test('gecersizler reddedilir', () {
      expect(EventDef.fromJson({'id': 'a b', 'metric': 'merge_mod1', 'goals': [{'t': 1}]}), isNull); // bosluk
      expect(EventDef.fromJson({'id': 'a.b', 'metric': 'merge_mod1', 'goals': [{'t': 1}]}), isNull); // nokta
      expect(EventDef.fromJson({'id': 'x', 'metric': 'bilinmeyen', 'goals': [{'t': 1}]}), isNull); // metrik
      expect(EventDef.fromJson({'id': 'x', 'metric': 'merge_mod1'}), isNull); // hedef de bot da yok
      expect(EventDef.fromJson({'metric': 'merge_mod1', 'goals': [{'t': 1}]}), isNull); // id yok
    });

    test('botlu tanim: hizlar ve siralama odulleri', () {
      final d = EventDef.fromJson({
        'id': 'league',
        'metric': 'order_mod1',
        'bots': {'speeds': [1, 2, 3], 'awake': 0.5},
        'ranks': [{'c': 100}, {'c': 50}],
      })!;
      expect(d.bots!.count, 3);
      expect(d.bots!.awakeChance, 0.5);
      expect(d.rankRewards.length, 2);
      expect(d.goals, isEmpty);
      expect(d.restGetsLast, isTrue); // uzaktan JSON'da eski davranis korunur
    });

    test('uzaktan: count/minSpeed/maxSpeed ile 1500 bot, restGetsLast kapatilabilir, en fazla 3000', () {
      final d = EventDef.fromJson({
        'id': 'big',
        'metric': 'order_mod1',
        'bots': {'count': 1500, 'minSpeed': 0.1, 'maxSpeed': 4.5, 'gamma': 3},
        'ranks': [for (var i = 0; i < 10; i++) {'c': 100 - i}],
        'restGetsLast': false,
      })!;
      expect(d.bots!.count, 1500);
      expect(d.bots!.baseSpeed(0) < d.bots!.baseSpeed(1499), isTrue);
      expect(d.bots!.baseSpeed(0) >= 0.1, isTrue);
      expect(d.bots!.baseSpeed(1499) <= 4.5, isTrue);
      expect(d.rankRewards.length, 10);
      expect(d.restGetsLast, isFalse);
      final huge = EventDef.fromJson({
        'id': 'huge',
        'metric': 'order_mod1',
        'bots': {'count': 999999},
      })!;
      expect(huge.bots!.count, EventDef.maxBots);
    });

    test('BotSpec.spread: dagilim cok yavas/orta bot, az hizli bot (u^gamma)', () {
      const b = BotSpec.spread(1000, minSpeed: 0.1, maxSpeed: 5.0);
      final sp = [for (var i = 0; i < b.count; i++) b.baseSpeed(i)];
      for (var i = 1; i < sp.length; i++) {
        expect(sp[i] >= sp[i - 1], isTrue);
      }
      final mid = sp[500];
      expect(mid < (0.1 + 5.0) / 4, isTrue); // ortanca bot, araligin cok altinda
      expect(sp.last > 4.9, isTrue);
    });

    test('mergeRemote: ezer, kapat, ekle, gecersiz JSON varsayilanda kalir', () {
      final base = LiveEvents.defaultDefs;
      expect(LiveEvents.mergeRemote(base, '').length, 2);
      expect(LiveEvents.mergeRemote(base, 'bozuk{json').length, 2);
      final off = LiveEvents.mergeRemote(base, '{"events":[{"id":"race_mod1","off":true}]}');
      expect(off.map((e) => e.id), ['race_mod2']);
      final over = LiveEvents.mergeRemote(
        base,
        '[{"id":"race_mod2","metric":"order_mod2","startWeekday":2,"days":1,"goals":[{"t":3,"c":10}]}]',
      );
      expect(over.length, 2);
      expect(over.firstWhere((e) => e.id == 'race_mod2').startWeekday, 2);
      final add = LiveEvents.mergeRemote(base, '{"events":[{"id":"yeni","metric":"combo_mod1","goals":[{"t":2,"c":10}]}]}');
      expect(add.length, 3);
      expect(add.last.id, 'yeni');
    });

    test('en fazla 12 etkinlik', () {
      final items = [
        for (var i = 0; i < 20; i++) '{"id":"e$i","metric":"order_mod1","goals":[{"t":1,"c":1}]}',
      ].join(',');
      expect(LiveEvents.mergeRemote(LiveEvents.defaultDefs, '[$items]').length, 12);
    });
  });

  group('Botlar', () {
    const bs = BotSpec([0.15, 0.25, 0.35, 0.50, 0.70]);
    const seed = 12345;

    test('ayni girdi ayni puan, baslangicta sifir, zamanla azalmaz', () {
      final a = LiveEvents.botScoreAt(seed, 2, 0.35, const Duration(hours: 20), bs);
      expect(LiveEvents.botScoreAt(seed, 2, 0.35, const Duration(hours: 20), bs), a);
      expect(LiveEvents.botScoreAt(seed, 2, 0.35, Duration.zero, bs), 0);
      for (var bot = 0; bot < bs.count; bot++) {
        var prev = 0;
        for (var m = 0; m <= 2880; m += 37) {
          final v = LiveEvents.botScoreAt(seed, bot, 2.0, Duration(minutes: m), bs);
          expect(v >= prev, isTrue, reason: 'bot=$bot dk=$m');
          prev = v;
        }
      }
    });

    test('saatlik hiz negatif olmaz ve ust sinirdadir', () {
      for (var h = 0; h < 48; h++) {
        final r = LiveEvents.hourRate(seed, 1, h, 1.0, bs);
        expect(r >= 0, isTrue);
        expect(r <= bs.burstMul * 1.5, isTrue);
      }
    });

    test('hizli bot yavas bottan ortalamada cok daha onde', () {
      var slow = 0;
      var fast = 0;
      for (var run = 0; run < 30; run++) {
        final sp = LiveEvents.botSpeedsFor(_mod2, run);
        final s = (_mod2.seed * 31 + run) & 0x7fffffff;
        final last = sp.length - 1;
        slow += LiveEvents.botScoreAt(s, 0, sp[0], const Duration(hours: 48), _mod2.bots!);
        fast += LiveEvents.botScoreAt(s, last, sp[last], const Duration(hours: 48), _mod2.bots!);
      }
      expect(fast > slow * 2, isTrue, reason: 'slow=$slow fast=$fast');
    });

    test('isimler tekrarsiz ve kosuya gore sabit; etkinlikler farkli tohum', () {
      final a = LiveEvents.botNamesFor(_mod2, 147);
      final n = _mod2.bots!.count;
      expect(n, 1500);
      expect(a.length, n);
      expect(a.map((e) => e.toLowerCase()).toSet().length, n); // 1500 isim, hicbiri tekrar etmez
      expect(LiveEvents.botNamesFor(_mod2, 147), a);
      expect(_mod2.seed != _mod1.seed, isTrue);
    });

    test('bot kimlikleri: sabit, tekrarsiz, karisik stil, seviye/avatar dolu', () {
      for (var run = 100; run < 110; run++) {
        final a = LiveEvents.botProfilesFor(_mod2, run);
        final b = LiveEvents.botProfilesFor(_mod2, run);
        expect(a.length, _mod2.bots!.count);
        expect(a.map((p) => p.name.toLowerCase()).toSet().length, _mod2.bots!.count, reason: 'run=$run');
        for (var i = 0; i < a.length; i++) {
          expect(a[i].name, b[i].name);
          expect(a[i].name.isNotEmpty, isTrue);
          expect(a[i].level >= 7 && a[i].level <= 52, isTrue, reason: 'level=${a[i].level}');
          expect(a[i].awakeAdj.abs() <= 0.15, isTrue);
        }
      }
    });

    test('bot isimleri hep ayni kaliptan degil: duz isim ve rakamli/takma ad bir arada', () {
      final names = <String>[];
      for (var run = 0; run < 10; run++) {
        names.addAll(LiveEvents.botNamesFor(_mod2, run));
      }
      expect(names.any((n) => RegExp(r'^[A-Za-z\u00C0-\u017F]+$').hasMatch(n)), isTrue); // duz isim
      expect(names.any((n) => RegExp(r'\d').hasMatch(n)), isTrue); // rakamli
      expect(names.where((n) => n.contains('_') || n.contains('.')).isNotEmpty, isTrue);
      expect(names.toSet().length > 60, isTrue); // havuz genis
    });

    test('kisilik (awakeAdj) puani bozmaz: hala monoton', () {
      var prev = 0;
      for (var m = 0; m <= 2880; m += 41) {
        final v = LiveEvents.botScoreAt(seed, 1, 1.5, Duration(minutes: m), bs, awakeAdj: 0.12);
        expect(v >= prev, isTrue);
        prev = v;
      }
    });

    test('v218: seviye hizla artar (en hizli botlar yuksek seviyeli)', () {
      final p = LiveEvents.botProfilesFor(_mod2, 147);
      final n = p.length;
      double avgLv(int from, int to) {
        var sum = 0;
        for (var i = from; i < to; i++) {
          sum += p[i].level;
        }
        return sum / (to - from);
      }

      expect(avgLv(n - 10, n) >= 30, isTrue, reason: 'ilk10=${avgLv(n - 10, n)}');
      expect(avgLv(n - 10, n) > avgLv(0, 100) + 10, isTrue);
    });

    test('v218: gece saatlerinde botlar belirgin daha az aktif (gun ritmi)', () {
      var night = 0;
      var evening = 0;
      for (var bot = 0; bot < 1000; bot++) {
        if (LiveEvents.hourRate(seed, bot, 3, 1.0, bs, tz: 0) > 0) night++;
        if (LiveEvents.hourRate(seed, bot, 20, 1.0, bs, tz: 0) > 0) evening++;
      }
      expect(night * 3 < evening, isTrue, reason: 'gece=$night aksam=$evening');
    });

    test('v218: saat ici kumelenme azalmaz; part=1 tam saatlik puan', () {
      for (var bot = 0; bot < 50; bot++) {
        for (var h = 0; h < 24; h++) {
          final full = LiveEvents.hourAmount(seed, bot, h, 1.0, bs);
          expect(full, LiveEvents.hourRate(seed, bot, h, 1.0, bs));
          var prev = 0.0;
          for (var k = 1; k <= 20; k++) {
            final v = LiveEvents.hourAmount(seed, bot, h, 1.0, bs, part: k / 20.0);
            expect(v >= prev - 1e-12, isTrue);
            expect(v <= full + 1e-9, isTrue);
            prev = v;
          }
        }
      }
    });

    test('v218: isim stilleri daha cesitli (kucuk harf, bosluklu, gamer, oyuncu kalibi)', () {
      final names = <String>[];
      for (var run = 0; run < 6; run++) {
        names.addAll(LiveEvents.botNamesFor(_mod2, run));
      }
      expect(names.any((n) => RegExp(r'^[a-z]+$').hasMatch(n)), isTrue);
      expect(names.any((n) => n.contains(' ')), isTrue);
      expect(names.any((n) => n.startsWith('xX') || n.startsWith('The') || n.startsWith('Mr')), isTrue);
      expect(names.any((n) => RegExp(r'^(oyuncu|user|player_|misafir)\d+').hasMatch(n)), isTrue);
    });

    test('v218: cihaza ozel tohum (botSalt) farkli liste uretir, 0 = eski davranis', () {
      addTearDown(() => LiveEvents.botSalt = 0);
      LiveEvents.botSalt = 0;
      final a = LiveEvents.botNamesFor(_mod2, 147);
      LiveEvents.botSalt = 987654;
      final b = LiveEvents.botNamesFor(_mod2, 147);
      var same = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] == b[i]) same++;
      }
      expect(same < a.length ~/ 10, isTrue, reason: 'ayni=$same');
      expect(LiveEvents.botNamesFor(_mod2, 147), b); // ayni tohum = ayni liste
    });

    test('Remote Config yuzdesi bot hizini olcekler (ev_<id>_bot_pct)', () {
      RemoteTuning.setAll({});
      final base = LiveEvents.botSpeedsFor(_mod2, 147);
      RemoteTuning.setAll({'ev_race_mod2_bot_pct': '200'});
      final doubled = LiveEvents.botSpeedsFor(_mod2, 147);
      RemoteTuning.setAll({});
      for (var i = 0; i < base.length; i++) {
        expect(doubled[i] / base[i], closeTo(2.0, 1e-9));
      }
    });
  });

  group('LiveEvents', () {
    late List<PlanetReward> given;
    late LiveEvents ev;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      given = [];
      RemoteTuning.setAll({});
      LiveEvents.clock = () => _mon;
      LiveEvents.unlocked = () => true;
      LiveEvents.deliver = (r, src) => given.add(r);
      LiveEvents.onSaved = null;
      ev = LiveEvents.instance;
      ev.resetForTest();
    });

    test('yalnizca o metrigi sayan ACIK etkinlige eklenir', () {
      ev.report(EventMetric.orderMod1, 4); // Pazartesi: Mod 1 yarisi kapali
      expect(ev.score(_mod2), 0);
      expect(ev.score(_mod1), 0);
      ev.report(EventMetric.orderMod2, 3);
      ev.report(EventMetric.orderMod2, 2);
      expect(ev.score(_mod2), 5);
      expect(ev.score(_mod1), 0);
      LiveEvents.clock = () => _fri;
      ev.report(EventMetric.orderMod2, 9); // yaris yok: sayilmaz; biten kosu kapanir (5 puan -> odul)
      expect(ev.score(_mod2), 0);
      expect(ev.isActive(_mod2), isFalse);
      expect(given.length, 1);
    });

    test('ayni metrigi sayan iki etkinlik birlikte ilerler (uzaktan eklenen)', () {
      RemoteTuning.setAll({
        LiveEvents.remoteKey:
            '{"events":[{"id":"extra","metric":"order_mod2","startWeekday":1,"days":2,"goals":[{"t":1,"c":100}]}]}',
      });
      final extra = ev.byId('extra')!;
      ev.report(EventMetric.orderMod2, 3);
      expect(ev.score(_mod2), 3);
      expect(ev.score(extra), 3);
      expect(ev.activeDefs.map((d) => d.id), containsAll(['race_mod2', 'extra']));
      expect(ev.canClaim(extra, 0), isTrue);
      expect(ev.hasBadge, isTrue);
    });

    test('seviye kilidi acik degilse puan sayilmaz', () {
      LiveEvents.unlocked = () => false;
      ev.report(EventMetric.orderMod2, 3);
      expect(ev.score(_mod2), 0);
      expect(ev.hasBadge, isFalse);
    });

    test('hedef odulu: hedefe ulasinca alinir, ikinci kez alinmaz', () {
      ev.report(EventMetric.orderMod2, 4);
      expect(ev.canClaim(_mod2, 0), isFalse);
      ev.report(EventMetric.orderMod2, 1); // 5 = ilk hedef
      expect(ev.canClaim(_mod2, 0), isTrue);
      expect(ev.hasClaimable(_mod2), isTrue);
      expect(ev.hasBadge, isTrue);
      final r = ev.claim(_mod2, 0)!;
      expect(_sum(r), _sum(_mod2.goals[0].reward));
      expect(given.length, 1);
      expect(ev.isClaimed(_mod2, 0), isTrue);
      expect(ev.claim(_mod2, 0), isNull);
      expect(ev.canClaim(_mod2, 1), isFalse);
      expect(ev.hasClaimable(_mod2), isFalse);
    });

    test('siralama: 1500 bot + oyuncu, oyuncu bir kez, puana gore azalan', () {
      ev.report(EventMetric.orderMod2, 7);
      final st = ev.standings(_mod2, playerName: 'Sen');
      expect(st.length, 1501);
      expect(st.where((e) => e.isPlayer).length, 1);
      for (var i = 1; i < st.length; i++) {
        expect(st[i - 1].score >= st[i].score, isTrue);
      }
      expect(ev.rank(_mod2), st.indexWhere((e) => e.isPlayer) + 1);
      expect(ev.totalRacers(_mod2), 1501);
    });

    test('limit: ilk N satir; oyuncu disarida kalirsa listede yok, sirasi rank() ile bilinir', () {
      ev.report(EventMetric.orderMod2, 1);
      final all = ev.standings(_mod2, playerName: 'Sen');
      final top = ev.standings(_mod2, playerName: 'Sen', limit: 100);
      expect(top.length, 100);
      for (var i = 0; i < 100; i++) {
        expect(top[i].name, all[i].name);
        expect(top[i].score, all[i].score);
        expect(top[i].isPlayer, all[i].isPlayer);
      }
      expect(ev.rank(_mod2), all.indexWhere((e) => e.isPlayer) + 1);
    });

    test('dakika-dakika onbellekli tahta, botScoreAt ile BIREBIR ayni', () {
      LiveEvents.clock = () => DateTime(2026, 10, 26, 10, 37);
      final run = EventDef.weekIdOf(_mon);
      final spec = _mod2.bots!;
      final speeds = LiveEvents.botSpeedsFor(_mod2, run);
      final profiles = LiveEvents.botProfilesFor(_mod2, run);
      final seed = (_mod2.seed * 31 + run) & 0x7fffffff;
      final elapsed = const Duration(hours: 10, minutes: 37);
      for (final e in ev.standings(_mod2).where((e) => !e.isPlayer).take(300)) {
        final i = e.botIndex;
        expect(e.score, LiveEvents.botScoreAt(seed, i, speeds[i], elapsed, spec, awakeAdj: profiles[i].awakeAdj));
      }
      // Saat ilerleyince (onbellek guncellenir) yine ayni
      LiveEvents.clock = () => DateTime(2026, 10, 27, 3, 5);
      final el2 = const Duration(days: 1, hours: 3, minutes: 5);
      for (final e in ev.standings(_mod2).where((e) => !e.isPlayer).take(300)) {
        final i = e.botIndex;
        expect(e.score, LiveEvents.botScoreAt(seed, i, speeds[i], el2, spec, awakeAdj: profiles[i].awakeAdj));
      }
    });

    test('dagilim dogal: cok yavas/orta, az sayida cok hizli; ilk 10 acik farkla ustte', () {
      LiveEvents.clock = () => DateTime(2026, 10, 27, 23, 59); // kosunun sonuna yakin
      final st = ev.standings(_mod2);
      final scores = [for (final e in st) e.score];
      expect(scores.first > scores[999], isTrue);
      expect(scores[9] > scores[749], isTrue); // ilk 10 > ortanca
      expect(scores[749] <= scores[99], isTrue);
      expect(scores.toSet().length > 10, isTrue); // esitlik yigini yok
    });

    test('baslangicta puan 0: oyuncu en sonda; puan alinca 1.', () {
      LiveEvents.clock = () => DateTime(2026, 10, 26, 0, 0);
      expect(ev.rank(_mod2), 1501); // henuz yarismiyor
      ev.report(EventMetric.orderMod2, 500);
      expect(ev.rank(_mod2), 1);
      expect(ev.pointsToNextRank(_mod2), isNull); // 1. sirada
    });

    test('bir ust sira ve ilk 100 icin gereken puan', () {
      LiveEvents.clock = () => DateTime(2026, 10, 27, 12, 0);
      ev.report(EventMetric.orderMod2, 3);
      final r = ev.rank(_mod2);
      final st = ev.standings(_mod2, playerName: 'Sen');
      expect(r > 100, isTrue, reason: 'rank=$r');
      final need = ev.pointsToNextRank(_mod2)!;
      expect(need >= 1, isTrue);
      final above = st[r - 2].score; // hemen ustteki
      expect(need, above - 3 < 1 ? 1 : above - 3);
      final toCut = ev.pointsToEnter(_mod2, 100)!;
      expect(toCut, st[99].score - 3 < 1 ? 1 : st[99].score - 3);
      ev.report(EventMetric.orderMod2, 500);
      expect(ev.pointsToEnter(_mod2, 100), isNull); // zaten icinde
    });

    test('etkinlik yokken siralama bos, geri sayim siradaki baslangica', () {
      LiveEvents.clock = () => _fri;
      expect(ev.standings(_mod2), isEmpty);
      expect(ev.rank(_mod2), 0);
      expect(ev.activeDefs, isEmpty);
      expect(ev.nextUpcoming!.id, 'race_mod2'); // Cuma 09:00 -> Pzt 00:00 en yakin
      expect(ev.timeLeft(_mod2).inHours, greaterThan(48));
    });

    test('kosu bitince siralama odulu + alinmamis hedefler OTOMATIK verilir (tek sefer)', () async {
      ev.report(EventMetric.orderMod2, 9); // ilk hedef (5) tamam, alinmadi
      LiveEvents.clock = () => _wed; // Mod 2 bitti, Mod 1 basladi
      final notes = await ev.takeNotes();
      expect(notes.length, 1);
      final n = notes.single;
      expect(n.eventId, 'race_mod2');
      expect(n.rank >= 1 && n.rank <= 1501, isTrue);
      expect(given.length, 1);
      final expected = _sum(LiveEvents.rankReward(_mod2, n.rank)) + _sum(_mod2.goals[0].reward);
      expect(_sum(given.single), expected);
      expect(_sum(n.reward), expected);
      expect(ev.score(_mod2), 0);
      expect(ev.isActive(_mod1), isTrue);
      expect((await ev.takeNotes()), isEmpty);
      expect(given.length, 1);
    });

    test('alinan hedef bitiste ikinci kez verilmez', () async {
      ev.report(EventMetric.orderMod2, 9);
      ev.claim(_mod2, 0);
      expect(given.length, 1);
      LiveEvents.clock = () => _wed;
      final notes = await ev.takeNotes();
      expect(given.length, 2);
      expect(_sum(given[1]), _sum(LiveEvents.rankReward(_mod2, notes.single.rank)));
    });

    test('puani 0 olana odul yok', () async {
      expect(ev.rank(_mod2) >= 1, isTrue); // kosuyu baslatir, puan yok
      LiveEvents.clock = () => _wed;
      expect(await ev.takeNotes(), isEmpty);
      expect(given, isEmpty);
    });

    test('botsuz etkinlik: yalnizca hedefler, bitince otomatik (siralamasiz)', () async {
      RemoteTuning.setAll({
        LiveEvents.remoteKey:
            '{"events":[{"id":"goalsonly","metric":"combo_mod1","startWeekday":1,"days":2,"goals":[{"t":3,"c":100}]}]}',
      });
      final d = ev.byId('goalsonly')!;
      ev.report(EventMetric.comboMod1, 3);
      expect(ev.standings(d), isEmpty);
      LiveEvents.clock = () => _wed;
      final notes = await ev.takeNotes();
      expect(notes.length, 1);
      expect(notes.single.eventId, 'goalsonly');
      expect(notes.single.rank, 0);
      expect(given.length, 1);
      expect(given.single.coins, 100);
    });

    test('Cuma gecince son (Mod 1) kosunun odulu verilir, etkinlik kalmaz', () async {
      LiveEvents.clock = () => _wed;
      ev.report(EventMetric.orderMod1, 35); // ilk hedef 30
      LiveEvents.clock = () => _sat;
      final notes = await ev.takeNotes();
      expect(notes.single.eventId, 'race_mod1');
      expect(given.length, 1);
      expect(ev.isActive(_mod1), isFalse);
      expect(ev.score(_mod1), 0);
    });

    test('siralama odulu sinirlar icinde kalir; botsuzda bos', () {
      final l = _mod1.rankRewards;
      expect(l.length, 10); // yalnizca ilk 10 odul alir
      expect(_mod1.restGetsLast, isFalse);
      expect(_sum(LiveEvents.rankReward(_mod1, 0)), _sum(l.first));
      expect(_sum(LiveEvents.rankReward(_mod1, 10)), _sum(l.last));
      expect(LiveEvents.rankReward(_mod1, 11).isEmpty, isTrue);
      expect(LiveEvents.rankReward(_mod1, 1500).isEmpty, isTrue);
      const legacy = EventDef(
        id: 'old',
        metric: EventMetric.orderMod1,
        startWeekday: 1,
        days: 1,
        bots: BotSpec([1.0]),
        rankRewards: [PlanetReward(coins: 5), PlanetReward(coins: 1)],
        restGetsLast: true,
      );
      expect(LiveEvents.rankReward(legacy, 99).coins, 1); // eski davranis: son odul kalanlara
      const noRanks = EventDef(id: 'x', metric: EventMetric.orderMod1, startWeekday: 1, days: 1);
      expect(LiveEvents.rankReward(noRanks, 1).isEmpty, isTrue);
    });

    test('kayit: yaz-oku puan ve alinanlari geri getirir', () async {
      ev.report(EventMetric.orderMod2, 6);
      ev.claim(_mod2, 0);
      await ev.save();
      ev.resetForTest();
      await ev.load();
      expect(ev.score(_mod2), 6);
      expect(ev.isClaimed(_mod2, 0), isTrue);
      expect(ev.isClaimed(_mod2, 1), isFalse);
    });
  });

  group('Bulut birlestirme (SaveMerge.liveEvents)', () {
    test('anahtar listede; ayni kosuda puan delta ile toplanir', () {
      expect(SaveMerge.keys, contains(SaveMerge.kLiveEvents));
      expect(SaveMerge.otherKeys, contains(SaveMerge.kLiveEvents));
      final base = {'a.r': 10, 'a.s': 2, 'a.dr': 8, 'a.cl': <int>[]};
      final local = {'a.r': 10, 'a.s': 5, 'a.dr': 8, 'a.cl': [0]};
      final cloud = {'a.r': 10, 'a.s': 3, 'a.dr': 8, 'a.cl': [1]};
      final m = SaveMerge.liveEvents(base, local, cloud);
      expect(m['a.s'], 6); // 3 + (5 - 2)
      expect((m['a.cl'] as List).toSet(), {0, 1});
      expect(m['a.dr'], 8);
    });

    test('farkli kosuda yeni olan kazanir, teslim isareti HER ZAMAN max', () {
      final local = {'a.r': 10, 'a.s': 4, 'a.dr': 9, 'a.cl': [0]};
      final cloud = {'a.r': 11, 'a.s': 1, 'a.dr': 10, 'a.cl': <int>[]};
      final m = SaveMerge.liveEvents(null, local, cloud);
      expect(m['a.r'], 11);
      expect(m['a.s'], 1);
      expect(m['a.dr'], 10);
      final m2 = SaveMerge.liveEvents(null, cloud, local);
      expect(m2['a.r'], 11);
      expect(m2['a.dr'], 10);
    });

    test('etkinlikler bagimsiz birlesir; yalniz bir tarafta olan korunur', () {
      final local = {'a.r': 10, 'a.s': 4, 'a.dr': -1, 'a.cl': <int>[], 'b.r': 5, 'b.s': 9, 'b.dr': -1, 'b.cl': <int>[]};
      final cloud = {'a.r': 10, 'a.s': 7, 'a.dr': -1, 'a.cl': <int>[]};
      final m = SaveMerge.liveEvents(null, local, cloud);
      expect(m['a.s'], 7); // base yok -> max
      expect(m['b.s'], 9);
      expect(m['b.r'], 5);
    });

    test('tum depolarda: biri yoksa digeri alinir', () {
      final one = SaveMerge.all(null, {SaveMerge.kLiveEvents: {'a.r': 4, 'a.s': 2, 'a.dr': -1, 'a.cl': <int>[]}}, {});
      expect(one[SaveMerge.kLiveEvents]!['a.s'], 2);
    });

    test('yeniden dayama: puan toplamsal, alinanlar birlesim, teslim max', () {
      final m = {'a.r': 10, 'a.s': 7, 'a.dr': 8, 'a.cl': [0]};
      final l1 = {'a.r': 10, 'a.s': 5, 'a.dr': 8, 'a.cl': [0]};
      final l2 = {'a.r': 10, 'a.s': 6, 'a.dr': 8, 'a.cl': [0, 1]};
      final out = SaveMerge.rebase(SaveMerge.kLiveEvents, m, l1, l2);
      expect(out['a.s'], 8); // 7 + (6 - 5)
      expect((out['a.cl'] as List).toSet(), {0, 1});
      expect(out['a.dr'], 8);
    });

    test('diger cihaz odulu zaten teslim ettiyse bu cihaz ikinci kez vermez', () async {
      SharedPreferences.setMockInitialValues({});
      final given = <PlanetReward>[];
      LiveEvents.clock = () => _wed;
      LiveEvents.unlocked = () => true;
      LiveEvents.deliver = (r, src) => given.add(r);
      LiveEvents.onSaved = null;
      final ev = LiveEvents.instance;
      ev.resetForTest();
      final run = EventDef.weekIdOf(_mon);
      // Bu cihazda biten Mod 2 kosusu kayitli (puan 12) ama BASKA cihaz odulu zaten teslim etmis (dr = run).
      final merged = SaveMerge.liveEvents(
        null,
        {'race_mod2.r': run, 'race_mod2.s': 12, 'race_mod2.dr': -1, 'race_mod2.cl': <int>[]},
        {'race_mod2.r': -1, 'race_mod2.s': 0, 'race_mod2.dr': run, 'race_mod2.cl': <int>[]},
      );
      expect(merged['race_mod2.r'], run);
      expect(merged['race_mod2.dr'], run);
      ev.applyJson(merged);
      final notes = await ev.takeNotes(); // kosu bitti ama dr >= r -> teslim yok
      expect(notes, isEmpty);
      expect(given, isEmpty);
    });
  });
}
