import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../config/app_config.dart';
import '../utils/secure_storage.dart';

final wsServiceProvider = Provider<WebSocketService>((_) => WebSocketService());

typedef WsEventCallback = void Function(String eventName, Map<String, dynamic> data);

class WebSocketService {
  PusherChannelsFlutter? _pusher;
  final Set<String> _subscribedChannels = {};
  WsEventCallback? _onEvent;
  VoidCallback? _onReconnect;

  Future<void> connect({
    required WsEventCallback onEvent,
    VoidCallback? onReconnect,
  }) async {
    _onEvent = onEvent;
    _onReconnect = onReconnect;

    _pusher = PusherChannelsFlutter.getInstance();
    await _pusher!.init(
      apiKey: AppConfig.reverbAppKey,
      cluster: 'mt1', // tidak dipakai Reverb, tapi required
      wsHost: AppConfig.wsHost,
      wsPort: AppConfig.wsPort,
      useTLS: AppConfig.wsTls,
      authEndpoint: '${AppConfig.baseUrl}/broadcasting/auth',
      onAuthorizer: _handleAuth,
      onConnectionStateChange: (current, previous) {
        if (current == 'CONNECTED' && previous == 'DISCONNECTED') {
          _onReconnect?.call();
        }
      },
    );
    await _pusher!.connect();
  }

  Future<dynamic> _handleAuth(String channelName, String socketId) async {
    // Reverb butuh Bearer token di request auth
    final token = await SecureStorage.getToken();
    return {
      'headers': {'Authorization': 'Bearer $token'},
    };
  }

  Future<void> subscribeToChannels(List<String> channels) async {
    for (final ch in channels) {
      if (_subscribedChannels.contains(ch)) continue;
      await _pusher?.subscribe(
        channelName: ch,
        onEvent: (event) {
          try {
            final data = jsonDecode(event.data as String? ?? '{}')
                as Map<String, dynamic>;
            _onEvent?.call(event.eventName, data);
          } catch (_) {}
        },
      );
      _subscribedChannels.add(ch);
    }
  }

  Future<void> unsubscribeAll() async {
    for (final ch in _subscribedChannels) {
      await _pusher?.unsubscribe(channelName: ch);
    }
    _subscribedChannels.clear();
  }

  Future<void> subscribeToMerchantChannel(String merchantId) async {
    final ch = 'private-merchant.$merchantId';
    await subscribeToChannels([ch]);
  }

  Future<void> disconnect() async {
    await unsubscribeAll();
    await _pusher?.disconnect();
  }
}
