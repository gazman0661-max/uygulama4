/// Ortak HTML blok üreticileri.
///
/// Her fonksiyon, ilgili Flutter widget paketindeki (kuafor_site_template,
/// beauty_salon_template, vb.) görsel tasarımın HTML/CSS karşılığıdır.
/// AI çağrısı YOKTUR — tamamen yerel string birleştirme.
///
/// Bu dosya business_site_html_generator.dart ve diğer sektör
/// generator'ları tarafından import edilir. Yeni bir sektör eklerken
/// önce burada eksik bir blok var mı bak, varsa reuse et.
library shared_html_blocks;

/// Basit HTML escape — kullanıcı girdisi (isim, açıklama vb.) doğrudan
/// HTML'e basılmadan önce MUTLAKA bu fonksiyondan geçmeli.
String escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Hero (üst kapak) bölümü. Tüm sektör şablonlarında ilk bölüm budur.
String heroBlockHtml({
  required String name,
  required String tagline,
  required String coverImage,
  String? logoImage,
  String ctaText = 'Randevu Al',
  String? ctaHref,
}) {
  final logoHtml = logoImage != null
      ? '<img class="hero-logo" src="${escapeHtml(logoImage)}" alt="logo">'
      : '';
  final ctaHtml = ctaHref != null
      ? '<a class="hero-cta" href="${escapeHtml(ctaHref)}">${escapeHtml(ctaText)}</a>'
      : '';
  return '''
<section class="hero" style="background-image:url('${escapeHtml(coverImage)}')">
  <div class="hero-overlay">
    $logoHtml
    <h1 class="hero-title">${escapeHtml(name)}</h1>
    <p class="hero-tagline">${escapeHtml(tagline)}</p>
    $ctaHtml
  </div>
</section>''';
}

/// Hizmet listesi bloğu (ad + opsiyonel süre + fiyat).
/// Kuaför, oto yıkama, klinik gibi sektörlerde kullanılır.
String serviceListBlockHtml({
  required String title,
  required List<Map<String, String?>> services, // name, duration, price
}) {
  final rows = services.map((s) {
    final durationHtml = s['duration'] != null
        ? '<span class="service-duration">${escapeHtml(s['duration']!)}</span>'
        : '';
    return '''
    <li class="service-row">
      <span class="service-name">${escapeHtml(s['name'] ?? '')}</span>
      $durationHtml
      <span class="service-price">${escapeHtml(s['price'] ?? '')}</span>
    </li>''';
  }).join('\n');

  return '''
<section class="section services-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <ul class="service-list">
$rows
  </ul>
</section>''';
}

/// Galeri bloğu — ızgara görünüm, tam ekran açılabilir (lightbox, basit CSS).
String galleryBlockHtml({
  required String title,
  required List<Map<String, String?>> images, // url, caption
  bool beforeAfter = false,
}) {
  final items = images.map((img) {
    final caption = img['caption'] != null
        ? '<span class="gallery-caption">${escapeHtml(img['caption']!)}</span>'
        : '';
    return '''
    <div class="gallery-item" onclick="document.getElementById('${_idFor(img['url'] ?? '')}').classList.add('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="">
      $caption
    </div>
    <div class="gallery-lightbox" id="${_idFor(img['url'] ?? '')}" onclick="this.classList.remove('open')">
      <img src="${escapeHtml(img['url'] ?? '')}" alt="">
    </div>''';
  }).join('\n');

  return '''
<section class="section gallery-section${beforeAfter ? ' before-after' : ''}">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="gallery-grid">
$items
  </div>
</section>''';
}

String _idFor(String url) => 'gal_${url.hashCode.abs()}';

/// Çalışma saatleri tablosu.
String workingHoursBlockHtml({
  required String title,
  required List<Map<String, String?>> hours, // day, range (null = kapalı)
}) {
  final rows = hours.map((h) {
    final range = h['range'] ?? 'Kapalı';
    return '''
    <tr>
      <td>${escapeHtml(h['day'] ?? '')}</td>
      <td>${escapeHtml(range)}</td>
    </tr>''';
  }).join('\n');

  return '''
<section class="section hours-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <table class="hours-table">
$rows
  </table>
</section>''';
}

