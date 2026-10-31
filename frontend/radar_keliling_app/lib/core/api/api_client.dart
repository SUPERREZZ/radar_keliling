import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../utils/secure_storage.dart';

/// Provider global untuk DioClient — inject di mana pun butuh HTTP.
final apiClientProvider = Provider<DioClient>((ref) => DioClient());

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.code, required this.message});

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => '[$statusCode] $code: $message';
}

class DioClient {
  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      // LogInterceptor hanya di debug
      // LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }

  late final Dio _dio;
  Dio get raw => _dio;

  // ── convenience wrappers ──────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path,
          queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) =>
      _dio.delete<T>(path, options: options);
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      final body = response.data;
      if (body is Map && body.containsKey('error')) {
        final e = body['error'] as Map;
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          code: e['code']?.toString() ?? 'UNKNOWN',
          message: e['message']?.toString() ?? 'Terjadi kesalahan.',
        );
      }
    }
    handler.next(err);
  }
}
