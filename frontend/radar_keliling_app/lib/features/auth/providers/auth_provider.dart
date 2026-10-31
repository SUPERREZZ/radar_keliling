import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/secure_storage.dart';

/// State autentikasi global — null = belum login / loading.
final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
      (ref) => AuthNotifier(ref.read(authServiceProvider)),
    );

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  final AuthService _service;

  Future<void> _init() async {
    try {
      final hasSession = await SecureStorage.hasSession();
      if (!hasSession) {
        state = const AsyncValue.data(null);
        debugPrint('[AuthProvider] _init: Tidak ada sesi tersimpan');
        return;
      }

      debugPrint('[AuthProvider] _init: Sesi ditemukan, memuat user...');
      final user = await _service.getMe();
      state = AsyncValue.data(user);
      debugPrint(
        '[AuthProvider] _init: User dimuat: ${user.email} (${user.role})',
      );
    } catch (e) {
      debugPrint('[AuthProvider] _init: Gagal memuat sesi: $e');
      try {
        await SecureStorage.clearSession();
      } catch (_) {
        // Storage tidak tersedia (mis. saat widget test).
      }
      state = const AsyncValue.data(null);
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.login(email: email, password: password);
      state = AsyncValue.data(user);
      debugPrint('[AuthProvider] Login berhasil: ${user.email} (${user.role})');
      return user;
    } catch (e, st) {
      debugPrint('[AuthProvider] Login gagal: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String role,
  }) async {
    await _service.register(email: email, password: password, role: role);
  }

  Future<void> logout() async {
    try {
      await _service.logout();
    } finally {
      state = const AsyncValue.data(null);
    }
  }

  /// Menandai user sudah login tanpa mengubah state loading/error,
  /// dipakai setelah verifikasi email dari halaman /verify.
  void setUser(UserModel user) {
    state = AsyncValue.data(user);
  }

  UserModel? get currentUser => state.valueOrNull;
}
