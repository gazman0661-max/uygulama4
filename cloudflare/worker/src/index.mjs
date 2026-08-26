/**
 * Sitora Hosting Worker
 * ---------------------
 * DOMAIN'SİZ MOD: Henüz bir domain alınmadı, bu yüzden siteler alt alan adı
 * (kuaforum.sitora.app) yerine Worker'ın ÜCRETSİZ workers.dev adresi altında
 * PATH ile servis ediliyor: https://<worker>.workers.dev/s/kuaforum/
 * Domain alınıp Cloudflare'a bağlandığında [SUBDOMAIN MODU AÇMAK İÇİN] etiketli
 * yerler değiştirilip wrangler.toml'daki route açılarak gerçek alt alan
 * adına geçilebilir — D1/R2 şeması aynı kalır, sadece serveHostedSite'ın
 * "hangi siteyi bulacağını nereden okuduğu" değişir (path -> hostname).
 *
 * Bindings (wrangler.toml'da tanımlı):
 *   env.DB             -> D1 database (sites + reports tabloları, bkz. schema.sql)
 *   env.BUCKET         -> R2 bucket (yayınlanan site dosyaları)
 *   env.ADMIN_TOKEN    -> secret; moderasyon uçlarını (/admin/*) korumak için
 *   env.RESEND_API_KEY -> secret (OPSİYONEL); site kapatılınca sahibine
 *                          e-posta göndermek için (bkz. sendOwnerDisabledEmail).
 *                          Tanımlı değilse e-posta adımı sessizce atlanır,
 *                          site yine de kapanır.
 *   env.CF_API_TOKEN   -> secret; "KENDİ DOMAİNİMİ BAĞLA" özelliği için.
 *                          Cloudflare API token'ı, en az "SSL and Certificates:Edit"
 *                          + "Zone:Read" yetkisine sahip olmalı (Cloudflare for SaaS /
 *                          Custom Hostnames uç noktalarını çağırmak için). Tanımlı
 *                          değilse domain bağlama uçları 501 döner, geri kalan her şey
 *                          (yayınlama, alt alan adı vb.) normal çalışmaya devam eder.
 *   env.CF_ZONE_ID     -> secret/var; Sitora'nın kendi zone'unun (örn. sitora.app)
 *                          Cloudflare Zone ID'si — Custom Hostnames bu zone altında oluşturulur.
 *   env.CF_FALLBACK_ORIGIN -> var; kullanıcılara CNAME hedefi olarak gösterilecek,
 *                          TÜM kullanıcılar için AYNI olan sabit adres (Cloudflare for
 *                          SaaS'ta "fallback origin" olarak zone'a tanımlanmış olmalı),
 *                          örn. "verify.sitora-hosting.com". Bkz. handleDomainConnect.
 *   env.GOOGLE_SERVICE_ACCOUNT_JSON -> secret; Play Store satın alma makbuzlarını
 *                          Google Play Developer API ile doğrulamak için kullanılan
 *                          Google Cloud servis hesabının JSON anahtarının TAMAMI
 *                          (tek satır string olarak). Play Console'da bu servis
 *                          hesabına "Ürünleri yönet" (view financial/order data)
 *                          izni verilmiş olmalı — bkz. handleVerifyPurchase.
 *                          Tanımlı değilse /api/verify-purchase her zaman
 *                          {valid:false} döner (satın alma reddedilir, sessizce
 *                          "başarılı" SAYILMAZ — güvenli taraf budur).
 *   env.FIREBASE_SERVICE_ACCOUNT_JSON -> secret; admin panelindeki kullanıcı
 *                          arama + puan/kota düzeltme özelliği için Firestore'a
 *                          erişen Firebase servis hesabının JSON anahtarı
 *                          (Firebase Console > Proje Ayarları > Servis
 *                          Hesapları > Yeni özel anahtar oluştur). YUKARIDAKİ
 *                          GOOGLE_SERVICE_ACCOUNT_JSON'dan FARKLIDIR (o Play
 *                          Developer API için). Tanımlı değilse /admin/users
 *                          uçları 501 döner, panelin geri kalanı etkilenmez.
 *
 * Rotalar:
 *   POST   /api/publish        -> yeni site yayınla / güncelle
 *   DELETE /api/sites/:id      -> siteyi KALICI sil (R2 + D1 temizler, geri dönüşü yok)
 *   POST   /api/report         -> ziyaretçi şikayeti D1'e kaydeder (bkz. reports tablosu)
 *   POST   /api/hit            -> ziyaretçi sayacını +1 artırır (bkz. handleHit).
 *                                  Yayınlanan HER sitenin sayfalarına otomatik enjekte
 *                                  edilen küçük bir script tarafından çağrılır (bkz.
 *                                  Flutter tarafı: hosting_service.dart > visitorTrackerSnippet).
 *   POST   /api/verify-purchase -> Flutter tarafından (BillingService._verifyPurchaseServerSide)
 *                                  bir Play Store satın alma makbuzunu doğrulamak için çağrılır.
 *                                  Google Play Developer API'ye servis hesabı üzerinden sorar,
 *                                  gerçekten "purchased" durumundaysa {valid:true} döner.
 *                                  Sahte/patch'lenmiş istemci taklitlerine karşı asıl savunma
 *                                  budur — bkz. handleVerifyPurchase.
 *   GET    /api/sites/:id/stats -> o siteye ait toplam + bugünkü ziyaretçi sayısını JSON döner
 *                                  (bkz. Flutter: HostingService.fetchStats). siteId zaten
 *                                  siteyi yayınlayan kişide olduğu için ekstra token gerektirmez
 *                                  — tıpkı DELETE /api/sites/:id gibi.
 *   GET    /api/sites/stats?ids=a,b,c -> yukarıdakinin TOPLU hali, Projelerim ekranındaki
 *                                  "Yayında olan siteler" listesi için (bkz. Flutter:
 *                                  HostingService.fetchStatsBatch) — N ayrı istek yerine tek istek.
 *   POST   /api/domains/connect     -> "Kendi domainimi bağla": Cloudflare'da custom hostname
 *                                       oluşturur, kullanıcıya eklemesi gereken CNAME kaydını döner
 *                                       (bkz. handleDomainConnect / Flutter: domain_service.dart).
 *   GET    /api/domains/:siteId/status -> DNS/SSL doğrulama durumunu Cloudflare'dan tazeleyip
 *                                       döner (Flutter tarafı bunu birkaç saniyede bir polling yapar).
 *                                       Ayrıca domain_connected_at'e göre hesaplanan expired/expiresAt
 *                                       bilgisini de döner (bkz. handleDomainStatus).
 *   POST   /api/domains/:siteId/renew  -> 1 yıllık bağlantı süresini bugünden itibaren sıfırlar
 *                                       (domain_connected_at = now). Cloudflare tarafında bir
 *                                       değişiklik YAPMAZ — sadece Sitora'nın kendi süre sayacını
 *                                       (bkz. serveCustomDomainSite'daki kesme kontrolü) resetler.
 *                                       Bağlı bir custom_domain yoksa 400 döner.
 *   DELETE /api/domains/:siteId     -> bağlı custom domain'i Cloudflare'dan ve D1'den kaldırır,
 *                                       site tekrar sadece alt alan adından erişilebilir olur.
 *   GET    /admin               -> [tarayıcıdan] token korumalı basit moderasyon paneli (HTML)
 *   GET    /admin/summary       -> [x-admin-token] dashboard özet rakamları (site/ziyaret/şikayet sayıları)
 *   GET    /admin/reports       -> [x-admin-token] bekleyen şikayetleri JSON listele
 *   POST   /admin/reports/:id/dismiss -> [x-admin-token] tek bir şikayeti ASILSIZ bularak
 *                                       'dismissed' işaretle — site KAPATILMAZ, sadece o
 *                                       şikayet bekleyen listeden kalkar (bkz. handleAdminReportDismiss)
 *   GET    /admin/sites         -> [x-admin-token] siteleri JSON listele — opsiyonel ?search=
 *                                       (subdomain'de kısmi eşleşme) ve ?status=live|disabled
 *                                       query param'larıyla filtrelenebilir (bkz. handleAdminSites)
 *   GET    /admin/sites/:id     -> [x-admin-token] tek bir sitenin detayı (şikayetler + günlük ziyaret dökümü)
 *   POST   /admin/sites/:id/disable -> [x-admin-token] siteyi YUMUŞAK kapat + sahibine mail
 *   POST   /admin/sites/:id/enable  -> [x-admin-token] kapatılan siteyi geri aç
 *   POST   /admin/sites/:id/delete  -> [x-admin-token] siteyi KALICI sil (R2+D1, geri dönüşü yok)
 *   GET    /admin/users?email=  -> [x-admin-token] Firestore'da e-postaya göre kullanıcı ara
 *   PATCH  /admin/users/:uid    -> [x-admin-token] kullanıcının puan/kota alanlarını elle düzelt
 *   GET    /admin/users/:uid/projects -> [x-admin-token] kullanıcının tüm projelerini listele
 *   PATCH  /admin/users/:uid/projects/:projectId -> [x-admin-token] o projeye rozet kaldırma
 *                                       ve/veya yayın hakkı ELLE tanımla (bkz. handleAdminProjectUpdate)
 *   GET    /admin/mail          -> [x-admin-token] gönderilmiş TÜM bildirim/hediye mesajlarını listele
 *   POST   /admin/mail          -> [x-admin-token] tek kullanıcıya (uid) ya da HERKESE ("all") yeni bir
 *                                       bildirim/hediye mesajı oluştur — bkz. handleAdminMailCreate,
 *                                       Flutter tarafında lib/services/mailbox_service.dart
 *   POST   /admin/mail/:id/delete -> [x-admin-token] bir mesajı KALICI sil (henüz teslim alınmamışsa
 *                                       kullanıcı bir daha görmez; zaten teslim alınmışsa hediye geri alınmaz)
 *   GET    /s/:slug/*          -> R2'den statik dosya servisi (domain'siz mod)
 *   GET    *                   -> Host header bağlı bir custom domain'e eşleşiyorsa (bkz.
 *                                  serveCustomDomainSite), o siteyi doğrudan kök path'ten servis eder.
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;

    if (pathname === '/api/publish' && request.method === 'POST') {
      return handlePublish(request, env);
    }
    if (pathname.startsWith('/api/sites/') && request.method === 'DELETE') {
      const siteId = pathname.split('/')[3];
      return handleUnpublish(siteId, env);
    }
    if (pathname === '/api/report' && request.method === 'POST') {
      return handleReport(request, env);
    }
    if (pathname === '/api/hit' && request.method === 'POST') {
      return handleHit(request, env);
    }
    if (pathname === '/api/sites/stats' && request.method === 'GET') {
      return handleStatsBatch(request, env);
    }
    if (pathname.match(/^\/api\/sites\/[^/]+\/stats$/) && request.method === 'GET') {
      const siteId = pathname.split('/')[3];
      return handleStats(siteId, env);
    }
    if (pathname === '/api/verify-purchase' && request.method === 'POST') {
      return handleVerifyPurchase(request, env);
    }
    if (pathname === '/api/domains/connect' && request.method === 'POST') {
      return handleDomainConnect(request, env);
    }
    if (pathname.match(/^\/api\/domains\/[^/]+\/status$/) && request.method === 'GET') {
      const siteId = pathname.split('/')[3];
      return handleDomainStatus(siteId, env);
    }
    if (pathname.match(/^\/api\/domains\/[^/]+\/renew$/) && request.method === 'POST') {
      const siteId = pathname.split('/')[3];
      return handleDomainRenew(siteId, env);
    }
    if (pathname.match(/^\/api\/domains\/[^/]+$/) && request.method === 'DELETE') {
      const siteId = pathname.split('/')[3];
      return handleDomainDisconnect(siteId, env);
    }
    if (pathname === '/admin' && request.method === 'GET') {
      return new Response(ADMIN_HTML, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
    }
    if (pathname === '/admin/summary' && request.method === 'GET') {
      return requireAdmin(request, env, () => handleAdminSummary(env));
    }
    if (pathname === '/admin/reports' && request.method === 'GET') {
      return requireAdmin(request, env, () => handleAdminReports(env));
    }
    if (pathname.match(/^\/admin\/reports\/[^/]+\/dismiss$/) && request.method === 'POST') {
      const reportId = pathname.split('/')[3];
      return requireAdmin(request, env, () => handleAdminReportDismiss(reportId, env));
    }
    if (pathname === '/admin/sites' && request.method === 'GET') {
      return requireAdmin(request, env, () => handleAdminSites(request, env));
    }
    if (pathname.match(/^\/admin\/sites\/[^/]+\/disable$/) && request.method === 'POST') {
      const siteId = pathname.split('/')[3];
      return requireAdmin(request, env, async () => {
        const body = await request.json().catch(() => ({}));
        return handleAdminDisable(siteId, body.reason || 'Kural ihlali', env);
      });
    }
    if (pathname.match(/^\/admin\/sites\/[^/]+\/enable$/) && request.method === 'POST') {
      const siteId = pathname.split('/')[3];
      return requireAdmin(request, env, () => handleAdminEnable(siteId, env));
    }
    if (pathname.match(/^\/admin\/sites\/[^/]+\/delete$/) && request.method === 'POST') {
      const siteId = pathname.split('/')[3];
      return requireAdmin(request, env, () => handleAdminHardDelete(siteId, env));
    }
    if (pathname.match(/^\/admin\/sites\/[^/]+$/) && request.method === 'GET') {
      const siteId = pathname.split('/')[3];
      return requireAdmin(request, env, () => handleAdminSiteDetail(siteId, env));
    }
    if (pathname === '/admin/users' && request.method === 'GET') {
      return requireAdmin(request, env, () => handleAdminUserSearch(request, env));
    }
    if (pathname.match(/^\/admin\/users\/[^/]+$/) && request.method === 'PATCH') {
      const uid = pathname.split('/')[3];
      return requireAdmin(request, env, async () => {
        const body = await request.json().catch(() => ({}));
        return handleAdminUserUpdate(uid, body, env);
      });
    }
    if (pathname.match(/^\/admin\/users\/[^/]+\/projects$/) && request.method === 'GET') {
      const uid = pathname.split('/')[3];
      return requireAdmin(request, env, () => handleAdminUserProjects(uid, env));
    }
    if (pathname.match(/^\/admin\/users\/[^/]+\/projects\/[^/]+$/) && request.method === 'PATCH') {
      const parts = pathname.split('/');
      const uid = parts[3];
      const projectId = parts[5];
      return requireAdmin(request, env, async () => {
        const body = await request.json().catch(() => ({}));
        return handleAdminProjectUpdate(uid, projectId, body, env);
      });
    }
    if (pathname === '/admin/mail' && request.method === 'GET') {
      return requireAdmin(request, env, () => handleAdminMailList(env));
    }
    if (pathname === '/admin/mail' && request.method === 'POST') {
      return requireAdmin(request, env, async () => {
        const body = await request.json().catch(() => ({}));
        return handleAdminMailCreate(body, env);
      });
    }
    if (pathname.match(/^\/admin\/mail\/[^/]+\/delete$/) && request.method === 'POST') {
      const mailId = pathname.split('/')[3];
      return requireAdmin(request, env, () => handleAdminMailDelete(mailId, env));
    }
    if (pathname === '/') {
      return new Response('Sitora Hosting çalışıyor. Site adresleri: /s/<slug>/ — Moderasyon: /admin', { status: 200 });
    }
    if (pathname.startsWith('/s/')) {
      return serveHostedSite(pathname, env);
    }

    // Yukarıdaki hiçbir sabit rotaya uymadıysa: bu istek belki de bağlanmış
    // bir "kendi domainim" üzerinden geliyordur (bkz. handleDomainConnect).
    // Host header'a göre D1'de eşleşen bir site varsa doğrudan servis edilir.
    const customDomainResponse = await serveCustomDomainSite(url.hostname, pathname, env);
    if (customDomainResponse) return customDomainResponse;

    return new Response('404', { status: 404 });
  },
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function requireAdmin(request, env, handler) {
  // Hem header (API çağrıları) hem de query param (?token=... — admin panelinin
  // kendi fetch()'leri header ile atıyor, query sadece kolay debug/curl için) kabul edilir.
  const url = new URL(request.url);
  const token = request.headers.get('x-admin-token') || url.searchParams.get('token');
  if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
    return json({ error: 'unauthorized' }, 401);
  }
  return handler();
}

async function slugify(desired) {
  return desired
    .toLowerCase()
    .replace(/ğ/g, 'g').replace(/ü/g, 'u').replace(/ş/g, 's')
    .replace(/ı/g, 'i').replace(/ö/g, 'o').replace(/ç/g, 'c')
    .replace(/[^a-z0-9-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40) || 'site';
}

async function uniqueSubdomain(base, env) {
  let candidate = base;
  let n = 1;
  // D1 free tier: bu döngü site başına sadece 1 okuma harcıyor (çoğu
  // durumda), aylık 5M okuma limitine göre önemsiz.
  while (true) {
    const existing = await env.DB
      .prepare('SELECT id FROM sites WHERE subdomain = ?')
      .bind(candidate)
      .first();
    if (!existing) return candidate;
    n += 1;
    candidate = `${base}-${n}`;
  }
}

async function handlePublish(request, env) {
  const url = new URL(request.url);
  const body = await request.json();
  const { siteId, desiredSubdomain, files, ownerEmail } = body;
  if (!siteId || !desiredSubdomain || !files || typeof files !== 'object') {
    return json({ error: 'siteId, desiredSubdomain ve files zorunlu' }, 400);
  }

  const existing = await env.DB.prepare('SELECT subdomain FROM sites WHERE id = ?').bind(siteId).first();
  const base = await slugify(desiredSubdomain);
  const subdomain = existing ? existing.subdomain : await uniqueSubdomain(base, env);
  const prefix = `sites/${siteId}/`;

  // R2'ye yaz (Class A op — free tier aylık 1M, burada dosya sayısı kadar harcanır)
  for (const [path, content] of Object.entries(files)) {
    await env.BUCKET.put(prefix + path, content, {
      httpMetadata: { contentType: guessContentType(path) },
    });
  }

  const now = new Date().toISOString();
  if (existing) {
    // Yeniden yayınlama: kapalıysa otomatik açılır (kullanıcı içeriği düzeltip
    // tekrar yayınlamış demektir). owner_email boş gelirse eskisini KORU
    // (COALESCE) — Flutter tarafı her publish'te e-posta göndermeyebilir.
    await env.DB.prepare(
      'UPDATE sites SET updated_at = ?, disabled = 0, disabled_reason = NULL, disabled_at = NULL, owner_notified = 0, owner_email = COALESCE(?, owner_email) WHERE id = ?'
    ).bind(now, ownerEmail || null, siteId).run();
  } else {
    await env.DB.prepare(
      'INSERT INTO sites (id, subdomain, r2_prefix, owner_email, created_at, updated_at, disabled) VALUES (?, ?, ?, ?, ?, ?, 0)'
    ).bind(siteId, subdomain, prefix, ownerEmail || null, now, now).run();
  }

  // DOMAIN'Sİz MOD: worker'ın kendi workers.dev origin'i + /s/slug/ path'i.
  // [SUBDOMAIN MODU AÇMAK İÇİN] domain alınca bu satırı
  // `https://${subdomain}.sitora.app/` ile değiştir.
  const siteUrl = `${url.origin}/s/${subdomain}/`;
  return json({ siteId, subdomain, url: siteUrl });
}

async function handleUnpublish(siteId, env) {
  const site = await env.DB.prepare('SELECT r2_prefix FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found' }, 404);

  const listed = await env.BUCKET.list({ prefix: site.r2_prefix });
  await Promise.all(listed.objects.map((o) => env.BUCKET.delete(o.key)));
  await env.DB.prepare('DELETE FROM sites WHERE id = ?').bind(siteId).run();
  await env.DB.prepare('DELETE FROM reports WHERE site_id = ?').bind(siteId).run();
  return json({ ok: true });
}

async function handleReport(request, env) {
  const body = await request.json();
  const { siteId, reason, details, publishedUrl } = body;
  if (!siteId || !reason || !details) {
    return json({ error: 'siteId, reason ve details zorunlu' }, 400);
  }
  await env.DB.prepare(
    'INSERT INTO reports (site_id, reason, details, published_url, status, created_at) VALUES (?, ?, ?, ?, "pending", ?)'
  ).bind(siteId, reason, details, publishedUrl || null, new Date().toISOString()).run();
  return json({ ok: true });
}

/// Ziyaretçi sayacı: yayınlanan sitenin her sayfa yüklemesinde 1 kez çağrılır
/// (bkz. Flutter: hosting_service.dart > visitorTrackerSnippet). Kapalı
/// (disabled) bir site için de sayaç artırılır — moderasyon durumu ile
/// istatistik ayrı kaygılar, sayaç gerçek trafiği yansıtmalı.
/// Bilinmeyen bir siteId sessizce yutulur (404 değil 204 döner) çünkü bu
/// uç nokta ziyaretçinin tarayıcısından çağrılıyor; hataya düşse bile
/// ziyaretçiye hiçbir şey göstermiyoruz (bkz. o script'teki .catch(()=>{})).
async function handleHit(request, env) {
  const body = await request.json().catch(() => ({}));
  const siteId = body.siteId;
  if (!siteId) return json({ error: 'siteId zorunlu' }, 400);

  const now = new Date();
  const today = now.toISOString().slice(0, 10); // 'YYYY-MM-DD' (UTC)

  await env.DB.prepare(
    'UPDATE sites SET visit_count = visit_count + 1, last_visit_at = ? WHERE id = ?'
  ).bind(now.toISOString(), siteId).run();

  // Günlük kırılım (bkz. schema.sql > site_daily_visits): "bugün kaç kişi
  // baktı" sorusu toplam sayaçtan çıkarılamıyor, bu yüzden ayrı bir UPSERT.
  // Bilinmeyen siteId'de bu satır da sessizce hiçbir şey yazmaz (yukarıdaki
  // UPDATE zaten 0 satır etkiler) — foreign key zorunluluğu YOK, bilerek
  // (bkz. handleHit'in üstündeki doküman: bilinmeyen site sessizce yutulur).
  await env.DB.prepare(
    `INSERT INTO site_daily_visits (site_id, date, count) VALUES (?, ?, 1)
     ON CONFLICT(site_id, date) DO UPDATE SET count = count + 1`
  ).bind(siteId, today).run();

  return new Response(null, { status: 204 });
}

/// Yayınlayan kişinin kendi sitesinin ziyaretçi sayısını görmesi için.
/// siteId zaten sadece o kişide olduğundan (yayınlarken kendisine döner)
/// ekstra bir admin token istenmiyor — DELETE /api/sites/:id ile aynı
/// güvenlik modeli.
async function handleStats(siteId, env) {
  const site = await env.DB
    .prepare('SELECT visit_count, last_visit_at, created_at FROM sites WHERE id = ?')
    .bind(siteId)
    .first();
  if (!site) return json({ error: 'not_found' }, 404);
  const today = new Date().toISOString().slice(0, 10);
  const daily = await env.DB
    .prepare('SELECT count FROM site_daily_visits WHERE site_id = ? AND date = ?')
    .bind(siteId, today)
    .first();
  return json({
    siteId,
    visitCount: site.visit_count || 0,
    todayVisitCount: daily?.count || 0,
    lastVisitAt: site.last_visit_at || null,
    createdAt: site.created_at,
  });
}

/// Projelerim ekranındaki "Yayında olan siteler" listesi için toplu sorgu.
/// Tek tek GET /api/sites/:id/stats çağırmak yerine (N istek = N round-trip),
/// kullanıcının TÜM yayındaki projeleri tek istekte sorgulanır.
/// GET /api/sites/stats?ids=id1,id2,id3 — en fazla 50 id kabul edilir
/// (Projelerim listesi için fazlasıyla yeterli, D1'in tek sorguda IN(...)
/// ile makul kalması için üst sınır).
async function handleStatsBatch(request, env) {
  const url = new URL(request.url);
  const idsParam = url.searchParams.get('ids') || '';
  const ids = idsParam.split(',').map((s) => s.trim()).filter(Boolean).slice(0, 50);
  if (ids.length === 0) return json({ sites: [] });

  const today = new Date().toISOString().slice(0, 10);
  const placeholders = ids.map(() => '?').join(',');

  const sitesResult = await env.DB
    .prepare(`SELECT id, visit_count, last_visit_at FROM sites WHERE id IN (${placeholders})`)
    .bind(...ids)
    .all();
  const dailyResult = await env.DB
    .prepare(`SELECT site_id, count FROM site_daily_visits WHERE date = ? AND site_id IN (${placeholders})`)
    .bind(today, ...ids)
    .all();

  const dailyBySite = {};
  for (const row of dailyResult.results || []) {
    dailyBySite[row.site_id] = row.count;
  }

  const sites = (sitesResult.results || []).map((s) => ({
    siteId: s.id,
    visitCount: s.visit_count || 0,
    todayVisitCount: dailyBySite[s.id] || 0,
    lastVisitAt: s.last_visit_at || null,
  }));

  return json({ sites });
}

// ============================================================================
// KENDİ DOMAİNİMİ BAĞLA — Cloudflare for SaaS / Custom Hostnames entegrasyonu
// ============================================================================
// Akış (bkz. dosya başındaki route açıklaması ve Flutter: domain_service.dart):
//   1) Kullanıcı "ahmetkuafor.com" yazar -> POST /api/domains/connect
//   2) Worker, Cloudflare'da bu hostname için bir "custom hostname" kaydı açar.
//      Cloudflare buna karşılık HERKESE AYNI olan sabit bir CNAME hedefi
//      (env.CF_FALLBACK_ORIGIN) + SSL doğrulaması için hostname'e özel bir
//      doğrulama CNAME'i döner.
//   3) Uygulama bu kayıtları kullanıcıya kopyala-yapıştır olarak gösterir.
//   4) Kullanıcı kendi DNS panelinde bunları ekler; uygulama GET
//      /api/domains/:siteId/status ile birkaç saniyede bir durumu sorar.
//      Cloudflare, DNS yayılıp doğrulama tamamlanınca SSL sertifikasını
//      OTOMATİK çıkarır — worker sadece Cloudflare'ın durumunu D1'e yansıtır.
//
// ÖNEMLİ NÜANS (apex/kök domain): "ahmetkuafor.com" gibi bir kök (apex) domain'e
// klasik DNS kuralı gereği CNAME koyulamaz (sadece A/AAAA/ALIAS/ANAME olur, ve
// tüm sağlayıcılar ALIAS/ANAME sunmuyor). Bu yüzden isApexDomain(...) true
// dönerse handleDomainConnect, "www.ahmetkuafor.com" için bağlanmayı önerir
// (apexWarning + suggestedDomain alanlarıyla) — Flutter tarafı bunu kullanıcıya
// bir uyarı kartı olarak gösterir, ama worker yine de kullanıcının verdiği
// domain'i (isterse apex'i) Cloudflare'a kaydeder; karar kullanıcıda kalır.

const CF_API_BASE = 'https://api.cloudflare.com/client/v4';

/// Basit bir "iki parçalı mı" kontrolü (ahmetkuafor.com -> apex, www.ahmetkuafor.com -> değil).
/// Kusursuz değildir (co.uk gibi çok parçalı public suffix'leri ayırt etmez) ama bu özelliğin
/// amacı kesin bir DNS doğrulayıcı olmak değil, kullanıcıya faydalı bir ön uyarı vermek.
function isApexDomain(hostname) {
  return hostname.split('.').filter(Boolean).length === 2;
}

function normalizeDomain(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, '')
    .replace(/\/.*$/, '');
}

async function cfApiFetch(env, path, options = {}) {
  const res = await fetch(`${CF_API_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${env.CF_API_TOKEN}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok && data.success !== false, status: res.status, data };
}

/// Cloudflare'ın custom hostname durumunu (hostname aktivasyonu + SSL sertifikası
/// birlikte) Sitora'nın kendi basit üç durumuna indirger: 'pending' | 'active' | 'error'.
function simplifyDomainStatus(cfHostname) {
  const sslStatus = cfHostname?.ssl?.status || '';
  const hostnameStatus = cfHostname?.status || '';
  const errorish = ['validation_timed_out', 'failed', 'temporary_failure'];
  if (errorish.includes(sslStatus) || hostnameStatus === 'blocked') {
    return { status: 'error', detail: sslStatus || hostnameStatus };
  }
  const isActive = hostnameStatus === 'active' && sslStatus === 'active';
  return { status: isActive ? 'active' : 'pending', detail: sslStatus || hostnameStatus };
}

/**
 * Flutter tarafından gönderilen bir Play Store satın alma makbuzunu Google
 * Play Developer API'ye sorup gerçekten "purchased" olup olmadığını
 * doğrular. Bkz. billing_service.dart > _verifyPurchaseServerSide — istemci
 * kendi başına "purchased" durumuna GÜVENMEZ, bu uca sorar.
 *
 * NEDEN GEREKLİ: patch'lenmiş bir APK, cihazda BillingClient'ın cevabını
 * taklit edip Google'a hiç gitmeden "purchased" döndürebilir. Böyle bir
 * sahte satın almada Play Console'un satış raporunda HİÇBİR İZ olmaz —
 * bu yüzden "Play Console'da zaten görünüyor" güvencesi TEK BAŞINA yeterli
 * değildir. Bu uç, makbuzu doğrudan Google'a sorarak bu açığı kapatır.
 */
