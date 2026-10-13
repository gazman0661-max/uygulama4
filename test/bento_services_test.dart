import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/templates/html/shared_html_blocks.dart';

void main() {
  group('bentoBlockSizes', () {
    test('3..60 görsel: toplam tutar, her blok 3-5 arası (boşluk/yetim yok)', () {
      for (var n = 3; n <= 60; n++) {
        final sizes = bentoBlockSizes(n);
        expect(sizes.fold<int>(0, (a, b) => a + b), n, reason: 'n=$n');
        expect(sizes.every((x) => x >= 3 && x <= 5), isTrue, reason: 'n=$n -> $sizes');
      }
    });

    test('örnekler', () {
      expect(bentoBlockSizes(5), [5]);
      expect(bentoBlockSizes(6), [3, 3]);
      expect(bentoBlockSizes(7), [3, 4]);
      expect(bentoBlockSizes(12), [3, 4, 5]);
    });
  });

  group('galleryBlockHtml bento', () {
    List<Map<String, String?>> imgs(int n) =>
        List.generate(n, (i) => {'url': 'https://x.test/$i.jpg', 'caption': null});

    test('5 görsel tek blok (gb-n5) ve 5 kart, 5 lightbox', () {
      final html = galleryBlockHtml(title: 'Galeri', images: imgs(5), style: 'bento');
      expect('class="gb-block gb-n5"'.allMatches(html).length, 1);
      expect('gallery-bento-item'.allMatches(html).length, 5);
      expect('class="gallery-lightbox"'.allMatches(html).length, 5);
    });

    test('7 görsel iki blok, ikincisi gb-flip', () {
      final html = galleryBlockHtml(title: 'Galeri', images: imgs(7), style: 'bento');
      expect(html, contains('gb-n3'));
      expect(html, contains('gb-n4 gb-flip'));
    });

    test('3 görselden azsa grid a düşer', () {
      final html = galleryBlockHtml(title: 'Galeri', images: imgs(2), style: 'bento');
      expect(html, isNot(contains('gb-block')));
    });
  });

  group('serviceGridColumns', () {
    test('son satırda yarım kart bırakmayan sütun sayıları', () {
      expect(serviceGridColumns(1), 1);
      expect(serviceGridColumns(2), 2);
      expect(serviceGridColumns(3), 3);
      expect(serviceGridColumns(4), 4);
      expect(serviceGridColumns(5), 3);
      expect(serviceGridColumns(6), 3);
      expect(serviceGridColumns(8), 4);
      expect(serviceGridColumns(9), 3);
    });

    test('serviceListBlockHtml --svc-cols yazar', () {
      final html = serviceListBlockHtml(title: 'Hizmetler', services: [
        {'name': 'A', 'duration': null, 'price': ''},
        {'name': 'B', 'duration': null, 'price': ''},
        {'name': 'C', 'duration': null, 'price': ''},
        {'name': 'D', 'duration': null, 'price': ''},
      ]);
      expect(html, contains('--svc-cols:4'));
    });
  });
}
