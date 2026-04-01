import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/haptics.dart';
import '../../core/router/app_router.dart';
import 'ocr_pipeline.dart';

/// Editable item list shown after scanner processes a receipt.
/// This is the correction screen — users verify/edit OCR output before splitting.
///
/// Design rules (V1.0):
///  • Amber (🟡) row highlight for items where confidence < 0.7
///  • Swipe-to-delete with Ember background reveal
///  • Inline editing by tapping name or price
///  • Tax + tip sliders at bottom with live gross total
///  • "Split it" CTA — the money button
class ItemReviewScreen extends StatefulWidget {
  const ItemReviewScreen({super.key, required this.ocrResult});
  final OcrResult ocrResult;

  @override
  State<ItemReviewScreen> createState() => _ItemReviewScreenState();
}

class _ItemReviewScreenState extends State<ItemReviewScreen> {
  late List<_EditableItem> _items;
  double _taxPct = 0;
  double _tipPct = 0;
  bool _usedGemini = false;

  @override
  void initState() {
    super.initState();
    _usedGemini = widget.ocrResult.usedGemini;
    _items = widget.ocrResult.items
        .map((i) => _EditableItem(
              name: i.name,
              price: i.price,
              confidence: i.confidence,
            ))
        .toList();

    // If empty (fallback failed), give one blank row
    if (_items.isEmpty) {
      _items.add(_EditableItem(name: '', price: 0, confidence: 1.0));
    }
  }

  double get _subtotal =>
      _items.fold(0, (sum, i) => sum + i.price);

  double get _taxAmount => _subtotal * (_taxPct / 100);
  double get _tipAmount => _subtotal * (_tipPct / 100);
  double get _grandTotal => _subtotal + _taxAmount + _tipAmount;

  void _addItem() {
    Haptics.lightTap();
    setState(() {
      _items.add(_EditableItem(name: '', price: 0, confidence: 1.0));
    });
  }

  void _deleteItem(int index) {
    Haptics.deletion();
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: const Text('Review Items'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            onPressed: _addItem,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Gemini badge (if LLM was used) ───────────────────────────────
          if (_usedGemini)
            Container(
              width: double.infinity,
              color: AppColors.mint,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.base, vertical: Spacing.sm),
              child: Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'Gemini AI extracted these items — review carefully',
                      style: AppTextStyles.caption(color: AppColors.forest),
                    ),
                  ),
                ],
              ),
            ),

          // ── Low confidence warning ───────────────────────────────────────
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
                    'Highlighted items need review',
                    style: AppTextStyles.caption(color: AppColors.amber),
                  ),
                ],
              ),
            ),

          // ── Item list ─────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              itemCount: _items.length,
              itemBuilder: (_, i) => _ItemRow(
                item: _items[i],
                onChanged: (updated) =>
                    setState(() => _items[i] = updated),
                onDelete: () => _deleteItem(i),
              ),
            ),
          ),

          // ── Tax + tip sliders ─────────────────────────────────────────────
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

          // ── Split it button ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.base, 0, Spacing.base, Spacing.xl),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _items.isNotEmpty
                    ? () {
                        Haptics.lightTap();
                        context.go(AppRoutes.addExpense, extra: {
                          'items': _items
                              .map((i) => {'name': i.name, 'price': i.price})
                              .toList(),
                          'total': _grandTotal,
                        });
                      }
                    : null,
                child: Row(
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

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(
        text: widget.item.price > 0
            ? widget.item.price.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLow = widget.item.isLowConfidence;

    return Dismissible(
      key: Key('${widget.item.name}_${widget.item.price}'),
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
          color: isLow
              ? AppColors.amber.withOpacity(0.08)
              : AppColors.white,
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
              // Low confidence indicator
              if (isLow)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: const Icon(Icons.warning_amber_outlined,
                      color: AppColors.amber, size: 16),
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

              // Price — inline editable, DM Mono
              SizedBox(
                width: 72,
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
                      widget.item.copyWith(price: price, confidence: 1.0),
                    );
                  },
                ),
              ),
            ],
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
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          // Tax slider row
          _SliderRow(
            label: 'Tax',
            value: taxPct,
            amount: taxAmount,
            max: 30,
            divisions: 60,
            color: AppColors.stone,
            onChanged: onTaxChanged,
          ),

          // Tip slider row
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

          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: AppTextStyles.overline()),
              Text(
                CurrencyFormatter.format(grandTotal),
                style: AppTextStyles.amountMono(
                    color: AppColors.obsidian).copyWith(fontSize: 20),
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
          child: Text(label, style: AppTextStyles.caption()),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: AppColors.subtle,
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
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
  final double confidence;

  _EditableItem({
    required this.name,
    required this.price,
    required this.confidence,
  });

  bool get isLowConfidence => confidence < 0.7;

  _EditableItem copyWith(
          {String? name, double? price, double? confidence}) =>
      _EditableItem(
        name: name ?? this.name,
        price: price ?? this.price,
        confidence: confidence ?? this.confidence,
      );
}
