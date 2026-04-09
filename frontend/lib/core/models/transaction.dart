import 'package:freezed_annotation/freezed_annotation.dart';

import 'category.dart';
import 'comment.dart';
import 'receipt.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String accountId,
    String? toAccountId,
    required String type,
    required double amount,
    required String currency,
    double? amountBase,
    required String date,
    String? description,
    String? categoryId,
    Category? category,
    @Default(false) bool aiCategorized,
    @Default(false) bool isRecurring,
    @Default([]) List<Comment> comments,
    @Default([]) List<Receipt> receipts,
    String? createdAt,
    String? updatedAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);
}

@freezed
class PaginatedTransactions with _$PaginatedTransactions {
  const factory PaginatedTransactions({
    required List<Transaction> items,
    required int total,
    required int page,
    required int pageSize,
  }) = _PaginatedTransactions;

  factory PaginatedTransactions.fromJson(Map<String, dynamic> json) =>
      _$PaginatedTransactionsFromJson(json);
}
