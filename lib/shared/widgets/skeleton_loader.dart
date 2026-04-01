import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';

/// Skeleton loader that matches actual content shapes.
/// Never show a spinner alongside shimmer — use one or the other.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.subtle,
      highlightColor: AppColors.white,
      period: const Duration(milliseconds: 1600),
      child: child,
    );
  }
}

/// A single shimmer bar — use to compose skeleton shapes.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton for a single ExpenseRow.
class ExpenseRowSkeleton extends StatelessWidget {
  const ExpenseRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.base,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            // Category icon placeholder
            SkeletonBox(width: 40, height: 40, radius: AppRadius.md),
            const SizedBox(width: Spacing.md),
            // Text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 120, height: 11),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            // Amount placeholder
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonBox(width: 64, height: 14),
                const SizedBox(height: 6),
                SkeletonBox(width: 48, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the home screen balance hero card.
class BalanceCardSkeleton extends StatelessWidget {
  const BalanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Container(
        margin: const EdgeInsets.all(Spacing.base),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppColors.obsidian,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 80, height: 11),
            const SizedBox(height: Spacing.sm),
            SkeletonBox(width: 180, height: 38),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                SkeletonBox(width: 130, height: 32, radius: AppRadius.full),
                const SizedBox(width: Spacing.sm),
                SkeletonBox(width: 130, height: 32, radius: AppRadius.full),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the receipt scanner processing state.
class ReceiptSkeleton extends StatelessWidget {
  const ReceiptSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final widths = [0.80, 0.55, 0.90, 0.70, 0.65];

    return SkeletonLoader(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        padding: const EdgeInsets.all(Spacing.base),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.forest,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          return Column(
            children: [
              for (int i = 0; i < widths.length; i++) ...[
                SkeletonBox(
                  width: constraints.maxWidth * widths[i],
                  height: 14,
                ),
                if (i < widths.length - 1) const SizedBox(height: Spacing.md),
              ],
            ],
          );
        }),
      ),
    );
  }
}
