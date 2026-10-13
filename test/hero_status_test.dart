import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/templates/html/shared_html_blocks.dart';

void main() {
  final hours = <Map<String, String?>>[
    {'day': 'Pazartesi', 'range': '09:00 - 19:00'},
    {'day': 'Pazar', 'range': null},
  ];

  String hero(String layout, {List<Map<String, String?>>? h, String lang = 'tr'}) =>
      heroBlockHtml(
        name: 'Acme',
        tagline: 'Slogan',
        coverImage: 'https://x.test/a.jpg',
        layoutStyle: layout,
        workingHours: h,
        lang: lang,
      );

  group('heroStatusPillHtml', () {
    test('saat yoksa veya hiç geçerli aralık yoksa boş döner', () {
      expect(heroStatusPillHtml(null), '');
      expect(heroStatusPillHtml([]), '');
      expect(heroStatusPillHtml([{'day': 'Pazar', 'range': null}]), '');
    });

    test('tr/en etiketleri ve gün haritası', () {
      final tr = heroStatusPillHtml(hours);
      expect(tr, contains('id="hero-status"'));
      expect(tr, contains('"1":{"start":"09:00","end":"19:00"}'));
      expect(tr, contains('Şu An Açık'));
      expect(tr, contains('Kapanış'));
      final en = heroStatusPillHtml(hours, lang: 'en');
      expect(en, contains('Open Now'));
      expect(en, contains('Closes'));
    });
  });

  group('heroBlockHtml', () {
    test('split ve social düzeninde hap basılır', () {
      expect(hero('split', h: hours), contains('hero-status'));
      expect(hero('social', h: hours), contains('hero-status'));
    });

    test('saat verilmezse hap yok', () {
      expect(hero('split'), isNot(contains('id="hero-status"')));
    });

    test('overlay düzenlerinde (centered/framed) hap yok', () {
      expect(hero('centered', h: hours), isNot(contains('id="hero-status"')));
      expect(hero('framed', h: hours), isNot(contains('id="hero-status"')));
    });
  });

  group('heroHoursFor', () {
    test('boşsa null; hours bölümü gizliyse null; aksi halde saatler', () {
      expect(heroHoursFor([], null), isNull);
      expect(heroHoursFor(hours, ['about', 'faq']), isNull);
      expect(heroHoursFor(hours, ['about', 'hours']), hours);
      expect(heroHoursFor(hours, null), hours);
      expect(heroHoursFor(hours, []), hours);
    });
  });

  group('saat dilimi ve gece vardiyası (29.09.2026)', () {
    test('varsayılan işletme saat dilimi Europe/Istanbul', () {
      expect(kDefaultBusinessTimeZone, 'Europe/Istanbul');
      expect(heroStatusPillHtml(hours), contains('Europe/Istanbul'));
      expect(heroStatusPillHtml(hours), contains('sitoraNowIn'));
    });

    test('özel saat dilimi hero hapına ve çalışma saatleri rozetine geçer', () {
      expect(heroStatusPillHtml(hours, timeZone: 'Europe/London'),
          contains('Europe/London'));
      final block = workingHoursBlockHtml(
          title: 'Saatler', hours: hours, timeZone: 'Europe/London');
      expect(block, contains('Europe/London'));
      expect(block, contains('sitoraHoursStatus'));
    });

    test('gece yarısını geçen aralık haritaya olduğu gibi girer', () {
      final night = heroStatusPillHtml([
        {'day': 'Cuma', 'range': '22:00 - 02:00'},
      ]);
      expect(night, contains('"5":{"start":"22:00","end":"02:00"}'));
      expect(night, contains('(now.day + 6) % 7'));
    });

    test('eski cihaz-saati mantığı kalmadı', () {
      final block = workingHoursBlockHtml(title: 'Saatler', hours: hours);
      expect(block, isNot(contains('now.getDay()')));
      expect(heroStatusPillHtml(hours), isNot(contains('now.getDay()')));
    });
  });

  group('satır bazlı saat dilimi (tz anahtarı)', () {
    final londonHours = <Map<String, String?>>[
      {'day': 'Pazartesi', 'range': '09:00 - 19:00', 'tz': 'Europe/London'},
      {'day': 'Pazar', 'range': null, 'tz': 'Europe/London'},
    ];

    test('hoursTimeZoneFor: yoksa/geçersizse null, geçerliyse değeri döner', () {
      expect(hoursTimeZoneFor(null), isNull);
      expect(hoursTimeZoneFor(hours), isNull); // eski kayıt: tz yok
      expect(hoursTimeZoneFor(londonHours), 'Europe/London');
      expect(
          hoursTimeZoneFor([
            {'day': 'Pazartesi', 'range': '09:00 - 19:00', 'tz': 'Europe/London;<b>'},
          ]),
          isNull);
      expect(
          hoursTimeZoneFor([
            {'day': 'Pazartesi', 'range': null, 'tz': ''},
            {'day': 'Salı', 'range': null, 'tz': 'America/New_York'},
          ]),
          'America/New_York');
    });

    test('hero hapı ve rozet satırlardaki tz değerini kullanır', () {
      expect(heroStatusPillHtml(londonHours), contains('Europe/London'));
      expect(heroStatusPillHtml(londonHours), isNot(contains('Europe/Istanbul')));
      expect(workingHoursBlockHtml(title: 'Saatler', hours: londonHours),
          contains('Europe/London'));
    });

    test('açık timeZone parametresi satırdaki tz\'yi ezer; tz yoksa İstanbul', () {
      expect(heroStatusPillHtml(londonHours, timeZone: 'Asia/Dubai'),
          contains('Asia/Dubai'));
      expect(heroStatusPillHtml(hours), contains('Europe/Istanbul'));
    });

    test('tz anahtarı çalışma saatleri tablosunu bozmaz', () {
      final block = workingHoursBlockHtml(title: 'Saatler', hours: londonHours);
      expect(block, contains('09:00 - 19:00'));
      expect(block, isNot(contains('<td>Europe/London</td>')));
    });

    test('heroHoursFor tz taşıyan listeyi olduğu gibi döndürür', () {
      expect(heroHoursFor(londonHours, null), londonHours);
    });
  });
}
