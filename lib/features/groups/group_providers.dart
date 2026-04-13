import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/group.dart';
import '../../shared/models/user.dart';
import '../contacts/contacts_repository.dart';
import 'groups_repository.dart';

/// Stream a single group by ID in real-time.
final singleGroupStreamProvider =
    StreamProvider.family<Group?, String>((ref, groupId) {
  return GroupsRepository.streamGroup(groupId);
});

/// Fetch full AppUser profiles for a comma-separated list of UIDs.
/// Key is UIDs joined with ',' — Riverpod caches by key equality.
final usersByUidsProvider =
    FutureProvider.family<List<AppUser>, String>((ref, uidsKey) async {
  final uids = uidsKey.split(',').where((s) => s.isNotEmpty).toList();
  if (uids.isEmpty) return [];
  return ContactsRepository.fetchContacts(uids);
});
