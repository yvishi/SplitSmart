import 'package:cloud_firestore/cloud_firestore.dart';
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
      status: settlement.status,
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

  /// Update settlement status (e.g. from pending to confirmed).
  static Future<void> updateStatus(String settlementId, SettlementStatus newStatus) async {
    await _settlements.doc(settlementId).update({
      'status': newStatus.name,
      if (newStatus == SettlementStatus.confirmed)
        'settledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream settlements where the given UID is either the payer or receiver.
  static Stream<List<Settlement>> streamUserSettlements(String uid) {
    // Firestore lacks an "OR" query natively for two different fields (without composite index).
    // The cleanest client-side workaround is fetching where fromUid == uid and toUid == uid
    // But rxdart CombineLatestStream is usually used.
    // However, Firebase introduced `Filter.or` in cloud_firestore 4.12.0+!
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
}