async function handleVerifyPurchase(request, env) {
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    // Servis hesabı henüz kurulmadıysa GÜVENLİ TARAF: reddet, sessizce
    // onaylama. (bkz. dosya başı bindings açıklaması)
    return json({ valid: false, reason: 'server_not_configured' }, 200);
  }

  const body = await request.json().catch(() => ({}));
  const { productId, purchaseToken } = body;
  const packageName = 'com.sitora.ai';
  if (!productId || !purchaseToken) {
    return json({ valid: false, reason: 'missing_fields' }, 400);
  }

  try {
    const accessToken = await getGoogleAccessToken(
      env.GOOGLE_SERVICE_ACCOUNT_JSON,
      'https://www.googleapis.com/auth/androidpublisher'
    );
    const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}`;
    const resp = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!resp.ok) {
      const errText = await resp.text().catch(() => '');
      console.error('verify-purchase: Google API hata döndü', resp.status, errText);
      return json({ valid: false, reason: 'google_api_error' }, 200);
    }
    const data = await resp.json();
    // purchaseState: 0 = satın alındı, 1 = iptal, 2 = beklemede.
    const valid = data.purchaseState === 0;
    return json({ valid });
  } catch (e) {
    console.error('verify-purchase: doğrulama başarısız', e);
    return json({ valid: false, reason: 'exception' }, 200);
  }
}

/**
 * [serviceAccountJson] içindeki servis hesabı anahtarıyla RS256 imzalı bir
 * JWT üretip Google'ın OAuth2 token endpoint'inden geçici bir access token
 * alır (Cloudflare Workers'ta Node'un crypto modülü YOK, bu yüzden imzalama
 * Web Crypto API — crypto.subtle — ile elle yapılıyor). [scope] çağırana
 * göre değişir: Play Developer API için androidpublisher, Firestore admin
 * işlemleri için datastore (bkz. handleAdminUserSearch/Update). Her çağrıda
 * yeni token alınır; bu ölçekte (düşük hacim) önbelleğe almaya gerek yok.
 */
async function getGoogleAccessToken(serviceAccountJson, scope) {
  const key = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: key.client_email,
    scope,
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };
  const enc = (obj) => base64UrlEncode(new TextEncoder().encode(JSON.stringify(obj)));
  const unsigned = `${enc(header)}.${enc(claims)}`;

  const pemBody = key.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!tokenResp.ok) {
    throw new Error(`Google token exchange başarısız: ${tokenResp.status}`);
  }
  const tokenData = await tokenResp.json();
  return tokenData.access_token;
}

function base64UrlEncode(bytes) {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function handleDomainConnect(request, env) {
  if (!env.CF_API_TOKEN || !env.CF_ZONE_ID) {
    return json({ error: 'Domain bağlama henüz yapılandırılmadı (CF_API_TOKEN/CF_ZONE_ID eksik).' }, 501);
  }

  const body = await request.json().catch(() => ({}));
  const { siteId } = body;
  const domain = normalizeDomain(body.domain);
  if (!siteId || !domain) {
    return json({ error: 'siteId ve domain zorunlu' }, 400);
  }
  if (!/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$/.test(domain)) {
    return json({ error: 'Geçersiz domain formatı' }, 400);
  }

  const site = await env.DB.prepare('SELECT * FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found', message: 'Önce siteyi yayınlaman gerekiyor.' }, 404);

  // Aynı domain başka bir siteye zaten bağlıysa engelle.
  const taken = await env.DB
    .prepare('SELECT id FROM sites WHERE custom_domain = ? AND id != ?')
    .bind(domain, siteId)
    .first();
  if (taken) return json({ error: 'domain_taken', message: 'Bu domain başka bir sitede kullanılıyor.' }, 409);

  const { ok, status, data } = await cfApiFetch(env, `/zones/${env.CF_ZONE_ID}/custom_hostnames`, {
    method: 'POST',
    body: JSON.stringify({ hostname: domain, ssl: { method: 'http', type: 'dv' } }),
  });
  if (!ok) {
    const message = data?.errors?.[0]?.message || 'Cloudflare isteği başarısız oldu';
    return json({ error: 'cloudflare_error', message }, status >= 400 ? status : 502);
  }

  const cfHostname = data.result;
  const { status: domainStatus } = simplifyDomainStatus(cfHostname);
  const now = new Date().toISOString();
  await env.DB.prepare(
    `UPDATE sites SET custom_domain = ?, domain_status = ?, cf_hostname_id = ?,
       domain_error = NULL, domain_connected_at = ? WHERE id = ?`
  ).bind(domain, domainStatus, cfHostname.id, now, siteId).run();

  const sslRecords = (cfHostname.ssl?.validation_records || []).map((r) => ({
    type: 'CNAME',
    name: r.cname || r.txt_name,
    value: r.cname_target || r.txt_value,
  }));

  return json({
    siteId,
    domain,
    status: domainStatus,
    apexWarning: isApexDomain(domain),
    suggestedDomain: isApexDomain(domain) ? `www.${domain}` : null,
    // Trafik CNAME'i: TÜM kullanıcılar için sabittir, tek fark hostname adı.
    cnameRecord: { name: domain, target: env.CF_FALLBACK_ORIGIN || 'YAPILANDIRILMADI' },
    // SSL doğrulaması için (varsa) ek CNAME kayıtları — hostname'e özeldir.
    sslValidationRecords: sslRecords,
  });
}

async function handleDomainStatus(siteId, env) {
  if (!env.CF_API_TOKEN || !env.CF_ZONE_ID) {
    return json({ error: 'Domain bağlama henüz yapılandırılmadı.' }, 501);
  }
  const site = await env.DB.prepare('SELECT * FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found' }, 404);
  if (!site.custom_domain || !site.cf_hostname_id) {
    return json({ siteId, domain: null, status: 'not_connected' });
  }

  const { ok, data } = await cfApiFetch(
    env,
    `/zones/${env.CF_ZONE_ID}/custom_hostnames/${site.cf_hostname_id}`,
    { method: 'GET' }
  );
  if (!ok) {
    // Cloudflare tarafında geçici bir hata; D1'deki son bilinen durumu döneriz,
    // polling zaten bir sonraki turda tekrar dener.
    return json({ siteId, domain: site.custom_domain, status: site.domain_status || 'pending', stale: true });
  }

  const { status: domainStatus, detail } = simplifyDomainStatus(data.result);
  await env.DB.prepare(
    'UPDATE sites SET domain_status = ?, domain_error = ? WHERE id = ?'
  ).bind(domainStatus, domainStatus === 'error' ? detail : null, siteId).run();

  const { expired, expiresAt } = domainExpiryInfo(site.domain_connected_at);
  return json({
    siteId,
    domain: site.custom_domain,
    status: domainStatus,
    detail,
    checkedAt: new Date().toISOString(),
    // 1 yıllık süre bilgisi Cloudflare'ın hostname/SSL durumundan BAĞIMSIZDIR
    // (bkz. serveCustomDomainSite'daki gerçek kesme kontrolü) — Flutter
    // tarafı süreyi yerelde de hesaplıyor, bu alanlar sunucudan doğrulama
    // amaçlı (cihaz saati kaymışsa veya uygulama yeniden kurulmuşsa).
    domainConnectedAt: site.domain_connected_at || null,
    domainExpiresAt: expiresAt,
    expired,
  });
}

const DOMAIN_CONNECTION_TTL_MS = 365 * 24 * 60 * 60 * 1000; // 1 yıl

/// [connectedAt] (ISO 8601 string veya null) verilen bir domain bağlantısının
/// 1 yıllık süresinin dolup dolmadığını hesaplar. connectedAt null/geçersizse
/// (henüz hiç bağlanmamış/eski kayıt) expired=false döner — o durumda zaten
/// serveCustomDomainSite'a hiç düşülmez (custom_domain NULL olur).
function domainExpiryInfo(connectedAt) {
  if (!connectedAt) return { expired: false, expiresAt: null };
  const connectedMs = new Date(connectedAt).getTime();
  if (Number.isNaN(connectedMs)) return { expired: false, expiresAt: null };
  const expiresAtMs = connectedMs + DOMAIN_CONNECTION_TTL_MS;
  return { expired: Date.now() > expiresAtMs, expiresAt: new Date(expiresAtMs).toISOString() };
}

/// Kullanıcı uygulamada "Bağlantıyı 1 Yıl Uzat" butonuna bastığında çağrılır.
/// SADECE Sitora'nın kendi süre sayacını (domain_connected_at) bugüne
/// sıfırlar — Cloudflare tarafında (custom hostname, SSL, DNS) HİÇBİR ŞEY
/// değiştirmez, çünkü domain zaten Cloudflare'da aktif/doğrulanmış durumda;
/// burada uzatılan sadece Sitora'nın "bu domain'i kaç gündür barındırıyoruz"
/// iş kuralı. Bağlı bir custom_domain yoksa (kullanıcı hiç domain
/// bağlamamışsa veya kaldırmışsa) 400 döner — o durumda önce domain
/// bağlanmalı (bkz. handleDomainConnect).
async function handleDomainRenew(siteId, env) {
  const site = await env.DB.prepare('SELECT * FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found' }, 404);
  if (!site.custom_domain) {
    return json({ error: 'not_connected', message: 'Bu projeye bağlı bir domain yok.' }, 400);
  }

  const now = new Date().toISOString();
  await env.DB.prepare('UPDATE sites SET domain_connected_at = ? WHERE id = ?').bind(now, siteId).run();

  const { expiresAt } = domainExpiryInfo(now);
  return json({
    siteId,
    domain: site.custom_domain,
    domainConnectedAt: now,
    domainExpiresAt: expiresAt,
  });
}

async function handleDomainDisconnect(siteId, env) {
  const site = await env.DB.prepare('SELECT * FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found' }, 404);

  if (site.cf_hostname_id && env.CF_API_TOKEN && env.CF_ZONE_ID) {
    // Cloudflare tarafı temizlenemese bile (örn. zaten silinmişse) D1'i
    // temizlemeye devam ederiz — kullanıcı için asıl önemli olan uygulamanın
    // artık bu domain'i "bağlı" göstermemesi.
    await cfApiFetch(
      env,
      `/zones/${env.CF_ZONE_ID}/custom_hostnames/${site.cf_hostname_id}`,
      { method: 'DELETE' }
    ).catch(() => {});
  }

  await env.DB.prepare(
    `UPDATE sites SET custom_domain = NULL, domain_status = NULL, cf_hostname_id = NULL,
       domain_error = NULL, domain_connected_at = NULL WHERE id = ?`
  ).bind(siteId).run();

  return json({ ok: true });
}

/// Bağlı bir custom domain'den gelen isteği servis eder (bkz. yukarıdaki
/// fetch() içindeki son fallback). Sadece domain_status = 'active' olan
/// (yani Cloudflare tarafında SSL/hostname doğrulaması tamamlanmış) siteler
/// için içerik döner — 'pending' durumundaki bir domain henüz DNS/SSL
/// doğrulanmadığı için burada bilerek servis edilmez (Cloudflare zaten bu
/// durumda kendi hata sayfasını gösterir, buraya hiç düşmez).
async function serveCustomDomainSite(hostname, pathname, env) {
  if (!hostname) return null;
  const site = await env.DB
    .prepare("SELECT * FROM sites WHERE custom_domain = ? AND domain_status = 'active'")
    .bind(hostname)
    .first();
  if (!site) return null;
  if (site.disabled) {
    return new Response('Bu site bir şikayet üzerine incelenip yayından kaldırıldı.', { status: 410 });
  }
  // GERÇEK KESME NOKTASI: "kendi domainimi bağla" 1 yıl süreli bir bağlantıdır
  // (ürün kararı). Bu kontrol sadece Flutter tarafındaki gösterge/bildirim
  // değil — süre dolmuşsa domain, subdomain modundan (workers.dev/s/slug)
  // FARKLI olarak burada gerçekten servis edilmez. Kullanıcı uygulamadan
  // "Bağlantıyı 1 Yıl Uzat"a basıp POST /api/domains/:siteId/renew'i
  // çağırana kadar bu adres erişilemez kalır (site verisi/subdomain adresi
  // silinmez, sadece bu custom domain üzerinden servis durur).
  if (domainExpiryInfo(site.domain_connected_at).expired) {
    return new Response(
      'Bu domain bağlantısının 1 yıllık süresi doldu. Siteyi bu adreste tekrar '
      + 'yayınlamak için Sitora uygulamasından "Bağlantıyı 1 Yıl Uzat" butonuna basman gerekiyor.',
      { status: 402 }
    );
  }

  let path = pathname === '/' || pathname === '' ? 'index.html' : pathname.replace(/^\//, '');
  let object = await env.BUCKET.get(site.r2_prefix + path);
  if (!object && !path.includes('.')) {
    object = await env.BUCKET.get(site.r2_prefix + path + '.html');
  }
  if (!object) return new Response('404', { status: 404 });

  return new Response(object.body, {
    headers: {
      'Content-Type': object.httpMetadata?.contentType || guessContentType(path),
      'Cache-Control': 'public, max-age=300',
    },
  });
}

/// ============================================================================
/// FIRESTORE ADMIN ERİŞİMİ (kullanıcı arama + puan/kota düzeltme)
/// ============================================================================
/// env.FIREBASE_SERVICE_ACCOUNT_JSON -> secret; Firebase Console > Proje
/// Ayarları > Servis Hesapları > "Yeni özel anahtar oluştur" ile indirilen
/// JSON dosyasının TAMAMI (tek satır string). GOOGLE_SERVICE_ACCOUNT_JSON'dan
/// (Play Developer API için) FARKLI bir anahtardır — karıştırma. Bu secret
/// tanımlı değilse /admin/users uçları 501 döner, panelin geri kalanı
/// (siteler, şikayetler, dashboard) etkilenmez.
function firestoreProjectId(env) {
  return JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON).project_id;
}

async function firestoreAccessToken(env) {
  return getGoogleAccessToken(
    env.FIREBASE_SERVICE_ACCOUNT_JSON,
    'https://www.googleapis.com/auth/datastore'
  );
}

/// Firestore REST API'nin tipli alan formatını ({stringValue:"x"} gibi)
/// düz bir JS objesine çevirir — admin panelinin okuması/göstermesi için.
function fsFieldsToPlain(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) {
    if ('stringValue' in v) out[k] = v.stringValue;
    else if ('integerValue' in v) out[k] = parseInt(v.integerValue, 10);
    else if ('doubleValue' in v) out[k] = v.doubleValue;
    else if ('booleanValue' in v) out[k] = v.booleanValue;
    else if ('nullValue' in v) out[k] = null;
    else if ('timestampValue' in v) out[k] = v.timestampValue;
    else out[k] = v;
  }
  return out;
}

/// Ters yön: admin panelinden gelen düz bir { formCredits: 20 } gibi objeyi
/// Firestore PATCH'in beklediği tipli formata çevirir. Sadece bu admin
/// panelinde düzenlenmesine izin verilen alanlar (bkz. handleAdminUserUpdate)
/// bu fonksiyona gelir, bu yüzden tip tahmini basit tutuldu.
function plainToFsFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (typeof v === 'number') fields[k] = { integerValue: String(Math.trunc(v)) };
    else if (typeof v === 'boolean') fields[k] = { booleanValue: v };
    else if (v === null) fields[k] = { nullValue: null };
    else fields[k] = { stringValue: String(v) };
  }
  return fields;
}

/// E-postaya göre users koleksiyonunda arama yapar (Firestore :runQuery).
/// En fazla 10 sonuç döner — bu panelde tek bir kullanıcı bulmak için
/// kullanılıyor, e-posta genelde benzersiz olduğundan pratikte 0 ya da 1 döner.
async function handleAdminUserSearch(request, env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'not_configured', message: 'FIREBASE_SERVICE_ACCOUNT_JSON tanımlı değil.' }, 501);
  }
  const email = new URL(request.url).searchParams.get('email')?.trim();
  if (!email) return json({ error: 'email zorunlu' }, 400);

  const token = await firestoreAccessToken(env);
  const projectId = firestoreProjectId(env);
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'users' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'email' },
              op: 'EQUAL',
              value: { stringValue: email },
            },
          },
          limit: 10,
        },
      }),
    }
  );
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    return json({ error: 'firestore_error', message: errText }, 502);
  }
  const rows = await res.json();
  const users = (rows || [])
    .filter((r) => r.document)
    .map((r) => ({
      uid: r.document.name.split('/').pop(),
      ...fsFieldsToPlain(r.document.fields),
    }));
  return json({ users });
}

/// Sadece bu 4 alanın (uygulamanın kota/puan mantığında kullanılan) elle
/// düzeltilmesine izin verilir — bkz. user_data_service.dart dosya başı
/// şema açıklaması. Başka bir alan (email, createdAt vb.) buradan
/// değiştirilemez, kazara bozulmayı önlemek için bilerek kısıtlı tutuldu.
const ADMIN_EDITABLE_USER_FIELDS = ['formCredits', 'purchasedPoints', 'extraPublishCredits', 'freeSitePublishUsed'];

async function handleAdminUserUpdate(uid, body, env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'not_configured', message: 'FIREBASE_SERVICE_ACCOUNT_JSON tanımlı değil.' }, 501);
  }
  const patch = {};
  for (const k of ADMIN_EDITABLE_USER_FIELDS) {
    if (k in body) patch[k] = body[k];
  }
  if (Object.keys(patch).length === 0) {
    return json({ error: 'düzenlenebilir hiçbir alan gönderilmedi' }, 400);
  }
  patch.updatedAt = new Date().toISOString();

  const token = await firestoreAccessToken(env);
  const projectId = firestoreProjectId(env);
  const maskParams = Object.keys(patch).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}?${maskParams}`,
    {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: plainToFsFields(patch) }),
    }
  );
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    return json({ error: 'firestore_error', message: errText }, 502);
  }
  const doc = await res.json();
  return json({ ok: true, uid, ...fsFieldsToPlain(doc.fields) });
}

