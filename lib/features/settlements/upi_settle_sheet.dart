import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_bottom_sheet.dart';

/// UPI Settle Up bottom sheet — the trust + conversion screen.
///
/// Features:
///  • Shows recipient avatar, name, UPI VPA, and amount
///  • Detects installed UPI apps (GPay, PhonePe, Paytm) via canLaunchUrl
///  • Pre-fills amount and VPA in the UPI deep-link
///  • Heavy haptic on successful settlement
///  • Trust note: "We don't handle payments — your UPI app does"
class UpiSettleSheet extends StatefulWidget {
  const UpiSettleSheet({super.key, required this.debt});

  final UpiDebtInfo debt;

  static Future<void> show(BuildContext context,
      {required dynamic debt}) {
    return AppBottomSheet.show(
      context,
      child: UpiSettleSheet(
        debt: UpiDebtInfo(
          personName: debt.personName as String,
          upiVpa: debt.upiVpa as String,
          amount: debt.amount as double,
        ),
      ),
    );
  }

  @override
  State<UpiSettleSheet> createState() => _UpiSettleSheetState();
}

class _UpiSettleSheetState extends State<UpiSettleSheet> {
  _UpiApp _selectedApp = _UpiApp.gpay;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ─── UPI deep-link builder ────────────────────────────────────────────────
  // Spec: upi://pay?pa=VPA&pn=Name&am=Amount&tn=Note&cu=INR
  Uri _buildUpiUri() {
    final amount = widget.debt.amount.toStringAsFixed(2);
    final note = _noteCtrl.text.trim().isEmpty
        ? 'SplitSmart settlement'
        : _noteCtrl.text.trim();
    return Uri.parse(
      'upi://pay'
      '?pa=${widget.debt.upiVpa}'
      '&pn=${Uri.encodeComponent(widget.debt.personName)}'
      '&am=$amount'
      '&tn=${Uri.encodeComponent(note)}'
      '&cu=INR',
    );
  }

  Future<void> _openUpi() async {
    final uri = _buildUpiUri();
    final canLaunch = await canLaunchUrl(uri);
    if (!mounted) return;

    if (canLaunch) {
      await Haptics.settlement(); // Heavy haptic — the money moment
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No UPI app found. Install GPay, PhonePe, or Paytm.',
            style: AppTextStyles.body(color: AppColors.white),
          ),
          backgroundColor: AppColors.obsidian,
        ),
      );
    }
  }

  Future<void> _markSettled() async {
    await Haptics.settlement();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.of(context).pop(true); // signals settled
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Recipient ────────────────────────────────────────────────────
        Center(
          child: AppAvatar(name: widget.debt.personName, size: 48),
        ),
        const SizedBox(height: Spacing.sm),
        Center(
          child: Text(widget.debt.personName,
              style: AppTextStyles.subtitle()),
        ),
        Center(
          child: Text(widget.debt.upiVpa,
              style: AppTextStyles.caption()),
        ),
        const SizedBox(height: Spacing.base),

        // ── Amount ───────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Text('AMOUNT', style: AppTextStyles.overline()),
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
                      color: selected
                          ? AppColors.forest
                          : AppColors.border,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(app.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        app.label,
                        style: AppTextStyles.caption(
                          color: selected
                              ? AppColors.forest
                              : AppColors.stone,
                        ).copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
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

        // ── Open UPI button ──────────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _openUpi,
            child: Text(
              'Open ${_selectedApp.label} →',
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Pre-filled with ${CurrencyFormatter.format(widget.debt.amount)} '
          'and UPI ID. Return here to confirm.',
          style: AppTextStyles.caption(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.base),

        // ── Mark settled manually ────────────────────────────────────────
        DestructiveButton(
          label: 'Mark as settled',
          onConfirm: _markSettled,
        ),
        const SizedBox(height: Spacing.sm),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: AppTextStyles.body(color: AppColors.stone)),
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
      ],
    );
  }
}

// ─── Supporting types ─────────────────────────────────────────────────────────
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

enum _UpiApp {
  gpay(emoji: 'G', label: 'Google Pay', scheme: 'gpay'),
  phonepe(emoji: '📱', label: 'PhonePe', scheme: 'phonepe'),
  paytm(emoji: '💙', label: 'Paytm', scheme: 'paytmmp');

  const _UpiApp(
      {required this.emoji, required this.label, required this.scheme});
  final String emoji;
  final String label;
  final String scheme;
}
