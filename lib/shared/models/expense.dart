import 'package:cloud_firestore/cloud_firestore.dart';
import 'expense_item.dart';

enum SplitType { equal, unequal, percentage, itemBased }

enum ExpenseCategory {
  food,
  transport,
  accommodation,
  entertainment,
  utilities,
  shopping,
  health,
  other
}

class Expense {
  final String id;
  final String title;
  final double totalAmount;
  final String paidByUid;
  final List<String> participantUids;
  final SplitType splitType;
  final ExpenseCategory category;
  final List<ExpenseItem> items;
  final Map<String, double> unequalAmounts; // uid -> amount
  final Map<String, double> percentages;    // uid -> percentage
  final double taxFraction;
  final double tipFraction;
  final String? groupId;
  final String? recurringTemplateId;
  final List<String> auditLog;
  final String? receiptImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUid;

  const Expense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.paidByUid,
    required this.participantUids,
    required this.splitType,
    required this.category,
    this.items = const [],
    this.unequalAmounts = const {},
    this.percentages = const {},
    this.taxFraction = 0.0,
    this.tipFraction = 0.0,
    this.groupId,
    this.recurringTemplateId,
    this.auditLog = const [],
    this.receiptImagePath,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
  });

  factory Expense.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      title: d['title'] as String? ?? 'Unnamed Expense',
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidByUid: d['paidByUid'] as String? ?? '',
      participantUids: List<String>.from(d['participantUids'] ?? []),
      splitType: SplitType.values.firstWhere(
        (e) => e.name == d['splitType'],
        orElse: () => SplitType.equal,
      ),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == d['category'],
        orElse: () => ExpenseCategory.other,
      ),
      items: (d['items'] as List<dynamic>? ?? [])
          .map((i) => ExpenseItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      unequalAmounts: (d['unequalAmounts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      percentages: (d['percentages'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      taxFraction: (d['taxFraction'] as num?)?.toDouble() ?? 0.0,
      tipFraction: (d['tipFraction'] as num?)?.toDouble() ?? 0.0,
      groupId: d['groupId'] as String?,
      recurringTemplateId: d['recurringTemplateId'] as String?,
      auditLog: List<String>.from(d['auditLog'] ?? []),
      receiptImagePath: d['receiptImageUrl'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByUid: d['createdByUid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'totalAmount': totalAmount,
        'paidByUid': paidByUid,
        'participantUids': participantUids,
        'splitType': splitType.name,
        'category': category.name,
        'items': items.map((i) => i.toMap()).toList(),
        'unequalAmounts': unequalAmounts,
        'percentages': percentages,
        'taxFraction': taxFraction,
        'tipFraction': tipFraction,
        'groupId': groupId,
        'recurringTemplateId': recurringTemplateId,
        'auditLog': auditLog,
        'receiptImageUrl': receiptImagePath,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdByUid': createdByUid,
      };

  double get amountPerPerson =>
      participantUids.isEmpty ? 0 : totalAmount / participantUids.length;

  double get grossAmount => totalAmount * (1 + taxFraction + tipFraction);

  /// Returns the share owed by [uid] for this expense.
  /// Handles all split types.
  double shareForUid(String uid) {
    if (!participantUids.contains(uid)) return 0;
    switch (splitType) {
      case SplitType.equal:
        return amountPerPerson;
      case SplitType.unequal:
        return unequalAmounts[uid] ?? 0;
      case SplitType.percentage:
        final pct = percentages[uid] ?? 0;
        return totalAmount * pct / 100;
      case SplitType.itemBased:
        // Sum items assigned to this uid
        return items
            .where((item) => item.assignedUids.contains(uid))
            .fold(0.0, (sum, item) => sum + item.price);
    }
  }

  /// Returns how much [uid] owes (positive) or is owed (negative) for this expense.
  /// Positive = uid owes money. Negative = uid is owed money.
  double netForUid(String uid) {
    final share = shareForUid(uid);
    if (paidByUid == uid) {
      // Payer lent everyone else their share, gets back: totalAmount - their own share
      return share - totalAmount;
    }
    return share;
  }
}
