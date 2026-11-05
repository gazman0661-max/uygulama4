import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/localization/story_strings.dart';
import 'package:fastfood_merge/models/mb_story.dart';

void main() {
  test('sahne kimlikleri benzersiz, her sahnede en az 2 satir', () {
    final ids = kStoryScenes.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final s in kStoryScenes) {
      expect(s.lines.length, greaterThanOrEqualTo(2), reason: s.id);
    }
  });

  test('her sahne metni ve konusan adi TR cevirisinde var', () {
    for (final s in kStoryScenes) {
      for (final l in s.lines) {
        expect(kStoryTr.containsKey(l.text), isTrue, reason: '${s.id}: ${l.text}');
        expect(kStoryTr.containsKey(l.who), isTrue, reason: '${s.id}: ${l.who}');
      }
    }
    expect(kStoryTr.containsKey('Tap to continue'), isTrue);
  });

  test('bolum 1: sadece acilis sahnesi bekler', () {
    final p = MbStory.pending(1, (_) => false);
    expect(p.map((s) => s.id).toList(), ['w0_a']);
  });

  test('dunya sonu: ipucu + sonraki dunya girisi sirayla gelir', () {
    // 8. bolum bitti -> chapter 9
    final seen = {'w0_a'};
    final p = MbStory.pending(9, seen.contains);
    expect(p.map((s) => s.id).toList(), ['w0_b', 'w1_a']);
  });

  test('final yalniz 6. dunya bitince acilir', () {
    expect(MbStory.pending(48, (_) => false).any((s) => s.id == 'fin'), isFalse);
    expect(MbStory.pending(49, (_) => false).any((s) => s.id == 'fin'), isTrue);
  });

  test('gorulen sahne tekrar gelmez', () {
    final seen = <String>{};
    var guard = 0;
    while (true) {
      final s = MbStory.next(60, seen.contains);
      if (s == null) break;
      seen.add(s.id);
      if (++guard > 50) fail('sonsuz dongu');
    }
    expect(seen.length, kStoryScenes.length);
  });

  test('ilerlemis oyuncu: ilk ve son sahne kalir, aradakiler sessizce gecilir', () {
    // bolum 20 = 3. dunya (index 2)
    final skips = MbStory.catchUpSkips(20, (_) => false);
    final p = MbStory.pending(20, (_) => false).map((s) => s.id).toList();
    expect(p.first, 'w0_a');
    expect(p.last, 'w2_a');
    expect(skips, p.sublist(1, p.length - 1));
    // 2 veya daha az bekleyen varsa hicbir sey atlanmaz
    expect(MbStory.catchUpSkips(9, {'w0_a'}.contains), isEmpty);
  });

  test('vurgu rengi her sahne icin tanimli', () {
    for (final s in kStoryScenes) {
      expect(MbStory.accentFor(s), isNonZero);
    }
  });
}
