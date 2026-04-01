import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/expense.dart';

class ExpensesRepository {
  static final _db = FirebaseFirestore.instance;

  /// Get the expenses collection for a specific group.
  static CollectionReference<Map<String, dynamic>> _groupExpenses(String groupId) =>
      _db.collection('groups').doc(groupId).collection('expenses');

  /// Create a new expense.
  static Future<Expense> createExpense({
    required Expense expense,
    required String groupId,
  }) async {
    final docRef = _groupExpenses(groupId).doc();
    
    // We recreate the expense to ensure the ID matches the auto-generated doc ID
    final newExpense = Expense(
      id: docRef.id,
      title: expense.title,
      totalAmount: expense.totalAmount,
      paidByUid: expense.paidByUid,
      participantUids: expense.participantUids,
      splitType: expense.splitType,
      category: expense.category,
      items: expense.items,
      unequalAmounts: expense.unequalAmounts,
      percentages: expense.percentages,
      taxFraction: expense.taxFraction,
      tipFraction: expense.tipFraction,
      groupId: groupId,
      recurringTemplateId: expense.recurringTemplateId,
      auditLog: [...expense.auditLog, 'Created on ${DateTime.now().toIso8601String()}'],
      receiptImagePath: expense.receiptImagePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdByUid: expense.createdByUid,
    );

    // Update group's updatedAt timestamp to bubble it to the top of the list
    final batch = _db.batch();
    batch.set(docRef, newExpense.toMap());
    batch.update(_db.collection('groups').doc(groupId), {
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return newExpense;
  }

  /// Delete an expense.
  static Future<void> deleteExpense(String groupId, String expenseId) async {
    final batch = _db.batch();
    batch.delete(_groupExpenses(groupId).doc(expenseId));
    batch.update(_db.collection('groups').doc(groupId), {
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Stream all expenses for a group, sorted descending by creation time.
  static Stream<List<Expense>> streamGroupExpenses(String groupId) {
    return _groupExpenses(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Expense.fromDoc(d)).toList());
  }
}
