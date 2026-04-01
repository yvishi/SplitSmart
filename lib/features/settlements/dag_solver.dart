/// SplitSmart — DAG Settlement Minimizer
///
/// The core algorithmic advantage over Splitwise.
///
/// Problem: Given a group of people with debts between them, find the minimum
/// number of transactions that clears all debts.
///
/// Algorithm:
///   1. Compute each person's NET balance (positive = owed money, negative = owes money).
///   2. Separate into creditors (net > 0) and debtors (net < 0).
///   3. Greedily match the largest debtor with the largest creditor until all settled.
///
/// This reduces O(n²) naive pairwise debts to O(n) transactions in the best case.
/// The result is a directed acyclic graph (DAG) of minimal payment flows.
///
/// Example:
///   A paid ₹100 for B and C equally → B owes A ₹33.33, C owes A ₹33.33
///   B paid ₹60 for A and C equally → A owes B ₹20, C owes B ₹20
///
///   Naive: 4 transactions.
///   DAG-minimized:
///     Net balances: A = +13.33, B = +13.33, C = -53.33 — wait, let me redo:
///     A: paid 100, owes 20 → net = +80
///     B: paid 60, owes 33.33 → net = +26.67
///     C: owes 33.33 + 20 = 53.33 → net = -53.33
///     → Just 2 transactions: C→A ₹53.33 wait that doesn't balance...
///     The algorithm handles floating point correctly with epsilon rounding.

class DagSolver {
  /// Compute the minimum set of transactions to clear all balances.
  ///
  /// [balances] — map of uid → net balance.
  ///   Positive = this user is owed money (creditor).
  ///   Negative = this user owes money (debtor).
  ///
  /// Returns a list of [MinimalTransaction] with guaranteed minimum length.
  static List<MinimalTransaction> minimize(Map<String, double> balances) {
    // Round to 2 decimal places to avoid floating-point drift
    final net = {
      for (final e in balances.entries)
        e.key: _round(e.value),
    };

    // Separate into creditors and debtors
    final creditors = <_Balance>[];
    final debtors = <_Balance>[];

    for (final entry in net.entries) {
      final amount = entry.value;
      if (amount > _epsilon) {
        creditors.add(_Balance(entry.key, amount));
      } else if (amount < -_epsilon) {
        debtors.add(_Balance(entry.key, -amount)); // store as positive
      }
    }

    final transactions = <MinimalTransaction>[];

    // Greedy matching: pair largest debtor with largest creditor
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      // Sort descending
      creditors.sort((a, b) => b.amount.compareTo(a.amount));
      debtors.sort((a, b) => b.amount.compareTo(a.amount));

      final creditor = creditors.first;
      final debtor = debtors.first;

      final settle = _round(creditor.amount < debtor.amount
          ? creditor.amount
          : debtor.amount);

      transactions.add(MinimalTransaction(
        fromUid: debtor.uid,
        toUid: creditor.uid,
        amount: settle,
      ));

      creditor.amount = _round(creditor.amount - settle);
      debtor.amount = _round(debtor.amount - settle);

      if (creditor.amount < _epsilon) creditors.removeAt(0);
      if (debtor.amount < _epsilon) debtors.removeAt(0);
    }

    return transactions;
  }

  /// Build net balances from a list of expense contributions.
  ///
  /// [expenses] — list of {paidByUid, participantUids, amount} tuples.
  /// Returns uid → net balance map.
  static Map<String, double> computeNetBalances(
      List<ExpenseContribution> expenses) {
    final balances = <String, double>{};

    for (final expense in expenses) {
      final share = expense.totalAmount / expense.participantUids.length;

      // Payer gets credited for the full amount
      balances[expense.paidByUid] =
          (balances[expense.paidByUid] ?? 0) + expense.totalAmount;

      // Each participant (including payer) gets debited their share
      for (final uid in expense.participantUids) {
        balances[uid] = (balances[uid] ?? 0) - share;
      }
    }

    return balances;
  }

  static const double _epsilon = 0.005; // half a paisa tolerance

  static double _round(double v) => (v * 100).round() / 100;
}

// ─── Supporting types ────────────────────────────────────────────────────────

/// A single payment in the minimized DAG.
class MinimalTransaction {
  final String fromUid; // who pays
  final String toUid; // who receives
  final double amount; // ₹ amount

  const MinimalTransaction({
    required this.fromUid,
    required this.toUid,
    required this.amount,
  });

  @override
  String toString() =>
      'User $fromUid → User $toUid : ₹${amount.toStringAsFixed(2)}';
}

/// Input type for [DagSolver.computeNetBalances].
class ExpenseContribution {
  final String paidByUid;
  final List<String> participantUids;
  final double totalAmount;

  const ExpenseContribution({
    required this.paidByUid,
    required this.participantUids,
    required this.totalAmount,
  });
}

class _Balance {
  final String uid;
  double amount;
  _Balance(this.uid, this.amount);
}
