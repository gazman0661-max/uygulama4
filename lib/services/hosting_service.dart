import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'analytics_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// SITORA HOSTING — Cloudflare Workers + R2 + D1 üzerinde çalışacak
/// "1 tık yayınla, ücretsiz alt alan adı al" özelliğinin Flutter tarafı.
///
/// NEDEN KV DEĞİL DE D1?
/// Workers KV free tier günde SADECE 1.000 yazma işlemine izin veriyor
/// (100.000 okuma serbest). Alt alan adı -> dosya eşlemesini KV'de tutarsak
/// günlük yayın limiti sert şekilde 1.000'de kilitlenir.
/// D1 free tier ise AYLIK 100.000 satır yazmaya izin veriyor — bu da günlük
/// ortalama ~3.300 yeni yayın demek (KV'nin ~3.3 katı), üstelik R2 (10 GB
/// depolama, ayda 1.000.000 yazma / 10.000.000 okuma) ve Worker'ın kendisi
/// (100.000 istek/gün) bunun çok üstünde limitlere sahip, yani gerçek
/// darboğaz D1'in aylık 100K yazma limiti oluyor — mevcut en yüksek/ücretsiz
/// kombinasyon bu.
///
/// Worker + D1 şeması + wrangler.toml deploy edilmeye hazır halde
/// `cloudflare/worker/` klasöründe duruyor. O taraf canlıya alınıp gerçek
/// URL elimize geçtiğinde tek yapılacak şey aşağıdaki [HostingConfig.baseUrl]
/// alanını doldurmak — başka HİÇBİR yeri değiştirmeye gerek yok.
/// ============================================================================

/// Worker canlıya alınınca burayı doldur. DOMAIN'SİZ MOD'da (domain
/// alınmadan) bu, wrangler deploy çıktısındaki workers.dev adresi olacak,
/// örn: 'https://sitora-hosting.<hesap>.workers.dev'. Siteler bu durumda
/// alt alan adı değil path ile yayınlanır: <baseUrl>/s/<slug>/. İleride
/// domain alınırsa (bkz. cloudflare/worker) burası kendi domain'inle
/// değiştirilir, kod tarafında başka hiçbir yer değişmez.
class HostingConfig {
  /// KASITLI OLARAK BOŞ. Worker hazır olmadan bu servis çağrılırsa
  /// [HostingNotConfiguredException] fırlatır, uygulamanın geri kalanını
  /// bozmaz — sadece "Yayınla" butonu kullanıcıya net bir mesaj gösterir.
  static const String baseUrl = 'https://sitora-hosting.sitora2026.workers.dev';

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}

class HostingNotConfiguredException implements Exception {
  final String message =
      'Hosting henüz aktif değil. Worker/D1 tarafı yayına alınınca bu özellik otomatik açılacak.';
  @override
  String toString() => message;
}

class HostingException implements Exception {
  final String message;
  HostingException(this.message);
  @override
  String toString() => message;
}

class PublishResult {
  final String siteId;
  final String subdomain;
  final String url;
  /// GÜVENLİK (2026-09-01 eklendi): worker bu siteId için SADECE İLK
  /// publish'te (site D1'de henüz yoksa) yeni bir sahiplik token'ı üretip
  /// burada döner — çağıran taraf (AppState) bunu SiteProject.ownerToken'a
  /// yazıp kalıcı saklamalı (bkz. worker > handlePublish). Sonraki
  /// republish/unpublish çağrılarında worker artık yeni bir token DÖNMEZ
  /// (null gelir) — o zaman SiteProject'te zaten saklı olan değer korunur.
  final String? ownerToken;
  PublishResult({
    required this.siteId,
    required this.subdomain,
    required this.url,
    this.ownerToken,
  });

  factory PublishResult.fromJson(Map<String, dynamic> json) => PublishResult(
        siteId: json['siteId'] as String,
        subdomain: json['subdomain'] as String,
        url: json['url'] as String,
        ownerToken: json['ownerToken'] as String?,
      );
}

