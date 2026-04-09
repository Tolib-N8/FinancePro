class AppConstants {
  static const String defaultApiBaseUrl = 'http://localhost:8000';
  static const String prefKeyApiBaseUrl = 'api_base_url';
  static const String prefKeyApiKey = 'api_key';
  static const String prefKeyBaseCurrency = 'base_currency';

  static const double navBreakpoint = 800.0;

  static const List<String> accountTypes = ['bank', 'cash', 'credit_card', 'crypto'];

  static const List<String> transactionTypes = ['income', 'expense', 'transfer'];

  static const Map<String, String> accountTypeLabels = {
    'bank': 'Bank Account',
    'cash': 'Cash',
    'credit_card': 'Credit Card',
    'crypto': 'Crypto',
  };

  static const Map<String, String> transactionTypeLabels = {
    'income': 'Income',
    'expense': 'Expense',
    'transfer': 'Transfer',
  };
}
