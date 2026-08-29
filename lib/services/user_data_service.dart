import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// SITORA BULUT SENKRONİZASYONU
/// ============================================================================
/// Firestore şeması: users/{uid}
///   email               : string
///   formCredits         : int    (aylık ücretsiz FORM kotası — o ay için kalan)
///   pointsResetMonth     : string ("2026-08" gibi, UTC ay anahtarı — AppState'teki
///                          _thisMonthUtcKey() ile AYNI formatta olmalı)
///   purchasedPoints      : int    (satın alınmış, ay sonunda sıfırlanmayan puan)
///   freeSitePublishUsed  : bool   (ücretsiz ilk yayın hakkı kullanıldı mı)
///   extraPublishCredits  : int    (satın alınmış, henüz harcanmamış yayın hakkı)
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
/// upsertProject/fetchProjects). Her proje kendi dokümanı olduğu için
/// Firestore'un doküman başına 1MB sınırı, tek bir çok sayfalı sitenin TÜM
/// hesabı değil SADECE o siteyi etkiler — büyük bir çok-sayfa proje o limite
/// takılırsa (nadir: tipik üretilen HTML birkaç yüz KB) upsertProject sessizce
/// hata fırlatır, çağıran taraf (AppState) bunu yutar — cihazdaki kayıt zaten
/// SharedPreferences'ta durur, kullanıcı akışı kesilmez, sadece o proje için
/// çoklu-cihaz senkronu o an başarısız olur.
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
    bool deviceFreeSitePublishUsed = false,
    int deviceExtraPublishCredits = 0,
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
      'freeSitePublishUsed': deviceFreeSitePublishUsed,
      'extraPublishCredits': deviceExtraPublishCredits.clamp(0, 1 << 30),
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
      batch.set(_projectsCol(uid).doc(id), projectJson);
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
    required bool freeSitePublishUsed,
    required int extraPublishCredits,
  }) async {
    await _userDoc(uid).set({
      'formCredits': formCredits,
      'pointsResetMonth': pointsResetMonth,
      'purchasedPoints': purchasedPoints,
      'freeSitePublishUsed': freeSitePublishUsed,
      'extraPublishCredits': extraPublishCredits,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Bir SiteProject'i (SiteProject.toJson() çıktısı) buluta yazar/günceller.
  /// Proje SİLİNMEDEN önce çağrılmamalı — silme için [deleteProject]
  /// kullanılır. `merge: false` kasıtlı: proje dokümanı her zaman
  /// AppState'teki SiteProject.toJson() ile BİREBİR eşleşmeli, eski
  /// alanların (ör. kaldırılmış bir domain) dokümanda çöp olarak kalmasını
  /// istemiyoruz.
  Future<void> upsertProject({
    required String uid,
    required Map<String, dynamic> projectJson,
  }) async {
    final id = projectJson['id'] as String?;
    if (id == null || id.isEmpty) return;
    await _projectsCol(uid).doc(id).set(projectJson);
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
    } catch (_) {
      return const [];
    }
  }
}
