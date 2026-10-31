import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/merchant_service.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';

final sellingProvider =
    StateNotifierProvider<SellingNotifier, AsyncValue<bool>>((ref) {
      final notifier = SellingNotifier(
        ref.read(merchantServiceProvider),
        ref.read(locationServiceProvider),
      );
      ref.listen(authProvider, (_, next) {
        final user = next.valueOrNull;
        if (user == null || !user.isMerchant) notifier.reset();
      });
      return notifier;
    });

class SellingNotifier extends StateNotifier<AsyncValue<bool>> {
  SellingNotifier(this._merchantService, this._locationService)
    : super(const AsyncValue.data(false));

  final MerchantService _merchantService;
  final LocationService _locationService;
  StreamSubscription? _sub;

  bool get isSelling => state.valueOrNull ?? false;

  Future<void> startSelling() async {
    state = const AsyncValue.loading();
    try {
      await _merchantService.startSelling();
      state = const AsyncValue.data(true);
      _startGps();
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> stopSelling() async {
    _stopGps();
    state = const AsyncValue.loading();
    try {
      await _merchantService.stopSelling();
      state = const AsyncValue.data(false);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  void _startGps() {
    _sub?.cancel();
    _sub = _locationService.locationStream.listen((loc) async {
      try {
        await _merchantService.updateLocation(
          latitude: loc.latitude,
          longitude: loc.longitude,
          accuracyM: loc.accuracyM,
          recordedAt: loc.recordedAt,
        );
      } catch (_) {
        // Kegagalan kirim GPS tidak menghentikan sesi berjualan
      }
    });
    _locationService.startGpsUpdates();
  }

  void _stopGps() {
    _locationService.stopGpsUpdates();
    _sub?.cancel();
    _sub = null;
  }

  void setInitialState(bool isSelling) {
    state = AsyncValue.data(isSelling);
    if (isSelling) {
      _startGps();
    } else {
      _stopGps();
    }
  }

  /// Kirim posisi terbaru dan mulai ulang timer setelah app kembali aktif.
  void refreshHeartbeat() {
    if (!isSelling) return;
    _startGps();
  }

  /// Hentikan heartbeat tanpa memanggil backend (mis. logout/switch akun).
  void reset() {
    _stopGps();
    state = const AsyncValue.data(false);
  }

  @override
  void dispose() {
    _stopGps();
    super.dispose();
  }
}
