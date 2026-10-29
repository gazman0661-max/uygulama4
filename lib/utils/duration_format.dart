import '../localization/app_strings.dart';

/// Bir [Duration]'ı "1s 23dk" ya da "07:42" gibi kısa, okunur bir
/// geri sayım metnine çevirir. Enerji dolum sayacı ve reklam kilidi
/// sayacı için ortak kullanılır.
String formatCountdown(Duration d) {
  final total = d.inSeconds.clamp(0, 1 << 30);
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) {
    final u = _units();
    return '$hours${u.h} $minutes${u.m}';
  }
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// Secili dile gore kisa birim kisaltmalari (saat / dakika / gun).
({String h, String m, String d}) _units() {
  switch (AppStrings.instance.language) {
    case AppLanguage.tr:
      return (h: ' sa', m: ' dk', d: ' g');
    case AppLanguage.es:
      return (h: ' h', m: ' min', d: ' d');
    case AppLanguage.pt:
      return (h: ' h', m: ' min', d: ' d');
    case AppLanguage.de:
      return (h: ' Std', m: ' Min', d: ' T');
    case AppLanguage.fr:
      return (h: ' h', m: ' min', d: ' j');
    case AppLanguage.ru:
      return (h: ' ч', m: ' мин', d: ' д');
    case AppLanguage.en:
      return (h: 'h', m: 'm', d: 'd');
  }
}

/// Gorev yenilenme suresi gibi uzun sureler icin: "2 g 5 sa" / "3 sa 37 dk".
String formatLongCountdown(Duration d) {
  final u = _units();
  if (d.inHours >= 24) return '${d.inDays}${u.d} ${d.inHours % 24}${u.h}';
  return '${d.inHours}${u.h} ${d.inMinutes % 60}${u.m}';
}