/// Bir kullanıcının TÜM projelerini (users/{uid}/projects alt koleksiyonu)
/// listeler — panelde "rozet kaldırma hakkı ver" / "yayın hakkı ver"
/// butonlarını hangi projeye uygulayacağını seçebilmek için. runQuery değil
/// düz koleksiyon listeleme kullanılır (filtre gerekmiyor, tüm projeler dönsün).
async function handleAdminUserProjects(uid, env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'not_configured', message: 'FIREBASE_SERVICE_ACCOUNT_JSON tanımlı değil.' }, 501);
  }
  const token = await firestoreAccessToken(env);
  const projectId = firestoreProjectId(env);
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}/projects?pageSize=100`,
    { headers: { Authorization: `Bearer ${token}` } }
  );
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    return json({ error: 'firestore_error', message: errText }, 502);
  }
  const data = await res.json();
  const projects = (data.documents || []).map((d) => ({
    id: d.name.split('/').pop(),
    ...fsFieldsToPlain(d.fields),
  }));
  return json({ projects });
}

/// Rozet kaldırma (watermarkRemoved) SİTE bazlı, yayın hakkı (publishRightGranted)
/// da PROJE bazlı olduğu için (bkz. site_project.dart) ikisi de kullanıcı
/// dokümanında değil, ilgili projects/{projectId} dokümanında tutuluyor —
/// bu yüzden handleAdminUserUpdate'ten (users/{uid}) AYRI bir uç nokta.
/// Hem tanımlama (true) HEM geri alma (false) desteklenir — yanlışlıkla
/// verilen bir hak panelden geri alınabilsin diye (bkz. ADMIN_HTML'deki
/// "Geri al" butonu). Sadece bu iki bool alan düzenlenebilir.
async function handleAdminProjectUpdate(uid, projectId, body, env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'not_configured', message: 'FIREBASE_SERVICE_ACCOUNT_JSON tanımlı değil.' }, 501);
  }
  const patch = {};
  if (typeof body.watermarkRemoved === 'boolean') patch.watermarkRemoved = body.watermarkRemoved;
  if (typeof body.publishRightGranted === 'boolean') patch.publishRightGranted = body.publishRightGranted;
  if (Object.keys(patch).length === 0) {
    return json({ error: 'watermarkRemoved ve/veya publishRightGranted true/false olarak gönderilmeli' }, 400);
  }

  const token = await firestoreAccessToken(env);
  const projectIdGcp = firestoreProjectId(env);
  const maskParams = Object.keys(patch).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectIdGcp}/databases/(default)/documents/users/${uid}/projects/${projectId}?${maskParams}`,
    {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: plainToFsFields(patch) }),
    }
  );
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    return json({ error: 'firestore_error', message: errText }, 502);
  }
  const doc = await res.json();
  return json({ ok: true, projectId, ...fsFieldsToPlain(doc.fields) });
}

