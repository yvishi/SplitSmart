import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user.dart';

class ContactsRepository {
  static final _db = FirebaseFirestore.instance;

  // ─── Search ──────────────────────────────────────────────────────────────────

  /// Find a registered user by their phone number.
  /// Returns null if no user with that phone exists.
  static Future<AppUser?> findByPhone(String phone) async {
    // Normalize: ensure it starts with +91
    final normalized = phone.startsWith('+') ? phone : '+91$phone';
    try {
      final snap = await _db
          .collection('users')
          .where('phone', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return AppUser.fromDoc(snap.docs.first);
    } catch (e) {
      debugPrint('🔥 [ContactsRepository.findByPhone] $e');
      return null;
    }
  }

  // ─── Contacts CRUD ────────────────────────────────────────────────────────────

  /// Add a user to your contacts list — and add yourself to theirs (bidirectional).
  static Future<void> addContact(String myUid, String contactUid) async {
    final batch = _db.batch();
    // Add contactUid to my list
    batch.update(_db.collection('users').doc(myUid), {
      'contactUids': FieldValue.arrayUnion([contactUid]),
    });
    // Add me to their list (bidirectional)
    batch.update(_db.collection('users').doc(contactUid), {
      'contactUids': FieldValue.arrayUnion([myUid]),
    });
    await batch.commit();
  }

  /// Remove a user from your contacts — and remove yourself from theirs.
  static Future<void> removeContact(String myUid, String contactUid) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(myUid), {
      'contactUids': FieldValue.arrayRemove([contactUid]),
    });
    batch.update(_db.collection('users').doc(contactUid), {
      'contactUids': FieldValue.arrayRemove([myUid]),
    });
    await batch.commit();
  }

  // ─── Fetch contacts ───────────────────────────────────────────────────────────

  /// Fetch the full AppUser profiles for all contactUids.
  static Future<List<AppUser>> fetchContacts(List<String> contactUids) async {
    if (contactUids.isEmpty) return [];
    // Firestore `whereIn` supports max 30 items per query
    final chunks = <List<String>>[];
    for (var i = 0; i < contactUids.length; i += 30) {
      chunks.add(contactUids.sublist(
          i, i + 30 > contactUids.length ? contactUids.length : i + 30));
    }
    final results = <AppUser>[];
    for (final chunk in chunks) {
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map((d) => AppUser.fromDoc(d)));
    }
    return results;
  }

  /// Stream the current user's contact list as full AppUser objects.
  static Stream<List<AppUser>> streamContacts(String myUid) {
    return _db
        .collection('users')
        .doc(myUid)
        .snapshots()
        .asyncMap((snap) async {
      if (!snap.exists) return [];
      final data = snap.data() as Map<String, dynamic>;
      final uids = List<String>.from(data['contactUids'] ?? []);
      return fetchContacts(uids);
    });
  }
}
