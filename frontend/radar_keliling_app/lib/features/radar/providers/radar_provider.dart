import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/models/merchant_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/merchant_service.dart';
import '../../../core/services/radar_service.dart';
import '../../../core/services/websocket_service.dart';

final radarProvider =
    StateNotifierProvider<RadarNotifier, AsyncValue<List<MerchantRadarItem>>>(
      (ref) => RadarNotifier(
        ref.read(radarServiceProvider),
        ref.read(locationServiceProvider),
        ref.read(wsServiceProvider),
        ref.read(merchantServiceProvider),
      ),
    );

class RadarNotifier extends StateNotifier<AsyncValue<List<MerchantRadarItem>>> {
  RadarNotifier(
    this._radarService,
    this._locationService,
    this._wsService,
    this._merchantService,
  ) : super(const AsyncValue.data([]));

  final RadarService _radarService;
  final LocationService _locationService;
  final WebSocketService _wsService;
  final MerchantService _merchantService;

  double? _lastLat;
  double? _lastLng;
  bool _enriching = false;

  Future<bool> loadRadar({bool keepExisting = false}) async {
    final existing = state.valueOrNull ?? const <MerchantRadarItem>[];
    if (!keepExisting) state = const AsyncValue.loading();

    try {
      final loc =
          _locationService.lastKnownLocation ??
          await _locationService.getCurrentLocation();
      final latitude = loc?.latitude ?? _lastLat;
      final longitude = loc?.longitude ?? _lastLng;

      if (latitude == null || longitude == null) {
        if (keepExisting && existing.isNotEmpty) {
          state = AsyncValue.data(existing);
        } else {
          state = const AsyncValue.data([]);
        }
        return false;
      }

      _lastLat = latitude;
      _lastLng = longitude;

      final result = await _radarService.fetchRadar(
        latitude: latitude,
        longitude: longitude,
      );

      await _wsService.subscribeToChannels(result.wsChannels);
      state = AsyncValue.data(result.merchants);
      unawaited(_enrichProfiles(result.merchants));
      return true;
    } catch (e, st) {
      if (keepExisting && existing.isNotEmpty) {
        state = AsyncValue.data(existing);
      } else if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }

  /// Update koordinat buyer dari stream GPS secara ringan & hitung ulang jarak.
  void updateBuyerCoordinates(double latitude, double longitude) {
    _lastLat = latitude;
    _lastLng = longitude;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    final updated = current
        .map(
          (m) => m.copyWith(
            distanceM: Geolocator.distanceBetween(
              latitude,
              longitude,
              m.latitude,
              m.longitude,
            ),
          ),
        )
        .toList(growable: false);
    state = AsyncValue.data(updated);
  }

  /// Dipanggil setelah WS reconnect — sync ulang dari REST.
  Future<void> resync() async {
    await loadRadar(keepExisting: true);
  }

  Future<void> _enrichProfiles(List<MerchantRadarItem> merchants) async {
    if (_enriching) return;
    _enriching = true;
    try {
      await Future.wait(
        merchants.map((merchant) async {
          if (merchant.profilePhotoUrl != null) return;
          try {
            final profile = await _merchantService.getPublicProfile(
              merchant.merchantId,
            );
            final photoUrl = profile.profilePhotoUrl;
            if (photoUrl == null || photoUrl.isEmpty) return;

            final current = state.valueOrNull;
            if (current == null) return;
            final index = current.indexWhere(
              (m) => m.merchantId == merchant.merchantId,
            );
            if (index == -1) return;

            final updated = List<MerchantRadarItem>.from(current);
            updated[index] = updated[index].copyWith(profilePhotoUrl: photoUrl);
            state = AsyncValue.data(updated);
          } catch (_) {
            // Foto profil bersifat opsional; radar tetap tampil tanpa foto.
          }
        }),
      );
    } finally {
      _enriching = false;
    }
  }

  double _computeDistance(double mLat, double mLng) {
    if (_lastLat == null || _lastLng == null) return 0;
    return Geolocator.distanceBetween(_lastLat!, _lastLng!, mLat, mLng);
  }

  /// Update marker dari WebSocket event MerchantLocationUpdated.
  void updateMerchantLocation(Map<String, dynamic> data) {
    final id = (data['merchant_id'] ?? data['merchantId']) as String?;
    if (id == null) return;

    final isSelling =
        (data['is_selling'] ?? data['isSelling']) as bool? ?? true;
    final merchants = List<MerchantRadarItem>.from(state.valueOrNull ?? []);

    // Jika pedagang berhenti jualan di event update lokasi, segera hapus marker
    if (!isSelling) {
      merchants.removeWhere((m) => m.merchantId == id);
      state = AsyncValue.data(merchants);
      return;
    }

    final mLat = (data['latitude'] as num).toDouble();
    final mLng = (data['longitude'] as num).toDouble();
    final dist = _computeDistance(mLat, mLng);

    final idx = merchants.indexWhere((m) => m.merchantId == id);
    if (idx == -1) {
      final added = MerchantRadarItem(
        merchantId: id,
        businessName: data['business_name'] as String? ?? 'Pedagang Keliling',
        latitude: mLat,
        longitude: mLng,
        distanceM: dist,
        gpsAccuracyM: (data['gps_accuracy_m'] as num?)?.toDouble() ?? 0,
        lastUpdatedAt:
            data['last_updated_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
        isSelling: true,
      );
      merchants.add(added);
      state = AsyncValue.data(merchants);
      unawaited(_enrichProfiles([added]));
    } else {
      merchants[idx] = merchants[idx].copyWith(
        latitude: mLat,
        longitude: mLng,
        distanceM: dist > 0 ? dist : merchants[idx].distanceM,
        gpsAccuracyM: (data['gps_accuracy_m'] as num?)?.toDouble(),
        lastUpdatedAt:
            data['last_updated_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
        isSelling: true,
      );
      state = AsyncValue.data(merchants);
    }
  }

  /// Update / hapus marker dari event MerchantSellingStatusChanged.
  void updateMerchantSellingStatus(Map<String, dynamic> data) {
    final id = (data['merchant_id'] ?? data['merchantId']) as String?;
    final isSelling =
        (data['is_selling'] ?? data['isSelling']) as bool? ?? false;
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
