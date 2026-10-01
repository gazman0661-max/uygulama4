enum SyncRetry {
  soon,

  later,

  never,
}

SyncRetry syncRetryForStatus(int statusCode) {
  if (statusCode == 401 || statusCode == 404) return SyncRetry.later;
  if (statusCode == 408 || statusCode == 429 || statusCode >= 500) {
    return SyncRetry.soon;
  }
  return SyncRetry.never;
}

class PendingActivation {
  static const String kindMini = 'mini';

  static const String kindWatermark = 'wm';

  final String kind;
  final String siteId;
  final DateTime queuedAt;

  const PendingActivation(this.kind, this.siteId, this.queuedAt);

  String get key => '$kind|$siteId';

  String encode() => '$kind|$siteId|${queuedAt.millisecondsSinceEpoch}';

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