/// GET /api/sites/:id/stats (ve toplu /api/sites/stats) yanıtı — bkz.
/// HostingService.fetchStats / fetchStatsBatch.
class SiteStats {
  final String siteId;
  final int visitCount;
  /// Bugün (worker'ın UTC gününe göre) atılan ziyaret sayısı — bkz.
  /// cloudflare/worker/schema.sql > site_daily_visits. Toplu uç nokta
  /// `createdAt` döndürmediği için o alan orada her zaman null gelir.
  final int todayVisitCount;
  /// Bu ayın başından bugüne toplam ziyaret (bkz. worker >
  /// handleStats/handleStatsBatch > monthly sorgusu) — FOMO mesajı için
  /// (bkz. projects_screen.dart > _buildFomoLine). Eski (deploy edilmemiş)
  /// worker sürümünde bu alan JSON'da yoksa sessizce 0 gelir, arayüz o
  /// durumda toplam sayaca geri döner.
  final int monthlyVisitCount;
  final DateTime? lastVisitAt;
  final DateTime? createdAt;
  SiteStats({
    required this.siteId,
    required this.visitCount,
    this.todayVisitCount = 0,
    this.monthlyVisitCount = 0,
    this.lastVisitAt,
    this.createdAt,
  });

  factory SiteStats.fromJson(Map<String, dynamic> json) => SiteStats(
        siteId: json['siteId'] as String,
        visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
        todayVisitCount: (json['todayVisitCount'] as num?)?.toInt() ?? 0,
        monthlyVisitCount: (json['monthlyVisitCount'] as num?)?.toInt() ?? 0,
        lastVisitAt: json['lastVisitAt'] != null
            ? DateTime.tryParse(json['lastVisitAt'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

class HostingService {
  /// Çoklu sayfa (B modu) veya tek dosya (A modu) fark etmeksizin,
  /// [files] map'i (yol -> içerik) Worker'ın /api/publish uç noktasına
  /// gönderilir. Worker bunları R2'ye yazar + D1'de subdomain -> site
  /// eşlemesini oluşturur (bkz. cloudflare/worker/schema.sql).
  ///
  /// [desiredSubdomain] kullanıcının seçtiği alt alan adı/slug (örn.
  /// "kuaförüm" -> DOMAIN'Sİz MOD'da <baseUrl>/s/kuaforum/, domain alınınca
  /// kuaforum.sitora.app). Worker müsaitlik kontrolü yapıp gerekirse
  /// sonuna sayı ekleyerek benzersizleştirir, gerçek sonucu döner.
  ///
  /// Yayınlanan HER sitenin index.html'ine, kaldırma talebi için
  /// [reportWidgetSnippet] otomatik olarak eklenir (bkz. aşağı).
  /// [ownerEmail] OPSİYONEL: verilirse D1'deki `sites.owner_email` alanına
  /// yazılır. Bir admin bu siteyi bir şikayet üzerine kapatırsa, worker
  /// (RESEND_API_KEY tanımlıysa) buraya otomatik bilgilendirme e-postası
  /// gönderir — bkz. cloudflare/worker/src/index.mjs > sendOwnerDisabledEmail.
  /// Boş bırakılırsa site yine yayınlanır, sadece kaldırma bildirimi gitmez.
  /// Var olan bir siteyi e-postasız tekrar yayınlarsan önceki e-posta KORUNUR.
  /// [ownerUid] OPSİYONEL: verilirse, üretilen HER .html sayfaya "Gelen
  /// Talepler" (lead) formunun ihtiyaç duyduğu `window.__SITORA_LEAD__`
  /// konfigürasyonu enjekte edilir (bkz. [_injectLeadConfig] ve
  /// templates/html/shared_html_blocks.dart > leadFormMarkup). Boş
  /// bırakılırsa site yine yayınlanır, sadece iletişim formundaki
  /// "Talep Gönder" gönderilemez hatası verir (telefon/WhatsApp butonları
  /// etkilenmez). Çağıran taraf (widgets/publish_sheet.dart) bunu
  /// AuthService.instance.currentUser?.uid ile dolduruyor — yayınlama
  /// zaten giriş gerektirdiği için (bkz. login_gate.dart) bu değer PRATİKTE
  /// her zaman mevcuttur.
  static Future<PublishResult> publish({
    required Map<String, String> files,
    required String desiredSubdomain,
    required String siteId,
    String? ownerEmail,
    String? ownerUid,
    String siteName = '',
    // GÜVENLİK (2026-09-01 eklendi): bu proje daha önce yayınlanıp bir
    // ownerToken kazandıysa (SiteProject.ownerToken) buraya geçilmeli —
    // worker, bu siteId zaten kayıtlıysa gelen token'ın eşleştiğini
    // doğrular (bkz. handlePublish). null geçilirse (ilk yayın VEYA eski/
    // henüz token'sız bir proje) worker duruma göre ya yeni token üretir
    // ya da (site zaten var ve DB'de token'sızsa) geriye dönük uyumluluk
    // için tek seferlik izin verir.
    String? ownerToken,
  }) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();

    final processedFiles = Map<String, String>.from(files);

    // Şikayet widget'ı sadece ana sayfaya (index.html, yoksa ilk .html)
    // eklenir — ziyaretçinin siteyi ilk gördüğü sayfa yeterli.
    final indexKey = processedFiles.containsKey('index.html')
        ? 'index.html'
        : processedFiles.keys.firstWhere(
            (k) => k.toLowerCase().endsWith('.html'),
            orElse: () => '',
          );
    if (indexKey.isNotEmpty) {
      processedFiles[indexKey] = _injectReportWidget(
        html: processedFiles[indexKey]!,
        siteId: siteId,
      );
    }

    // Ziyaretçi sayacı İSE tüm .html sayfalara eklenir (çok sayfalı bir
    // sitede sadece index'e girenler değil, urunler.html/listing_x.html
    // gibi diğer sayfalara girenler de sayılmalı).
    for (final key in processedFiles.keys.toList()) {
      if (!key.toLowerCase().endsWith('.html')) continue;
      processedFiles[key] = _injectVisitorTracker(
        html: processedFiles[key]!,
        siteId: siteId,
      );
      if (ownerUid != null && ownerUid.trim().isNotEmpty) {
        processedFiles[key] = _injectLeadConfig(
          html: processedFiles[key]!,
          ownerUid: ownerUid.trim(),
          siteId: siteId,
          siteName: siteName,
        );
      }
    }

    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${HostingConfig.baseUrl}/api/publish'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'siteId': siteId,
          'desiredSubdomain': desiredSubdomain,
          'files': processedFiles,
          if (ownerEmail != null && ownerEmail.trim().isNotEmpty)
            'ownerEmail': ownerEmail.trim(),
          if (ownerToken != null && ownerToken.trim().isNotEmpty)
            'ownerToken': ownerToken.trim(),
        }),
      );
    } catch (e) {
      throw HostingException('İnternet bağlantısı sorunu: $e');
    }
    // 06.09.2026 eklendi — bkz. server_time_service.dart: yayınlama en sık
    // tetiklenen worker çağrısı olduğu için clock-skew'i güncel tutmak için
    // iyi bir fırsat.
    ServerTimeService.updateFromResponse(res);

