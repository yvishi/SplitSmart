import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/balance_hero_card.dart';
import '../../shared/widgets/expense_row.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../auth/auth_notifier.dart';
import '../expenses/add_expense_sheet.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentExpensesAsync = ref.watch(recentExpensesProvider);
    final balanceAsync = ref.watch(netBalanceSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.chalk,
      body: SafeArea(
        child: Column(
          children: [
            _HomeAppBar(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.forest,
                onRefresh: () async {
                  ref.refresh(recentExpensesProvider);
                  ref.refresh(netBalanceSummaryProvider);
                },
                child: ListView(
                  children: [
                    // ── Balance hero ──────────────────────────────────────
                    balanceAsync.when(
                      loading: () => const BalanceCardSkeleton(),
                      error: (_, __) => const BalanceHeroCard(
                        netBalance: 0,
                        totalOwedToYou: 0,
                        totalYouOwe: 0,
                      ),
                      data: (summary) => BalanceHeroCard(
                        netBalance: summary.netBalance,
                        totalOwedToYou: summary.totalOwedToYou,
                        totalYouOwe: summary.totalYouOwe,
                      ),
                    ),

                    _QuickActions(),

                    const SizedBox(height: Spacing.lg),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
                      child: Text('RECENT', style: AppTextStyles.overline()),
                    ),
                    const SizedBox(height: Spacing.sm),

                    // Expense rows mapped to Firestore
                    recentExpensesAsync.when(
                      loading: () => Column(
                        children: List.generate(3, (i) => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: Spacing.base, vertical: Spacing.sm),
                          child: SkeletonLoader(child: SkeletonBox(width: double.infinity, height: 72, radius: 16)),
                        )),
                      ),
                      error: (err, stack) => Padding(
                        padding: const EdgeInsets.all(Spacing.base),
                        child: Text('Error loading expenses: $err', style: AppTextStyles.caption(color: AppColors.ember)),
                      ),
                      data: (expenses) {
                        final auth = ref.watch(authStateProvider);
                        final currentUid = auth is AuthAuthenticated ? auth.profile.uid : null;
                        
                        if (expenses.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(Spacing.xl),
                            child: Center(
                              child: Text('No expenses yet. Add one above!', 
                                style: AppTextStyles.body(color: AppColors.stone)),
                            ),
                          );
                        }
                        return Column(
                          children: expenses.map((e) {
                            // Per-user split logic
                            final uid = currentUid ?? '';
                            final myShare = e.shareForUid(uid);
                            final iAmPayer = e.paidByUid == uid;
                            // Payer is owed back (myShare - total = negative net, they get money back)
                            // Non-payer owes their share
                            final isOwed = iAmPayer && e.participantUids.length > 1;
                            final displayAmount = iAmPayer
                                ? e.totalAmount - myShare  // how much others owe you
                                : myShare;                  // how much you owe

                            return Padding(
                              padding: const EdgeInsets.only(bottom: Spacing.sm),
                              child: ExpenseRow(
                                title: e.title,
                                subtitle: iAmPayer
                                    ? 'You paid · ${e.participantUids.length} people'
                                    : '${e.participantUids.length} people · your share',
                                amount: displayAmount,
                                isOwed: isOwed,
                                category: e.category,
                                onTap: () {},
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Forest FAB — opens Add Expense sheet
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Haptics.lightTap();
          AddExpenseSheet.show(context);
        },
        backgroundColor: AppColors.forest,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom nav
      bottomNavigationBar: _BottomNav(),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          Text(
            'SplitSmart',
            style: AppTextStyles.title().copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            color: AppColors.obsidian,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            color: AppColors.obsidian,
            onPressed: () {
              Haptics.lightTap();
              context.go(AppRoutes.profile);
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (icon: Icons.document_scanner_outlined, label: 'Scan', route: AppRoutes.scanner),
      (icon: Icons.swap_horiz_rounded, label: 'Settle', route: AppRoutes.settlements),
      (icon: Icons.group_outlined, label: 'Groups', route: AppRoutes.groups),
      (icon: Icons.add_circle_outline, label: 'Add', route: ''),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
      child: Row(
        children: actions.map((a) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                Haptics.lightTap();
                if (a.label == 'Add') {
                  AddExpenseSheet.show(context);
                } else {
                  context.go(a.route);
                }
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Icon(a.icon,
                            color: AppColors.forest, size: 20),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(a.label,
                          style: AppTextStyles.caption(
                              color: AppColors.stone)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.white,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            active: true,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.history_outlined,
            label: 'Activity',
            onTap: () {},
          ),
          const SizedBox(width: 48), // FAB gap
          _NavItem(
            icon: Icons.group_outlined,
            label: 'Groups',
            onTap: () {
              Haptics.navSwitch();
              context.go(AppRoutes.groups);
            },
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            onTap: () {
              Haptics.navSwitch();
              context.go(AppRoutes.profile);
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.forest : AppColors.stone;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption(color: color).copyWith(
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
