import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/user.dart';

/// Single source of truth for /users/{uid} in Firestore.
class UserRepository {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// Returns the current user's profile, or null if doc doesn't exist yet.
  static Future<AppUser?> fetchCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromDoc(snap);
  }

  /// Check if a profile doc exists (used to differentiate new vs returning user).
  static Future<bool> profileExists(String uid) async {
    final snap = await _doc(uid).get();
    return snap.exists;
  }

  /// Create profile for a brand-new user (first sign-in).
  static Future<void> createProfile({
    required String uid,
    required String name,
    required String phone,
    String email = '',
    String upiVpa = '',
  }) async {
    await _doc(uid).set(AppUser(
      uid: uid,
      name: name,
      phone: phone,
      email: email,
      upiVpa: upiVpa,
      createdAt: DateTime.now(),
      groupIds: [],
    ).toMap());
  }

  /// Update mutable fields on an existing profile.
  static Future<void> updateProfile(
      String uid, {String? name, String? upiVpa, String? phone, String? email}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (upiVpa != null) updates['upiVpa'] = upiVpa;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;
    if (updates.isEmpty) return;
    await _doc(uid).update(updates);
  }

  /// Delete the Firestore profile. Called before deleting the Auth user.
  static Future<void> deleteProfile(String uid) async {
    await _doc(uid).delete();
  }

  /// Stream of profile changes — used by ProfileNotifier.
  static Stream<AppUser?> profileStream(String uid) {
    return _doc(uid).snapshots().map(
          (snap) => snap.exists ? AppUser.fromDoc(snap) : null,
        );
  }
}

