import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/free/free_model.dart';
import 'package:sitora_ai/free/free_templates.dart';
import 'package:sitora_ai/templates/html/free_builder_html_generator.dart';

FreeElement el(FType t, {int c = 0, int r = 0, int w = 10, int h = 4, int bg = 0, String text = ''}) =>
    FreeElement(id: newFreeId(), type: t, c: c, r: r, w: w, h: h, bg: bg, text: text);

void main() {
  group('FreePage tek tuval (flatten)', () {
    test('çok bölümlü eski sayfa tek canvas olur; blok ve iletişim öğeye dönüşür', () {
      final p = FreePage('Ana', sections: [
        FreeSection(id: 'a', kind: 'canvas', els: [el(FType.title, r: 2, text: 'Merhaba')]),
        FreeSection(id: 'b', kind: 'block', block: {'type': 'gallery', 'images': []}),
        FreeSection(id: 'c', kind: 'contact'),
      ]);
      expect(p.sections.length, 1);
      expect(p.canvas.isCanvas, isTrue);
      final types = p.canvas.els.map((e) => e.type).toList();
      expect(types, containsAll([FType.title, FType.block, FType.contact]));
      final gallery = p.canvas.els.firstWhere((e) => e.type == FType.block);
      final contact = p.canvas.els.firstWhere((e) => e.type == FType.contact);
      final title = p.canvas.els.firstWhere((e) => e.type == FType.title);
      expect(gallery.r, greaterThan(title.r));
      expect(contact.r, greaterThanOrEqualTo(gallery.r + gallery.h));
    });

    test('bölüm arka planı şerit olur ve içindeki yazıya okunaklı renk yazılır', () {
      final p = FreePage('Ana', sections: [
        FreeSection(id: 'a', kind: 'canvas', bg: 0xFF1E293B, els: [el(FType.title, r: 2, text: 'Koyu')]),
      ]);
      final band = p.canvas.els.firstWhere((e) => e.type == FType.band);
      expect(band.bg, 0xFF1E293B);
      expect(band.w, kCols);
      final title = p.canvas.els.firstWhere((e) => e.type == FType.title);
      expect(title.color, 0xFFFFFFFF);
      expect(p.canvas.bg, 0);
    });

    test('flatten idempotent: JSON gidiş-dönüşte aynı kalır', () {
      final p = FreePage('Ana', sections: buildFreeTemplate('tanitim'));
      final j1 = jsonEncode(p.toJson());
      final p2 = FreePage.fromJson(jsonDecode(j1) as Map<String, dynamic>);
      expect(jsonEncode(p2.toJson()), j1);
    });

    test('appendSections tuvalin altına ekler, mevcut öğelere dokunmaz', () {
      final p = FreePage('Ana', sections: [
        FreeSection(id: 'a', kind: 'canvas', els: [el(FType.title, r: 2)]),
      ]);
      final first = p.canvas.els.first;
      final r0 = first.r;
      p.appendSections([buildFreeSectionPreset('hero')]);
      expect(first.r, r0);
      final added = p.canvas.els.skip(1).toList();
      expect(added, isNotEmpty);
      expect(added.every((e) => e.r > first.r + first.h - 1), isTrue);
    });

    test('imageCount blok görsellerini de sayar', () {
      final p = FreePage('Ana', sections: [
        FreeSection(id: 'a', kind: 'canvas', els: [FreeElement(id: 'i', type: FType.image, img: 'data:image/webp;base64,AAAA')]),
        FreeSection(id: 'b', kind: 'block', block: {
          'type': 'gallery',
          'images': [
            {'url': 'data:image/webp;base64,AAAA'},
            {'url': 'data:image/webp;base64,BBBB'},
          ],
        }),
      ]);
      expect(p.imageCount, 3);
    });
  });

  group('mobil sıra ve şerit', () {
    test('elle sıra yoksa konuma göre (yukarıdan aşağı, soldan sağa)', () {
      final a = el(FType.text, r: 10, c: 0);
      final b = el(FType.text, r: 2, c: 20);
      final c = el(FType.text, r: 2, c: 4);
      final s = FreeSection(id: 's', kind: 'canvas', els: [a, b, c, el(FType.band, w: kCols, r: 0, h: 30, bg: 0xFF000000)]);
      expect(s.ordered.map((e) => e.id).toList(), [c.id, b.id, a.id]);
    });

    test('tüm öğelerde mo varsa elle sıra geçerli, şeritler listeye girmez', () {
      final a = el(FType.text, r: 0)..mo = 1;
      final b = el(FType.text, r: 20)..mo = 0;
      final band = el(FType.band, w: kCols, r: 0, h: 40, bg: 0xFF000000);
      final s = FreeSection(id: 's', kind: 'canvas', els: [a, b, band]);
      expect(s.manualOrder, isTrue);
      expect(s.ordered.map((e) => e.id).toList(), [b.id, a.id]);
    });

    test('bandOf: dikey merkezi şeritte olan öğe şeride ait', () {
      final band = el(FType.band, w: kCols, r: 10, h: 20, bg: 0xFF112233);
      final inside = el(FType.text, r: 12, h: 4);
      final outside = el(FType.text, r: 40, h: 4);
      final s = FreeSection(id: 's', kind: 'canvas', els: [band, inside, outside]);
      expect(s.bandBgFor(inside), 0xFF112233);
      expect(s.bandBgFor(outside), 0);
    });
  });

  group('HTML çıktısı', () {
    test('şerit, şeritteki öğe, blok ve masaüstü/mobil sınıfları üretilir', () {
      final site = FreeSite(pages: [
        FreePage('Ana', sections: [
          FreeSection(id: 'a', kind: 'canvas', bg: 0xFF1E293B, els: [el(FType.title, r: 2, w: 40, text: 'Selam')]),
          FreeSection(id: 'b', kind: 'block', block: {
            'type': 'faq',
            'items': [
              {'question': 'Soru?', 'answer': 'Cevap.'},
            ],
          }),
        ]),
      ]);
      final html = generateFreeBuilderSite(site).values.first;
      expect(html, contains('fb-band'));
      expect(html, contains('fb-inb'));
      expect(html, contains('fb-block'));
      expect(html, contains('Soru?'));
      expect(html, contains('Selam'));
    });
  });
}
