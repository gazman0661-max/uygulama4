import '../services/remote_tuning.dart';

/// TAKIM YARISI TAKVIMI (saf fonksiyonlar). Hafta Pazartesi 10:00'da doner (diger etkinliklerle ayni sinir).
///
/// Haftalar sirayla doner: NORMAL hafta (Merge Yarisi + Firlat Yarisi + Hafta Sonu etkinligi) ->
/// TAKIM YARISI haftasi (yalniz takim yarisi, diger etkinlikler KAPALI) -> normal hafta ...
/// Varsayilan: hafta numarasi CIFT ise takim yarisi haftasi (2 haftada bir). 2024-01-01 bir Pazartesi (hafta 0).
///
/// Uzaktan ayar (Remote Config): `team_race_every_weeks` (varsayilan 2; 0 = takim yarisi KAPALI, diger
/// etkinlikler her hafta calisir), `team_race_phase` (varsayilan 0; 0..every-1, hangi haftalarin takim yarisi olacagi).
/// Yarisin ortasinda DEGISTIRME: hafta sinirlari kayar.
class TeamRaceSchedule {
  TeamRaceSchedule._();

  /// Haftanin degistigi saat (yerel). Diger etkinliklerin 10:00 acilisiyla ayni.
  static const int startHour = 10;

  /// Testlerde false: eski (takim yarisi olmayan) takvim davranisi.
  static bool enabled = true;

  static int get everyWeeks => enabled ? RemoteTuning.i('team_race_every_weeks', 2).clamp(0, 8).toInt() : 0;

  static int get phase {
    final e = everyWeeks;
    return e <= 0 ? 0 : RemoteTuning.i('team_race_phase', 0).clamp(0, e - 1).toInt();
  }

  /// [n]'i [startHour] saat geri alir (takvim gunu hesabi; yaz/kis saati kaymasindan etkilenmez).
  static DateTime _shift(DateTime n) => DateTime(n.year, n.month, n.day, n.hour - startHour, n.minute, n.second);

  /// Pazartesi 10:00'da degisen hafta numarasi.
  static int weekIdOf(DateTime n) {
    final s = _shift(n);
    return DateTime.utc(s.year, s.month, s.day).difference(DateTime.utc(2024, 1, 1)).inDays ~/ 7;
  }

  /// Bu hafta numarasi takim yarisi haftasi mi?
  static bool isRaceWeekId(int w) {
    final e = everyWeeks;
    if (e <= 0 || w < 0) return false;
    return (w - phase) % e == 0;
  }

  /// [n] aninda takim yarisi haftasi mi? (Pzt 10:00 - ertesi Pzt 10:00)
  static bool isRaceWeekAt(DateTime n) => isRaceWeekId(weekIdOf(n));

  static DateTime startOfWeek(int w) => DateTime(2024, 1, 1 + w * 7, startHour);
  static DateTime endOfWeek(int w) => DateTime(2024, 1, 1 + (w + 1) * 7, startHour);

  /// [n]'den SONRA acilacak ilk takim yarisi haftasi (yoksa -1; yarisin KENDISI aciksa o hafta sayilmaz).
  static int nextRaceWeekAfter(DateTime n) {
    if (everyWeeks <= 0) return -1;
    final w = weekIdOf(n);
    for (var c = w; c <= w + everyWeeks + 1; c++) {
      if (isRaceWeekId(c) && startOfWeek(c).isAfter(n)) return c;
    }
    return -1;
  }
}
