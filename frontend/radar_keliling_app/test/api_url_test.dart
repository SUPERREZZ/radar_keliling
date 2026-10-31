import 'package:flutter_test/flutter_test.dart';
import 'package:radar_keliling/config/app_config.dart';
import 'package:radar_keliling/core/api/endpoints.dart';
import 'package:radar_keliling/core/models/user_model.dart';

void main() {
  group('URL API', () {
    test('tidak menghasilkan /v1 ganda', () {
      final url = '${AppConfig.baseUrl}${Endpoints.login}';

      expect(url, 'http://backend.jh-beon.cloud/api/v1/auth/login');
      expect(url, isNot(contains('/v1/v1')));
    });
  });

  group('UserModel.homeRoute', () {
    UserModel user(String role) => UserModel(
      id: '1',
      email: 'user@example.com',
      role: role,
      emailVerified: true,
    );

    test('buyer diarahkan ke radar', () {
      expect(user('buyer').homeRoute, '/radar');
    });

    test('merchant diarahkan ke selling', () {
      expect(user('merchant').homeRoute, '/selling');
    });

    test('admin diarahkan ke laporan', () {
      expect(user('admin').homeRoute, '/admin/reports');
    });
  });
}