/// Harita bloğu — Google Maps embed iframe (API key gerektirmez).
String mapBlockHtml({
  required String title,
  required String address,
  required double lat,
  required double lng,
}) {
  return '''
<section class="section map-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <p class="address-text">${escapeHtml(address)}</p>
  <div class="map-embed">
    <iframe
      width="100%" height="300" style="border:0" loading="lazy"
      src="https://maps.google.com/maps?q=$lat,$lng&z=15&output=embed">
    </iframe>
  </div>
  <a class="directions-link" target="_blank"
     href="https://www.google.com/maps/dir/?api=1&destination=$lat,$lng">
     Yol Tarifi Al
  </a>
</section>''';
}

/// İletişim bloğu — telefon / WhatsApp / Instagram butonları.
String contactBlockHtml({
  required String title,
  String? phone,
  String? whatsapp,
  String? instagram,
}) {
  final buttons = <String>[];
  if (phone != null) {
    buttons.add('<a class="contact-btn phone" href="tel:${escapeHtml(phone)}">📞 Ara</a>');
  }
  if (whatsapp != null) {
    buttons.add('<a class="contact-btn whatsapp" target="_blank" href="https://wa.me/${escapeHtml(whatsapp)}">💬 WhatsApp</a>');
  }
  if (instagram != null) {
    buttons.add('<a class="contact-btn instagram" target="_blank" href="https://instagram.com/${escapeHtml(instagram)}">📷 Instagram</a>');
  }
  return '''
<section class="section contact-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="contact-buttons">
    ${buttons.join('\n    ')}
  </div>
</section>''';
}

/// Menü bloğu (kategori + ürün) — kafe/restoran için.
String menuBlockHtml({
  required String title,
  required List<Map<String, dynamic>> categories, // {title, items:[{name,description,price}]}
}) {
  final catHtml = categories.map((cat) {
    final items = (cat['items'] as List).map((item) {
      final desc = item['description'] != null && (item['description'] as String).isNotEmpty
          ? '<p class="menu-item-desc">${escapeHtml(item['description'])}</p>'
          : '';
      return '''
      <li class="menu-item">
        <div class="menu-item-main">
          <span class="menu-item-name">${escapeHtml(item['name'] ?? '')}</span>
          <span class="menu-item-price">${escapeHtml(item['price'] ?? '')}</span>
        </div>
        $desc
      </li>''';
    }).join('\n');
    return '''
    <div class="menu-category">
      <h3 class="menu-category-title">${escapeHtml(cat['title'] ?? '')}</h3>
      <ul class="menu-item-list">
$items
      </ul>
    </div>''';
  }).join('\n');

  return '''
<section class="section menu-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  $catHtml
</section>''';
}

/// Randevu formu bloğu — statik HTML'de gerçek backend olmadığı için
/// gönderince WhatsApp'a yönlendiren basit bir form (mailto/wa.me).
String randevuBlockHtml({
  required String title,
  required String whatsapp,
}) {
  return '''
<section class="section randevu-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <form class="randevu-form" onsubmit="event.preventDefault();
    const ad=document.getElementById('rv_ad').value;
    const tarih=document.getElementById('rv_tarih').value;
    const not=document.getElementById('rv_not').value;
    const msg=encodeURIComponent('Randevu talebi - Ad: '+ad+' Tarih: '+tarih+' Not: '+not);
    window.open('https://wa.me/${escapeHtml(whatsapp)}?text='+msg,'_blank');">
    <input id="rv_ad" placeholder="Ad Soyad" required>
    <input id="rv_tarih" placeholder="Tercih edilen tarih/saat" required>
    <textarea id="rv_not" placeholder="Not (opsiyonel)"></textarea>
    <button type="submit">Randevu Talebi Gönder</button>
  </form>
</section>''';
}

