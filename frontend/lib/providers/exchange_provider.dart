import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Fetches rates directly from frankfurter.app (free, no key needed).
/// Returns map like {"EUR": 0.92, "CAD": 1.36, ...} with base=1.0 included.
final exchangeRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final base = settings.baseCurrency.toUpperCase();

  try {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
    final r = await dio.get('https://open.er-api.com/v6/latest/$base');
    final raw = Map<String, dynamic>.from(r.data['rates'] as Map);
    return raw.map((k, v) => MapEntry(k.toUpperCase(), (v as num).toDouble()));
  } catch (_) {
    // Fallback: approximate rates based on USD
    return {
      'USD': 1.0,  'EUR': 0.92,  'GBP': 0.79,  'JPY': 149.5,
      'CAD': 1.36, 'AUD': 1.53,  'CHF': 0.90,  'CNY': 7.24,
      'INR': 83.1, 'TRY': 32.5,  'RUB': 91.5,  'KRW': 1325.0,
      'BRL': 5.0,  'SEK': 10.4,  'NOK': 10.6,  'DKK': 6.88,
      'PLN': 3.96, 'HUF': 356.0, 'CZK': 22.9,  'MXN': 17.1,
      'SGD': 1.34, 'UZS': 12700.0, 'TJS': 10.9,
    };
  }
});

/// Converts [amount] from [from] to [to] using cached rates (all relative to [base]).
/// Returns null if either rate is unavailable.
double? convertAmount(
  Map<String, double> rates,
  double amount,
  String from,
  String to,
  String base,
) {
  from = from.toUpperCase();
  to = to.toUpperCase();
  base = base.toUpperCase();
  if (from == to) return amount;

  // Step 1: from → base
  double inBase;
  if (from == base) {
    inBase = amount;
  } else {
    final rate = rates[from];
    if (rate == null || rate == 0) return null;
    inBase = amount / rate;
  }

  // Step 2: base → to
  if (to == base) return inBase;
  final rateTo = rates[to];
  if (rateTo == null) return null;
  return inBase * rateTo;
}
