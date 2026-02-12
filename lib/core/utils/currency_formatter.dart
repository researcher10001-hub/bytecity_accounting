import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    symbol: '', // No symbol by default, can be added if needed
    decimalDigits: 2,
    locale: 'en_US', // Use en_US pattern for comma separators
  );

  static String format(dynamic amount) {
    if (amount == null) return '0.00';
    if (amount is String) {
      double? parsed = double.tryParse(amount);
      if (parsed == null) return '0.00';
      return _formatter.format(parsed);
    }
    if (amount is num) {
      return _formatter.format(amount);
    }
    return '0.00';
  }

  static String getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'BDT':
        return '৳';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      case 'AED':
        return 'AED';
      case 'RM':
        return 'RM';
      default:
        return currency.toUpperCase();
    }
  }
}
