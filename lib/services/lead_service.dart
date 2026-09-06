import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead.dart';

/// ============================================================================
/// SITORA GELEN TALEPLER (LEAD INBOX) — 31.08.2026 eklendi
/// ============================================================================
/// Yayınlanan sitelerdeki "Talep Gönder" formundan (bkz.
/// templates/html/shared_html_blocks.dart > leadFormMarkup) gelen kayıtları
/// okur. Yazma tarafı UYGULAMADAN DEĞİL, ziyaretçinin tarayıcısından da
/// DEĞİL — 03.09.2026'dan itibaren Cloudflare Worker'daki POST /api/leads
/// üzerinden, servis hesabıyla yapılıyor (bkz. cloudflare/worker/src/index.mjs
/// > handleLeadCreate). Worker aynı anda site sahibine GERÇEK bir FCM push
/// bildirimi de gönderiyor. Bu sınıf hâlâ sadece OKUMA yapıyor.
///
/// Firestore şeması:
///   leads/{leadId}
///     ownerId   : string    (sitenin sahibi olan Sitora kullanıcısının uid'i)
///     siteId    : string    (SiteProject.id)
///     siteName  : string
///     name      : string    (talebi gönderen ziyaretçinin adı)
///     phone     : string
///     message   : string
///     source    : string    ('site_form')
///     read      : bool      (işletme sahibi uygulama içinde görüntüledi mi)
///     createdAt : timestamp
///
/// GÜVENLİK: leads koleksiyonuna YAZMA kimliksiz (anonim) açık — herhangi
/// bir site ziyaretçisi form doldurabilmeli. OKUMA ise sadece
/// `request.auth.uid == resource.data.ownerId` ile kısıtlı (bkz.
/// FIREBASE_SETUP.md > "leads" kuralları) — yani bir kullanıcı SADECE
/// KENDİ sitelerine gelen talepleri görebilir.
class LeadService {
  LeadService._();
  static final LeadService instance = LeadService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// [uid]'e ait TÜM sitelerdeki talepleri (en yeni en üstte) canlı dinler.
  Stream<List<Lead>> watchLeads(String uid) {
    return _db
        .collection('leads')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Lead.fromDoc).toList());
  }

  /// Ana ekrandaki zarf/rozet ikonu için — henüz okunmamış talep sayısı.
  Stream<int> watchUnreadCount(String uid) {
    return watchLeads(uid).map((leads) => leads.where((l) => !l.read).length);
  }

  /// Talebi "okundu" olarak işaretler. Hata sessizce yutulur — bu sadece
  /// bir UI rozetidir, kritik bir veri kaybı riski yok.
  Future<void> markRead(String leadId) async {
    try {
      await _db.collection('leads').doc(leadId).update({'read': true});
    } catch (_) {
      // sessiz geç
    }
  }

  /// Talebi siler (kullanıcı listeden temizlemek isterse).
  Future<void> delete(String leadId) async {
    await _db.collection('leads').doc(leadId).delete();
  }
}
