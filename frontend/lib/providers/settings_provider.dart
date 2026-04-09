import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

class AppSettings {
  final String apiBaseUrl;
  final String apiKey;
  final String baseCurrency;

  const AppSettings({
    required this.apiBaseUrl,
    required this.apiKey,
    required this.baseCurrency,
  });
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiBaseUrl: prefs.getString(AppConstants.prefKeyApiBaseUrl) ?? AppConstants.defaultApiBaseUrl,
      apiKey: prefs.getString(AppConstants.prefKeyApiKey) ?? '',
      baseCurrency: prefs.getString(AppConstants.prefKeyBaseCurrency) ?? 'USD',
    );
  }

  Future<void> save({String? apiBaseUrl, String? apiKey, String? baseCurrency}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = state.value!;
    if (apiBaseUrl != null) await prefs.setString(AppConstants.prefKeyApiBaseUrl, apiBaseUrl);
    if (apiKey != null) await prefs.setString(AppConstants.prefKeyApiKey, apiKey);
    if (baseCurrency != null) await prefs.setString(AppConstants.prefKeyBaseCurrency, baseCurrency);
    state = AsyncData(AppSettings(
      apiBaseUrl: apiBaseUrl ?? current.apiBaseUrl,
      apiKey: apiKey ?? current.apiKey,
      baseCurrency: baseCurrency ?? current.baseCurrency,
    ));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
