import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/group.dart';

class GroupsRepository {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  /// Create a new group with a full member list in one atomic batch.
  static Future<Group> createGroup({
    required String name,
    required GroupType type,
    required String creatorUid,
    List<String> memberUids = const [],
  }) async {
    final docRef = _groups.doc();
    final now = DateTime.now();
    // Always include creator in members
    final allMembers = {creatorUid, ...memberUids}.toList();
    final group = Group(
      id: docRef.id,
      name: name,
      type: type,
      memberUids: allMembers,
      createdBy: creatorUid,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _db.batch();
    // Write the group with all members
    batch.set(docRef, group.toMap());
    // Update groupIds for every member atomically
    for (final uid in allMembers) {
      batch.update(_db.collection('users').doc(uid), {
        'groupIds': FieldValue.arrayUnion([docRef.id]),
      });
    }
    await batch.commit();

    return group;
  }

  /// Get a single group by ID.
  static Future<Group?> getGroup(String groupId) async {
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return null;
    return Group.fromDoc(snap);
  }

  /// Stream a user's groups in real-time.
  static Stream<List<Group>> streamUserGroups(String uid) {
    return _groups
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final groups = snap.docs
              .map((d) => Group.fromDoc(d))
              .where((g) => !g.isArchived)
              .toList();
          // Sort client-side — avoids composite index requirement
          groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return groups;
        });
  }

  /// Add a member to a group.
  static Future<void> addMember(String groupId, String targetUid) async {
    final batch = _db.batch();

    // 1. Add uid to group's memberUids
    batch.update(_groups.doc(groupId), {
      'memberUids': FieldValue.arrayUnion([targetUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Add groupId to user's denormalized groupIds
    batch.update(_db.collection('users').doc(targetUid), {
      'groupIds': FieldValue.arrayUnion([groupId])
    });

    await batch.commit();
  }

  /// Remove a member from a group.
  static Future<void> removeMember(String groupId, String targetUid) async {
    final batch = _db.batch();

    batch.update(_groups.doc(groupId), {
      'memberUids': FieldValue.arrayRemove([targetUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('users').doc(targetUid), {
      'groupIds': FieldValue.arrayRemove([groupId])
    });

    await batch.commit();
  }

  /// Update group details.
  static Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _groups.doc(groupId).update(updates);
  }
}
