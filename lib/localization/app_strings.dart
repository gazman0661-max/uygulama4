import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'locale_controller.dart';

/// Uygulama arayüzünde kullanılan tüm Türkçe metinlerin İngilizce
/// karşılıklarını tutan sözlük. Anahtar olarak orijinal Türkçe metin
/// kullanılır; bu sayede kod içinde ayrı bir "key" sistemi kurmaya
/// gerek kalmaz — dil Türkçe olduğunda metin zaten olduğu gibi doğru
/// döner, İngilizce olduğunda bu haritadan karşılığı aranır.
///
/// NOT: Bu sözlük yalnızca UYGULAMA ARAYÜZÜ metinlerini içerir.
/// Form ile üretilen web sitesi kodunun (HTML/CSS) içindeki metinler
/// kullanıcı içeriğidir ve KESİNLİKLE çevrilmez.
class AppStrings {
  AppStrings._();

  static const Map<String, String> en = <String, String>{
    // 19.09.2026 eklendi (kanka isteği) — ürün bazlı yasal bilgi
    // (bkz. widgets/menu_legal_info_field.dart)
    'Ürün Bazlı Yasal Bilgiler (Alerjen / Kalori / İçerik)': 'Per-Item Legal Info (Allergens / Calories / Content)',
    'Abonelikte': 'Subscription',
    'Bu özellik abonelikle açılır': 'This feature unlocks with a subscription',
    'Abonelik planlarını gör': 'View subscription plans',
    'Gıda Bilgilendirme Yönetmeliği kapsamında müşterilerin görmesi gereken içerik/alerjen bilgisini ürün altında gösterir. Hangi bilgilerin zorunlu olduğunu yayına almadan önce kendi işletme türün için doğrula.':
        'Shows the content/allergen info customers need to see under each item, per Turkey\'s food information regulation. Verify which fields are mandatory for your business type before publishing.',
    'Önce yukarıya menü ürünlerini ekle — her ürün için ayrı ayrı burada alerjen/kalori/içerik bilgisi girebilirsin.':
        'Add your menu items above first — then you can enter allergen/calorie/content info for each one here.',
    'Dokunup yasal bilgi ekle': 'Tap to add legal info',
    'Alkol/Domuz': 'Alcohol/Pork',
    'Alerjenler': 'Allergens',
    'Kalori (kcal)': 'Calories (kcal)',
    'Et türü': 'Meat type',
    'Alkol veya domuz içerir': 'Contains alcohol or pork',
    'Alkol içerir': 'Contains alcohol',
    'Domuz içerir': 'Contains pork',
    'Bu ürün eski kayıtta tek "alkol/domuz" seçeneğiyle işaretlenmiş — lütfen aşağıda ayrı ayrı işaretle.':
        'This item was saved with a single "alcohol/pork" flag — please mark them separately below.',
    'Yasal bilgiler siteye basılmayacak': 'Legal info will not appear on your site',
    'Menüde alerjen/kalori/içerik bilgisi girilmiş ama aktif aboneliğin yok, bu yüzden bu bilgiler yayınlanan sitede GÖRÜNMEYECEK. Yine de devam edilsin mi?':
        'You entered allergen/calorie/content info, but you have no active subscription, so it will NOT appear on the published site. Continue anyway?',
    'Yine de üret': 'Generate anyway',
    'Yayınlamak için giriş yapmış olmalısın.': 'You need to be signed in to publish.',
    'Çok fazla yayınlama isteği yapıldı, biraz sonra tekrar dene.': 'Too many publish requests, please try again shortly.',
    'Giriş yapmış olmalısın.': 'You need to be signed in.',
    'Doğrulanmış bir mini paket satın alımı bulunamadı.': 'No verified mini package purchase was found.',
    'Doğrulanmış bir rozet kaldırma satın alımı bulunamadı.': 'No verified badge removal purchase was found.',
    'Devam etmek için giriş yapmış olmalısın.': 'You need to be signed in to continue.',
    'Doğrulanmış bir domain satın alımı bulunamadı. Ödeme tamamlandıysa birkaç saniye sonra tekrar dene.':
        'No verified domain purchase was found. If your payment went through, try again in a few seconds.',
    'Siteyi devralmak için giriş yapmış olmalısın.': 'You need to be signed in to take over a site.',
    'Çok fazla hatalı kod denemesi yapıldı, biraz sonra tekrar dene.': 'Too many wrong code attempts, please try again shortly.',
    'Gluten': 'Gluten',
    'Süt': 'Dairy',
    'Yumurta': 'Egg',
    'Fıstık/Kuruyemiş': 'Peanuts/Nuts',
    'Yer Fıstığı': 'Peanuts',
    'Kuruyemiş': 'Tree nuts',
    'Yumuşakçalar': 'Molluscs',
    'Kereviz': 'Celery',
    'Hardal': 'Mustard',
    'Acı Bakla': 'Lupin',
    'Sülfit': 'Sulphites',
    'Soya': 'Soy',
    'Balık': 'Fish',
    'Kabuklu Deniz Ürünleri': 'Crustaceans',
    'Susam': 'Sesame',
    'Yok / Vejetaryen': 'None / Vegetarian',
    'Vejetaryen': 'Vegetarian',
    'Seçilmedi': 'Not selected',
    'Vegan': 'Vegan',
    'Dana': 'Beef',
    'Kuzu': 'Lamb',
    'Tavuk': 'Chicken',

    // 15.09.2026 eklendi (kanka isteği) — Bölüm Sırala/Gizle (bkz.
    // widgets/section_order_field.dart).
    'Bölüm Sırası ve Görünürlüğü': 'Section Order & Visibility',
    'Kapatılan bölüm sitede hiç görünmez. Tutup sürükleyerek sırasını değiştirebilirsin.':
        'A section you turn off never appears on the site. Press and drag to reorder.',
    // === Genel / Ortak butonlar ===
    'İptal': 'Cancel',

    // === "Talepler nereye gelsin?" (15.09.2026 eklendi, kanka isteği —
    // mailto tabanlı e-posta teslimatı, bkz. publish_sheet.dart) ===
    'Talepler için geçerli bir e-posta adresi gir.': 'Enter a valid email address for requests.',
    'Talepler nereye gelsin?': 'Where should requests go?',
    'Talep Kutusu': 'Request Inbox',
    'E-posta': 'Email',
    'İkisi de': 'Both',
    'Ziyaretçi formu gönderdiğinde kendi mail uygulamasından bu adrese e-posta açılır — ücretsiz ve sınırsızdır.':
        "When a visitor submits the form, an email to this address opens in their own mail app — free and unlimited.",

    // === "Proje Kopyalama" ve "Siteyi Devret" (14.09.2026 eklendi, kanka
    // isteği — freelancer/ajans modeli, bkz. proje sohbeti) ===
    'Proje kopyalandı.': 'Project duplicated.',
    'Siteyi Devret': 'Transfer Site',
    'için bir devir kodu üretilecek. Bu kodu müşterine WhatsApp\'tan iletebilirsin; kodu kullandığı an site TAMAMEN onun hesabına geçer (sen artık düzenleyemez/yayından kaldıramazsın). Devam edilsin mi?':
        'a transfer code will be generated for this. You can send this code to your customer via WhatsApp; the moment they use it, the site fully moves to their account (you will no longer be able to edit or unpublish it). Continue?',
    'Kod Üret': 'Generate Code',
    'Kodla Site Devral': 'Claim Site with Code',
    'artık senin — Projelerim listende görünüyor.': 'is now yours — it shows up in your Projects list.',
    'Devir Kodu Hazır': 'Transfer Code Ready',
    'Bu kodu müşterine ilet — Sitora hesabıyla "Kodla Site Devral"dan girince site tamamen ona geçer.':
        'Share this code with your customer — once they enter it under "Claim Site with Code" with their Sitora account, the site fully moves to them.',
    'Son geçerlilik': 'Valid until',
    'Kod kopyalandı.': 'Code copied.',
    'Sana iletilen devir kodunu gir — site Projelerim listene eklenecek.':
        'Enter the transfer code you were given — the site will be added to your Projects list.',
    'Devral': 'Claim',

    // === Eksik çeviriler (13.09.2026, kanka isteği — Play Store yorumunda
    // "tüm sayfalar tamamen İngilizce değil" şikayeti üzerine tarandı) ===
    'Dikey': 'Vertical',
    'Domain': 'Domain',
    // 18.09.2026 eklendi — Projelerim kartındaki ücretsiz plan 6 aylık
    // yayın sayacının etiketi (bkz. projects_screen.dart > _ProjectCard).
    'Ücretsiz Yayın': 'Free Publish',
    'Talep Formu': 'Lead Form',
    'Video Linki (opsiyonel)': 'Video Link (optional)',
    'Video Yönü': 'Video Orientation',
    'Yatay': 'Horizontal',
    'Ziyaretçi sayısı — Premium': 'Visitor count — Premium',

    // === Domain sağlayıcı rehberi (06.09.2026, kanka isteği) ===
    'Domainin nereden alındı? Adım adım göster': 'Where did you buy your domain? Show me step by step',
    '"Hesabım" → "Domain Yönetimi" → domainine tıkla': '"My Account" → "Domain Management" → click your domain',
    '"DNS Ayarları" / "DNS Yönetimi" sekmesine geç': 'Go to the "DNS Settings" / "DNS Management" tab',
    '"Yeni Kayıt Ekle" → Tür: CNAME seç': '"Add New Record" → Type: select CNAME',
    'Yukarıdaki Ad ve Hedef değerlerini ilgili kutulara yapıştır, kaydet': 'Paste the Name and Target values above into the matching fields, save',
    '"Domainlerim" → domainine tıkla → "DNS Yönetimi"': '"My Domains" → click your domain → "DNS Management"',
    '"Kayıt Ekle" → Tür: CNAME seç': '"Add Record" → Type: select CNAME',
    'Yukarıdaki Ad ve Hedef değerlerini gir, "Ekle"ye bas': 'Enter the Name and Target values above, click "Add"',
    '"Hizmetlerim" → "Domainler" → domainine tıkla': '"My Services" → "Domains" → click your domain',
    '"DNS Yönetimi" → "Kayıt Ekle" → CNAME seç': '"DNS Management" → "Add Record" → select CNAME',
    'Yukarıdaki Ad ve Hedef değerlerini yapıştır, kaydet': 'Paste the Name and Target values above, save',
    '"My Products" → domainin yanındaki "DNS" butonuna tıkla': '"My Products" → click the "DNS" button next to your domain',
    '"Add New Record" → Type: CNAME seç': '"Add New Record" → Type: select CNAME',
    'Yukarıdaki Ad değerini "Name/Host", Hedef değerini "Value" alanına yapıştır, kaydet': 'Paste the Name value above into "Name/Host" and the Target value into "Value", save',
    '"Domain List" → domainin yanındaki "Manage" butonuna tıkla': '"Domain List" → click the "Manage" button next to your domain',
    '"Advanced DNS" sekmesine geç → "Add New Record" → CNAME seç': 'Go to the "Advanced DNS" tab → "Add New Record" → select CNAME',
    'Yukarıdaki Ad ve Hedef değerlerini gir, yeşil onay işaretine tıkla': 'Enter the Name and Target values above, click the green checkmark',
    'Sağlayıcın listede yok mu? Panelinde "DNS Ayarları" veya "DNS Yönetimi" bölümünü ara, adı ve mantığı hep aynı.':
        'Provider not on this list? Look for a "DNS Settings" or "DNS Management" section in your panel — the name and logic are always similar.',
    'Domainini yeni aldıysan önce şunu kontrol et: kayıt firmasının (Natro, GoDaddy vb.) sana attığı "e-posta doğrulama / kimlik doğrulama" mailini onayladın mı? Onaylamazsan domain askıya alınır ve CNAME\'i doğru girsen bile hiçbir şekilde çalışmaz. Bu, MySitora dışında, tamamen domain firmasının/ICANN\'ın kuralı.':
        'If you just bought your domain, check this first: did you confirm the "email verification / identity verification" message your registrar (Natro, GoDaddy, etc.) sent you? If you don\'t, the domain gets suspended and won\'t work even if you enter the CNAME correctly. This is entirely your registrar\'s/ICANN\'s rule, unrelated to MySitora.',

    // === Sık Sorulan Sorular ekranı (06.09.2026, kanka isteği) ===
    'Sık Sorulan Sorular': 'FAQ',
    'Domainimi bağladım ama site açılmıyor, neden?': 'I connected my domain but the site won\'t open, why?',
    'En sık sebep: domaini yeni aldıysan, kayıt firmasının sana attığı "e-posta doğrulama" mailini onaylamamış olabilirsin — onaylanmadan domain askıda kalır, CNAME doğru olsa bile çalışmaz. Ayrıca DNS kaydının yayılması bazı sağlayıcılarda 24 saate kadar sürebilir, hemen açılmaması normal olabilir.':
        'The most common reason: if you just bought the domain, you may not have confirmed the "email verification" message your registrar sent you — without it the domain stays suspended and won\'t work even with a correct CNAME. Also, DNS propagation can take up to 24 hours with some providers, so it not opening right away can be normal.',
    'CNAME kaydını nereye ekleyeceğimi bulamıyorum': 'I can\'t find where to add the CNAME record',
    'Domain bağlama ekranındaki "Domainin nereden alındı? Adım adım göster" bölümünü aç — Natro, İsimtescil, Turhost, GoDaddy ve Namecheap için ayrı ayrı adımlar ve o firmanın resmi yardım sayfasına giden bir link var.':
        'Open the "Where did you buy your domain? Show me step by step" section on the domain connect screen — it has separate steps for Natro, İsimtescil, Turhost, GoDaddy and Namecheap, plus a link to that provider\'s official help page.',
    '"MySitora ile üretildi" rozeti neden geri geldi?': 'Why did the "Made with MySitora" badge come back?',
    'Rozeti domain veya mini paket satın alarak kaldırdıysan, bu kaldırma o satın almanın SÜRESİNE bağlıdır — süre dolup yenilenmezse rozet otomatik geri gelir. Rozeti AYRICA/kalıcı olarak satın aldıysan bu durum seni etkilemez, kalıcı kaldırma asla geri gelmez.':
        'If you removed the badge by purchasing a domain or mini package, that removal is tied to that purchase\'s DURATION — if it expires without renewal, the badge comes back automatically. If you purchased permanent badge removal SEPARATELY, this doesn\'t affect you — a permanent removal never comes back.',
    'Domain/mini paket süresi dolunca ne oluyor?': 'What happens when the domain/mini package expires?',
    'Süre dolduğunda site otomatik olarak ücretsiz katmana iner: fazla sayfalar kaldırılır, harita/talep formu gibi premium özellikler kapanır ve rozet geri gelir. Bunun için uygulamayı açmana gerek yok, sunucu tarafında günlük olarak otomatik kontrol edilir.':
        'When it expires, the site automatically drops to the free tier: extra pages are removed, premium features like the map/lead form turn off, and the badge comes back. You don\'t need to open the app for this — it\'s checked automatically on the server every day.',
    'Satın alma yaptım ama özellik açılmadı': 'I made a purchase but the feature didn\'t unlock',
    'Önce Play Store\'daki satın alma geçmişinden ödemenin gerçekten tamamlandığını kontrol et. Tamamlandıysa uygulamayı tamamen kapatıp yeniden aç — bazen satın alma onayı birkaç dakika gecikebilir.':
        'First check your Play Store purchase history to confirm the payment actually went through. If it did, fully close and reopen the app — purchase confirmation can sometimes lag by a few minutes.',
    'Domainimi yanlış girdim, düzeltebilir miyim?': 'I entered my domain wrong, can I fix it?',
    'Domain bağlama tek seferlik bir satın almadır ve bir domaine bağlanır. Yanlış girdiysen destek ile iletişime geçmen gerekir, kendi başına değiştiremezsin.':
        'Domain connection is a one-time purchase tied to one domain. If you entered it wrong, you\'ll need to contact support — you can\'t change it yourself.',
    'Domain/mini paket otomatik yenileniyor mu, tekrar ücret keser mi?': 'Does the domain/mini package auto-renew or charge me again?',
    'Hayır. İkisi de tek seferlik satın almadır, otomatik yenilenen bir abonelik DEĞİLDİR. Süre dolduğunda kendiliğinden yenilenmez ve tekrar ücret kesmez — uzatmak istersen tekrar senin satın alman gerekir.':
        'No. Both are one-time purchases, NOT an auto-renewing subscription. When they expire they don\'t renew or charge you again by themselves — to extend, you need to purchase again.',
    'Yayınladığım site kaç dilde olabilir?': 'What language can my published site be in?',
    'Siteyi yayınladığın anda o anki uygulama dilinde (Türkçe veya İngilizce) yayınlanır. Dili değiştirip tekrar yayınlarsan yeni dilde güncellenir.':
        'The site publishes in whatever language the app is set to at that moment (Turkish or English). If you change the language and republish, it updates to the new language.',
    'Kayıt yayılınca (genelde birkaç dakika içinde, bazı sağlayıcılarda 24 saate kadar sürebilir) bu sayfa otomatik güncellenir, bir şey yapmana gerek yok. Uygulamayı kapatıp daha sonra tekrar açabilirsin.':
        'Once the record propagates (usually within a few minutes, though some providers can take up to 24 hours) this page updates automatically — you don\'t need to do anything. You can close the app and come back later.',

    // === "1 Aylık Mini Paket" (05.09.2026) ===
    '1 Aylık Mini Paket': '1-Month Mini Package',
    'Mini paket aktif!': 'Mini package active!',

    // === Kılavuz — 6. Premium Özellikler (05.09.2026, kanka isteği) ===
    '6. Premium Özellikler (Domain / Mini Paket)':
        '6. Premium Features (Domain / Mini Package)',
    'Mağaza\'dan \'Kendi Domain Bağla\' (1 yıllık) ya da \'1 Aylık Mini Paket\' satın alarak rozeti kaldırabilir; Talep Kutusu, tam galeri, harita, talep formu, Google yorum butonu ve ziyaretçi sayısını açabilirsiniz. Açılan bu özellikleri kullanmak için ilgili siteyi Projelerim ekranından \'DÜZENLE\' butonuyla açıp formu güncellemeniz gerekir.':
        'From the Store you can buy "Connect My Own Domain" (1 year) or the "1-Month Mini Package" to remove the badge and unlock the lead inbox, full gallery, map, lead form, Google review button, and visitor stats. To use these unlocked features, open the relevant site from My Projects and tap "EDIT" to update the form.',
    // === Şablon Ön İzleme (27.08.2026) ===
    'Şablonu önizle': 'Preview template',
    'Bu, örnek verilerle oluşturulmuş bir gösterimdir. Aşağıdan tema ve tipografiyi değiştirip nasıl göründüğünü deneyebilirsin.':
        'This is a demo built with sample data. You can change the theme and typography below to see how it looks.',
    'Bu, örnek verilerle oluşturulmuş bir gösterimdir. Aşağıdan temayı değiştirip nasıl göründüğünü deneyebilirsin.':
        'This is a demo built with sample data. You can change the theme below to see how it looks.',
    'Bu şablonla oluştur': 'Create with this template',
    // === Ücretli İndirme (28.08.2026, fiyat/akış revizyonu 28.08.2026) ===
    'Siteni İndir': 'Download Your Site',
    'Watermarklı İndir': 'Download with badge',
    'Watermarksız İndir': 'Download without badge',
    '"MySitora ile üretildi" rozeti sitede görünür kalır.': 'The "Made with MySitora" badge stays visible on the site.',
    'Rozet tamamen kaldırılır + indirme hakkı verilir — bu site ileride yayınlanırsa o da rozetsiz olur.':
        'The badge is fully removed and download rights are granted — if you publish this site later, that will be badge-free too.',
    'Rozet zaten kaldırılmıştı — dosya rozetsiz iner.': 'The badge was already removed — the file downloads badge-free.',
    'Anaokulu / Kreş Sitesi': 'Kindergarten / Nursery Site',
    'Butik Otel / Pansiyon Sitesi': 'Boutique Hotel / Guesthouse Site',
    'Elektrikçi Sitesi': 'Electrician Site',
    'Fırın / Pastane Sitesi': 'Bakery / Pastry Shop Site',
    'Masaj / Spa Sitesi': 'Massage / Spa Site',
    'Mobilyacı / Dekorasyon Sitesi': 'Furniture / Decor Store Site',
    'Oto Tamirci / Lastikçi Sitesi': 'Auto Repair / Tire Shop Site',
    'Pet Kuaförü Sitesi': 'Pet Grooming Site',
    'Restoran / Lokanta Sitesi': 'Restaurant Site',
    'Tadilatçı Sitesi': 'Handyman Site',
    'Veteriner Sitesi': 'Veterinarian Site',
    'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan diyetisyen sitesi.': 'Dietitian site generated as separate Home + Services + Booking pages.',
    'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan diş hekimi sitesi.': 'Dentist site generated as separate Home + Services + Booking pages.',
    'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan hukuk bürosu sitesi.': 'Law firm site generated as separate Home + Services + Booking pages.',
    'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan kişisel antrenör sitesi.': 'Personal trainer site generated as separate Home + Services + Booking pages.',
    'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan veteriner sitesi.': 'Veterinarian site generated as separate Home + Services + Booking pages.',
    'Ana Sayfa + iş örnekleri ayrı sayfalar olarak oluşturulan fotoğrafçı sitesi.': 'Photographer site generated as separate Home + portfolio pages.',
    'Ana Sayfa + iş örnekleri ayrı sayfalar olarak oluşturulan makyaj sanatçısı sitesi.': 'Makeup artist site generated as separate Home + portfolio pages.',
    'Ana Sayfa + iş örnekleri ayrı sayfalar olarak oluşturulan müzisyen/DJ sitesi.': 'Musician/DJ site generated as separate Home + portfolio pages.',
    'Bakım/onarım hizmetleri, galeri ve randevu bilgileriyle oto tamirci/lastikçi sitesi.': 'Auto repair/tire shop site with maintenance/repair services, gallery, and booking info.',
    'Branşlar, hekimler ve randevu bilgileriyle veteriner kliniği sitesi.': 'Veterinary clinic site with specialties, doctors, and booking info.',
    'Ehliyet sınıfları, eğitmenler ve kayıt bilgileriyle sürücü kursu sitesi.': 'Driving school site with license classes, instructors, and enrollment info.',
    'Galeri, hizmet paketleri ve randevu bilgileriyle makyaj sanatçısı sitesi.': 'Makeup artist site with gallery, service packages, and booking info.',
    'Galeri, performans/etkinlik bilgileri ve iletişimle müzisyen/DJ sitesi.': 'Musician/DJ site with gallery, performance/event info, and contact details.',
    'Galeri, çekim paketleri ve iletişimle fotoğrafçı portfolyo sitesi.': 'Photographer portfolio site with gallery, shoot packages, and contact info.',
    'Herhangi bir işletme için hizmetler, hakkında ve iletişim bilgileriyle genel amaçlı tanıtım sitesi.': 'General-purpose site for any business, with services, about, and contact info.',
    'Hizmet bölgeleri, araç filosu ve teklif alma bilgileriyle nakliyat sitesi.': 'Moving company site with service areas, fleet, and quote request info.',
    'Hizmet paketleri ve randevu bilgileriyle masaj/spa merkezi sitesi.': 'Massage/spa center site with service packages and booking info.',
    'Hizmet paketleri, bölgeler ve teklif alma bilgileriyle temizlik şirketi sitesi.': 'Cleaning company site with service packages, areas served, and quote request info.',
    'Hizmet paketleri, galeri ve randevu bilgileriyle pet kuaförü sitesi.': 'Pet grooming site with service packages, gallery, and booking info.',
    'Hizmetler, galeri ve hızlı iletişim bilgileriyle elektrikçi/tesisatçı sitesi.': 'Electrician/plumber site with services, gallery, and quick contact info.',
    'Hizmetler, ölçü/randevu ve iletişim bilgileriyle terzi tanıtım sitesi.': 'Tailor site with services, fitting/appointment info, and contact details.',
    'Menü, galeri ve rezervasyon bilgileriyle tam hizmet restoran sitesi.': 'Full-service restaurant site with menu, gallery, and reservation info.',
    'Oda tipleri, galeri ve rezervasyon bilgileriyle butik otel/pansiyon sitesi.': 'Boutique hotel/guesthouse site with room types, gallery, and reservation info.',
    'Programlar, başarı hikayeleri ve randevu bilgileriyle kişisel antrenör sitesi.': 'Personal trainer site with programs, success stories, and booking info.',
    'Programlar, danışmanlık ve randevu bilgileriyle diyetisyen sitesi.': 'Dietitian site with programs, consultation info, and booking details.',
    'Programlar, galeri ve kayıt bilgileriyle anaokulu/kreş sitesi.': 'Kindergarten/nursery site with programs, gallery, and enrollment info.',
    'Tedaviler, hekimler ve randevu bilgileriyle diş hekimi/klinik sitesi.': 'Dental clinic site with treatments, doctors, and booking info.',
    'Uzmanlık alanları, ekip ve iletişim bilgileriyle hukuk bürosu sitesi.': 'Law firm site with practice areas, team, and contact info.',
    'Öncesi/sonrası galerisi ve teklif alma bilgileriyle tadilat/tamirat sitesi.': 'Handyman/renovation site with before/after gallery and quote request info.',
    'Ürün galerisi, teslimat ve sipariş bilgileriyle çiçekçi sitesi.': 'Florist site with product gallery, delivery, and ordering info.',
    'Ürün kategorileri, galeri ve sipariş bilgileriyle fırın/pastane sitesi.': 'Bakery/pastry shop site with product categories, gallery, and ordering info.',
    'Ürün kategorileri, galeri ve teklif alma bilgileriyle mobilyacı/dekorasyon sitesi.': 'Furniture/decor store site with product categories, gallery, and quote request info.',
    'Dijital/QR ürün listesi linki (opsiyonel)': 'Digital/QR product list link (optional)',
    'Oda Tipleri (her satıra bir tane: Ad - Kapasite - Gecelik Fiyat)': 'Room Types (one per line: Name - Capacity - Nightly Rate)',
    'Programlar (her satıra bir tane: Ad - Yaş Grubu - Ücret)': 'Programs (one per line: Name - Age Group - Fee)',
    'Ürün Kategorileri (her satıra bir tane: Ad - Açıklama - Fiyat Aralığı)': 'Product Categories (one per line: Name - Description - Price Range)',
    'Ürünler (kategoriler arasına boş satır bırak)': 'Products (leave a blank line between categories)',
    'Başlangıçlar\nMercimek Çorbası - - 90 TL\nÇoban Salata - - 110 TL\n\nAna Yemekler\nIzgara Köfte - - 280 TL': 'Starters\nLentil Soup - - 90 TL\nShepherd Salad - - 110 TL\n\nMain Courses\nGrilled Meatballs - - 280 TL',
    'Ekmekler\nEkşi Mayalı Somun - 900g - 90 TL\nTam Buğday - 700g - 70 TL\n\nPastalar\nÇikolatalı Pasta - 8 Dilim - 350 TL': 'Breads\nSourdough Loaf - 900g - 90 TL\nWhole Wheat - 700g - 70 TL\n\nCakes\nChocolate Cake - 8 Slices - 350 TL',
    'Lastik Değişimi - 20 dk - 300 TL\nRot Balans - 45 dk - 500 TL': 'Tire Change - 20 min - 300 TL\nWheel Alignment - 45 min - 500 TL',
    'Priz/Sigorta Arızası - 1 saat - 400 TL\nTesisat Yenileme - - Teklif üzerine': 'Outlet/Fuse Fault - 1 hour - 400 TL\nWiring Renewal - - Quote on request',
    'Standart Oda - 2 Kişilik - 1500 TL\nSuit Oda - 4 Kişilik - 3000 TL': 'Standard Room - 2 Guests - 1500 TL\nSuite - 4 Guests - 3000 TL',
    'Tam Gün Bakım - 3-6 Yaş - 8500 TL/ay\nYarım Gün Bakım - 2-4 Yaş - 5500 TL/ay': 'Full-Day Care - Ages 3-6 - 8500 TL/mo\nHalf-Day Care - Ages 2-4 - 5500 TL/mo',
    'Oturma Grubu - Modern Tasarım - 15000 TL\'den başlayan\nYatak Odası Takımı - Ahşap - 25000 TL\'den başlayan': 'Sofa Set - Modern Design - starting from 15000 TL\nBedroom Set - Wood - starting from 25000 TL',
    'Geri alınacak bir değişiklik yok.': 'No change to undo.',
    'İleri alınacak bir değişiklik yok.': 'No change to redo.',
    'Canvas zaten boş.': 'Canvas is already empty.',
    'Tasarım silindi.': 'Design deleted.',
    'Canvas boş — önce bir şablon seçiniz ya da eleman ekleyiniz.': 'Canvas is empty — pick a template or add an element first.',
    'Projelerim\'e kaydedildi! 📁': 'Saved to My Projects! 📁',
    'HTML dosyası cihaza kaydedildi ve Projelerim\'e eklendi! 💾': 'HTML file saved to device and added to My Projects! 💾',
    'Projelerim\'e kaydedildi (dosya indirilmedi).': 'Saved to My Projects (file not downloaded).',
    'Tasarımı Sil': 'Delete Design',
    'Canvas üzerindeki tüm elemanlar silinecek. Bu işlem geri alınamaz. Silmek istediğinizden emin misiniz?': 'All elements on the canvas will be deleted. This cannot be undone. Are you sure you want to delete?',
    'kalıcı olarak silinecek. Bu işlem geri alınamaz. Silmek istediğinizden emin misiniz?': 'will be permanently deleted. This cannot be undone. Are you sure you want to delete?',
    'Vazgeç': 'Cancel',
    // === Giriş (login gate) — bkz. widgets/login_gate.dart ===
    'için giriş gerekiyor': 'requires sign-in',
    'Bu özellik hesabına bağlı çalışır. Devam etmek için e-posta ile giriş yapman gerekiyor.':
        'This feature is tied to your account. To continue, sign in with your email.',
    'Şifre': 'Password',
    'E-posta gerekli.': 'Email is required.',
    'Geçerli bir e-posta gir.': 'Enter a valid email.',
    'Şifre gerekli.': 'Password is required.',
    'Şifre en az 6 karakter olmalı.': 'Password must be at least 6 characters.',
    'Şifremi Unuttum': 'Forgot Password',
    'Önce e-posta adresini yaz.': 'Enter your email address first.',
    'Şifre sıfırlama bağlantısı e-postana gönderildi.':
        'A password reset link has been sent to your email.',
    'Kayıt Ol': 'Sign Up',
    'Hesabın yok mu? Kayıt Ol': "Don't have an account? Sign Up",
    'Zaten hesabın var mı? Giriş Yap': 'Already have an account? Sign In',
    // === Satın alma (billing) — bkz. billing_constants.dart ===
    'Satın Al': 'Buy',
    'Fiyat alınamadı': 'Price unavailable',
    'Ücretsiz yayın hakkın doldu': "You've used your free publish",
    'Ek Sayfalar': 'Extra Pages',
    'Genel İşletme Sitesi': 'General Business Site',
    'Sektörünü yaz... (ör. kuaför, restoran)': 'Type your sector... (e.g. hairdresser, restaurant)',
    'için tam eşleşme yok, sana en uygun genel şablonu önerdik:':
        'has no exact match, so we suggested the closest general template:',
    'Kurşun Kalem - 15 TL\nDefter - 40 TL': 'Pencil - 15 TL\nNotebook - 40 TL',
    'Paragrafları boş satırla ayırabilirsin.': 'You can separate paragraphs with a blank line.',
    'Sayfa Ekle': 'Add Page',
    'Sayfa başlığı (örn. Hakkımızda)': 'Page title (e.g. About Us)',
    'Sayfa başlığı gerekli.': 'Page title is required.',
    'Sektörüne özel bir şablon bulamadıysan (kırtasiye, bakkal, kuyumcu, optik, züccaciye vb.) bu genel şablonu kullanabilirsin.':
        "If you couldn't find a template for your sector (stationery, grocery store, jeweler, optician, hardware store, etc.) you can use this general template.",
    'Sektörüne özel bir şablon yoksa: hem tek hem çok sayfa, tema ve dil seçenekli genel işletme sitesi.':
        'No template for your sector? A general business site with single- or multi-page, theme, and language options.',
    'Site Yapısı': 'Site Structure',
    'Site İçeriği Dili': 'Site Content Language',
    'Sitenin ziyaretçiye görüneceği dil. Bu uygulamanın kendi arayüz dilinden bağımsızdır.':
        "The language visitors will see on the site. This is independent of the app's own interface language.",
    'Tüm içerik tek bir sayfada, kaydırarak gezilir.': 'All content is on a single page, browsed by scrolling.',
    'yükleniyor…': 'loading…',
    'ziyaretçi': 'visitor',
    'Yayında olan siteler': 'Live sites',
    'toplam': 'total',
    'bugün': 'today',
    'kişi bu ay ulaştı': 'reached you this month',
    'Çok sayfa modunda en az 1 ek sayfa eklemelisin.': 'In multi-page mode you must add at least 1 extra page.',
    'Ürün/Hizmetler (her satıra bir tane: Ad - Fiyat)': 'Products/Services (one per line: Name - Price)',
    'İstatistik alınamadı': 'Could not load stats',
    'İstediğin kadar ek sayfa (Hakkımızda, Kurumsal, SSS vb.) ekleyebilirsin, hepsi ortak bir menüyle bağlanır.':
        'You can add as many extra pages as you like (About Us, Corporate, FAQ, etc.), all linked by a shared menu.',
    'İçerik': 'Content',
    '↻ Yenile': '↻ Refresh',
    'Ana Sayfa + Hizmetler + Randevu ayrı sayfalar olarak oluşturulan klinik sitesi.':
        'Clinic site generated as separate Home + Services + Appointment pages.',
    'Ana Sayfa + Menü + Galeri ayrı sayfalar olarak oluşturulan kafe/restoran sitesi.':
        'Cafe/restaurant site generated as separate Home + Menu + Gallery pages.',
    'Ana Sayfa + her iş örneği kendi detay sayfasında oluşturulan portfolyo sitesi.':
        'Portfolio site generated as a Home page plus a dedicated detail page for each work sample.',
    'Ana Sayfa, Hizmetler ve Randevu ayrı sayfalar olarak oluşturulur.':
        'Home, Services and Appointment are generated as separate pages.',
    'Her iş örneği kendi sayfasında (Ana Sayfa + iş detay sayfaları) oluşturulur.':
        'Each work sample gets its own page (Home + work detail pages).',
    'Tamam': 'OK',
    'Evet, Sil': 'Yes, Delete',
    'Kaydet': 'Save',
    'Bu modda henüz şablon yok.': 'No template available in this mode yet.',
    'Devam Et': 'Continue',
    // === Rozet kaldırma (site bazlı, tek seferlik) ===
    'Rozeti Kaldır': 'Remove Badge',
    'Sitora rozetini kaldır': 'Remove Sitora badge',
    'Rozet kaldırıldı!': 'Badge removed!',
    'Satın Al — Bu Site İçin': 'Buy — For This Site',
    'İşleniyor...': 'Processing...',
    'Kapat': 'Close',
    'Gelen Kutusu': 'Inbox',
    'Gelen Talepler': 'Requests',
    'Izgara': 'Grid',
    'Kalın': 'Bold',
    'Normal': 'Normal',
    'Rezervasyon Yap': 'Make a Reservation',
    'Hesap': 'Account',
    'Misafir modundasın': 'You are in guest mode',
    'Giriş yapıldı': 'Signed in',
    'Giriş Yap': 'Sign In',
    'Çıkış Yap': 'Sign Out',
    'Sil': 'Delete',

    // === İşletmeyi Öner (viral paylaşım) ===
    'İşletmeyi Öner': 'Recommend This Business',

    // === Yayından Kaldır / Domain Bağla kart butonları (2026-09-02) ===
    'Yayından Kaldır': 'Unpublish',
    'yayından kaldırılacak, site adresi artık açılmayacak. Proje silinmez, istediğinde tekrar yayınlayabilirsin.':
        'will be unpublished, its address will no longer work. The project itself is not deleted — you can republish it anytime.',
    'Evet, Kaldır': 'Yes, Unpublish',
    'Yayından kaldırıldı.': 'Unpublished.',
    'Bu proje şu anda YAYINDA — silince canlı sitesi de kaldırılacak.':
        'This project is currently LIVE — deleting it will also take the live site down.',
    'Domain Bağlı': 'Domain Connected',
    'Domain Bağla': 'Connect Domain',
    'Kendi domainini bağlama özelliği şu anda aktif değil. Çok yakında burada kendi alan adını (örn. isletmem.com) bağlayabileceksin.':
        'Connecting your own domain isn\'t active yet. Very soon you\'ll be able to connect your own domain (e.g. mybusiness.com) right here.',

    // === Kendi Domainimi Bağla ===
    'Kendi Domainimi Bağla': 'Connect My Own Domain',
    'Kendi domainini bu siteye bağla': 'Connect your own domain to this site',
    'Örn: ahmetkuafor.com — domain sağlayıcının panelinde bir CNAME kaydı ekleyeceksin, başka bir şey gerekmiyor.':
        'e.g. ahmetkuafor.com — you\'ll add one CNAME record in your domain provider\'s panel, nothing else is needed.',
    'Bağlanıyor…': 'Connecting…',
    'Bağla': 'Connect',
    'Domain sağlayıcının panelinde şu CNAME kaydını ekle:':
        'Add this CNAME record in your domain provider\'s panel:',
    'Ad (Name/Host)': 'Name/Host',
    'Hedef (Value/Target)': 'Value/Target',
    'SSL doğrulaması için ek kayıt:': 'Additional record for SSL validation:',
    'Kopyala': 'Copy',
    'Kopyalandı ✅': 'Copied ✅',
    '✅ Bağlandı': '✅ Connected',
    '⚠️ Doğrulama başarısız': '⚠️ Validation failed',
    '⏳ DNS kaydı bekleniyor…': '⏳ Waiting for DNS record…',
    'Kaldırılıyor…': 'Removing…',
    'Uzatılıyor…': 'Extending…',
    'Domaini Kaldır': 'Remove Domain',
    'Bu özellik şu an aktif değil.': 'This feature isn\'t active right now.',
    'Siten şu anda kendi ücretsiz alt alan adından yayında kalmaya devam ediyor.':
        'Your site stays live on its free subdomain in the meantime.',
    'Bağlantıyı 1 Yıl Uzat': 'Extend Connection 1 Year',
    'Domain bağlantın 1 yıl daha uzatıldı ✅': 'Your domain connection has been extended by 1 year ✅',
    // 05.09.2026 eklendi — kProductConnectDomain satın alma akışı.
    '1 yıllık, tek seferlik satın alma + 1 ek site yayın hakkı': 'One-time purchase, valid 1 year + 1 extra site publish right',
    'Kendi domainimi bağla': 'Connect my own domain',

    // === Yayınla ===
    'Yayınla': 'Publish',
    'Yayınlama': 'Publishing',
    'Siteyi Yayınla': 'Publish Site',
    'Sitenin ücretsiz bir alt alan adında yayına alınacak. İstediğin adı yazabilirsin, dolu ise Sitora otomatik benzersizleştirir.':
        'Your site will go live on a free subdomain. Pick any name — if it\'s taken, Sitora will make it unique automatically.',
    'Yayınlanıyor…': 'Publishing…',
    'Siten yayında! ✅': 'Your site is live! ✅',
    'Siteyi Aç': 'Open Site',
    'Önce bir site oluşturmanız gerekiyor.': 'You need to create a site first.',
    'Proje bulunamadı, lütfen tekrar deneyin.': 'Project not found, please try again.',
    'Düzenle': 'Edit',
    'DÜZENLE': 'EDIT',
    'İndir': 'Download',
    'İNDİR': 'DOWNLOAD',
    'Paylaş': 'Share',
    'Yükleniyor...': 'Loading...',
    'Hata': 'Error',
    'Başarılı': 'Success',
    'Ekle': 'Add',
    'Ayarla': 'Set',
    'Temizle': 'Clear',
    'Çizimi Ekle': 'Add Drawing',
    'Özel': 'Custom',
    'Özel Renk': 'Custom Color',

    // === Ana Ekran (home_screen.dart) ===
    'Kılavuz': 'Guide',
    'Çok Sayfa': 'Multi-Page',
    'Tek Sayfa': 'Single Page',
    'Puan Ver': 'Rate Us',
    'Ücretsiz Plan': 'Free Plan',
    'Önce formu doldurup bir site oluşturmanız gerekiyor.':
        'You need to fill in the form and generate a site first.',
    'ZIP dosyası cihaza kaydedildi! 📦': 'ZIP file saved to your device! 📦',
    'HTML dosyası cihaza kaydedildi! 💾': 'HTML file saved to your device! 💾',

    // === Ayarlar (settings_sheet.dart) ===
    'Ayarlar': 'Settings',
    'Galeri': 'Gallery',
    'Gizlilik Politikası': 'Privacy Policy',
    'Kullanım Şartları': 'Terms of Service',

    // === Açılış Onay Popup'ı (legal_consent_popup.dart) ===
    'Devam Etmeden Önce': 'Before You Continue',
    'Sitora\'yı kullanmaya devam etmeden önce lütfen Gizlilik Politikası ve Kullanım Şartları\'nı okuyup onaylayın.':
        'Please read and accept the Privacy Policy and Terms of Service before continuing to use Sitora.',
    'Okudum, kabul ediyorum: ': 'I have read and accept the ',
    ' ve ': ' and ',
    'Kabul Ediyorum ve Devam Et': 'I Accept and Continue',

    // === Splash Ekranı (splash_screen.dart) ===
    'WEB SİTESİ OLUŞTURUCU': 'WEB SITE BUILDER',

    // === Kullanım Kılavuzu (guide_dialog.dart) ===
    'Sitora Kullanım Kılavuzu': 'Sitora User Guide',
    // 18.09.2026 eklendi (kanka isteği) — kılavuzun en üstündeki 6 aylık
    // ücretsiz yayın uyarı bandı (bkz. _GuideWarningBanner).
    'Ücretsiz planda yayınlanan siteler 6 ay boyunca güncellenmezse '
        '(tekrar yayınlanmazsa) otomatik olarak yayından kaldırılır. '
        'Sitenizin yayında kalması için süresi dolmadan Projelerim '
        'kısmından siteyi açıp tekrar yayınlayın.':
        'Sites published on the free plan are automatically unpublished if '
        'they go 6 months without being updated (republished). To keep '
        'your site live, open it from My Projects and republish it before '
        'the time runs out.',
    '1. Form ile Site Oluştur': '1. Create a Site via Form',
    'Formu doldurup \'Oluştur\'a bastığınızda siteniz anında üretilir — '
        'istediğiniz kadar deneyip beğendiğiniz sonuca ulaşana kadar '
        'tekrar tekrar oluşturabilirsiniz.':
        'Fill out the form and tap \'Create\' — your site is generated '
            'instantly. You can try as many times as you like until '
            'you\'re happy with the result.',
    '2. Önizleme': '2. Preview',
    'Form gönderildiğinde siteniz otomatik olarak önizleme ekranında '
        'açılır; burada nasıl görüneceğini anında test edebilirsiniz.':
        'When you submit the form, your site automatically opens in the '
            'preview screen so you can instantly see how it looks.',

    '3. Yayınlama': '3. Publishing',
    'Önizleme ekranındaki \'YAYINLA\' butonuyla siteniz kendi alt alan '
        'adınızda (veya bağladığınız domainde) canlıya alınır.':
        'The \'PUBLISH\' button on the preview screen makes your site live '
            'on your subdomain (or your connected domain).',

    '4. Düzenleme': '4. Editing',
    'Önizleme ekranındaki \'DÜZENLE\' butonuyla formunuz, daha önce '
        'girdiğiniz bilgilerle DOLU şekilde tekrar açılır. Değişikliklerinizi '
        'yapıp \'DÜZENLEMEYİ BİTİR\'e bastığınızda site güncellenir ve '
        'önizlemeye dönersiniz.':
        'The \'EDIT\' button on the preview screen reopens your form '
            'already FILLED with what you entered before. Make your '
            'changes and tap \'FINISH EDITING\' — your site updates and '
            'you\'re taken back to the preview.',

    '5. İndirme & Kaydetme': '5. Download & Save',
    '\'İNDİR\' butonuna bastığınızda, site rozetliyse önce rozet '
        'kaldırma + indirme hakkını birlikte veren bir satın alma '
        'sunulur; rozet zaten kalkmışsa doğrudan indirme satın alınır. '
        'Satın alındıktan sonra o proje sınırsız tekrar indirilebilir; '
        'cihazınızın kayıt penceresinden dosya adını ve konumu siz '
        'seçersiniz.':
        'Tapping \'DOWNLOAD\': if the site still has the badge, you\'re '
            'offered a purchase that removes the badge and grants '
            'download together; if the badge is already removed, only '
            'the download is purchased. Once purchased, that project can '
            'be downloaded again unlimited times; you choose the file '
            'name and location from your device\'s save dialog.',

    '6. Abonelik Paketleri': '6. Subscription Plans',
    'Mağaza > Abonelik Planları\'ndan Mini/Freelancer/Freelancer Max '
        'paketlerinden birine abone olarak kota dahilindeki sitelerinizde '
        'rozeti kaldırabilir, Talep Kutusu, tam galeri, harita, talep '
        'formu, Google yorum butonu + Google İşletme Profili Kurulum '
        'Sihirbazı ve ziyaretçi sayısını açabilirsiniz; bunlar sadece '
        'ücretsiz planda kilitlidir. '
        'Her paketin kaç site ve kaç özel domain kotası verdiği paket '
        'kartında yazar. İndirme bu paketlerin dışındadır — hangi '
        'pakete/aboneliğe sahip olunursa olsun her zaman site başına '
        'ayrı satılan bir kilittir (bkz. adım 5).':
        'From Store > Subscription Plans, subscribe to Mini, Freelancer, '
            'or Freelancer Max to remove the badge and unlock the lead '
            'inbox, full gallery, map, lead form, Google review button + '
            'Google Business Profile Setup Wizard, and visitor stats on '
            'the sites within your quota; these are locked only on the '
            'free plan. Each '
            'plan\'s site and custom-domain quota is shown on its card. '
            'Downloads are separate from these plans — regardless of '
            'plan or subscription, downloading is always a per-site '
            'purchase (see step 5).',

    '7. Kendi Domainimi Bağla': '7. Connect My Own Domain',
    'Zaten sahip olduğunuz bir alan adını (domain) Projelerim\'deki 🌐 '
        'ikonuyla sitenize bağlayabilirsiniz — bu, domain satın almak '
        'DEĞİL, elinizdeki domaini hosting\'imize yönlendirmektir. '
        'Abonelik kotanız varsa dahildir, yoksa site başına 1 yıllık '
        'ayrı satın alınır; süre dolunca uzatmak yeniden satın alma '
        'gerektirir. Bu satın alma hesabınıza ayrıca +1 ek site yayın hakkı ekler. '
        'Domain paketi de aynı premium özellikleri açar (Google İşletme Profili '
        'Kurulum Sihirbazı dahil).':
        'You can connect a domain you already own to your site using the '
            '🌐 icon in My Projects — this is NOT buying a domain, it\'s '
            'pointing the domain you have at our hosting. It\'s included '
            'if you have subscription quota available; otherwise it\'s a '
            'separate 1-year purchase per site, and extending it after it '
            'expires requires purchasing again. This purchase also adds +1 '
            'extra site publish right to your account. A domain package '
            'unlocks the same premium features (including the Google '
            'Business Profile Setup Wizard).',

    '8. Proje Kopyalama': '8. Duplicating a Project',
    'Bir siteyi Projelerim\'den kopyalayarak aynı içerikle sıfırdan '
        'yeni, yayınlanmamış bir proje oluşturabilirsiniz — yayın, '
        'domain ve satın alma durumları kopyaya taşınmaz. Aynı şablonu '
        'farklı müşterileriniz için tekrar tekrar kullanmak isteyenler '
        '(ör. freelancer\'lar) için pratiktir.':
        'You can duplicate a site from My Projects to create a fresh, '
            'unpublished project with the same content — publish state, '
            'domain, and purchases are not carried over. Handy if you '
            'want to reuse the same template for different clients (e.g. '
            'freelancers).',

    '9. Siteyi Devretme': '9. Transferring a Site',
    'Bir siteyi (bağlıysa domaini dahil) \'Siteyi Devret\'le başka bir '
        'hesaba aktarabilirsiniz — sistem bir kod üretir, karşı taraf bu '
        'kodu kendi hesabında girerek siteyi devralır. Bir siteyi '
        'müşteriniz için kurup işi bitince kendi hesabına teslim etmek '
        'isteyenler için düşünülmüştür.':
        'You can transfer a site (including its connected domain, if '
            'any) to another account with \'Transfer Site\' — the system '
            'generates a code, and the other party enters it on their '
            'own account to take ownership. Designed for handing a '
            'finished site over to your client\'s own account.',

    '10. Talep Kutusu & Bildirimler': '10. Lead Inbox & Notifications',

    '11. Google İşletme Profili Sihirbazı': '11. Google Business Profile Wizard',
    'Abonelik veya özel domain paketi olan sitelerde (ücretsiz planda '
        'kilitli) formdaki "Google Yorum Linki" alanının altında bir '
        'sihirbaz açılır. Sihirbaz Google işletme profilini senin yerine '
        'AÇMAZ — profili Google, senin hesabınla açar. Sihirbaz forma '
        'girdiğin bilgilerden kopyalamaya hazır bir kart hazırlar, seni '
        'Google\'ın ücretsiz kayıt ekranına yönlendirir ve profilin yorum '
        'linkini sitendeki "Bizi Google\'da Değerlendirin" butonuna bağlar.':
        'On sites with a subscription or a custom-domain package (locked on '
            'the free plan), a wizard appears under the "Google Review Link" '
            'field in the form. The wizard does NOT create your Google '
            'Business Profile for you — Google does, with your account. It '
            'prepares a copy-ready card from the details you entered in the '
            'form, sends you to Google\'s free sign-up screen, and connects '
            'your profile\'s review link to the "Rate us on Google" button '
            'on your site.',

    // 20.09.2026 eklendi (kanka isteği) — bkz. guide_dialog.dart adım 12/13.
    '12. Siten Google\'ın Bulabileceği Şekilde Hazır (Ücretsiz)':
        '12. Your Site Is Ready for Google to Find (Free)',
    'Ücretsiz plan dahil, yayınladığın HER site otomatik olarak bir '
        'sitemap.xml ve robots.txt ile gelir — bunlar Google\'a "sitem bu '
        'sayfalardan oluşuyor, tara" diyen teknik dosyalardır ve hiçbir şey '
        'yapmana gerek kalmadan kendiliğinden çalışır. Sayfa ekleyip '
        'yeniden yayınladığında da otomatik güncel kalır.':
        'Including the free plan, EVERY site you publish automatically '
            'comes with a sitemap.xml and robots.txt — technical files '
            'that tell Google "my site is made of these pages, go crawl '
            'them", working on their own with nothing for you to set up. '
            'They also stay automatically up to date whenever you add a '
            'page and republish.',

    '13. Google Search Console\'a Bağlan': '13. Connect to Google Search Console',
    'Abonelik veya özel domain paketi olan sitelerde (ücretsiz planda '
        'kilitli), Google\'ın verdiği doğrulama kodunu girerek sitenin '
        'gerçek sahibi olduğunu Google\'a kanıtlayabilirsin. Bu, sitenin '
        'Google\'da ÇIKMASI için şart değildir (sitemap zaten yeterli) — '
        'ama Google Search Console panelinden sitenin hangi aramalarda '
        'göründüğünü izlemene ve yeni sayfaların çok daha hızlı '
        'taranmasını Google\'dan doğrudan istemene imkân tanır. Kod '
        'kaydedildiğinde siteyi yeniden yayınlaman gerekmez, birkaç '
        'dakika içinde otomatik olarak devreye girer. Nasıl yapılır: '
        'Projelerim\'de yayındaki sitenin kartında "Search Console" '
        'butonuna bas, Google\'ın verdiği kodu yapıştırıp kaydet.':
        'On sites with a subscription or a custom-domain package (locked '
            'on the free plan), you can enter the verification code Google '
            'gives you into the form to prove to Google that you own the '
            'site. This is not required for your site to appear in Google '
            '(the sitemap already takes care of that) — but it lets you '
            'track which searches your site shows up in from the Google '
            'Search Console dashboard, and ask Google directly to crawl '
            'new pages much faster. Once the code is saved you don\'t need '
            'to republish the site — it kicks in automatically within a '
            'few minutes. How to: in My Projects, tap the "Search Console" '
            'button on your published site\'s card, paste the code Google '
            'gives you and save.',

    'Yayınlanan sitenizdeki iletişim formundan gelen talepler Talep '
        'Kutusu\'na düşer ve anlık bildirim olarak telefonunuza gelir — '
        'ziyaretçi formu doldurduğu anda haberiniz olur, siteyi sürekli '
        'açık tutmanız gerekmez.':
        'Submissions from your published site\'s contact form land in '
            'the Lead Inbox and arrive as an instant notification on '
            'your phone — you\'re alerted the moment a visitor submits '
            'the form, with no need to keep the app open.',

    // === Telefon numarası popup (phone_number_popup.dart) ===
    'WhatsApp Telefon Numarası': 'WhatsApp Phone Number',
    'Ülke kodu ile birlikte, boşluksuz giriniz.\nÖrn: 905551112233':
        'Enter it with the country code, no spaces.\nE.g.: 905551112233',
    'Lütfen geçerli bir telefon numarası giriniz.':
        'Please enter a valid phone number.',

    // === Bildir (report_dialog.dart) ===
    'İçeriği Bildir': 'Report Content',
    'Kısaca açıkla (zorunlu)...': 'Briefly explain (required)...',
    'Gönder 🚩': 'Send 🚩',
    'Lütfen kısa bir açıklama yazınız.': 'Please write a short description.',
    'Bildirimin bize ulaştı, teşekkürler! En kısa sürede inceleyeceğiz. 🙏':
        'Your report has reached us, thank you! We\'ll review it as soon as '
            'possible. 🙏',
    'Rahatsız edici / uygunsuz içerik': 'Offensive / inappropriate content',
    'Yasa dışı içerik': 'Illegal content',
    'Nefret söylemi / taciz': 'Hate speech / harassment',
    'Hatalı / bozuk site': 'Faulty / broken site',
    'Diğer': 'Other',

    // === Önizleme ekranı (preview_screen.dart) ===
    'Ön İzleme': 'Preview',
    'Fotoğraf güncellendi! 🖼️': 'Photo updated! 🖼️',
    'Henüz üretilmiş bir site yok. Önce formu doldurup bir istek gönderiniz.':
        'No site generated yet. Please fill in the form first.',

    // === Ortak (form ekranlarında da kullanılır) ===
    'Randevu Al': 'Book an Appointment',
    'Emlak': 'Real Estate',
    'Portfolyo': 'Portfolio',

    // === Projelerim ===
    'Projelerim': 'My Projects',
    'Henüz bir projen yok.': 'You don\'t have any projects yet.',
    'Bir form doldurduğunda veya Sürükle-Bırak ile oluşturduğunda burada listelenecek.':
        'It will be listed here once you fill out a form or create one with Drag & Drop.',
    // === 2026-08-24: eksik çeviriler tamamlandı (t() ile çağrılıyordu ama
    // en map'te karşılığı yoktu — İngilizce modda Türkçe görünüyorlardı) ===
    'Sürükle-Bırak ile Oluştur': 'Create with Drag & Drop',
    'Boş bir canvas üzerinde sıfırdan tasarla': 'Design from scratch on a blank canvas',
    'Mağaza': 'Store',
    'Ek Site Yayın Hakkı': 'Extra Site Publish Credit',
    'Form kotan bittiğinde otomatik kullanılır, ay sonunda sıfırlanmaz.':
        'Used automatically once your form quota runs out; it doesn\'t reset at month end.',
    'Paketleri Gör': 'View Packages',
    // 16.09.2026 eklendi (kanka isteği — "gerçek sorun #3" fix'i: devir
    // öncesi önleyici abonelik uyarısı, bkz. projects_screen.dart >
    // _claimTransferCode).
    'Devretmeden önce bilmen gereken bir şey var': 'Something you should know before claiming this',
    'Bu site bir aylık abonelik kapsamında rozetsizdi. Kendi aboneliğin olmadığı için devraldığında rozet geri gelecek — dilersen önce bir paket seçebilir, sonra AYNI kodla devralabilirsin.':
        'This site was badge-free under a monthly subscription. Since you don\'t have your own subscription, the badge will come back once you claim it — you can pick a plan first and claim with the SAME code afterwards if you\'d like.',
    'Yine de Devral': 'Claim Anyway',
    'Önce Paketleri Gör': 'View Packages First',
    // 16.09.2026 eklendi (kanka isteği — "domain devirde kaybolmasın"
    // akışı, bkz. projects_screen.dart > _claimTransferCode).
    'Bu site bir domainle geliyor': 'This site comes with a domain',
    'Domain, eski sahibin aylık aboneliğinden ücretsiz bağlanmış. Kendi aboneliğinde boş bir domain hakkın olmadığı için, devraldığında bu domain otomatik olarak sökülür. İstersen yıllık domain bağlama ücretini şimdi ödeyip domaini siteyle birlikte kalıcı olarak devralabilirsin.':
        'The domain was connected for free through the previous owner\'s subscription. Since you don\'t have a free domain slot on your own plan, it will be disconnected automatically when you claim this site. If you\'d like, you can pay the annual domain fee now and keep the domain permanently attached to the site.',
    'Domainsiz Devral': 'Claim Without Domain',
    'Yıllık Domain Öde ve Devral': 'Pay Annual Domain & Claim',
    'Domain kotanda o an boş slot kalmamış olabilir — bu site şu an domainsiz devralındı. Dilersen yıllık domain ücretini ödeyip yeniden bağlayabilirsin.':
        'Your domain quota may have filled up right at that moment — this site was claimed without its domain. You can pay the annual domain fee to reconnect it whenever you\'d like.',
    'artık senin — domain dahil, Projelerim listende görünüyor.':
        'is now yours — domain included, and it\'s in your Projects list.',
    'Rozet Kaldır': 'Remove Badge',
    'Site Seç': 'Select Site',
    'Renk seçin': 'Choose color',
    'Seçilen renk': 'Selected color',
    'Kalem Boyutu:': 'Pen Size:',
    'Kendi Şeklini Çiz': 'Draw Your Own Shape',
    'Bir form ile site oluşturduğunda burada listelenecek.':
        'Once you generate a site from a form, it will be listed here.',
    'Proje Adını Değiştir': 'Rename Project',
    'Adını Değiştir': 'Rename',
    'Proje adı güncellendi.': 'Project name updated.',
    'Projeyi Sil': 'Delete Project',
    'Proje silindi.': 'Project deleted.',

    // === Form ekranları (sektör bazlı, otomatik eklenmiştir) ===
    '-': '-',
    '2023 - Freelance DJ - İstanbul\n2019 - Müzik Yapımcılığı - Eğitim': '2023 - Freelance DJ - Istanbul\n2019 - Music Production - Education',
    '2023 - Freelance Fotoğrafçı - İstanbul\n2020 - Fotoğrafçılık Sertifikası - Kurs': '2023 - Freelance Photographer - Istanbul\n2020 - Photography Certificate - Course',
    '2023 - Freelance Makyaj Sanatçısı - İstanbul\n2021 - Makyaj Sertifikası - Akademi': '2023 - Freelance Makeup Artist - Istanbul\n2021 - Makeup Certificate - Academy',
    '2023 - Kişisel Antrenör - Freelance\n2020 - Fitness Eğitmenliği Sertifikası - Federasyon': '2023 - Personal Trainer - Freelance\n2020 - Fitness Coaching Certificate - Federation',
    '2023 - UI/UX Tasarımcı - Freelance\n2020 - Grafik Tasarım - Üniversite': '2023 - UI/UX Designer - Freelance\n2020 - Graphic Design - University',
    '905551112233': '905551112233',
    'ANA SAYFA': 'HOME',
    'Ad Soyad': 'Full Name',
    'Adres': 'Address',
    'Aidat (opsiyonel)': 'Membership Fee (optional)',
    'Aile Danışmanlığı\nBireysel Terapi': 'Family Counseling\nIndividual Therapy',
    'Avukat / Hukuk Bürosu Sitesi': 'Lawyer / Law Firm Site',
    'Aylık Üyelik - 1200 TL\nGrup Dersi (tekli) - 150 TL': 'Monthly Membership - 1200 TL\nGroup Class (single) - 150 TL',
    'Açıklama': 'Description',
    'Aşı & Kontrol\nCerrahi Operasyon\nMikroçip': 'Vaccination & Checkup\nSurgical Operation\nMicrochip',
    'B Sınıfı Ehliyet Kursu - 8 hafta - 12000 TL\nDireksiyon Ek Ders - 45 dk - 400 TL': 'Class B Driving Course - 8 weeks - 12000 TL\nExtra Driving Lesson - 45 min - 400 TL',
    'Bağlantı, wifi veya metin için QR kod üret.': 'Generate a QR code for a link, wifi, or text.',
    'Biyo Link Sayfası': 'Bio Link Page',
    'Boylam (lng)': 'Longitude (lng)',
    'Branşlar, hekimler ve iletişim bilgileriyle klinik sitesi.': 'A clinic site with specialties, doctors, and contact info.',
    'Deneyim & eğitim (her satıra bir tane: Yıl - Başlık - Açıklama)': 'Experience & education (one per line: Year - Title - Description)',
    'Ders programı (her satıra bir tane: Gün - Saat - Ders - Eğitmen)': 'Class schedule (one per line: Day - Time - Class - Instructor)',
    'Dijital Kartvizit': 'Digital Business Card',
    'Dijital/QR menü linki (opsiyonel)': 'Digital/QR menu link (optional)',
    'Diyetisyen Sitesi': 'Dietitian Site',
    'Diş Hekimi Sitesi': 'Dentist Site',
    'Düğün Organizasyonu, Canlı Performans, Ses Sistemi': 'Wedding Organization, Live Performance, Sound System',
    'Düğün Çekimi, Dış Mekan, Stüdyo Portre': 'Wedding Shoot, Outdoor, Studio Portrait',
    'E-posta (opsiyonel)': 'Email (optional)',
    'Elektrik Arıza - 300 TL\nTesisat Tamiri - 350 TL': 'Electrical Fault - 300 TL\nPlumbing Repair - 350 TL',
    'Elektrikçi, tesisatçı veya tamirci için hizmet ve iletişim sitesi.': 'A services and contact site for an electrician, plumber, or handyman.',
    'Emlak Sitesi': 'Real Estate Site',
    'Emlakçı / ofis adı': 'Agent / office name',
    'Emlakçı/ofis adı ve telefon gerekli.': 'Agent/office name and phone are required.',
    'En az 1 ilan eklemelisin.': 'You must add at least 1 listing.',
    'English': 'English',
    'Enlem (lat)': 'Latitude (lat)',
    'Ev Temizliği - 3 saat - 500 TL\nOfis Temizliği - 800 TL': 'House Cleaning - 3 hours - 500 TL\nOffice Cleaning - 800 TL',
    'Evden Eve Nakliyat - 2500 TL\nOfis Taşıma - 3500 TL': 'Home Moving - 2500 TL\nOffice Moving - 3500 TL',
    'Figma, UI Tasarım, Flutter': 'Figma, UI Design, Flutter',
    'Firma adı': 'Company name',
    'Fitness Stüdyosu Sitesi': 'Fitness Studio Site',
    'Fiyat (TL)': 'Price (TL)',
    'Fotoğraf': 'Photo',
    'Fotoğraf Örnekleri': 'Photo Samples',
    'Fotoğraf örnekleri ve deneyimle fotoğrafçı portfolyo sitesi.': 'A photographer portfolio site with photo samples and experience.',
    'Fotoğrafçı Sitesi': 'Photographer Site',
    'Gelin Buketi - 800 TL\nAynı Gün Teslimat - 150 TL': 'Bridal Bouquet - 800 TL\nSame Day Delivery - 150 TL',
    'Gelin Makyajı, Özel Gün Makyajı, Kişisel Bakım': 'Bridal Makeup, Special Occasion Makeup, Personal Care',
    'Görsel açıklaması (opsiyonel)': 'Image description (optional)',
    'Görseller cihazdan seçilir, dosya olarak gömülür (yükleme gerekmez).': 'Images are picked from the device and embedded as files (no upload needed).',
    'Güzellik Salonu Sitesi': 'Beauty Salon Site',
    'Hakkında': 'About',
    'Hakkında (opsiyonel)': 'About (optional)',
    'Hizmet alanları (her satıra bir tane)': 'Service areas (one per line)',
    'Hizmet alanları ve randevu bilgileriyle diyetisyen tanıtım sitesi.': 'A dietitian profile site with service areas and appointment info.',
    'Hizmet paketleri ve iletişimle oto yıkama/servis sitesi.': 'A car wash/service site with service packages and contact info.',
    'Hizmetler (her satıra bir tane)': 'Services (one per line)',
    'Hizmetler (her satıra bir tane: Ad - Süre - Fiyat)': 'Services (one per line: Name - Duration - Price)',
    'Hizmetler ve iletişim bilgileriyle nakliyat/evden eve nakliyat sitesi.': 'A moving/home relocation site with services and contact info.',
    'Hizmetler ve randevu bilgileriyle veteriner kliniği sitesi.': 'A veterinary clinic site with services and appointment info.',
    'Hizmetler, galeri ve randevu bilgileriyle kuaför/berber sitesi.': 'A hair salon/barber site with services, gallery, and appointment info.',
    'Hizmetler, galeri ve randevu bilgileriyle pet kuaförü/pet shop sitesi.': 'A pet groomer/pet shop site with services, gallery, and appointment info.',
    'Hizmetler, galeri ve randevu bilgileriyle terzi tanıtım sitesi.': 'A tailor profile site with services, gallery, and appointment info.',
    'Hizmetler, çalışma saatleri ve konumuyla temizlik şirketi tanıtım sitesi.': 'A cleaning company profile site with services, working hours, and location.',
    'Instagram - https://instagram.com/kullanici\nYoutube - https://youtube.com/@kanal': 'Instagram - https://instagram.com/username\nYoutube - https://youtube.com/@channel',
    'Instagram kullanıcı adı (opsiyonel)': 'Instagram username (optional)',
    'Instagram/TikTok bio\'na koyacağın, tüm bağlantılarını tek sayfada toplayan mini site.': 'A mini site that gathers all your links on one page, to put in your Instagram/TikTok bio.',
    'Kafe / Restoran Sitesi': 'Café / Restaurant Site',
    'Çok Sayfalı Site': 'Multi-Page Site',
    'Ana Sayfa, Menü ve Galeri ayrı sayfalar olarak oluşturulur.':
        'Home, Menu and Gallery are generated as separate pages.',
    'Kahveler\nEspresso - - 60 TL\nLatte - Sütlü - 75 TL\n\nTatlılar\nCheesecake - Ev yapımı - 90 TL': 'Coffees\nEspresso - - 60 TL\nLatte - With milk - 75 TL\n\nDesserts\nCheesecake - Homemade - 90 TL',
    'Kapak Görseli': 'Cover Image',
    'Kapalı': 'Closed',
    'Kartviziti Oluştur': 'Generate Business Card',
    'Kat (opsiyonel)': 'Floor (optional)',
    'Kaydediliyor...': 'Saving...',
    'Kilo Verme, Kas Kütlesi Artırma, Online Koçluk': 'Weight Loss, Muscle Building, Online Coaching',
    'Kişisel Antrenör Sitesi': 'Personal Trainer Site',
    'Kişiye Özel Beslenme Programı\nSporcu Beslenmesi\nOnline Danışmanlık': 'Personalized Nutrition Program\nSports Nutrition\nOnline Consulting',
    'Klinik / Sağlık Sitesi': 'Clinic / Health Site',
    'Klinik / hekim adı': 'Clinic / doctor name',
    'Klinik / uzman adı': 'Clinic / specialist name',
    'Klinik / veteriner adı': 'Clinic / vet name',
    'Klinik/uzman adı ve telefon gerekli.': 'Clinic/specialist name and phone are required.',
    'Konum': 'Location',
    'Kuaför / Berber Sitesi': 'Hair Salon / Barber Site',
    'Kurs Paketleri (her satıra bir tane: Ad - Süre - Fiyat)': 'Course Packages (one per line: Name - Duration - Price)',
    'Kurs adı': 'Course name',
    'Kurs paketleri ve iletişim bilgileriyle sürücü kursu sitesi.': 'A driving school site with course packages and contact info.',
    'Köpek Yıkama & Tıraş - 45 dk - 350 TL\nTırnak Kesimi - 100 TL': 'Dog Wash & Trim - 45 min - 350 TL\nNail Trimming - 100 TL',
    'Kısa açıklama (opsiyonel, max 100 karakter)': 'Short description (optional, max 100 characters)',
    'Kısa özgeçmiş / tanıtım': 'Short bio / introduction',
    'Link, wifi bilgisi veya metin': 'Link, wifi info, or text',
    'LinkedIn - https://linkedin.com/in/...\nWeb sitesi - https://...': 'LinkedIn - https://linkedin.com/in/...\nWebsite - https://...',
    'Linkler (her satıra bir tane: Etiket - URL)': 'Links (one per line: Label - URL)',
    'Logo/foto URL (opsiyonel)': 'Logo/photo URL (optional)',
    'Mahalle, cadde, ilçe, il': 'Neighborhood, street, district, city',
    'Makyaj Sanatçısı Sitesi': 'Makeup Artist Site',
    'Manikür - 45 dk - 200 TL\nCilt Bakımı - 300 TL': 'Manicure - 45 min - 200 TL\nSkin Care - 300 TL',
    'Masaj / SPA Sitesi': 'Massage / SPA Site',
    'Menü (kategoriler arasına boş satır bırak)': 'Menu (leave a blank line between categories)',
    'Menü, çalışma saatleri ve konumuyla hazır bir kafe/restoran sitesi.': 'A ready-made café/restaurant site with menu, working hours, and location.',
    'Meslek / unvan': 'Profession / title',
    'Müzisyen / DJ Sitesi': 'Musician / DJ Site',
    'Nakliyat Sitesi': 'Moving Company Site',
    'Oda (örn. 3+1)': 'Rooms (e.g. 3+1)',
    'Oluşturuluyor...': 'Generating...',
    'Oto Yıkama / Servis Sitesi': 'Car Wash / Service Site',
    'PNG Kaydet': 'Save PNG',
    'Paketler (her satıra bir tane: Ad - Süre - Fiyat)': 'Packages (one per line: Name - Duration - Price)',
    'Pantolon Paça Kısaltma - 100 TL\nElbise Dikim - 1500 TL': 'Trouser Hemming - 100 TL\nDress Tailoring - 1500 TL',
    'Pazartesi - 18:00 - CrossFit - Ahmet\nÇarşamba - 19:00 - Yoga - Elif': 'Monday - 18:00 - CrossFit - Ahmet\nWednesday - 19:00 - Yoga - Elif',
    'Performans Örnekleri': 'Performance Samples',
    'Performans örnekleri ve deneyimle müzisyen/DJ portfolyo sitesi.': 'A musician/DJ portfolio site with performance samples and experience.',
    'Pet Kuaförü / Pet Shop Sitesi': 'Pet Groomer / Pet Shop Site',
    'PhD - Klinik Psikoloji\nEMDR Sertifikası': 'PhD - Clinical Psychology\nEMDR Certificate',
    'Portfolyo Sitesi': 'Portfolio Site',
    'Profil Fotoğrafı': 'Profile Photo',
    'Profil Fotoğrafı (opsiyonel)': 'Profile Photo (optional)',
    'Program, eğitmen ve ders saatleriyle fitness stüdyosu sitesi.': 'A fitness studio site with program, trainers, and class schedule.',
    'Projelerini/işlerini sergileyeceğin kişisel portfolyo sitesi.': 'A personal portfolio site to showcase your projects/work.',
    'QR Kod Oluştur': 'Generate QR Code',
    'QR Oluştur': 'Generate QR',
    'QR kod PNG olarak kaydedildi! ✅': 'QR code saved as PNG! ✅',
    'QR kodun burada görünecek': 'Your QR code will appear here',
    'Sayfayı Oluştur': 'Generate Page',
    'Saç Kesimi - 30 dk - 150 TL\nSakal Tıraşı - 100 TL': 'Haircut - 30 min - 150 TL\nBeard Trim - 100 TL',
    'Semt/ilçe etiketi': 'Neighborhood/district tag',
    'Sertifika / unvan rozetleri (her satıra bir tane, opsiyonel)': 'Certificate / title badges (one per line, optional)',
    'Siteyi Oluştur': 'Generate Site',
    'Sitora': 'Sitora',
    'Slogan (opsiyonel)': 'Tagline (optional)',
    'Sosyal / web linkleri (opsiyonel, her satıra bir tane: Platform - URL)': 'Social / web links (optional, one per line: Platform - URL)',
    'Stüdyo adı': 'Studio name',
    'Stüdyo adı ve telefon gerekli.': 'Studio name and phone are required.',
    'Sürücü Kursu Sitesi': 'Driving School Site',
    'Tek sayfalık şablonlar': 'Single-page templates',
    'Telefon': 'Phone',
    'Tema': 'Theme',
    'Tipografi': 'Typography',
    'Yoğunluk': 'Density',
    'Editoryal': 'Editorial',
    'Modern Sade': 'Modern Plain',
    'Sıcak': 'Warm',
    'Klasik': 'Classic',
    'Kalın / Vurgulu': 'Bold / Expressive',
    'İnce': 'Light',
    'Galeri Görünümü': 'Gallery Layout',
    'Slayt Gösterisi': 'Slideshow',
    'Çalışma Saatleri': 'Working Hours',
    'Pazartesi': 'Monday',
    'Salı': 'Tuesday',
    'Çarşamba': 'Wednesday',
    'Perşembe': 'Thursday',
    'Cuma': 'Friday',
    'Cumartesi': 'Saturday',
    'Pazar': 'Sunday',
    'Temizlik Şirketi Sitesi': 'Cleaning Company Site',
    'Terzi Sitesi': 'Tailor Site',
    'Ticaret Hukuku\nAile Hukuku\nİş Hukuku': 'Commercial Law\nFamily Law\nLabor Law',
    'Türkçe': 'Turkish',
    'Unvan (örn. Avukat)': 'Title (e.g. Lawyer)',
    'Unvan (örn. Diş Hekimi)': 'Title (e.g. Dentist)',
    'Unvan (örn. Uzman Diyetisyen)': 'Title (e.g. Dietitian Specialist)',
    'Unvan (örn. Uzman Psikolog)': 'Title (e.g. Psychologist Specialist)',
    'Unvan (örn. Veteriner Hekim)': 'Title (e.g. Veterinarian)',
    'Unvan / meslek': 'Title / profession',
    'Unvan, uzmanlık alanları ve randevu bilgileriyle diş hekimi sitesi.': 'A dentist site with title, specialties, and appointment info.',
    'Usta Hizmetleri Sitesi': 'Handyman Services Site',
    "Uzmanlık (örn. Düğün DJ'i)": 'Specialty (e.g. Wedding DJ)',
    'Uzmanlık (örn. Düğün Fotoğrafçısı)': 'Specialty (e.g. Wedding Photographer)',
    'Uzmanlık (örn. Gelin Makyajı Uzmanı)': 'Specialty (e.g. Bridal Makeup Specialist)',
    'Uzmanlık (örn. Kişisel Fitness Koçu)': 'Specialty (e.g. Personal Fitness Coach)',
    'Uzmanlık alanları (her satıra bir tane)': 'Specialties (one per line)',
    'Uzmanlık alanları ve iletişim bilgileriyle avukat/hukuk bürosu sitesi.': 'A lawyer/law firm site with specialties and contact info.',
    'Veteriner Kliniği Sitesi': 'Veterinary Clinic Site',
    'WhatsApp (90XXXXXXXXXX)': 'WhatsApp (90XXXXXXXXXX)',
    'WhatsApp (opsiyonel, 90XXXXXXXXXX)': 'WhatsApp (optional, 90XXXXXXXXXX)',
    'Yeni İlan': 'New Listing',
    'Yeni Sayfa': 'New Page',
    'Sayfayı Düzenle': 'Edit Page',
    'Yetenekler (virgülle ayır)': 'Skills (comma-separated)',
    'https://ornek.com': 'https://ornek.com',
    'm²': 'm²',
    'Çalışma Örnekleri': 'Work Samples',
    'Çalışma örnekleri ve deneyimle kişisel antrenör portfolyo sitesi.': 'A personal trainer portfolio site with work samples and experience.',
    'Çalışma örnekleri ve deneyimle makyaj sanatçısı portfolyo sitesi.': 'A makeup artist portfolio site with work samples and experience.',
    'Çiçekçi Sitesi': 'Florist Site',
    'Çok sayfalı şablonlar (Emlak)': 'Multi-page templates (Real Estate)',
    'Öncesi / Sonrası Galeri': 'Before / After Gallery',
    'Öncesi/Sonrası & Çalışma Fotoğrafları': 'Before/After & Work Photos',
    'Öncesi/sonrası galerisiyle güzellik salonu tanıtım sitesi.': 'A beauty salon profile site with a before/after gallery.',
    'Öncesi/sonrası galerisiyle masaj/SPA salonu tanıtım sitesi.': 'A massage/SPA salon profile site with a before/after gallery.',
    'Örn: Öncesi / Sonrası': 'E.g.: Before / After',
    'Ürün/Hizmetler (her satıra bir tane: Ad - Süre - Fiyat)': 'Products/Services (one per line: Name - Duration - Price)',
    'Ürünler, galeri ve sipariş bilgileriyle çiçekçi sitesi.': 'A florist site with products, gallery, and order info.',
    'Üyelik / hizmet paketleri (her satıra bir tane: Ad - Fiyat)': 'Membership / service packages (one per line: Name - Price)',
    'İlan Ekle': 'Add Listing',
    'İlan Galerisi': 'Listing Gallery',
    'İlan başlığı': 'Listing title',
    'İlan başlığı ve fiyat gerekli.': 'Listing title and price are required.',
    'İlan listesi ve detay sayfalarıyla çok sayfalı emlak sitesi.': 'A multi-page real estate site with a listing list and detail pages.',
    'İlanı Düzenle': 'Edit Listing',
    'İletişim e-postası': 'Contact email',
    'İmplant Tedavisi\nDiş Beyazlatma\nOrtodonti': 'Implant Treatment\nTeeth Whitening\nOrthodontics',
    'İsim': 'Name',
    'İsim / büro adı': 'Name / office name',
    'İsim / işletme adı': 'Name / business name',
    'İsim / marka adı': 'Name / brand name',
    'İsim gerekli.': 'Name is required.',
    'İsim ve e-posta gerekli.': 'Name and email are required.',
    'İsim ve en az bir link gerekli.': 'Name and at least one link are required.',
    'İsim, unvan, iletişim ve sosyal linklerinle şık bir dijital kartvizit sayfası.': 'A stylish digital business card page with your name, title, contact info, and social links.',
    'İsveç Masajı - 60 dk - 600 TL\nAromaterapi - 90 dk - 900 TL': 'Swedish Massage - 60 min - 600 TL\nAromatherapy - 90 min - 900 TL',
    'İç-Dış Yıkama - 30 dk - 250 TL\nSeramik Kaplama - 1500 TL': 'Interior-Exterior Wash - 30 min - 250 TL\nCeramic Coating - 1500 TL',
    'İş Örnekleri': 'Work Samples',
    'İşletme adı': 'Business name',
    'İşletme adı ve telefon gerekli.': 'Business name and phone are required.',
    'Şirket (opsiyonel)': 'Company (optional)',
    // 25.08.2026 eklendi — Ön İzleme > Düzenle akışı (bkz.
    // screens/preview_screen.dart > _openEditForm, screens/*_form_screen.dart).
    'Düzenlemeyi Bitir': 'Finish Editing',
    'Bu site formdan düzenlenemiyor.': "This site can't be edited from a form.",
    'Bu site türü için düzenleme ekranı yok.': 'There is no edit screen for this site type.',
    'Bu site bu hesaba özel hazırlanmıştır ve uygulama içinden düzenlenemez.':
        'This site was prepared specifically for this account and cannot be edited from the app.',
    // 31.08.2026 eklendi — e-posta doğrulama bekleme ekranı (login_gate.dart)
    // ve App Links ile gelen şifre sıfırlama ekranı (reset_password_confirm_screen.dart).
    'E-postanı doğrula': 'Verify your email',
    'Gelen kutuna bir doğrulama bağlantısı gönderdik. Linke tıklayıp buraya döndüğünde otomatik devam edeceğiz — başka bir şey yapmana gerek yok.':
        "We've sent a verification link to your inbox. Tap the link and come back here — we'll continue automatically, nothing else to do.",
    'Doğruladım, kontrol et': "I've verified, check now",
    'Doğrulama e-postasını tekrar gönder': 'Resend verification email',
    'Farklı hesapla devam et': 'Continue with a different account',
    'Doğrulama bağlantısı tekrar gönderildi.': 'Verification link sent again.',
    'Henüz doğrulanmamış görünüyor. E-postanı kontrol et.':
        "Doesn't look verified yet. Check your email.",
    'Yeni şifre belirle': 'Set a new password',
    'Yeni şifre': 'New password',
    'Yeni şifre (tekrar)': 'New password (repeat)',
    'Şifreler eşleşmiyor.': "Passwords don't match.",
    'Şifreyi Güncelle': 'Update Password',
    'Şifren güncellendi': 'Your password has been updated',
    'Yeni şifrenle giriş yapabilirsin.': 'You can now sign in with your new password.',
    // === 31.08.2026 eklendi — SSS/testimonial alanları ===
    'Müşteri Yorumları (opsiyonel — her satıra bir tane: İsim | Yorum | Puan)':
        'Customer Reviews (optional — one per line: Name | Review | Rating)',
    'Ayşe K. | Çok memnun kaldım, teşekkürler! | 5':
        'Jane D. | Very happy with the service, thank you! | 5',
    'Sıkça Sorulan Sorular (opsiyonel — her satıra bir tane: Soru | Cevap)':
        'Frequently Asked Questions (optional — one per line: Question | Answer)',
    'Randevusuz gelebilir miyim? | Evet, ama randevulu müşteriler önceliklidir.':
        'Can I walk in without an appointment? | Yes, but customers with appointments have priority.',
    // === 01.09.2026 eklendi — eksik SSS/yorum placeholder çevirileri ===
    'Ayşe K. | Süreç boyunca çok ilgiliydi, teşekkürler! | 5':
        'Jane D. | Very attentive throughout the process, thank you! | 5',
    'Kredi kullanabilir miyim? | Evet, anlaşmalı bankalarımız üzerinden destek sağlıyoruz.':
        'Can I use a mortgage/loan? | Yes, we provide support through our partner banks.',
    'Nasıl randevu alabilirim? | E-posta veya telefon üzerinden iletişime geçebilirsiniz.':
        'How can I book an appointment? | You can reach out by email or phone.',
    'Randevu nasıl alabilirim? | Telefon veya WhatsApp üzerinden randevu alabilirsiniz.':
        'How can I book an appointment? | You can book by phone or WhatsApp.',
    'Rezervasyon gerekli mi? | Hafta sonları önerilir, hafta içi genelde yer var.':
        'Is a reservation required? | Recommended on weekends, there is usually room on weekdays.',
    // === 01.09.2026 eklendi — servis katmanı hata mesajları (bkz.
    // widgets/login_gate.dart, widgets/publish_sheet.dart,
    // widgets/report_dialog.dart, screens/domain_connect_screen.dart) ===
    'Hosting henüz aktif değil. Worker/D1 tarafı yayına alınınca bu özellik otomatik açılacak.':
        'Hosting is not active yet. This feature will turn on automatically once the Worker/D1 side goes live.',
    'Bu site için istatistik bulunamadı (henüz yayınlanmamış olabilir).':
        'No stats found for this site (it may not be published yet).',
    'Domain bağlama henüz aktif değil. Bu özellik Cloudflare tarafında yapılandırılınca otomatik açılacak.':
        'Domain connection is not active yet. This feature will turn on automatically once configured on the Cloudflare side.',
    'Bu domain başka bir sitede zaten kullanılıyor.': 'This domain is already in use on another site.',
    'Site bulunamadı.': 'Site not found.',
    'Bu projeye bağlı bir domain yok.': 'There is no domain connected to this project.',
    'Giriş sistemi henüz aktif değil. Firebase kurulumu tamamlanınca bu özellik otomatik açılacak.':
        'The sign-in system is not active yet. This feature will turn on automatically once Firebase is set up.',
    'Doğrulama bağlantısı e-postana gönderildi. Linke tıklayıp uygulamaya dön — otomatik devam edeceksin.':
        "We've sent a verification link to your email. Tap the link and come back to the app — we'll continue automatically.",
    'E-postanı henüz doğrulamadın. Gelen kutunu (ve spam klasörünü) kontrol et.':
        "You haven't verified your email yet. Check your inbox (and spam folder).",
    'Bildirim gönderilemedi. İnternetini kontrol edip tekrar dener misin?':
        'The report could not be sent. Please check your connection and try again.',
    // === TR/EN eksik çeviri taraması — 02.09.2026 eklendi ===
    'Ana Sayfa': 'Home',
    'Google Yorum Linki (opsiyonel)': 'Google Review Link (optional)',
    'Kutu': 'Mailbox',
    'Projeler': 'Projects',
    'Talepler': 'Requests',
    // === Şablon önizleme kart başlıkları — 02.09.2026 eklendi ===
    'Kuaför / Berber': 'Hairdresser / Barber',
    'Kafe / Restoran': 'Cafe / Restaurant',
    'Klinik / Sağlık': 'Clinic / Health',
    'Oto Tamirci / Lastikçi': 'Auto Repair / Tire Shop',
    'Butik Otel / Pansiyon': 'Boutique Hotel / Guesthouse',
    'Oto Yıkama / Servis': 'Car Wash / Service',
    'Temizlik Şirketi': 'Cleaning Company',
    'Sürücü Kursu': 'Driving School',
    'Elektrikçi': 'Electrician',
    'Çiçekçi': 'Florist',
    'Mobilyacı / Dekorasyon': 'Furniture / Decor',
    'Genel İşletme': 'General Business',
    'Tadilatçı': 'Handyman',
    'Anaokulu / Kreş': 'Kindergarten / Nursery',
    'Masaj / Spa': 'Massage / Spa',
    'Nakliyat': 'Moving Company',
    'Pet Kuaförü': 'Pet Grooming',
    'Terzi': 'Tailor',
    'Fırın / Pastane': 'Bakery / Pastry Shop',
    'Restoran / Lokanta': 'Restaurant',
    'Diş Hekimi': 'Dentist',
    'Diyetisyen': 'Dietitian',
    'Avukat / Hukuk Bürosu': 'Lawyer / Law Firm',
    'Veteriner': 'Veterinarian',
    'Güzellik Salonu': 'Beauty Salon',
    'Fitness Stüdyosu': 'Fitness Studio',
    'Makyaj Sanatçısı': 'Makeup Artist',
    'Müzisyen / DJ': 'Musician / DJ',
    'Kişisel Antrenör': 'Personal Trainer',
    'Fotoğrafçı': 'Photographer',

    // === 17.09.2026 eklendi (kanka isteği — TR/EN eksik çeviri taraması) ===
    // Mağaza / Abonelik ekranı (store_sheet.dart, subscription_plans_screen.dart):
    // bu satırlar t(context, ...) ile çağrılıyordu ama sözlükte karşılığı yoktu,
    // İngilizce modda bile Türkçe metin görünüyordu.
    'Abonelik Planları': 'Subscription Plans',
    'Yönet': 'Manage',
    // SSS ekranı (faq_screen.dart) — 16.09.2026'da eklenen 2 yeni soru/cevap
    // sözlüğe hiç işlenmemiş.
    'Domain süresi dolunca ne oluyor?': 'What happens when the domain expires?',
    'Rozeti domain bağlayarak kaldırdıysan, bu kaldırma o satın almanın SÜRESİNE bağlıdır — süre dolup yenilenmezse rozet otomatik geri gelir. Rozeti AYRICA/kalıcı olarak satın aldıysan bu durum seni etkilemez, kalıcı kaldırma asla geri gelmez.':
        'If you removed the badge by connecting a domain, that removal is tied to that purchase\'s DURATION — if it expires without renewal, the badge comes back automatically. If you purchased permanent badge removal SEPARATELY, this doesn\'t affect you — a permanent removal never comes back.',
    'Domain otomatik yenileniyor mu, tekrar ücret keser mi?': 'Does the domain renew automatically — will it charge me again?',
    'Hayır. Tek seferlik satın almadır, otomatik yenilenen bir abonelik DEĞİLDİR. Süre dolduğunda kendiliğinden yenilenmez ve tekrar ücret kesmez — uzatmak istersen tekrar senin satın alman gerekir.':
        'No. It\'s a one-time purchase, NOT an auto-renewing subscription. It won\'t renew on its own when it expires and won\'t charge you again — if you want to extend it, you\'ll need to purchase it again.',
    // Hero Düzeni seçici (layout_style_picker_field.dart) — 3 seçenek etiketi
    // hiç çevrilmemiş, İngilizce modda hâlâ Türkçe görünüyordu.
    'Klasik (Ortalı)': 'Classic (Centered)',
    'Editorial (Sola Yaslı)': 'Editorial (Left-Aligned)',
    '👑 Framed (Çerçeveli)': '👑 Framed',
  };
}

/// Aktif dile göre [trText] metnini döndürür.
///
/// [context] üzerinden [LocaleController]'ı DİNLEMEDEN (listen:false) okur;
/// bu yüzden hem build() içinde hem de onPressed/onTap gibi callback'ler
/// içinde güvenle kullanılabilir. Dil değiştiğinde ilgili ekranın yeniden
/// çizilmesi için her ekranın/dialogun build() metodunun başında bir kez
/// `context.watch<LocaleController>();` çağrılması yeterlidir.
String t(BuildContext context, String trText) {
  final isEn = Provider.of<LocaleController>(context, listen: false).isEnglish;
  if (!isEn) return trText;
  return AppStrings.en[trText] ?? trText;
}

/// Enterpolasyonlu (değişken içeren) mesajlarda TR/EN dallanması yapmak
/// için kullanılan kısa yardımcı: aktif dilin İngilizce olup olmadığını
/// döner. `t()` sabit metinler için yeterliyken, içine `${...}` gibi
/// dinamik veri giren mesajlarda doğrudan bu bayrakla dallanmak gerekir.
bool isEnglish(BuildContext context) {
  return Provider.of<LocaleController>(context, listen: false).isEnglish;
}
