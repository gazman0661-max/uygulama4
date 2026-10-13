/// 05.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği).
///
/// Üretilen sitedeki PREMİUM'a özel bölümleri (şimdilik: harita, talep
/// formu) merkezi olarak temizleyen servis.
///
/// NEDEN MERKEZİ (bkz. WatermarkService — AYNI GEREKÇE): site içeriği 10
/// farklı sektör generator'ından (bkz. lib/templates/html/) gelebiliyor —
/// her birine ayrı ayrı "eğer free ise ekleme" mantığı eklemek yerine, TEK
/// bir yerden (bkz. AppState.updateQtGeneratedCode/updateQtGeneratedFiles/
/// updateQtActiveFileContent — WatermarkService.apply ile AYNI noktalar)
/// üretilmiş HTML üzerinde regex ile temizlik yapılıyor.
///
/// WatermarkService'ten YÖN FARKI: rozet HTML'e SONRADAN "ekleniyor", bu
/// servis generator'ın ZATEN ürettiği bölümleri HTML'den "çıkarıyor" —
/// yön ters ama merkezi-tek-nokta mantığı aynı.
///
/// 05.09.2026 değişti (kanka isteği, devamı) — TALEP FORMU artık bu servisin
/// regex'iyle ÇIKTIDA temizlenmiyor, [isPremiumGeneration] flag'i üzerinden
/// ÜRETİM ANINDA (site üretme aşamasında) hiç yazılmıyor — tıpkı haritanın
/// [LocationPickerField] ile GİRİŞTE kilitlenmesi gibi (bkz. o widget'ın
/// dokümanı). Kanka'nın gerekçesi: talep formu için watermark'la AYNI
/// (çıktı-sonrası) yöntemi kullanmak "olmaz" — form doldurma/site üretme
/// aşamasında kilitli olmalı. Aşağıdaki [_stripLeadForm] artık sadece bu
/// değişiklikten ÖNCE kaydedilmiş eski projeler için bir GÜVENLİK AĞI
/// (harita için zaten var olan safety net ile AYNI gerekçe) — normal akışta
/// hiç tetiklenmemesi beklenir.
class FreePlanRestrictionService {
  FreePlanRestrictionService._();

  /// [LocalGenerationHelper.generateSinglePage]/[generateMultiPage],
  /// buildHtml()/buildFiles() ÇAĞRILMADAN HEMEN ÖNCE appState.
  /// qtCurrentIsPremium'a göre bu flag'i günceller (ve işlem bitince TEKRAR
  /// `true`'ya döner — bkz. o dosyadaki finally bloğu). [contactBlockHtml]
  /// (shared_html_blocks.dart) HTML üretirken bunu okur; `false` ise talep
  /// formu (leadFormMarkup) HİÇ YAZILMAZ. Varsayılan `true` — demo şablon
  /// önizlemeleri (demo_templates.dart) LocalGenerationHelper'dan GEÇMEDİĞİ
  /// için bu flag'e hiç dokunmaz, dolayısıyla her zaman tam özellikli
  /// görünür (zaten amaçlanan budur: demo, satış/tanıtım amaçlı).
  ///
  /// 06.09.2026 DÜZELTİLDİ (kanka bulgusu — kod incelemesi): bu alan artık
  /// DIŞARIDAN doğrudan set EDİLMEMELİ — bkz. aşağıdaki [runGeneration].
  /// Eskiden LocalGenerationHelper bunu elle "set et → buildHtml()/buildFiles()
  /// çağır → sabit olarak `true`'ya geri döndür" şeklinde yönetiyordu. Bunun
  /// İKİ sorunu vardı: (1) hata/istisna [buildHtml] İÇİNDE değil de
  /// LocalGenerationHelper'ın try/catch'inde yakalanırsa (ör. context.mounted
  /// kontrolünden önce) reset satırına hiç gelinmeden flag yanlış değerde
  /// kalabiliyordu — finally bloğu bunu telafi ediyordu ama YİNE DE değeri
  /// `true` diye SABİT bir değere zorluyordu; (2) bir yerde bu flag zaten
  /// `false` iken (varsayımsal, ileride eklenebilecek iç içe/nested bir
  /// üretim akışında) bu kod çalışırsa, bitişte SABİT `true`'ya dönmesi
  /// dıştaki çağıranın kendi ayarladığı değeri sessizce EZERDİ. [runGeneration]
  /// bunun yerine ÖNCEKİ değeri kaydedip İŞ BİTİNCE (hata olsa bile) TAM O
  /// DEĞERE geri döner — "sabit true" varsayımı yerine doğru save/restore.
  static bool isPremiumGeneration = true;

