import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/endpoints.dart';
import '../core/models/analytics.dart';
import 'api_client_provider.dart';

final monthlySummaryProvider =
    FutureProvider.family<MonthlySummary, String?>((ref, month) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(
    Endpoints.analyticsSummary,
    queryParameters: month != null ? {'month': month} : null,
  );
  return MonthlySummary.fromJson(response.data);
});

// Use (dateFrom, dateTo) record — has structural equality, no infinite loops
final categoryBreakdownProvider =
    FutureProvider.family<List<CategoryBreakdown>, (String?, String?)>((ref, range) async {
  final (dateFrom, dateTo) = range;
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.analyticsByCategory,
      queryParameters: {
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      });
  return (response.data as List).map((e) => CategoryBreakdown.fromJson(e)).toList();
});

final monthlyTrendProvider =
    FutureProvider.family<List<MonthlyTrend>, int>((ref, months) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.analyticsMonthlyTrend,
      queryParameters: {'months': months});
  return (response.data as List).map((e) => MonthlyTrend.fromJson(e)).toList();
});

final forecastProvider =
    FutureProvider.family<ForecastData, String?>((ref, month) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(
    Endpoints.analyticsForecast,
    queryParameters: month != null ? {'month': month} : null,
  );
  return ForecastData.fromJson(response.data);
});
