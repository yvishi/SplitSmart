import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_notifier.dart';
import '../../shared/models/user.dart';
import 'contacts_repository.dart';

/// Streams the current user's contacts as full AppUser profiles.
final contactsProvider = StreamProvider<List<AppUser>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth is! AuthAuthenticated) return const Stream.empty();
  return ContactsRepository.streamContacts(auth.profile.uid);
});
