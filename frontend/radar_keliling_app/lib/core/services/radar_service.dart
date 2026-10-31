import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/merchant_model.dart';

final radarServiceProvider = Provider<RadarService>(
  (ref) => RadarService(ref.read(apiClientProvider)),
);

class RadarResult {
  const RadarResult({required this.merchants, required this.wsChannels});
  final List<MerchantRadarItem> merchants;
  final List<String> wsChannels;
}

class RadarService {
  RadarService(this._api);
  final DioClient _api;

  Future<RadarResult> fetchRadar({
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.get(
      Endpoints.radarMerchants,
      queryParameters: {'latitude': latitude, 'longitude': longitude},
    );
    final body = res.data as Map<String, dynamic>;
    final items = (body['data'] as List)
        .map((e) => MerchantRadarItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = body['meta'] as Map<String, dynamic>? ?? {};
    final channels = (meta['websocket_channels'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return RadarResult(merchants: items, wsChannels: channels);
  }
}
