import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/haptics.dart';
import '../../core/router/app_router.dart';
import '../auth/auth_notifier.dart';
import 'ocr_pipeline.dart';
import 'receipt_storage_service.dart';

/// Editable item list shown after the scanner processes a receipt.
///
/// Features:
///  • Amber row highlight for items where confidence < 0.7
///  • Auto-scroll + flash animation to first low-confidence item on open
///  • Swipe-to-delete with ember background reveal
///  • Inline tap-to-edit name and price
///  • Qty badge (non-editable — derived from Gemini)
///  • Tax + tip sliders with live grand total
///  • "Split it" CTA → uploads receipt image → opens AddExpenseSheet
///    pre-filled with items + total + receiptImageUrl
///  • "Rescan" AppBar button to go back to camera
class ItemReviewScreen extends ConsumerStatefulWidget {
  const ItemReviewScreen({
    super.key,
    required this.ocrResult,
    this.imageFile,
  });

  final OcrResult ocrResult;

  /// The original image file from the scanner — used for Storage upload.
  final File? imageFile;

  @override
  ConsumerState<ItemReviewScreen> createState() => _ItemReviewScreenState();
}

class _ItemReviewScreenState extends ConsumerState<ItemReviewScreen> {
  late List<_EditableItem> _items;
  double _taxPct = 0;
  double _tipPct = 0;
  bool _uploading = false;

  final _scrollController = ScrollController();
  final List<GlobalKey> _rowKeys = [];

  @override
  void initState() {
    super.initState();
    _items = widget.ocrResult.items
        .map((i) => _EditableItem(
              name: i.name,
              price: i.price,
              qty: i.qty,
              confidence: i.confidence,
            ))
        .toList();

    // Give one blank row if the pipeline returned nothing
    if (_items.isEmpty) {
      _items.add(_EditableItem(name: '', price: 0, qty: 1, confidence: 1.0));
    }

    _rowKeys.addAll(List.generate(_items.length, (_) => GlobalKey()));

    // Auto-scroll to the first low-confidence item after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusLowConfidence());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Low-confidence auto-focus ──────────────────────────────────────────────

  Future<void> _focusLowConfidence() async {
    final idx = _items.indexWhere((i) => i.isLowConfidence);
    if (idx < 0 || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final ctx = _rowKeys[idx].currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.3,
    );
    // Brief amber flash to draw attention
    setState(() => _items[idx] = _items[idx].copyWith(flash: true));
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _items[idx] = _items[idx].copyWith(flash: false));
  }

  // ── Totals ────────────────────────────────────────────────────────────────

  double get _subtotal => _items.fold(0, (s, i) => s + i.price);
  double get _taxAmount => _subtotal * (_taxPct / 100);
  double get _tipAmount => _subtotal * (_tipPct / 100);
  double get _grandTotal => _subtotal + _taxAmount + _tipAmount;

  // ── Item CRUD ─────────────────────────────────────────────────────────────

  void _addItem() {
    Haptics.lightTap();
    setState(() {
      _items.add(_EditableItem(name: '', price: 0, qty: 1, confidence: 1.0));
      _rowKeys.add(GlobalKey());
    });
  }

  void _deleteItem(int index) {
    Haptics.deletion();
    setState(() {
      _items.removeAt(index);
      _rowKeys.removeAt(index);
    });
  }

  // ── Split it ──────────────────────────────────────────────────────────────

  Future<void> _splitIt() async {
    if (_uploading) return;
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) return;

    setState(() => _uploading = true);
    await Haptics.lightTap();

