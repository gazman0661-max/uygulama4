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
  ///
  /// DÜZELTME (07.09.2026 — kanka bildirdi: "bildirim geliyor ama talep
  /// kutusu 'Talepler yüklenemedi' hatası veriyor"): eskiden burada TEK bir
  /// sorgu vardı — `where('ownerId', isEqualTo: uid).orderBy('createdAt',
  /// descending: true)`. Firestore'da bir alanda EŞİTLİK filtresi
  /// (`ownerId`) ile FARKLI bir alanda `orderBy` (`createdAt`) birlikte
  /// kullanılınca bir COMPOSITE INDEX gerekir; bu index Firebase
  /// konsolunda elle oluşturulmadıysa sorgu FAILED_PRECONDITION hatasıyla
  /// patlar. Bildirim (push) bu sorgudan tamamen bağımsız bir yoldan
  /// (Worker → FCM) gittiği için hatasız çalışmaya devam ediyordu — sorun
  /// sadece uygulama içi listeyi okuyan bu sorgudaydı. Aynı hata daha önce
  /// `mailbox_service.dart`'ta da yaşanmıştı (bkz. oradaki yorum).
  ///
  /// ÇÖZÜM: composite index'e hiç ihtiyaç duymayacak şekilde `orderBy`'ı
  /// sorgudan çıkarıp (sadece otomatik tek-alan index'i yeten düz bir
  /// `where` kalıyor), sıralamayı burada istemci tarafında yapıyoruz.
  Stream<List<Lead>> watchLeads(String uid) {
    return _db
        .collection('leads')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final leads = snap.docs.map(Lead.fromDoc).toList();
          leads.sort((a, b) {
            final aTime = a.createdAt;
            final bTime = b.createdAt;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          return leads;
        });
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
