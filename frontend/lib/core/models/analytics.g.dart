// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MonthlySummaryImpl _$$MonthlySummaryImplFromJson(Map json) =>
    _$MonthlySummaryImpl(
      month: json['month'] as String,
      income: (json['income'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
      savings: (json['savings'] as num).toDouble(),
      net: (json['net'] as num).toDouble(),
    );

Map<String, dynamic> _$$MonthlySummaryImplToJson(
        _$MonthlySummaryImpl instance) =>
    <String, dynamic>{
      'month': instance.month,
      'income': instance.income,
      'expenses': instance.expenses,
      'savings': instance.savings,
      'net': instance.net,
    };

_$CategoryBreakdownImpl _$$CategoryBreakdownImplFromJson(Map json) =>
    _$CategoryBreakdownImpl(
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String,
      total: (json['total'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      color: json['color'] as String,
    );

Map<String, dynamic> _$$CategoryBreakdownImplToJson(
        _$CategoryBreakdownImpl instance) =>
    <String, dynamic>{
      'category_id': instance.categoryId,
      'category_name': instance.categoryName,
      'total': instance.total,
      'percentage': instance.percentage,
      'color': instance.color,
    };

_$MonthlyTrendImpl _$$MonthlyTrendImplFromJson(Map json) => _$MonthlyTrendImpl(
      month: json['month'] as String,
      income: (json['income'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
    );

Map<String, dynamic> _$$MonthlyTrendImplToJson(_$MonthlyTrendImpl instance) =>
    <String, dynamic>{
      'month': instance.month,
      'income': instance.income,
      'expenses': instance.expenses,
    };

_$ForecastDataImpl _$$ForecastDataImplFromJson(Map json) => _$ForecastDataImpl(
      month: json['month'] as String,
      predictions: Map<String, dynamic>.from(json['predictions'] as Map),
      totalPredicted: (json['total_predicted'] as num?)?.toDouble(),
      confidence: json['confidence'] as String?,
      generatedAt: json['generated_at'] as String?,
    );

Map<String, dynamic> _$$ForecastDataImplToJson(_$ForecastDataImpl instance) =>
    <String, dynamic>{
      'month': instance.month,
      'predictions': instance.predictions,
      'total_predicted': instance.totalPredicted,
      'confidence': instance.confidence,
      'generated_at': instance.generatedAt,
    };
