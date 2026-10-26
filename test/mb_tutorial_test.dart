import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/mb_tutorial.dart';
import 'package:fastfood_merge/models/merge_board.dart';

MbBoard _board(List<MapEntry<int, int>> items, List<MbOrder> orders) {
  final b = MbBoard();
  for (final e in items) {
    b.cells[e.key] = e.value;
  }
  b.orders.addAll(orders);
  return b;
}

void main() {
  test('siparis Lv2 istiyor, iki Lv1 var -> BIRLESTIR (en yakin cift)', () {
    final b = _board(
      [const MapEntry(0, 1), const MapEntry(5, 1), const MapEntry(7, 1)],
      [MbOrder(id: 1, levels: [2], reward: 6)],
    );
    final p = MbTutorial.plan(b)!;
    expect(p.kind, MbTutKind.merge);
    expect(p.level, 1);
    // 0 (satir0,sutun0) ile 7 (satir1,sutun1) mesafe 2; 5 ikisinden de uzak (5 ve 5)
    expect([p.a, p.b]..sort(), [0, 7]);
  });

  test('istenen seviye tahtada -> TESLIM, dogru hucre ve siparis', () {
    final b = _board(
      [const MapEntry(12, 2), const MapEntry(3, 1)],
      [MbOrder(id: 1, levels: [2], reward: 6)],
    );
    final p = MbTutorial.plan(b)!;
    expect(p.kind, MbTutKind.deliver);
    expect(p.a, 12);
    expect(p.b, 0);
    expect(p.level, 2);
  });

  test('birlestirilecek cift yok -> URET', () {
    final b = _board([const MapEntry(0, 1)], [MbOrder(id: 1, levels: [2], reward: 6)]);
    final p = MbTutorial.plan(b)!;
    expect(p.kind, MbTutKind.spawn);
  });

  test('tahta dolu, teslim ve birlestirme yok -> null (gosterilecek adim yok)', () {
    final b = MbBoard();
    for (var i = 0; i < MbBoard.size; i++) {
      b.cells[i] = MbBoard.maxLevel;
    }
    b.orders.add(MbOrder(id: 1, levels: [2], reward: 6));
    expect(MbTutorial.plan(b), isNull);
  });

  test('yarisi dolmus siparis once: Lv3 kalemi o siparise teslim', () {
    final done = MbOrder(id: 2, levels: [2, 3], reward: 20, filled: [true, false]);
    final b = _board(
      [const MapEntry(10, 3), const MapEntry(11, 2)],
      [MbOrder(id: 1, levels: [2], reward: 6), done],
    );
    final p = MbTutorial.plan(b)!;
    expect(p.kind, MbTutKind.deliver);
    expect(p.a, 10);
    expect(p.b, 1);
  });

  test('siparis yoksa null; max seviye cifti birlesmez', () {
    expect(MbTutorial.plan(MbBoard()), isNull);
    final b = _board([const MapEntry(0, 8), const MapEntry(1, 8)], const []);
    expect(MbTutorial.closestPair(b, MbBoard.maxLevel), isNull);
  });
}
