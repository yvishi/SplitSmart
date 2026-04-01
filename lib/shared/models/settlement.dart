import 'package:cloud_firestore/cloud_firestore.dart';

enum SettlementStatus { pending, confirmed, cancelled }

class Settlement {
  final String id;
  final String fromUid;
  final String toUid;
  final double amount;
  final SettlementStatus status;
  final List<String> expenseIds;
  final String? note;
  final String? proofImagePath;
  final String? upiTxnId;
  final DateTime createdAt;
  final DateTime settledAt;

  const Settlement({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.amount,
    this.status = SettlementStatus.pending,
    required this.expenseIds,
    this.note,
    this.proofImagePath,
    this.upiTxnId,
    required this.createdAt,
    required this.settledAt,
  });

  factory Settlement.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Settlement(
      id: doc.id,
      fromUid: d['fromUid'] as String? ?? '',
      toUid: d['toUid'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      status: SettlementStatus.values.firstWhere(
        (e) => e.name == d['status'],
        orElse: () => SettlementStatus.pending,
      ),
      expenseIds: List<String>.from(d['expenseIds'] ?? []),
      note: d['note'] as String?,
      proofImagePath: d['proofImageUrl'] as String?,
      upiTxnId: d['upiTxnId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settledAt: (d['settledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'amount': amount,
        'status': status.name,
        'expenseIds': expenseIds,
        'note': note,
        'proofImageUrl': proofImagePath,
        'upiTxnId': upiTxnId,
        'createdAt': Timestamp.fromDate(createdAt),
        'settledAt': Timestamp.fromDate(settledAt),
      };
}

