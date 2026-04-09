// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReceiptImpl _$$ReceiptImplFromJson(Map json) => _$ReceiptImpl(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String?,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      merchant: json['merchant'] as String?,
      receiptDate: json['receipt_date'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      lineItems: json['line_items'] as List<dynamic>?,
      ocrStatus: json['ocr_status'] as String,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$$ReceiptImplToJson(_$ReceiptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'transaction_id': instance.transactionId,
      'file_name': instance.fileName,
      'mime_type': instance.mimeType,
      'merchant': instance.merchant,
      'receipt_date': instance.receiptDate,
      'total_amount': instance.totalAmount,
      'currency': instance.currency,
      'line_items': instance.lineItems,
      'ocr_status': instance.ocrStatus,
      'created_at': instance.createdAt,
    };
