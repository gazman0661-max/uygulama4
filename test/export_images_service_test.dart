import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/services/export_images_service.dart';

void main() {
  final big = base64Encode(List<int>.filled(2000, 7));
  final tiny = base64Encode(List<int>.filled(10, 1));

  test('büyük görsel images/ klasörüne çıkar, referans göreli olur', () {
    final b = ExportImagesService.extract({
      'index.html': '<img src="data:image/webp;base64,$big"><div style="background:url(data:image/jpeg;base64,$big)">',
    });
    expect(b.hasImages, isTrue);
    expect(b.binaryFiles.keys, ['images/img-001.webp']); // aynı URI tek dosya
    expect(b.textFiles['index.html'], contains('src="images/img-001.webp"'));
    expect(b.textFiles['index.html'], isNot(contains('base64')));
  });

  test('aynı veri iki dosyada tek görsel; alt klasörde ../ öneki', () {
    final b = ExportImagesService.extract({
      'index.html': '<img src="data:image/png;base64,$big">',
      'sayfa/x.html': '<img src="data:image/png;base64,$big">',
    });
    expect(b.binaryFiles.length, 1);
    expect(b.textFiles['sayfa/x.html'], contains('../images/img-001.png'));
  });

  test('küçük görsel satır içi kalır, görsel yoksa paket boş', () {
    final b = ExportImagesService.extract({'index.html': '<img src="data:image/png;base64,$tiny">'});
    expect(b.hasImages, isFalse);
    expect(b.textFiles['index.html'], contains('base64,$tiny'));
  });
}
