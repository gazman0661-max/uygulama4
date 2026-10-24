import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/services/save_merge.dart';

Stores _s(Map<String, dynamic> progress, {Map<String, dynamic>? piggy}) => {
      SaveMerge.kProgress: progress,
      if (piggy != null) SaveMerge.kPiggy: piggy,
    };

void main() {
  mbMissionsMergeTests();
  test('A harcar, B kazanir: ikisi de korunur (delta)', () {
    final base = _s({'gems': 100, 'coins': 500});
    final a = _s({'gems': 40, 'coins': 500}); // A 60 mucevher harcadi
    final cloudAfterB = _s({'gems': 130, 'coins': 500}); // B 30 kazandi, buluta yazdi
    final m = SaveMerge.all(base, a, cloudAfterB);
    expect(m[SaveMerge.kProgress]!['gems'], 70); // 130 - 60
  });

  test('eski cihaz bulutu ezmez: harcama negatife dusmez', () {
    final base = _s({'gems': 50});
    final local = _s({'gems': 0});
    final cloud = _s({'gems': 20});
    final m = SaveMerge.all(base, local, cloud);
    expect(m[SaveMerge.kProgress]!['gems'], 0);
  });

  test('tek seferlik satin alma ve seviyeler geri gitmez', () {
    final local = _s({'starterPackBought': true, 'maxUnlockedChapter': 3, 'townLevels': [2, 0]});
    final cloud = _s({'starterPackBought': false, 'maxUnlockedChapter': 5, 'townLevels': [1, 4]});
    final m = SaveMerge.all(null, local, cloud)[SaveMerge.kProgress]!;
    expect(m['starterPackBought'], true);
    expect(m['maxUnlockedChapter'], 5);
    expect(m['townLevels'], [2, 4]);
  });

  test('gunluk odul iki cihazda iki kez alinmaz', () {
    final day = '2026-10-04T00:00:00.000';
    final local = _s({'lastDailyRewardClaim': day, 'dailyStreak': 4});
    final cloud = _s({'lastDailyRewardClaim': '2026-10-03T00:00:00.000', 'dailyStreak': 3});
    final m = SaveMerge.all(null, local, cloud)[SaveMerge.kProgress]!;
    expect(m['lastDailyRewardClaim'], day);
    expect(m['dailyStreak'], 4);
  });

  test('ayni donemde alinmis gorev odulu geri acilmaz', () {
    final d = '2026-10-04T00:00:00.000';
    final local = _s({'missionsResetDate': d, 'missionMergeClaimed': false, 'missionMergeProgress': 3});
    final cloud = _s({'missionsResetDate': d, 'missionMergeClaimed': true, 'missionMergeProgress': 5});
    final m = SaveMerge.all(null, local, cloud)[SaveMerge.kProgress]!;
    expect(m['missionMergeClaimed'], true);
    expect(m['missionMergeProgress'], 5);
  });

  test('kumbara: A bosaltti, B eski dolu hali gonderse cift odul olmaz', () {
    final base = _s({'gems': 0}, piggy: {'gems': 30});
    final bLocal = _s({'gems': 0}, piggy: {'gems': 30}); // B degismedi
    final cloud = _s({'gems': 30}, piggy: {'gems': 0}); // A bosaltti
    final m = SaveMerge.all(base, bLocal, cloud);
    expect(m[SaveMerge.kPiggy]!['gems'], 0);
    expect(m[SaveMerge.kProgress]!['gems'], 30);
  });

  test('ses ayarlari cihaza ozel kalir', () {
    final local = _s({'soundEnabled': false});
    final cloud = _s({'soundEnabled': true});
    expect(SaveMerge.all(null, local, cloud)[SaveMerge.kProgress]!['soundEnabled'], false);
  });

  test('rebase: ag turunda yapilan harcama kaybolmaz', () {
    final m = {'gems': 100};
    final l1 = {'gems': 50};
    final l2 = {'gems': 30}; // arada 20 harcandi
    expect(SaveMerge.rebase(SaveMerge.kProgress, m, l1, l2)['gems'], 80);
  });

  test('davet kimligi: eski kimlik kazanir, islendi listeleri birlesir', () {
    final local = {
      SaveMerge.kProgress: {'gems': 1},
      SaveMerge.kInvite: {'playerId': 'new', 'token': 'new.t', 'inviteCode': 'NEWW-CODE', 'createdAt': 2000, 'processed': ['a']},
    };
    final cloud = {
      SaveMerge.kProgress: {'gems': 1},
      SaveMerge.kInvite: {'playerId': 'old', 'token': 'old.t', 'inviteCode': 'OLDD-CODE', 'createdAt': 1000, 'processed': ['b']},
    };
    final m = SaveMerge.all(null, local, cloud)[SaveMerge.kInvite]!;
    expect(m['playerId'], 'old');
    expect(m['inviteCode'], 'OLDD-CODE');
    expect(m['processed'], ['a', 'b']);
  });

  test('davet kimligi: bulutta yoksa yerel kalir, yerelde yoksa bulut gelir', () {
    final id = {'playerId': 'x', 'token': 'x.t', 'inviteCode': 'AAAA-BBBB', 'createdAt': 5, 'processed': <String>[]};
    expect(SaveMerge.all(null, {SaveMerge.kInvite: id}, {SaveMerge.kProgress: {}})[SaveMerge.kInvite]!['playerId'], 'x');
    expect(SaveMerge.all(null, {SaveMerge.kProgress: {}}, {SaveMerge.kInvite: id})[SaveMerge.kInvite]!['playerId'], 'x');
  });

  test('ogretici gorulenleri (tutSeen) iki cihazdan birlesir, geri acilmaz', () {
    final local = _s({'tutSeen': ['ch1_steps', 'danger']});
    final cloud = _s({'tutSeen': ['danger', 'feat_wheel']});
    final m = SaveMerge.all(null, local, cloud)[SaveMerge.kProgress]!;
    expect(Set<String>.from(m['tutSeen'] as List), {'ch1_steps', 'danger', 'feat_wheel'});
  });

  Map<String, dynamic> mb(int ch, int cp, int d, {int e = 50, String tag = ''}) => {
        'v': 3,
        'e': e,
        'rs': 0,
        'b': {
          'c': List<int>.filled(48, 0),
          'o': <dynamic>[],
          'd': d,
          'n': 1,
          'ch': ch,
          'cp': cp,
          'tag': tag,
        },
      };

  test('Mod 2 (Merge Tahtasi): daha ileri bolum komple kazanir (enerji dahil)', () {
    final Stores local = {SaveMerge.kProgress: {'gems': 1}, SaveMerge.kMergeBoard: mb(3, 1, 20, e: 10)};
    final Stores cloud = {SaveMerge.kProgress: {'gems': 1}, SaveMerge.kMergeBoard: mb(7, 0, 41, e: 80)};
    final m = SaveMerge.all(null, local, cloud)[SaveMerge.kMergeBoard]!;
    expect((m['b'] as Map)['ch'], 7);
    expect(m['e'], 80);
    final m2 = SaveMerge.all(null, cloud, local)[SaveMerge.kMergeBoard]!;
    expect((m2['b'] as Map)['ch'], 7);
  });

  test('Mod 2: ayni bolumde ilerleyen taraf kazanir; tam esitse yerel degistiyse yerel', () {
    final Stores a = {SaveMerge.kProgress: {}, SaveMerge.kMergeBoard: mb(4, 1, 10)};
    final Stores b = {SaveMerge.kProgress: {}, SaveMerge.kMergeBoard: mb(4, 3, 12)};
    expect((SaveMerge.all(null, a, b)[SaveMerge.kMergeBoard]!['b'] as Map)['cp'], 3);
    expect((SaveMerge.all(null, b, a)[SaveMerge.kMergeBoard]!['b'] as Map)['cp'], 3);

    final Stores base = {SaveMerge.kProgress: {}, SaveMerge.kMergeBoard: mb(4, 1, 10, e: 50)};
    final Stores local = {SaveMerge.kProgress: {}, SaveMerge.kMergeBoard: mb(4, 1, 10, e: 30)}; // enerji harcandi
    final Stores cloud = {SaveMerge.kProgress: {}, SaveMerge.kMergeBoard: mb(4, 1, 10, e: 50)};
    expect(SaveMerge.all(base, local, cloud)[SaveMerge.kMergeBoard]!['e'], 30);
    expect(SaveMerge.all(base, cloud, cloud)[SaveMerge.kMergeBoard]!['e'], 50);
  });

  test('Mod 2: bulutta yoksa yerel yuklenir, yerelde yoksa bulut gelir; eski 6 tahtali kayit okunur', () {
    final onlyLocal = SaveMerge.all(null, {SaveMerge.kMergeBoard: mb(2, 0, 5)}, {SaveMerge.kProgress: {}});
    expect((onlyLocal[SaveMerge.kMergeBoard]!['b'] as Map)['ch'], 2);
    final onlyCloud = SaveMerge.all(null, {SaveMerge.kProgress: {}}, {SaveMerge.kMergeBoard: mb(9, 2, 70)});
    expect((onlyCloud[SaveMerge.kMergeBoard]!['b'] as Map)['ch'], 9);

    final Map<String, dynamic> oldFmt = {'v': 1, 'e': 5, 'rs': 0, 'b': [mb(1, 0, 3)['b'], mb(6, 1, 30)['b'], mb(2, 0, 9)['b']]};
    expect(SaveMerge.mergeBoardRank(oldFmt), [6, 1, 30]);
    final win = SaveMerge.all(null, {SaveMerge.kMergeBoard: mb(3, 0, 10)}, {SaveMerge.kMergeBoard: oldFmt});
    expect(win[SaveMerge.kMergeBoard], oldFmt);
  });
}

