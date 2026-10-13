import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/free/free_model.dart';
import 'package:sitora_ai/templates/html/free_builder_html_generator.dart';

FreeElement el(FType t, {int c = 0, int r = 0, int w = 10, int h = 4, int bg = 0, String text = ''}) =>
    FreeElement(id: newFreeId(), type: t, c: c, r: r, w: w, h: h, bg: bg, text: text);

FreePage samplePage() => FreePage('Ana', sections: [
      FreeSection(id: 'a', kind: 'canvas', els: [
        el(FType.band, c: 0, r: 0, w: kCols, h: 12, bg: 0xFF1E293B),
        el(FType.title, c: 4, r: 2, w: 20, h: 5, text: 'Merhaba'),
        el(FType.text, c: 26, r: 2, w: 18, h: 6, text: 'Yan yana yazı'),
        el(FType.button, c: 4, r: 20, w: 14, h: 5, text: 'Ara'),
      ]),
    ]);

void main() {
  group('Ayrı mobil düzen', () {
    test('varsayılan kapalı ve eski JSON mobil alanları olmadan yüklenir', () {
      final p = samplePage();
      expect(p.mobileCustom, isFalse);
      final j = jsonEncode(p.toJson());
      expect(j.contains('mcustom'), isFalse);
      expect(j.contains('"mr"'), isFalse);
      final p2 = FreePage.fromJson(jsonDecode(j) as Map<String, dynamic>);
      expect(p2.mobileCustom, isFalse);
      expect(p2.canvas.els.every((e) => !e.hasMobileGeo), isTrue);
    });

    test('ensureMobileGeometry öğeleri alt alta dizer, çakışma ve taşma olmaz', () {
      final p = samplePage();
      p.ensureMobileGeometry();
      final items = p.canvas.els.where((e) => e.type != FType.band).toList();
      expect(items.every((e) => e.hasMobileGeo), isTrue);
      for (final e in items) {
        expect(e.mc! + e.mw!, lessThanOrEqualTo(kCols));
        expect(e.mh, e.h);
      }
      items.sort((a, b) => a.mr!.compareTo(b.mr!));
      for (var i = 1; i < items.length; i++) {
        expect(items[i].mr!, greaterThanOrEqualTo(items[i - 1].mr! + items[i - 1].mh!));
      }
      // Konuma göre sıra: başlık, yan yazı, sonra buton.
      expect(items.map((e) => e.type).toList(), [FType.title, FType.text, FType.button]);
    });

    test('şerit mobilde içindeki öğeleri kapsar', () {
      final p = samplePage();
      p.ensureMobileGeometry();
      final band = p.canvas.els.firstWhere((e) => e.type == FType.band);
      final title = p.canvas.els.firstWhere((e) => e.type == FType.title);
      final text = p.canvas.els.firstWhere((e) => e.type == FType.text);
      expect(band.mc, 0);
      expect(band.mw, kCols);
      for (final e in [title, text]) {
        expect(band.mr!, lessThanOrEqualTo(e.mr!));
        expect(band.mr! + band.mh!, greaterThanOrEqualTo(e.mr! + e.mh!));
      }
    });

    test('ensureMobileGeometry idempotent; sonradan eklenen öğe en alta gelir', () {
      final p = samplePage();
      p.ensureMobileGeometry();
      final before = jsonEncode(p.toJson());
      p.ensureMobileGeometry();
      expect(jsonEncode(p.toJson()), before);

      final added = el(FType.text, c: 2, r: 3, w: 10, h: 3, text: 'Yeni');
      p.canvas.els.add(added);
      p.ensureMobileGeometry();
      expect(added.hasMobileGeo, isTrue);
      final others = p.canvas.els.where((e) => e.type != FType.band && e != added);
      final bottom = others.map((e) => e.mr! + e.mh!).reduce((a, b) => a > b ? a : b);
      expect(added.mr!, greaterThan(bottom));
    });

    test('mobil düzenleme masaüstü geometrisine dokunmaz; JSON gidiş-dönüş', () {
      final p = samplePage();
      p.ensureMobileGeometry();
      p.mobileCustom = true;
      final t = p.canvas.els.firstWhere((e) => e.type == FType.title);
      final c0 = t.c, r0 = t.r, w0 = t.w, h0 = t.h;
      t.setC(true, 6);
      t.setW(true, 30);
      t.setR(true, 40);
      t.setH(true, 9);
      t.mfs = 30;
      expect([t.c, t.r, t.w, t.h], [c0, r0, w0, h0]);
      expect([t.cOn(true), t.wOn(true), t.rOn(true), t.hOn(true)], [6, 30, 40, 9]);
      expect(t.fontPxOn(true), 30);
      expect(t.fontPxOn(false), t.fontPx);

      final p2 = FreePage.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(p2.mobileCustom, isTrue);
      final t2 = p2.canvas.els.firstWhere((e) => e.type == FType.title);
      expect([t2.mc, t2.mw, t2.mr, t2.mh, t2.mfs], [6, 30, 40, 9, 30]);
    });

    test('geometri yokken setter masaüstünü değiştirir (güvenli geri dönüş)', () {
      final e = el(FType.text, c: 1, r: 1, w: 5, h: 2);
      e.setC(true, 9);
      expect(e.c, 9);
      expect(e.cOn(true), 9);
    });
  });

  group('Ayrı mobil düzen HTML', () {
    FreeSite site(FreePage p) => FreeSite(name: 'Test', pages: [p]);

    test('kapalıyken çıktı .fb-m içermez (eski davranış)', () {
      final html = generateFreeBuilderSite(site(samplePage()))['index.html']!;
      expect(html.contains('class="fb-grid"'), isTrue);
      expect(html.contains('class="fb-grid fb-m"'), isFalse);
      expect(html.contains('--mc:'), isFalse);
    });

    test('açıkken ızgara .fb-m olur, her öğeye --mc/--mr yazılır, --mrows eklenir', () {
      final p = samplePage();
      p.mobileCustom = true;
      final html = generateFreeBuilderSite(site(p))['index.html']!;
      expect(html.contains('class="fb-grid fb-m"'), isTrue);
      expect(html.contains('--mrows:'), isTrue);
      final t = p.canvas.els.firstWhere((e) => e.type == FType.title);
      expect(html.contains('--mc:${t.mc! + 1}/span ${t.mw};--mr:${t.mr! + 1}/span ${t.mh};'), isTrue);
      // masaüstü yerleşim satır içi stilleri aynen durur
      expect(html.contains('grid-column:${t.c + 1}/span ${t.w};grid-row:${t.r + 1}/span ${t.h};'), isTrue);
      // şerit de mobil konum alır
      final band = p.canvas.els.firstWhere((e) => e.type == FType.band);
      expect(html.contains('--mc:1/span $kCols;--mr:${band.mr! + 1}/span ${band.mh};'), isTrue);
    });

    test('mobil yazı boyutu --mfs olarak yazılır', () {
      final p = samplePage();
      p.mobileCustom = true;
      p.ensureMobileGeometry();
      p.canvas.els.firstWhere((e) => e.type == FType.title).mfs = 28;
      final html = generateFreeBuilderSite(site(p))['index.html']!;
      expect(html.contains('--mfs:28px;'), isTrue);
    });

    test('öğe mobilde şeritten çıkarsa mobil yazı rengi sıfırlanır (--mtc)', () {
      final p = samplePage();
      p.mobileCustom = true;
      p.ensureMobileGeometry();
      final title = p.canvas.els.firstWhere((e) => e.type == FType.title);
      title.setR(true, 200); // şeritin dışına taşı
      final html = generateFreeBuilderSite(site(p))['index.html']!;
      expect(html.contains('--mtc:var(--sitora-text);'), isTrue);
    });
  });
}
