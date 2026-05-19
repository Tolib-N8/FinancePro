class Endpoints {
  static const String accounts = '/api/v1/accounts';
  static String account(String id) => '/api/v1/accounts/$id';
  static String accountTransactions(String id) =>
      '/api/v1/accounts/$id/transactions';
  static String recalculateBalance(String id) =>
      '/api/v1/accounts/$id/recalculate';
  static String importStatement(String id) =>
      '/api/v1/accounts/$id/import-statement';

  static const String categories = '/api/v1/categories';
  static String category(String id) => '/api/v1/categories/$id';

  static const String transactions = '/api/v1/transactions';
  static String transaction(String id) => '/api/v1/transactions/$id';
  static String transactionComments(String id) =>
      '/api/v1/transactions/$id/comments';
  static String transactionComment(String txId, String commentId) =>
      '/api/v1/transactions/$txId/comments/$commentId';
  static String categorizeTransaction(String id) =>
      '/api/v1/transactions/$id/categorize';

  static const String receiptUpload = '/api/v1/receipts/upload';
  static String receipt(String id) => '/api/v1/receipts/$id';
  static String receiptFile(String id) => '/api/v1/receipts/$id/file';
  static String linkReceipt(String receiptId, String txId) =>
      '/api/v1/receipts/$receiptId/link/$txId';

  static const String chatSessions = '/api/v1/chat/sessions';
  static String chatSession(String id) => '/api/v1/chat/sessions/$id';
  static String chatMessages(String id) => '/api/v1/chat/sessions/$id/messages';
  static String sendChatMessage(String id) =>
      '/api/v1/chat/sessions/$id/message';

  static const String exportCsv = '/api/v1/admin/export/csv';
  static const String fixAmountBase = '/api/v1/admin/fix-amount-base';

  static const String exchangeRates = '/api/v1/exchange/rates';
  static const String exchangeConvert = '/api/v1/exchange/convert';

  static const String analyticsSummary = '/api/v1/analytics/summary';
  static const String analyticsByCategory = '/api/v1/analytics/by-category';
  static const String analyticsMonthlyTrend = '/api/v1/analytics/monthly-trend';
  static const String analyticsForecast = '/api/v1/analytics/forecast';
  static const String analyticsRefreshForecast =
      '/api/v1/analytics/forecast/refresh';
}
