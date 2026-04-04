import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/models/group.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../home/home_providers.dart';
import '../auth/auth_notifier.dart';
import '../contacts/contacts_provider.dart';
import 'groups_repository.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  GroupType? _selectedFilter;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGroupSheet(parentRef: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.forest,
            onPressed: _showCreateGroupDialog,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.base, Spacing.sm, Spacing.base, Spacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search groups…',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.stone, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.stone, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedFilter == null,
                  onTap: () => setState(() => _selectedFilter = null),
                ),
                for (final type in GroupType.values)
                  _FilterChip(
                    label: _groupTypeLabel(type),
                    selected: _selectedFilter == type,
                    onTap: () => setState(() => _selectedFilter =
                        _selectedFilter == type ? null : type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),

          // Groups list via Riverpod
          Expanded(
            child: groupsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.base, vertical: Spacing.sm),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                itemBuilder: (_, __) => const SkeletonLoader(
                  child: SkeletonBox(width: double.infinity, height: 80, radius: 12),
                ),
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (groups) {
                final filtered = groups.where((g) {
                  final matchesType = _selectedFilter == null || g.type == _selectedFilter;
                  final matchesSearch =
                      _query.isEmpty || g.name.toLowerCase().contains(_query.toLowerCase());
                  return matchesType && matchesSearch;
                }).toList();

                if (filtered.isEmpty) return _EmptyState(onCreate: _showCreateGroupDialog);

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.base, vertical: Spacing.sm),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                  itemBuilder: (_, i) => _GroupCard(group: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group card ──────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    const netBalance = 0.0; // PENDING DAG SOLVER HOOK
    final balanceColor = netBalance >= 0 ? AppColors.forest : AppColors.ember;

    return Card(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.base),
          child: Row(
            children: [
              // Avatar stack placeholder
              AvatarStack(names: const ['+', '+', '+'], size: 28),
              const SizedBox(width: Spacing.md),

              // Name + type badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(group.name,
                              style: AppTextStyles.bodyMedium(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _TypeBadge(type: group.type),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.memberUids.length} members',
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),

              // Net balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    CurrencyFormatter.format(netBalance.abs()),
                    style: AppTextStyles.amountMono(color: balanceColor),
                  ),
                  Text(
                    netBalance >= 0 ? 'you get' : 'you owe',
                    style: AppTextStyles.caption(color: AppColors.stone)
                        .copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.xs),
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.border,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption(
              color: selected ? AppColors.white : AppColors.stone,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// ─── Type badge ──────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final GroupType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        _groupTypeLabel(type),
        style: AppTextStyles.caption(color: AppColors.stone)
            .copyWith(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.group_outlined,
                color: AppColors.forest, size: 28),
          ),
          const SizedBox(height: Spacing.base),
          Text('No groups yet',
              style: AppTextStyles.bodyMedium().copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text('Create one to start splitting',
              style: AppTextStyles.caption()),
          const SizedBox(height: Spacing.base),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Group'),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────
String _groupTypeLabel(GroupType t) => switch (t) {
      GroupType.trip => 'Trip',
      GroupType.flat => 'Flat',
      GroupType.couple => 'Couple',
      GroupType.other => 'Other',
    };

// ─── Create Group Sheet ────────────────────────────────────────────────────────
class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet({required this.parentRef});
  final WidgetRef parentRef;

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  GroupType _type = GroupType.trip;
  final Set<String> _selectedUids = {};
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final contacts = contactsAsync.valueOrNull ?? [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
              Text('New Group', style: AppTextStyles.subtitle()),
              const SizedBox(height: Spacing.base),

              // Group name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Group Name'),
              ),
              const SizedBox(height: Spacing.md),

              // Group type
              Wrap(
                spacing: 8,
                children: GroupType.values.map((t) => ChoiceChip(
                  label: Text(_groupTypeLabel(t)),
                  selected: _type == t,
                  onSelected: (v) { if (v) setState(() => _type = t); },
                )).toList(),
              ),
              const SizedBox(height: Spacing.md),

              // Members from contacts
              Text('Add Members', style: AppTextStyles.overline()),
              const SizedBox(height: Spacing.sm),
              if (contactsAsync.isLoading)
                const LinearProgressIndicator()
              else if (contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.subtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'No contacts yet. Add contacts from your profile to invite them.',
                    style: AppTextStyles.caption(color: AppColors.stone),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    itemBuilder: (_, i) {
                      final c = contacts[i];
                      final selected = _selectedUids.contains(c.uid);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedUids.add(c.uid);
                          } else {
                            _selectedUids.remove(c.uid);
                          }
                        }),
                        secondary: AppAvatar(name: c.name, size: 40),
                        title: Text(c.name, style: AppTextStyles.bodyMedium()),
                        subtitle: Text(c.phone,
                            style: AppTextStyles.caption(
                                color: AppColors.stone)),
                        controlAffinity: ListTileControlAffinity.trailing,
                        activeColor: AppColors.forest,
                      );
                    },
                  ),
                ),
              const SizedBox(height: Spacing.md),

              // Create button
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saving || _nameCtrl.text.isEmpty ? null : _create,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) {
      setState(() => _saving = false);
      return;
    }

    await GroupsRepository.createGroup(
      name: _nameCtrl.text.trim(),
      type: _type,
      creatorUid: auth.profile.uid,
      memberUids: _selectedUids.toList(),  // all selected contacts included atomically
    );

    if (mounted) Navigator.pop(context);
  }
}
