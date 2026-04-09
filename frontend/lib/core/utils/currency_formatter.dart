import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, String currency) {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, String currency) {
    if (amount.abs() >= 1000000) {
      return '${_getCurrencySymbol(currency)}${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '${_getCurrencySymbol(currency)}${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, currency);
  }

  static String _getCurrencySymbol(String code) {
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'RUB': '₽',
      'UAH': '₴',
      'KZT': '₸',
      'JPY': '¥',
      'CNY': '¥',
    };
    return symbols[code.toUpperCase()] ?? code;
  }
}