/// ============================================================================
/// MAILBOX (BİLDİRİM / HEDİYE KUTUSU) — bkz. Flutter lib/services/mailbox_service.dart
/// ============================================================================
/// Empires & Puzzles vb. oyunlardaki "gelen kutusu" mantığı: admin panelinden
/// TEK bir kullanıcıya (uid) ya da HERKESE ("all") bir mesaj + opsiyonel bir
/// hediye (puan / yayın hakkı) gönderilir. Firestore'da tek koleksiyon:
/// mailbox/{mailId} — "herkese" gönderim için TEK doküman yeterli, kullanıcı
/// başına ayrı kopya YAZILMAZ (milyonlarca yazma maliyetinden kaçınmak için);
/// istemci tarafı bu koleksiyonu `target in [uid, "all"]` sorgusuyla okur ve
/// kimin teslim aldığını kendi users/{uid}/claimedMail alt koleksiyonunda
/// tutar (bkz. mailbox_service.dart > claim). Bu yüzden BURADA "kaç kişi
/// teslim aldı" gibi bir sayaç YOK — istemci tarafı zaten çift teslimi
/// transaction'la engelliyor, sunucu tarafında ekstra bir defter tutmaya
/// gerek yok.
const MAIL_GIFT_TYPES = ['none', 'points', 'publishCredit'];

