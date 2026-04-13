import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user.dart';

class ContactsRepository {
  static final _db = FirebaseFirestore.instance;

  // ─── Phone normalisation ──────────────────────────────────────────────────────
  // Accepts any common Indian mobile format and returns +91XXXXXXXXXX.
  // Examples:
  //   9876543210        → +919876543210
  //   09876543210       → +919876543210
  //   919876543210      → +919876543210
  //   +919876543210     → +919876543210
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();

    // Already has a + prefix — trust the caller.
    if (trimmed.startsWith('+')) return trimmed;

    // Strip every non-digit character.
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');

    // 12 digits starting with 91 → already has country code without the +.
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }

    // 11 digits starting with 0 → leading STD 0, strip it.
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    }

    // Assume a bare 10-digit number.
    return '+91$digits';
  }

  // ─── Search ──────────────────────────────────────────────────────────────────

  /// Find a registered user by their phone number.
  /// Accepts all common Indian formats (see [normalizePhone]).
  static Future<AppUser?> findByPhone(String phone) async {
    final normalized = normalizePhone(phone);
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

  /// Add [contactUid] to the current user's contact list.
  ///
  /// One-directional by design: Firestore rules only allow a user to write
  /// their OWN document, so we never touch the other user's document.
  /// The other person can independently add you back if they choose to.
  static Future<void> addContact(String myUid, String contactUid) async {
    await _db.collection('users').doc(myUid).update({
      'contactUids': FieldValue.arrayUnion([contactUid]),
    });
  }

  /// Remove [contactUid] from the current user's contact list.
  static Future<void> removeContact(String myUid, String contactUid) async {
    await _db.collection('users').doc(myUid).update({
      'contactUids': FieldValue.arrayRemove([contactUid]),
    });
  }

  // ─── Fetch contacts ───────────────────────────────────────────────────────────

  /// Fetch the full AppUser profiles for all [contactUids].
  static Future<List<AppUser>> fetchContacts(List<String> contactUids) async {
    if (contactUids.isEmpty) return [];
    // Firestore `whereIn` supports max 30 items per query.
    final results = <AppUser>[];
    for (var i = 0; i < contactUids.length; i += 30) {
      final chunk = contactUids.sublist(
          i, (i + 30).clamp(0, contactUids.length));
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map((d) => AppUser.fromDoc(d)));
    }
    return results;
  }

  /// Stream the current user's contacts as full [AppUser] objects (live).
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
