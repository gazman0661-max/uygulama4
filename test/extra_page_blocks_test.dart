import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/templates/html/extra_page_blocks.dart';
import 'package:sitora_ai/templates/html/generic_business_html_generator.dart';

void main() {
  group('decode/encode', () {
    test('bozuk veya boş girdi boş liste döner', () {
      expect(decodeExtraPageBlocks(null), isEmpty);
      expect(decodeExtraPageBlocks(''), isEmpty);
      expect(decodeExtraPageBlocks('{bozuk'), isEmpty);
      expect(decodeExtraPageBlocks('{"a":1}'), isEmpty);
    });

    test('bilinmeyen blok türü atlanır, gidiş-dönüş korunur', () {
      final raw = jsonEncode([
        {'type': 'text', 'body': 'a'},
        {'type': 'xyz'},
      ]);
      final out = decodeExtraPageBlocks(raw);
      expect(out.length, 1);
      expect(decodeExtraPageBlocks(encodeExtraPageBlocks(out)).first['body'], 'a');
    });
  });

  group('sanitizeButtonUrl', () {
    test('http/https/mailto/tel kabul edilir', () {
      expect(sanitizeButtonUrl('https://a.com'), 'https://a.com');
      expect(sanitizeButtonUrl('mailto:a@b.com'), 'mailto:a@b.com');
      expect(sanitizeButtonUrl('tel:+905551112233'), 'tel:+905551112233');
    });
    test('şemasız alan adına https eklenir', () {
      expect(sanitizeButtonUrl('ornek.com/randevu'), 'https://ornek.com/randevu');
    });
    test('javascript: ve boş reddedilir', () {
      expect(sanitizeButtonUrl('javascript:alert(1)'), isNull);
      expect(sanitizeButtonUrl('  '), isNull);
      expect(sanitizeButtonUrl('abc'), isNull);
    });
  });

  group('extraPageBlocksHtml', () {
    test('yazı bloğu HTML kaçırır', () {
      final html = extraPageBlocksHtml([
        {'type': 'text', 'heading': 'Başlık', 'body': '<script>x</script>'},
      ]);
      expect(html, contains('Başlık'));
      expect(html, isNot(contains('<script>x</script>')));
    });

    test('boş bloklar hiçbir şey üretmez', () {
      final html = extraPageBlocksHtml([
        {'type': 'text', 'body': ''},
        {'type': 'video', 'url': ''},
        {'type': 'services', 'lines': ''},
        {'type': 'button', 'label': 'x', 'action': 'link', 'url': 'javascript:1'},
      ]);
      expect(html.trim(), isEmpty);
    });

    test('fiyat listesi satırları ayrıştırılır', () {
      final html = extraPageBlocksHtml([
        {'type': 'services', 'lines': 'Saç Kesimi - 30 dk - 250 TL\nBoya - 900 TL'},
      ]);
      expect(html, contains('Saç Kesimi'));
      expect(html, contains('900 TL'));
    });

    test('WhatsApp butonu numara yoksa yazılmaz, varsa wa.me olur', () {
      final blocks = [
        {'type': 'button', 'label': 'Yaz', 'action': 'whatsapp'},
      ];
      expect(extraPageBlocksHtml(blocks).trim(), isEmpty);
      expect(extraPageBlocksHtml(blocks, whatsapp: '905551112233'), contains('wa.me/905551112233'));
    });

    test('SSS boş soru/cevabı atlar', () {
      final html = extraPageBlocksHtml([
        {
          'type': 'faq',
          'items': [
            {'question': 'Var mı?', 'answer': 'Evet'},
            {'question': '', 'answer': 'x'},
          ],
        },
      ]);
      expect(html, contains('Var mı?'));
    });
  });

  group('parseServiceLines', () {
    test('adı içinde tire geçen hizmet bozulmaz', () {
      final r = parseServiceLines('Anti-Aging Bakım - 500 TL');
      expect(r.length, 1);
      expect(r.first['name'], 'Anti-Aging Bakım');
      expect(r.first['duration'], isNull);
      expect(r.first['price'], '500 TL');
    });

    test('Ad - Süre - Fiyat üç parçaya bölünür', () {
      final r = parseServiceLines('Saç Kesimi - 30 dk - 250 TL');
      expect(r.first['name'], 'Saç Kesimi');
      expect(r.first['duration'], '30 dk');
      expect(r.first['price'], '250 TL');
    });

    test('boşluksuz "Boya-900 TL" eski davranışla ad/fiyat olur', () {
      final r = parseServiceLines('Boya-900 TL');
      expect(r.first['name'], 'Boya');
      expect(r.first['price'], '900 TL');
    });

    test('fiyatsız satır sadece ad olur, boş satırlar atlanır', () {
      final r = parseServiceLines('Danışmanlık\n\n  \n');
      expect(r.length, 1);
      expect(r.first['name'], 'Danışmanlık');
      expect(r.first['price'], '');
    });
  });

  group('Google Yorum butonu', () {
    final blocks = [
      {'type': 'button', 'label': 'Yorum Yaz', 'action': 'review'},
    ];

    test('şemasız link https:// ile yazılır', () {
      final html = extraPageBlocksHtml(blocks, googleReviewLink: 'g.page/abc');
      expect(html, contains('href="https://g.page/abc"'));
    });

    test('javascript: ve mailto: linki yazılmaz', () {
      expect(extraPageBlocksHtml(blocks, googleReviewLink: 'javascript:alert(1)').trim(), isEmpty);
      expect(extraPageBlocksHtml(blocks, googleReviewLink: 'mailto:a@b.com').trim(), isEmpty);
    });

    test('link yoksa yazılmaz', () {
      expect(extraPageBlocksHtml(blocks).trim(), isEmpty);
    });
  });

  group('generateGenericBusinessSite ek sayfa', () {
    Map<String, String> build(List<Map<String, String>> pages) => generateGenericBusinessSite(
          name: 'Test',
          coverImage: '',
          tagline: 't',
          services: const [],
          gallery: const [],
          workingHours: const [],
          address: '',
          lat: 0,
          lng: 0,
          phone: '',
          extraPages: pages,
        );

    test('eski (blocks olmayan) sayfa düz metinle çalışmaya devam eder', () {
      final files = build([
        {'slug': 'hakkimizda', 'title': 'Hakkımızda', 'content': 'Merhaba dünya'},
      ]);
      expect(files['hakkimizda.html'], contains('Merhaba dünya'));
    });

    test('blok tabanlı sayfa blokları ve SEO açıklamasını yazar', () {
      final files = build([
        {
          'slug': 'fiyatlar',
          'title': 'Fiyatlar',
          'content': '',
          'seoDesc': 'Güncel fiyat listemiz',
          'blocks': jsonEncode([
            {'type': 'services', 'lines': 'Kesim - 250 TL'},
          ]),
        },
      ]);
      final html = files['fiyatlar.html']!;
      expect(html, contains('Kesim'));
      expect(html, contains('Güncel fiyat listemiz'));
    });
  });
}
