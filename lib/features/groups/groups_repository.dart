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

    // Write the group document — memberUids already stores all members.
    // We do NOT write groupIds back to each user doc because security rules
    // only allow a user to write their own document, so cross-user batch
    // writes would reject the entire batch. streamUserGroups queries groups
    // by memberUids instead, so groupIds is not needed.
    await docRef.set(group.toMap());

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
    await _groups.doc(groupId).update({
      'memberUids': FieldValue.arrayUnion([targetUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a member from a group.
  static Future<void> removeMember(String groupId, String targetUid) async {
    await _groups.doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([targetUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update group details.
  static Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _groups.doc(groupId).update(updates);
  }

  /// Stream a single group by ID in real-time.
  static Stream<Group?> streamGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map(
          (snap) => snap.exists ? Group.fromDoc(snap) : null,
        );
  }
}
