// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  String get id => throw _privateConstructorUsedError;
  String get accountId => throw _privateConstructorUsedError;
  String? get toAccountId => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  double? get amountBase => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get categoryId => throw _privateConstructorUsedError;
  Category? get category => throw _privateConstructorUsedError;
  bool get aiCategorized => throw _privateConstructorUsedError;
  bool get isRecurring => throw _privateConstructorUsedError;
  List<Comment> get comments => throw _privateConstructorUsedError;
  List<Receipt> get receipts => throw _privateConstructorUsedError;
  String? get createdAt => throw _privateConstructorUsedError;
  String? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
          Transaction value, $Res Function(Transaction) then) =
      _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call(
      {String id,
      String accountId,
      String? toAccountId,
      String type,
      double amount,
      String currency,
      double? amountBase,
      String date,
      String? description,
      String? categoryId,
      Category? category,
      bool aiCategorized,
      bool isRecurring,
      List<Comment> comments,
      List<Receipt> receipts,
      String? createdAt,
      String? updatedAt});

  $CategoryCopyWith<$Res>? get category;
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? accountId = null,
    Object? toAccountId = freezed,
    Object? type = null,
    Object? amount = null,
    Object? currency = null,
    Object? amountBase = freezed,
    Object? date = null,
    Object? description = freezed,
    Object? categoryId = freezed,
    Object? category = freezed,
    Object? aiCategorized = null,
    Object? isRecurring = null,
    Object? comments = null,
    Object? receipts = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: null == accountId
          ? _value.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      toAccountId: freezed == toAccountId
          ? _value.toAccountId
          : toAccountId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      amountBase: freezed == amountBase
          ? _value.amountBase
          : amountBase // ignore: cast_nullable_to_non_nullable
              as double?,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as Category?,
      aiCategorized: null == aiCategorized
          ? _value.aiCategorized
          : aiCategorized // ignore: cast_nullable_to_non_nullable
              as bool,
      isRecurring: null == isRecurring
          ? _value.isRecurring
          : isRecurring // ignore: cast_nullable_to_non_nullable
              as bool,
      comments: null == comments
          ? _value.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as List<Comment>,
      receipts: null == receipts
          ? _value.receipts
          : receipts // ignore: cast_nullable_to_non_nullable
              as List<Receipt>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategoryCopyWith<$Res>? get category {
    if (_value.category == null) {
      return null;
    }

    return $CategoryCopyWith<$Res>(_value.category!, (value) {
      return _then(_value.copyWith(category: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
          _$TransactionImpl value, $Res Function(_$TransactionImpl) then) =
      __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String accountId,
      String? toAccountId,
      String type,
      double amount,
      String currency,
      double? amountBase,
      String date,
      String? description,
      String? categoryId,
      Category? category,
      bool aiCategorized,
      bool isRecurring,
      List<Comment> comments,
      List<Receipt> receipts,
      String? createdAt,
      String? updatedAt});

  @override
  $CategoryCopyWith<$Res>? get category;
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
      _$TransactionImpl _value, $Res Function(_$TransactionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? accountId = null,
    Object? toAccountId = freezed,
    Object? type = null,
    Object? amount = null,
    Object? currency = null,
    Object? amountBase = freezed,
    Object? date = null,
    Object? description = freezed,
    Object? categoryId = freezed,
    Object? category = freezed,
    Object? aiCategorized = null,
    Object? isRecurring = null,
    Object? comments = null,
    Object? receipts = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$TransactionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: null == accountId
          ? _value.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      toAccountId: freezed == toAccountId
          ? _value.toAccountId
          : toAccountId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      amountBase: freezed == amountBase
          ? _value.amountBase
          : amountBase // ignore: cast_nullable_to_non_nullable
              as double?,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as Category?,
      aiCategorized: null == aiCategorized
          ? _value.aiCategorized
          : aiCategorized // ignore: cast_nullable_to_non_nullable
              as bool,
      isRecurring: null == isRecurring
          ? _value.isRecurring
          : isRecurring // ignore: cast_nullable_to_non_nullable
              as bool,
      comments: null == comments
          ? _value._comments
          : comments // ignore: cast_nullable_to_non_nullable
              as List<Comment>,
      receipts: null == receipts
          ? _value._receipts
          : receipts // ignore: cast_nullable_to_non_nullable
              as List<Receipt>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl implements _Transaction {
  const _$TransactionImpl(
      {required this.id,
      required this.accountId,
      this.toAccountId,
      required this.type,
      required this.amount,
      required this.currency,
      this.amountBase,
      required this.date,
      this.description,
      this.categoryId,
      this.category,
      this.aiCategorized = false,
      this.isRecurring = false,
      final List<Comment> comments = const [],
      final List<Receipt> receipts = const [],
      this.createdAt,
      this.updatedAt})
      : _comments = comments,
        _receipts = receipts;

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final String id;
  @override
  final String accountId;
  @override
  final String? toAccountId;
  @override
  final String type;
  @override
  final double amount;
  @override
  final String currency;
  @override
  final double? amountBase;
  @override
  final String date;
  @override
  final String? description;
  @override
  final String? categoryId;
  @override
  final Category? category;
  @override
  @JsonKey()
  final bool aiCategorized;
  @override
  @JsonKey()
  final bool isRecurring;
  final List<Comment> _comments;
  @override
  @JsonKey()
  List<Comment> get comments {
    if (_comments is EqualUnmodifiableListView) return _comments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_comments);
  }

  final List<Receipt> _receipts;
  @override
  @JsonKey()
  List<Receipt> get receipts {
    if (_receipts is EqualUnmodifiableListView) return _receipts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_receipts);
  }

  @override
  final String? createdAt;
  @override
  final String? updatedAt;

  @override
  String toString() {
    return 'Transaction(id: $id, accountId: $accountId, toAccountId: $toAccountId, type: $type, amount: $amount, currency: $currency, amountBase: $amountBase, date: $date, description: $description, categoryId: $categoryId, category: $category, aiCategorized: $aiCategorized, isRecurring: $isRecurring, comments: $comments, receipts: $receipts, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.toAccountId, toAccountId) ||
                other.toAccountId == toAccountId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.amountBase, amountBase) ||
                other.amountBase == amountBase) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.aiCategorized, aiCategorized) ||
                other.aiCategorized == aiCategorized) &&
            (identical(other.isRecurring, isRecurring) ||
                other.isRecurring == isRecurring) &&
            const DeepCollectionEquality().equals(other._comments, _comments) &&
            const DeepCollectionEquality().equals(other._receipts, _receipts) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      accountId,
      toAccountId,
      type,
      amount,
      currency,
      amountBase,
      date,
      description,
      categoryId,
      category,
      aiCategorized,
      isRecurring,
      const DeepCollectionEquality().hash(_comments),
      const DeepCollectionEquality().hash(_receipts),
      createdAt,
      updatedAt);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(
      this,
    );
  }
}

