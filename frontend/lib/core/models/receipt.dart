import 'package:freezed_annotation/freezed_annotation.dart';

part 'receipt.freezed.dart';
part 'receipt.g.dart';

@freezed
class Receipt with _$Receipt {
  const factory Receipt({
    required String id,
    String? transactionId,
    required String fileName,
    required String mimeType,
    String? merchant,
    String? receiptDate,
    double? totalAmount,
    String? currency,
    List<dynamic>? lineItems,
    required String ocrStatus,
    required String createdAt,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) => _$ReceiptFromJson(json);
}
