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
  
  if (authState is! AuthAuthenticated || groupsAsync.value == null || groupsAsync.value!.isEmpty) {
    return const Stream.empty();
  }
  
  // No orderBy here — it would require a composite index.
  // We sort client-side instead.
  return FirebaseFirestore.instance
      .collectionGroup('expenses')
      .where('participantUids', arrayContains: authState.profile.uid)
      .limit(20)
      .snapshots()
      .handleError((err, stack) {
        // Firestore prints the index creation URL in the error message.
        // Copy and open it in a browser to auto-create the missing index.
        debugPrint('🔥 [Firestore/expenses] $err');
      })
      .map((snap) {
        final expenses = snap.docs.map((d) => Expense.fromDoc(d)).toList();
        expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return expenses.take(10).toList();
      });
});
