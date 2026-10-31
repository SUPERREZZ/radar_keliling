import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'auth_token';
  static const _keyRole = 'user_role';
  static const _keyUserId = 'user_id';
  static const _keyEmail = 'user_email';

  static Future<void> saveSession({
    required String token,
    required String role,
    required String userId,
    required String email,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyRole, value: role),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyEmail, value: email),
    ]);
  }

  static Future<String?> getToken() => _storage.read(key: _keyToken);
  static Future<String?> getRole() => _storage.read(key: _keyRole);
  static Future<String?> getUserId() => _storage.read(key: _keyUserId);
  static Future<String?> getEmail() => _storage.read(key: _keyEmail);

  static Future<bool> hasSession() async {
    final token = await _storage.read(key: _keyToken);
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyRole),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyEmail),
    ]);
  }
}
