import 'package:cloud_firestore/cloud_firestore.dart';

class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _projectsCol(String uid) =>
      _userDoc(uid).collection('projects');

  Future<Map<String, dynamic>> fetchOrCreateUserDoc({
    required String uid,
    required String? email,
    bool deviceFreeSitePublishUsed = false,
    int deviceExtraPublishCredits = 0,
    int deviceGiftPublishCredits = 0,
    int deviceGiftWatermarkRemovalCredits = 0,
    int deviceGiftDownloadWatermarkedCredits = 0,
    int deviceGiftDownloadCleanCredits = 0,
    int deviceGiftDomainConnectCredits = 0,
    int deviceGiftMiniPackageCredits = 0,
    List<Map<String, dynamic>> deviceProjects = const [],
  }) async {
    final docRef = _userDoc(uid);
    final snap = await docRef.get();

    if (snap.exists) {
      return snap.data()!;
    }

    final data = <String, dynamic>{
      'email': email,
      'freeSitePublishUsed': deviceFreeSitePublishUsed,
      'extraPublishCredits': deviceExtraPublishCredits.clamp(0, 1 << 30),
      'giftPublishCredits': deviceGiftPublishCredits.clamp(0, 1 << 30),
      'giftWatermarkRemovalCredits': deviceGiftWatermarkRemovalCredits.clamp(0, 1 << 30),
      'giftDownloadWatermarkedCredits': deviceGiftDownloadWatermarkedCredits.clamp(0, 1 << 30),
      'giftDownloadCleanCredits': deviceGiftDownloadCleanCredits.clamp(0, 1 << 30),
      'giftDomainConnectCredits': deviceGiftDomainConnectCredits.clamp(0, 1 << 30),
      'giftMiniPackageCredits': deviceGiftMiniPackageCredits.clamp(0, 1 << 30),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(docRef, data);
    for (final projectJson in deviceProjects) {
      final id = projectJson['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final sanitized = _stripImages(projectJson) as Map<String, dynamic>;
      batch.set(_projectsCol(uid).doc(id), sanitized);
    }
    await batch.commit();
    return data;
  }

  Future<void> updateAccountState({
    required String uid,
    required bool freeSitePublishUsed,
    required int extraPublishCredits,
    required int giftPublishCredits,
    int giftWatermarkRemovalCredits = 0,
    int giftDownloadWatermarkedCredits = 0,
    int giftDownloadCleanCredits = 0,
    int giftDomainConnectCredits = 0,
    int giftMiniPackageCredits = 0,
  }) async {
    await _userDoc(uid).set({
      'freeSitePublishUsed': freeSitePublishUsed,
      'extraPublishCredits': extraPublishCredits,
      'giftPublishCredits': giftPublishCredits,
      'giftWatermarkRemovalCredits': giftWatermarkRemovalCredits,
      'giftDownloadWatermarkedCredits': giftDownloadWatermarkedCredits,
      'giftDownloadCleanCredits': giftDownloadCleanCredits,
      'giftDomainConnectCredits': giftDomainConnectCredits,
      'giftMiniPackageCredits': giftMiniPackageCredits,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertProject({
    required String uid,
    required Map<String, dynamic> projectJson,
  }) async {
    final id = projectJson['id'] as String?;
    if (id == null || id.isEmpty) return;
    final sanitized = _stripImages(projectJson) as Map<String, dynamic>;
    await _projectsCol(uid).doc(id).set(sanitized);
  }

  static final RegExp _dataUriPattern =
      RegExp(r'data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+');

  static const String _placeholderDataUri =
      'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';

  Map<String, dynamic> stripImagesForExport(Map<String, dynamic> json) =>
      _stripImages(json) as Map<String, dynamic>;

  dynamic _stripImages(dynamic value) {
    if (value is String) {
      if (!value.contains('base64,')) return value;
      return value.replaceAll(_dataUriPattern, _placeholderDataUri);
    }
    if (value is Map) {
      return value.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), _stripImages(v)),
      );
    }
    if (value is List) {
      return value.map(_stripImages).toList();
    }
    return value;
  }

  Future<void> deleteProject({
    required String uid,
    required String projectId,
  }) async {
    await _projectsCol(uid).doc(projectId).delete();
  }

  Future<List<Map<String, dynamic>>> fetchProjects(String uid) async {
    try {
      final snap = await _projectsCol(uid).get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return const [];
    }
  }
}
