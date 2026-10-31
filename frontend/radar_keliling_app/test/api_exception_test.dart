import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radar_keliling/core/api/api_client.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('EMAIL_NOT_VERIFIED dipetakan menjadi ApiException', () async {
    final client = DioClient();
    client.raw.httpClientAdapter = _FakeAdapter(
      403,
      '{"error":{"code":"EMAIL_NOT_VERIFIED",'
      '"message":"Email belum diverifikasi.","details":{}}}',
    );

    await expectLater(
      client.post(
        '/v1/auth/login',
        data: {'email': 'user@example.com', 'password': 'secret'},
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED')
            .having((e) => e.message, 'message', 'Email belum diverifikasi.'),
      ),
    );
  });

  test('detail validasi backend ditampilkan dalam Bahasa Indonesia', () async {
    final client = DioClient();
    client.raw.httpClientAdapter = _FakeAdapter(
      422,
      '{"error":{"code":"VALIDATION_ERROR",'
      '"message":"Data yang dikirim tidak valid.",'
      '"details":{"email":["The email has already been taken."]}}}',
    );

    await expectLater(
      client.post(
        '/v1/auth/register',
        data: {
          'email': 'user@example.com',
          'password': 'secret123',
          'role': 'buyer',
        },
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Data yang dikirim tidak valid. Email sudah terdaftar.',
        ),
      ),
    );
  });
}
