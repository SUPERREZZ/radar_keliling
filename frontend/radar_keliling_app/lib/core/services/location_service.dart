import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';

final locationServiceProvider = Provider<LocationService>(
  (_) => LocationService(),
);

class LocationResult {
  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.recordedAt,
  });
  final double latitude;
  final double longitude;
  final double accuracyM;
  final String recordedAt;
}

class LocationService {
  Timer? _gpsTimer;
  final StreamController<LocationResult> _locationStream =
      StreamController.broadcast();

  Stream<LocationResult> get locationStream => _locationStream.stream;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<LocationResult?> getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _posToResult(pos);
    } catch (_) {
      return null;
    }
  }

  /// Cek akurasi GPS memenuhi syarat panggilan (≤ 50m).
  Future<LocationResult?> getLocationForCall() async {
    LocationResult? loc = await getCurrentLocation();
    if (loc != null && loc.accuracyM <= AppConfig.callGpsAccuracyMaxMeters) {
      return loc;
    }
    // Retry sekali dengan timeout lebih longgar
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      loc = _posToResult(pos);
      return loc.accuracyM <= AppConfig.callGpsAccuracyMaxMeters ? loc : null;
    } catch (_) {
      return null;
    }
  }

  /// Mulai timer GPS untuk merchant — kirim segera lalu setiap 10 detik.
  void startGpsUpdates() {
    _gpsTimer?.cancel();
    _emitCurrentLocation();
    _gpsTimer = Timer.periodic(
      Duration(seconds: AppConfig.gpsUpdateIntervalSeconds),
      (_) => _emitCurrentLocation(),
    );
  }

  Future<void> _emitCurrentLocation() async {
    final loc = await getCurrentLocation();
    if (loc != null && !_locationStream.isClosed) {
      _locationStream.add(loc);
    }
  }

  void stopGpsUpdates() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  LocationResult _posToResult(Position pos) => LocationResult(
    latitude: pos.latitude,
    longitude: pos.longitude,
    accuracyM: pos.accuracy,
    recordedAt: DateTime.now().toUtc().toIso8601String(),
  );

  void dispose() {
    _gpsTimer?.cancel();
    _locationStream.close();
  }
}