void mbMissionsMergeTests() {
  Map<String, dynamic> mm({String d = '2026-10-24T00:00:00.000', String w = '2026-10-19T00:00:00.000', String m = '2026-10-01T00:00:00.000', Map<String, int> p = const {}, List<String> c = const []}) =>
      {'p': p, 'c': c, 'd': d, 'w': w, 'm': m};

  test('Mod 2 gorevleri: ayni donemde ilerleme max, alinanlar birlesim', () {
    final l = {SaveMerge.kProgress: <String, dynamic>{}, SaveMerge.kMbMissions: mm(p: {'d_orders': 5, 'w_chapters': 2}, c: ['d_chapters'])};
    final c = {SaveMerge.kProgress: <String, dynamic>{}, SaveMerge.kMbMissions: mm(p: {'d_orders': 3, 'w_chapters': 4}, c: ['w_energy'])};
    final m = SaveMerge.all(null, l, c)[SaveMerge.kMbMissions]!;
    expect((m['p'] as Map)['d_orders'], 5);
    expect((m['p'] as Map)['w_chapters'], 4);
    expect(List<String>.from(m['c'] as List).toSet(), {'d_chapters', 'w_energy'});
  });

  test('Mod 2 gorevleri: yeni gun/haftanin tarafi kazanir, eski donemin odulu geri gelmez', () {
    final l = {SaveMerge.kProgress: <String, dynamic>{}, SaveMerge.kMbMissions: mm(d: '2026-10-25T00:00:00.000', p: {'d_orders': 1}, c: [])};
    final c = {SaveMerge.kProgress: <String, dynamic>{}, SaveMerge.kMbMissions: mm(d: '2026-10-24T00:00:00.000', p: {'d_orders': 8, 'w_chapters': 3}, c: ['d_orders'])};
    final m = SaveMerge.all(null, l, c)[SaveMerge.kMbMissions]!;
    expect(m['d'], '2026-10-25T00:00:00.000'); // gunluk: yerel (yeni gun) kazandi
    expect((m['p'] as Map)['d_orders'], 1);
    expect(List<String>.from(m['c'] as List).contains('d_orders'), isFalse); // dunku alinma tasinmaz
    expect((m['p'] as Map)['w_chapters'], 3); // haftalik ayni hafta: buluttaki ilerleme korunur
  });

  test('Mod 2 gorevleri: bir tarafta kayit yoksa digeri aynen gelir', () {
    final only = {SaveMerge.kProgress: <String, dynamic>{}, SaveMerge.kMbMissions: mm(p: {'d_orders': 2})};
    final none = {SaveMerge.kProgress: <String, dynamic>{}};
    expect(SaveMerge.all(null, only, none)[SaveMerge.kMbMissions]!['p'], {'d_orders': 2});
    expect(SaveMerge.all(null, none, only)[SaveMerge.kMbMissions]!['p'], {'d_orders': 2});
  });
}
