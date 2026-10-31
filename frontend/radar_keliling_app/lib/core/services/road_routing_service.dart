import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final roadRoutingServiceProvider = Provider<RoadRoutingService>(
  (_) => RoadRoutingService(),
);

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.maneuverType,
    this.maneuverModifier,
  });

  final String instruction;
  final double distanceMeters;
  final String maneuverType;
  final String? maneuverModifier;
}

class RoadRouteResult {
  const RoadRouteResult({
    required this.polylinePoints,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.steps,
  });

  final List<LatLng> polylinePoints;
  final double totalDistanceMeters;
  final double totalDurationSeconds;
  final List<RouteStep> steps;
}

class RoadRoutingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 7),
    ),
  );

  /// Fetch real road-following route geometry & turn-by-turn steps via OSRM.
  Future<RoadRouteResult> getRoute(LatLng origin, LatLng destination) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=true';

      final response = await _dio.get(url);
      final data = response.data as Map<String, dynamic>;

      if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
        final route = (data['routes'] as List).first as Map<String, dynamic>;
        final geometry = route['geometry'] as Map<String, dynamic>;
        final coords = geometry['coordinates'] as List;

        final points = coords.map((c) {
          final pair = c as List;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        }).toList();

        final distance = (route['distance'] as num).toDouble();
        final duration = (route['duration'] as num).toDouble();

        final stepsList = <RouteStep>[];
        final legs = route['legs'] as List? ?? [];
        if (legs.isNotEmpty) {
          final rawSteps = (legs.first as Map<String, dynamic>)['steps'] as List? ?? [];
          for (final s in rawSteps) {
            final stepMap = s as Map<String, dynamic>;
            final maneuver = stepMap['maneuver'] as Map<String, dynamic>? ?? {};
            final type = maneuver['type']?.toString() ?? 'straight';
            final modifier = maneuver['modifier']?.toString();
            final roadName = stepMap['name']?.toString() ?? '';
            final stepDist = (stepMap['distance'] as num?)?.toDouble() ?? 0.0;

            stepsList.add(
              RouteStep(
                instruction: _translateInstruction(type, modifier, roadName),
                distanceMeters: stepDist,
                maneuverType: type,
                maneuverModifier: modifier,
              ),
            );
          }
        }

        return RoadRouteResult(
          polylinePoints: points,
          totalDistanceMeters: distance,
          totalDurationSeconds: duration,
          steps: stepsList,
        );
      }
    } catch (_) {
      // Fallback jika OSRM sedang sibuk / tidak terjangkau
    }

    const distCalc = Distance();
    final directDist = distCalc.as(LengthUnit.Meter, origin, destination);
    return RoadRouteResult(
      polylinePoints: [origin, destination],
      totalDistanceMeters: directDist,
      totalDurationSeconds: directDist / 4.0,
      steps: const [
        RouteStep(
          instruction: 'Ikuti arah menuju titik pembeli',
          distanceMeters: 0,
          maneuverType: 'depart',
        ),
      ],
    );
  }

  String _translateInstruction(String type, String? modifier, String roadName) {
    final targetRoad = roadName.isNotEmpty ? ' ke $roadName' : '';
    final onRoad = roadName.isNotEmpty ? ' di $roadName' : '';

    if (type == 'depart') {
      return 'Mulai jalan$onRoad';
    }
    if (type == 'arrive') {
      return 'Tiba di lokasi pembeli';
    }
    if (type == 'turn' || type == 'end of road' || type == 'fork') {
      switch (modifier) {
        case 'left':
          return 'Belok kiri$targetRoad';
        case 'right':
          return 'Belok kanan$targetRoad';
        case 'slight left':
          return 'Serong kiri$targetRoad';
        case 'slight right':
          return 'Serong kanan$targetRoad';
        case 'sharp left':
          return 'Belok tajam ke kiri$targetRoad';
        case 'sharp right':
          return 'Belok tajam ke kanan$targetRoad';
        case 'uturn':
          return 'Putar balik$onRoad';
        default:
          return 'Lurus terus$onRoad';
      }
    }
    if (type == 'roundabout' || type == 'rotary') {
      return 'Masuk bundaran lalu keluar$targetRoad';
    }
    return 'Lurus ikuti jalan$onRoad';
  }
}

