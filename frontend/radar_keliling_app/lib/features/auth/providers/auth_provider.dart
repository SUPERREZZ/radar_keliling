import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/secure_storage.dart';

/// State autentikasi global — null = belum login / loading.
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
  (ref) => AuthNotifier(ref.read(authServiceProvider)),
);

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  final AuthService _service;

  Future<void> _init() async {
    final hasSession = await SecureStorage.hasSession();
    if (!hasSession) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final user = await _service.getMe();
      state = AsyncValue.data(user);
    } catch (_) {
      await SecureStorage.clearSession();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _service.login(email: email, password: password),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String role,
  }) async {
    await _service.register(email: email, password: password, role: role);
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AsyncValue.data(null);
  }

  UserModel? get currentUser => state.valueOrNull;
}
