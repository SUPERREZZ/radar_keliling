import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/buyer_hotspot_model.dart';
import '../../../core/models/call_model.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/location_service.dart';

final merchantRadarRadiusProvider = StateProvider<int>((_) => 2000);

/// Menyimpan ID panggilan masuk yang sudah ditampilkan popup-nya agar tidak duplikat.
final handledIncomingCallIdsProvider = StateProvider<Set<String>>(
  (_) => <String>{},
);

final merchantRadarSnapshotProvider =
    FutureProvider.autoDispose<MerchantRadarSnapshot>((ref) async {
      final api = ref.read(apiClientProvider);
      final callService = ref.read(callServiceProvider);
      final locService = ref.read(locationServiceProvider);
      final radius = ref.watch(merchantRadarRadiusProvider);

      final loc =
          locService.lastKnownLocation ?? await locService.getCurrentLocation();
      final lat = loc?.latitude ?? -7.448830;
      final lng = loc?.longitude ?? 112.457453;

      final hotspots = <DemandHotspotCluster>[];

      try {
        final res = await api.get(
          Endpoints.merchantBuyerHotspots,
          queryParameters: {
            'latitude': lat,
            'longitude': lng,
            'radius': radius,
          },
        );
        final list = (res.data as Map)['data'] as List? ?? [];
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final cluster = DemandHotspotCluster.fromJson(map);
          final dist = cluster.distanceM > 0
              ? cluster.distanceM
              : Geolocator.distanceBetween(
                  lat,
                  lng,
                  cluster.latitude,
                  cluster.longitude,
                );
          hotspots.add(
            DemandHotspotCluster(
              latitude: cluster.latitude,
              longitude: cluster.longitude,
              weight: cluster.weight,
              totalRequests: cluster.totalRequests,
              distanceM: dist,
              recommendation: cluster.recommendation,
            ),
          );
        }
      } catch (_) {}

      // Jika di sekitar radius belum ada cluster spesifik, muat juga dari heatmap umum
      if (hotspots.isEmpty) {
        try {
          final heatRes = await api.get(Endpoints.heatmap);
          final list = (heatRes.data as Map)['data'] as List? ?? [];
          for (final item in list) {
            final map = item as Map<String, dynamic>;
            final cluster = DemandHotspotCluster.fromJson(map);
            final dist = Geolocator.distanceBetween(
              lat,
              lng,
              cluster.latitude,
              cluster.longitude,
            );
            if (dist <= radius) {
              hotspots.add(
                DemandHotspotCluster(
                  latitude: cluster.latitude,
                  longitude: cluster.longitude,
                  weight: cluster.weight,
                  totalRequests: cluster.totalRequests,
                  distanceM: dist,
                  recommendation: cluster.recommendation,
                ),
              );
            }
          }
        } catch (_) {}
      }

      List<CallModel> allCalls = [];
      try {
        allCalls = await callService.getCalls();
      } catch (_) {}

      CallModel enrichDistance(CallModel c) {
        if (!c.hasBuyerCoordinates) return c;
        if (c.distanceM != null && c.distanceM! > 0) return c;
        final dist = Geolocator.distanceBetween(
          lat,
          lng,
          c.buyerLatitude!,
          c.buyerLongitude!,
        );
        return c.copyWith(distanceM: dist);
      }

      final enrichedCalls = allCalls.map(enrichDistance).toList();

      final pendingCalls = enrichedCalls
          .where((c) => c.status == 'pending')
          .toList();
      final acceptedCalls = enrichedCalls
          .where((c) => c.status == 'accept')
          .toList();
      final demandHistoryCalls = enrichedCalls
          .where(
            (c) =>
                c.hasBuyerCoordinates &&
                c.status != 'pending' &&
                c.status != 'accept',
          )
          .take(20)
          .toList();

      return MerchantRadarSnapshot(
        hotspots: hotspots,
        pendingCalls: pendingCalls,
        acceptedCalls: acceptedCalls,
        demandHistoryCalls: demandHistoryCalls,
      );
    });

