import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/settlements/dag_solver.dart';
import '../../shared/widgets/app_avatar.dart';
import 'upi_settle_sheet.dart';

class SettlementsScreen extends StatelessWidget {
  const SettlementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Build net balances from sample data (replace with Riverpod+Isar)
    final contributions = [
      ExpenseContribution(paidByUid: '1', participantUids: ['1', '2', '3', '4'], totalAmount: 450),
      ExpenseContribution(paidByUid: '2', participantUids: ['1', '2', '3'], totalAmount: 810),
      ExpenseContribution(paidByUid: '3', participantUids: ['1', '2', '3', '4'], totalAmount: 120),
      ExpenseContribution(paidByUid: '1', participantUids: ['1', '4'], totalAmount: 340),
    ];
    final balances = DagSolver.computeNetBalances(contributions);
    final transactions = DagSolver.minimize(balances);
    final naiveCount = contributions.fold<int>(
        0, (acc, e) => acc + e.participantUids.length - 1);

    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: const Text('Settlements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.base, vertical: Spacing.sm),
        children: [
          // ── DAG hero banner ──────────────────────────────────────────────
          _DagBanner(
            minimizedCount: transactions.length,
            naiveCount: naiveCount,
          ),
          const SizedBox(height: Spacing.lg),

          // ── You owe ──────────────────────────────────────────────────────
          Text('YOU OWE', style: AppTextStyles.overline()),
          const SizedBox(height: Spacing.sm),
          ..._sampleDebts
              .where((d) => !d.isOwedToYou)
              .map((d) => _BalanceRow(debt: d, onSettle: () {
                    UpiSettleSheet.show(context, debt: d);
                  })),
          const SizedBox(height: Spacing.lg),

          // ── Owed to you ──────────────────────────────────────────────────
          Text('OWED TO YOU', style: AppTextStyles.overline()),
          const SizedBox(height: Spacing.sm),
          ..._sampleDebts
              .where((d) => d.isOwedToYou)
              .map((d) => _BalanceRow(debt: d, onNudge: () {})),
          const SizedBox(height: Spacing.base),

          // ── History link ─────────────────────────────────────────────────
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'View 12 past settlements →',
                style: AppTextStyles.body(color: AppColors.forest)
                    .copyWith(fontSize: 13),
              ),
            ),
          ),
        ],
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
        border: Border(
          left: BorderSide(color: AppColors.forest, width: 3),
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.border,
              blurRadius: 0,
              spreadRadius: 0.5),
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
          // Minimal node graph icon
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
  final _DebtSample debt;
  final VoidCallback? onSettle;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final bgColor = debt.isOwedToYou ? AppColors.mint : AppColors.rose;
    final amtColor = debt.isOwedToYou ? AppColors.forest : AppColors.ember;

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
            AppAvatar(name: debt.personName, size: 36),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(debt.personName, style: AppTextStyles.bodyMedium()),
                  const SizedBox(height: 2),
                  Text(debt.context,
                      style: AppTextStyles.caption()),
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
                        'Settle via UPI →',
                        style: AppTextStyles.caption(
                                color: AppColors.white)
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
                        border: Border.all(
                            color: AppColors.stone, width: 0.5),
                      ),
                      child: Text(
                        'Nudge 🔔',
                        style: AppTextStyles.caption(
                            color: AppColors.stone),
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

// ─── Sample data ─────────────────────────────────────────────────────────────
class _DebtSample {
  final String personName, context, upiVpa;
  final double amount;
  final bool isOwedToYou;
  const _DebtSample({
    required this.personName,
    required this.context,
    required this.upiVpa,
    required this.amount,
    required this.isOwedToYou,
  });
}

const _sampleDebts = [
  _DebtSample(
    personName: 'Priya Sharma',
    context: 'Goa Trip food',
    upiVpa: 'priya.sharma@okaxis',
    amount: 340,
    isOwedToYou: false,
  ),
  _DebtSample(
    personName: 'Rahul Mehta',
    context: 'Petrol split',
    upiVpa: 'rahul.m@okicici',
    amount: 120,
    isOwedToYou: false,
  ),
  _DebtSample(
    personName: 'Arjun Kapoor',
    context: 'Hotel booking',
    upiVpa: 'arjun.k@ybl',
    amount: 810,
    isOwedToYou: true,
  ),
];
