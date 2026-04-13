import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/expense.dart';
import '../../shared/models/user.dart';
import '../auth/auth_notifier.dart';
import '../home/home_providers.dart';
import 'dag_solver.dart';
import 'settlements_repository.dart';
import '../../shared/models/settlement.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

/// A single resolved debt between the current user and one other person.
class PersonDebt {
  const PersonDebt({
    required this.otherUid,
    required this.otherName,
    required this.otherUpiVpa,
    required this.amount,
    required this.isOwedToYou, // true = other person owes you
  });

  final String otherUid;
  final String otherName;
  final String otherUpiVpa;
  final double amount;
  final bool isOwedToYou;
}

class SettlementsState {
  const SettlementsState({
    required this.youOwe,
    required this.owedToYou,
    required this.minimizedCount,
    required this.naiveCount,
  });

  final List<PersonDebt> youOwe;
  final List<PersonDebt> owedToYou;
  final int minimizedCount;
  final int naiveCount;

  static const empty = SettlementsState(
    youOwe: [],
    owedToYou: [],
    minimizedCount: 0,
    naiveCount: 0,
  );
}

// ─── Providers ───────────────────────────────────────────────────────────────

/// Streams the current user's past settlements (history).
final userSettlementsProvider = StreamProvider<List<Settlement>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth is! AuthAuthenticated) return const Stream.empty();
  return SettlementsRepository.streamUserSettlements(auth.profile.uid)
      .handleError((e, s) => debugPrint('🔥 [settlements] $e'));
});

/// Streams the live per-person debt summary using the DAG minimizer.
///
/// Balance = gross expense debts − confirmed settlements already paid.
///
/// The settlements collection is the primary source of truth for "what has
/// been paid". Expense documents are mutated best-effort in the background
/// (for filtering purposes), but the balance shown here derives from:
///   gross share from expenses  −  total confirmed settlements between the pair.
///
/// This means the balance screen updates instantly when a settlement is written,
/// regardless of whether the expense mutation succeeded.
final settlementsStateProvider = StreamProvider<SettlementsState>((ref) {
  final auth = ref.watch(authStateProvider);
  final groupsAsync = ref.watch(userGroupsProvider);

  if (auth is! AuthAuthenticated ||
      groupsAsync.value == null ||
      groupsAsync.value!.isEmpty) {
    return Stream.value(SettlementsState.empty);
  }

  final currentUid = auth.profile.uid;
  final db = FirebaseFirestore.instance;

  return db
      .collectionGroup('expenses')
      .where('participantUids', arrayContains: currentUid)
      .snapshots()
      .asyncMap((expSnap) async {
        final expenses = expSnap.docs.map((d) => Expense.fromDoc(d)).toList();

        // ── Step 1: Gross pairwise balances from expenses ────────────────────
        // Uses grossShareForUid (ignores settledUids) because the settlements
        // collection handles the deduction layer below.
        //
        // peerBalances[peerUid] > 0  → peer owes currentUser
        // peerBalances[peerUid] < 0  → currentUser owes peer
        final peerBalances = <String, double>{};

        for (final expense in expenses) {
          for (final participantUid in expense.participantUids) {
            if (participantUid == currentUid) continue;

            if (expense.paidByUid == currentUid) {
              final theirShare = expense.grossShareForUid(participantUid);
              if (theirShare > 0) {
                peerBalances[participantUid] =
                    (peerBalances[participantUid] ?? 0) + theirShare;
              }
            } else if (expense.paidByUid == participantUid) {
              final myShare = expense.grossShareForUid(currentUid);
              if (myShare > 0) {
                peerBalances[participantUid] =
                    (peerBalances[participantUid] ?? 0) - myShare;
              }
            }
          }
        }

        // naiveCount = total individual debt edges (for DAG banner display).
        final naiveCount = expenses.fold<int>(
            0, (acc, e) => acc + e.participantUids.length - 1);

        // ── Step 2: Deduct confirmed settlements ─────────────────────────────
        // Fetch all confirmed settlements involving currentUser.
        // This is a small collection per user, so a get() here is fine.
        try {
          final settlSnap = await db
              .collection('settlements')
              .where(
                Filter.or(
                  Filter('fromUid', isEqualTo: currentUid),
                  Filter('toUid', isEqualTo: currentUid),
                ),
              )
              .where('status', isEqualTo: 'confirmed')
              .get();

          for (final doc in settlSnap.docs) {
            final s = Settlement.fromDoc(doc);
            // fromUid paid toUid — deduct from the balance between them.
            if (s.fromUid == currentUid) {
              // currentUser paid s.toUid — reduce what currentUser owes them.
              peerBalances[s.toUid] =
                  (peerBalances[s.toUid] ?? 0) + s.amount;
            } else {
              // s.fromUid paid currentUser — reduce what they owe currentUser.
              peerBalances[s.fromUid] =
                  (peerBalances[s.fromUid] ?? 0) - s.amount;
            }
          }
        } catch (e) {
          debugPrint('🔥 [settlements/deduct] $e');
        }

        // Remove pairs whose balance rounded to zero.
        peerBalances.removeWhere((_, v) => v.abs() < 0.01);

        // ── Step 3: DAG minimizer ────────────────────────────────────────────
        final currentUserNet =
            peerBalances.values.fold<double>(0, (acc, v) => acc + v);

        final balanceMap = <String, double>{
          currentUid: currentUserNet,
          for (final e in peerBalances.entries) e.key: -e.value,
        };

        final allTransactions = DagSolver.minimize(balanceMap);
        final myTransactions = allTransactions
            .where((t) => t.fromUid == currentUid || t.toUid == currentUid)
            .toList();

        // ── Step 4: Resolve peer UIDs → names / UPI VPAs ────────────────────
        final peerUids = myTransactions
            .map((t) => t.fromUid == currentUid ? t.toUid : t.fromUid)
            .toSet()
            .toList();

        var peerMap = <String, AppUser>{};
        if (peerUids.isNotEmpty) {
          try {
            final docs = await db
                .collection('users')
                .where(FieldPath.documentId, whereIn: peerUids)
                .get();
            peerMap = {for (final d in docs.docs) d.id: AppUser.fromDoc(d)};
          } catch (e) {
            debugPrint('🔥 [settlements/users] $e');
          }
        }

        // ── Step 5: Build PersonDebt lists ───────────────────────────────────
        final youOwe = <PersonDebt>[];
        final owedToYou = <PersonDebt>[];

        for (final txn in myTransactions) {
          final isOwedToYou = txn.toUid == currentUid;
          final peerUid = isOwedToYou ? txn.fromUid : txn.toUid;
          final peer = peerMap[peerUid];

          final debt = PersonDebt(
            otherUid: peerUid,
            otherName: peer?.name ?? peerUid,
            otherUpiVpa: peer?.upiVpa ?? '',
            amount: txn.amount,
            isOwedToYou: isOwedToYou,
          );

          if (isOwedToYou) {
            owedToYou.add(debt);
          } else {
            youOwe.add(debt);
          }
        }

        return SettlementsState(
          youOwe: youOwe,
          owedToYou: owedToYou,
          minimizedCount: myTransactions.length,
          naiveCount: naiveCount,
        );
      })
      .handleError((e, s) => debugPrint('🔥 [settlementState] $e'));
});
