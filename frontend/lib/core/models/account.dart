import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    required String name,
    required String type,
    required String currency,
    required double balance,
    required String color,
    required String icon,
    @Default(true) bool isActive,
    String? createdAt,
    String? updatedAt,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);
}
