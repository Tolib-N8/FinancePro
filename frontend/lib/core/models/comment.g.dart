// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CommentImpl _$$CommentImplFromJson(Map json) => _$CommentImpl(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      body: json['body'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$$CommentImplToJson(_$CommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'transaction_id': instance.transactionId,
      'body': instance.body,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
