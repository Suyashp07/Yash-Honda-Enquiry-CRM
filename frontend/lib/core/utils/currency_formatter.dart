import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String format(dynamic amount) {
    if (amount == null) return '₹0';
    if (amount is num) {
      return _inrFormat.format(amount);
    }
    if (amount is String) {
      final parsed = double.tryParse(amount) ?? 0.0;
      return _inrFormat.format(parsed);
    }
    return '₹0';
  }
}

