import 'package:cloud_firestore/cloud_firestore.dart';
import 'debug_log_service.dart';

/// ============================================================================
/// SITORA BULUT SENKRONİZASYONU
/// ============================================================================
/// Firestore şeması: users/{uid}
///   email               : string
///   formCredits         : int    (aylık ücretsiz FORM kotası — o ay için kalan)
///   pointsResetMonth     : string ("2026-08" gibi, UTC ay anahtarı — AppState'teki
///                          _thisMonthUtcKey() ile AYNI formatta olmalı)
///   purchasedPoints      : int    (satın alınmış, ay sonunda sıfırlanmayan puan)
///   giftPoints           : int    (hediye/mailbox'tan gelen, ay sonunda sıfırlanmayan puan —
///                          satın alınan puandan AYRI tutulur ki Ayarlar ekranında ikisi
///                          ayrı ayrı gösterilebilsin, bkz. settings_sheet.dart)
///   freeSitePublishUsed  : bool   (ücretsiz ilk yayın hakkı kullanıldı mı)
///   extraPublishCredits  : int    (satın alınmış, henüz harcanmamış yayın hakkı)
///   giftPublishCredits   : int    (hediye/mailbox'tan gelen, henüz harcanmamış yayın
///                          hakkı — satın alınandan AYRI tutulur, aynı gerekçe ile
///                          giftPoints/purchasedPoints ayrımı, bkz. yukarı)
///   giftWatermarkRemovalCredits   : int (03.09.2026 eklendi — hediye/mailbox'tan
///                          gelen, henüz harcanmamış "rozet kaldırma hakkı" bakiyesi.
///                          Proje bazlı watermarkRemoved'dan FARKLI: bu bir HESAP
///                          bakiyesidir, kullanıcı dilediği projede AppState.
///                          redeemGiftWatermarkRemoval ile harcar.)
///   giftDownloadWatermarkedCredits : int (aynı mantık — "watermarklı indirme hakkı"
///                          hediyesi bakiyesi, bkz. AppState.redeemGiftDownloadWatermarked)
///   giftDownloadCleanCredits       : int (aynı mantık — "watermarksız indirme hakkı"
///                          hediyesi bakiyesi; harcandığında hem rozeti kaldırır hem
///                          indirme hakkı verir, bkz. AppState.redeemGiftDownloadClean)
///   createdAt            : timestamp
///   updatedAt            : timestamp
///
/// NOT: Rozet kaldırma HESAP GENELİNDE değil, SİTE BAZLI — her proje kendi
/// `watermarkRemoved` alanını taşır (bkz. SiteProject.toJson), bu yüzden
/// users/{uid} dokümanında ayrı bir hasBranding alanı YOK; alt koleksiyondaki
/// her projects/{projectId} kaydında bulunur.
///
/// Projeler alt koleksiyonda tutulur: users/{uid}/projects/{projectId} —
/// SiteProject.toJson()/fromJson() ile BİREBİR aynı alanlar (bkz. aşağıdaki
/// upsertProject/fetchProjects) — TEK FARK: base64 gömülü fotoğraflar
/// _stripImages() ile çıkarılmış olarak yazılır (bkz. upsertProject
/// üstündeki not). Bu yüzden Firestore'un doküman başına 1MB sınırına asla
/// yaklaşılmaz.
///
/// GÜVENLİK KURALLARI (Firestore Console → Rules — bkz. FIREBASE_SETUP.md):
///   match /users/{userId} {
///     allow read, write: if request.auth != null && request.auth.uid == userId;
///     match /projects/{projectId} {
///       allow read, write: if request.auth != null && request.auth.uid == userId;
///     }
///   }
///
/// ÖNEMLİ — GÜVENLİ KOTA/VERİ TAŞIMA KARARI:
/// Bir misafir kullanıcı bir hesaba İLK KEZ giriş yaptığında (yani bu uid'e
/// ait Firestore dokümanı henüz hiç yoksa), bulut hesabı SIFIRDAN DOLU kota
/// ile değil, cihazda O AN KALAN kota/puan/proje neyse onunla oluşturulur
/// (bkz. [fetchOrCreateUserDoc]). Bu, "misafirken kotayı bitir, sonra giriş
/// yap, bedava tekrar dolu kota kap" istismarını engeller. Doküman zaten
/// varsa (bu hesapla daha önce herhangi bir cihazdan giriş yapılmışsa) cihaz
/// değerleri TAMAMEN YOK SAYILIR — bulut esas alınır, AppState cihazdaki
/// değerleri buluttan gelenle değiştirir (bkz. AppState._onAuthChanged).
/// ============================================================================
class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _projectsCol(String uid) =>
      _userDoc(uid).collection('projects');

  /// Kullanıcının Firestore dokümanı var mı diye bakar; yoksa oluşturur.
  /// İLK KEZ oluşturuluyorsa (bu hesapla hiçbir cihazdan daha önce giriş
  /// yapılmamış), cihazdaki (SharedPreferences'taki) GÜNCEL durum bulutun
  /// başlangıç değeri olur — bkz. dosya başındaki "GÜVENLİ TAŞIMA" notu.
  /// Aynı anda cihazdaki [deviceProjects] listesi de (varsa) buluta
  /// (users/{uid}/projects alt koleksiyonu) taşınır — TEK SEFERLİK, sadece
  /// doküman ilk oluşturulduğunda.
  ///
  /// Doküman zaten varsa TÜM device* parametreleri YOK SAYILIR — bulut
  /// esas alınır, hiçbir "taşıma" tekrar yapılmaz. Dönen Map, AppState'in
  /// senkron edeceği alanları taşır.
  Future<Map<String, dynamic>> fetchOrCreateUserDoc({
    required String uid,
    required String? email,
    required int deviceFormCredits,
    required String deviceResetMonth,
    required int maxFormPoints,
    int deviceExtraPurchasedPoints = 0,
    int deviceGiftPoints = 0,
    bool deviceFreeSitePublishUsed = false,
    int deviceExtraPublishCredits = 0,
    int deviceGiftPublishCredits = 0,
    int deviceGiftWatermarkRemovalCredits = 0,
    int deviceGiftDownloadWatermarkedCredits = 0,
    int deviceGiftDownloadCleanCredits = 0,
    List<Map<String, dynamic>> deviceProjects = const [],
  }) async {
    final docRef = _userDoc(uid);
    final snap = await docRef.get();

    if (snap.exists) {
      // Doküman zaten var — bulut esas alınır, cihaz değerleri yok sayılır.
      return snap.data()!;
    }

    // İLK GİRİŞ: güvenli taşıma — cihazda kalan kota/puan/hak/proje neyse
    // bulutta da o kadarla başlanır (dolu kotayla/boş projeyle değil).
    final data = <String, dynamic>{
      'email': email,
      'formCredits': deviceFormCredits.clamp(0, maxFormPoints),
      'pointsResetMonth': deviceResetMonth,
      'purchasedPoints': deviceExtraPurchasedPoints.clamp(0, 1 << 30),
      'giftPoints': deviceGiftPoints.clamp(0, 1 << 30),
      'freeSitePublishUsed': deviceFreeSitePublishUsed,
      'extraPublishCredits': deviceExtraPublishCredits.clamp(0, 1 << 30),
      'giftPublishCredits': deviceGiftPublishCredits.clamp(0, 1 << 30),
      'giftWatermarkRemovalCredits': deviceGiftWatermarkRemovalCredits.clamp(0, 1 << 30),
      'giftDownloadWatermarkedCredits': deviceGiftDownloadWatermarkedCredits.clamp(0, 1 << 30),
      'giftDownloadCleanCredits': deviceGiftDownloadCleanCredits.clamp(0, 1 << 30),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Kullanıcı dokümanı + (varsa) cihazdaki projeler TEK bir batch'te
    // yazılır — ya hepsi ya hiçbiri, yarım kalmış bir taşıma olmaz.
    final batch = _db.batch();
    batch.set(docRef, data);
    for (final projectJson in deviceProjects) {
      final id = projectJson['id'] as String?;
      if (id == null || id.isEmpty) continue;
      // upsertProject ile AYNI kural: fotoğraflar buluta hiç gönderilmez,
      // sadece Firestore'a giden kopyadan çıkarılır (bkz. _stripImages).
      final sanitized = _stripImages(projectJson) as Map<String, dynamic>;
      batch.set(_projectsCol(uid).doc(id), sanitized);
    }
    await batch.commit();
    return data;
  }

  /// Hesap genelindeki bakiyeleri (aylık FORM kotası, satın alınan puan,
  /// ücretsiz/satın alınan yayın hakkı) tek seferde bulutla eşitler.
  /// AppState içinde bu değerlerden herhangi biri değiştiğinde (puan
  /// harcama, puan/yayın hakkı satın alma), kullanıcı giriş yapmışsa
  /// çağrılır — bkz. AppState._syncAccountStateToCloudIfSignedIn.
  Future<void> updateAccountState({
    required String uid,
    required int formCredits,
    required String pointsResetMonth,
    required int purchasedPoints,
    required int giftPoints,
    required bool freeSitePublishUsed,
    required int extraPublishCredits,
    required int giftPublishCredits,
    int giftWatermarkRemovalCredits = 0,
    int giftDownloadWatermarkedCredits = 0,
    int giftDownloadCleanCredits = 0,
  }) async {
    await _userDoc(uid).set({
      'formCredits': formCredits,
      'pointsResetMonth': pointsResetMonth,
      'purchasedPoints': purchasedPoints,
      'giftPoints': giftPoints,
      'freeSitePublishUsed': freeSitePublishUsed,
      'extraPublishCredits': extraPublishCredits,
      'giftPublishCredits': giftPublishCredits,
      'giftWatermarkRemovalCredits': giftWatermarkRemovalCredits,
      'giftDownloadWatermarkedCredits': giftDownloadWatermarkedCredits,
      'giftDownloadCleanCredits': giftDownloadCleanCredits,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Bir SiteProject'i (SiteProject.toJson() çıktısı) buluta yazar/günceller.
  /// Proje SİLİNMEDEN önce çağrılmamalı — silme için [deleteProject]
  /// kullanılır. `merge: false` kasıtlı: proje dokümanı her zaman
  /// AppState'teki SiteProject.toJson() ile BİREBİR eşleşmeli, eski
  /// alanların (ör. kaldırılmış bir domain) dokümanda çöp olarak kalmasını
  /// istemiyoruz.
  ///
  /// 30.08.2026 — ÖNCEKİ SÜRÜM (900KB üstünü sessizce atlama) ile
  /// KARIŞTIRMA: o yaklaşım artık KULLANILMIYOR. Bunun yerine [_stripImages]
  /// ile base64 gömülü fotoğraflar Firestore'a giden veriden HER ZAMAN
  /// çıkarılıyor (bkz. altındaki not) — böylece:
  ///   1) Doküman HER ZAMAN küçük kalır → SQLiteBlobTooBigException native
  ///      çökmesi (bkz. Crashlytics issue b64e2c60...) yapısal olarak
  ///      imkansız hale gelir, "bazı büyük projeler senkron dışı kalır"
  ///      diye bir durum KALMAZ.
  ///   2) EN ÖNEMLİSİ: kullanıcının fotoğrafı hiçbir zaman, hiçbir sunucuya
  ///      (R2 dahil) kullanıcının haberi/onayı OLMADAN gönderilmez. Fotoğraf
  ///      sadece kullanıcı bilerek "Yayınla"ya bastığında (mevcut,
  ///      değişmeyen davranış) R2'ye gider — bu metod (arka planda otomatik
  ///      çalışan bulut senkronu) buna hiç dokunmaz.
  Future<void> upsertProject({
    required String uid,
    required Map<String, dynamic> projectJson,
  }) async {
    final id = projectJson['id'] as String?;
    if (id == null || id.isEmpty) return;
    final sanitized = _stripImages(projectJson) as Map<String, dynamic>;
    await _projectsCol(uid).doc(id).set(sanitized);
  }

  /// base64 gömülü görselleri (data:image/...;base64,...) JSON ağacının
  /// HERHANGİ bir yerinden (code, files map'i, formData — nerede olursa
  /// olsun, iç içe Map/List fark etmez) bulup küçük, saydam bir placeholder
  /// ile değiştirir. Görselin kendisi HİÇBİR YERE gönderilmez — sadece
  /// Firestore'a giden kopyadan silinir; cihazdaki asıl kayıt
  /// (SharedPreferences) bundan etkilenmez, kullanıcı hiçbir veri
  /// kaybetmez.
  static final RegExp _dataUriPattern =
      RegExp(r'data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+');

  // 1x1 saydam GIF — kırık resim ikonu göstermek yerine sessizce boş kalsın.
  static const String _placeholderDataUri =
      'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';

  dynamic _stripImages(dynamic value) {
    if (value is String) {
      if (!value.contains('base64,')) return value;
      return value.replaceAll(_dataUriPattern, _placeholderDataUri);
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _stripImages(v)));
    }
    if (value is List) {
      return value.map(_stripImages).toList();
    }
    return value;
  }

  /// Bir projeyi buluttan kalıcı olarak siler (AppState.deleteProject
  /// tarafından, yerel silme ile birlikte çağrılır).
  Future<void> deleteProject({
    required String uid,
    required String projectId,
  }) async {
    await _projectsCol(uid).doc(projectId).delete();
  }

  /// Bu hesaba (uid) bağlı TÜM projeleri buluttan çeker — giriş anında
  /// (AppState._onAuthChanged) cihazdaki listeyle birleştirmek için
  /// kullanılır. Ağ/izin hatasında boş liste döner (exception yutulur) —
  /// çağıran taraf zaten try/catch içinde, ama burada da savunma amaçlı.
  Future<List<Map<String, dynamic>>> fetchProjects(String uid) async {
    try {
      final snap = await _projectsCol(uid).get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      // 05.09.2026 eklendi — önceden sessizce yutuluyordu, artık ekranda da
      // görülebiliyor (bkz. Ayarlar > Hata Kayıtları / debug_log_screen.dart).
      DebugLogService.instance.log('fetchProjects başarısız: $e');
      return const [];
    }
  }
}
