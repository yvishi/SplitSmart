import 'package:intl/intl.dart';

/// SplitSmart V1.0 — Currency formatting utility.
///
/// All screens must use these methods — never format currency inline.
///
/// Rules:
///  • Always 2 decimal places: ₹340.00 not ₹340
///  • Indian locale: ₹1,00,000.00 not ₹100,000.00
///  • ₹ symbol everywhere — never INR or Rs.
///  • Pair with AppTextStyles.amountMono for tabular figures.
abstract final class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Format a double as Indian Rupees.
  /// e.g., 340.0 → "₹340.00", 100000.0 → "₹1,00,000.00"
  static String format(double amount) => _formatter.format(amount);

  /// Format without symbol — for cases where ₹ is shown separately.
  /// e.g., 340.0 → "340.00"
  static String formatRaw(double amount) =>
      NumberFormat('#,##,##0.00', 'en_IN').format(amount);

  /// Short format for chips/pills — rounds to nearest whole if .00
  /// e.g., 340.0 → "₹340", 340.5 → "₹340.50"
  static String formatShort(double amount) {
    if (amount == amount.truncateToDouble()) {
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      ).format(amount);
    }
    return format(amount);
  }
}
