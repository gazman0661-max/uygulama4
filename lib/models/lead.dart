import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir sitenin iletişim formundan gelen talep (bkz.
/// templates/html/shared_html_blocks.dart > leadFormMarkup — ziyaretçi bu
/// formu doldurup gönderdiğinde, doğrudan tarayıcıdan Firestore'un `leads`
/// koleksiyonuna yazılır; kimlik doğrulaması YOKTUR, güvenlik Firestore
/// Security Rules'tan gelir (bkz. FIREBASE_SETUP.md).
class Lead {
  final String id;
  final String ownerId;
  final String siteId;
  final String siteName;
  final String name;
  final String phone;
  final String email;
  final String message;
  final String source;
  final DateTime? createdAt;
  final bool read;

  const Lead({
    required this.id,
    required this.ownerId,
    required this.siteId,
    required this.siteName,
    required this.name,
    required this.phone,
    this.email = '',
    required this.message,
    required this.source,
    required this.createdAt,
    required this.read,
  });

  Lead copyWith({bool? read}) => Lead(
        id: id,
        ownerId: ownerId,
        siteId: siteId,
        siteName: siteName,
        name: name,
        phone: phone,
        email: email,
        message: message,
        source: source,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  factory Lead.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Lead(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      siteId: (data['siteId'] as String?) ?? '',
      siteName: (data['siteName'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      source: (data['source'] as String?) ?? 'site_form',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      read: (data['read'] as bool?) ?? false,
    );
  }
}