async function handleAdminMailList(env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'not_configured', message: 'FIREBASE_SERVICE_ACCOUNT_JSON tanımlı değil.' }, 501);
  }
  const token = await firestoreAccessToken(env);
  const projectId = firestoreProjectId(env);
  // orderBy + runQuery: en yeni mesaj en üstte, panelde en fazla son 200
  // mesaj gösterilir (moderasyon geçmişi için fazlasıyla yeterli).
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'mailbox' }],
          orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
          limit: 200,
        },
      }),
    }
  );
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    return json({ error: 'firestore_error', message: errText }, 502);
  }
  const rows = await res.json();
  const mail = (rows || [])
    .filter((r) => r.document)
    .map((r) => ({ id: r.document.name.split('/').pop(), ...fsFieldsToPlain(r.document.fields) }));
  return json({ mail });
}

/// [body] alanları: target (uid ya da "all", ZORUNLU), title/body (TR,
/// ZORUNLU), titleEn/bodyEn (opsiyonel — boşsa istemci TR metni kullanır,
/// bkz. MailItem._fromDoc), giftType ("none"|"points"|"publishCredit",
/// varsayılan "none"), giftAmount (giftType "none" değilse ZORUNLU, > 0),
/// expiresDays (opsiyonel — verilirse mesaj o kadar gün sonra istemci
/// tarafında otomatik gizlenir, bkz. mailbox_service.dart > watchInbox).
async function handleAdminMailCreate(body, env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'not_configured', message: 'FIREBASE_SERVICE_ACCOUNT_JSON tanımlı değil.' }, 501);
  }
  const target = (body.target || '').trim();
  const title = (body.title || '').trim();
  const bodyText = (body.body || '').trim();
  const giftType = MAIL_GIFT_TYPES.includes(body.giftType) ? body.giftType : 'none';
  const giftAmount = giftType === 'none' ? 0 : Math.max(0, Math.trunc(Number(body.giftAmount) || 0));

  if (!target) return json({ error: 'target zorunlu ("all" ya da bir uid)' }, 400);
  if (!title || !bodyText) return json({ error: 'title ve body zorunlu' }, 400);
  if (giftType !== 'none' && giftAmount <= 0) {
    return json({ error: 'giftAmount, giftType "none" değilse 0\'dan büyük olmalı' }, 400);
  }

  const now = new Date();
  const doc = {
    target,
    title,
    titleEn: (body.titleEn || '').trim() || title,
    body: bodyText,
    bodyEn: (body.bodyEn || '').trim() || bodyText,
    giftType,
    giftAmount,
    createdAt: now.toISOString(),
  };
  const expiresDays = Math.trunc(Number(body.expiresDays) || 0);
  if (expiresDays > 0) {
    doc.expiresAt = new Date(now.getTime() + expiresDays * 86400000).toISOString();
  }

  const token = await firestoreAccessToken(env);
  const projectId = firestoreProjectId(env);
  const fields = plainToFsFields(doc);
  // ISO string tarihleri Firestore'un timestampValue'suna çevir — istemci
  // tarafı (mailbox_service.dart) `Timestamp` bekliyor, düz string değil.
  fields.createdAt = { timestampValue: doc.createdAt };
  if (doc.expiresAt) fields.expiresAt = { timestampValue: doc.expiresAt };

  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/mailbox`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    }
  );
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    return json({ error: 'firestore_error', message: errText }, 502);
  }
  const created = await res.json();
  return json({ ok: true, id: created.name.split('/').pop() });
}

async function handleAdminMailDelete(mailId, env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'not_configured', message: 'FIREBASE_SERVICE_ACCOUNT_JSON tanımlı değil.' }, 501);
  }
  const token = await firestoreAccessToken(env);
  const projectId = firestoreProjectId(env);
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/mailbox/${mailId}`,
    { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } }
  );
  if (!res.ok && res.status !== 404) {
    const errText = await res.text().catch(() => '');
    return json({ error: 'firestore_error', message: errText }, 502);
  }
  return json({ ok: true });
}

/// Panelin ana ekranında gösterilecek 5-6 özet rakam. Toplam ziyaret gibi
/// alanlar zaten sites tablosunda tutulduğu için ek bir tablo/join gerekmez;
/// bugünkü toplam ziyaret için site_daily_visits'teki bugünün satırları toplanır.
async function handleAdminSummary(env) {
  const today = new Date().toISOString().slice(0, 10);
  const [siteCounts, pending, visitsToday, visitsTotal] = await Promise.all([
    env.DB.prepare('SELECT COUNT(*) AS total, SUM(disabled) AS disabledCount FROM sites').first(),
    env.DB.prepare("SELECT COUNT(*) AS total FROM reports WHERE status = 'pending'").first(),
    env.DB.prepare('SELECT SUM(count) AS total FROM site_daily_visits WHERE date = ?').bind(today).first(),
    env.DB.prepare('SELECT SUM(visit_count) AS total FROM sites').first(),
  ]);
  const totalSites = siteCounts?.total || 0;
  const disabledSites = siteCounts?.disabledCount || 0;
  return json({
    totalSites,
    liveSites: totalSites - disabledSites,
    disabledSites,
    pendingReports: pending?.total || 0,
    visitsToday: visitsToday?.total || 0,
    visitsAllTime: visitsTotal?.total || 0,
  });
}

/// Tek bir sitenin detayı: site satırı + kendine ait (tüm durumlardaki)
/// şikayetler + son 14 günün günlük ziyaret dökümü (grafik/liste için).
async function handleAdminSiteDetail(siteId, env) {
  const site = await env.DB.prepare('SELECT * FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found' }, 404);
  const [{ results: reports }, { results: dailyVisits }] = await Promise.all([
    env.DB.prepare('SELECT * FROM reports WHERE site_id = ? ORDER BY created_at DESC').bind(siteId).all(),
    env.DB.prepare('SELECT date, count FROM site_daily_visits WHERE site_id = ? ORDER BY date DESC LIMIT 14').bind(siteId).all(),
  ]);
  return json({ site, reports, dailyVisits });
}

/// Admin panelinden GERÇEK/KALICI silme — disable'ın aksine geri dönüşü
/// yoktur (R2 dosyaları + D1 satırı tamamen kaldırılır). Mevcut
/// handleUnpublish ile AYNI mantığı kullanır (bkz. DELETE /api/sites/:id),
/// tek fark burada admin token zorunlu — o uç noktayı site sahibi kendi
/// cihazından çağırıyor, bunu ise moderatör başka birinin sitesi için çağırır.
async function handleAdminHardDelete(siteId, env) {
  return handleUnpublish(siteId, env);
}

async function handleAdminReports(env) {
  // pending raporu, ilgili sitenin güncel durumuyla (subdomain, disabled?) birlikte döner
  // -> admin panelinde ek sorgu yapmadan "siteyi kapat" butonunu göstermek için.
  const { results } = await env.DB
    .prepare(
      `SELECT r.*, s.subdomain, s.disabled AS site_disabled
       FROM reports r LEFT JOIN sites s ON s.id = r.site_id
       WHERE r.status = 'pending'
       ORDER BY r.created_at DESC LIMIT 200`
    )
    .all();
  return json({ reports: results });
}

/// Bir şikayeti ASILSIZ/incelendi olarak işaretler — [handleAdminDisable]'ın
/// aksine site KAPATILMAZ, sadece bu TEK şikayet 'pending' listesinden
/// kalkar (bkz. ADMIN_HTML > dismissReport). Site zaten kapatılırken TÜM
/// şikayetleri 'reviewed' yapan handleAdminDisable'dan farklı olarak burada
/// tek bir rapor id'si hedeflenir, geri kalan aynı siteye ait bekleyen
/// şikayetler etkilenmez.
async function handleAdminReportDismiss(reportId, env) {
  const result = await env.DB.prepare('UPDATE reports SET status = "dismissed" WHERE id = ?').bind(reportId).run();
  if (!result.meta || result.meta.changes === 0) {
    return json({ error: 'not_found' }, 404);
  }
  return json({ ok: true });
}

