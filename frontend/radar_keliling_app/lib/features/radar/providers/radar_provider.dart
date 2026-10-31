import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/merchant_model.dart';
import '../../../core/services/radar_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/websocket_service.dart';

final radarProvider =
    StateNotifierProvider<RadarNotifier, AsyncValue<List<MerchantRadarItem>>>(
  (ref) => RadarNotifier(
    ref.read(radarServiceProvider),
    ref.read(locationServiceProvider),
    ref.read(wsServiceProvider),
  ),
);

class RadarNotifier
    extends StateNotifier<AsyncValue<List<MerchantRadarItem>>> {
  RadarNotifier(this._radarService, this._locationService, this._wsService)
      : super(const AsyncValue.data([]));

  final RadarService _radarService;
  final LocationService _locationService;
  final WebSocketService _wsService;

  double? _lastLat;
  double? _lastLng;

  Future<void> loadRadar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final loc = await _locationService.getCurrentLocation();
      if (loc == null) return [];

      _lastLat = loc.latitude;
      _lastLng = loc.longitude;

      final result = await _radarService.fetchRadar(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );

      // Subscribe ke WS channels
      await _wsService.subscribeToChannels(result.wsChannels);

      return result.merchants;
    });
  }

  /// Dipanggil setelah WS reconnect — sync ulang dari REST.
  Future<void> resync() async {
    if (_lastLat == null || _lastLng == null) {
      await loadRadar();
      return;
    }
    try {
      final result = await _radarService.fetchRadar(
        latitude: _lastLat!,
        longitude: _lastLng!,
      );
      await _wsService.subscribeToChannels(result.wsChannels);
      state = AsyncValue.data(result.merchants);
    } catch (_) {}
  }

  /// Update marker dari WebSocket event MerchantLocationUpdated.
  void updateMerchantLocation(Map<String, dynamic> data) {
    final merchants = List<MerchantRadarItem>.from(state.valueOrNull ?? []);
    final id = data['merchant_id'] as String?;
    if (id == null) return;
    final idx = merchants.indexWhere((m) => m.merchantId == id);
    if (idx == -1) {
      // Pedagang baru masuk area radar
      merchants.add(MerchantRadarItem(
        merchantId: id,
        businessName: data['business_name'] as String? ?? '',
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        distanceM: 0,
        gpsAccuracyM: (data['gps_accuracy_m'] as num?)?.toDouble() ?? 0,
        lastUpdatedAt: data['last_updated_at'] as String? ?? '',
        isSelling: data['is_selling'] as bool? ?? true,
      ));
    } else {
      merchants[idx] = merchants[idx].copyWith(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        gpsAccuracyM: (data['gps_accuracy_m'] as num?)?.toDouble(),
        lastUpdatedAt: data['last_updated_at'] as String?,
        isSelling: data['is_selling'] as bool?,
      );
    }
    state = AsyncValue.data(merchants);
  }

  /// Update / hapus marker dari event MerchantSellingStatusChanged.
  void updateMerchantSellingStatus(Map<String, dynamic> data) {
    final id = data['merchant_id'] as String?;
    final isSelling = data['is_selling'] as bool? ?? false;
    if (id == null) return;

    final merchants = List<MerchantRadarItem>.from(state.valueOrNull ?? []);
    if (!isSelling) {
      merchants.removeWhere((m) => m.merchantId == id);
    } else {
      final idx = merchants.indexWhere((m) => m.merchantId == id);
      if (idx != -1) merchants[idx] = merchants[idx].copyWith(isSelling: true);
    }
    state = AsyncValue.data(merchants);
  }
}
