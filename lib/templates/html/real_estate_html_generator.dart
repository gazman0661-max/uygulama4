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
  String? agentGoogleReviewLink, // 01.09.2026 eklendi
  String? agentCoverImage,
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  // 05.09.2026 eklendi (kanka isteği) — kullanıcı bu bölümlerin sırasını
  // form ekranında sürükle-bırakla değiştirebilir (bkz.
  // widgets/section_order_field.dart). 05.09.2026 değişti (kanka isteği,
  // "tam özgürlük olsun") — 'hero' de dahil, HİÇBİR bölüm artık sabit
  // DEĞİL, hepsi taşınabilir. Varsayılan liste, bu fonksiyonun ESKİ sabit
  // sırasıyla BİREBİR AYNI — bu yüzden order verilmezse (eski kayıtlı
  // formlar) hiçbir şey değişmez.
  List<String> sectionOrder = const ['hero', 'reviewButton', 'listings', 'testimonials', 'faq'],
}) {
  final cardData = listings.map((l) => {
        ...l,
        'href': 'listing_${l['id']}.html',
      }).toList();
  final subtext = themeOf(themeId)['subtext']!;

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

  final _reviewBtnHero = googleReviewButtonHtml(agentGoogleReviewLink, lang: lang);
  final reviewButtonHtml = _reviewBtnHero.isNotEmpty
      ? '<div style="text-align:center;margin-top:8px;">$_reviewBtnHero</div>'
      : '';

  // 05.09.2026 eklendi (kanka isteği) — sıralanabilir bölümler bir Map'e
  // toplanır, sonra kullanıcının [sectionOrder]'ına göre dizilir. Boş
  // içerikli bloklar (testimonials/faq yoksa) zaten boş string olduğu
  // için otomatik atlanır — davranış eskiyle BİREBİR AYNI, sadece SIRA
  // değişebiliyor.
  // 05.09.2026 değişti (kanka isteği, "tam özgürlük") — 'hero' de artık
  // sıralamaya DAHİL (önceden her zaman en üstte sabitti). headerHtml
  // zaten kapak fotoğrafı yoksa otomatik sade metin başlığa düşüyor
  // (bkz. yukarıdaki if/else) — bu davranış AYNEN korunuyor, sadece
  // konumu artık kullanıcı tarafından seçilebiliyor.
  final orderableBlocks = <String, String>{
    'hero': headerHtml,
    'reviewButton': reviewButtonHtml,
    'listings': propertyCardGridHtml(listings: cardData),
    'testimonials': testimonials.isNotEmpty ? testimonialBlockHtml(testimonials: testimonials, lang: lang) : '',
    'faq': faqs.isNotEmpty ? faqBlockHtml(faqs: faqs, lang: lang) : '',
  };

  final orderedSections = StringBuffer();
  final _writtenKeys = <String>{};
  for (final key in sectionOrder) {
    final html = orderableBlocks[key];
    if (html != null && html.trim().isNotEmpty) orderedSections.writeln(html);
    _writtenKeys.add(key);
  }
  // Güvenlik ağı: eski kayıtlı bir sectionOrder yeni bir anahtarı
  // içermiyorsa (ileride yeni bir bölüm eklenirse) o blok sessizce
  // ATLANMASIN diye sona eklenir.
  for (final entry in orderableBlocks.entries) {
    if (!_writtenKeys.contains(entry.key) && entry.value.trim().isNotEmpty) {
      orderedSections.writeln(entry.value);
    }
  }

  final body = orderedSections.toString();

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
  String? agentGoogleReviewLink, // 01.09.2026 eklendi
  // 05.09.2026 eklendi — Video bloğu (kanka isteği): ilan için ev turu videosu.
  String? videoUrl,
  String videoOrientation = 'landscape',
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  bool includeLeadForm = true, // 05.09.2026 eklendi
  // 05.09.2026 eklendi (kanka isteği) — kullanıcı bu bölümlerin sırasını
  // form ekranında sürükle-bırakla değiştirebilir (bkz.
  // widgets/section_order_field.dart). 05.09.2026 değişti (kanka isteği,
  // "tam özgürlük olsun") — 'contact' de dahil, HİÇBİR bölüm artık sabit
  // DEĞİL, hepsi taşınabilir. Varsayılan liste bu fonksiyonun ESKİ sabit
  // sırasıyla BİREBİR AYNI — order verilmezse (eski kayıtlı ilanlar)
  // hiçbir şey değişmez.
  List<String> sectionOrder = const ['gallery', 'video', 'propertyDetails', 'map', 'contact'],
  // 05.09.2026 eklendi (kanka isteği, "serbest yerleşim") — true olursa
  // galeri TEK bir bloka gruplanmaz; her fotoğraf, [photoLayoutOrder]'da
  // verilen sırayla, video/İlan Bilgileri/harita/iletişim ile AYNI
  // seviyede bağımsız bir bölüm olarak basılır (böylece kullanıcı 1.
  // fotoğrafı en üste, 2. fotoğrafı Harita'nın altına koyabilir).
  // false ise (varsayılan, eski davranış) [sectionOrder] ve bundled
  // 'gallery' bloğu kullanılır — mevcut ilanlar ETKİLENMEZ.
  bool freeformLayout = false,
  // 'photo::<url>' anahtarlarıyla fotoğrafları + 'video'/'propertyDetails'/
  // 'map'/'contact' anahtarlarını karışık sırada içerir (bkz.
  // real_estate_form_screen.dart > _ListingEditorSheetState._photoLayoutOrder).
  List<String>? photoLayoutOrder,
}) {
  final body = StringBuffer();
  final labels = siteLabels(lang);
  final propertyLabels = lang == 'en'
      ? {'price': 'Price', 'm2': 'm²', 'room': 'Rooms', 'floor': 'Floor', 'dues': 'HOA Fee', 'currency': ''}
      : {'price': 'Fiyat', 'm2': 'm²', 'room': 'Oda', 'floor': 'Kat', 'dues': 'Aidat', 'currency': ' TL'};
  final contactTitle = lang == 'en' ? 'Get in Touch' : 'İletişime Geç';

  final propertyDetailsHtml = propertyDetailsBlockHtml(
    details: {
      propertyLabels['price']!: '${price.toStringAsFixed(0)}${propertyLabels['currency']}',
      propertyLabels['m2']!: m2.toStringAsFixed(0),
      propertyLabels['room']!: roomLabel,
      if (floor != null) propertyLabels['floor']!: floor.toString(),
      if (aidat != null) propertyLabels['dues']!: '${aidat.toStringAsFixed(0)}${propertyLabels['currency']}',
    },
    description: description,
  );
  final videoHtml = (videoUrl != null && videoUrl.trim().isNotEmpty)
      ? videoBlockHtml(title: labels['videoTitle']!, videoUrl: videoUrl, orientation: videoOrientation, lang: lang)
      : '';
  final mapHtml = address.trim().isNotEmpty
      ? mapBlockHtml(title: labels['location']!, address: address, lat: lat, lng: lng, lang: lang)
      : '';
  final contactHtml = contactBlockHtml(
    title: contactTitle,
    phone: agentPhone,
    whatsapp: agentWhatsapp,
    googleReviewLink: agentGoogleReviewLink,
    lang: lang,
    siteName: title,
    includeLeadForm: includeLeadForm,
  );

  // 05.09.2026 eklendi (kanka isteği, "serbest yerleşim") — galeri bir
  // tek blok yerine fotoğraf başına bağımsız bölümlere ayrılıyor,
  // [photoLayoutOrder]'daki karışık sırayla diğer bloklarla iç içe basılır.
  if (freeformLayout && photoLayoutOrder != null && photoLayoutOrder.isNotEmpty) {
    final photoBlocks = <String, String>{
      for (final img in gallery)
        if ((img['url'] ?? '').isNotEmpty)
          'photo::${img['url']}': singlePhotoBlockHtml(url: img['url']!, caption: img['caption']),
    };
    final fixedBlocks = <String, String>{
      'video': videoHtml,
      'propertyDetails': propertyDetailsHtml,
      'map': mapHtml,
      'contact': contactHtml,
    };
    final freeformBlocks = <String, String>{...photoBlocks, ...fixedBlocks};
    final _writtenFreeKeys = <String>{};
    for (final key in photoLayoutOrder) {
      final html = freeformBlocks[key];
      if (html != null && html.trim().isNotEmpty) body.writeln(html);
      _writtenFreeKeys.add(key);
    }
    // Güvenlik ağı: sıralamada olmayan (ör. sonradan eklenen) bir
    // fotoğraf/blok sessizce atlanmasın diye sona eklenir.
    for (final entry in freeformBlocks.entries) {
      if (!_writtenFreeKeys.contains(entry.key) && entry.value.trim().isNotEmpty) {
        body.writeln(entry.value);
      }
    }
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

  // 05.09.2026 eklendi (kanka isteği) — sıralanabilir bölümler bir Map'e
  // toplanır, sonra [sectionOrder]'a göre dizilir. Boş içerikli bloklar
  // (galeri/video/harita yoksa) zaten boş string olduğu için otomatik
  // atlanır — davranış eskiyle BİREBİR AYNI, sadece SIRA değişebiliyor.
  // 05.09.2026 değişti (kanka isteği, "tam özgürlük") — 'contact' de
  // artık sıralamaya DAHİL (önceden her zaman en altta sabitti).
  final orderableBlocks = <String, String>{
    'gallery': gallery.isNotEmpty ? galleryBlockHtml(style: galleryStyle, title: title, images: gallery) : '',
    'video': videoHtml,
    'propertyDetails': propertyDetailsHtml,
    'map': mapHtml,
    // 05.09.2026 değişti — önceden burada değil, döngüden sonra sabit
    // basılıyordu (bkz. aşağıdaki eski yorum). Artık diğerleriyle aynı
    // Map'te, sıralamaya tabi.
    'contact': contactHtml,
  };

  final _writtenKeys = <String>{};
  for (final key in sectionOrder) {
    final html = orderableBlocks[key];
    if (html != null && html.trim().isNotEmpty) body.writeln(html);
    _writtenKeys.add(key);
  }
  // Güvenlik ağı: eski kayıtlı bir sectionOrder yeni bir anahtarı
  // içermiyorsa (ileride yeni bir bölüm eklenirse) o blok sessizce
  // ATLANMASIN diye sona eklenir.
  for (final entry in orderableBlocks.entries) {
    if (!_writtenKeys.contains(entry.key) && entry.value.trim().isNotEmpty) {
      body.writeln(entry.value);
    }
  }

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
  String? agentGoogleReviewLink, // 01.09.2026 eklendi
  required List<Map<String, dynamic>> listings, // tüm ilan detaylarını içerir
  String? agentCoverImage,
  String themeId = 'clean_light',
  String fontPackageId = 'modern_sade',
  String density = 'normal',
  String galleryStyle = 'grid',
  String lang = 'tr',
  List<Map<String, String>> faqs = const [],
  List<Map<String, dynamic>> testimonials = const [],
  bool includeLeadForm = true, // 05.09.2026 eklendi
  // 05.09.2026 eklendi (kanka isteği) — bkz. generateListingListHtml/
  // generateListingDetailHtml içindeki sectionOrder dokümanı.
  List<String> indexSectionOrder = const ['hero', 'reviewButton', 'listings', 'testimonials', 'faq'],
  List<String> detailSectionOrder = const ['gallery', 'video', 'propertyDetails', 'map', 'contact'],
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
    agentGoogleReviewLink: agentGoogleReviewLink,
    agentCoverImage: agentCoverImage,
    themeId: themeId,
    fontPackageId: fontPackageId,
    density: density,
    galleryStyle: galleryStyle,
    lang: lang,
    faqs: faqs,
    testimonials: testimonials,
    sectionOrder: indexSectionOrder,
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
      agentGoogleReviewLink: agentGoogleReviewLink,
      videoUrl: l['videoUrl']?.toString(),
      videoOrientation: l['videoOrientation']?.toString() ?? 'landscape',
      themeId: themeId,
      fontPackageId: fontPackageId,
      density: density,
      galleryStyle: galleryStyle,
      lang: lang,
      includeLeadForm: includeLeadForm,
      sectionOrder: detailSectionOrder,
      // 05.09.2026 eklendi (kanka isteği, "serbest yerleşim") — bkz.
      // generateListingDetailHtml > freeformLayout/photoLayoutOrder.
      freeformLayout: (l['freeformLayout'] as bool?) ?? false,
      photoLayoutOrder: (l['photoLayoutOrder'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  return files;
}