/// Paket/üyelik kartları — güzellik salonu ve fitness'ta kullanılır.
String packageCardsBlockHtml({
  required String title,
  required List<Map<String, dynamic>> packages, // {title, sessionLabel, price, originalPrice, includedServices:[], note, isFeatured}
}) {
  final cards = packages.map((p) {
    final featured = p['isFeatured'] == true ? ' featured' : '';
    final original = p['originalPrice'] != null
        ? '<span class="pkg-original-price">${escapeHtml(p['originalPrice'].toString())}</span>'
        : '';
    final included = (p['includedServices'] as List? ?? [])
        .map((s) => '<li>${escapeHtml(s.toString())}</li>')
        .join('\n');
    final note = p['note'] != null
        ? '<p class="pkg-note">${escapeHtml(p['note'].toString())}</p>'
        : '';
    return '''
    <div class="pkg-card$featured">
      <h3 class="pkg-title">${escapeHtml(p['title']?.toString() ?? '')}</h3>
      <p class="pkg-session">${escapeHtml(p['sessionLabel']?.toString() ?? '')}</p>
      <div class="pkg-price">$original<span>${escapeHtml(p['price']?.toString() ?? '')}</span></div>
      <ul class="pkg-included">$included</ul>
      $note
    </div>''';
  }).join('\n');

  return '''
<section class="section packages-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="pkg-grid">
$cards
  </div>
</section>''';
}

/// Ekip/eğitmen/uzman tanıtım kartları.
String teamBlockHtml({
  required String title,
  required List<Map<String, dynamic>> members, // {name, specialty, photoUrl, bio, tags:[]}
}) {
  final cards = members.map((m) {
    final tags = (m['tags'] as List? ?? [])
        .map((t) => '<span class="team-tag">${escapeHtml(t.toString())}</span>')
        .join('');
    final bio = m['bio'] != null
        ? '<p class="team-bio">${escapeHtml(m['bio'].toString())}</p>'
        : '';
    return '''
    <div class="team-card">
      <img class="team-photo" src="${escapeHtml(m['photoUrl']?.toString() ?? '')}" alt="">
      <h3 class="team-name">${escapeHtml(m['name']?.toString() ?? '')}</h3>
      <p class="team-specialty">${escapeHtml(m['specialty']?.toString() ?? '')}</p>
      $bio
      <div class="team-tags">$tags</div>
    </div>''';
  }).join('\n');

  return '''
<section class="section team-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="team-grid">
$cards
  </div>
</section>''';
}

/// Doktor/uzman tanıtım bloğu (klinik).
String practitionerBlockHtml({
  required String name,
  required String title,
  required String photoUrl,
  required String bio,
  required List<Map<String, String?>> credentials, // {label}
}) {
  final badges = credentials
      .map((c) => '<span class="cred-badge">${escapeHtml(c['label'] ?? '')}</span>')
      .join('\n');
  return '''
<section class="section practitioner-section">
  <img class="practitioner-photo" src="${escapeHtml(photoUrl)}" alt="">
  <h2 class="practitioner-name">${escapeHtml(name)}</h2>
  <p class="practitioner-title">${escapeHtml(title)}</p>
  <p class="practitioner-bio">${escapeHtml(bio)}</p>
  <div class="cred-badges">$badges</div>
</section>''';
}

/// Program tablosu (gün x saat) — fitness stüdyosu.
String scheduleTableBlockHtml({
  required String title,
  required List<Map<String, String?>> entries, // {day, time, className, trainer}
}) {
  final rows = entries.map((e) {
    final trainer = e['trainer'] != null ? ' — ${escapeHtml(e['trainer']!)}' : '';
    return '''
    <tr>
      <td>${escapeHtml(e['day'] ?? '')}</td>
      <td>${escapeHtml(e['time'] ?? '')}</td>
      <td>${escapeHtml(e['className'] ?? '')}$trainer</td>
    </tr>''';
  }).join('\n');

  return '''
<section class="section schedule-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <table class="schedule-table">
$rows
  </table>
</section>''';
}

