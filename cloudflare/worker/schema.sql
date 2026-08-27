-- Sitora Hosting — D1 şeması
-- KV değil D1 kullanılıyor: KV free tier günde 1.000 yazma ile sınırlı,
-- D1 free tier ise AYLIK 100.000 satır yazmaya izin veriyor (günlük ~3.300
-- yeni yayın demek). R2 (aylık 1M yazma) ve Worker (günlük 100K istek) zaten
-- bunun üstünde, o yüzden gerçek darboğaz burası ve bu şema onu maksimize ediyor.
--
-- Kurulum:
--   wrangler d1 create sitora-hosting
--   wrangler d1 execute sitora-hosting --file=./schema.sql

CREATE TABLE IF NOT EXISTS sites (
  id            TEXT PRIMARY KEY,        -- Flutter tarafındaki SiteProject.id
  subdomain     TEXT UNIQUE NOT NULL,    -- örn. "kuaforum" -> kuaforum.sitora.app
  r2_prefix     TEXT NOT NULL,           -- örn. "sites/<id>/"
  owner_email   TEXT,                    -- yayınlayan kişinin e-postası (opsiyonel, kaldırma bildirimi için)
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  disabled      INTEGER NOT NULL DEFAULT 0,  -- 1 = şikayet üzerine kaldırıldı
  disabled_reason TEXT,
  disabled_at   TEXT,
  owner_notified INTEGER NOT NULL DEFAULT 0, -- 1 = kaldırma e-postası gönderildi (veya denendi)
  visit_count   INTEGER NOT NULL DEFAULT 0,  -- ziyaretçi sayacı (bkz. handleHit) — sayfa yüklemesi başına +1
  last_visit_at TEXT,                        -- son ziyaretin zaman damgası (ISO 8601)

  -- "Kendi domainimi bağla" (bkz. src/index.mjs > handleDomainConnect/Status/Disconnect) --
  custom_domain      TEXT,   -- örn. "ahmetkuafor.com" ya da "www.ahmetkuafor.com" — NULL = bağlı değil
  domain_status      TEXT,   -- 'pending' | 'active' | 'error' | NULL (hiç bağlanmadıysa)
  domain_error       TEXT,   -- domain_status='error' ise Cloudflare'ın döndüğü kısa gerekçe
  cf_hostname_id     TEXT,   -- Cloudflare Custom Hostname ID'si (durum sorgulama/silme için gerekli)
  domain_connected_at TEXT   -- 1 yıllık bağlantı döngüsünün başlangıcı (ISO 8601) — ilk bağlanmada
                              -- VEYA en son "yenile"nildiğinde set edilir (bkz. handleDomainConnect /
                              -- handleDomainRenew). serveCustomDomainSite bu alanı + 365 gün ile
                              -- karşılaştırıp süresi dolmuş domain'leri GERÇEKTEN servis etmeyi durdurur
                              -- (yeni kolon eklemeye gerek yok, mevcut alan yeniden kullanıldı).
);

CREATE INDEX IF NOT EXISTS idx_sites_subdomain ON sites (subdomain);
CREATE INDEX IF NOT EXISTS idx_sites_custom_domain ON sites (custom_domain);

-- NOT: Eğer bu şema DAHA ÖNCE (aşağıdaki kolonlar eklenmeden önce) bir D1
-- veritabanına uygulandıysa, "CREATE TABLE IF NOT EXISTS" var olan tabloyu
-- DEĞİŞTİRMEZ — bu durumda eksik olan satırları tek seferlik elle çalıştır
-- (wrangler d1 execute sitora-hosting --command="..." --remote):
--   ALTER TABLE sites ADD COLUMN visit_count INTEGER NOT NULL DEFAULT 0;
--   ALTER TABLE sites ADD COLUMN last_visit_at TEXT;
--   ALTER TABLE sites ADD COLUMN custom_domain TEXT;
--   ALTER TABLE sites ADD COLUMN domain_status TEXT;
--   ALTER TABLE sites ADD COLUMN domain_error TEXT;
--   ALTER TABLE sites ADD COLUMN cf_hostname_id TEXT;
--   ALTER TABLE sites ADD COLUMN domain_connected_at TEXT;
--   CREATE INDEX IF NOT EXISTS idx_sites_custom_domain ON sites (custom_domain);

-- Günlük ziyaretçi kırılımı (bkz. handleHit / handleStatsBatch).
-- sites.visit_count zaten TOPLAM ziyareti tutuyor ama "bugün kaç kişi
-- baktı" gibi bir soruya cevap vermez — bunun için (site_id, date)
-- bazında ayrı bir sayaç gerekiyor. count her /api/hit çağrısında UPSERT
-- ile +1 artırılır (bkz. handleHit). date, worker'ın çalıştığı UTC gününe
-- göre 'YYYY-MM-DD' formatında tutulur (kullanıcının cihaz saat dilimine
-- göre DEĞİL — bu, D1'de zaman dilimi başına ayrı sorgu yazmaktan
-- kaçınmak için bilinçli bir basitleştirme; birkaç saatlik sınır kayması
-- ürün için önemli değil).
--
-- NOT: Bu tablo her /api/hit çağrısında sites.visit_count'a EK olarak
-- ikinci bir D1 yazması demek — günlük yazma bütçesini (bkz. dosya başı
-- yorumu) kabaca ikiye katlar. Trafik şu an test aşamasında düşük
-- olduğu için sorun değil; ölçek büyüdüğünde bu tabloyu Workers
-- Analytics Engine'e taşımak (D1 yazma limitine hiç dokunmaz) bir
-- sonraki adım olabilir.
CREATE TABLE IF NOT EXISTS site_daily_visits (
  site_id  TEXT NOT NULL,
  date     TEXT NOT NULL,   -- 'YYYY-MM-DD' (UTC)
  count    INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (site_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_visits_date ON site_daily_visits (date);

-- NOT: Eğer bu tablo DAHA ÖNCE (yukarıdaki satırlar eklenmeden önce) bir
-- D1 veritabanına uygulandıysa, "CREATE TABLE IF NOT EXISTS" mevcut
-- veritabanını DEĞİŞTİRMEZ — yeni bir veritabanıysa zaten otomatik
-- oluşur, var olan bir veritabanına eklemek için tek seferlik:
--   wrangler d1 execute sitora-hosting --file=./schema.sql --remote

CREATE TABLE IF NOT EXISTS reports (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  site_id       TEXT NOT NULL,
  reason        TEXT NOT NULL,
  details       TEXT NOT NULL,
  published_url TEXT,
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending | reviewed | dismissed
  created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_reports_site ON reports (site_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports (status);