    // Upload receipt image in background (don't block on failure)
    String? receiptUrl;
    if (widget.imageFile != null) {
      final expenseId = const Uuid().v4();
      receiptUrl = await ReceiptStorageService.upload(
        imageFile: widget.imageFile!,
        uid: auth.profile.uid,
        expenseId: expenseId,
      );
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    // Navigate to add-expense, passing pre-filled data
    context.go(AppRoutes.addExpense, extra: {
      'items': _items
          .where((i) => i.name.isNotEmpty && i.price > 0)
          .map((i) => {'name': i.name, 'price': i.price, 'qty': i.qty})
          .toList(),
      'total': _grandTotal,
      'taxFraction': _taxPct / 100,
      'tipFraction': _tipPct / 100,
      'receiptImageUrl': receiptUrl,
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when user scrolls or taps outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.chalk,
        appBar: AppBar(
          title: const Text('Review Items'),
          actions: [
            // Rescan — go back to the scanner
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'Rescan',
              onPressed: () => context.go(AppRoutes.scanner),
            ),
            // Add item
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: _addItem,
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Source badge ─────────────────────────────────────────────
            _SourceBadge(source: widget.ocrResult.source),

            // ── Low-confidence warning ───────────────────────────────────
            if (_items.any((i) => i.isLowConfidence))
              Container(
                width: double.infinity,
                color: AppColors.amber.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.base, vertical: Spacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: AppColors.amber, size: 16),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '🟡 highlighted items need review',
                      style: AppTextStyles.caption(color: AppColors.amber),
                    ),
                  ],
                ),
              ),

            // ── Item list ────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                itemCount: _items.length,
                itemBuilder: (_, i) => KeyedSubtree(
                  key: _rowKeys[i],
                  child: _ItemRow(
                    item: _items[i],
                    onChanged: (updated) =>
                        setState(() => _items[i] = updated),
                    onDelete: () => _deleteItem(i),
                  ),
                ),
              ),
            ),

            // ── Tax + tip sliders ────────────────────────────────────────
            _TaxTipPanel(
              subtotal: _subtotal,
              taxPct: _taxPct,
              tipPct: _tipPct,
              taxAmount: _taxAmount,
              tipAmount: _tipAmount,
              grandTotal: _grandTotal,
              onTaxChanged: (v) => setState(() => _taxPct = v),
              onTipChanged: (v) => setState(() => _tipPct = v),
            ),

            // ── Split it CTA ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.base, 0, Spacing.base, Spacing.xl),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _items.any((i) => i.name.isNotEmpty && i.price > 0)
                      ? _splitIt
                      : null,
                  child: _uploading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.group_outlined, size: 18),
                            const SizedBox(width: Spacing.sm),
                            Text(
                              'Split ${CurrencyFormatter.format(_grandTotal)}',
                              style: AppTextStyles.bodyMedium(
                                  color: AppColors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Source badge ─────────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final OcrSource source;

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, text) = switch (source) {
      OcrSource.geminiVision => (
          AppColors.forest,
          AppColors.mint,
          '✨ Gemini Vision extracted these items — review before splitting',
        ),
      OcrSource.geminiText => (
          AppColors.forest,
          AppColors.mint,
          '✦ Gemini AI extracted from OCR text — please verify',
        ),
      OcrSource.mlKitRegex => (
          AppColors.stone,
          AppColors.subtle,
          '⚡ Extracted on-device (offline) — verify highlighted items',
        ),
    };

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.base, vertical: Spacing.sm),
      child: Text(text, style: AppTextStyles.caption(color: color)),
    );
  }
}

