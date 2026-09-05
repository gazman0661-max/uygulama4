import 'dart:collection';
import 'package:flutter/foundation.dart';

/// ============================================================================
/// SITORA HATA KAYITLARI (USB/adb OLMADAN GÖRÜNTÜLEME) — 05.09.2026 eklendi
/// ============================================================================
/// Kanka'nın telefonunun USB'si arızalı olduğu için `adb logcat` her zaman
/// kullanılamıyor. Bu servis, önemli olayları (özellikle bulut senkron
/// hatalarını, bkz. AppState._syncProjectToCloudIfSignedIn /
/// UserDataService.fetchProjects) BELLEKTE tutan basit bir halka tampon.
///
/// Ayarlar > "Hata Kayıtları" ekranı (bkz. debug_log_screen.dart) bu listeyi
/// gösterir, "Kopyala" ile panoya alıp buradan/mesajla paylaşılabilir.
///
/// ÖNEMLİ SINIR: bu KALICI bir kayıt DEĞİL — sadece RAM'de tutulur, uygulama
/// tamamen kapanıp yeniden açıldığında (veya "Son uygulamalar"dan kapatılıp
/// süreç öldürüldüğünde) sıfırlanır. Yani akış şu olmalı: sorunu üret (proje
/// oluştur/yayınla) → uygulamayı KAPATMADAN Ayarlar > Hata Kayıtları'na gir
/// → kopyala. Kalıcı/uzun vadeli analiz için yine Firebase Crashlytics +
/// Console kullanılmalı, bu servis onun yerine geçmez.
/// ============================================================================
class DebugLogService {
  DebugLogService._();
  static final DebugLogService instance = DebugLogService._();

  static const int _maxEntries = 200;
  final Queue<String> _entries = ListQueue<String>();

  /// Eskiden yeniye sıralı kayıtlar. Ekran bunu ters çevirip en yeniyi üstte
  /// gösterir (bkz. debug_log_screen.dart).
  List<String> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// Bir olayı kaydeder: hem debugPrint ile (USB çalışıyorsa adb'den de
  /// görünsün) hem de bellekteki listeye ekler.
  void log(String message) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final ts = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final line = '[$ts] $message';
    debugPrint(line);
    _entries.addLast(line);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
  }

  void clear() => _entries.clear();
}
