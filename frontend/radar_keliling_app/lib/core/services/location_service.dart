import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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

  LocationResult withFreshTimestamp() => LocationResult(
    latitude: latitude,
    longitude: longitude,
    accuracyM: accuracyM,
    recordedAt: DateTime.now().toUtc().toIso8601String(),
  );
}

class LocationService {
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  LocationResult? _lastKnownLocation;
  DateTime? _lastEmitTime;

  final StreamController<LocationResult> _locationStream =
      StreamController.broadcast();

  Stream<LocationResult> get locationStream => _locationStream.stream;
  LocationResult? get lastKnownLocation => _lastKnownLocation;

  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
          timeLimit: Duration(seconds: 6),
        ),
      );
      final res = _posToResult(pos);
      _lastKnownLocation = res;
      return res;
    } catch (_) {
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          final res = _posToResult(lastPos);
          _lastKnownLocation = res;
          return res;
        }
      } catch (_) {}
      return _lastKnownLocation?.withFreshTimestamp();
    }
  }

  /// Stream posisi buyer yang ringan untuk update marker & radar secara mulus.
  Stream<LocationResult> watchPosition({int distanceFilter = 5}) {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 5),
      );
    } else {
      settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings).map((pos) {
      final res = _posToResult(pos);
      _lastKnownLocation = res;
      return res;
    });
  }

  /// Cek akurasi GPS memenuhi syarat panggilan (≤ 50m).
  Future<LocationResult?> getLocationForCall() async {
    LocationResult? loc = await getCurrentLocation();
    if (loc != null && loc.accuracyM <= AppConfig.callGpsAccuracyMaxMeters) {
      return loc;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      loc = _posToResult(pos);
      _lastKnownLocation = loc;
      return loc.accuracyM <= AppConfig.callGpsAccuracyMaxMeters ? loc : null;
    } catch (_) {
      return loc;
    }
  }

  /// Mulai GPS stream berkelanjutan untuk merchant + heartbeat saat berhenti.
  Future<bool> startGpsUpdates() async {
    stopGpsUpdates();

    final hasPermission = await requestPermission();
    if (!hasPermission) return false;

    final initialLoc = await getCurrentLocation();
    if (initialLoc != null) {
      _emitLocation(initialLoc);
    }

    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: Duration(seconds: AppConfig.gpsUpdateIntervalSeconds),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (pos) {
        _emitLocation(_posToResult(pos));
      },
      onError: (_) {
        // Abaikan error transien agar stream tetap berjalan
      },
    );

    // Heartbeat ringan: jika gerobak berhenti (0m) selama > interval,
    // tetap kirim koordinat terakhir agar status di radar tidak dianggap stale.
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: AppConfig.gpsUpdateIntervalSeconds),
      (_) async {
        final now = DateTime.now();
        if (_lastEmitTime != null &&
            now.difference(_lastEmitTime!).inSeconds <
                AppConfig.gpsUpdateIntervalSeconds - 1) {
          return;
        }
        final loc =
            _lastKnownLocation?.withFreshTimestamp() ??
            await getCurrentLocation();
        if (loc != null) {
          _emitLocation(loc);
        }
      },
    );

    return true;
  }

  void _emitLocation(LocationResult loc) {
    _lastKnownLocation = loc;
    _lastEmitTime = DateTime.now();
    if (!_locationStream.isClosed) {
      _locationStream.add(loc);
    }
  }

  void stopGpsUpdates() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  LocationResult _posToResult(Position pos) => LocationResult(
    latitude: pos.latitude,
    longitude: pos.longitude,
    accuracyM: pos.accuracy,
    recordedAt: DateTime.now().toUtc().toIso8601String(),
  );

  void dispose() {
    stopGpsUpdates();
    _locationStream.close();
  }
}
