// ============================================================================
// WORKER AKTİVASYON ÇAĞRILARI — OTOMATİK YENİDEN DENEME. 20.09.2026 eklendi
// (kanka isteği; bkz. cloudflare/worker/GUVENLIK_19_09_2026.md > "Bilerek
// YAPILMAYANLAR": "aktivasyon isteği ağ hatasıyla düşerse kredi harcanmadan
// bekler ama istemci otomatik yeniden denemiyor").
//
// SORUN: Sıkı modda worker, mini paket aktivasyonu ([MiniPackageService]) ve
// kalıcı rozet kaldırma ([WatermarkSyncService]) için doğrulanmış bir satın
// alma KREDİSİ arar; kredi ancak istek worker'a ULAŞIP başarılı olursa
// harcanır. İstemci bu iki çağrıyı best-effort (`unawaited` + hatayı yut)
// yaptığı için, ağ o an yoksa istek sessizce düşüyor, kredi D1'de
// harcanmadan bekliyor ve ikinci bir deneme HİÇ yapılmıyordu — kullanıcı
// parasını ödemiş, ama worker (dolayısıyla canlı site) bunu hiç öğrenmiyordu.
//
// ÇÖZÜM (AppState > _queueWorkerActivation): her aktivasyon isteği ÖNCE
// cihazda kalıcı bir kuyruğa yazılır, sonra denenir; başarısız olursa
// hatanın türüne göre ([SyncRetry]) ya kısa aralıklarla tekrar denenir, ya
// kuyrukta bekleyip bir sonraki tetikte (uygulama açılışı, giriş yapma,
// site yayınlama) denenir, ya da (tekrar denemek anlamsızsa) kuyruktan düşer.
//
// TEKRAR GÜVENLİ Mİ? Evet: worker her iki uçta da tekrarı tolere ediyor —
// mark-permanent zaten kalıcıysa kredi istemeden 200 döner; mini paket
// aktivasyonu, aynı (hesap, site) için son [CREDIT_IDEMPOTENCY_WINDOW_MS]
// (10 dk) içinde harcanmış bir kredi varsa (yanıtı kaybolan istek) tekrar
// kredi istemeden aynı sonucu döner.
// ============================================================================

/// Bir aktivasyon çağrısı başarısız olduğunda NE ZAMAN tekrar denenmesi
/// gerektiğini söyler.
enum SyncRetry {
  /// Geçici arıza (ağ yok, zaman aşımı, 408/429/5xx) — kısa aralıklarla,
  /// uygulama açıkken hemen tekrar dene.
  soon,

  /// Şu an anlamsız ama koşul değişince düzelebilir (giriş yapılmamış -> 401,
  /// site henüz yayınlanmamış -> 404) — kuyrukta BEKLE, bir sonraki tetikte
  /// (açılış / giriş / yayınlama) dene. Hemen tekrar deneme.
  later,

  /// Tekrar denemek işe yaramaz (403 sahip değil, 402 doğrulanmış kredi yok,
  /// diğer 4xx) — kuyruktan düşür.
  never,
}

/// Başarısız (2xx olmayan) bir worker cevabının yeniden deneme sınıfı.
SyncRetry syncRetryForStatus(int statusCode) {
  if (statusCode == 401 || statusCode == 404) return SyncRetry.later;
  if (statusCode == 408 || statusCode == 429 || statusCode >= 500) {
    return SyncRetry.soon;
  }
  return SyncRetry.never;
}

/// Cihazda kalıcı tutulan, worker'a henüz ulaşmamış tek bir aktivasyon isteği.
class PendingActivation {
  /// Mini paket aktivasyonu (MiniPackageService.activate).
  static const String kindMini = 'mini';

  /// Kalıcı rozet kaldırma (WatermarkSyncService.markPermanent).
  static const String kindWatermark = 'wm';

  final String kind;
  final String siteId;
  final DateTime queuedAt;

  const PendingActivation(this.kind, this.siteId, this.queuedAt);

  /// Aynı (tür, site) için kuyrukta TEK kayıt tutulur.
  String get key => '$kind|$siteId';

  /// SharedPreferences string listesi için "tür|siteId|kuyrugaGirisMs".
  /// (Proje id'leri sayısaldır, '|' içermez.)
  String encode() => '$kind|$siteId|${queuedAt.millisecondsSinceEpoch}';

  /// Bozuk/eksik bir kayıt için null döner (çağıran yok sayar).
  static PendingActivation? tryParse(String raw) {
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final ms = int.tryParse(parts[2]);
    if (parts[0].isEmpty || parts[1].isEmpty || ms == null) return null;
    return PendingActivation(
      parts[0],
      parts[1],
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }
}
