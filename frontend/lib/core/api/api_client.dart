import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({required String baseUrl, required String apiKey}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(minutes: 2),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  static Future<ApiClient> create() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(AppConstants.prefKeyApiBaseUrl) ?? AppConstants.defaultApiBaseUrl;
    final apiKey = prefs.getString(AppConstants.prefKeyApiKey) ?? '';
    return ApiClient(baseUrl: baseUrl, apiKey: apiKey);
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<Response> postFormData(String path, FormData formData) =>
      _dio.post(path, data: formData);
}
