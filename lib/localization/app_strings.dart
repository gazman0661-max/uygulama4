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
    // === Genel / Ortak butonlar ===
    'İptal': 'Cancel',
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
    '"Sitora ile üretildi" rozeti sitede görünür kalır.': 'The "Made with Sitora" badge stays visible on the site.',
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
    'E-posta': 'Email',
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
    'Puan Satın Al': 'Buy Points',
    'puan': 'points',
    'Fiyat alınamadı': 'Price unavailable',
    'Ücretsiz yayın hakkın doldu': "You've used your free publish",
    'Satın aldığın puanlar ayın sonunda sıfırlanmaz; aylık ücretsiz kotan bittiğinde otomatik kullanılır.':
        "Purchased points don't reset at month end; they're used automatically once your free monthly quota runs out.",
    'Ek Sayfalar': 'Extra Pages',
    'Genel İşletme Sitesi': 'General Business Site',
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
    // === Builder Pro — üst araç çubuğu (bkz. screens/builder_screen.dart) ===
    'Geri': 'Undo',
    'İleri': 'Redo',
    'Izgara': 'Grid',
    'Akıllı CTA': 'Smart CTA',
    'Uygulama Tanıtımı': 'App Landing',
    // === Builder Pro — alt araç çubuğu (toolChip etiketleri) ===
    'Arka Plan': 'Background',
    'Bölümler': 'Sections',
    'Dikdörtgen': 'Rectangle',
    'Foto': 'Photo',
    'Kalın': 'Bold',
    'Yazı': 'Text',
    'Yıldız': 'Star',
    'Çizim': 'Draw',
    'Üçgen': 'Triangle',
    'Şablonlar': 'Templates',
    'Şekiller': 'Shapes',
    '📑 Şablonlar': '📑 Templates',
    // === Builder Pro — canvas / özellik paneli / dialoglar ===
    'Daire': 'Circle',
    'Bağlantı (https:// veya https://wa.me/...)': 'Link (https:// or https://wa.me/...)',
    'Bağlantı (instagram.com/, tiktok.com/... vb.)': 'Link (instagram.com/, tiktok.com/... etc.)',
    'Başlığını buraya yaz': 'Type your title here',
    'Bize Ulaş': 'Contact Us',
    'Buton Rengi': 'Button Color',
    'Buton Yazısı': 'Button Text',
    'Canvas hazır.\nAlt taraftaki araçlarla\nsitenizi tasarlamaya başlayabilirsiniz.':
        'Canvas ready.\nUse the tools below\nto start designing your site.',
    'Dolgu Rengi': 'Fill Color',
    'Fotoğraf Değiştir': 'Change Photo',
    'Fotoğrafı Değiştir': 'Change Photo',
    'Şekle Foto Ekle': 'Add Photo to Shape',
    'Yazı Boyutu': 'Font Size',
    'Köşe Yuvarlaklığı': 'Corner Radius',
    'Fotoğrafı Kaldır': 'Remove Photo',
    'Görsel alanı — 🖼️ ile fotoğraf ekle': 'Image area — add a photo with 🖼️',
    'Hemen Başla': 'Get Started',
    'Hemen İncele': 'Check It Out',
    'Kahraman Bölüm (başlık + CTA)': 'Hero Section (title + CTA)',
    'Kare / Dikdörtgen': 'Square / Rectangle',
    'Kısa bir alt açıklama ekle': 'Add a short subtitle',
    'Metin': 'Text',
    'Telefon numarası girilmedi': 'No phone number entered',
    'Yeni metin': 'New text',
    'İletişim Bölümü (WA + IG)': 'Contact Section (WA + IG)',
    '🎨 Arka Plan Rengi': '🎨 Background Color',
    // === Builder Pro — hazır şablonlar (kBuilderTemplates) ===
    'Kafe & Restoran': 'Café & Restaurant',
    'Yeme-İçme': 'Food & Drink',
    'Menü, konum ve rezervasyon butonu odaklı sıcak tonlu tasarım.':
        'Warm-toned design focused on menu, location, and a reservation button.',
    'Rezervasyon Yap': 'Make a Reservation',
    'Kuaför & Güzellik Salonu': 'Hair Salon & Beauty Salon',
    'Güzellik': 'Beauty',
    "Hizmet listesi, galeri ve WhatsApp'tan randevu akışı.":
        'Service list, gallery, and WhatsApp booking flow.',
    'Emlak Ofisi': 'Real Estate Office',
    'İlan kartları, harita ve iletişim formu düzeni.':
        'Listing cards, map, and contact form layout.',
    'İlanları Gör': 'View Listings',
    'Spor Salonu / Fitness': 'Gym / Fitness',
    'Spor & Sağlık': 'Sports & Health',
    'Üyelik paketleri, program tanıtımı ve enerjik koyu tema.':
        'Membership packages, program showcase, and an energetic dark theme.',
    'Üye Ol': 'Join Now',
    'E-ticaret / Butik': 'E-commerce / Boutique',
    'Satış': 'Sales',
    "Ürün vitrini, kampanya bandı ve sepete/WhatsApp'a yönlendirme.":
        'Product showcase, campaign banner, and cart/WhatsApp redirect.',
    'Alışverişe Başla': 'Start Shopping',
    'Diş / Estetik Kliniği': 'Dental / Aesthetic Clinic',
    'Sağlık': 'Health',
    'Güven veren mavi-beyaz palet, hizmetler ve online randevu.':
        'Trust-building blue-white palette, services, and online appointments.',
    'Online Randevu': 'Book Online',
    'Düğün & Etkinlik': 'Wedding & Event',
    'Etkinlik': 'Event',
    'Davetiye tarzı zarif tipografi, geri sayım ve konum bilgisi.':
        'Invitation-style elegant typography, countdown, and location info.',
    'Detayları Gör': 'See Details',
    'Kişisel Portfolyo / CV': 'Personal Portfolio / CV',
    'Proje vitrini, yetenekler ve sosyal medya bağlantıları.':
        'Project showcase, skills, and social media links.',
    'Projelerimi Gör': 'See My Projects',
    'Mobil Uygulama Tanıtımı': 'Mobile App Landing',
    'Ekran görüntüleri, özellik listesi ve Play Store/App Store CTA.':
        'Screenshots, feature list, and Play Store/App Store CTA.',
    'Uygulamayı İndir': 'Download the App',
    'Kurumsal / Ajans': 'Corporate / Agency',
    'Kurumsal': 'Corporate',
    'Hizmet alanları, referanslar ve iletişim odaklı ciddi düzen.':
        'A professional layout focused on service areas, references, and contact.',
    'Bize Ulaşın': 'Contact Us',
    'Hesap': 'Account',
    'Misafir modundasın': 'You are in guest mode',
    'Giriş yapıldı': 'Signed in',
    'Giriş Yap': 'Sign In',
    'Çıkış Yap': 'Sign Out',
    'Sil': 'Delete',

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
    'Kayıt yayılınca (genelde birkaç dakika içinde) bu sayfa otomatik güncellenir, bir şey yapmana gerek yok.':
        'Once the record propagates (usually within a few minutes) this page updates automatically — you don\'t need to do anything.',
    'Kaldırılıyor…': 'Removing…',
    'Uzatılıyor…': 'Extending…',
    'Domaini Kaldır': 'Remove Domain',
    'Bu özellik şu an aktif değil.': 'This feature isn\'t active right now.',
    'Siten şu anda kendi ücretsiz alt alan adından yayında kalmaya devam ediyor.':
        'Your site stays live on its free subdomain in the meantime.',
    'Bağlantıyı 1 Yıl Uzat': 'Extend Connection 1 Year',
    'Domain bağlantın 1 yıl daha uzatıldı ✅': 'Your domain connection has been extended by 1 year ✅',

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
    '1. Form ile Ücretsiz Puanlar': '1. Free Points via Form',
    'Form doldurarak site üretmek için ayda ücretsiz 15 puanınız var. '
        'Bu puanlar her ayın 1\'inde 15\'e YENİLENİR (biriktirmez, '
        'kullanmazsanız bir sonraki aya taşınmaz). Tek sayfa site 5 puan, '
        'çok sayfalı site 10 puan düşer.':
        'You get 15 free points every month for generating sites via the '
            'form. These points RESET to 15 on the 1st of every month '
            '(they don\'t accumulate, and unused points don\'t carry over). '
            'A single-page site costs 5 points, a multi-page site costs 10 '
            'points.',
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
        'önizlemeye dönersiniz; her düzenleme sabit 2 puan düşer (tek/çok '
        'sayfa farketmez).':
        'The \'EDIT\' button on the preview screen reopens your form '
            'already FILLED with what you entered before. Make your '
            'changes and tap \'FINISH EDITING\' — your site updates and '
            'you\'re taken back to the preview; each edit costs a flat 2 '
            'points (regardless of single- or multi-page).',

    '5. İndirme & Kaydetme': '5. Download & Save',
    '\'İNDİR\' butonuna bastığınızda cihazınızın kayıt penceresi '
        'açılır; dosya adını değiştirebilir ve kaydedilecek konumu '
        'kendiniz seçebilirsiniz.':
        'Tapping \'DOWNLOAD\' opens your device\'s save dialog; you can '
            'rename the file and choose where to save it yourself.',

    // === Kota / Limit popup'ları (quota_limit_popup.dart) ===
    'Bu ayki limitiniz doldu': 'We\'ve reached this month\'s limit',
    'Ücretsiz aylık krediniz bitti. Puanlarınız her ayın 1\'inde yenilenecek.':
        'Your free monthly credit is used up. Your points will reset on the 1st of next month.',

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
    'Bağlantı, wifi veya metin için QR kod üret (site oluşturmayla aynı puan kotasından düşer).': 'Generate a QR code for a link, wifi, or text (deducted from the same point quota as site generation).',
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

    // === AI ile Doldur popup'ı (30.08.2026) — bkz. widgets/ai_fill_dialog.dart ===
    'AI ile Doldur': 'Fill with AI',
    'Sektör': 'Sector',
    'İşletme adını yaz.': 'Enter your business name.',
    'Ürünlerin/hizmetlerin ve işletmen hakkında': 'About your products/services and business',
    'Örn: 10 yıldır saç kesimi ve sakal tıraşı yapıyoruz, çocuk kesimi de var, samimi bir ortamımız var...':
        "E.g.: We've been doing haircuts and beard trims for 10 years, we also do kids' cuts, and we have a friendly atmosphere...",
    'Adres (opsiyonel)': 'Address (optional)',
    'Telefon (opsiyonel)': 'Phone (optional)',
    'Gönder': 'Submit',
    'AI şu an yardımcı olamadı. Adres/telefon/sosyal medya bilgilerini yine de uyguladım — metin alanlarını elle doldurabilirsin.':
        "AI couldn't help right now. I've still filled in the address/phone/social info — you can fill the text fields in manually.",

    // === E-posta doğrulama akışı (bkz. widgets/login_gate.dart) ===
    'E-postanı doğrula': 'Verify your email',
    'Gelen kutuna bir doğrulama bağlantısı gönderdik. Linke tıklayıp buraya döndüğünde otomatik devam edeceğiz — başka bir şey yapmana gerek yok.':
        "We've sent a verification link to your inbox. Click the link and come back here — we'll continue automatically, no need to do anything else.",
    'Doğruladım, kontrol et': "I've verified, check now",
    'Doğrulama e-postasını tekrar gönder': 'Resend verification email',
    'Farklı hesapla devam et': 'Continue with a different account',
    'Henüz doğrulanmamış görünüyor. E-postanı kontrol et.': "Doesn't look verified yet. Check your email.",
    'Doğrulama bağlantısı tekrar gönderildi.': 'Verification link sent again.',

    // === Önizleme/düzenleme uyarı mesajı ===
    'Bu site bu hesaba özel hazırlanmıştır ve uygulama içinden düzenlenemez.':
        "This site was created specifically for this account and can't be edited from within the app.",

    // === Sektör isimleri (bkz. models/site_project.dart sector label'ları) ===
    'Kuaför / Berber': 'Hairdresser / Barber',
    'Kafe / Restoran': 'Cafe / Restaurant',
    'Güzellik Salonu': 'Beauty Salon',
    'Klinik / Sağlık': 'Clinic / Health',
    'Fitness Stüdyosu': 'Fitness Studio',
    'Oto Yıkama / Servis': 'Car Wash / Service',
    'Temizlik Şirketi': 'Cleaning Company',
    'Nakliyat': 'Moving Company',
    'Terzi': 'Tailor',
    'Usta Hizmetleri': 'Handyman Services',
    'Çiçekçi': 'Florist',
    'Genel İşletme': 'General Business',
    'Elektrikçi': 'Electrician',
    'Oto Tamirci / Lastikçi': 'Auto Repair / Tire Shop',
    'Fırın / Pastane': 'Bakery / Pastry Shop',
    'Restoran / Lokanta': 'Restaurant',
    'Anaokulu / Kreş': 'Kindergarten / Nursery',
    'Butik Otel / Pansiyon': 'Boutique Hotel / Guesthouse',
    'Mobilyacı / Dekorasyon': 'Furniture / Decor Store',
    'Avukat / Hukuk Bürosu': 'Lawyer / Law Firm',
    'Müzisyen / DJ': 'Musician / DJ',
    'Diyetisyen': 'Dietitian',
    'Diş Hekimi': 'Dentist',
    'Fotoğrafçı': 'Photographer',
    'Kişisel Antrenör': 'Personal Trainer',
    'Makyaj Sanatçısı': 'Makeup Artist',
    'Masaj / SPA': 'Massage / Spa',
    'Sürücü Kursu': 'Driving School',
    'Pet Kuaförü / Pet Shop': 'Pet Grooming / Pet Shop',
    'Veteriner Kliniği': 'Veterinary Clinic',
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
