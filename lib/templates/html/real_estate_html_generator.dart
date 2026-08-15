import 'shared_html_blocks.dart';

/// real_estate_template'in HTML karşılığı. Çok sayfalı yapı burada
/// "iki ayrı HTML dosyası" olarak modelleniyor: index.html (liste) ve
/// her ilan için listing_<id>.html (detay). AppState.generatedFiles
/// (B modu, Map<String,String>) zaten bu yapıyı destekliyor — download
/// zaten zip olarak paketliyor, ekstra bir şey gerekmiyor.

/// Liste sayfası (index.html).
String generateListingListHtml({
  required String agentName,
  required String agentLogo,
  required String tagline,
  required List<Map<String, String?>> listings, // {id, title, coverImage, price, m2, roomLabel, locationTag}
  String? agentPhone,
  String? agentWhatsapp,
  String themeId = 'clean_light',
}) {
  final cardData = listings.map((l) => {
        ...l,
        'href': 'listing_${l['id']}.html',
      }).toList();
  final subtext = themeOf(themeId)['subtext']!;

  final body = '''
<section class="section" style="text-align:center;">
  ${agentLogo.isNotEmpty ? '<img src="${escapeHtml(agentLogo)}" style="width:64px;height:64px;border-radius:50%;object-fit:cover;margin-bottom:12px;">' : ''}
  <h1 style="font-size:24px;font-weight:700;">${escapeHtml(agentName)}</h1>
  <p style="color:$subtext;">${escapeHtml(tagline)}</p>
</section>
${propertyCardGridHtml(listings: cardData)}''';

  return wrapPageHtml(
    pageTitle: agentName,
    bodyHtml: body,
    themeId: themeId,
    metaDescription: tagline,
    ogImage: agentLogo,
    whatsapp: agentWhatsapp,
    phone: agentPhone,
  );
}

/// Tek bir ilanın detay sayfası (listing_<id>.html).
String generateListingDetailHtml({
  required String title,
  required List<Map<String, String?>> gallery,
  required double price,
  required double m2,
  required String roomLabel,
  int? floor,
  double? aidat,
  required String description,
  required String address,
  required double lat,
  required double lng,
  required String agentName,
  required String agentPhone,
  required String agentWhatsapp,
  String themeId = 'clean_light',
}) {
  final body = StringBuffer();

  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(title: title, images: gallery));
  }

  body.writeln(propertyDetailsBlockHtml(
    details: {
      'Fiyat': '${price.toStringAsFixed(0)} TL',
      'm²': m2.toStringAsFixed(0),
      'Oda': roomLabel,
      if (floor != null) 'Kat': floor.toString(),
      if (aidat != null) 'Aidat': '${aidat.toStringAsFixed(0)} TL',
    },
    description: description,
  ));

  body.writeln(mapBlockHtml(title: 'Konum', address: address, lat: lat, lng: lng));

  body.writeln(contactFormBlockHtml(title: 'İletişime Geç', email: '$agentWhatsapp@wa.contact'));
  body.writeln(contactBlockHtml(title: '', phone: agentPhone, whatsapp: agentWhatsapp));

  return wrapPageHtml(
    pageTitle: title,
    bodyHtml: body.toString(),
    themeId: themeId,
    metaDescription: description,
    ogImage: gallery.isNotEmpty ? gallery.first['url'] : null,
    whatsapp: agentWhatsapp,
    phone: agentPhone,
  );
}

/// Bir emlakçının tüm ilanlarını (liste + her ilan için detay) tek seferde
/// üretip Map<String,String> olarak döner — doğrudan
/// appState.updateGeneratedFiles(...) 'e (B modu) verilebilir.
Map<String, String> generateRealEstateSite({
  required String agentName,
  required String agentLogo,
  required String tagline,
  required String agentPhone,
  required String agentWhatsapp,
  required List<Map<String, dynamic>> listings, // tüm ilan detaylarını içerir
  String themeId = 'clean_light',
}) {
  final files = <String, String>{};

  final listCards = listings.map((l) => {
        'id': l['id'].toString(),
        'title': l['title'].toString(),
        'coverImage': l['coverImage'].toString(),
        'price': '${(l['price'] as num).toStringAsFixed(0)} TL',
        'm2': (l['m2'] as num).toStringAsFixed(0),
        'roomLabel': l['roomLabel'].toString(),
        'locationTag': l['locationTag']?.toString() ?? '',
      }).toList();

  files['index.html'] = generateListingListHtml(
    agentName: agentName,
    agentLogo: agentLogo,
    tagline: tagline,
    listings: listCards,
    agentPhone: agentPhone,
    agentWhatsapp: agentWhatsapp,
    themeId: themeId,
  );

  for (final l in listings) {
    files['listing_${l['id']}.html'] = generateListingDetailHtml(
      title: l['title'].toString(),
      gallery: (l['gallery'] as List? ?? [])
          .map((g) => {'url': (g as Map)['url']?.toString(), 'caption': g['caption']?.toString()})
          .toList()
          .cast<Map<String, String?>>(),
      price: (l['price'] as num).toDouble(),
      m2: (l['m2'] as num).toDouble(),
      roomLabel: l['roomLabel'].toString(),
      floor: l['floor'] as int?,
      aidat: (l['aidat'] as num?)?.toDouble(),
      description: l['description'].toString(),
      address: l['address'].toString(),
      lat: (l['lat'] as num).toDouble(),
      lng: (l['lng'] as num).toDouble(),
      agentName: agentName,
      agentPhone: agentPhone,
      agentWhatsapp: agentWhatsapp,
      themeId: themeId,
    );
  }

  return files;
}