// ─── Item row ─────────────────────────────────────────────────────────────────
class _ItemRow extends StatefulWidget {
  const _ItemRow({
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });
  final _EditableItem item;
  final ValueChanged<_EditableItem> onChanged;
  final VoidCallback onDelete;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final AnimationController _flashCtrl;
  late final Animation<Color?> _flashAnim;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(
        text: widget.item.price > 0
            ? widget.item.price.toStringAsFixed(2)
            : '');

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashAnim = ColorTween(
      begin: AppColors.amber.withOpacity(0.35),
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger flash animation when parent sets flash=true
    if (widget.item.flash && !oldWidget.item.flash) {
      _flashCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLow = widget.item.isLowConfidence;

    return AnimatedBuilder(
      animation: _flashAnim,
      builder: (_, child) => Container(
        color: widget.item.flash ? _flashAnim.value : null,
        child: child,
      ),
      child: Dismissible(
        key: ValueKey('${widget.item.name}_${widget.item.price}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: Spacing.base),
          color: AppColors.ember.withOpacity(0.15),
          child: const Icon(Icons.delete_outline,
              color: AppColors.ember, size: 22),
        ),
        onDismissed: (_) => widget.onDelete(),
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: Spacing.base, vertical: Spacing.xs),
          decoration: BoxDecoration(
            color: isLow ? AppColors.amber.withOpacity(0.08) : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isLow ? AppColors.amber : AppColors.border,
              width: isLow ? 1.0 : 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            child: Row(
              children: [
                // Warning icon for low-confidence items
                if (isLow)
                  const Padding(
                    padding: EdgeInsets.only(right: Spacing.sm),
                    child: Icon(Icons.warning_amber_outlined,
                        color: AppColors.amber, size: 16),
                  ),

                // Qty badge (non-editable — set by Gemini)
                if (widget.item.qty > 1)
                  Container(
                    margin: const EdgeInsets.only(right: Spacing.sm),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.subtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '×${widget.item.qty}',
                      style: AppTextStyles.caption(color: AppColors.stone)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),

                // Item name — inline editable
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: AppTextStyles.body(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Item name',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      fillColor: Colors.transparent,
                      filled: true,
                    ),
                    onChanged: (v) => widget.onChanged(
                      widget.item.copyWith(name: v, confidence: 1.0),
                    ),
                  ),
                ),

                // Price — inline editable, monospace
                SizedBox(
                  width: 78,
                  child: TextField(
                    controller: _priceCtrl,
                    style: AppTextStyles.amountMono(),
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      fillColor: Colors.transparent,
                      filled: true,
                    ),
                    onChanged: (v) {
                      final price = double.tryParse(v) ?? 0;
                      widget.onChanged(
                          widget.item.copyWith(price: price, confidence: 1.0));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tax + tip panel ─────────────────────────────────────────────────────────
class _TaxTipPanel extends StatelessWidget {
  const _TaxTipPanel({
    required this.subtotal,
    required this.taxPct,
    required this.tipPct,
    required this.taxAmount,
    required this.tipAmount,
    required this.grandTotal,
    required this.onTaxChanged,
    required this.onTipChanged,
  });

  final double subtotal, taxPct, tipPct, taxAmount, tipAmount, grandTotal;
  final ValueChanged<double> onTaxChanged;
  final ValueChanged<double> onTipChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Spacing.base, Spacing.md, Spacing.base, Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        border:
            Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          _SliderRow(
            label: 'Tax',
            value: taxPct,
            amount: taxAmount,
            max: 30,
            divisions: 60,
            color: AppColors.stone,
            onChanged: onTaxChanged,
          ),
          _SliderRow(
            label: 'Tip',
            value: tipPct,
            amount: tipAmount,
            max: 30,
            divisions: 30,
            color: AppColors.forest,
            onChanged: onTipChanged,
          ),
          const Divider(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: AppTextStyles.overline()),
              Text(
                CurrencyFormatter.format(grandTotal),
                style: AppTextStyles.amountMono(color: AppColors.obsidian)
                    .copyWith(fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.amount,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value, amount, max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 28,
            child: Text(label, style: AppTextStyles.caption())),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: AppColors.subtle,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            style: AppTextStyles.caption(),
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        SizedBox(
          width: 64,
          child: Text(
            CurrencyFormatter.format(amount),
            style: AppTextStyles.amountMono(color: color)
                .copyWith(fontSize: 11),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ─── Editable item model ──────────────────────────────────────────────────────
class _EditableItem {
  final String name;
  final double price;
  final int qty;
  final double confidence;

  /// Triggers an amber flash animation when true — cleared after 600ms.
  final bool flash;

  _EditableItem({
    required this.name,
    required this.price,
    this.qty = 1,
    required this.confidence,
    this.flash = false,
  });

  bool get isLowConfidence => confidence < 0.7;

  _EditableItem copyWith({
    String? name,
    double? price,
    int? qty,
    double? confidence,
    bool? flash,
  }) =>
      _EditableItem(
        name: name ?? this.name,
        price: price ?? this.price,
        qty: qty ?? this.qty,
        confidence: confidence ?? this.confidence,
        flash: flash ?? this.flash,
      );
}
