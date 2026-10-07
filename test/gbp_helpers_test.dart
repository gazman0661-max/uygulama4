import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/services/gbp_helpers.dart';

void main() {
  group('gbpNormalizeReviewLink', () {
    test('boşlukları kırpar', () {
      expect(gbpNormalizeReviewLink('  https://g.page/r/abc/review  '),
          'https://g.page/r/abc/review');
    });

    test('metnin içinden ilk linki alır ve http -> https yapar', () {
      expect(
          gbpNormalizeReviewLink('Yorum yap: http://g.page/r/abc/review lütfen'),
          'https://g.page/r/abc/review');
    });

    test('şemasız yapıştırılırsa https ekler', () {
      expect(gbpNormalizeReviewLink('g.page/r/abc/review'),
          'https://g.page/r/abc/review');
    });

    test('boş girdi boş kalır', () {
      expect(gbpNormalizeReviewLink('   '), '');
    });
  });

  group('gbpReviewLinkProblem', () {
    test('Google linkleri geçerli', () {
      expect(gbpReviewLinkProblem('https://g.page/r/abc/review'), isNull);
      expect(
          gbpReviewLinkProblem(
              'https://search.google.com/local/writereview?placeid=X'),
          isNull);
      expect(gbpReviewLinkProblem('https://www.google.com/maps/place/x'), isNull);
    });

    test('Google olmayan / Google gibi görünen hostlar reddedilir', () {
      expect(gbpReviewLinkProblem('https://example.com/review'), 'host');
      expect(gbpReviewLinkProblem('https://evilgoogle.com/x'), 'host');
      expect(gbpReviewLinkProblem('https://google.com.evil.com/x'), 'host');
    });

    test('geçersiz / tehlikeli girdi reddedilir', () {
      expect(gbpReviewLinkProblem('https://yorum linki'), 'scheme');
      expect(
          gbpReviewLinkProblem(gbpNormalizeReviewLink('javascript:alert(1)')),
          isNotNull);
    });
  });

  group('gbpLooksLikeReviewLink', () {
    test('yorum formu linkleri', () {
      expect(gbpLooksLikeReviewLink('https://g.page/r/abc/review'), isTrue);
      expect(
          gbpLooksLikeReviewLink(
              'https://search.google.com/local/writereview?placeid=1'),
          isTrue);
    });

    test('harita linki yorum formu değil', () {
      expect(gbpLooksLikeReviewLink('https://maps.app.goo.gl/xyz'), isFalse);
    });
  });

  group('gbpFormatHours', () {
    final hours = <Map<String, String?>>[
      {'day': 'Pazartesi', 'range': '09:00 - 19:00'},
      {'day': 'Pazar', 'range': null},
    ];

    test('Türkçe', () {
      expect(gbpFormatHours(hours, en: false),
          'Pazartesi: 09:00 - 19:00\nPazar: Kapalı');
    });

    test('İngilizce', () {
      expect(gbpFormatHours(hours, en: true),
          'Monday: 09:00 - 19:00\nSunday: Closed');
    });

    test('boş / null', () {
      expect(gbpFormatHours(null, en: false), '');
      expect(gbpFormatHours(const [], en: true), '');
    });
  });
}
