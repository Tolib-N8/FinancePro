import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../core/api/api_client.dart';

final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final baseUrl =
      prefs.getString(AppConstants.prefKeyApiBaseUrl) ?? AppConstants.defaultApiBaseUrl;
  final apiKey = prefs.getString(AppConstants.prefKeyApiKey) ?? '';
  return ApiClient(baseUrl: baseUrl, apiKey: apiKey);
});
