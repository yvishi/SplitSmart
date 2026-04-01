import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/app_avatar.dart';
import '../auth/auth_notifier.dart';
import 'contacts_provider.dart';
import 'contacts_repository.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add Contact',
            onPressed: () => _showAddContactSheet(context),
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: AppTextStyles.body(color: AppColors.ember)),
        ),
        data: (contacts) {
          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: AppColors.stone),
                  const SizedBox(height: Spacing.md),
                  Text('No contacts yet', style: AppTextStyles.subtitle()),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Add friends by their phone number\nto create groups with them.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.stone),
                  ),
                  const SizedBox(height: Spacing.lg),
                  FilledButton.icon(
                    onPressed: () => _showAddContactSheet(context),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add a Contact'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.base, vertical: Spacing.sm),
            itemCount: contacts.length,
            itemBuilder: (_, i) => _ContactTile(
              user: contacts[i],
              onRemove: () => _removeContact(contacts[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeContact(AppUser contact) async {
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text('Remove ${contact.name} from your contacts?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove',
                  style: TextStyle(color: AppColors.ember))),
        ],
      ),
    );
    if (confirmed == true) {
      await ContactsRepository.removeContact(
          auth.profile.uid, contact.uid);
    }
  }

  void _showAddContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddContactSheet(),
    );
  }
}

// ─── Contact tile ─────────────────────────────────────────────────────────────
class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.user, required this.onRemove});
  final AppUser user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        leading: AppAvatar(name: user.name, size: 40),
        title: Text(user.name, style: AppTextStyles.bodyMedium()),
        subtitle: Text(user.phone,
            style: AppTextStyles.caption(color: AppColors.stone)),
        trailing: IconButton(
          icon: Icon(Icons.person_remove_outlined, color: AppColors.stone),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

// ─── Add contact bottom sheet ─────────────────────────────────────────────────
class _AddContactSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<_AddContactSheet> {
  final _phoneCtrl = TextEditingController();
  AppUser? _found;
  bool _searching = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _found = null;
      _error = null;
      _searched = false;
    });
    final result = await ContactsRepository.findByPhone(_phoneCtrl.text.trim());
    setState(() {
      _searching = false;
      _searched = true;
      _found = result;
      if (result == null) _error = 'No user found with that phone number.';
    });
  }

  Future<void> _add() async {
    if (_found == null) return;
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) return;

    // Don't add yourself
    if (_found!.uid == auth.profile.uid) {
      setState(() => _error = 'You cannot add yourself.');
      return;
    }

    await ContactsRepository.addContact(auth.profile.uid, _found!.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_found!.name} added to contacts!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.all(Spacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: Spacing.base),
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text('Add a Contact', style: AppTextStyles.subtitle()),
            const SizedBox(height: Spacing.base),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91 98765 43210',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),

            // Result
            if (_searched && _found != null) ...[
              Card(
                child: ListTile(
                  leading: AppAvatar(name: _found!.name, size: 40),
                  title: Text(_found!.name, style: AppTextStyles.bodyMedium()),
                  subtitle: Text(_found!.phone,
                      style: AppTextStyles.caption(color: AppColors.stone)),
                  trailing: FilledButton(
                    onPressed: _add,
                    child: const Text('Add'),
                  ),
                ),
              ),
            ] else if (_searched && _error != null) ...[
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: AppColors.ember.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.ember, size: 18),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(_error!,
                          style: AppTextStyles.caption(color: AppColors.ember)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}
