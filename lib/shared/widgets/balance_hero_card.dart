import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';

/// The hero balance card shown at the top of the Home screen.
///
/// Design: dark Obsidian card, Forest radial glow top-right,
/// large DM Mono balance, two directional pills.
class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({
    super.key,
    required this.netBalance,
    required this.totalOwedToYou,
    required this.totalYouOwe,
  });

  final double netBalance;
  final double totalOwedToYou;
  final double totalYouOwe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Spacing.base, Spacing.xxl, Spacing.base, Spacing.base),
      decoration: BoxDecoration(
        color: AppColors.obsidian,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Stack(
        children: [
          // Forest radial glow — top-right corner depth cue
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x331A6B4A), // Forest at 20% opacity
                    Color(0x001A6B4A),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Text(
                  'NET BALANCE',
                  style: AppTextStyles.overline(color: AppColors.heroLabel),
                ),
                const SizedBox(height: Spacing.sm),

                // Main amount
                Text(
                  CurrencyFormatter.format(netBalance.abs()),
                  style: AppTextStyles.displayMono(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  netBalance >= 0
                      ? 'owed to you overall'
                      : 'you owe overall',
                  style: AppTextStyles.caption(
                    color: AppColors.heroLabel,
                  ),
                ),
                const SizedBox(height: Spacing.base),

                // Directional pills row
                Row(
                  children: [
                    _DirectionPill(
                      label: 'you get',
                      amount: totalOwedToYou,
                      isPositive: true,
                    ),
                    const SizedBox(width: Spacing.sm),
                    _DirectionPill(
                      label: 'you owe',
                      amount: totalYouOwe,
                      isPositive: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionPill extends StatelessWidget {
  const _DirectionPill({
    required this.label,
    required this.amount,
    required this.isPositive,
  });

  final String label;
  final double amount;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final bg = isPositive
        ? const Color(0x1A1A6B4A) // Forest 10%
        : const Color(0x1AC0392B); // Ember 10%
    final textColor = isPositive ? AppColors.forest : AppColors.ember;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption(color: AppColors.heroLabel)
                  .copyWith(fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              '${isPositive ? '+' : '−'} ${CurrencyFormatter.format(amount)}',
              style: AppTextStyles.amountMono(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
