import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/endpoints.dart';
import '../core/models/transaction.dart';
import 'api_client_provider.dart';

class TransactionFilters {
  final String? accountId;
  final String? categoryId;
  final String? type;
  final String? dateFrom;
  final String? dateTo;
  final String? search;
  final int page;
  final int pageSize;

  const TransactionFilters({
    this.accountId,
    this.categoryId,
    this.type,
    this.dateFrom,
    this.dateTo,
    this.search,
    this.page = 1,
    this.pageSize = 50,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilters &&
          accountId == other.accountId &&
          categoryId == other.categoryId &&
          type == other.type &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo &&
          search == other.search &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(accountId, categoryId, type, dateFrom, dateTo, search, page, pageSize);
}

final transactionsProvider =
    FutureProvider.family<PaginatedTransactions, TransactionFilters>((ref, filters) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.transactions, queryParameters: {
    if (filters.accountId != null) 'account_id': filters.accountId,
    if (filters.categoryId != null) 'category_id': filters.categoryId,
    if (filters.type != null) 'type': filters.type,
    if (filters.dateFrom != null) 'date_from': filters.dateFrom,
    if (filters.dateTo != null) 'date_to': filters.dateTo,
    if (filters.search != null) 'search': filters.search,
    'page': filters.page,
    'page_size': filters.pageSize,
  });
  return PaginatedTransactions.fromJson(response.data);
});

final transactionDetailProvider =
    FutureProvider.family<Transaction, String>((ref, id) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.transaction(id));
  return Transaction.fromJson(response.data);
});
