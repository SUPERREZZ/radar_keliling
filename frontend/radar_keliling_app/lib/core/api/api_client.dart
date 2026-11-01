import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../utils/secure_storage.dart';

/// Provider global untuk DioClient — inject di mana pun butuh HTTP.
final apiClientProvider = Provider<DioClient>((ref) => DioClient());

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  @override
  String toString() => '[$statusCode] $code: $message';
}

class DioClient {
  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(_AuthInterceptor());
  }

  late final Dio _dio;
  Dio get raw => _dio;

  // ── convenience wrappers ──────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _guard(
    () => _dio.get<T>(path, queryParameters: queryParameters, options: options),
  );

  Future<Response<T>> post<T>(String path, {dynamic data, Options? options}) =>
      _guard(() => _dio.post<T>(path, data: data, options: options));

  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) =>
      _guard(() => _dio.put<T>(path, data: data, options: options));

  Future<Response<T>> patch<T>(String path, {dynamic data, Options? options}) =>
      _guard(() => _dio.patch<T>(path, data: data, options: options));

  Future<Response<T>> delete<T>(String path, {dynamic data, Options? options}) =>
      _guard(() => _dio.delete<T>(path, data: data, options: options));

  /// Mengubah semua kegagalan Dio menjadi [ApiException] agar bisa
  /// ditangkap konsisten oleh layer UI.
  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final response = e.response;
    final body = response?.data;

    if (body is Map && body['error'] is Map) {
      final error = Map<String, dynamic>.from(body['error'] as Map);
      final rawDetails = error['details'];
      final details = rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : null;

      return ApiException(
        statusCode: response?.statusCode ?? 0,
        code: error['code']?.toString() ?? 'UNKNOWN',
        message: _buildMessage(
          error['message']?.toString() ?? 'Terjadi kesalahan.',
          details,
        ),
        details: details,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          statusCode: 0,
          code: 'TIMEOUT',
          message: 'Koneksi ke server terlalu lama. Coba lagi.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return ApiException(
          statusCode: 0,
          code: 'NETWORK_ERROR',
          message:
              'Tidak dapat terhubung ke server. Periksa koneksi internet kamu.',
        );
      case DioExceptionType.cancel:
        return ApiException(
          statusCode: 0,
          code: 'CANCELLED',
          message: 'Permintaan dibatalkan.',
        );
      default:
        final status = response?.statusCode ?? 0;
        final message = switch (status) {
          401 => 'Sesi kamu tidak valid. Silakan masuk kembali.',
          403 => 'Kamu tidak memiliki akses ke fitur ini.',
          404 => 'Data atau endpoint tidak ditemukan.',
          429 => 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
          >= 500 => 'Terjadi kesalahan pada server ($status). Coba lagi.',
          _ => 'Terjadi kesalahan. Coba lagi.',
        };
        return ApiException(
          statusCode: status,
          code: 'HTTP_$status',
          message: message,
        );
    }
  }

  String _buildMessage(String base, Map<String, dynamic>? details) {
    final detail = _firstDetail(details);
    if (detail == null) return base;
    return base.endsWith('.') ? '$base $detail' : '$base. $detail';
  }

  String? _firstDetail(Map<String, dynamic>? details) {
    if (details == null) return null;
    for (final value in details.values) {
      final first = value is List && value.isNotEmpty ? value.first : value;
      if (first is String && first.trim().isNotEmpty) {
        return _translateValidation(first.trim());
      }
    }
    return null;
  }

  String _translateValidation(String message) {
    const translations = {
      'The email has already been taken.': 'Email sudah terdaftar.',
      'The email field is required.': 'Email wajib diisi.',
      'The email field must be a valid email address.':
          'Format email tidak valid.',
      'The password field is required.': 'Kata sandi wajib diisi.',
      'The password field must be at least 8 characters.':
          'Kata sandi minimal 8 karakter.',
      'The selected role is invalid.': 'Role tidak valid.',
      'The token field is required.': 'Token wajib diisi.',
      'The token is invalid or has expired.':
          'Token tidak valid atau sudah kedaluwarsa.',
    };
    return translations[message] ?? message;
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await SecureStorage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Penyimpanan sesi gagal dibaca — lanjutkan request tanpa token.
    }
    handler.next(options);
  }
}
