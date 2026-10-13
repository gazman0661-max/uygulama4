import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 06.09.2026 eklendi — Galeri/kapak fotoğrafı seçiminde JPEG yerine
/// WebP'ye geçiş için ortak yardımcı (bkz. gallery_picker_field.dart ve
/// preview_screen.dart._pickImageForGallery). Amaç: aynı görsel kalitede
/// JPEG'e göre ~%25-35 daha küçük dosya, tek noktadan yönetilen
/// maxWidth/quality.
///
/// flutter_image_compress her iki platformda da native/derlenmiş kod
/// kullanıyor (Android: kendi native encoder'ı, iOS: gömülü libwebp) —
/// Dart tarafında ham pikselle uğraşmıyoruz, bu yüzden RAM riski
/// image_picker'ın kendi sıkıştırmasından farklı değil.
///
/// TASARIM KARARI — PNG'LER WEBP'YE ÇEVRİLMİYOR: PNG kaynaklar genelde
/// şeffaf logo/ikon türünde oluyor; lossy WebP keskin kenar/şeffaflıkta
/// artefakt yaratabilir. Bu yüzden PNG olarak seçilen görseller olduğu
/// gibi (sıkıştırılmadan) bırakılıyor — sadece foto niteliğindeki
/// (jpg/heic/diğer) görseller WebP'ye çevriliyor.
class ImageCompressService {
  ImageCompressService._();

  /// Galeri (çoklu) görseller için hedef genişlik — thumbnail
  /// büyüklüğünde göz farkı yaratmaz ama dosya boyutunu belirgin küçültür.
  static const int defaultMaxWidth = 1280;

  /// WebP kalite ölçeği JPEG'den farklı davranıyor; JPEG q78'in görsel
  /// karşılığı için q70 civarı test edildi/kalibre edildi.
  static const int defaultQuality = 70;

  /// Bu boyutun altındaki PNG'ler (tipik logo/ikon) dokunulmadan kalır.
  static const int pngKeepAsIsBytes = 300 * 1024;

  /// Yayın öncesi: bir HTML içindeki bu boyutun (base64 metin uzunluğu)
  /// üstündeki gömülü görseller yeniden sıkıştırılır.
  static const int _embeddedRecompressMinChars = 400 * 1024;

  static final RegExp _dataUriRe = RegExp(
      r'data:image/(?:png|jpe?g|webp|heic|heif);base64,[A-Za-z0-9+/=]+');

  /// 28.09.2026 eklendi — YAYIN ÖNCESİ güvenlik ağı. Eskiden eklenmiş
  /// (sıkıştırılmamış PNG dahil) görseller projede zaten büyük data URI
  /// olarak duruyor; kullanıcı yeniden fotoğraf seçmeden de yayınlama
  /// başarılı olsun diye [html] içindeki büyük gömülü görselleri WebP'ye
  /// çevirir. Küçük görsellere ve sıkıştırma başarısız olanlara dokunmaz;
  /// hata olursa orijinal HTML aynen döner (yayın asla bu yüzden bozulmaz).
  static Future<String> optimizeEmbeddedImages(String html) async {
    if (html.length < _embeddedRecompressMinChars) return html;
    final matches = _dataUriRe.allMatches(html).toList();
    if (matches.isEmpty) return html;
    final out = StringBuffer();
    var last = 0;
    for (final m in matches) {
      out.write(html.substring(last, m.start));
      final uri = m.group(0)!;
      last = m.end;
      if (uri.length < _embeddedRecompressMinChars) {
        out.write(uri);
        continue;
      }
      try {
        final b64 = uri.substring(uri.indexOf(',') + 1);
        final raw = base64Decode(b64);
        final result = await FlutterImageCompress.compressWithList(
          raw,
          minWidth: 1280,
          minHeight: 1280,
          quality: 72,
          format: CompressFormat.webp,
        );
        if (result.isNotEmpty && result.length < raw.length) {
          out.write('data:image/webp;base64,${base64Encode(result)}');
        } else {
          out.write(uri);
        }
      } catch (_) {
        out.write(uri);
      }
    }
    out.write(html.substring(last));
    return out.toString();
  }

  /// [bytes]: ham görsel baytları (image_picker'dan gelen, zaten
  /// maxWidth ile native olarak ön-downsample edilmiş olabilir).
  /// [isPng]: kaynağın PNG olup olmadığı (dosya adı/uzantısından
  /// belirlenir) — true ise sıkıştırma uygulanmadan aynı bayt/mime döner.
  static Future<CompressedImage> compress(
    Uint8List bytes, {
    required bool isPng,
    int maxWidth = defaultMaxWidth,
    int quality = defaultQuality,
  }) async {
    // 28.09.2026 GÜNCELLENDİ (kanka isteği — 413 yayınlama hatası): PNG'ler
    // ESKİDEN hiç sıkıştırılmıyordu; ekran görüntüsü/PNG fotoğraf seçen
    // kullanıcıda tek görsel birkaç MB base64 olup index.html'i worker'ın
    // 8 MB tek-dosya sınırının üstüne çıkarıyor, yayınlama "(413)" ile
    // başarısız oluyordu. Artık SADECE küçük PNG'ler (logo/ikon, ≤ 300 KB)
    // olduğu gibi kalıyor; büyük PNG'ler WebP'ye (alfa/şeffaflık korunur)
    // çevriliyor. Sonuç orijinalden küçük değilse orijinal korunur.
    if (isPng) {
      if (bytes.length <= pngKeepAsIsBytes) {
        return CompressedImage(bytes: bytes, mime: 'image/png');
      }
      try {
        final result = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: maxWidth,
          minHeight: maxWidth,
          quality: 80,
          format: CompressFormat.webp,
        );
        if (result.isNotEmpty && result.length < bytes.length) {
          return CompressedImage(bytes: result, mime: 'image/webp');
        }
      } catch (_) {}
      return CompressedImage(bytes: bytes, mime: 'image/png');
    }
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: maxWidth,
        quality: quality,
        format: CompressFormat.webp,
      );
      if (result.isEmpty) {
        // Sıkıştırma boş sonuç döndürdüyse (desteklenmeyen bir durum)
        // orijinal baytlarla devam et — görsel eklenmemiş kalmasın.
        return CompressedImage(bytes: bytes, mime: 'image/jpeg');
      }
      return CompressedImage(bytes: result, mime: 'image/webp');
    } catch (_) {
      // Herhangi bir sıkıştırma hatasında orijinal baytlara düş —
      // kullanıcı en azından görseli ekleyebilsin.
      return CompressedImage(bytes: bytes, mime: 'image/jpeg');
    }
  }
}

class CompressedImage {
  final Uint8List bytes;
  final String mime;
  const CompressedImage({required this.bytes, required this.mime});
}