/// Zaman çizelgesi (deneyim/eğitim) — portfolyo.
String timelineBlockHtml({
  required String title,
  required List<Map<String, String?>> entries, // {year, title, description}
}) {
  final items = entries.map((e) {
    return '''
    <div class="timeline-item">
      <span class="timeline-year">${escapeHtml(e['year'] ?? '')}</span>
      <div class="timeline-body">
        <h3>${escapeHtml(e['title'] ?? '')}</h3>
        <p>${escapeHtml(e['description'] ?? '')}</p>
      </div>
    </div>''';
  }).join('\n');

  return '''
<section class="section timeline-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <div class="timeline">
$items
  </div>
</section>''';
}

/// Yetenek/uzmanlık etiketleri (chip listesi) — portfolyo.
String skillChipsBlockHtml(List<String> skills) {
  final chips = skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join('\n');
  return '<div class="skill-chips">\n$chips\n</div>';
}

/// İletişim formu — gönderince mailto: üzerinden e-postaya yönlendirir.
String contactFormBlockHtml({
  required String title,
  required String email,
}) {
  return '''
<section class="section contact-form-section">
  <h2 class="section-title">${escapeHtml(title)}</h2>
  <form class="contact-form" onsubmit="event.preventDefault();
    const ad=document.getElementById('cf_ad').value;
    const eposta=document.getElementById('cf_eposta').value;
    const mesaj=document.getElementById('cf_mesaj').value;
    window.location.href='mailto:${escapeHtml(email)}?subject='+encodeURIComponent('Site üzerinden mesaj - '+ad)+'&body='+encodeURIComponent(mesaj+'\\n\\nCevap için: '+eposta);">
    <input id="cf_ad" placeholder="Ad Soyad" required>
    <input id="cf_eposta" type="email" placeholder="E-posta" required>
    <textarea id="cf_mesaj" placeholder="Mesajınız" required></textarea>
    <button type="submit">Gönder</button>
  </form>
</section>''';
}

/// Emlak ilan kartı ızgarası (liste sayfası).
String propertyCardGridHtml({
  required List<Map<String, String?>> listings, // {id, title, coverImage, price, m2, roomLabel, locationTag, href}
}) {
  final cards = listings.map((l) {
    return '''
    <a class="property-card" href="${escapeHtml(l['href'] ?? '#')}">
      <img src="${escapeHtml(l['coverImage'] ?? '')}" alt="">
      <div class="property-card-body">
        <h3>${escapeHtml(l['title'] ?? '')}</h3>
        <p class="property-tags">${escapeHtml(l['roomLabel'] ?? '')} · ${escapeHtml(l['m2'] ?? '')} m² · ${escapeHtml(l['locationTag'] ?? '')}</p>
        <p class="property-price">${escapeHtml(l['price'] ?? '')}</p>
      </div>
    </a>''';
  }).join('\n');

  return '''
<div class="property-grid">
$cards
</div>''';
}

/// Emlak ilan detay bilgi tablosu.
String propertyDetailsBlockHtml({
  required Map<String, String?> details, // {price, m2, roomLabel, floor, aidat}
  required String description,
}) {
  final rows = details.entries.where((e) => e.value != null).map((e) {
    return '<tr><td>${escapeHtml(e.key)}</td><td>${escapeHtml(e.value!)}</td></tr>';
  }).join('\n');

  return '''
<section class="section property-details-section">
  <table class="property-details-table">
$rows
  </table>
  <p class="property-description">${escapeHtml(description)}</p>
</section>''';
}

/// vCard indirme linki (data URI ile — sunucu gerekmez).
String vcardSectionHtml({
  required String name,
  required String title,
  required String? company,
  required String phone,
  required String? email,
}) {
  final vcard = 'BEGIN:VCARD\\nVERSION:3.0\\nFN:$name\\nTITLE:$title\\n'
      '${company != null ? 'ORG:$company\\n' : ''}'
      'TEL:$phone\\n'
      '${email != null ? 'EMAIL:$email\\n' : ''}'
      'END:VCARD';
  return '''
<a class="vcard-btn" download="${escapeHtml(name)}.vcf"
   href="data:text/vcard;charset=utf-8,${Uri.encodeComponent(vcard)}">
   📇 Kişiye Ekle
</a>''';
}

