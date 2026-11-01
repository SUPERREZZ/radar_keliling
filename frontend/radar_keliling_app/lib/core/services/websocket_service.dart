import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../utils/secure_storage.dart';

final wsServiceProvider = Provider<WebSocketService>((_) => WebSocketService());

typedef WsEventCallback =
    void Function(String eventName, Map<String, dynamic> data);

class WebSocketService {
  WebSocket? _socket;
  StreamSubscription? _socketSub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _socketId;
  bool _isConnecting = false;
  bool _manualDisconnect = false;

  final Set<String> _subscribedChannels = {};
  final Set<String> _activeServerSubscriptions = {};

  WsEventCallback? _onEvent;
  VoidCallback? _onReconnect;
  final Map<String, WsEventCallback> _listeners = {};
  final Map<String, VoidCallback> _reconnectListeners = {};

  final Dio _authDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  void addListener(
    String id, {
    required WsEventCallback onEvent,
    VoidCallback? onReconnect,
  }) {
    _listeners[id] = onEvent;
    if (onReconnect != null) {
      _reconnectListeners[id] = onReconnect;
    }
    _ensureConnected();
  }

  void removeListener(String id) {
    _listeners.remove(id);
    _reconnectListeners.remove(id);
  }

  Future<void> connect({
    required WsEventCallback onEvent,
    VoidCallback? onReconnect,
  }) async {
    _onEvent = onEvent;
    _onReconnect = onReconnect;
    _manualDisconnect = false;
    await _ensureConnected();
  }

  Future<void> _ensureConnected() async {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      return;
    }
    if (_isConnecting) return;

    if (AppConfig.reverbAppKey == 'YOUR_REVERB_APP_KEY' ||
        AppConfig.reverbAppKey.isEmpty) {
      debugPrint(
        '[WS] Reverb app key belum dikonfigurasi — realtime dilewati.',
      );
      return;
    }

    _isConnecting = true;
    final wasConnectedBefore = _socketId != null;

    try {
      final scheme = AppConfig.wsTls ? 'wss' : 'ws';
      final wsUrl =
          '$scheme://${AppConfig.wsHost}:${AppConfig.wsPort}/app/${AppConfig.reverbAppKey}?protocol=7&client=flutter&version=1.0&flash=false';

      final socket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 8),
      );
      _socket = socket;
      _activeServerSubscriptions.clear();

      _socketSub?.cancel();
      _socketSub = socket.listen(
        (rawMessage) => _handleRawMessage(rawMessage, wasConnectedBefore),
        onDone: _handleSocketClosed,
        onError: (e) {
          debugPrint('[WS Error] $e');
          _handleSocketClosed();
        },
        cancelOnError: true,
      );

      _startPingTimer();
    } catch (e) {
      debugPrint('[WS] WebSocket connection error: $e');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleRawMessage(dynamic rawMessage, bool wasReconnect) {
    if (rawMessage is! String) return;

    try {
      final decoded = jsonDecode(rawMessage) as Map<String, dynamic>;
      final eventName = decoded['event'] as String? ?? '';
      final rawData = decoded['data'];

      if (eventName == 'pusher:connection_established') {
        final dataMap = rawData is String
            ? jsonDecode(rawData) as Map<String, dynamic>
            : (rawData as Map<String, dynamic>? ?? {});
        _socketId = dataMap['socket_id'] as String?;
        debugPrint('[WS] Connected to Reverb (socket_id: $_socketId)');

        for (final ch in _subscribedChannels.toList()) {
          _sendSubscribe(ch);
        }

        if (wasReconnect) {
          _onReconnect?.call();
          for (final cb in _reconnectListeners.values.toList()) {
            cb();
          }
        }
        return;
      }

      if (eventName == 'pusher:ping') {
        _sendJson({'event': 'pusher:pong', 'data': <String, dynamic>{}});
        return;
      }

      if (eventName.startsWith('pusher:') ||
          eventName.startsWith('pusher_internal:')) {
        return;
      }

      Map<String, dynamic> eventData = {};
      if (rawData is String && rawData.isNotEmpty) {
        final parsed = jsonDecode(rawData);
        if (parsed is Map<String, dynamic>) {
          eventData = parsed;
        }
      } else if (rawData is Map<String, dynamic>) {
        eventData = rawData;
      }

      final normalizedEvent = eventName.startsWith('.')
          ? eventName.substring(1)
          : eventName;

      _onEvent?.call(normalizedEvent, eventData);
      for (final listener in _listeners.values.toList()) {
        listener(normalizedEvent, eventData);
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  Future<void> _sendSubscribe(String channel) async {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    if (_socketId == null) return;
    if (_activeServerSubscriptions.contains(channel)) return;

    try {
      if (channel.startsWith('private-') || channel.startsWith('presence-')) {
        final token = await SecureStorage.getToken();
        if (token == null || token.isEmpty) return;

        final res = await _authDio.post(
          '/v1/broadcasting/auth',
          data: {
            'socket_id': _socketId,
            'channel_name': channel,
          },
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );

        final resMap = res.data is String
            ? jsonDecode(res.data as String) as Map<String, dynamic>
            : (res.data as Map).cast<String, dynamic>();
        final authSignature = resMap['auth'] as String?;
        if (authSignature == null) return;

        _sendJson({
          'event': 'pusher:subscribe',
          'data': {
            'channel': channel,
            'auth': authSignature,
          },
        });
      } else {
        _sendJson({
          'event': 'pusher:subscribe',
          'data': {'channel': channel},
        });
      }

      _activeServerSubscriptions.add(channel);
    } catch (e) {
      debugPrint('[WS] Subscribe error ($channel): $e');
    }
  }

  void _sendJson(Map<String, dynamic> payload) {
    try {
      if (_socket != null && _socket!.readyState == WebSocket.open) {
        _socket!.add(jsonEncode(payload));
      }
    } catch (_) {}
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _sendJson({'event': 'pusher:ping', 'data': <String, dynamic>{}});
    });
  }

  void _handleSocketClosed() {
    _pingTimer?.cancel();
    _socketSub?.cancel();
    _socket = null;
    _activeServerSubscriptions.clear();
    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer(const Duration(seconds: 15), () {
      if (!_manualDisconnect) {
        _ensureConnected();
      }
    });
  }

  Future<void> subscribeToChannels(List<String> channels) async {
    for (final ch in channels) {
      _subscribedChannels.add(ch);
      await _sendSubscribe(ch);
    }
    if (_socket == null && !(_reconnectTimer?.isActive ?? false)) {
      unawaited(_ensureConnected());
    }
  }

  Future<void> unsubscribeAll() async {
    for (final ch in _subscribedChannels.toList()) {
      _sendJson({
        'event': 'pusher:unsubscribe',
        'data': {'channel': ch},
      });
    }
    _subscribedChannels.clear();
    _activeServerSubscriptions.clear();
  }

  Future<void> subscribeToMerchantChannel(String merchantId) async {
    final ch = 'private-merchant.$merchantId';
    await subscribeToChannels([ch]);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await unsubscribeAll();
    await _socketSub?.cancel();
    await _socket?.close();
    _socket = null;
    _socketId = null;
  }
}
