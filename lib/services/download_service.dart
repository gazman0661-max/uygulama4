import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DownloadService {
  static Future<File> saveSingleHtml({
    required String html,
    String fileName = 'site.html',
    bool isEnglish = false,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(html, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/html')],
      text: isEnglish ? 'Made with MySitora 🚀' : 'MySitora ile üretildi 🚀',
    );
    return file;
  }

  static Future<File> saveMultiPageZip({
    required Map<String, String> files,
    String zipFileName = 'site.zip',
    bool isEnglish = false,
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
      text: isEnglish
          ? 'Made with MySitora 🚀 — unzip it and upload to any hosting you like.'
          : 'MySitora ile üretildi 🚀 — zip\'i açıp istediğin hosting\'e yükleyebilirsin.',
    );
    return zipFile;
  }

  static Future<bool> pickAndSaveHtml({
    required String html,
    String suggestedFileName = 'site.html',
    bool isEnglish = false,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(html));
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: isEnglish ? 'Save Your Site' : 'Siteni Kaydet',
      fileName: suggestedFileName,
      bytes: bytes,
    );
    return savedPath != null;
  }

  static Future<bool> pickAndSaveZip({
    required Map<String, String> files,
    String suggestedFileName = 'site.zip',
    bool isEnglish = false,
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
      dialogTitle: isEnglish ? 'Save Your Site' : 'Siteni Kaydet',
      fileName: suggestedFileName,
      bytes: Uint8List.fromList(zipData),
    );
    return savedPath != null;
  }

  static Future<bool> pickAndSavePng({
    required Uint8List pngBytes,
    String suggestedFileName = 'qr-kod.png',
    bool isEnglish = false,
  }) async {
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: isEnglish ? 'Save as PNG' : 'PNG Olarak Kaydet',
      fileName: suggestedFileName,
      bytes: pngBytes,
    );
    return savedPath != null;
  }

  static Future<void> sharePng({
    required Uint8List pngBytes,
    String fileName = 'qr-kod.png',
    bool isEnglish = false,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: isEnglish ? 'Made with MySitora 🚀' : 'MySitora ile üretildi 🚀',
    );
  }

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
