import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// ============================================================================
/// SITORA BULUT SENKRONİZASYONU — İSKELET
/// ============================================================================
/// Firestore şeması: users/{uid}
///   email          : string
///   aiCredits      : int
///   formCredits    : int
///   pointsResetMonth: string ("2026-08" gibi, UTC ay anahtarı — AppState'teki
///                     _thisMonthUtcKey() ile AYNI formatta olmalı)
///   createdAt      : timestamp
///   updatedAt      : timestamp
///
/// NOT: Rozet kaldırma artık HESAP GENELİNDE değil, SİTE BAZLI — her proje
/// kendi `watermarkRemoved` alanını taşır (bkz. SiteProject.toJson), bu
/// yüzden users/{uid} dokümanında ayrı bir hasBranding alanı YOK; alt
/// koleksiyondaki her projects/{projectId} kaydında bulunur.
///
/// Projeler alt koleksiyonda tutulur: users/{uid}/projects/{projectId}
/// (SiteProject modeliyle birebir eşlenecek — henüz bağlanmadı, bkz. TODO).
///
/// ÖNEMLİ — GÜVENLİ KOTA TAŞIMA KARARI (netleştirdiğimiz gibi):
/// Bir misafir kullanıcı ilk kez Google ile giriş yaptığında, bulut hesabı
/// SIFIRDAN DOLU kota ile değil, cihazda O AN KALAN kota neyse onunla
/// oluşturulur (bkz. [migrateGuestQuotaOnFirstLogin]). Bu, "misafirken
/// kotayı bitir, sonra giriş yap, bedava tekrar dolu kota kap" istismarını
/// engeller.
///
/// BU DOSYA HENÜZ AppState'E BAĞLANMADI. Sıradaki adım: main.dart'ta Firebase
/// hazırsa AuthService.instance.authStateChanges dinlenip, giriş olduğunda
/// bu servisin fetchOrCreateUserDoc/migrateGuestQuotaOnFirstLogin metodları
/// AppState içinden çağrılacak.
/// ============================================================================
class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// Kullanıcının Firestore dokümanı var mı diye bakar; yoksa oluşturur.
  /// [deviceAiCredits] / [deviceFormCredits] / [deviceResetMonth]: cihazdaki
  /// (SharedPreferences'taki) GÜNCEL kota durumu — SADECE doküman İLK KEZ
  /// oluşturulurken kullanılır (güvenli taşıma). Doküman zaten varsa
  /// (kullanıcı daha önce bu hesapla giriş yapmışsa) bu parametreler
  /// YOK SAYILIR — bulut değeri her zaman esas alınır, tekrar tekrar
  /// "taşıma" yapılmaz.
  ///
  /// Dönen Map, AppState'in senkron edeceği alanları taşır.
  Future<Map<String, dynamic>> fetchOrCreateUserDoc({
    required String uid,
    required String? email,
    required int deviceAiCredits,
    required int deviceFormCredits,
    required String deviceResetMonth,
    required int maxAiPoints,
    required int maxFormPoints,
  }) async {
    final docRef = _userDoc(uid);
    final snap = await docRef.get();

    if (snap.exists) {
      // Doküman zaten var — bulut esas alınır, cihaz değerleri yok sayılır.
      return snap.data()!;
    }

    // İLK GİRİŞ: güvenli taşıma — cihazda kalan kota neyse bulutta da o
    // kadarla başlanır (dolu kotayla değil).
    final data = <String, dynamic>{
      'email': email,
      'aiCredits': deviceAiCredits.clamp(0, maxAiPoints),
      'formCredits': deviceFormCredits.clamp(0, maxFormPoints),
      'pointsResetMonth': deviceResetMonth,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);
    return data;
  }

  /// Bir işlem sonrası (AI/form kredisi düştüğünde) bulutu günceller.
  /// AppState.consumeAiQuota / consumeFormQuota içine, kullanıcı giriş
  /// yapmışsa çağrılacak (TODO — henüz bağlanmadı).
  Future<void> updateCredits({
    required String uid,
    required int aiCredits,
    required int formCredits,
    required String pointsResetMonth,
  }) async {
    await _userDoc(uid).update({
      'aiCredits': aiCredits,
      'formCredits': formCredits,
      'pointsResetMonth': pointsResetMonth,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// TODO (sıradaki adımlardan biri): cihazdaki SiteProject listesini
  /// users/{uid}/projects alt koleksiyonuna yükler (ilk giriş merge'i).
  /// Şimdilik sadece imza/iskelet — proje modeli (SiteProject) tarafını
  /// bir sonraki adımda bağlayacağız.
  Future<void> migrateGuestProjectsOnFirstLogin({
    required String uid,
    required List<Map<String, dynamic>> deviceProjects,
  }) async {
    // Kasıtlı olarak boş bırakıldı — SiteProject <-> Firestore eşlemesi
    // ayrı bir adımda netleştirilip yazılacak (dosya boyutu/limit
    // stratejisi: Firestore doküman başına 1MB sınırı var, büyük çok
    // sayfalı siteler için Firebase Storage gerekebilir — bu karar
    // ayrıca konuşulacak).
  }
}
