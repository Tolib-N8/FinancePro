import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics.freezed.dart';
part 'analytics.g.dart';

@freezed
class MonthlySummary with _$MonthlySummary {
  const factory MonthlySummary({
    required String month,
    required double income,
    required double expenses,
    required double savings,
    required double net,
  }) = _MonthlySummary;

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => _$MonthlySummaryFromJson(json);
}

@freezed
class CategoryBreakdown with _$CategoryBreakdown {
  const factory CategoryBreakdown({
    String? categoryId,
    required String categoryName,
    required double total,
    required double percentage,
    required String color,
  }) = _CategoryBreakdown;

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) =>
      _$CategoryBreakdownFromJson(json);
}

@freezed
class MonthlyTrend with _$MonthlyTrend {
  const factory MonthlyTrend({
    required String month,
    required double income,
    required double expenses,
  }) = _MonthlyTrend;

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) => _$MonthlyTrendFromJson(json);
}

@freezed
class ForecastData with _$ForecastData {
  const factory ForecastData({
    required String month,
    required Map<String, dynamic> predictions,
    double? totalPredicted,
    String? confidence,
    String? generatedAt,
  }) = _ForecastData;

  factory ForecastData.fromJson(Map<String, dynamic> json) => _$ForecastDataFromJson(json);
}
