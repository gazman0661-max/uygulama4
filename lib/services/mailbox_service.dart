import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class MailItem {
  final String id;
  final String target;
  final String title;
  final String titleEn;
  final String body;
  final String bodyEn;
  final String giftType;
  final int giftAmount;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool claimed;

  const MailItem({
    required this.id,
    required this.target,
    required this.title,
    required this.titleEn,
    required this.body,
    required this.bodyEn,
    required this.giftType,
    required this.giftAmount,
    required this.createdAt,
    required this.expiresAt,
    required this.claimed,
  });

  bool get hasGift =>
      giftType == 'publishCredit' ||
      giftType == 'watermarkRemoval' ||
      giftType == 'downloadWatermarked' ||
      giftType == 'downloadClean' ||
      giftType == 'domainConnect' ||
      giftType == 'miniPackage';

  MailItem copyWith({bool? claimed}) => MailItem(
        id: id,
        target: target,
        title: title,
        titleEn: titleEn,
        body: body,
        bodyEn: bodyEn,
        giftType: giftType,
        giftAmount: giftAmount,
        createdAt: createdAt,
        expiresAt: expiresAt,
        claimed: claimed ?? this.claimed,
      );

  factory MailItem._fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return MailItem(
      id: doc.id,
      target: (data['target'] as String?) ?? 'all',
      title: (data['title'] as String?) ?? '',
      titleEn: (data['titleEn'] as String?) ?? (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      bodyEn: (data['bodyEn'] as String?) ?? (data['body'] as String?) ?? '',
      giftType: (data['giftType'] as String?) ?? 'none',
      giftAmount: (data['giftAmount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      claimed: false,
    );
  }
}

class MailboxService {
  MailboxService._();
  static final MailboxService instance = MailboxService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<List<MailItem>> watchInbox(String uid) {
    late final StreamController<List<MailItem>> controller;
    StreamSubscription? subPersonal;
    StreamSubscription? subBroadcast;
    StreamSubscription? subClaimed;
    StreamSubscription? subDismissed;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? personalDocs;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? broadcastDocs;
    Set<String>? claimedIds;
    Set<String>? dismissedIds;

    void emit() {
      if (personalDocs == null ||
          broadcastDocs == null ||
          claimedIds == null ||
          dismissedIds == null) {
        return;
      }

      final now = DateTime.now();
      final merged = [...personalDocs!, ...broadcastDocs!]
          .map(MailItem._fromDoc)
          .where((m) => m.expiresAt == null || m.expiresAt!.isAfter(now))
          .where((m) => !dismissedIds!.contains(m.id))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

      controller.add(
        merged.map((m) => m.copyWith(claimed: claimedIds!.contains(m.id))).toList(),
      );
    }

    controller = StreamController<List<MailItem>>.broadcast(
      onListen: () {
        subPersonal = _db
            .collection('mailbox')
            .where('target', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          personalDocs = snap.docs;
          emit();
        }, onError: controller.addError);

        subBroadcast = _db
            .collection('mailbox')
            .where('target', isEqualTo: 'all')
            .snapshots()
            .listen((snap) {
          broadcastDocs = snap.docs;
          emit();
        }, onError: controller.addError);

        subClaimed = _db
            .collection('users')
            .doc(uid)
            .collection('claimedMail')
            .snapshots()
            .listen((snap) {
          claimedIds = snap.docs.map((d) => d.id).toSet();
          emit();
        }, onError: (_) {
          claimedIds ??= const {};
          emit();
        });

        subDismissed = _db
            .collection('users')
            .doc(uid)
            .collection('dismissedMail')
            .snapshots()
            .listen((snap) {
          dismissedIds = snap.docs.map((d) => d.id).toSet();
          emit();
        }, onError: (_) {
          dismissedIds ??= const {};
          emit();
        });
      },
      onCancel: () {
        subPersonal?.cancel();
        subBroadcast?.cancel();
        subClaimed?.cancel();
        subDismissed?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<int> watchUnclaimedCount(String uid) {
    return watchInbox(uid).map((items) => items.where((m) => !m.claimed).length);
  }

  Future<void> claim(String uid, String mailId) async {
    final ref = _db.collection('users').doc(uid).collection('claimedMail').doc(mailId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw MailAlreadyClaimedException();
      }
      tx.set(ref, {'claimedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> dismiss(String uid, String mailId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('dismissedMail')
        .doc(mailId)
        .set({'dismissedAt': FieldValue.serverTimestamp()});
  }
}

class MailAlreadyClaimedException implements Exception {}
