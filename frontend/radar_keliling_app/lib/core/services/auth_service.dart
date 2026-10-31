import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/user_model.dart';
import '../utils/secure_storage.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(apiClientProvider)),
);

class AuthService {
  AuthService(this._api);
  final DioClient _api;

  /// Register — throws [ApiException] on failure.
  Future<void> register({
    required String email,
    required String password,
    required String role,
  }) async {
    await _api.post(
      Endpoints.register,
      data: {'email': email, 'password': password, 'role': role},
    );
  }

  /// Login — saves session, returns [UserModel].
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      Endpoints.login,
      data: {'email': email, 'password': password},
    );

    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    try {
      await SecureStorage.saveSession(
        token: token,
        role: user.role,
        userId: user.id,
        email: user.email,
      );
    } catch (e) {
      // Login tetap berhasil walau penyimpanan sesi bermasalah
      // (mis. web di konteks non-HTTPS). User cukup login ulang nanti.
      debugPrint('[AuthService] Gagal menyimpan sesi: $e');
    }

    debugPrint('[AuthService] Login berhasil: ${user.email} (${user.role})');
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post(Endpoints.logout);
    } catch (_) {
      // Token sudah tidak valid — tetap lanjut hapus sesi lokal.
    } finally {
      try {
        await SecureStorage.clearSession();
      } catch (_) {
        // Abaikan — sesi lokal mungkin sudah tidak ada.
      }
    }
  }

  Future<UserModel> getMe() async {
    final res = await _api.get(Endpoints.me);
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<void> verifyEmail(String token) async {
    await _api.post(Endpoints.emailVerify, data: {'token': token});
  }

  Future<String?> resendVerification({required String email}) async {
    final res = await _api.post(Endpoints.emailResend, data: {'email': email});
    final data = (res.data as Map)['data'];
    return data is Map ? data['message']?.toString() : null;
  }

  Future<void> registerFcmToken(String fcmToken) async {
    await _api.post(Endpoints.fcmToken, data: {'fcm_token': fcmToken});
  }

  Future<void> deleteAccount() async {
    await _api.delete(Endpoints.deleteAccount);
    await SecureStorage.clearSession();
  }
}
