import 'shared_html_blocks.dart';

/// clinic_template'in HTML karşılığı. extended_business_html_generator ile
/// aynı temel (WorkingDay/LocationInfo/ContactInfo) yapıyı kullanır ama
/// paket/ekip yerine tekil "Uzman Tanıtımı" (PractitionerProfile) bölümü
/// vardır, bu yüzden ayrı fonksiyon olarak tutuldu.
String generateClinicHtml({
  required String businessName,
  required String title, // "Uzman Psikolog" gibi unvan
  required String photoUrl,
  required String tagline,
  List<Map<String, String?>> services = const [],
  Map<String, dynamic>? practitioner, // {name, title, photoUrl, bio, credentials:[{label}]}
  required List<Map<String, String?>> workingHours,
  required String address,
  double? lat,
  double? lng,
  required String phone,
  String? whatsapp,
  String? instagram,
  String accentColor = '#2E7D6B', // sakin yeşil-mavi ton
}) {
  final body = StringBuffer();

  body.writeln(heroBlockHtml(
    name: businessName,
    tagline: '$title — $tagline',
    coverImage: photoUrl,
    ctaText: 'Randevu Al',
    ctaHref: whatsapp != null ? 'https://wa.me/$whatsapp' : 'tel:$phone',
  ));

  if (services.isNotEmpty) {
    body.writeln(serviceListBlockHtml(title: 'Uzmanlık Alanları', services: services));
  }

  if (practitioner != null) {
    body.writeln(practitionerBlockHtml(
      name: practitioner['name']?.toString() ?? businessName,
      title: practitioner['title']?.toString() ?? title,
      photoUrl: practitioner['photoUrl']?.toString() ?? photoUrl,
      bio: practitioner['bio']?.toString() ?? '',
      credentials: (practitioner['credentials'] as List? ?? [])
          .map((c) => {'label': (c as Map)['label']?.toString()})
          .toList()
          .cast<Map<String, String?>>(),
    ));
  }

  if (workingHours.isNotEmpty) {
    body.writeln(workingHoursBlockHtml(title: 'Çalışma Saatleri', hours: workingHours));
  }

  if (lat != null && lng != null) {
    body.writeln(mapBlockHtml(title: 'Konum', address: address, lat: lat, lng: lng));
  } else {
    body.writeln('<section class="section"><p class="address-text">${escapeHtml(address)}</p></section>');
  }

  body.writeln(contactBlockHtml(
    title: 'İletişim',
    phone: phone,
    whatsapp: whatsapp,
    instagram: instagram,
  ));

  return wrapPageHtml(pageTitle: businessName, bodyHtml: body.toString(), accentColor: accentColor);
}
