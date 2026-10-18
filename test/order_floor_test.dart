import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_theme.dart';

void main() {
  test('siparis alt seviyesi bolumle birlikte yukselir', () {
    expect(ChapterConfig.orderMinLevel(2, ChapterKind.normal), 1);
    expect(ChapterConfig.orderMinLevel(3, ChapterKind.normal), 2);
    expect(ChapterConfig.orderMinLevel(7, ChapterKind.normal), 2);
    expect(ChapterConfig.orderMinLevel(8, ChapterKind.normal), 3);
    expect(ChapterConfig.orderMinLevel(14, ChapterKind.normal), 3);
    expect(ChapterConfig.orderMinLevel(15, ChapterKind.normal), 4);
    expect(ChapterConfig.orderMinLevel(24, ChapterKind.normal), 4);
    expect(ChapterConfig.orderMinLevel(25, ChapterKind.normal), 5);
    expect(ChapterConfig.orderMinLevel(500, ChapterKind.normal), 5);
  });

  test('rahat bolumde alt sinir 1 seviye gevsek, hic 1 altina inmez', () {
    expect(ChapterConfig.orderMinLevel(2, ChapterKind.easy), 1);
    expect(ChapterConfig.orderMinLevel(15, ChapterKind.easy), 3);
    expect(ChapterConfig.orderMinLevel(26, ChapterKind.easy), 4);
  });
}
