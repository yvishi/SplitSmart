import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/models/settlement.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'settlements_provider.dart';
import 'upi_settle_sheet.dart';

class SettlementsScreen extends ConsumerWidget {
  const SettlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(settlementsStateProvider);

    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: const Text('Settlements'),
      ),
      body: stateAsync.when(
        loading: () => const _SettlementsSkeleton(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.ember, size: 40),
                const SizedBox(height: Spacing.md),
                Text('Could not load settlements',
                    style: AppTextStyles.bodyMedium()),
                const SizedBox(height: Spacing.sm),
                Text('$err',
                    style: AppTextStyles.caption(color: AppColors.stone),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (state) {
          final hasAny =
              state.youOwe.isNotEmpty || state.owedToYou.isNotEmpty;

          return RefreshIndicator(
            color: AppColors.forest,
            onRefresh: () async => ref.refresh(settlementsStateProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.base, vertical: Spacing.sm),
              children: [
                // ── DAG hero banner ─────────────────────────────────────
                if (hasAny)
                  _DagBanner(
                    minimizedCount: state.minimizedCount,
                    naiveCount: state.naiveCount,
                  ),
                if (hasAny) const SizedBox(height: Spacing.lg),

                // ── YOU OWE section ─────────────────────────────────────
                if (state.youOwe.isNotEmpty) ...[
                  Text('YOU OWE', style: AppTextStyles.overline()),
                  const SizedBox(height: Spacing.sm),
                  ...state.youOwe.map((debt) => _BalanceRow(
                        debt: debt,
                        onSettle: () =>
                            UpiSettleSheet.show(context, ref: ref, debt: debt),
                      )),
                  const SizedBox(height: Spacing.lg),
                ],

                // ── OWED TO YOU section ─────────────────────────────────
                if (state.owedToYou.isNotEmpty) ...[
                  Text('OWED TO YOU', style: AppTextStyles.overline()),
                  const SizedBox(height: Spacing.sm),
                  ...state.owedToYou.map((debt) => _BalanceRow(
                        debt: debt,
                        onNudge: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Reminder sent to ${debt.otherName} 🔔'),
                              backgroundColor: AppColors.obsidian,
                            ),
                          );
                        },
                      )),
                  const SizedBox(height: Spacing.base),
                ],

                // ── All settled state ───────────────────────────────────
                if (!hasAny) ...[
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Icon(Icons.check_circle_outline,
                              color: AppColors.forest, size: 36),
                        ),
                        const SizedBox(height: Spacing.base),
                        Text('All settled up! 🎉',
                            style: AppTextStyles.subtitle()),
                        const SizedBox(height: Spacing.sm),
                        Text('No pending debts with anyone.',
                            style:
                                AppTextStyles.caption(color: AppColors.stone)),
                      ],
                    ),
                  ),
                ],

                // ── Settlement history ──────────────────────────────────
                const SizedBox(height: Spacing.lg),
                _SettlementHistory(),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── DAG banner ──────────────────────────────────────────────────────────────
class _DagBanner extends StatelessWidget {
  const _DagBanner(
      {required this.minimizedCount, required this.naiveCount});
  final int minimizedCount;
  final int naiveCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.base),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: const Border(
          left: BorderSide(color: AppColors.forest, width: 3),
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.border, blurRadius: 0, spreadRadius: 0.5),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚡ $minimizedCount transaction${minimizedCount == 1 ? '' : 's'} clear all debts',
                  style: AppTextStyles.bodyMedium(color: AppColors.forest),
                ),
                const SizedBox(height: 3),
                Text(
                  'Naive approach would need $naiveCount — DAG-minimized',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          _NodeGraphIcon(),
        ],
      ),
    );
  }
}

class _NodeGraphIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(painter: _GraphPainter()),
    );
  }
}

class _GraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.forest
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final nodePaint = Paint()
      ..color = AppColors.forest
      ..style = PaintingStyle.fill;

    final nodes = [
      Offset(size.width * 0.15, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.5),
    ];
    for (int i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], paint);
    }
    for (final n in nodes) {
      canvas.drawCircle(n, 5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Balance row ─────────────────────────────────────────────────────────────
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.debt, this.onSettle, this.onNudge});

  final PersonDebt debt;
  final VoidCallback? onSettle;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final bgColor = debt.isOwedToYou ? AppColors.mint : AppColors.rose;
    final amtColor =
        debt.isOwedToYou ? AppColors.forest : AppColors.ember;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.base),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            AppAvatar(name: debt.otherName, size: 36),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(debt.otherName,
                      style: AppTextStyles.bodyMedium()),
                  const SizedBox(height: 2),
                  Text(
                    debt.isOwedToYou
                        ? 'owes you'
                        : 'you owe',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(debt.amount),
                  style: AppTextStyles.amountMono(color: amtColor),
                ),
                const SizedBox(height: 4),
                if (onSettle != null)
                  GestureDetector(
                    onTap: onSettle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Settle →',
                        style: AppTextStyles.caption(color: AppColors.white)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (onNudge != null)
                  GestureDetector(
                    onTap: onNudge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                        border:
                            Border.all(color: AppColors.stone, width: 0.5),
                      ),
                      child: Text(
                        'Nudge 🔔',
                        style: AppTextStyles.caption(color: AppColors.stone),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Settlement history ───────────────────────────────────────────────────────
class _SettlementHistory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(userSettlementsProvider);

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (settlements) {
        if (settlements.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HISTORY', style: AppTextStyles.overline()),
            const SizedBox(height: Spacing.sm),
            ...settlements.take(5).map((s) => _HistoryRow(settlement: s)),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.settlement});
  final Settlement settlement;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = settlement.status.name == 'confirmed';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.base, vertical: Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              isConfirmed
                  ? Icons.check_circle_outline
                  : Icons.hourglass_empty_outlined,
              color: isConfirmed ? AppColors.forest : AppColors.stone,
              size: 20,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                CurrencyFormatter.format(settlement.amount),
                style: AppTextStyles.bodyMedium(),
              ),
            ),
            Text(
              isConfirmed ? 'Settled' : 'Pending',
              style: AppTextStyles.caption(
                color: isConfirmed ? AppColors.forest : AppColors.stone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────
class _SettlementsSkeleton extends StatelessWidget {
  const _SettlementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.base, vertical: Spacing.sm),
      children: [
        // DAG banner skeleton
        SkeletonLoader(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        // Section label
        SkeletonLoader(child: SkeletonBox(width: 80, height: 11)),
        const SizedBox(height: Spacing.sm),
        // Balance rows
        for (int i = 0; i < 3; i++) ...[
          SkeletonLoader(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}
