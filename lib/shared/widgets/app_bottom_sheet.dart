import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';

/// SplitSmart V1.0 — Standard bottom sheet presenter.
///
/// Rules:
///  • All confirmations use this — never center modals
///  • 24px top radius, drag-to-dismiss enabled
///  • Handle indicator: 32×3px pill, Border color, 12px from top
///  • Destructive button has 400ms tap delay (enforced by [DestructiveButton])
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

  /// Show this sheet. Returns the result from [child] if any.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(title: title, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: Spacing.md),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),

          // Optional title
          if (title != null) ...[
            const SizedBox(height: Spacing.base),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Content
          Padding(
            padding: EdgeInsets.only(
              left: Spacing.base,
              right: Spacing.base,
              top: Spacing.base,
              bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xl,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// A destructive action button with a mandatory 400ms delay.
/// Prevents accidental double-tap on irreversible actions.
class DestructiveButton extends StatefulWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    required this.onConfirm,
  });

  final String label;
  final VoidCallback onConfirm;

  @override
  State<DestructiveButton> createState() => _DestructiveButtonState();
}

class _DestructiveButtonState extends State<DestructiveButton> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _ready ? widget.onConfirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.obsidian,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          disabledBackgroundColor: AppColors.subtle,
        ),
        child: Text(widget.label),
      ),
    );
  }
}
