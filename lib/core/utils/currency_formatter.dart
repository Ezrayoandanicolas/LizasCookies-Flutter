import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _idrDecimal = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 2,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format: Rp 35.000
  static String idr(num amount) => _idr.format(amount);

  /// Format: Rp 35.000,00
  static String idrDecimal(num amount) => _idrDecimal.format(amount);

  /// Format: Rp 35K, Rp 1,2jt (compact)
  static String compact(num amount) => _compact.format(amount);

  /// Parse string to number (handles dots as thousand separator)
  static num? parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d,-]'), '');
    return num.tryParse(cleaned.replaceAll(',', '.'));
  }
}
