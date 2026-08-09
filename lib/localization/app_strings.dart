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
/// AI ile veya Builder Pro ile üretilen web sitesi kodunun (HTML/CSS)
/// içindeki metinler kullanıcı içeriğidir ve KESİNLİKLE çevrilmez.
class AppStrings {
  AppStrings._();

  static const Map<String, String> en = <String, String>{
    // === Genel / Ortak butonlar ===
    'İptal': 'Cancel',
    'Vazgeç': 'Cancel',
    'Tamam': 'OK',
    'Tamam, Beklerim': 'OK, I\'ll Wait',
    'Evet, Sil': 'Yes, Delete',
    'Kaydet': 'Save',
    'Devam Et': 'Continue',
    'Kapat': 'Close',
    'Sil': 'Delete',
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
    '+5 puan eklendi! 🎬': '+5 points added! 🎬',
    '+5 Puan': '+5 Points',
    '🎬 Reklam İzle': '🎬 Watch Ad',

    // === Ayarlar (settings_sheet.dart) ===
    'API Ayarları': 'API Settings',
    'Gizlilik Politikası': 'Privacy Policy',
    'Kullanım Şartları': 'Terms of Service',

    // === Açılış Onay Popup'ı (legal_consent_popup.dart) ===
    'Devam Etmeden Önce': 'Before You Continue',
    'Sitora AI\'yı kullanmaya devam etmeden önce lütfen Gizlilik Politikası ve Kullanım Şartları\'nı okuyup onaylayın.':
        'Please read and accept the Privacy Policy and Terms of Service before continuing to use Sitora AI.',
    'Okudum, kabul ediyorum: ': 'I have read and accept the ',
    ' ve ': ' and ',
    'Kabul Ediyorum ve Devam Et': 'I Accept and Continue',

    // === Splash Ekranı (splash_screen.dart) ===
    'AI DESTEKLİ SİTE OLUŞTURUCU': 'AI-POWERED SITE BUILDER',
    'Sağlayıcı Seçimi:': 'Provider Selection:',
    'Gemini (Google)': 'Gemini (Google)',
    '🚀 Nasıl Gemini Key Alınır?': '🚀 How to Get a Gemini Key?',
    '1. Google AI Studio adr. git.': '1. Go to the Google AI Studio site.',
    '2. "Create API Key" butonuna bas.': '2. Tap the "Create API Key" button.',
    '3. Kopyaladığın keyi kutuya yapıştır.': '3. Paste the key you copied into the box.',
    'API Key...': 'API Key...',
    'Model Seçimi:': 'Model Selection:',
    'Model Seçiniz...': 'Select a Model...',
    'Modelleri Getir': 'Fetch Models',
    'Önce bir API anahtarı girmelisiniz.': 'You must enter an API key first.',
    'API anahtarı boş olamaz.': 'The API key cannot be empty.',
    'API anahtarınız kaydedildi! ✅': 'Your API key has been saved! ✅',
    "Key'i Sil": 'Delete Key',
    'API Anahtarı Gir': 'Enter API Key',

    // === Kullanım Kılavuzu (guide_dialog.dart) ===
    'Sitora AI Kullanım Kılavuzu': 'Sitora AI User Guide',
    '1. API Key Kurulumu (opsiyonel)': '1. API Key Setup (optional)',
    'Kendi Gemini API anahtarınızı girmek isterseniz sağ üstteki Ayarlar '
        '(⚙️) simgesine dokunun, sağlayıcıyı seçip linkten ücretsiz API Key '
        'alıp yapıştırın. Anahtar girerseniz kullanımınız sınırsız olur.':
        'If you\'d like to enter your own Gemini API key, tap the Settings '
            '(⚙️) icon at the top right, choose a provider, get a free API '
            'key from the link and paste it in. Entering a key makes your '
            'usage unlimited.',
    '2. Günlük Ücretsiz Puanlar': '2. Daily Free Points',
    'API anahtarı girmeseniz de her gün ücretsiz 15 puanla başlarsınız. '
        'Puanlarınız her gün UTC 00:00\'da 15\'e YENİLENİR (biriktirmez, gün '
        'içinde kullanmazsanız ertesi güne taşınmaz). 1 site oluşturma 5 '
        'puan, her AI düzenlemesi (tam kod, bölüm veya arkaplan) 2 puan '
        'düşer. Puanınız biterse "🎬 Reklam İzle" ile +5 puan kazanabilir ya '
        'da kendi API anahtarınızı girip sınırsız devam edebilirsiniz.':
        'Even without an API key, you start with 15 free points every day. '
            'Your points RESET to 15 every day at UTC 00:00 (they don\'t '
            'accumulate, and unused points don\'t carry over). Generating a '
            'site costs 5 points, and each AI edit (full code, section, or '
            'background) costs 2 points. If you run out, you can earn +5 '
            'points via "🎬 Watch Ad", or enter your own API key to continue '
            'without limits.',
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
    '5. Builder Pro (Sürükle-Bırak)': '5. Builder Pro (Drag & Drop)',
    'Üstteki tablardan \'BUILDER PRO\'ya geçerek; şablonlar, hazır '
        'bölümler, akıllı neon/glass CTA butonlar ve geometrik şekiller '
        'ekleyip sürükleyerek görsel tasarım yapın.':
        'Switch to \'BUILDER PRO\' from the tabs above; add templates, '
            'ready-made sections, smart neon/glass CTA buttons and '
            'geometric shapes and design visually by dragging them around.',
    '6. Özelleştirilebilir Şekiller': '6. Customizable Shapes',
    'Kare, daire, üçgen, yıldız, ampul, bulut veya kendi çizdiğiniz '
        'şekilleri ekleyin! İçine URL/Galeri görseli yerleştirin ve '
        'gidilecek linkleri ayarlayın.':
        'Add squares, circles, triangles, stars, or shapes you draw '
            'yourself! Place a URL/gallery image inside them and set the '
            'links they should open.',
    '7. İndirme & Kaydetme': '7. Download & Save',
    '\'İNDİR\' butonuna bastığınızda cihazınızın kayıt penceresi '
        'açılır; dosya adını değiştirebilir ve kaydedilecek konumu '
        'kendiniz seçebilirsiniz.':
        'When you tap the \'DOWNLOAD\' button, your device\'s save dialog '
            'opens; you can change the file name and choose where to save '
            'it yourself.',

    // === Kota / Limit popup'ları (quota_limit_popup.dart) ===
    'Bugünlük limitimiz doldu': 'We\'ve reached today\'s limit',
    'Ücretsiz günlük krediniz bitti. Puanlarınız UTC 00:00\'da yenilenecek.\n\n'
        'Beklemek istemiyorsanız kendi Gemini API anahtarınızı girerek '
        'sınırsız kullanmaya devam edebilirsiniz.':
        'Your free daily credit is used up. Your points will reset at UTC '
            '00:00.\n\nIf you don\'t want to wait, you can enter your own '
            'Gemini API key to keep using the app without limits.',
    'Sunucumuz şu an çok yoğun': 'Our server is very busy right now',
    'Çok fazla kullanıcı aynı anda istek attığı için Gemini geçici olarak '
        'yanıt vermiyor. Birkaç dakika sonra tekrar deneyebilirsiniz.\n\n'
        'Beklemek istemiyorsanız kendi Gemini API anahtarınızı girerek '
        'hemen devam edebilirsiniz.':
        'Because too many users are requesting at the same time, Gemini is '
            'temporarily not responding. You can try again in a few '
            'minutes.\n\nIf you don\'t want to wait, you can enter your own '
            'Gemini API key to continue right away.',

    // === Reklam bulunamadı (no_ad_popup.dart) ===
    'Reklam Bulunamadı': 'No Ad Available',
    'Şu anda gösterilecek bir reklam bulunamadı, bu yüzden puan '
        'eklenmedi.\n\nLütfen birkaç dakika sonra tekrar deneyin.':
        'No ad is available to show right now, so no points were added.\n\n'
            'Please try again in a few minutes.',

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

    // === Builder Pro genel ===
    'Şablonlar': 'Templates',
    '📑 Şablonlar': '📑 Templates',
    'Çizim': 'Drawing',
    'Bölümler': 'Sections',
    'Şekiller': 'Shapes',
    'Smart CTA': 'Smart CTA',
    'Yazı': 'Text',
    'Foto': 'Photo',
    'Arka Plan': 'Background',
    '🎨 Arka Plan Rengi': '🎨 Background Color',
    'Kare / Dikdörtgen': 'Square / Rectangle',
    'Daire': 'Circle',
    'Üçgen': 'Triangle',
    'Yıldız': 'Star',
    'Kahraman Bölüm (başlık + CTA)': 'Hero Section (title + CTA)',
    'İletişim Bölümü (WA + IG)': 'Contact Section (WA + IG)',
    'Başlığını buraya yaz': 'Write your title here',
    'Kısa bir alt açıklama ekle': 'Add a short subtitle',
    'Hemen Başla': 'Get Started',
    'Bize Ulaş': 'Contact Us',
    'Hemen İncele': 'Check It Out',
    'Yeni metin': 'New text',
    'Geri': 'Back',
    'İleri': 'Forward',
    'Izgara': 'Grid',
    'Canvas zaten boş.': 'The canvas is already empty.',
    'Geri alınacak bir değişiklik yok.': 'There is no change to undo.',
    'İleri alınacak bir değişiklik yok.': 'There is no change to redo.',
    'Tasarımı Sil': 'Delete Design',
    'Canvas üzerindeki tüm elemanlar silinecek. Bu işlem geri alınamaz. '
        'Silmek istediğinizden emin misiniz?':
        'All elements on the canvas will be deleted. This action cannot be '
            'undone. Are you sure you want to delete it?',
    'Tasarım silindi.': 'Design deleted.',
    'Canvas boş — önce bir şablon seçiniz ya da eleman ekleyiniz.':
        'The canvas is empty — please choose a template or add an element first.',
    'Canvas hazır.\nAlt taraftaki araçlarla\nsitenizi tasarlamaya başlayabilirsiniz.':
        'Canvas is ready.\nYou can start designing your site\nwith the tools below.',
    'Görsel alanı — 🖼️ ile fotoğraf ekle': 'Image area — add a photo with 🖼️',

    // === Şablon (properties panel) ===
    'Metin': 'Text',
    'Yazı Boyutu': 'Font Size',
    'Kalın': 'Bold',
    'Fotoğraf Değiştir': 'Change Photo',
    'Köşe Yuvarlaklığı': 'Corner Roundness',
    'Şekle Foto Ekle': 'Add Photo to Shape',
    'Fotoğrafı Kaldır': 'Remove Photo',
    'Dolgu Rengi': 'Fill Color',
    'Telefon numarası girilmedi': 'No phone number entered',
    'Bağlantı (instagram.com/, tiktok.com/... vb.)':
        'Link (instagram.com/, tiktok.com/... etc.)',
    'Buton Yazısı': 'Button Text',
    'Bağlantı (https:// veya https://wa.me/...)':
        'Link (https:// or https://wa.me/...)',
    'Buton Rengi': 'Button Color',

    // === Çizim aracı (drawing_pad_dialog.dart) ===
    'Renk seçin': 'Choose a color',
    'Seçilen renk': 'Selected color',
    'Kendi Şeklini Çiz': 'Draw Your Own Shape',
    '🖌️ Silgi': '🖌️ Eraser',
    '✏️ Kalem': '✏️ Pen',
    'Kalem Boyutu:': 'Pen Size:',

    // === Şablon verileri (BuilderTemplate) ===
    'Kafe & Restoran': 'Cafe & Restaurant',
    'Yeme-İçme': 'Food & Drink',
    'Menü, konum ve rezervasyon butonu odaklı sıcak tonlu tasarım.':
        'A warm-toned design focused on the menu, location, and a '
            'reservation button.',
    'Rezervasyon Yap': 'Make a Reservation',
    'Kuaför & Güzellik Salonu': 'Hair & Beauty Salon',
    'Güzellik': 'Beauty',
    'Hizmet listesi, galeri ve WhatsApp\'tan randevu akışı.':
        'A service list, gallery, and a WhatsApp booking flow.',
    'Randevu Al': 'Book an Appointment',
    'Emlak Ofisi': 'Real Estate Office',
    'Emlak': 'Real Estate',
    'İlan kartları, harita ve iletişim formu düzeni.':
        'A layout with listing cards, a map, and a contact form.',
    'İlanları Gör': 'View Listings',
    'Spor Salonu / Fitness': 'Gym / Fitness',
    'Spor & Sağlık': 'Sports & Health',
    'Üyelik paketleri, program tanıtımı ve enerjik koyu tema.':
        'Membership packages, a program overview, and an energetic dark theme.',
    'Üye Ol': 'Sign Up',
    'E-ticaret / Butik': 'E-commerce / Boutique',
    'Satış': 'Sales',
    'Ürün vitrini, kampanya bandı ve sepete/WhatsApp\'a yönlendirme.':
        'A product showcase, a promo banner, and links to cart/WhatsApp.',
    'Alışverişe Başla': 'Start Shopping',
    'Diş / Estetik Kliniği': 'Dental / Aesthetic Clinic',
    'Sağlık': 'Health',
    'Güven veren mavi-beyaz palet, hizmetler ve online randevu.':
        'A reassuring blue-and-white palette, services, and online booking.',
    'Online Randevu': 'Book Online',
    'Düğün & Etkinlik': 'Wedding & Event',
    'Etkinlik': 'Event',
    'Davetiye tarzı zarif tipografi, geri sayım ve konum bilgisi.':
        'Elegant invitation-style typography, a countdown, and location info.',
    'Detayları Gör': 'View Details',
    'Kişisel Portfolyo / CV': 'Personal Portfolio / CV',
    'Portfolyo': 'Portfolio',
    'Proje vitrini, yetenekler ve sosyal medya bağlantıları.':
        'A project showcase, skills, and social media links.',
    'Projelerimi Gör': 'View My Projects',
    'Mobil Uygulama Tanıtımı': 'Mobile App Showcase',
    'App Landing': 'App Landing',
    'Ekran görüntüleri, özellik listesi ve Play Store/App Store CTA.':
        'Screenshots, a feature list, and a Play Store/App Store CTA.',
    'Uygulamayı İndir': 'Download the App',
    'Kurumsal / Ajans': 'Corporate / Agency',
    'Kurumsal': 'Corporate',
    'Hizmet alanları, referanslar ve iletişim odaklı ciddi düzen.':
        'A professional layout focused on service areas, references, and contact.',
    'Bize Ulaşın': 'Contact Us',
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