  /// Şu an bir [runGeneration] çağrısı sürüyor mu — bu SENKRON, iç içe
  /// GEÇMEMESİ beklenen bir akış (bkz. LocalGenerationHelper dokümanı:
  /// "buildHtml() SENKRON çalıştığı için..."). Bu bayrak, o varsayımı ihlal
  /// eden bir durum (aynı anda/iç içe iki üretim) olursa SESSİZCE state
  /// karışıklığına yol açmak yerine erkenden (assert ile, debug modda)
  /// haber vermek için var — production'da assert devre dışı olduğundan
  /// uygulamayı çökertmez, sadece debug'da geliştiriciyi uyarır.
  static bool _generationInProgress = false;

  /// [isPremium] değerini [isPremiumGeneration]'a yazıp [body]'yi (senkron
  /// `buildHtml`/`buildFiles` çağrısını) çalıştırır; [body] normal bitse de
  /// istisna fırlatsa da flag'i ÇAĞRIDAN ÖNCEKİ değerine geri yükler (sabit
  /// `true` DEĞİL — bkz. yukarıdaki [isPremiumGeneration] dokümanı).
  /// [LocalGenerationHelper.generateSinglePage]/[generateMultiPage] artık
  /// flag'i elle set/reset etmek yerine bunu çağırmalı.
  static T runGeneration<T>(bool isPremium, T Function() body) {
    assert(
      !_generationInProgress,
      'FreePlanRestrictionService.runGeneration iç içe çağrıldı — '
      'isPremiumGeneration flag\'i senkron/tek-akış varsayımıyla tasarlandı, '
      'bu varsayım burada ihlal edildi.',
    );
    final previous = isPremiumGeneration;
    _generationInProgress = true;
    isPremiumGeneration = isPremium;
    try {
      return body();
    } finally {
      isPremiumGeneration = previous;
      _generationInProgress = false;
    }
  }

  /// [html] premium değilse haritayı ve talep formunu çıkarır; premium ise
  /// dokunmadan aynen döner.
  ///
  /// 05.09.2026 itibarıyla talep formu normal akışta ZATEN üretilmiyor
  /// (bkz. [isPremiumGeneration]) — [_stripLeadForm] burada sadece bu
  /// değişiklikten ÖNCE kaydedilmiş projeler tekrar işlenirse diye bir
  /// güvenlik ağı olarak çağrılmaya devam ediyor.
  static String strip(String html, {required bool isPremium}) {
    if (isPremium) return html;
    var out = _stripSection(html, 'map-section');
    out = _stripLeadForm(out);
    return out;
  }

  /// Çok sayfa (B modu) projeler için — tüm `.html` dosyalarına uygulanır,
  /// diğer dosya türlerine (css/js/json vb.) dokunulmaz.
  static Map<String, String> stripFromFiles(
    Map<String, String> files, {
    required bool isPremium,
  }) {
    if (isPremium) return files;
    return files.map((name, content) {
      if (!name.toLowerCase().endsWith('.html')) return MapEntry(name, content);
      return MapEntry(name, strip(content, isPremium: isPremium));
    });
  }

  /// [shared_html_blocks.dart] > `leadFormMarkup` çıktısı her zaman
  /// `<form id="sitora-lead-form" ...>` ile başlayıp hemen ardından gelen
  /// tek bir `<script>...</script>` bloğuyla biter — ikisi birlikte TEK bir
  /// parça olarak kaldırılır (form'suz kalan bir script anlamsız/hataya
  /// açık olurdu). Marker (`sitora-lead-form`) leadFormMarkup dışında
  /// KULLANILMADIĞI için global bir replaceAll güvenli.
  static final RegExp _leadFormRe = RegExp(
    r'<form id="sitora-lead-form".*?</script>',
    dotAll: true,
  );

  static String _stripLeadForm(String html) => html.replaceAll(_leadFormRe, '');

  /// `<section class="section $sectionClass">...</section>` bloğunu
  /// bütünüyle kaldırır. mapBlockHtml içeriğinde İÇ İÇE `<section>` OLMADIĞI
  /// için lazy (`.*?`) eşleşme kendi kapanışını doğru yakalar.
  static String _stripSection(String html, String sectionClass) {
    final re = RegExp(
      '<section class="section $sectionClass">.*?</section>',
      dotAll: true,
    );
    return html.replaceAll(re, '');
  }
}
