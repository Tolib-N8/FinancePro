// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map json) => _$TransactionImpl(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      toAccountId: json['to_account_id'] as String?,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      amountBase: (json['amount_base'] as num?)?.toDouble(),
      date: json['date'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      category: json['category'] == null
          ? null
          : Category.fromJson(
              Map<String, dynamic>.from(json['category'] as Map)),
      aiCategorized: json['ai_categorized'] as bool? ?? false,
      isRecurring: json['is_recurring'] as bool? ?? false,
      comments: (json['comments'] as List<dynamic>?)
              ?.map(
                  (e) => Comment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      receipts: (json['receipts'] as List<dynamic>?)
              ?.map(
                  (e) => Receipt.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'account_id': instance.accountId,
      'to_account_id': instance.toAccountId,
      'type': instance.type,
      'amount': instance.amount,
      'currency': instance.currency,
      'amount_base': instance.amountBase,
      'date': instance.date,
      'description': instance.description,
      'category_id': instance.categoryId,
      'category': instance.category?.toJson(),
      'ai_categorized': instance.aiCategorized,
      'is_recurring': instance.isRecurring,
      'comments': instance.comments.map((e) => e.toJson()).toList(),
      'receipts': instance.receipts.map((e) => e.toJson()).toList(),
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

_$PaginatedTransactionsImpl _$$PaginatedTransactionsImplFromJson(Map json) =>
    _$PaginatedTransactionsImpl(
      items: (json['items'] as List<dynamic>)
          .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
    );

Map<String, dynamic> _$$PaginatedTransactionsImplToJson(
        _$PaginatedTransactionsImpl instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
      'page': instance.page,
      'page_size': instance.pageSize,
    };
