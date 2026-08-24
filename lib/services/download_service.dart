import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A modu ve B modu için ortak indirme/paylaşma katmanı.
/// Not: uygulama sunucusuz çalışıyor — burada yalnızca dosyayı kullanıcının
/// cihazına yazıp paylaşım/kaydetme menüsünü açıyoruz; barındırma
/// (hosting) sorumluluğu tamamen kullanıcıda kalıyor.
class DownloadService {
  /// A modu: tek bir .html dosyasını cihaza yazar ve paylaşım menüsünü açar.
  static Future<File> saveSingleHtml({
    required String html,
    String fileName = 'site.html',
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(html, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/html')],
      text: 'Sitora ile üretildi 🚀',
    );
    return file;
  }

  /// B modu: dosya haritasını (index.html, style.css, urunler.html, ...)
  /// tek bir .zip haline getirir ve paylaşım menüsünü açar.
  static Future<File> saveMultiPageZip({
    required Map<String, String> files,
    String zipFileName = 'site.zip',
  }) async {
    final archive = Archive();
    for (final entry in files.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('ZIP oluşturulamadı, lütfen tekrar deneyiniz.');
    }

    final dir = await getTemporaryDirectory();
    final zipFile = File('${dir.path}/$zipFileName');
    await zipFile.writeAsBytes(zipData);

    await Share.shareXFiles(
      [XFile(zipFile.path, mimeType: 'application/zip')],
      text: 'Sitora ile üretildi 🚀 — zip\'i açıp istediğin hosting\'e yükleyebilirsin.',
    );
    return zipFile;
  }

  /// A modu (gerçek "indirme"): kullanıcıya sistemin kayıt/kaydet penceresini
  /// açar; kullanıcı dosya adını değiştirebilir ve kayıt konumunu (İndirilenler,
  /// Belgeler, herhangi bir klasör...) kendisi seçer. Paylaşım ekranı AÇILMAZ.
  ///
  /// Döner: kullanıcı gerçekten kaydettiyse true, "İptal"e bastıysa false.
  static Future<bool> pickAndSaveHtml({
    required String html,
    String suggestedFileName = 'site.html',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(html));
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Siteni Kaydet',
      fileName: suggestedFileName,
      bytes: bytes,
    );
    return savedPath != null;
  }

  /// B modu (gerçek "indirme"): dosya haritasını zip'e sarar, ardından
  /// kullanıcıya kayıt penceresi açarak dosya adı ve konumunu kendisinin
  /// seçmesini sağlar.
  ///
  /// Döner: kullanıcı gerçekten kaydettiyse true, "İptal"e bastıysa false.
  static Future<bool> pickAndSaveZip({
    required Map<String, String> files,
    String suggestedFileName = 'site.zip',
  }) async {
    final archive = Archive();
    for (final entry in files.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('ZIP oluşturulamadı, lütfen tekrar deneyiniz.');
    }

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Siteni Kaydet',
      fileName: suggestedFileName,
      bytes: Uint8List.fromList(zipData),
    );
    return savedPath != null;
  }

  /// QR kod ekranı (gerçek "indirme"): PNG baytlarını kullanıcıya kayıt
  /// penceresi açarak kaydettirir; dosya adı ve konumunu kendisi seçer.
  ///
  /// Döner: kullanıcı gerçekten kaydettiyse true, "İptal"e bastıysa false.
  static Future<bool> pickAndSavePng({
    required Uint8List pngBytes,
    String suggestedFileName = 'qr-kod.png',
  }) async {
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'PNG Olarak Kaydet',
      fileName: suggestedFileName,
      bytes: pngBytes,
    );
    return savedPath != null;
  }

  /// QR kod ekranı: PNG baytlarını geçici bir dosyaya yazıp paylaşım
  /// menüsünü açar.
  static Future<void> sharePng({
    required Uint8List pngBytes,
    String fileName = 'qr-kod.png',
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'Sitora ile üretildi 🚀',
    );
  }

  /// B modunda önizleme ekranı için: dosya haritasını geçici bir klasöre
  /// GERÇEK dosyalar olarak yazar (index.html, style.css, urunler.html...)
  /// böylece WebView bunları `loadFile` ile açtığında <a href="urunler.html">
  /// gibi linkler normal dosya sistemi üzerinden çalışır.
  static Future<String> writeFilesForPreview(
      Map<String, String> files) async {
    final dir = await getTemporaryDirectory();
    final previewDir = Directory('${dir.path}/preview_multi');
    if (await previewDir.exists()) {
      await previewDir.delete(recursive: true);
    }
    await previewDir.create(recursive: true);

    for (final entry in files.entries) {
      final f = File('${previewDir.path}/${entry.key}');
      await f.writeAsString(entry.value, encoding: utf8);
    }

    final indexPath = '${previewDir.path}/index.html';
    return indexPath;
  }
}
