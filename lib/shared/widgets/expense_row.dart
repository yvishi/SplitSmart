import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/models/expense.dart';

/// A single expense row as displayed in the home and group screens.
///
/// Design rules (V1.0):
///  • No dividers — 8px vertical spacing between rows
///  • Amount in DM Mono with tabular figures
///  • Ember for you-owe, Forest for you-get
///  • Tapped state: Chalk background, 150ms transition
class ExpenseRow extends StatelessWidget {
  const ExpenseRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isOwed, // true = you get back, false = you owe
    required this.category,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final double amount;
  final bool isOwed;
  final ExpenseCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amountColor = isOwed ? AppColors.forest : AppColors.ember;
    final amountLabel = isOwed ? 'you get back' : 'you owe';

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.chalk,
        highlightColor: AppColors.chalk,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.base,
            vertical: Spacing.md,
          ),
          child: Row(
            children: [
              // Category emoji in a rounded container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.subtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  _categoryEmoji(category),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: Spacing.md),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),

              // Amount + direction label
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(amount),
                    style: AppTextStyles.amountMono(color: amountColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    amountLabel,
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

  static String _categoryEmoji(ExpenseCategory cat) {
    return switch (cat) {
      ExpenseCategory.food => '🍕',
      ExpenseCategory.transport => '🚖',
      ExpenseCategory.accommodation => '🏠',
      ExpenseCategory.entertainment => '🎬',
      ExpenseCategory.utilities => '💡',
      ExpenseCategory.shopping => '🛍️',
      ExpenseCategory.health => '💊',
      ExpenseCategory.other => '📝',
    };
  }
}
