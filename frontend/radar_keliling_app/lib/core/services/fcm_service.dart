import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../utils/secure_storage.dart';

/// Top-level background message handler yang wajib terdaftar untuk Firebase.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint('[FCM Background] Pesan diterima: ${message.messageId}');
  } catch (e) {
    debugPrint('[FCM Background Error] $e');
  }
}

/// Provider global untuk FcmService.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final dioClient = ref.watch(apiClientProvider);
  return FcmService(dioClient);
});

/// Stream provider untuk mendengarkan pesan panggilan masuk (type == 'incoming_call') secara real-time.
final incomingCallFcmStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final fcmService = ref.watch(fcmServiceProvider);
  return fcmService.incomingCallStream;
});

class FcmService {
  FcmService(this._dioClient);

  final DioClient _dioClient;

  /// Getter aman untuk FirebaseMessaging instance (mencegah crash pada test environment).
  FirebaseMessaging? get _messaging {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<Map<String, dynamic>> _incomingCallStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get incomingCallStream =>
      _incomingCallStreamController.stream;

  String? _lastRegisteredToken;
  bool _initialized = false;

  /// Inisialisasi listener FCM, background handler, dan request permission.
  Future<void> initialize() async {
    if (_initialized) return;

    final messaging = _messaging;
    if (messaging == null) {
      debugPrint('[FCM] Firebase App belum diinisialisasi — listener dilewati.');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Minta izin notifikasi (wajib untuk Android 13+ & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '[FCM] Status izin notifikasi: ${settings.authorizationStatus}',
      );

      // Konfigurasi heads-up display untuk foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listener pesan saat aplikasi aktif di foreground
      FirebaseMessaging.onMessage.listen(_handleMessage);

      // Listener ketika user mengklik notifikasi (dari background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Periksa apakah aplikasi dibuka dari terminasi oleh klik notifikasi
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Listener refresh token otomatis dari Firebase SDK
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token disegarkan oleh Firebase SDK.');
        unawaited(syncTokenWithBackend(newToken));
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Inisialisasi FCM dilewati/gagal: $e');
    }
  }

  /// Mendaftarkan token perangkat saat ini ke backend Laravel.
  Future<void> registerCurrentToken() async {
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await syncTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Gagal mengambil token FCM: $e');
    }
  }

  /// Mengirimkan token ke backend API `/v1/auth/fcm-token`.
  Future<void> syncTokenWithBackend(String token) async {
    // Hindari request berulang jika token sama persis
    if (_lastRegisteredToken == token) return;

    final hasSession = await SecureStorage.hasSession();
    if (!hasSession) return;

    try {
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      await _dioClient.post(
        Endpoints.fcmToken,
        data: {
          'fcm_token': token,
          'device_type': deviceType,
        },
      );
      _lastRegisteredToken = token;
      debugPrint('[FCM] Berhasil mendaftarkan token FCM ke backend.');
    } catch (e) {
      debugPrint('[FCM] Gagal mengirim token FCM ke backend: $e');
    }
  }

  /// Menghapus token saat user melakukan logout.
  Future<void> deleteToken() async {
    final messaging = _messaging;
    try {
      final token = _lastRegisteredToken ?? await messaging?.getToken();
      if (token != null && token.isNotEmpty) {
        await _dioClient.delete(
          Endpoints.fcmToken,
          data: {
            'fcm_token': token,
          },
        );
      }
      await messaging?.deleteToken();
      _lastRegisteredToken = null;
      debugPrint('[FCM] Token FCM berhasil dihapus lokal & backend.');
    } catch (e) {
      debugPrint('[FCM] Gagal menghapus token FCM saat logout: $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint(
      '[FCM Foreground] Pesan: ${message.notification?.title} - ${message.notification?.body}',
    );
    _messageStreamController.add(message);

    final data = message.data;
    if (data['type'] == 'incoming_call') {
      debugPrint('[FCM] Terdeteksi incoming call payload: $data');
      _incomingCallStreamController.add(data);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM OpenedApp] Notifikasi dibuka: ${message.data}');
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      _incomingCallStreamController.add(data);
    }
  }

  void dispose() {
    _messageStreamController.close();
    _incomingCallStreamController.close();
  }
}
