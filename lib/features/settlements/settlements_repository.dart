import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/settlement.dart';

class SettlementsRepository {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _settlements =>
      _db.collection('settlements');

  /// Create a new settlement record.
  static Future<Settlement> createSettlement(Settlement settlement) async {
    final docRef = _settlements.doc();

    final newSettlement = Settlement(
      id: docRef.id,
      fromUid: settlement.fromUid,
      toUid: settlement.toUid,
      amount: settlement.amount,
      status: SettlementStatus.confirmed,
      expenseIds: settlement.expenseIds,
      note: settlement.note,
      proofImagePath: settlement.proofImagePath,
      upiTxnId: settlement.upiTxnId,
      createdAt: DateTime.now(),
      settledAt: DateTime.now(),
    );

    await docRef.set(newSettlement.toMap());
    return newSettlement;
  }

  /// Update settlement status.
  static Future<void> updateStatus(
      String settlementId, SettlementStatus newStatus) async {
    await _settlements.doc(settlementId).update({
      'status': newStatus.name,
      if (newStatus == SettlementStatus.confirmed)
        'settledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream settlements where the given UID is either the payer or receiver.
  static Stream<List<Settlement>> streamUserSettlements(String uid) {
    return _settlements
        .where(
          Filter.or(
            Filter('fromUid', isEqualTo: uid),
            Filter('toUid', isEqualTo: uid),
          ),
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Settlement.fromDoc(d)).toList());
  }

  // ─── Core settle-up logic ────────────────────────────────────────────────────
  //
  // Splitwise-style settlement model:
  //
  //   When user A (debtor) settles with user B (creditor) for a net amount:
  //
  //   1. Every expense where B paid and A participated  →  add A to settledUids.
  //   2. Every expense where A paid and B participated  →  add B to settledUids.
  //
  //   Both directions are cleared because the net payment offsets gross debts
  //   in both directions.
  //
  //   After marking, any expense where ALL non-payer participants are now in
  //   settledUids is DELETED (it's fully paid off and no longer relevant).
  //
  //   This guarantees that after settling up:
  //   • Both users see zero balance towards each other.
  //   • Expenses that only existed between the two users disappear entirely.
  //   • Expenses shared with a third party are kept (third party still owes).

  /// Bidirectional settle-up between [debtorUid] and [creditorUid].
  ///
  /// • [debtorUid]   — the person who owes (initiating the settlement).
  /// • [creditorUid] — the person who is owed.
  ///
  /// Marks settled shares in both directions and deletes fully-settled expenses.
  ///
  /// This is a best-effort background operation — it NEVER throws.
  /// The balance screen derives its state from the settlements collection, so
  /// even if this fails the UI is already correct.
  static Future<void> settleUpBetweenUsers({
    required String debtorUid,
    required String creditorUid,
  }) async {
    try {
      await _settleUpBetweenUsersImpl(
          debtorUid: debtorUid, creditorUid: creditorUid);
    } catch (e, st) {
      // Log but never rethrow — the settlement record is already written and
      // the balance will be correct. Expense mutation is cosmetic cleanup.
      debugPrint('⚠️ [settleUpBetweenUsers] best-effort failed: $e\n$st');
    }
  }

  static Future<void> _settleUpBetweenUsersImpl({
    required String debtorUid,
    required String creditorUid,
  }) async {
    // ── Direction 1: expenses where creditor paid, debtor participated ──────
    final creditorPaidSnap = await _db
        .collectionGroup('expenses')
        .where('participantUids', arrayContains: debtorUid)
        .get();

    final direction1 = creditorPaidSnap.docs.where((doc) {
      final d = doc.data();
      return d['paidByUid'] == creditorUid &&
          !List<String>.from(d['settledUids'] ?? []).contains(debtorUid);
    }).toList();

    // ── Direction 2: expenses where debtor paid, creditor participated ──────
    final debtorPaidSnap = await _db
        .collectionGroup('expenses')
        .where('participantUids', arrayContains: creditorUid)
        .get();

    final direction2 = debtorPaidSnap.docs.where((doc) {
      final d = doc.data();
      return d['paidByUid'] == debtorUid &&
          !List<String>.from(d['settledUids'] ?? []).contains(creditorUid);
    }).toList();

    if (direction1.isEmpty && direction2.isEmpty) return;

    // ── Classify each doc: delete (fully settled) vs update (arrayUnion) ────
    //
    // We compute the NEW settledUids in memory so we can check whether the
    // expense becomes fully settled BEFORE writing to Firestore.

    final toDelete = <DocumentReference<Object?>>[];
    // Map from doc reference → uid to add via arrayUnion.
    final toUpdate = <DocumentReference<Object?>, String>{};
    // Track which group docs need an updatedAt bump.
    final affectedGroupIds = <String>{};

    void classify(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      String uidToSettle,
    ) {
      final d = doc.data();
      final participants = List<String>.from(d['participantUids'] ?? []);
      final paidBy = d['paidByUid'] as String? ?? '';
      final currentSettled =
          Set<String>.from(d['settledUids'] as List? ?? []);

      final newSettled = {...currentSettled, uidToSettle};
      final nonPayers =
          participants.where((uid) => uid != paidBy).toSet();

      // An expense is fully settled when every non-payer is in settledUids.
      final isFullySettled =
          nonPayers.isNotEmpty && nonPayers.every(newSettled.contains);

      if (isFullySettle(isFullySettled)) {
        toDelete.add(doc.reference);
      } else {
        toUpdate[doc.reference] = uidToSettle;
      }

      // Track the group so we can bump updatedAt.
      final groupId = d['groupId'] as String?;
      if (groupId != null && groupId.isNotEmpty) {
        affectedGroupIds.add(groupId);
      }
    }

    for (final doc in direction1) { classify(doc, debtorUid); }
    for (final doc in direction2) { classify(doc, creditorUid); }

    // ── Batch write (Firestore limit: 500 ops per batch) ────────────────────
    const batchLimit = 490; // leave headroom for group updates

    final allOps = [
      ...toDelete.map((ref) => _BatchOp.delete(ref)),
      ...toUpdate.entries
          .map((e) => _BatchOp.update(e.key, e.value)),
    ];

    for (int i = 0; i < allOps.length; i += batchLimit) {
      final chunk = allOps.skip(i).take(batchLimit).toList();
      final batch = _db.batch();

      for (final op in chunk) {
        if (op.isDelete) {
          batch.delete(op.ref);
        } else {
          batch.update(op.ref, {
            'settledUids': FieldValue.arrayUnion([op.uid!]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Bump group timestamps in the last chunk (or first if there's only one).
      if (i + batchLimit >= allOps.length) {
        for (final groupId in affectedGroupIds) {
          batch.update(_db.collection('groups').doc(groupId), {
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    }

    debugPrint(
      '✅ [settle] debtorUid=$debtorUid creditorUid=$creditorUid '
      '| updated=${toUpdate.length} deleted=${toDelete.length}',
    );
  }

  // Helper — avoids a type-system glitch with the inline ternary.
  static bool isFullySettle(bool v) => v;
}

// ─── Internal batch operation descriptor ─────────────────────────────────────

class _BatchOp {
  final DocumentReference ref;
  final bool isDelete;
  final String? uid; // only set for updates

  const _BatchOp._({required this.ref, required this.isDelete, this.uid});

  factory _BatchOp.delete(DocumentReference ref) =>
      _BatchOp._(ref: ref, isDelete: true);

  factory _BatchOp.update(DocumentReference ref, String uidToSettle) =>
      _BatchOp._(ref: ref, isDelete: false, uid: uidToSettle);
}
