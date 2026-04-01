import 'package:flutter_test/flutter_test.dart';
import 'package:splitsmart/features/settlements/dag_solver.dart';

void main() {
  group('DagSolver', () {
    test('equal 3-way split produces 2 transactions', () {
      // A paid ₹300 for A, B, C equally
      final expenses = [
        ExpenseContribution(
          paidByUid: '1',
          participantUids: ['1', '2', '3'],
          totalAmount: 300,
        ),
      ];
      final balances = DagSolver.computeNetBalances(expenses);

      // A: +300 - 100 = +200, B: -100, C: -100
      expect(balances['1'], closeTo(200, 0.01));
      expect(balances['2'], closeTo(-100, 0.01));
      expect(balances['3'], closeTo(-100, 0.01));

      final txns = DagSolver.minimize(balances);
      expect(txns.length, 2);
      // Both B and C pay A ₹100
      for (final t in txns) {
        expect(t.toUid, '1');
        expect(t.amount, closeTo(100, 0.01));
      }
    });

    test('complex 4-person split minimizes to 3 transactions', () {
      // Naive would produce up to 6 pairwise transactions
      final expenses = [
        ExpenseContribution(
          paidByUid: '1',
          participantUids: ['1', '2', '3', '4'],
          totalAmount: 400,
        ),
        ExpenseContribution(
          paidByUid: '2',
          participantUids: ['1', '2', '3', '4'],
          totalAmount: 200,
        ),
        ExpenseContribution(
          paidByUid: '3',
          participantUids: ['1', '2', '3', '4'],
          totalAmount: 100,
        ),
      ];
      final balances = DagSolver.computeNetBalances(expenses);
      final txns = DagSolver.minimize(balances);

      // Verify all debts cancel
      final netAfter = Map<String, double>.from(balances);
      for (final t in txns) {
        netAfter[t.fromUid] = (netAfter[t.fromUid] ?? 0) + t.amount;
        netAfter[t.toUid] = (netAfter[t.toUid] ?? 0) - t.amount;
      }
      for (final v in netAfter.values) {
        expect(v.abs(), lessThan(0.01));
      }

      // Should be at most 3 transactions (n-1 where n=4 people)
      expect(txns.length, lessThanOrEqualTo(3));
    });

    test('already balanced returns zero transactions', () {
      final balances = {'1': 0.0, '2': 0.0, '3': 0.0};
      final txns = DagSolver.minimize(balances);
      expect(txns, isEmpty);
    });

    test('two-person debt is single transaction', () {
      final expenses = [
        ExpenseContribution(
          paidByUid: '1',
          participantUids: ['1', '2'],
          totalAmount: 340,
        ),
      ];
      final balances = DagSolver.computeNetBalances(expenses);
      final txns = DagSolver.minimize(balances);
      expect(txns.length, 1);
      expect(txns.first.fromUid, '2');
      expect(txns.first.toUid, '1');
      expect(txns.first.amount, closeTo(170, 0.01));
    });

    test('floating point handled within half-paisa tolerance', () {
      // ₹100 / 3 = ₹33.333... — should not cause infinite loop
      final expenses = [
        ExpenseContribution(
          paidByUid: '1',
          participantUids: ['1', '2', '3'],
          totalAmount: 100,
        ),
      ];
      final balances = DagSolver.computeNetBalances(expenses);
      final txns = DagSolver.minimize(balances);
      // Should complete without error
      expect(txns.length, greaterThanOrEqualTo(1));
    });
  });
}

