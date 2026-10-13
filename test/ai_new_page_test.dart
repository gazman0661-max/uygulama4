import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/free/ai_site_builder.dart';
import 'package:sitora_ai/free/ai_site_editor.dart';
import 'package:sitora_ai/free/free_model.dart';

// 06.10.2026 — "AI ile yeni sayfa" (AiSiteBuilder.buildPage / AiSiteEditor.addPage).
// Çalıştırma: flutter test test/ai_new_page_test.dart
Map<String, dynamic> pageJson({String name = 'Fiyatlar', List? sections}) => {
      'summary': 'Fiyatlar sayfası hazırlandı.',
      'page_name': name,
      'desc': 'Hizmet fiyatları',
      'sections': sections ??
          [
            {'type': 'about', 'heading': 'Fiyatlarımız', 'body': 'Şeffaf fiyat politikası.'},
            {'type': 'services', 'heading': 'Hizmetler', 'lines': 'Saç kesimi - 300 TL\nBoya - 900 TL'},
            {'type': 'contact'},
          ],
    };

void main() {
  group('AiSiteBuilder.buildPage', () {
    test('geçerli JSON -> sayfa + iletişim bölümü', () {
      final p = AiSiteBuilder.buildPage(pageJson())!;
      expect(p.name, 'Fiyatlar');
      expect(p.desc, 'Hizmet fiyatları');
      final els = p.canvas.els;
      expect(els.where((e) => e.type == FType.contact).length, 1);
      expect(els.where((e) => e.type == FType.block).isNotEmpty, true);
    });

    test('sayfa adı boşsa null', () {
      expect(AiSiteBuilder.buildPage(pageJson(name: '')), isNull);
    });

    test('geçerli bölüm yoksa null (reddedilen/boş yanıt)', () {
      expect(AiSiteBuilder.buildPage(pageJson(sections: const [])), isNull);
      expect(AiSiteBuilder.buildPage(pageJson(sections: [
        {'type': 'bilinmeyen'}
      ])), isNull);
    });

    test('HTML etiketleri temizlenir', () {
      final p = AiSiteBuilder.buildPage(pageJson(name: '<b>Fiyat</b>lar'))!;
      expect(p.name.contains('<'), false);
    });
  });

  group('AiSiteEditor.addPage', () {
    test('yeni sayfa kopyaya eklenir, orijinal değişmez', () {
      final site = FreeSite();
      final res = AiSiteEditor.addPage(site, pageJson());
      expect(site.pages.length, 1);
      expect(res.site.pages.length, 2);
      expect(res.site.pages.last.name, 'Fiyatlar');
      expect(res.changes.single.startsWith('Yeni sayfa: Fiyatlar'), true);
    });

    test('aynı ad varsa (2) eklenir', () {
      final site = FreeSite();
      final r1 = AiSiteEditor.addPage(site, pageJson());
      final r2 = AiSiteEditor.addPage(r1.site, pageJson());
      expect(r2.site.pages.map((p) => p.name).toList(), ['Ana Sayfa', 'Fiyatlar', 'Fiyatlar (2)']);
    });

    test('AI reddederse sayfa eklenmez, refused korunur', () {
      final site = FreeSite();
      final res = AiSiteEditor.addPage(site, {'refused': 'Bunu yapamam.', 'sections': []});
      expect(res.changes, isEmpty);
      expect(res.site.pages.length, 1);
      expect(res.refused, 'Bunu yapamam.');
    });

    test('sayfa üst sınırı', () {
      var site = FreeSite();
      for (var i = 0; i < AiSiteEditor.maxPages - 1; i++) {
        site.pages.add(FreePage('S$i'));
      }
      final res = AiSiteEditor.addPage(site, pageJson());
      expect(res.changes, isEmpty);
      expect(res.site.pages.length, AiSiteEditor.maxPages);
    });

    test('describeForNewPage: sayfa adlarını içerir, görsel verisi içermez', () {
      final site = FreeSite();
      final d = AiSiteEditor.describeForNewPage(site);
      expect(d.contains('Ana Sayfa'), true);
      expect(d.contains('data:image'), false);
    });
  });
}
