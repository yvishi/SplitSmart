import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/haptics.dart';
import '../../shared/models/expense.dart';
import '../../shared/models/group.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../auth/auth_notifier.dart';
import '../groups/expenses_repository.dart';
import '../home/home_providers.dart';

/// Add Expense bottom sheet — supports all 4 split types.
class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key, this.groupId});
  final String? groupId;

  static Future<void> show(BuildContext context, {String? groupId}) {
    return AppBottomSheet.show(
      context,
      child: AddExpenseSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  SplitType _splitType = SplitType.equal;
  ExpenseCategory _category = ExpenseCategory.food;

  // Use String ID for dropdown — avoids Group object != issue after stream rebuild
  String? _selectedGroupId;
  String? _paidByUid;
  final Set<String> _selectedMembers = {};
  bool _initialized = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _initFromGroups(List<Group> groups, String currentUid) {
    if (_initialized || groups.isEmpty) return;
    _initialized = true;
    final initial = widget.groupId != null
        ? groups.firstWhere((g) => g.id == widget.groupId,
            orElse: () => groups.first)
        : groups.first;
    _selectedGroupId = initial.id;
    _paidByUid = currentUid;
    _selectedMembers
      ..clear()
      ..addAll(initial.memberUids);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final auth = ref.watch(authStateProvider);
    final currentUid = auth is AuthAuthenticated ? auth.profile.uid : null;

    if (currentUid == null || groupsAsync.isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final groups = groupsAsync.valueOrNull ?? [];
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Create a group first to add an expense.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium(),
        ),
      );
    }

    // Safe deferred initialization — never mutate state during build
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _initFromGroups(groups, currentUid));
      });
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Always lookup by ID so equality never fails after stream rebuild
    final selectedGroup =
        groups.firstWhere((g) => g.id == _selectedGroupId, orElse: () => groups.first);
    final members = selectedGroup.memberUids;

    // ── Sheet content ────────────────────────────────────────────────────
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Group Selector ─────────────────────────────────────────
            if (widget.groupId == null) ...[
              DropdownButtonFormField<String>(
                value: _selectedGroupId,
                decoration: const InputDecoration(labelText: 'Group'),
                items: groups
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(g.name),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final g = groups.firstWhere((g) => g.id == id);
                  setState(() {
                    _selectedGroupId = id;
                    _selectedMembers
                      ..clear()
                      ..addAll(g.memberUids);
                    if (!_selectedMembers.contains(_paidByUid)) {
                      _paidByUid = currentUid;
                    }
                  });
                },
              ),
              const SizedBox(height: Spacing.md),
            ],

            // ── Title ──────────────────────────────────────────────────
            TextField(
              controller: _titleCtrl,
              style: AppTextStyles.subtitle(),
              decoration: const InputDecoration(hintText: 'What was this for?'),
            ),
            const SizedBox(height: Spacing.md),

            // ── Amount ─────────────────────────────────────────────────
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: AppTextStyles.amountInput(),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: AppTextStyles.amountInput(color: AppColors.stone),
                prefixIcon: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Text('₹',
                      style: AppTextStyles.amountInput(
                          color: AppColors.stone)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
              ),
            ),
            const SizedBox(height: Spacing.base),

            // ── AI category chip ───────────────────────────────────────
            _AiCategorySuggestion(category: _category, onDismiss: null),
            const SizedBox(height: Spacing.base),

            // ── Split type ─────────────────────────────────────────────
            Text('Split', style: AppTextStyles.overline()),
            const SizedBox(height: Spacing.sm),
            Row(
              children: SplitType.values.map((t) {
                final sel = _splitType == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Haptics.lightTap();
                      setState(() => _splitType = t);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: Spacing.xs),
                      padding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.forest : AppColors.subtle,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _splitLabel(t),
                        style: AppTextStyles.caption(
                          color: sel
                              ? AppColors.white
                              : AppColors.stone,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.base),

            // ── Members ────────────────────────────────────────────────
            Text('With', style: AppTextStyles.overline()),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: members.map((uid) {
                final sel = _selectedMembers.contains(uid);
                return GestureDetector(
                  onTap: () {
                    Haptics.lightTap();
                    setState(() {
                      if (sel) {
                        _selectedMembers.remove(uid);
                      } else {
                        _selectedMembers.add(uid);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.xs),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.mint : AppColors.subtle,
                      borderRadius:
                          BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: sel
                            ? AppColors.forest
                            : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAvatar(name: uid, size: 20),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          uid == currentUid ? 'You' : uid.substring(0, 6),
                          style: AppTextStyles.caption(
                            color: sel
                                ? AppColors.forest
                                : AppColors.stone,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.base),

            // ── Paid by ────────────────────────────────────────────────
            Text('Paid by', style: AppTextStyles.overline()),
            const SizedBox(height: Spacing.sm),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                itemBuilder: (_, i) {
                  final uid = members[i];
                  final sel = _paidByUid == uid;
                  return GestureDetector(
                    onTap: () => setState(() => _paidByUid = uid),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: Spacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color:
                            sel ? AppColors.obsidian : AppColors.subtle,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppAvatar(name: uid, size: 20),
                          const SizedBox(width: Spacing.xs),
                          Text(
                            uid == currentUid ? 'You' : uid.substring(0, 6),
                            style: AppTextStyles.caption(
                              color: sel
                                  ? AppColors.white
                                  : AppColors.stone,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // ── Save ───────────────────────────────────────────────────
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _selectedGroupId != null &&
                        _selectedMembers.isNotEmpty &&
                        _paidByUid != null &&
                        _amountCtrl.text.isNotEmpty &&
                        _titleCtrl.text.isNotEmpty
                    ? _save
                    : null,
                child: const Text('Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    Haptics.lightTap();
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0 || _selectedGroupId == null || _paidByUid == null) return;

    final expense = Expense(
      id: const Uuid().v4(),
      groupId: _selectedGroupId!,
      title: _titleCtrl.text.trim(),
      totalAmount: amount,
      category: _category,
      splitType: _splitType,
      paidByUid: _paidByUid!,
      participantUids: _selectedMembers.toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdByUid: _paidByUid!,
    );

    await ExpensesRepository.createExpense(
      groupId: _selectedGroupId!,
      expense: expense,
    );

    if (mounted) Navigator.of(context).pop();
  }
}

// ─── AI category suggestion chip ─────────────────────────────────────────────
class _AiCategorySuggestion extends StatefulWidget {
  const _AiCategorySuggestion(
      {required this.category, required this.onDismiss});
  final ExpenseCategory category;
  final VoidCallback? onDismiss;

  @override
  State<_AiCategorySuggestion> createState() => _AiCategorySuggestionState();
}

class _AiCategorySuggestionState extends State<_AiCategorySuggestion> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.xs),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.forest, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                'AI: ${_catLabel(widget.category)}',
                style: AppTextStyles.caption(color: AppColors.forest)
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: const Icon(Icons.close, size: 14, color: AppColors.stone),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _catLabel(ExpenseCategory c) => switch (c) {
        ExpenseCategory.food => '🍕 Food',
        ExpenseCategory.transport => '🚖 Transport',
        ExpenseCategory.accommodation => '🏠 Accommodation',
        ExpenseCategory.entertainment => '🎬 Entertainment',
        ExpenseCategory.utilities => '💡 Utilities',
        ExpenseCategory.shopping => '🛍️ Shopping',
        ExpenseCategory.health => '💊 Health',
        ExpenseCategory.other => '📝 Other',
      };
}

String _splitLabel(SplitType t) => switch (t) {
      SplitType.equal => 'Equal',
      SplitType.unequal => 'Unequal',
      SplitType.percentage => '%',
      SplitType.itemBased => 'Items',
    };
