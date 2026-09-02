import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// SITORA MAILBOX (BİLDİRİM / HEDİYE KUTUSU)
/// ============================================================================
/// Empires & Puzzles vb. oyunlardaki "gelen kutusu" ile AYNI mantık: admin
/// panelinden (bkz. cloudflare/worker/src/index.mjs > handleAdminMailCreate)
/// TEK bir kullanıcıya ya da TÜM kullanıcılara ("all") bir mesaj + opsiyonel
/// bir hediye (puan / yayın hakkı) gönderilir; kullanıcı uygulama içinde bu
/// ekrandan "Teslim Al"a basınca hediye hesabına işlenir.
///
/// Firestore şeması:
///   mailbox/{mailId}
///     target        : string  ("all" ya da tek bir kullanıcının uid'i)
///     title/titleEn : string  (başlık, TR/EN)
///     body/bodyEn   : string  (mesaj metni, TR/EN)
///     giftType      : string  ("none" | "points" | "publishCredit")
///     giftAmount    : int     (giftType "none" ise 0/yok sayılır)
///     createdAt     : timestamp
///     expiresAt     : timestamp | null  (null ise süresiz görünür)
///
///   users/{uid}/claimedMail/{mailId}
///     claimedAt     : timestamp
///     (bu doküman VARSA o mesaj zaten teslim alınmış demektir — bkz. [claim])
///
/// GÜVENLİK: mailbox koleksiyonuna istemciden YAZMA YOK (bkz.
/// FIREBASE_SETUP.md kuralları) — sadece admin panelindeki servis hesabı
/// yazabilir. Hediyenin GERÇEKTEN hesaba işlenmesi (AppState.addPurchasedPoints
/// vb.) her zaman [claim] Firestore transaction'ı BAŞARILI döndükten SONRA,
/// çağıran widget (mailbox_screen.dart) tarafından yapılır — bu, uygulamanın
/// zaten mevcut güven modeliyle (users/{uid} alanlarının istemciden yazılması,
/// bkz. UserDataService) birebir tutarlıdır.
class MailItem {
  final String id;
  final String target;
  final String title;
  final String titleEn;
  final String body;
  final String bodyEn;
  final String giftType; // 'none' | 'points' | 'publishCredit'
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

  bool get hasGift => giftType == 'points' || giftType == 'publishCredit';

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

  /// [uid]'e ait gelen kutusunu CANLI dinler: hem bu kullanıcıya özel
  /// (`target == uid`) hem de herkese gönderilmiş (`target == "all"`)
  /// mesajları getirir.
  ///
  /// DÜZELTME (02.09.2026 — kanka bildirdi: "hediye panelde gönderildi
  /// görünüyor ama uygulamaya gelmiyor"): eskiden burada TEK bir sorgu
  /// vardı — `where('target', whereIn: [uid, 'all']).orderBy('createdAt')`.
  /// Firestore'da bir "in" filtresini FARKLI bir alanda orderBy ile
  /// birleştirmek (`whereIn` + `orderBy` başka alanda) bir COMPOSITE INDEX
  /// gerektirir; bu index Firebase konsolunda elle oluşturulmadıysa sorgu
  /// FAILED_PRECONDITION hatasıyla patlar. `.asyncMap` içinde bu hata
  /// hiçbir yere yakalanmıyordu ve StreamBuilder da `snap.hasError`
  /// kontrolü yapmıyordu (bkz. mailbox_screen.dart) — sonuç: mesaj hiç
  /// gelmemiş gibi sessizce "Henüz bir mesajın yok" gösteriliyordu.
  ///
  /// ÇÖZÜM: composite index'e hiç ihtiyaç duymayacak şekilde İKİ AYRI,
  /// orderBy'sız (dolayısıyla sadece otomatik tek-alan index'i yeten)
  /// sorguyu ayrı ayrı dinleyip sonuçları burada, istemci tarafında
  /// birleştirip sıralıyoruz. Herhangi biri hata verirse `controller`
  /// üzerinden dışarıya (mailbox_screen.dart'taki StreamBuilder'a) iletilir,
  /// artık sessizce yutulmuyor.
  Stream<List<MailItem>> watchInbox(String uid) {
    late final StreamController<List<MailItem>> controller;
    StreamSubscription? subPersonal;
    StreamSubscription? subBroadcast;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? personalDocs;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? broadcastDocs;

    Future<void> emit() async {
      // İki sorgunun da en az bir kez sonuç vermesini bekle — biri
      // gelmeden emit edersek geçici olarak eksik liste gösterebiliriz.
      if (personalDocs == null || broadcastDocs == null) return;

      final now = DateTime.now();
      final merged = [...personalDocs!, ...broadcastDocs!]
          .map(MailItem._fromDoc)
          .where((m) => m.expiresAt == null || m.expiresAt!.isAfter(now))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

      if (merged.isEmpty) {
        controller.add(merged);
        return;
      }

      Set<String> claimedIds;
      try {
        final claimedSnap =
            await _db.collection('users').doc(uid).collection('claimedMail').get();
        claimedIds = claimedSnap.docs.map((d) => d.id).toSet();
      } catch (_) {
        // Ağ hatasında hiçbirini "teslim alınmış" gösterme — kullanıcı yine
        // de listeyi görebilsin, [claim] zaten çift teslimi transaction'la
        // engelliyor.
        claimedIds = const {};
      }
      controller.add(merged.map((m) => m.copyWith(claimed: claimedIds.contains(m.id))).toList());
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
      },
      onCancel: () {
        subPersonal?.cancel();
        subBroadcast?.cancel();
      },
    );

    return controller.stream;
  }

  /// [uid] için henüz teslim alınmamış mesaj sayısını CANLI verir — ana
  /// ekrandaki zarf ikonunun üzerindeki rozet sayısı için kullanılır.
  Stream<int> watchUnclaimedCount(String uid) {
    return watchInbox(uid).map((items) => items.where((m) => !m.claimed).length);
  }

  /// Bir mesajı "teslim alındı" olarak işaretler. Firestore transaction'ı
  /// önce `claimedMail/{mailId}` dokümanının VAR OLUP OLMADIĞINA bakar —
  /// zaten varsa (aynı hesaptan başka bir cihaz daha önce teslim aldıysa)
  /// [MailAlreadyClaimedException] fırlatır, hediye İKİNCİ KEZ verilmez.
  /// Başarılı dönerse ÇAĞIRAN TARAF (mailbox_screen.dart) hediyeyi
  /// AppState üzerinden hesaba işlemekle yükümlüdür — bu metod sadece
  /// "teslim alındı" kilidini koyar, hediyenin türünü/miktarını bilmez.
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
}

/// [MailboxService.claim] bir mesaj için İKİNCİ kez çağrıldığında fırlatılır
/// (ör. kullanıcı butona art arda dokunduysa ya da başka bir cihazda zaten
/// teslim almışsa). Çağıran widget bunu yakalayıp sessizce "zaten alınmış"
/// göstermeli, hediyeyi TEKRAR hesaba işlememelidir.
class MailAlreadyClaimedException implements Exception {}