async function handleAdminSites(request, env) {
  // ?search= subdomain'de KISMİ eşleşme (LIKE %...%), ?status=live|disabled
  // ile filtrelenebilir — panelde 200 site sınırını aşan hesaplarda belirli
  // bir siteyi bulmak için (bkz. ADMIN_HTML > siteSearchInput/siteStatusFilter).
  // ?offset= ile sayfalama: "Daha fazla yükle" butonu her tıklamada offset'i
  // 200 artırarak aynı search/status filtresiyle tekrar çağırır (bkz.
  // ADMIN_HTML > loadMoreSites). total da dönülür ki panelde "X / Y
  // gösteriliyor" yazılabilsin. Hiçbir param yoksa eski davranışla BİREBİR
  // aynı: son 200 site, en yeni önde.
  const url = new URL(request.url);
  const search = url.searchParams.get('search')?.trim();
  const status = url.searchParams.get('status');
  const offset = Math.max(0, parseInt(url.searchParams.get('offset'), 10) || 0);
  const LIMIT = 200;

  const conditions = [];
  const params = [];
  if (search) {
    conditions.push('subdomain LIKE ?');
    params.push(`%${search}%`);
  }
  if (status === 'live') conditions.push('disabled = 0');
  else if (status === 'disabled') conditions.push('disabled = 1');
  const whereClause = conditions.length ? ' WHERE ' + conditions.join(' AND ') : '';

  let query = 'SELECT * FROM sites' + whereClause + ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  const countQuery = 'SELECT COUNT(*) AS total FROM sites' + whereClause;

  const stmt = env.DB.prepare(query).bind(...params, LIMIT, offset);
  const countStmt = env.DB.prepare(countQuery);
  const [{ results }, totalRow] = await Promise.all([
    stmt.all(),
    (params.length ? countStmt.bind(...params) : countStmt).first(),
  ]);
  return json({ sites: results, total: totalRow?.total || 0, offset, limit: LIMIT });
}

async function handleAdminDisable(siteId, reason, env) {
  const site = await env.DB.prepare('SELECT * FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found' }, 404);

  const now = new Date().toISOString();
  await env.DB.prepare(
    'UPDATE sites SET disabled = 1, disabled_reason = ?, disabled_at = ? WHERE id = ?'
  ).bind(reason, now, siteId).run();
  await env.DB.prepare('UPDATE reports SET status = "reviewed" WHERE site_id = ?').bind(siteId).run();

  let emailResult = { attempted: false };
  if (site.owner_email) {
    emailResult = await sendOwnerDisabledEmail({ toEmail: site.owner_email, subdomain: site.subdomain, reason, env });
    await env.DB.prepare('UPDATE sites SET owner_notified = ? WHERE id = ?')
      .bind(emailResult.sent ? 1 : 0, siteId).run();
  }

  return json({ ok: true, ownerEmail: site.owner_email || null, emailResult });
}

async function handleAdminEnable(siteId, env) {
  const site = await env.DB.prepare('SELECT id FROM sites WHERE id = ?').bind(siteId).first();
  if (!site) return json({ error: 'not_found' }, 404);
  await env.DB.prepare(
    'UPDATE sites SET disabled = 0, disabled_reason = NULL, disabled_at = NULL WHERE id = ?'
  ).bind(siteId).run();
  return json({ ok: true });
}

/**
 * Site kapatılınca sahibine bilgilendirme e-postası — Resend API kullanır
 * (https://resend.com, ücretsiz katmanı ayda 3.000 mail'e izin veriyor,
 * kurulumu tek bir API key). env.RESEND_API_KEY secret'ı tanımlı değilse
 * (veya site sahibi e-postasını hiç vermediyse) bu adım sessizce atlanır —
 * site yine de kapatılır, sadece bildirim gitmez.
 *
 * Başka bir sağlayıcı kullanmak istersen (SendGrid, Postmark, Mailgun...)
 * sadece bu fonksiyonun içini değiştirmen yeterli, geri kalan akış aynı kalır.
 */
async function sendOwnerDisabledEmail({ toEmail, subdomain, reason, env }) {
  if (!env.RESEND_API_KEY) return { attempted: false, sent: false, note: 'RESEND_API_KEY tanımlı değil' };

  const fromAddress = env.NOTIFY_FROM_EMAIL || 'Sitora <bildirim@sitora.app>';
  const subject = 'Sitora — Yayınladığın site kaldırıldı';
  const text =
    `Merhaba,\n\n` +
    `"${subdomain}" adresinde yayınladığın site, gelen bir şikayet incelendikten sonra kaldırıldı.\n\n` +
    `Gerekçe: ${reason}\n\n` +
    `Bunun bir hata olduğunu düşünüyorsan veya içeriği düzeltip tekrar yayınlamak istiyorsan ` +
    `bu e-postaya yanıt verebilirsin.\n\n` +
    `Sitora`;

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from: fromAddress, to: toEmail, subject, text }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      return { attempted: true, sent: false, status: res.status, body };
    }
    return { attempted: true, sent: true };
  } catch (e) {
    return { attempted: true, sent: false, error: String(e) };
  }
}

async function serveHostedSite(pathname, env) {
  // /s/kuaforum/urunler.html -> slug = "kuaforum", filePath = "urunler.html"
  const parts = pathname.split('/').filter(Boolean); // ["s", "kuaforum", "urunler.html"]
  const subdomain = parts[1];
  if (!subdomain) return new Response('404', { status: 404 });
  const filePath = parts.slice(2).join('/');

  const site = await env.DB.prepare('SELECT * FROM sites WHERE subdomain = ?').bind(subdomain).first();
  if (!site) return new Response('Site bulunamadı', { status: 404 });
  if (site.disabled) {
    return new Response('Bu site bir şikayet üzerine incelenip yayından kaldırıldı.', { status: 410 });
  }

  let path = filePath === '' ? 'index.html' : filePath;
  let object = await env.BUCKET.get(site.r2_prefix + path);
  if (!object && !path.includes('.')) {
    object = await env.BUCKET.get(site.r2_prefix + path + '.html');
  }
  if (!object) return new Response('404', { status: 404 });

  return new Response(object.body, {
    headers: {
      'Content-Type': object.httpMetadata?.contentType || guessContentType(path),
      'Cache-Control': 'public, max-age=300',
    },
  });
}

