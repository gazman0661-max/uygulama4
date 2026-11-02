import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_theme.dart';

void main() {
  test('ilk 8 bolum dokunulmaz: degistirici yok, alt seviye sade yukselir', () {
    for (var c = 1; c <= 8; c++) {
      expect(ChapterConfig.modsFor(c).isNeutral, true, reason: 'bolum $c');
    }
    expect(ChapterConfig.orderMinLevel(2, ChapterKind.normal), 1);
    expect(ChapterConfig.orderMinLevel(3, ChapterKind.normal), 2);
    expect(ChapterConfig.orderMinLevel(8, ChapterKind.normal), 2);
  });

  test('alt seviye her bolumde 1..6 arasinda kalir', () {
    for (var c = 1; c <= 600; c++) {
      final f = ChapterConfig.orderMinLevel(c, ChapterConfig.kindFor(c));
      expect(f, inInclusiveRange(1, 6), reason: 'bolum $c');
    }
  });

  test('rahat (easy) bolumde alt sinir 1 seviye gevsek', () {
    expect(ChapterConfig.kindFor(15), ChapterKind.easy);
    expect(ChapterConfig.orderMinLevel(15, ChapterKind.easy), 3); // taban 4 - 1
    expect(ChapterConfig.kindFor(25), ChapterKind.easy);
    expect(ChapterConfig.orderMinLevel(25, ChapterKind.easy), 4); // taban 5 - 1
  });

  test('zor bolum kolay bolumden daha yuksek alt sinir ister (ayni blokta)', () {
    // Blok 17-24: bolum 18 = kolay, bolum 20 = boss atla; 21 orta, 22 zor.
    final easy = ChapterConfig.orderMinLevel(18, ChapterKind.normal);
    final hard = ChapterConfig.orderMinLevel(22, ChapterKind.normal);
    expect(hard, greaterThan(easy));
  });
}
