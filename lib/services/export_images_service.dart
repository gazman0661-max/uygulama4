import 'dart:convert';
import 'dart:typed_data';

/// İndirme paketi: metin dosyaları + ayrı görsel dosyaları.
class ExportBundle {
  final Map<String, String> textFiles;
  final Map<String, Uint8List> binaryFiles;
  const ExportBundle({required this.textFiles, required this.binaryFiles});
  bool get hasImages => binaryFiles.isNotEmpty;
}

/// 06.10.2026 eklendi (kanka isteği) — Freelancer teslimatı: indirilen sitede base64 gömülü
/// görseller `images/` klasörüne GERÇEK dosya olarak çıkarılır, HTML/CSS içindeki
/// referanslar `images/img-001.webp` gibi göreli yollara çevrilir. Bu sayede müşteriye
/// `index.html + /images` yapısı teslim edilir; dosya da şişmez, görseller tek tek değiştirilebilir.
///
/// Saf Dart (eklenti yok): yalnızca indirme kopyasında çalışır; yayındaki siteye ve projenin
/// kayıtlı HTML'ine dokunmaz. Görsel baytları olduğu gibi yazılır (yeniden sıkıştırma yok).
/// Çözülemeyen/çok küçük (< [minBytes]) görseller satır içi kalır.
class ExportImagesService {
  ExportImagesService._();

  static final RegExp _dataUriRe = RegExp(r'data:image/(png|jpe?g|webp|gif);base64,([A-Za-z0-9+/=]+)');
  static const _textExts = ['.html', '.htm', '.css', '.js'];

  static String _ext(String mimeSub) {
    switch (mimeSub) {
      case 'jpeg':
      case 'jpg':
        return 'jpg';
      default:
        return mimeSub; // png, webp, gif
    }
  }

  static ExportBundle extract(
    Map<String, String> files, {
    String folder = 'images',
    int minBytes = 1024,
  }) {
    final binary = <String, Uint8List>{};
    final byUri = <String, String?>{}; // data URI -> klasör içi dosya adı (null: satır içi bırak)
    var counter = 0;

    String? register(String uri, String mimeSub, String b64) {
      if (byUri.containsKey(uri)) return byUri[uri];
      try {
        final bytes = base64Decode(b64);
        if (bytes.length < minBytes) {
          byUri[uri] = null;
          return null;
        }
        counter++;
        final name = 'img-${counter.toString().padLeft(3, '0')}.${_ext(mimeSub)}';
        binary['$folder/$name'] = bytes;
        byUri[uri] = name;
        return name;
      } catch (_) {
        byUri[uri] = null;
        return null;
      }
    }

    final out = <String, String>{};
    for (final entry in files.entries) {
      final key = entry.key;
      final isText = _textExts.any(key.toLowerCase().endsWith);
      if (!isText || !entry.value.contains('data:image/')) {
        out[key] = entry.value;
        continue;
      }
      // Alt klasördeki dosyalar için ../ öneki (kök: boş).
      final depth = '/'.allMatches(key).length;
      final up = '../' * depth;
      out[key] = entry.value.replaceAllMapped(_dataUriRe, (m) {
        final name = register(m.group(0)!, m.group(1)!, m.group(2)!);
        return name == null ? m.group(0)! : '$up$folder/$name';
      });
    }
    return ExportBundle(textFiles: out, binaryFiles: binary);
  }
}