function guessContentType(path) {
  if (path.endsWith('.html')) return 'text/html; charset=utf-8';
  if (path.endsWith('.css')) return 'text/css; charset=utf-8';
  if (path.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (path.endsWith('.json')) return 'application/json; charset=utf-8';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

// ============================================================================
// /admin — token korumalı, tek dosyalık basit moderasyon paneli.
// Worker'ın kendi origin'inden servis edilir, ekstra hosting gerekmez.
// Token tarayıcıda sadece sessionStorage'da tutulur (sekme kapanınca gider).
// ============================================================================
const ADMIN_HTML = `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Sitora — Moderasyon Paneli</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; background:#0f1115; color:#e7e9ee; margin:0; padding:20px; }
  h1 { font-size:18px; margin:0 0 4px; }
  .sub { color:#9aa0ab; font-size:13px; margin-bottom:20px; }
  #gate { max-width:360px; margin:60px auto; text-align:center; }
  #gate input { width:100%; padding:10px; border-radius:8px; border:1px solid #333; background:#1a1d24; color:#fff; margin-bottom:10px; box-sizing:border-box; }
  #gate button, .btn { padding:8px 14px; border-radius:8px; border:none; background:#3b82f6; color:#fff; cursor:pointer; font-size:13px; }
  .btn.danger { background:#b91c1c; }
  .btn.ghost { background:#1a1d24; border:1px solid #333; color:#e7e9ee; }
  section { margin-bottom:28px; }
  .card { background:#171a21; border:1px solid #262a33; border-radius:10px; padding:14px; margin-bottom:10px; }
  .row { display:flex; justify-content:space-between; align-items:flex-start; gap:10px; flex-wrap:wrap; }
  .tag { display:inline-block; font-size:11px; padding:2px 8px; border-radius:999px; background:#262a33; margin-right:6px; }
  .tag.pending { background:#7c2d12; color:#fed7aa; }
  .tag.disabled { background:#450a0a; color:#fecaca; }
  .tag.live { background:#052e16; color:#bbf7d0; }
  .tag.hits { background:#1e293b; color:#93c5fd; }
  .meta { color:#9aa0ab; font-size:12px; margin-top:6px; }
  .empty { color:#9aa0ab; font-size:13px; }
  a { color:#93c5fd; }
  .summary { display:flex; gap:10px; flex-wrap:wrap; margin-bottom:20px; }
  .stat { background:#171a21; border:1px solid #262a33; border-radius:10px; padding:12px 18px; min-width:110px; }
  .stat .n { font-size:22px; font-weight:700; }
  .stat .l { font-size:11px; color:#9aa0ab; margin-top:2px; }
  .searchbar { display:flex; gap:8px; margin-bottom:12px; }
  .searchbar input { flex:1; padding:8px 10px; border-radius:8px; border:1px solid #333; background:#1a1d24; color:#fff; }
  .searchbar select { padding:8px 10px; border-radius:8px; border:1px solid #333; background:#1a1d24; color:#fff; }
  .field-row { display:flex; align-items:center; gap:8px; margin-top:6px; }
  .field-row label { font-size:12px; color:#9aa0ab; width:160px; }
  .field-row input[type=number] { width:90px; padding:6px 8px; border-radius:6px; border:1px solid #333; background:#1a1d24; color:#fff; }
  .visits-list { display:flex; gap:4px; flex-wrap:wrap; margin-top:8px; }
  .visits-list span { background:#1e293b; color:#93c5fd; font-size:11px; padding:2px 6px; border-radius:6px; }
  details.site-card summary { cursor:pointer; list-style:none; }
  details.site-card summary::-webkit-details-marker { display:none; }
  .detail-body { margin-top:10px; padding-top:10px; border-top:1px solid #262a33; }
</style>
</head>
<body>

<div id="gate">
  <h1>Sitora Moderasyon</h1>
  <p class="sub">Devam etmek için admin token'ı gir</p>
  <input id="tokenInput" type="password" placeholder="ADMIN_TOKEN" />
  <button onclick="saveToken()">Giriş yap</button>
</div>

<div id="panel" style="display:none">
  <h1>Sitora Moderasyon Paneli</h1>
  <p class="sub">· <a href="#" onclick="logout()">çıkış</a></p>

  <section>
    <h2>Özet</h2>
    <div id="summary" class="summary"><p class="empty">Yükleniyor…</p></div>
  </section>

  <section>
    <h2>Kullanıcı ara (puan / kota düzelt)</h2>
    <div class="searchbar">
      <input id="userEmailInput" type="text" placeholder="kullanici@ornek.com" />
      <button class="btn" onclick="searchUser()">Ara</button>
    </div>
    <div id="userResult"></div>
  </section>

  <section>
    <h2>Bildirim / Hediye Gönder</h2>
    <p class="sub">Herkese ya da tek bir kullanıcıya (uid) mesaj + opsiyonel puan/yayın hakkı hediyesi gönder. Kullanıcı uygulamadaki gelen kutusundan (zarf ikonu) teslim alır.</p>
    <div class="card">
      <div class="field-row"><label>Hedef</label>
        <select id="mailTarget" onchange="document.getElementById('mailUidRow').style.display = this.value==='uid' ? 'flex' : 'none'">
          <option value="all">Herkese</option>
          <option value="uid">Tek kullanıcı (uid)</option>
        </select>
      </div>
      <div class="field-row" id="mailUidRow" style="display:none"><label>Kullanıcı uid</label><input id="mailUid" type="text" style="flex:1" placeholder="Firestore users/{uid}" /></div>
      <div class="field-row"><label>Başlık (TR)</label><input id="mailTitle" type="text" style="flex:1" placeholder="Bir hediyen var! 🎁" /></div>
      <div class="field-row"><label>Başlık (EN, ops.)</label><input id="mailTitleEn" type="text" style="flex:1" placeholder="boş bırakılırsa TR kullanılır" /></div>
      <div class="field-row"><label>Mesaj (TR)</label><input id="mailBody" type="text" style="flex:1" placeholder="Sadakatin için 10 puan hediye ettik." /></div>
      <div class="field-row"><label>Mesaj (EN, ops.)</label><input id="mailBodyEn" type="text" style="flex:1" placeholder="boş bırakılırsa TR kullanılır" /></div>
      <div class="field-row"><label>Hediye türü</label>
        <select id="mailGiftType" onchange="document.getElementById('mailGiftAmountRow').style.display = this.value==='none' ? 'none' : 'flex'">
          <option value="none">Sadece mesaj (hediyesiz)</option>
          <option value="points">Puan</option>
          <option value="publishCredit">Yayın hakkı</option>
        </select>
      </div>
      <div class="field-row" id="mailGiftAmountRow" style="display:none"><label>Miktar</label><input id="mailGiftAmount" type="number" value="10" /></div>
      <div class="field-row"><label>Süre (gün, ops.)</label><input id="mailExpiresDays" type="number" placeholder="boş = süresiz" /></div>
      <div style="margin-top:10px"><button class="btn" onclick="sendMail()">Gönder</button></div>
      <div id="mailSendResult" class="meta"></div>
    </div>
    <div id="mailList"><p class="empty">Yükleniyor…</p></div>
  </section>

  <section>
    <h2>Bekleyen şikayetler</h2>
    <div id="reports"><p class="empty">Yükleniyor…</p></div>
  </section>

  <section>
    <h2>Tüm siteler</h2>
    <p class="sub">Detay/ziyaret dökümü + kalıcı silme için bir siteye tıkla.</p>
    <div class="searchbar">
      <input id="siteSearchInput" type="text" placeholder="subdomain ara (örn. kuaforum)" onkeydown="if(event.key==='Enter') refresh()" />
      <select id="siteStatusFilter">
        <option value="all">Tümü</option>
        <option value="live">Yayında</option>
        <option value="disabled">Kapalı</option>
      </select>
      <button class="btn" onclick="refresh()">Ara</button>
    </div>
    <div id="sitesCount" class="meta"></div>
    <div id="sites"><p class="empty">Yükleniyor…</p></div>
    <div id="sitesLoadMoreWrap" style="margin-top:10px; display:none">
      <button class="btn ghost" id="sitesLoadMoreBtn" onclick="loadMoreSites()">Daha fazla yükle</button>
    </div>
  </section>
</div>

<script>
function saveToken() {
  const t = document.getElementById('tokenInput').value.trim();
  if (!t) return;
  sessionStorage.setItem('sitora_admin_token', t);
  boot();
}
function logout() {
  sessionStorage.removeItem('sitora_admin_token');
  location.reload();
}
function token() { return sessionStorage.getItem('sitora_admin_token'); }

async function api(path, opts) {
  const res = await fetch(path, Object.assign({}, opts, {
    headers: Object.assign({ 'x-admin-token': token(), 'Content-Type': 'application/json' }, (opts && opts.headers) || {})
  }));
  if (res.status === 401) { sessionStorage.removeItem('sitora_admin_token'); location.reload(); throw new Error('unauthorized'); }
  return res.json();
}

async function disableSite(siteId) {
  const reason = prompt('Kaldırma gerekçesi (site sahibine e-posta ile gönderilecek):', 'Kural ihlali');
  if (reason === null) return;
  await api('/admin/sites/' + encodeURIComponent(siteId) + '/disable', { method: 'POST', body: JSON.stringify({ reason }) });
  await refresh();
}
async function enableSite(siteId) {
  if (!confirm('Bu site tekrar yayına alınsın mı?')) return;
  await api('/admin/sites/' + encodeURIComponent(siteId) + '/enable', { method: 'POST' });
  await refresh();
}
async function hardDeleteSite(siteId) {
  if (!confirm('Bu siteyi KALICI olarak silmek istediğine emin misin? Geri dönüşü YOK (R2 dosyaları + veritabanı kaydı tamamen silinir).')) return;
  await api('/admin/sites/' + encodeURIComponent(siteId) + '/delete', { method: 'POST' });
  await refresh();
}

async function dismissReport(reportId) {
  if (!confirm('Bu şikayeti asılsız/incelendi olarak işaretleyip listeden kaldırmak istiyor musun? Site KAPATILMAZ, sadece bu şikayet kalkar.')) return;
  await api('/admin/reports/' + encodeURIComponent(reportId) + '/dismiss', { method: 'POST' });
  await refresh();
}

async function loadSummary() {
  const s = await api('/admin/summary').catch(() => null);
  const el = document.getElementById('summary');
  if (!s) { el.innerHTML = '<p class="empty">Yüklenemedi.</p>'; return; }
  const stat = (n, l) => '<div class="stat"><div class="n">' + n + '</div><div class="l">' + l + '</div></div>';
  el.innerHTML =
    stat(s.totalSites, 'toplam site') +
    stat(s.liveSites, 'yayında') +
    stat(s.disabledSites, 'kapalı') +
    stat(s.pendingReports, 'bekleyen şikayet') +
    stat(s.visitsToday, 'bugünkü ziyaret') +
    stat(s.visitsAllTime, 'toplam ziyaret');
}

async function searchUser() {
  const email = document.getElementById('userEmailInput').value.trim();
  const el = document.getElementById('userResult');
  if (!email) return;
  el.innerHTML = '<p class="empty">Aranıyor…</p>';
  const data = await api('/admin/users?email=' + encodeURIComponent(email)).catch((e) => ({ error: String(e) }));
  if (data.error) { el.innerHTML = '<p class="empty">' + esc(data.message || data.error) + '</p>'; return; }
  if (!data.users || !data.users.length) { el.innerHTML = '<p class="empty">Bu e-postayla kullanıcı bulunamadı.</p>'; return; }

  el.innerHTML = '';
  data.users.forEach(u => {
    const div = document.createElement('div');
    div.className = 'card';
    div.innerHTML =
      '<div class="meta">uid: ' + esc(u.uid) + ' · ' + esc(u.email || '') + '</div>' +
      numberField('fc_' + u.uid, 'Aylık form kotası', u.formCredits ?? 0) +
      numberField('pp_' + u.uid, 'Satın alınmış puan', u.purchasedPoints ?? 0) +
      numberField('epc_' + u.uid, 'Ekstra yayın hakkı (bakiye)', u.extraPublishCredits ?? 0) +
      boolField('fspu_' + u.uid, 'Ücretsiz ilk yayın hakkı kullanıldı', u.freeSitePublishUsed ?? false) +
      '<div style="margin-top:10px"><button class="btn" onclick="saveUser(' + JSON.stringify(u.uid) + ')">Kaydet</button></div>' +
      '<div id="projects_' + u.uid + '" style="margin-top:14px"><p class="empty">Projeler yükleniyor…</p></div>';
    el.appendChild(div);
    loadUserProjects(u.uid);
  });
}

/// Bir puan/kota alanı için: sayı input'u + hızlı artır/azalt butonları
/// (-5/-1/+1/+5) + özel miktar girip ekle/çıkar yapabileceğin küçük bir kutu.
/// Hiçbiri sunucuya hemen yazmaz — kaydetmek için hâlâ "Kaydet" butonuna
/// basılması gerekir, böylece birden fazla alanı aynı anda ayarlayıp TEK
/// istekte kaydedebilirsin.
function numberField(id, label, value) {
  return '<div class="field-row"><label>' + label + '</label>' +
    '<button class="btn ghost" type="button" onclick="bumpField(' + JSON.stringify(id) + ',-5)">-5</button>' +
    '<button class="btn ghost" type="button" onclick="bumpField(' + JSON.stringify(id) + ',-1)">-1</button>' +
    '<input type="number" id="' + id + '" value="' + value + '" />' +
    '<button class="btn ghost" type="button" onclick="bumpField(' + JSON.stringify(id) + ',1)">+1</button>' +
    '<button class="btn ghost" type="button" onclick="bumpField(' + JSON.stringify(id) + ',5)">+5</button>' +
    '</div>' +
    '<div class="field-row">' +
    '<label>Özel miktar</label>' +
    '<input type="number" id="' + id + '_custom" placeholder="ör. 20" style="width:80px" />' +
    '<button class="btn ghost" type="button" onclick="bumpFieldCustom(' + JSON.stringify(id) + ',1)">Ekle</button>' +
    '<button class="btn ghost" type="button" onclick="bumpFieldCustom(' + JSON.stringify(id) + ',-1)">Çıkar</button>' +
    '</div>';
}

/// Boolean bir alan için: etiket + checkbox. numberField'ın aksine anlık
/// sunucuya yazmaz — diğer alanlarla birlikte "Kaydet"e basınca saveUser
/// tarafından okunur (bkz. aşağıdaki saveUser).
function boolField(id, label, value) {
  return '<div class="field-row"><label>' + label + '</label>' +
    '<input type="checkbox" id="' + id + '"' + (value ? ' checked' : '') + ' />' +
    '</div>';
}

function bumpField(id, delta) {
  const input = document.getElementById(id);
  const current = parseInt(input.value, 10) || 0;
  input.value = Math.max(0, current + delta);
}

function bumpFieldCustom(id, sign) {
  const amount = parseInt(document.getElementById(id + '_custom').value, 10);
  if (!amount || amount < 0) { alert('Önce geçerli, pozitif bir miktar gir.'); return; }
  bumpField(id, sign * amount);
}

async function loadUserProjects(uid) {
  const el = document.getElementById('projects_' + uid);
  const data = await api('/admin/users/' + encodeURIComponent(uid) + '/projects').catch((e) => ({ error: String(e) }));
  if (data.error) { el.innerHTML = '<p class="empty">' + esc(data.message || data.error) + '</p>'; return; }
  if (!data.projects || !data.projects.length) { el.innerHTML = '<p class="empty">Bu kullanıcının projesi yok.</p>'; return; }

  el.innerHTML = '<strong style="font-size:13px">Projeler — rozet/yayın hakkı ELLE tanımla</strong>';
  data.projects.forEach(p => {
    const row = document.createElement('div');
    row.className = 'meta';
    row.style.marginTop = '8px';
    row.innerHTML =
      esc(p.name || p.id) + (p.publishedSubdomain ? ' · /s/' + esc(p.publishedSubdomain) + '/' : '') + '<br/>' +
      '<span class="tag ' + (p.watermarkRemoved ? 'live' : '') + '">' + (p.watermarkRemoved ? 'rozet kaldırıldı' : 'rozetli') + '</span>' +
      '<span class="tag ' + (p.publishRightGranted ? 'live' : '') + '">' + (p.publishRightGranted ? 'yayın hakkı var' : 'yayın hakkı yok') + '</span><br/>' +
      (p.watermarkRemoved
        ? '<button class="btn ghost" onclick="setProjectRight(' + JSON.stringify(uid) + ',' + JSON.stringify(p.id) + ',\'watermarkRemoved\',false)">Rozet kaldırma hakkını geri al</button>'
        : '<button class="btn ghost" onclick="setProjectRight(' + JSON.stringify(uid) + ',' + JSON.stringify(p.id) + ',\'watermarkRemoved\',true)">Rozet kaldırma hakkı ver</button>') + ' ' +
      (p.publishRightGranted
        ? '<button class="btn ghost" onclick="setProjectRight(' + JSON.stringify(uid) + ',' + JSON.stringify(p.id) + ',\'publishRightGranted\',false)">Yayın hakkını geri al</button>'
        : '<button class="btn ghost" onclick="setProjectRight(' + JSON.stringify(uid) + ',' + JSON.stringify(p.id) + ',\'publishRightGranted\',true)">Yayın hakkı ver</button>');
    el.appendChild(row);
  });
}

async function setProjectRight(uid, projectId, field, value) {
  const label = field === 'watermarkRemoved' ? 'rozet kaldırma hakkını' : 'yayın hakkını';
  const msg = value
    ? 'Bu kullanıcıya ' + label + ' TANIMLAMAK üzeresin. Devam edilsin mi?'
    : 'Bu kullanıcıdan ' + label + ' GERİ ALMAK üzeresin — eğer parayla satın aldıysa bu tartışmalı bir işlem olabilir. Devam edilsin mi?';
  if (!confirm(msg)) return;
  await api('/admin/users/' + encodeURIComponent(uid) + '/projects/' + encodeURIComponent(projectId), {
    method: 'PATCH',
    body: JSON.stringify({ [field]: value }),
  });
  await loadUserProjects(uid);
}

async function saveUser(uid) {
  const patch = {
    formCredits: parseInt(document.getElementById('fc_' + uid).value, 10) || 0,
    purchasedPoints: parseInt(document.getElementById('pp_' + uid).value, 10) || 0,
    extraPublishCredits: parseInt(document.getElementById('epc_' + uid).value, 10) || 0,
    freeSitePublishUsed: document.getElementById('fspu_' + uid).checked,
  };
  await api('/admin/users/' + encodeURIComponent(uid), { method: 'PATCH', body: JSON.stringify(patch) });
  alert('Kaydedildi.');
}

async function loadSiteDetail(siteId) {
  const box = document.getElementById('detail_' + siteId);
  if (box.dataset.loaded === '1') return;
  box.dataset.loaded = '1';
  const { site, reports, dailyVisits } = await api('/admin/sites/' + encodeURIComponent(siteId));
  const visitsHtml = dailyVisits.length
    ? '<div class="visits-list">' + dailyVisits.map(v => '<span>' + esc(v.date) + ': ' + v.count + '</span>').join('') + '</div>'
    : '<p class="empty">Henüz günlük ziyaret verisi yok.</p>';
  const reportsHtml = reports.length
    ? reports.map(r => '<div class="meta">[' + esc(r.status) + '] ' + esc(r.reason) + ' — ' + esc(r.details) + ' · ' + esc(r.created_at) + '</div>').join('')
    : '<p class="empty">Bu siteyle ilgili şikayet yok.</p>';
  box.innerHTML =
    '<div class="detail-body">' +
    '<strong>Son 14 gün ziyaret</strong>' + visitsHtml +
    '<strong style="display:block;margin-top:10px">Şikayet geçmişi</strong>' + reportsHtml +
    '<div style="margin-top:10px"><button class="btn danger" onclick="hardDeleteSite(' + JSON.stringify(siteId) + ')">Kalıcı sil</button></div>' +
    '</div>';
}

async function sendMail() {
  const target = document.getElementById('mailTarget').value === 'uid'
    ? document.getElementById('mailUid').value.trim()
    : 'all';
  const title = document.getElementById('mailTitle').value.trim();
  const body = document.getElementById('mailBody').value.trim();
  const giftType = document.getElementById('mailGiftType').value;
  const giftAmount = document.getElementById('mailGiftAmount').value;
  const expiresDays = document.getElementById('mailExpiresDays').value;
  const resultEl = document.getElementById('mailSendResult');

  if (!target) { resultEl.textContent = 'Hedef uid boş olamaz.'; return; }
  if (!title || !body) { resultEl.textContent = 'Başlık ve mesaj zorunlu.'; return; }

  resultEl.textContent = 'Gönderiliyor…';
  const data = await api('/admin/mail', {
    method: 'POST',
    body: JSON.stringify({
      target,
      title,
      titleEn: document.getElementById('mailTitleEn').value.trim(),
      body,
      bodyEn: document.getElementById('mailBodyEn').value.trim(),
      giftType,
      giftAmount: giftAmount ? parseInt(giftAmount, 10) : 0,
      expiresDays: expiresDays ? parseInt(expiresDays, 10) : 0,
    }),
  }).catch((e) => ({ error: String(e) }));

  if (data.error) { resultEl.textContent = 'Hata: ' + (data.message || data.error); return; }
  resultEl.textContent = 'Gönderildi ✅';
  document.getElementById('mailTitle').value = '';
  document.getElementById('mailTitleEn').value = '';
  document.getElementById('mailBody').value = '';
  document.getElementById('mailBodyEn').value = '';
  await loadMailList();
}

async function deleteMail(mailId) {
  if (!confirm('Bu mesajı silmek istediğine emin misin? Zaten teslim alınmışsa hediye geri alınmaz, sadece mesaj listeden kalkar.')) return;
  await api('/admin/mail/' + encodeURIComponent(mailId) + '/delete', { method: 'POST' });
  await loadMailList();
}

async function loadMailList() {
  const el = document.getElementById('mailList');
  const data = await api('/admin/mail').catch((e) => ({ error: String(e) }));
  if (data.error) { el.innerHTML = '<p class="empty">' + esc(data.message || data.error) + '</p>'; return; }
  const mail = data.mail || [];
  if (!mail.length) { el.innerHTML = '<p class="empty">Henüz gönderilmiş mesaj yok.</p>'; return; }
  const giftLabel = (m) => m.giftType === 'points' ? ('+' + m.giftAmount + ' puan')
    : m.giftType === 'publishCredit' ? ('+' + m.giftAmount + ' yayın hakkı') : 'hediyesiz';
  el.innerHTML = '';
  mail.forEach(m => {
    const div = document.createElement('div');
    div.className = 'card';
    div.innerHTML =
      '<div class="row"><div>' +
      '<span class="tag ' + (m.target === 'all' ? 'live' : 'pending') + '">' + (m.target === 'all' ? 'herkese' : esc(m.target)) + '</span>' +
      '<span class="tag hits">' + esc(giftLabel(m)) + '</span>' +
      '<strong style="display:block;margin-top:6px">' + esc(m.title) + '</strong>' +
      '<div class="meta">' + esc(m.body) + '</div>' +
      '<div class="meta">' + esc(m.createdAt) + (m.expiresAt ? ' · bitiş: ' + esc(m.expiresAt) : '') + '</div>' +
      '</div>' +
      '<button class="btn danger" onclick="deleteMail(' + JSON.stringify(m.id) + ')">Sil</button>' +
      '</div>';
    el.appendChild(div);
  });
}

function esc(s) { return (s == null ? '' : String(s)).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

// Sayfalama durumu: /admin/sites her seferinde en fazla 200 site döner.
// "Daha fazla yükle" tıklandığında aynı search/status ile offset artırılıp
// tekrar çağrılır, sonuçlar mevcut listenin sonuna eklenir (bkz.
// loadMoreSites). refresh() her yeni arama/filtrede bu listeyi sıfırlar.
let sitesLoaded = [];
let sitesOffset = 0;
let sitesTotal = 0;

function currentSitesQuery() {
  const search = document.getElementById('siteSearchInput').value.trim();
  const status = document.getElementById('siteStatusFilter').value;
  return { search, status };
}

function renderSites() {
  const sEl = document.getElementById('sites');
  const countEl = document.getElementById('sitesCount');
  const moreWrap = document.getElementById('sitesLoadMoreWrap');

  countEl.textContent = sitesTotal
    ? sitesLoaded.length + ' / ' + sitesTotal + ' gösteriliyor'
    : '';

  sEl.innerHTML = sitesLoaded.length ? '' : '<p class="empty">Eşleşen site yok.</p>';
  sitesLoaded.forEach(s => {
    const details = document.createElement('details');
    details.className = 'site-card card';
    details.ontoggle = function () { if (this.open) loadSiteDetail(s.id); };
    const domainTag = s.custom_domain
      ? '<span class="tag ' + (s.domain_status === 'active' ? 'live' : s.domain_status === 'error' ? 'disabled' : 'pending') + '">🌐 ' + esc(s.custom_domain) + (s.domain_status ? ' · ' + esc(s.domain_status) : '') + '</span>'
      : '';
    details.innerHTML =
      '<summary><div class="row"><div>' +
      '<span class="tag ' + (s.disabled ? 'disabled' : 'live') + '">' + (s.disabled ? 'kapalı' : 'yayında') + '</span>' +
      '<span class="tag hits">👁 ' + (s.visit_count || 0) + ' ziyaret</span>' +
      domainTag +
      '<strong>/s/' + esc(s.subdomain) + '/</strong>' +
      '<div class="meta">siteId: ' + esc(s.id) + (s.owner_email ? ' · ' + esc(s.owner_email) : ' · sahip e-postası yok') +
      (s.disabled ? ' · gerekçe: ' + esc(s.disabled_reason) + (s.owner_notified ? ' · mail gönderildi' : ' · mail gönderilemedi/atlandı') : '') +
      '</div></div>' +
      '<span onclick="event.preventDefault(); event.stopPropagation(); ' +
        (s.disabled ? 'enableSite(' + JSON.stringify(s.id) + ')' : 'disableSite(' + JSON.stringify(s.id) + ')') + '">' +
      '<button class="btn ' + (s.disabled ? 'ghost' : 'danger') + '" type="button">' + (s.disabled ? 'Tekrar yayınla' : 'Kapat') + '</button>' +
      '</span></div></summary>' +
      '<div id="detail_' + s.id + '"><p class="empty">Detay için tıkla…</p></div>';
    sEl.appendChild(details);
  });

  moreWrap.style.display = sitesLoaded.length < sitesTotal ? 'block' : 'none';
}

async function loadMoreSites() {
  const btn = document.getElementById('sitesLoadMoreBtn');
  btn.disabled = true;
  btn.textContent = 'Yükleniyor…';
  const { search, status } = currentSitesQuery();
  const qs = '?search=' + encodeURIComponent(search) + '&status=' + encodeURIComponent(status) + '&offset=' + sitesOffset;
  const { sites, total } = await api('/admin/sites' + qs);
  sitesLoaded = sitesLoaded.concat(sites);
  sitesOffset += sites.length;
  sitesTotal = total;
  btn.disabled = false;
  btn.textContent = 'Daha fazla yükle';
  renderSites();
}

async function refresh() {
  await loadSummary();
  await loadMailList();
  const { search, status } = currentSitesQuery();
  const sitesQs = '?search=' + encodeURIComponent(search) + '&status=' + encodeURIComponent(status);
  const [{ reports }, { sites, total }] = await Promise.all([api('/admin/reports'), api('/admin/sites' + sitesQs)]);

  const rEl = document.getElementById('reports');
  rEl.innerHTML = reports.length ? '' : '<p class="empty">Bekleyen şikayet yok.</p>';
  reports.forEach(r => {
    const div = document.createElement('div');
    div.className = 'card';
    div.innerHTML =
      '<div class="row"><div>' +
      '<span class="tag pending">' + esc(r.reason) + '</span>' +
      (r.site_disabled ? '<span class="tag disabled">site zaten kapalı</span>' : '') +
      '<div style="margin-top:6px">' + esc(r.details) + '</div>' +
      '<div class="meta">siteId: ' + esc(r.site_id) + (r.subdomain ? ' · /s/' + esc(r.subdomain) + '/' : '') + ' · ' + esc(r.created_at) + '</div>' +
      '</div>' +
      (r.site_disabled ? '' : '<button class="btn danger" onclick="disableSite(' + JSON.stringify(r.site_id) + ')">Siteyi kapat</button>') +
      '<button class="btn ghost" onclick="dismissReport(' + JSON.stringify(r.id) + ')">Asılsız — reddet</button>' +
      '</div>';
    rEl.appendChild(div);
  });

  // Yeni arama/filtre => baştan başla (offset sıfırlanır, liste değiştirilmez eklenmez).
  sitesLoaded = sites;
  sitesOffset = sites.length;
  sitesTotal = total;
  renderSites();
}

function boot() {
  if (!token()) return;
  document.getElementById('gate').style.display = 'none';
  document.getElementById('panel').style.display = 'block';
  refresh().catch(() => {});
}
boot();
</script>
</body>
</html>`;