/// Tüm sayfayı saran ortak CSS + HTML iskeleti.
/// [bodyHtml] yukarıdaki blokların birleştirilmiş hali olmalı.
String wrapPageHtml({
  required String pageTitle,
  required String bodyHtml,
  String accentColor = '#212529',
}) {
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(pageTitle)}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, Roboto, sans-serif; color: #212529; line-height: 1.5; }
  .hero { position: relative; height: 60vh; min-height: 320px; background-size: cover; background-position: center; display:flex; align-items:center; justify-content:center; }
  .hero-overlay { background: rgba(0,0,0,0.45); width:100%; height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; padding: 24px; color: white; }
  .hero-logo { width: 72px; height: 72px; border-radius: 50%; margin-bottom: 12px; object-fit: cover; }
  .hero-title { font-size: 32px; font-weight: 700; margin-bottom: 8px; }
  .hero-tagline { font-size: 16px; opacity: 0.9; margin-bottom: 20px; }
  .hero-cta { background: $accentColor; color: white; padding: 12px 28px; border-radius: 30px; text-decoration: none; font-weight: 600; }
  .section { max-width: 720px; margin: 0 auto; padding: 40px 20px; }
  .section-title { font-size: 22px; font-weight: 700; margin-bottom: 20px; }
  .service-list { list-style: none; }
  .service-row { display:flex; align-items:center; gap: 12px; padding: 14px 0; border-bottom: 1px solid #eee; }
  .service-name { flex: 1; font-weight: 600; }
  .service-duration { color: #888; font-size: 13px; }
  .service-price { font-weight: 700; color: $accentColor; }
  .gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px,1fr)); gap: 8px; }
  .gallery-item { position: relative; aspect-ratio: 1; overflow: hidden; border-radius: 10px; cursor: pointer; }
  .gallery-item img { width:100%; height:100%; object-fit: cover; }
  .gallery-lightbox { display:none; position: fixed; inset:0; background: rgba(0,0,0,0.9); z-index:999; align-items:center; justify-content:center; }
  .gallery-lightbox.open { display:flex; }
  .gallery-lightbox img { max-width: 92%; max-height: 92%; }
  .hours-table { width:100%; border-collapse: collapse; }
  .hours-table td { padding: 10px 0; border-bottom: 1px solid #eee; }
  .hours-table td:last-child { text-align: right; }
  .map-embed { border-radius: 12px; overflow: hidden; margin: 16px 0; }
  .directions-link { display:inline-block; color: $accentColor; font-weight: 600; text-decoration: none; }
  .contact-buttons { display:flex; flex-wrap: wrap; gap: 12px; }
  .contact-btn { padding: 12px 20px; border-radius: 10px; text-decoration:none; font-weight:600; color:white; background:$accentColor; }
  .menu-category { margin-bottom: 24px; }
  .menu-category-title { font-size: 18px; font-weight:700; margin-bottom: 10px; color: $accentColor; }
  .menu-item { padding: 10px 0; border-bottom: 1px solid #eee; }
  .menu-item-main { display:flex; justify-content: space-between; font-weight:600; }
  .menu-item-desc { color:#888; font-size: 13px; margin-top:4px; }
  .randevu-form { display:flex; flex-direction:column; gap: 12px; max-width: 420px; }
  .randevu-form input, .randevu-form textarea { padding: 12px; border-radius: 8px; border: 1px solid #ddd; font-size:15px; }
  .randevu-form button { padding: 14px; border:none; border-radius: 8px; background:$accentColor; color:white; font-weight:700; cursor:pointer; }
  .pkg-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(220px,1fr)); gap:16px; }
  .pkg-card { border:1px solid #eee; border-radius:14px; padding:20px; }
  .pkg-card.featured { border-color:$accentColor; border-width:2px; }
  .pkg-title { font-size:17px; font-weight:700; margin-bottom:4px; }
  .pkg-session { color:#888; font-size:13px; margin-bottom:10px; }
  .pkg-price { font-size:20px; font-weight:800; color:$accentColor; margin-bottom:10px; }
  .pkg-original-price { text-decoration:line-through; color:#aaa; font-size:14px; margin-right:8px; }
  .pkg-included { list-style:none; font-size:13px; color:#555; margin-bottom:8px; }
  .pkg-included li { padding:2px 0; }
  .pkg-note { font-size:12px; color:#999; }
  .team-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(160px,1fr)); gap:16px; }
  .team-card { text-align:center; }
  .team-photo { width:88px; height:88px; border-radius:50%; object-fit:cover; margin-bottom:10px; }
  .team-name { font-size:15px; font-weight:700; }
  .team-specialty { font-size:13px; color:#888; margin-bottom:6px; }
  .team-bio { font-size:12px; color:#666; margin-bottom:6px; }
  .team-tags { display:flex; flex-wrap:wrap; gap:6px; justify-content:center; }
  .team-tag { font-size:11px; background:#f1f1f1; padding:3px 8px; border-radius:10px; }
  .practitioner-section { text-align:center; }
  .practitioner-photo { width:110px; height:110px; border-radius:50%; object-fit:cover; margin-bottom:12px; }
  .practitioner-name { font-size:20px; font-weight:700; }
  .practitioner-title { color:$accentColor; font-weight:600; margin-bottom:10px; }
  .practitioner-bio { color:#555; margin-bottom:12px; }
  .cred-badges { display:flex; flex-wrap:wrap; gap:8px; justify-content:center; }
  .cred-badge { font-size:12px; background:#f1f1f1; padding:4px 10px; border-radius:10px; }
  .schedule-table { width:100%; border-collapse:collapse; }
  .schedule-table td { padding:10px; border-bottom:1px solid #eee; font-size:14px; }
  .timeline { border-left:2px solid #eee; padding-left:20px; }
  .timeline-item { margin-bottom:20px; }
  .timeline-year { font-weight:700; color:$accentColor; font-size:13px; }
  .timeline-body h3 { font-size:15px; margin:4px 0; }
  .timeline-body p { font-size:13px; color:#666; }
  .skill-chips { display:flex; flex-wrap:wrap; gap:8px; }
  .skill-chip { background:#f1f1f1; padding:6px 14px; border-radius:14px; font-size:13px; }
  .contact-form { display:flex; flex-direction:column; gap:12px; max-width:420px; }
  .contact-form input, .contact-form textarea { padding:12px; border-radius:8px; border:1px solid #ddd; font-size:15px; }
  .contact-form button { padding:14px; border:none; border-radius:8px; background:$accentColor; color:white; font-weight:700; cursor:pointer; }
  .property-grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap:16px; padding: 20px; max-width:960px; margin:0 auto; }
  .property-card { border-radius:12px; overflow:hidden; border:1px solid #eee; text-decoration:none; color:inherit; display:block; }
  .property-card img { width:100%; height:140px; object-fit:cover; }
  .property-card-body { padding:12px; }
  .property-card-body h3 { font-size:14px; margin-bottom:4px; }
  .property-tags { font-size:12px; color:#888; margin-bottom:6px; }
  .property-price { font-weight:700; color:$accentColor; }
  .property-details-table { width:100%; border-collapse:collapse; margin-bottom:16px; }
  .property-details-table td { padding:8px 0; border-bottom:1px solid #eee; }
  .property-details-table td:first-child { color:#888; }
  .property-description { color:#444; }
  .vcard-btn { display:inline-block; padding:12px 24px; border-radius:10px; background:$accentColor; color:white; text-decoration:none; font-weight:700; margin-top:16px; }
</style>
</head>
<body>
$bodyHtml
</body>
</html>''';
}
