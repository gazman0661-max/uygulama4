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
/// AI ile üretilen web sitesi kodunun (HTML/CSS) içindeki metinler
/// kullanıcı içeriğidir ve KESİNLİKLE çevrilmez.
class AppStrings {
  AppStrings._();

  static const Map<String, String> en = <String, String>{
    // === Genel / Ortak butonlar ===
    'İptal': 'Cancel',
    'Vazgeç': 'Cancel',
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

    // === Ana Sohbet Ekranı (home_screen.dart) ===
    'Hayalindeki Siteyi Anlat...': 'Describe the site of your dreams...',
    'Kılavuz': 'Guide',
    'Çok Sayfa': 'Multi-Page',
    'Tek Sayfa': 'Single Page',
    'Bağlantılı sayfalar — ZIP indir': 'Linked pages — download as ZIP',
    'Biolink / kartvizit — HTML indir': 'Biolink / business card — download HTML',
    'ÖN İZLEME': 'PREVIEW',
    'Puan Ver': 'Rate Us',
    'Siteniz oluşturuluyor... ⏳': 'Your site is being generated... ⏳',
    'Siteniz hazır! 🚀 DÜZENLE\'den kodu görebilir, ÖN İZLEME\'den siteyi canlı izleyebilirsiniz.':
        'Your site is ready! 🚀 You can view the code from EDIT, or see the live site from PREVIEW.',
    'Silinecek bir şey yok.': 'There is nothing to delete.',
    'Sohbeti ve Siteyi Sil': 'Delete Chat and Site',
    'Sohbet geçmişi ve üretilmiş site silinecek. Bu işlem geri '
        'alınamaz. Silmek istediğinizden emin misiniz?':
        'Your chat history and generated site will be deleted. This action '
            'cannot be undone. Are you sure you want to delete it?',
    'Önce sohbetten bir site oluşturmanız gerekiyor.':
        'You need to generate a site from the chat first.',
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
        'çok sayfalı site 10 puan düşer. Bu akışta AI kullanılmaz, '
        'düzenleme seçeneği yoktur.':
        'You get 15 free points every month for generating sites via the '
            'form. These points RESET to 15 on the 1st of every month '
            '(they don\'t accumulate, and unused points don\'t carry over). '
            'A single-page site costs 5 points, a multi-page site costs 10 '
            'points. This flow doesn\'t use AI and has no editing option.',
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

    '4. İndirme & Kaydetme': '4. Download & Save',
    '\'İNDİR\' butonuna bastığınızda cihazınızın kayıt penceresi '
        'açılır; dosya adını değiştirebilir ve kaydedilecek konumu '
        'kendiniz seçebilirsiniz.':
        'Tapping \'DOWNLOAD\' opens your device\'s save dialog; you can '
            'rename the file and choose where to save it yourself.',

    '2. AI Chat ile Ücretsiz Puanlar': '2. Free Points via AI Chat',
    'Yapay zekayla sohbet ederek site üretmek/düzenlemek için ayrı '
        'bir ayda ücretsiz 20 puanınız var (form puanlarınızı etkilemez). '
        'Bu puanlar da her ayın 1\'inde 20\'ye yenilenir. Tek sayfa site '
        '5 puan, çok sayfalı site 10 puan, her AI düzenlemesi (tam kod, '
        'bölüm veya arkaplan) 2 puan düşer.':
        'You get a separate 20 free points every month for generating/'
            'editing sites via AI chat (doesn\'t affect your form points). '
            'These also reset to 20 on the 1st of every month. A '
            'single-page site costs 5 points, a multi-page site costs 10 '
            'points, and each AI edit (full code, section, or background) '
            'costs 2 points.',
    '3. Sitenizi Hayal Edin': '3. Imagine Your Site',
    'Yapay zekaya nasıl bir site istediğinizi anlatın. Dilerseniz '
        'galeriden görseller ekleyerek tasarıma dahil edebilirsiniz.':
        'Tell the AI what kind of site you want. If you\'d like, you can '
            'add images from your gallery to include in the design.',
    '4. Düzenleme & Önizleme': '4. Edit & Preview',
    'Üretilen sitenin kodunu \'DÜZENLE\' butonuyla canlı CodeMirror '
        'editöründe değiştirebilir veya \'ÖN İZLEME\' ile anında test '
        'edebilirsiniz.':
        'You can change the generated site\'s code live in the CodeMirror '
            'editor via the \'EDIT\' button, or test it instantly via '
            '\'PREVIEW\'.',
    '5. İndirme & Kaydetme': '5. Download & Save',
    '\'İNDİR\' butonuna bastığınızda cihazınızın kayıt penceresi '
        'açılır; dosya adını değiştirebilir ve kaydedilecek konumu '
        'kendiniz seçebilirsiniz.':
        'When you tap the \'DOWNLOAD\' button, your device\'s save dialog '
            'opens; you can change the file name and choose where to save '
            'it yourself.',

    // === Örnekler galerisi (examples_gallery_dialog.dart) ===
    'Örnekler': 'Examples',
    'Bir örneğe dokunun, sohbet kutusuna yazılsın — dilerseniz '
        'göndermeden önce düzenleyebilirsiniz.':
        'Tap an example to fill the chat box — you can edit it before '
            'sending if you\'d like.',
    'Kafe / Kahveci': 'Café / Coffee Shop',
    'Kadıköy\'de sıcak, samimi bir üçüncü nesil kahveci için tek sayfalık bir '
        'web sitesi oluştur. Menü bölümü (filtre kahve, espresso bazlı içecekler, '
        'tatlılar), açılış saatleri, konum ve Instagram linki olsun. Sıcak, kahverengi '
        've krem tonlarında, ahşap dokulu bir tasarım istiyorum.':
        'Create a one-page website for a warm, cozy third-wave coffee shop. '
            'Include a menu section (filter coffee, espresso drinks, desserts), '
            'opening hours, location and an Instagram link. I want a warm, '
            'brown-and-cream, wood-textured design.',
    'Kuaför / Berber': 'Hair Salon / Barber',
    'Erkek berber salonu için modern, koyu temalı (siyah-altın) bir tek sayfa site '
        'yap. Hizmetler ve fiyat listesi (saç kesimi, sakal tıraşı, cilt bakımı), '
        'WhatsApp\'tan randevu butonu, önce-sonra galeri bölümü olsun.':
        'Make a modern, dark-themed (black-and-gold) one-page site for a men\'s '
            'barbershop. Include a services and price list (haircut, beard trim, '
            'skincare), a WhatsApp booking button, and a before/after gallery '
            'section.',
    'Spor Salonu': 'Gym',
    'Enerjik, motivasyon veren bir fitness/spor salonu web sitesi oluştur. '
        'Üyelik paketleri (aylık/yıllık), eğitmen kadrosu, salon fotoğraf galerisi '
        've "Ücretsiz Deneme Dersi" için WhatsApp CTA butonu olsun. Kırmızı-siyah, '
        'güçlü kontrastlı bir tasarım istiyorum.':
        'Create an energetic, motivating fitness/gym website. Include '
            'membership packages (monthly/yearly), the trainer lineup, a photo '
            'gallery of the gym, and a WhatsApp CTA button for a "Free Trial '
            'Class". I want a red-and-black, high-contrast design.',
    'Emlak Danışmanı': 'Real Estate Agent',
    'Bireysel bir emlak danışmanı için güven veren, kurumsal bir tanıtım sitesi '
        'yap. Hakkımda bölümü, hizmet verdiğim bölgeler, iletişim ve WhatsApp\'tan '
        'hızlı ulaşım butonu olsun. Lacivert-beyaz, sade ve profesyonel bir tasarım.':
        'Make a trustworthy, corporate profile site for an independent real '
            'estate agent. Include an about section, the areas I serve, contact '
            'info, and a quick WhatsApp button. A navy-and-white, clean and '
            'professional design.',
    'Portföy / Serbest Çalışan': 'Portfolio / Freelancer',
    'Bir grafik tasarımcının kişisel portföy sitesini oluştur. Kısa bir hakkımda '
        'yazısı, öne çıkan proje kartları (görsel + başlık), kullandığım yazılımlar '
        've iletişim bölümü olsun. Minimal, beyaz zeminli, tipografi odaklı bir tasarım.':
        'Create a personal portfolio site for a graphic designer. Include a '
            'short about section, featured project cards (image + title), the '
            'software I use, and a contact section. A minimal, white-background, '
            'typography-focused design.',
    'Restoran': 'Restaurant',
    'Aile işletmesi bir restoran için sıcak ve davetkar bir web sitesi oluştur. '
        'Kategorilere ayrılmış menü (başlangıçlar, ana yemekler, tatlılar, içecekler), '
        'rezervasyon için telefon/WhatsApp butonu ve konum haritası olsun.':
        'Create a warm and inviting website for a family-owned restaurant. '
            'Include a categorized menu (starters, mains, desserts, drinks), a '
            'phone/WhatsApp button for reservations, and a location map.',

    // === Kota / Limit popup'ları (quota_limit_popup.dart) ===
    'Bu ayki limitiniz doldu': 'We\'ve reached this month\'s limit',
    'Ücretsiz aylık krediniz bitti. Puanlarınız her ayın 1\'inde yenilenecek.':
        'Your free monthly credit is used up. Your points will reset on the 1st of next month.',
    'Sunucumuz şu an çok yoğun': 'Our server is very busy right now',
    'Çok fazla kullanıcı aynı anda istek attığı için Gemini geçici olarak '
        'yanıt vermiyor. Birkaç dakika sonra tekrar deneyebilirsiniz.':
        'Because too many users are requesting at the same time, Gemini is '
            'temporarily not responding. You can try again in a few minutes.',

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
    'Hatalı / bozuk AI çıktısı': 'Faulty / broken AI output',
    'Diğer': 'Other',

    // === AI düzenleme kartı (ai_edit_dialog.dart) ===
    'Gönder ✨': 'Send ✨',
    'AI Kod Düzenleyici': 'AI Code Editor',
    'AI Bölüm Düzenleyici': 'AI Section Editor',
    'AI Arka Plan Düzenleyici': 'AI Background Editor',
    'Bu bölümden ne değiştirmek istersin? Örn: başlığı değiştir, butonun rengini kırmızı yap.':
        'What would you like to change in this section? E.g.: change the '
            'title, make the button red.',
    'Sayfanın arka planı için ne istersin? (Örn: koyu mor gradient, animasyonlu neon vb.)':
        'What would you like for the page background? (E.g.: a dark purple '
            'gradient, animated neon, etc.)',
    'Örn: Bu bölümün arka planını mor yap, başlığı büyüt...':
        'E.g.: Make this section\'s background purple, enlarge the title...',
    "Kodda ne değiştirmek veya eklemek istersiniz? Örn: 'Bu butonun rengini kırmızı yap' "
        "gibi kısa bir cümle yazın.":
        "What would you like to change or add in the code? Write a short "
            "sentence like 'make this button red'.",

    // === Edit ekranı (edit_screen.dart) ===
    'Görsel Ekle': 'Add Image',
    '.html / .txt Dosyası Aç': 'Open .html / .txt File',
    'Etiket denetimi temiz': 'Tag check is clean',
    '✨ AI kodu düzenliyor...': '✨ AI is editing the code...',
    'Görsel eklendi.': 'Image added.',
    'AI değişikliği uyguladı!': 'AI applied the change!',

    // === Önizleme ekranı (preview_screen.dart) ===
    'Ön İzleme': 'Preview',
    '✨ AI düzenliyor...': '✨ AI is editing...',
    'Fotoğraf güncellendi! 🖼️': 'Photo updated! 🖼️',
    'Bölüm güncellendi!': 'Section updated!',
    'Arkaplan güncellendi!': 'Background updated!',
    'Henüz üretilmiş bir site yok. Önce sohbetten bir istek gönderiniz.':
        'No site generated yet. Please send a request from the chat first.',

    // === Ortak (form ekranlarında da kullanılır) ===
    'Randevu Al': 'Book an Appointment',
    'Emlak': 'Real Estate',
    'Portfolyo': 'Portfolio',

    // === Projelerim ===
    'Projelerim': 'My Projects',
    'Henüz bir projen yok.': 'You don\'t have any projects yet.',
    'Sohbetten bir site oluşturduğunda burada listelenecek.':
        'Once you generate a site from chat, it will be listed here.',
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
    'AI': 'AI',
    'AI SOHBET': 'AI CHAT',
    'AI ile Sohbet Ederek Oluştur': 'Create by Chatting with AI',
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
    'İstediğini yaz, AI senin için siteyi tasarlasın.': 'Write what you want, let AI design the site for you.',
    'İsveç Masajı - 60 dk - 600 TL\nAromaterapi - 90 dk - 900 TL': 'Swedish Massage - 60 min - 600 TL\nAromatherapy - 90 min - 900 TL',
    'İç-Dış Yıkama - 30 dk - 250 TL\nSeramik Kaplama - 1500 TL': 'Interior-Exterior Wash - 30 min - 250 TL\nCeramic Coating - 1500 TL',
    'İş Örnekleri': 'Work Samples',
    'İşletme adı': 'Business name',
    'İşletme adı ve telefon gerekli.': 'Business name and phone are required.',
    'Şirket (opsiyonel)': 'Company (optional)',
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