    if (res.statusCode == 403) {
      throw HostingException(
          'Bu site başka bir cihaz/hesaba ait görünüyor, üzerine yazılamadı.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('Yayınlama başarısız oldu (${res.statusCode}).');
    }
    final result =
        PublishResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    // Analitik: 'site_published' — Worker gerçek subdomain'i (varsa
    // benzersizleştirilmiş halini) döndükten SONRA loglanır, kullanıcının
    // isteği DEĞİL gerçekleşen sonuç kaydedilir.
    unawaited(AnalyticsService.logSitePublished(subdomain: result.subdomain));
    return result;
  }

  /// Yayınlanan sitenin ziyaretçi sayısını Worker'dan okur (bkz.
  /// cloudflare/worker/src/index.mjs > handleStats). Worker henüz
  /// deploy edilmediyse (baseUrl boş) [HostingNotConfiguredException] fırlatır.
  static Future<SiteStats> fetchStats({required String siteId}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      res = await http.get(Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId/stats'));
    } catch (e) {
      throw HostingException('İnternet bağlantısı sorunu: $e');
    }
    if (res.statusCode == 404) {
      throw HostingException('Bu site için istatistik bulunamadı (henüz yayınlanmamış olabilir).');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('İstatistikler alınamadı (${res.statusCode}).');
    }
    return SiteStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Birden fazla yayındaki proje için ziyaretçi istatistiklerini TEK
  /// istekte çeker (bkz. cloudflare/worker/src/index.mjs > handleStatsBatch).
  /// Projelerim ekranındaki "Yayında olan siteler" listesi bunu kullanır —
  /// her kart için ayrı ayrı [fetchStats] çağırmak N round-trip demek,
  /// bu ise 1. Bulunamayan/silinmiş bir siteId sonuçta sessizce eksik
  /// kalır (worker onu listede döndürmez), çağıran taraf eksik siteId'ler
  /// için "—" göstermeye hazırlıklı olmalı.
  /// [siteIds] boşsa hiç istek atmadan boş liste döner. Worker en fazla
  /// 50 id kabul eder (bkz. handleStatsBatch) — daha fazlası sessizce kırpılır.
  static Future<Map<String, SiteStats>> fetchStatsBatch({required List<String> siteIds}) async {
    if (siteIds.isEmpty) return {};
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    http.Response res;
    try {
      final idsParam = Uri.encodeComponent(siteIds.join(','));
      res = await http.get(Uri.parse('${HostingConfig.baseUrl}/api/sites/stats?ids=$idsParam'));
    } catch (e) {
      throw HostingException('İnternet bağlantısı sorunu: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('İstatistikler alınamadı (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (decoded['sites'] as List<dynamic>? ?? []);
    final result = <String, SiteStats>{};
    for (final item in list) {
      final stats = SiteStats.fromJson(item as Map<String, dynamic>);
      result[stats.siteId] = stats;
    }
    return result;
  }

  static Future<void> unpublish({required String siteId, String? ownerToken}) async {
    if (!HostingConfig.isConfigured) throw HostingNotConfiguredException();
    final res = await http.delete(
      Uri.parse('${HostingConfig.baseUrl}/api/sites/$siteId'),
      headers: {
        if (ownerToken != null && ownerToken.trim().isNotEmpty)
          'x-owner-token': ownerToken.trim(),
      },
    );
    if (res.statusCode == 403) {
      throw HostingException('Bu siteyi kaldırma yetkiniz yok.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HostingException('Yayından kaldırma başarısız oldu (${res.statusCode}).');
    }
  }

  /// Ziyaretçinin canlı sitede göreceği, sağ altta sabit duran 🚩 "Şikayet
  /// Et" butonu + basit modal. Gönderim İKİ yere birden gider:
  ///   1) Apps Script uç noktası (aynı [ReportService] ile) -> mail kutusuna düşer,
  ///   2) Worker'ın kendi `/api/report`'u (relative fetch, aynı origin'den servis
  ///      edildiği için hem path-mode hem domain-mode'da otomatik doğru adrese
  ///      gider) -> D1'deki `reports` tablosuna yazılır, /admin panelinde görünür.
  /// (1) her koşulda çalışır (Worker kurulmasa da). (2) sadece site Worker
  /// üzerinden servis ediliyorsa (yani zaten yayınlanmışsa) anlamlıdır ve
  /// başarısız olsa bile ziyaretçiye hata gösterilmez — sessizce yutulur.
  static String _injectReportWidget({required String html, required String siteId}) {
    // 06.09.2026 eklendi (kanka isteği) — "Şikayet Et" yazısı ziyaretçide
    // "site sahibine şikayet ediyorum" izlenimi verebiliyordu; ayrıca widget
    // HER ZAMAN Türkçeydi (İngilizce sitede bile). Sitenin kendi
    // `<html lang="...">` attribute'undan (bkz. shared_html_blocks.dart
    // satır ~1601) dili okuyup [reportWidgetSnippet]'e iletiyoruz.
    final isEnglish =
        RegExp(r'<html[^>]*\blang\s*=\s*"en"', caseSensitive: false)
            .hasMatch(html);
    final widget = reportWidgetSnippet(siteId: siteId, isEnglish: isEnglish);
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$widget</body>');
    }
    return '$html\n$widget';
  }

  /// "Gelen Talepler" formunun okuduğu `window.__SITORA_LEAD__` konfig
  /// script'ini sayfaya ekler — bkz. [publish] > [ownerUid] dokümanı ve
  /// templates/html/shared_html_blocks.dart > leadFormMarkup.
  static String _injectLeadConfig({
    required String html,
    required String ownerUid,
    required String siteId,
    required String siteName,
  }) {
    final snippet = '''
<script>
window.__SITORA_LEAD__ = { ownerUid: ${jsonEncode(ownerUid)}, siteId: ${jsonEncode(siteId)}, siteName: ${jsonEncode(siteName)} };
</script>
''';
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$snippet</body>');
    }
    return '$html\n$snippet';
  }

  /// Ziyaretçi sayacı script'ini sayfaya ekler (bkz. [visitorTrackerSnippet]).
  static String _injectVisitorTracker({required String html, required String siteId}) {
    final tracker = visitorTrackerSnippet(siteId: siteId);
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$tracker</body>');
    }
    return '$html\n$tracker';
  }

  /// Sayfa açılınca Worker'ın `/api/hit` uç noktasına 1 kere ping atan,
  /// gözle görülmez minik bir script. Ziyaretçiye hiçbir şey göstermez,
  /// hiçbir veri toplamaz (kişisel veri/çerez yok) — sadece siteId başına
  /// bir sayaç artırır (bkz. cloudflare/worker/src/index.mjs > handleHit).
  /// Aynı origin'den relative fetch kullanır (report widget'taki (2) adımıyla
  /// aynı sebepten): hem path-mode (/s/slug/) hem ileride domain-mode'da
  /// otomatik doğru worker'a gider. Başarısız olursa sessizce yutulur —
  /// ziyaretçi deneyimini asla etkilemez.
  static String visitorTrackerSnippet({required String siteId}) {
    return '''
<script>
(function(){
  try {
    fetch('/api/hit', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ siteId: ${jsonEncode(siteId)} })
    }).catch(function(){});
  } catch (e) {}
})();
</script>
''';
  }

  static String reportWidgetSnippet(
      {required String siteId, bool isEnglish = false}) {
    // Aynı Apps Script endpoint'i report_service.dart ile birebir aynı;
    // text/plain kullanımı da aynı sebepten (CORS preflight'i atlamak için).
    const endpoint =
        'https://script.google.com/macros/s/AKfycbwYCfWn4ZZztD2htFqwIwZiDeaichlb-G5xVTMXAAMbqOGkZA_mn7Tr_dCq8Hljz1x4yA/exec';
    // 06.09.2026 eklendi (kanka isteği) — buton metni "Şikayet Et"ten
    // "Siteyi Bildir"e çevrildi: ziyaretçi bunu "site sahibinden şikayetçi
    // oluyorum" diye değil, "bu siteyi Sitora'ya bildiriyorum" diye
    // okumalı. Modal başlığında da AÇIKÇA "Sitora'ya" ekleniyor.
    final t = isEnglish
        ? const {
            'btn': '🚩 Report this site',
            'title': 'Report this site to Sitora',
            'offensive': 'Offensive / inappropriate content',
            'illegal': 'Illegal content',
            'hate': 'Hate speech / harassment',
            'other': 'Other',
            'placeholder': 'Briefly explain (required)',
            'cancel': 'Cancel',
            'send': 'Send',
            'needDetails': 'Please write a short explanation.',
            'success':
                'Your report was received, thank you. It will be reviewed shortly.',
            'failure':
                "Couldn't send the report — check your connection and try again.",
          }
        : const {
            'btn': '🚩 Siteyi Bildir',
            'title': "Bu siteyi Sitora'ya bildir",
            'offensive': 'Rahatsız edici / uygunsuz içerik',
            'illegal': 'Yasa dışı içerik',
            'hate': 'Nefret söylemi / taciz',
            'other': 'Diğer',
            'placeholder': 'Kısaca açıkla (zorunlu)',
            'cancel': 'İptal',
            'send': 'Gönder',
            'needDetails': 'Lütfen kısa bir açıklama yaz.',
            'success':
                'Bildirimin ulaştı, teşekkürler. En kısa sürede incelenecek.',
            'failure':
                'Bildirim gönderilemedi, internetini kontrol edip tekrar dener misin?',
          };
    return '''
<div id="sitora-report-widget" style="position:fixed;bottom:14px;left:14px;z-index:999999;font-family:sans-serif;">
  <button id="sitora-report-btn" style="background:#B91C1C;color:#fff;border:none;border-radius:999px;padding:8px 14px;font-size:12px;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,.25);opacity:.85;">${t['btn']}</button>
  <div id="sitora-report-modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.6);align-items:center;justify-content:center;">
    <div style="background:#141821;color:#fff;border-radius:14px;padding:18px;max-width:320px;width:90%;">
      <div style="font-weight:bold;margin-bottom:8px;">${t['title']}</div>
      <select id="sitora-report-reason" style="width:100%;padding:8px;margin-bottom:8px;border-radius:8px;">
        <option value="offensive">${t['offensive']}</option>
        <option value="illegal">${t['illegal']}</option>
        <option value="hate">${t['hate']}</option>
        <option value="other">${t['other']}</option>
      </select>
      <textarea id="sitora-report-details" placeholder="${t['placeholder']}" style="width:100%;min-height:60px;padding:8px;border-radius:8px;margin-bottom:8px;"></textarea>
      <div style="display:flex;gap:8px;">
        <button id="sitora-report-cancel" style="flex:1;padding:10px;border-radius:8px;border:1px solid #444;background:transparent;color:#fff;">${t['cancel']}</button>
        <button id="sitora-report-send" style="flex:1;padding:10px;border-radius:8px;border:none;background:#B91C1C;color:#fff;">${t['send']}</button>
      </div>
    </div>
  </div>
</div>
<script>
(function(){
  var siteId = ${jsonEncode(siteId)};
  var endpoint = ${jsonEncode(endpoint)};
  var btn = document.getElementById('sitora-report-btn');
  var modal = document.getElementById('sitora-report-modal');
  var cancel = document.getElementById('sitora-report-cancel');
  var send = document.getElementById('sitora-report-send');
  btn.onclick = function(){ modal.style.display = 'flex'; };
  cancel.onclick = function(){ modal.style.display = 'none'; };
  send.onclick = function(){
    var details = document.getElementById('sitora-report-details').value.trim();
    if (!details) { alert(${jsonEncode(t['needDetails'])}); return; }
    send.disabled = true;
    fetch(endpoint, {
      method: 'POST',
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: JSON.stringify({
        reason: document.getElementById('sitora-report-reason').value,
        details: '[YAYINLANAN SİTE ŞİKAYETİ] siteId=' + siteId + ' url=' + location.href + ' | ' + details,
        context: 'hosted_site',
        siteId: siteId,
        publishedUrl: location.href,
        lang: ${jsonEncode(isEnglish ? 'en' : 'tr')},
        appVersion: 'SitoraAI-HostedSiteWidget',
        timestamp: new Date().toISOString()
      })
    }).then(function(){
      // (2) Worker'ın kendi /api/report'una da (D1'e kalıcı kayıt için) ayrıca
      // gönder. Aynı origin'den relative fetch -> path-mode'da /s/<slug>/'dan,
      // domain-mode'da <subdomain>.sitora.app'ten atıldığında da doğru worker'a
      // gider. Bu adım sessiz: başarısız olsa da ziyaretçiye hata gösterilmez,
      // çünkü asıl bildirim (Apps Script/mail) zaten yukarıda gitti.
      try {
        fetch('/api/report', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({
            siteId: siteId,
            reason: document.getElementById('sitora-report-reason').value,
            details: details,
            publishedUrl: location.href
          })
        }).catch(function(){});
      } catch (e) {}
      alert(${jsonEncode(t['success'])});
      modal.style.display = 'none';
      send.disabled = false;
    }).catch(function(){
      alert(${jsonEncode(t['failure'])});
      send.disabled = false;
    });
  };
})();
</script>
''';
  }
}
