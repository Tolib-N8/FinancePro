import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({required String baseUrl, required String apiKey}) {
    // Strip a trailing slash so "http://192.168.1.42:8000/" + "/api/v1/..."
    // doesn't produce a double-slash path that some proxies reject.
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: normalizedBase,
      connectTimeout: const Duration(seconds: 10),
      // Statement import drives several Gemini calls (one per PDF page) and
      // can legitimately run a few minutes on a large multi-page statement.
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 2),
      // Default JSON for normal requests. Do NOT pin Content-Type in the
      // shared headers map — that overrides Dio's automatic
      // multipart/form-data + boundary detection for FormData uploads
      // (statement / receipt import), which makes the server unable to
      // parse the body and the request hangs.
      contentType: Headers.jsonContentType,
      headers: {
        'Authorization': 'Bearer $apiKey',
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
