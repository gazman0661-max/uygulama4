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
    if (isPng) {
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
