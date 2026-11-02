import 'remote_tuning.dart';

/// Gecis reklami sikligi: deney (A/B) varyanti + "ne zaman gosterilir" karari.
/// SAF Dart (eklenti yok) oldugu icin birim testle denenir.
///
/// Varyant A = her 3 bolumde bir (eski davranis), B = her 2 bolumde bir.
/// Remote Config'te `inter_every_chapters` / `mb_inter_every_chapters` YAYINLANMISSA
/// deney devre disi kalir ve panelden gelen deger herkese uygulanir.
class InterstitialPlan {
  InterstitialPlan._();

  static const int everyA = 3;
  static const int everyB = 2;

  /// Rastgele sayidan varyant: cift = A, tek = B.
  static String variantFor(int roll) => roll.isEven ? 'A' : 'B';

  /// Kac bolumde bir gecis reklami gosterilsin.
  static int every(String key, String variant) {
    if (RemoteTuning.has(key)) return RemoteTuning.i(key, everyA).clamp(1, 20).toInt();
    return variant == 'B' ? everyB : everyA;
  }

  /// Ilk [grace] bolum muaf; sonra sayac [every]'e ulasinca reklam zamani.
  static bool due({required int lifetime, required int grace, required int since, required int every}) =>
      lifetime > grace && since >= every;
}
