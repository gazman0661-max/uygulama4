import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/services/favicon_publish.dart';
import 'package:sitora_ai/templates/html/shared_html_blocks.dart';

void main() {
  group('faviconSvg', () {
    test('tr: i -> İ, ı -> I', () {
      expect(faviconSvg('istanbul Kafe', '#112233', '#FFFFFF'), contains('>İ</text>'));
      expect(faviconSvg('ısı Ltd', '#112233', '#FFFFFF'), contains('>I</text>'));
    });

    test('en: i -> I', () {
      expect(faviconSvg('istanbul', '#112233', '#FFFFFF', lang: 'en'), contains('>I</text>'));
    });

    test('geçersiz renk varsayılana düşer', () {
      final svg = faviconSvg('Acme', 'linear-gradient(red,blue)', 'rgb(1,2,3)');
      expect(svg, contains('fill="#3D5AFE"'));
      expect(svg, contains('fill="#FFFFFF"'));
    });

    test('emoji ile başlayan başlıkta ilk harf/rakam alınır; hiç yoksa S', () {
      expect(faviconSvg('🍕 Pizza', '#111', '#fff'), contains('>P</text>'));
      expect(faviconSvg('🍕🍕', '#111', '#fff'), contains('>S</text>'));
    });
  });

  group('externalizeFavicon', () {
    final link = faviconLinkHtml('Acme', '#112233', '#FFFFFF');
    Map<String, String> site() => {
          'index.html': '<head>$link</head>',
          'hizmetler.html': '<head>${faviconLinkHtml('Zeta', '#112233', '#FFFFFF')}</head>',
          'style.css': 'body{}',
        };

    test('favicon.svg üretir ve tüm sayfalarda /favicon.svg e çevirir', () {
      final out = externalizeFavicon(site());
      expect(out[faviconPublishPath], startsWith('<svg'));
      expect(out[faviconPublishPath], contains('>A</text>')); // index'in harfi
      expect(out['index.html'], contains(faviconLinkPublished));
      expect(out['hizmetler.html'], contains(faviconLinkPublished));
      expect(out['index.html'], isNot(contains('data:image/svg+xml')));
    });

    test('girdi map i değişmez', () {
      final input = site();
      externalizeFavicon(input);
      expect(input.containsKey(faviconPublishPath), isFalse);
    });

    test('favicon.svg zaten varsa dokunmaz', () {
      final input = site()..['favicon.svg'] = '<svg>custom</svg>';
      final out = externalizeFavicon(input);
      expect(out['favicon.svg'], '<svg>custom</svg>');
      expect(out['index.html'], contains('data:image/svg+xml'));
    });

    test('ikon yoksa veya html yoksa olduğu gibi döner', () {
      expect(externalizeFavicon({'index.html': '<head></head>'}).length, 1);
      expect(externalizeFavicon({'a.css': 'x'}).length, 1);
    });
  });
}
