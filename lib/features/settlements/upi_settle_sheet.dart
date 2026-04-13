import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/haptics.dart';
import '../../shared/models/settlement.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../auth/auth_notifier.dart';
import '../home/home_providers.dart';
import 'settlements_provider.dart';
import 'settlements_repository.dart';

/// UPI Settle Up bottom sheet.
///
/// Shows the recipient, amount, a UPI app selector (dummy — opens deep-link),
/// and a "Mark as settled" button that writes a confirmed [Settlement] to
/// Firestore and refreshes the balance providers.
class UpiSettleSheet extends ConsumerStatefulWidget {
  const UpiSettleSheet({super.key, required this.debt});

  final PersonDebt debt;

  /// Opens the sheet. [ref] is used to refresh providers after settling.
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required PersonDebt debt,
  }) {
    return AppBottomSheet.show(
      context,
      child: ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: UpiSettleSheet(debt: debt),
      ),
    );
  }

  @override
  ConsumerState<UpiSettleSheet> createState() => _UpiSettleSheetState();
}

class _UpiSettleSheetState extends ConsumerState<UpiSettleSheet> {
  _UpiApp _selectedApp = _UpiApp.gpay;
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUpi() async {
    // On web canLaunchUrl for upi:// always returns false.
    // We show a friendly dummy simulation instead.
    await Haptics.lightTap();
    if (!mounted) return;
    _showUpiSimulationDialog();
  }

  void _showUpiSimulationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Text(_selectedApp.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(_selectedApp.label,
                style: AppTextStyles.subtitle()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paying ${CurrencyFormatter.format(widget.debt.amount)} to ${widget.debt.otherName}',
              style: AppTextStyles.body(),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'UPI ID: ${widget.debt.otherUpiVpa.isEmpty ? 'Not set' : widget.debt.otherUpiVpa}',
              style: AppTextStyles.caption(color: AppColors.stone),
            ),
            const SizedBox(height: Spacing.base),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '🔧  Payment gateway integration coming soon.\nTap "Mark as Settled" after completing payment manually.',
                style: AppTextStyles.caption(color: AppColors.forest),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close',
                style: AppTextStyles.body(color: AppColors.stone)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _markSettled();
            },
            child: const Text('Mark Settled'),
          ),
        ],
      ),
    );
  }

  // ─── Write settlement to Firestore ────────────────────────────────────────
  Future<void> _markSettled() async {
    if (_saving) return;
    setState(() => _saving = true);

    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) {
      setState(() => _saving = false);
      return;
    }

    try {
      await Haptics.settlement();

      final currentUid = auth.profile.uid;
      final now = DateTime.now();

      // 1. Write the settlement record
      await SettlementsRepository.createSettlement(
        Settlement(
          id: '',
          fromUid: currentUid,
          toUid: widget.debt.otherUid,
          amount: widget.debt.amount,
          status: SettlementStatus.confirmed,
          expenseIds: const [],
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          upiTxnId: null,
          createdAt: now,
          settledAt: now,
        ),
      );

      // 2. Bidirectionally mark settled shares and delete fully-settled expenses.
      //    Clears debts in both directions so neither user sees phantom balances.
      await SettlementsRepository.settleUpBetweenUsers(
        debtorUid: currentUid,
        creditorUid: widget.debt.otherUid,
      );

      // 3. Refresh all live balance providers
      ref.invalidate(settlementsStateProvider);
      ref.invalidate(netBalanceSummaryProvider);
      ref.invalidate(userSettlementsProvider);
      ref.invalidate(recentExpensesProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Settled with ${widget.debt.otherName}! '
                    'All shared expenses updated.'),
              ],
            ),
            backgroundColor: AppColors.forest,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record settlement. Try again.'),
            backgroundColor: AppColors.ember,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Recipient ────────────────────────────────────────────────────
        Center(child: AppAvatar(name: widget.debt.otherName, size: 56)),
        const SizedBox(height: Spacing.sm),
        Center(
          child: Text(widget.debt.otherName,
              style: AppTextStyles.subtitle()),
        ),
        Center(
          child: Text(
            widget.debt.otherUpiVpa.isEmpty
                ? 'UPI not set'
                : widget.debt.otherUpiVpa,
            style: AppTextStyles.caption(
              color: widget.debt.otherUpiVpa.isEmpty
                  ? AppColors.ember
                  : AppColors.stone,
            ),
          ),
        ),
        const SizedBox(height: Spacing.base),

        // ── Amount ───────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Text('YOU OWE', style: AppTextStyles.overline()),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(widget.debt.amount),
                style: AppTextStyles.amountLarge(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // ── UPI app selector ─────────────────────────────────────────────
        Text('Pay via', style: AppTextStyles.overline()),
        const SizedBox(height: Spacing.sm),
        Row(
          children: _UpiApp.values.map((app) {
            final selected = _selectedApp == app;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  Haptics.lightTap();
                  setState(() => _selectedApp = app);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: Spacing.sm),
                  padding: const EdgeInsets.symmetric(
                      vertical: Spacing.md, horizontal: Spacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected ? AppColors.forest : AppColors.border,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(app.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        app.label,
                        style: AppTextStyles.caption(
                          color: selected
                              ? AppColors.forest
                              : AppColors.stone,
                        ).copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Spacing.base),

        // ── Note field ───────────────────────────────────────────────────
        TextField(
          controller: _noteCtrl,
          style: AppTextStyles.body(),
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
          ),
        ),
        const SizedBox(height: Spacing.base),

        // ── Open UPI button (dummy) ───────────────────────────────────────
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _openUpi,
            icon: Text(_selectedApp.emoji,
                style: const TextStyle(fontSize: 16)),
            label: Text('Pay via ${_selectedApp.label}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),

        // ── Mark as settled (writes to Firestore) ─────────────────────────
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: _saving ? null : _markSettled,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.stone,
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.stone),
                  )
                : const Text('Mark as settled (paid outside app)'),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Center(
          child: TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: AppTextStyles.body(color: AppColors.stone)),
          ),
        ),
        const SizedBox(height: Spacing.sm),

        // ── Trust note ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '🔒  We don\'t handle payments — your UPI app does',
            style: AppTextStyles.caption(color: AppColors.forest),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Spacing.sm),
      ],
    );
  }
}

// ─── Supporting types ─────────────────────────────────────────────────────────

/// Re-exported for backward compat in case anything still references it.
class UpiDebtInfo {
  final String personName;
  final String upiVpa;
  final double amount;
  const UpiDebtInfo({
    required this.personName,
    required this.upiVpa,
    required this.amount,
  });
}

// ─── UPI app definitions ──────────────────────────────────────────────────────

class DestructiveButton extends StatelessWidget {
  const DestructiveButton(
      {super.key, required this.label, required this.onConfirm});
  final String label;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onConfirm,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ember,
          side: const BorderSide(color: AppColors.ember, width: 0.5),
        ),
        child: Text(label),
      ),
    );
  }
}

enum _UpiApp {
  gpay(emoji: '🟢', label: 'Google Pay', scheme: 'gpay'),
  phonepe(emoji: '💜', label: 'PhonePe', scheme: 'phonepe'),
  paytm(emoji: '💙', label: 'Paytm', scheme: 'paytmmp');

  const _UpiApp(
      {required this.emoji, required this.label, required this.scheme});
  final String emoji;
  final String label;
  final String scheme;
}
