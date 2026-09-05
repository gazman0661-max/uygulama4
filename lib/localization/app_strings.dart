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
    // === Hata Kayıtları ekranı (05.09.2026) ===
    'Hata Kayıtları': 'Error Logs',
    'Tümünü kopyala': 'Copy all',
    'Temizle': 'Clear',
    'Yenile': 'Refresh',
    'Kayıtlar kopyalandı': 'Logs copied',
    'Henüz kayıt yok. Bir proje oluştur/yayınla, sonra uygulamayı kapatmadan buraya dön.':
        'No logs yet. Create/publish a project, then come back here without closing the app.',
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
    // 05.09.2026 eklendi — kProductConnectDomain satın alma akışı.
    '1 yıllık, tek seferlik satın alma': 'One-time purchase, valid 1 year',
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
