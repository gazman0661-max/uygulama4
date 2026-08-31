import 'shared_html_blocks.dart';

/// real_estate_template'in HTML karşılığı. Çok sayfalı yapı burada
/// "iki ayrı HTML dosyası" olarak modelleniyor: index.html (liste) ve
/// her ilan için listing_<id>.html (detay). AppState.generatedFiles
/// (B modu, Map<String,String>) zaten bu yapıyı destekliyor — download
/// zaten zip olarak paketliyor, ekstra bir şey gerekmiyor.
///
/// `lang`: üretilen SİTENİN dili ('tr' | 'en'), uygulamanın seçili
/// arayüz diline göre otomatik geliyor (form ekranı bu değeri
/// context.read<LocaleController>() ile hesaplayıp geçiyor).

/// Liste sayfası (index.html).
/// [agentCoverImage] verilirse profesyonel bir hero (emlakçının kendi
/// ofis/marka görseli + logo + tagline, editoryal düzen) gösterilir.
/// Verilmezse eski sade metin başlığına düşülür — bir ilanın fotoğrafı
/// ASLA otomatik kapak görseli olarak kullanılmaz (ilanla emlakçının
/// kendi kimliği farklı şeylerdir, karıştırılmamalı).
String generateListingListHtml({
  required String agentName,
  required String agentLogo,
  required String tagline,
  required List<Map<String, String?>> listings, // {id, title, coverImage, price, m2, roomLabel, locationTag}
  String? agentPhone,
  String? agentWhatsapp,
  String? agentCoverImage,
  String? agentAddress,
  double? agentLat,
  double? agentLng,
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
}) {
  final cardData = listings.map((l) => {
        ...l,
        'href': 'listing_${l['id']}.html',
      }).toList();
  final subtext = themeOf(themeId)['subtext']!;
  final labels = siteLabels(lang);

  final headerHtml = (agentCoverImage != null && agentCoverImage.isNotEmpty)
      ? heroBlockHtml(
          name: agentName,
          tagline: tagline,
          coverImage: agentCoverImage,
          logoImage: agentLogo.isNotEmpty ? agentLogo : null,
          layoutStyle: 'editorial',
        )
      : '''
<section class="section" style="text-align:center;">
  ${agentLogo.isNotEmpty ? '<img src="${escapeHtml(agentLogo)}" style="width:64px;height:64px;border-radius:50%;object-fit:cover;margin-bottom:12px;">' : ''}
  <h1 style="font-size:24px;font-weight:700;">${escapeHtml(agentName)}</h1>
  <p style="color:$subtext;">${escapeHtml(tagline)}</p>
</section>''';

  final officeMapHtml = (agentAddress != null && agentAddress.isNotEmpty && agentLat != null && agentLng != null)
      ? mapBlockHtml(title: labels['location']!, address: agentAddress, lat: agentLat, lng: agentLng, lang: lang)
      : '';

  final body = '''
$headerHtml
${propertyCardGridHtml(listings: cardData)}
$officeMapHtml''';

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: agentName,
    bodyHtml: body,
    themeId: themeId,
    metaDescription: tagline,
    ogImage: agentLogo,
    schemaType: 'RealEstateAgent',
    whatsapp: agentWhatsapp,
    phone: agentPhone,
    lang: lang,
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
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
}) {
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final propertyLabels = lang == 'en'
      ? {'price': 'Price', 'm2': 'm²', 'room': 'Rooms', 'floor': 'Floor', 'dues': 'HOA Fee', 'currency': ''}
      : {'price': 'Fiyat', 'm2': 'm²', 'room': 'Oda', 'floor': 'Kat', 'dues': 'Aidat', 'currency': ' TL'};
  final contactTitle = lang == 'en' ? 'Get in Touch' : 'İletişime Geç';

  if (gallery.isNotEmpty) {
    body.writeln(galleryBlockHtml(
    style: galleryStyle,title: title, images: gallery));
  }

  body.writeln(propertyDetailsBlockHtml(
    details: {
      propertyLabels['price']!: '${price.toStringAsFixed(0)}${propertyLabels['currency']}',
      propertyLabels['m2']!: m2.toStringAsFixed(0),
      propertyLabels['room']!: roomLabel,
      if (floor != null) propertyLabels['floor']!: floor.toString(),
      if (aidat != null) propertyLabels['dues']!: '${aidat.toStringAsFixed(0)}${propertyLabels['currency']}',
    },
    description: description,
  ));

  body.writeln(mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang));

  body.writeln(contactFormBlockHtml(title: contactTitle, email: '$agentWhatsapp@wa.contact', lang: lang));
  body.writeln(contactBlockHtml(title: '', phone: agentPhone, whatsapp: agentWhatsapp, lang: lang));

  return wrapPageHtml(
    fontPackageId: fontPackageId,
    density: density,
    pageTitle: title,
    bodyHtml: body.toString(),
    themeId: themeId,
    metaDescription: description,
    ogImage: gallery.isNotEmpty ? gallery.first['url'] : null,
    schemaType: 'Product',
    whatsapp: agentWhatsapp,
    phone: agentPhone,
    lang: lang,
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
  String? agentCoverImage,
  String? agentAddress,
  double? agentLat,
  double? agentLng,
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
}) {
  final files = <String, String>{};
  final currencySuffix = lang == 'en' ? '' : ' TL';

  final listCards = listings.map((l) => {
        'id': l['id'].toString(),
        'title': l['title'].toString(),
        'coverImage': l['coverImage'].toString(),
        'price': '${(l['price'] as num).toStringAsFixed(0)}$currencySuffix',
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
    agentCoverImage: agentCoverImage,
    agentAddress: agentAddress,
    agentLat: agentLat,
    agentLng: agentLng,
    themeId: themeId,
    fontPackageId: fontPackageId,
    density: density,
    galleryStyle: galleryStyle,
    lang: lang,
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
      fontPackageId: fontPackageId,
      density: density,
      galleryStyle: galleryStyle,
      lang: lang,
    );
  }

  return files;
}
