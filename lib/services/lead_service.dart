import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead.dart';

class LeadService {
  LeadService._();
  static final LeadService instance = LeadService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

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

  Stream<int> watchUnreadCount(String uid) {
    return watchLeads(uid).map((leads) => leads.where((l) => !l.read).length);
  }

  Future<void> markRead(String leadId) async {
    try {
      await _db.collection('leads').doc(leadId).update({'read': true});
    } catch (_) {
    }
  }

  Future<void> delete(String leadId) async {
    await _db.collection('leads').doc(leadId).delete();
  }
}
