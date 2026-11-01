import 'call_model.dart';

class DemandHotspotCluster {
  const DemandHotspotCluster({
    required this.latitude,
    required this.longitude,
    required this.weight,
    required this.totalRequests,
    required this.distanceM,
    required this.recommendation,
  });

  final double latitude;
  final double longitude;
  final double weight;
  final int totalRequests;
  final double distanceM;
  final String recommendation;

  factory DemandHotspotCluster.fromJson(Map<String, dynamic> json) {
    final weight = (json['weight'] as num?)?.toDouble() ?? 0.5;
    final totalReq =
        (json['total_requests'] as num?)?.toInt() ??
        ((weight * 12).round().clamp(1, 50));
    final dist = (json['distance_m'] as num?)?.toDouble() ?? 0.0;
    final rec =
        json['recommendation'] as String? ??
        (weight >= 0.7
            ? 'Area Sangat Ramai — Banyak pembeli aktif membuka radar di titik ini'
            : weight >= 0.4
            ? 'Area Cukup Ramai — Potensi pembeli sedang di sekitar sini'
            : 'Area Mulai Terpantau — Ada aktivitas pencarian pembeli');

    return DemandHotspotCluster(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      weight: weight.clamp(0.1, 1.0),
      totalRequests: totalReq,
      distanceM: dist,
      recommendation: rec,
    );
  }
}

class MerchantRadarSnapshot {
  const MerchantRadarSnapshot({
    required this.hotspots,
    required this.pendingCalls,
    required this.acceptedCalls,
    required this.demandHistoryCalls,
  });

  final List<DemandHotspotCluster> hotspots;
  final List<CallModel> pendingCalls;
  final List<CallModel> acceptedCalls;
  final List<CallModel> demandHistoryCalls;

  int get totalBuyerActivity =>
      hotspots.fold<int>(0, (sum, h) => sum + h.totalRequests) +
      pendingCalls.length;
}

