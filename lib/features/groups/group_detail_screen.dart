import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../shared/models/group.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../auth/auth_notifier.dart';
import 'group_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(singleGroupStreamProvider(groupId));
    final auth = ref.watch(authStateProvider);
    final currentUid =
        auth is AuthAuthenticated ? auth.profile.uid : null;

    return groupAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.chalk,
        appBar: AppBar(backgroundColor: AppColors.chalk),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.chalk,
        appBar: AppBar(
            backgroundColor: AppColors.chalk, title: const Text('Group')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (group) {
        if (group == null) {
          return Scaffold(
            backgroundColor: AppColors.chalk,
            appBar: AppBar(
                backgroundColor: AppColors.chalk, title: const Text('Group')),
            body: const Center(child: Text('Group not found.')),
          );
        }
        return _GroupDetailBody(group: group, currentUid: currentUid);
      },
    );
  }
}

// ─── Body ──────────────────────────────────────────────────────────────────────
class _GroupDetailBody extends ConsumerWidget {
  const _GroupDetailBody({required this.group, required this.currentUid});
  final Group group;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersKey = group.memberUids.join(',');
    final membersAsync = ref.watch(usersByUidsProvider(membersKey));
    final createdAt = DateFormat('d MMM yyyy').format(group.createdAt);

    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        backgroundColor: AppColors.chalk,
        elevation: 0,
        title: Text(group.name, style: AppTextStyles.bodyMedium()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.base),
        children: [
          // ── Header card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(Spacing.base),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(_typeIcon(group.type),
                          color: AppColors.forest, size: 26),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name, style: AppTextStyles.subtitle()),
                          const SizedBox(height: 4),
                          _TypeBadge(type: group.type),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.base),
                const Divider(height: 1, thickness: 0.5, color: AppColors.border),
                const SizedBox(height: Spacing.base),
                Wrap(
                  spacing: Spacing.md,
                  runSpacing: Spacing.xs,
                  children: [
                    _InfoChip(
                      icon: Icons.people_outline,
                      label: '${group.memberUids.length} member${group.memberUids.length == 1 ? '' : 's'}',
                    ),
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created $createdAt',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.base),

          // ── Members section ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text('Members', style: AppTextStyles.overline()),
          ),

          membersAsync.when(
            loading: () => Column(
              children: List.generate(
                group.memberUids.length,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: Spacing.sm),
                  child: SkeletonLoader(
                    child: SkeletonBox(
                        width: double.infinity, height: 68, radius: 12),
                  ),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Could not load members.',
                style: AppTextStyles.caption(color: AppColors.ember),
              ),
            ),
            data: (members) => Column(
              children: members.map((member) {
                final isCreator = member.uid == group.createdBy;
                final isMe = member.uid == currentUid;
                return _MemberTile(
                  member: member,
                  isCreator: isCreator,
                  isMe: isMe,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Member tile ──────────────────────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCreator,
    required this.isMe,
  });

  final dynamic member; // AppUser
  final bool isCreator;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.base, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: isMe ? AppColors.mint : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isMe
              ? const Color(0xFF1A6B4A).withValues(alpha: 0.25)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          AppAvatar(name: member.name, size: 42),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: AppTextStyles.bodyMedium(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: Spacing.xs),
                      _Tag(label: 'You', color: AppColors.forest),
                    ],
                    if (isCreator) ...[
                      const SizedBox(width: Spacing.xs),
                      _Tag(label: 'Admin', color: AppColors.stone),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  member.phone,
                  style: AppTextStyles.caption(color: AppColors.stone),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.stone),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption(color: AppColors.stone)),
      ],
    );
  }
}

// ─── Tag badge ────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(color: color).copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Type badge ───────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final GroupType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        _groupTypeLabel(type),
        style: AppTextStyles.caption(color: AppColors.stone)
            .copyWith(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
IconData _typeIcon(GroupType type) => switch (type) {
      GroupType.trip => Icons.flight_outlined,
      GroupType.flat => Icons.home_outlined,
      GroupType.couple => Icons.favorite_border,
      GroupType.other => Icons.group_outlined,
    };

String _groupTypeLabel(GroupType t) => switch (t) {
      GroupType.trip => 'Trip',
      GroupType.flat => 'Flat',
      GroupType.couple => 'Couple',
      GroupType.other => 'Other',
    };