abstract class _Transaction implements Transaction {
  const factory _Transaction(
      {required final String id,
      required final String accountId,
      final String? toAccountId,
      required final String type,
      required final double amount,
      required final String currency,
      final double? amountBase,
      required final String date,
      final String? description,
      final String? categoryId,
      final Category? category,
      final bool aiCategorized,
      final bool isRecurring,
      final List<Comment> comments,
      final List<Receipt> receipts,
      final String? createdAt,
      final String? updatedAt}) = _$TransactionImpl;

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  String get id;
  @override
  String get accountId;
  @override
  String? get toAccountId;
  @override
  String get type;
  @override
  double get amount;
  @override
  String get currency;
  @override
  double? get amountBase;
  @override
  String get date;
  @override
  String? get description;
  @override
  String? get categoryId;
  @override
  Category? get category;
  @override
  bool get aiCategorized;
  @override
  bool get isRecurring;
  @override
  List<Comment> get comments;
  @override
  List<Receipt> get receipts;
  @override
  String? get createdAt;
  @override
  String? get updatedAt;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaginatedTransactions _$PaginatedTransactionsFromJson(
    Map<String, dynamic> json) {
  return _PaginatedTransactions.fromJson(json);
}

/// @nodoc
mixin _$PaginatedTransactions {
  List<Transaction> get items => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  int get page => throw _privateConstructorUsedError;
  int get pageSize => throw _privateConstructorUsedError;

  /// Serializes this PaginatedTransactions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaginatedTransactions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaginatedTransactionsCopyWith<PaginatedTransactions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaginatedTransactionsCopyWith<$Res> {
  factory $PaginatedTransactionsCopyWith(PaginatedTransactions value,
          $Res Function(PaginatedTransactions) then) =
      _$PaginatedTransactionsCopyWithImpl<$Res, PaginatedTransactions>;
  @useResult
  $Res call({List<Transaction> items, int total, int page, int pageSize});
}

/// @nodoc
class _$PaginatedTransactionsCopyWithImpl<$Res,
        $Val extends PaginatedTransactions>
    implements $PaginatedTransactionsCopyWith<$Res> {
  _$PaginatedTransactionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaginatedTransactions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? page = null,
    Object? pageSize = null,
  }) {
    return _then(_value.copyWith(
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      page: null == page
          ? _value.page
          : page // ignore: cast_nullable_to_non_nullable
              as int,
      pageSize: null == pageSize
          ? _value.pageSize
          : pageSize // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaginatedTransactionsImplCopyWith<$Res>
    implements $PaginatedTransactionsCopyWith<$Res> {
  factory _$$PaginatedTransactionsImplCopyWith(
          _$PaginatedTransactionsImpl value,
          $Res Function(_$PaginatedTransactionsImpl) then) =
      __$$PaginatedTransactionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Transaction> items, int total, int page, int pageSize});
}

/// @nodoc
class __$$PaginatedTransactionsImplCopyWithImpl<$Res>
    extends _$PaginatedTransactionsCopyWithImpl<$Res,
        _$PaginatedTransactionsImpl>
    implements _$$PaginatedTransactionsImplCopyWith<$Res> {
  __$$PaginatedTransactionsImplCopyWithImpl(_$PaginatedTransactionsImpl _value,
      $Res Function(_$PaginatedTransactionsImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaginatedTransactions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? page = null,
    Object? pageSize = null,
  }) {
    return _then(_$PaginatedTransactionsImpl(
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      page: null == page
          ? _value.page
          : page // ignore: cast_nullable_to_non_nullable
              as int,
      pageSize: null == pageSize
          ? _value.pageSize
          : pageSize // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaginatedTransactionsImpl implements _PaginatedTransactions {
  const _$PaginatedTransactionsImpl(
      {required final List<Transaction> items,
      required this.total,
      required this.page,
      required this.pageSize})
      : _items = items;

  factory _$PaginatedTransactionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaginatedTransactionsImplFromJson(json);

  final List<Transaction> _items;
  @override
  List<Transaction> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final int total;
  @override
  final int page;
  @override
  final int pageSize;

  @override
  String toString() {
    return 'PaginatedTransactions(items: $items, total: $total, page: $page, pageSize: $pageSize)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaginatedTransactionsImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.pageSize, pageSize) ||
                other.pageSize == pageSize));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_items), total, page, pageSize);

  /// Create a copy of PaginatedTransactions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaginatedTransactionsImplCopyWith<_$PaginatedTransactionsImpl>
      get copyWith => __$$PaginatedTransactionsImplCopyWithImpl<
          _$PaginatedTransactionsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaginatedTransactionsImplToJson(
      this,
    );
  }
}

abstract class _PaginatedTransactions implements PaginatedTransactions {
  const factory _PaginatedTransactions(
      {required final List<Transaction> items,
      required final int total,
      required final int page,
      required final int pageSize}) = _$PaginatedTransactionsImpl;

  factory _PaginatedTransactions.fromJson(Map<String, dynamic> json) =
      _$PaginatedTransactionsImpl.fromJson;

  @override
  List<Transaction> get items;
  @override
  int get total;
  @override
  int get page;
  @override
  int get pageSize;

  /// Create a copy of PaginatedTransactions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaginatedTransactionsImplCopyWith<_$PaginatedTransactionsImpl>
      get copyWith => throw _privateConstructorUsedError;
}
