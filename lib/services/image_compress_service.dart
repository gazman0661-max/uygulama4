import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressService {
  ImageCompressService._();

  static const int defaultMaxWidth = 1280;

  static const int defaultQuality = 70;

  static const int pngKeepAsIsBytes = 300 * 1024;

  static const int _embeddedRecompressMinChars = 400 * 1024;

  static final RegExp _dataUriRe = RegExp(
      r'data:image/(?:png|jpe?g|webp|heic|heif);base64,[A-Za-z0-9+/=]+');

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

  static Future<CompressedImage> compress(
    Uint8List bytes, {
    required bool isPng,
    int maxWidth = defaultMaxWidth,
    int quality = defaultQuality,
  }) async {
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
        return CompressedImage(bytes: bytes, mime: 'image/jpeg');
      }
      return CompressedImage(bytes: result, mime: 'image/webp');
    } catch (_) {
      return CompressedImage(bytes: bytes, mime: 'image/jpeg');
    }
  }
}

class CompressedImage {
  final Uint8List bytes;
  final String mime;
  const CompressedImage({required this.bytes, required this.mime});
}
