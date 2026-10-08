import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/templates/html/shared_html_blocks.dart';

/// 05.10.2026 — og:locale site diline göre (eskiden her sayfada sabit tr_TR'ydi).
/// NOT: bu dosya yazıldığı ortamda ÇALIŞTIRILMADI (Flutter yoktu); `flutter test` ile doğrula.
void main() {
  group('ogLocaleFor', () {
    test('tr -> tr_TR, en -> en_US (büyük/küçük harf fark etmez)', () {
      expect(ogLocaleFor('tr'), 'tr_TR');
      expect(ogLocaleFor('en'), 'en_US');
      expect(ogLocaleFor('EN'), 'en_US');
    });

    test('bilinmeyen dil için boş döner (yanlış dil bildirilmez)', () {
      expect(ogLocaleFor('de'), '');
      expect(ogLocaleFor(''), '');
    });
  });

  group('seoMetaHtml og:locale', () {
    test('varsayılan (lang verilmez) eski davranış: tr_TR', () {
      final html = seoMetaHtml(pageTitle: 'Test');
      expect(html, contains('<meta property="og:locale" content="tr_TR">'));
    });

    test('en sitede en_US yazılır, tr_TR yazılmaz', () {
      final html = seoMetaHtml(pageTitle: 'Test', lang: 'en');
      expect(html, contains('<meta property="og:locale" content="en_US">'));
      expect(html, isNot(contains('tr_TR')));
    });

    test('bilinmeyen dilde og:locale hiç yazılmaz', () {
      final html = seoMetaHtml(pageTitle: 'Test', lang: 'de');
      expect(html, isNot(contains('og:locale')));
    });
  });

  group('wrapPageHtml', () {
    test('lang değeri og:locale ve <html lang> ile tutarlı', () {
      final en = wrapPageHtml(pageTitle: 'Test', bodyHtml: '<p>x</p>', lang: 'en');
      expect(en, contains('<html lang="en">'));
      expect(en, contains('content="en_US"'));
      final tr = wrapPageHtml(pageTitle: 'Test', bodyHtml: '<p>x</p>');
      expect(tr, contains('<html lang="tr">'));
      expect(tr, contains('content="tr_TR"'));
    });
  });
}
