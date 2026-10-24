import 'merge_board.dart';

/// MOD 2 OGRETICI MANTIGI (saf, ekran yok -> test edilebilir).
///
/// Mod 1'deki gibi "goster-yaptir": ekran, tahtaya bakip siradaki EN FAYDALI hamleyi
/// gosterir (el animasyonu + parlayan halka + kisa balon). Senaryo sabit degildir,
/// tahtanin o anki haline uyar; boylece oyuncu ne yaparsa yapsin yonlendirme dogru kalir.
///
/// Onceligi:
///  1) Siparise teslim edilebilen bir obje varsa -> TESLIM (dokun ya da karta birak)
///  2) Siparisin istedigi seviyenin altinda ayni seviyeden iki obje varsa -> BIRLESTIR
///  3) Yoksa -> URET
enum MbTutKind { spawn, merge, deliver }

class MbTutPlan {
  final MbTutKind kind;

  /// merge: birinci hucre | deliver: objenin hucresi | spawn: -1
  final int a;

  /// merge: ikinci hucre | deliver: siparis indeksi | spawn: -1
  final int b;

  /// merge: birlestirilen seviye | deliver: teslim edilen seviye | spawn: 1
  final int level;

  const MbTutPlan(this.kind, this.a, this.b, this.level);

  String get sig => '${kind.name}-$a-$b-$level';
}

class MbTutorial {
  MbTutorial._();

  /// Tahtaya gore siradaki adim. Gosterilecek bir sey yoksa (ornegin tahta dolu ve
  /// birlesecek cift yok) null.
  static MbTutPlan? plan(MbBoard board) {
    if (board.orders.isEmpty) return null;
    // Yarisi dolmus siparis once; yoksa ilk siparis.
    var first = board.orders.indexWhere((o) => !o.complete && o.filled.any((f) => f));
    if (first < 0) first = 0;
    final order = <int>[
      first,
      for (var i = 0; i < board.orders.length; i++)
        if (i != first) i,
    ];

    // 1) Teslim edilebilir obje.
    for (final oi in order) {
      final o = board.orders[oi];
      for (var k = 0; k < o.levels.length; k++) {
        if (o.filled[k]) continue;
        final cell = board.cells.indexOf(o.levels[k]);
        if (cell >= 0) return MbTutPlan(MbTutKind.deliver, cell, oi, o.levels[k]);
      }
    }

    // 2) Hedef siparisin en dusuk bos kaleminin altindaki seviyelerde birlestirme.
    final o = board.orders[first];
    var need = 0;
    for (var k = 0; k < o.levels.length; k++) {
      if (!o.filled[k]) {
        need = o.levels[k];
        break;
      }
    }
    for (var l = need - 1; l >= 1; l--) {
      final pair = closestPair(board, l);
      if (pair != null) return MbTutPlan(MbTutKind.merge, pair[0], pair[1], l);
    }

    // 3) Uret (tahta doluysa gosterecek bir sey yok).
    if (board.isFull) return null;
    return const MbTutPlan(MbTutKind.spawn, -1, -1, 1);
  }

  /// [level] seviyesindeki birbirine EN YAKIN iki hucre (izgara mesafesi), yoksa null.
  static List<int>? closestPair(MbBoard board, int level) {
    if (level >= MbBoard.maxLevel) return null; // max seviye birlesmez
    final idx = <int>[
      for (var i = 0; i < board.cells.length; i++)
        if (board.cells[i] == level) i,
    ];
    if (idx.length < 2) return null;
    var best = <int>[idx[0], idx[1]];
    var bestD = 1 << 30;
    for (var i = 0; i < idx.length; i++) {
      for (var j = i + 1; j < idx.length; j++) {
        final dr = (idx[i] ~/ MbBoard.cols - idx[j] ~/ MbBoard.cols).abs();
        final dc = (idx[i] % MbBoard.cols - idx[j] % MbBoard.cols).abs();
        final d = dr + dc;
        if (d < bestD) {
          bestD = d;
          best = <int>[idx[i], idx[j]];
        }
      }
    }
    return best;
  }
}
