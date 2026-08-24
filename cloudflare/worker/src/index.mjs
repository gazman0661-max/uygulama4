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
 *   GET    /api/sites/:id/stats -> o siteye ait ziyaretçi sayısını JSON döner
 *                                  (bkz. Flutter: HostingService.fetchStats). siteId zaten
 *                                  siteyi yayınlayan kişide olduğu için ekstra token gerektirmez
 *                                  — tıpkı DELETE /api/sites/:id gibi.
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
 *   GET    /admin/reports       -> [x-admin-token] bekleyen şikayetleri JSON listele
 *   GET    /admin/sites         -> [x-admin-token] tüm siteleri JSON listele
 *   POST   /admin/sites/:id/disable -> [x-admin-token] siteyi YUMUŞAK kapat + sahibine mail
 *   POST   /admin/sites/:id/enable  -> [x-admin-token] kapatılan siteyi geri aç
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
    if (pathname === '/admin/reports' && request.method === 'GET') {
      return requireAdmin(request, env, () => handleAdminReports(env));
    }
    if (pathname === '/admin/sites' && request.method === 'GET') {
      return requireAdmin(request, env, () => handleAdminSites(env));
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

  await env.DB.prepare(
    'UPDATE sites SET visit_count = visit_count + 1, last_visit_at = ? WHERE id = ?'
  ).bind(new Date().toISOString(), siteId).run();

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
  return json({
    siteId,
    visitCount: site.visit_count || 0,
    lastVisitAt: site.last_visit_at || null,
    createdAt: site.created_at,
  });
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
    const accessToken = await getGoogleAccessToken(env);
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
 * env.GOOGLE_SERVICE_ACCOUNT_JSON içindeki servis hesabı anahtarıyla RS256
 * imzalı bir JWT üretip Google'ın OAuth2 token endpoint'inden geçici bir
 * access token alır (Cloudflare Workers'ta Node'un crypto modülü YOK, bu
 * yüzden imzalama Web Crypto API — crypto.subtle — ile elle yapılıyor).
 * Her çağrıda yeni token alınır; bu ölçekte (düşük hacim) önbelleğe almaya
 * gerek yok, gereksiz karmaşıklık katmamak için eklenmedi.
 */
async function getGoogleAccessToken(env) {
  const key = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT_JSON);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
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

async function handleAdminSites(env) {
  const { results } = await env.DB
    .prepare('SELECT * FROM sites ORDER BY created_at DESC LIMIT 200')
    .all();
  return json({ sites: results });
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

  const fromAddress = env.NOTIFY_FROM_EMAIL || 'Sitora AI <bildirim@sitora.app>';
  const subject = 'Sitora AI — Yayınladığın site kaldırıldı';
  const text =
    `Merhaba,\n\n` +
    `"${subdomain}" adresinde yayınladığın site, gelen bir şikayet incelendikten sonra kaldırıldı.\n\n` +
    `Gerekçe: ${reason}\n\n` +
    `Bunun bir hata olduğunu düşünüyorsan veya içeriği düzeltip tekrar yayınlamak istiyorsan ` +
    `bu e-postaya yanıt verebilirsin.\n\n` +
    `Sitora AI`;

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
  <p class="sub">Bekleyen şikayetler ve yayındaki siteler · <a href="#" onclick="logout()">çıkış</a></p>

  <section>
    <h2>Bekleyen şikayetler</h2>
    <div id="reports"><p class="empty">Yükleniyor…</p></div>
  </section>

  <section>
    <h2>Tüm siteler</h2>
    <div id="sites"><p class="empty">Yükleniyor…</p></div>
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

function esc(s) { return (s == null ? '' : String(s)).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

async function refresh() {
  const [{ reports }, { sites }] = await Promise.all([api('/admin/reports'), api('/admin/sites')]);

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
      '</div>';
    rEl.appendChild(div);
  });

  const sEl = document.getElementById('sites');
  sEl.innerHTML = sites.length ? '' : '<p class="empty">Henüz site yok.</p>';
  sites.forEach(s => {
    const div = document.createElement('div');
    div.className = 'card';
    div.innerHTML =
      '<div class="row"><div>' +
      '<span class="tag ' + (s.disabled ? 'disabled' : 'live') + '">' + (s.disabled ? 'kapalı' : 'yayında') + '</span>' +
      '<span class="tag hits">👁 ' + (s.visit_count || 0) + ' ziyaret</span>' +
      '<strong>/s/' + esc(s.subdomain) + '/</strong>' +
      '<div class="meta">siteId: ' + esc(s.id) + (s.owner_email ? ' · ' + esc(s.owner_email) : ' · sahip e-postası yok') +
      (s.disabled ? ' · gerekçe: ' + esc(s.disabled_reason) + (s.owner_notified ? ' · mail gönderildi' : ' · mail gönderilemedi/atlandı') : '') +
      '</div></div>' +
      (s.disabled
        ? '<button class="btn ghost" onclick="enableSite(' + JSON.stringify(s.id) + ')">Tekrar yayınla</button>'
        : '<button class="btn danger" onclick="disableSite(' + JSON.stringify(s.id) + ')">Kapat</button>') +
      '</div>';
    sEl.appendChild(div);
  });
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
