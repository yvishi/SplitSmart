import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/group.dart';
import '../../shared/models/expense.dart';
import '../auth/auth_notifier.dart';
import '../groups/groups_repository.dart';

/// Streams the list of groups the current user belongs to.
final userGroupsProvider = StreamProvider<List<Group>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthAuthenticated) return const Stream.empty();

  return GroupsRepository.streamUserGroups(authState.profile.uid)
      .handleError((err, stack) {
    debugPrint('🔥 [Firestore/groups] $err');
  });
});

/// Streams recent expenses across all groups the user is in.
/// Uses a Firestore collectionGroup query.
final recentExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final authState = ref.watch(authStateProvider);
  final groupsAsync = ref.watch(userGroupsProvider);

  if (authState is! AuthAuthenticated ||
      groupsAsync.value == null ||
      groupsAsync.value!.isEmpty) {
    return const Stream.empty();
  }

  // No orderBy here — it would require a composite index.
  // We sort client-side instead.
  return FirebaseFirestore.instance
      .collectionGroup('expenses')
      .where('participantUids', arrayContains: authState.profile.uid)
      .limit(50) // fetch more so filtering doesn't starve the list
      .snapshots()
      .handleError((err, stack) {
    debugPrint('🔥 [Firestore/expenses] $err');
  }).map((snap) {
    final uid = authState.profile.uid;
    final expenses = snap.docs
        .map((d) => Expense.fromDoc(d))
        // Hide expenses where this user has zero outstanding balance:
        //   • As non-payer: they are in settledUids.
        //   • As payer: every other participant has settled (netForUid == 0).
        .where((e) => e.netForUid(uid) != 0)
        .toList();
    expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return expenses.take(10).toList();
  });
});

// ─── Net Balance Summary ──────────────────────────────────────────────────────

/// Holds the three figures shown on the hero balance card.
class NetBalanceSummary {
  const NetBalanceSummary({
    required this.totalOwedToYou,
    required this.totalYouOwe,
  });

  /// Total amount others owe you (always ≥ 0).
  final double totalOwedToYou;

  /// Total amount you owe others (always ≥ 0).
  final double totalYouOwe;

  /// Positive = net gain, negative = net debt.
  double get netBalance => totalOwedToYou - totalYouOwe;

  static const zero = NetBalanceSummary(totalOwedToYou: 0, totalYouOwe: 0);
}

/// Streams the live balance summary for the current user across ALL their
/// expenses (no limit).  A separate query from [recentExpensesProvider] so
/// the hero card always reflects the full dataset, not just the recent 10.
final netBalanceSummaryProvider = StreamProvider<NetBalanceSummary>((ref) {
  final authState = ref.watch(authStateProvider);
  final groupsAsync = ref.watch(userGroupsProvider);

  if (authState is! AuthAuthenticated ||
      groupsAsync.value == null ||
      groupsAsync.value!.isEmpty) {
    // Emit zero immediately — no loading spinner needed when there's no data.
    return Stream.value(NetBalanceSummary.zero);
  }

  final uid = authState.profile.uid;

  return FirebaseFirestore.instance
      .collectionGroup('expenses')
      .where('participantUids', arrayContains: uid)
      .snapshots()
      .handleError((err, stack) {
    debugPrint('🔥 [Firestore/balance] $err');
  }).map((snap) {
    double owedToYou = 0;
    double youOwe = 0;

    for (final doc in snap.docs) {
      final expense = Expense.fromDoc(doc);
      // netForUid already returns 0 for settled participants (via settledUids),
      // so settled expenses are automatically excluded from the balance.
      final net = expense.netForUid(uid);
      if (net < 0) {
        owedToYou += -net;
      } else if (net > 0) {
        youOwe += net;
      }
    }

    return NetBalanceSummary(
      totalOwedToYou: owedToYou,
      totalYouOwe: youOwe,
    );
  });
});
