import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 28.09.2026 eklendi (kanka isteği) — YAYIN ANINDA büyük data URI görselleri
/// HTML'den çıkarıp worker'a (`/api/publish-image`, foto başına 1 istek) yükler
/// ve HTML'deki referansı `img/<hash>.<uzantı>` ile değiştirir.
///
/// Neden: HTML birkaç yüz KB kalır (8 MB tek-dosya sınırı sorun olmaz), fotoğraflar
/// Google Görseller'de çıkabilir, tarayıcı görselleri ayrı önbelleğe alır.
///
/// Editör/generator DEĞİŞMEDİ: onlar data URI üretmeye devam eder, uygulama içi
/// önizleme ve ZIP indirme aynen çalışır. Dönüşüm yalnızca yayınlanan kopyada olur.
///
/// GÜVENLİ DÜŞÜŞ: herhangi bir görsel yüklenemezse (ağ hatası, eski worker, limit
/// vb.) O görsel data URI olarak HTML'de KALIR — yayın bu yüzden asla başarısız
/// olmaz. Sunucu dosya adını içeriğin SHA-256'sından kendisi üretir; aynı görsel
/// tekrar yüklenirse R2'ye yeniden yazılmaz.
class PublishImageService {
  PublishImageService._();

  /// base64 metin uzunluğu bu değerin altındaki küçük görseller (logo/ikon)
  /// HTML'de gömülü kalır — her biri için ayrı istek atmaya değmez.
  static const int minExternalizeChars = 20 * 1024;

  /// Aynı anda en fazla bu kadar yükleme (telefonu/ağı boğmasın).
  static const int _parallel = 4;

  static final RegExp _dataUriRe =
      RegExp(r'data:image/(?:png|jpe?g|webp|gif);base64,([A-Za-z0-9+/=]+)');
  static final RegExp _serverPathRe =
      RegExp(r'^img/[a-f0-9]{32}\.(?:webp|png|jpg|gif)$');

  /// [files] içindeki .html dosyalarını işler, yeni bir harita döner
  /// (girdiyi değiştirmez). [endpoint]: `<worker>/api/publish-image`.
  static Future<Map<String, String>> externalize({
    required Map<String, String> files,
    required Uri endpoint,
    required String siteId,
    String? ownerToken,
    Map<String, String> authHeaders = const {},
  }) async {
    // 1) Yüklenecek benzersiz data URI'leri topla (aynı görsel birden çok
    //    sayfada geçse de TEK kez yüklenir).
    final unique = <String>{};
    for (final e in files.entries) {
      if (!e.key.toLowerCase().endsWith('.html')) continue;
      for (final m in _dataUriRe.allMatches(e.value)) {
        if (m.group(1)!.length >= minExternalizeChars) unique.add(m.group(0)!);
      }
    }
    if (unique.isEmpty) return files;

    // 2) Sınırlı paralellikle yükle.
    final uploaded = <String, String>{}; // data URI -> 'img/<hash>.<ext>'
    final queue = unique.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final uri = queue.removeLast();
        final path = await _uploadWithRetry(
          uri: uri,
          endpoint: endpoint,
          siteId: siteId,
          ownerToken: ownerToken,
          authHeaders: authHeaders,
        );
        if (path != null) uploaded[uri] = path;
      }
    }

    await Future.wait(List.generate(
        _parallel < queue.length ? _parallel : queue.length, (_) => worker()));
    if (uploaded.isEmpty) return files;

    // 3) HTML'leri yeniden yaz. Alt klasördeki sayfa için yol göreli kalsın
    //    diye derinlik kadar '../' eklenir (kök sayfalar için boş).
    final out = Map<String, String>.from(files);
    for (final e in files.entries) {
      if (!e.key.toLowerCase().endsWith('.html')) continue;
      final depth = '/'.allMatches(e.key).length;
      final up = '../' * depth;
      out[e.key] = e.value.replaceAllMapped(_dataUriRe, (m) {
        final p = uploaded[m.group(0)!];
        return p == null ? m.group(0)! : '$up$p';
      });
    }
    return out;
  }

  static Future<String?> _uploadWithRetry({
    required String uri,
    required Uri endpoint,
    required String siteId,
    required String? ownerToken,
    required Map<String, String> authHeaders,
  }) async {
    Uint8List bytes;
    try {
      bytes = base64Decode(uri.substring(uri.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/octet-stream',
                'x-site-id': siteId,
                if (ownerToken != null && ownerToken.trim().isNotEmpty)
                  'x-owner-token': ownerToken.trim(),
                ...authHeaders,
              },
              body: bytes,
            )
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 200) {
          final path = (jsonDecode(res.body) as Map)['path'];
          if (path is String && _serverPathRe.hasMatch(path)) return path;
          return null;
        }
        // 4xx: tekrar denemenin anlamı yok (yetki/format/boyut/limit).
        if (res.statusCode >= 400 && res.statusCode < 500) return null;
      } catch (_) {
        // ağ hatası/zaman aşımı: bir kez daha dene
      }
    }
    return null;
  }
}
