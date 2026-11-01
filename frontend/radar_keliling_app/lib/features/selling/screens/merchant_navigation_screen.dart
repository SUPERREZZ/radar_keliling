import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/call_model.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/road_routing_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../providers/merchant_radar_provider.dart';

class MerchantNavigationScreen extends ConsumerStatefulWidget {
  const MerchantNavigationScreen({super.key, required this.call});

  final CallModel call;

  @override
  ConsumerState<MerchantNavigationScreen> createState() =>
      _MerchantNavigationScreenState();
}

class _MerchantNavigationScreenState
    extends ConsumerState<MerchantNavigationScreen> {
  final MapController _mapController = MapController();

  LatLng _merchantLocation = const LatLng(-7.448830, 112.457453);
  late LatLng _buyerLocation;
  LatLng? _lastRoutedOrigin;

  List<LatLng> _routePoints = [];
  List<RouteStep> _steps = [];
  double _roadDistanceMeters = 0;
  double _etaSeconds = 0;
  bool _isLoadingRoute = true;
  bool _isCompleting = false;
  bool _followMerchant = true;

  StreamSubscription<LocationResult>? _positionStreamSub;
  static const Distance _distCalc = Distance();

  bool get _isHotspotTarget => widget.call.id.startsWith('hotspot_');

  @override
  void initState() {
    super.initState();
    _buyerLocation = LatLng(
      widget.call.buyerLatitude ?? -7.447500,
      widget.call.buyerLongitude ?? 112.458500,
    );
    _initNavigation();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _initNavigation() async {
    final locService = ref.read(locationServiceProvider);

    // Jika koordinat pembeli belum terisi pada argumen awal, ambil detail call terbaru
    if (!widget.call.hasBuyerCoordinates && !_isHotspotTarget) {
      try {
        final fresh = await ref
            .read(callServiceProvider)
            .getCallById(widget.call.id);
        if (fresh.hasBuyerCoordinates && mounted) {
          setState(() {
            _buyerLocation = LatLng(
              fresh.buyerLatitude!,
              fresh.buyerLongitude!,
            );
          });
        }
      } catch (_) {}
    }

    // 1. Ambil posisi GPS terkini pedagang
    final currentPos =
        locService.lastKnownLocation ?? await locService.getCurrentLocation();
    if (currentPos != null && mounted) {
      setState(() {
        _merchantLocation = LatLng(currentPos.latitude, currentPos.longitude);
      });
    }

    // 2. Hitung jalur jalan raya (OSRM)
    await _fetchRoadRoute(_merchantLocation, _buyerLocation);
    _fitBounds();

    // 3. Pantau pergerakan GPS pedagang secara real-time & ringan
    _positionStreamSub = locService.watchPosition(distanceFilter: 4).listen((
      pos,
    ) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _merchantLocation = newPos;
      });

      if (_followMerchant) {
        _mapController.move(newPos, _mapController.camera.zoom);
      }

      // Hanya hitung ulang rute ke OSRM jika pedagang berpindah > 35 meter agar ringan
      if (_lastRoutedOrigin == null ||
          _distCalc.as(LengthUnit.Meter, _lastRoutedOrigin!, newPos) > 35) {
        _fetchRoadRoute(newPos, _buyerLocation);
      }
    });
  }

  Future<void> _fetchRoadRoute(LatLng origin, LatLng destination) async {
    final routingService = ref.read(roadRoutingServiceProvider);
    final result = await routingService.getRoute(origin, destination);
    if (!mounted) return;
    setState(() {
      _lastRoutedOrigin = origin;
      _routePoints = result.polylinePoints;
      _roadDistanceMeters = result.totalDistanceMeters;
      _etaSeconds = result.totalDurationSeconds;
      _steps = result.steps;
      _isLoadingRoute = false;
    });
  }

  void _fitBounds() {
    if (!mounted) return;
    final points = _routePoints.isNotEmpty
        ? _routePoints
        : [_merchantLocation, _buyerLocation];
    if (points.length >= 2) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 150,
            bottom: 240,
            left: 55,
            right: 55,
          ),
          maxZoom: 17.5,
        ),
      );
    }
  }

  Future<void> _completeCall() async {
    if (_isHotspotTarget) {
      context.pop();
      return;
    }

    setState(() => _isCompleting = true);
    try {
      await ref.read(callServiceProvider).completeCall(widget.call.id);
    } catch (_) {
      // Tetap lanjutkan jika panggilan sudah berstatus selesai
    }
    ref.invalidate(merchantRadarSnapshotProvider);
    if (!mounted) return;
    showRkSnackbar(
      context,
      'Pesanan selesai! Terima kasih telah melayani pembeli.',
    );
    context.pop();
  }

  IconData _getManeuverIcon(String type, String? modifier) {
    if (type == 'arrive') return Icons.flag_rounded;
    if (type == 'roundabout' || type == 'rotary') {
      return Icons.roundabout_right_rounded;
    }
    switch (modifier) {
      case 'left':
      case 'sharp left':
        return Icons.turn_left_rounded;
      case 'slight left':
        return Icons.turn_slight_left_rounded;
      case 'right':
      case 'sharp right':
        return Icons.turn_right_rounded;
      case 'slight right':
        return Icons.turn_slight_right_rounded;
      case 'uturn':
        return Icons.u_turn_left_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextStep = _steps.length > 1
        ? _steps[1]
        : (_steps.isNotEmpty ? _steps.first : null);
    final etaMinutes = (_etaSeconds / 60).ceil().clamp(1, 999);
    final distanceLabel = _roadDistanceMeters >= 1000
        ? '${(_roadDistanceMeters / 1000).toStringAsFixed(1)} km'
        : '${_roadDistanceMeters.toStringAsFixed(0)} m';

    final shortId = widget.call.id.length >= 6
        ? widget.call.id.substring(0, 6).toUpperCase()
        : widget.call.id.toUpperCase();
    final targetLabel = _isHotspotTarget
        ? 'Area Ramai Pembeli'
        : 'Pembeli #$shortId';

    return Scaffold(
      body: Stack(
        children: [
          // 1. Peta Navigasi Real-Time dengan Garis Jalur Jalan Raya
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _merchantLocation,
              initialZoom: 16.5,
              minZoom: 11.0,
              maxZoom: 18.5,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _followMerchant) {
                  setState(() => _followMerchant = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.radarkeliling.radar_keliling',
                maxZoom: 18,
              ),

              // Garis Jalur Jalan Raya (Double-Layer Green Polyline ala Grab/Gojek)
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 10.0,
                      color: const Color(0xFF005C3B),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6.0,
                      color: const Color(0xFF00B14F),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

              // Marker Gerobak & Titik Tujuan
              MarkerLayer(
                markers: [
                  // Marker Lokasi Pembeli / Tujuan
                  Marker(
                    point: _buyerLocation,
                    width: 110,
                    height: 85,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              targetLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: AppColors.error,
                            size: 42,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Marker Gerobak Pedagang
                  Marker(
                    point: _merchantLocation,
                    width: 90,
                    height: 80,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF005C3B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Gerobak Anda',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B14F),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Turn-by-Turn Navigation Header HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF006837),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        nextStep != null
                            ? _getManeuverIcon(
                                nextStep.maneuverType,
                                nextStep.maneuverModifier,
                              )
                            : Icons.directions_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (nextStep != null && nextStep.distanceMeters > 0)
                            Text(
                              '${nextStep.distanceMeters.toStringAsFixed(0)} m lagi',
                              style: const TextStyle(
                                color: Color(0xFFA7F3D0),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            _isLoadingRoute
                                ? 'Menghitung jalur jalan terdekat...'
                                : (nextStep?.instruction ??
                                      'Ikuti jalur hijau menuju pembeli'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                      tooltip: 'Tutup Navigasi',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Tombol Kontrol Peta Mengambang (Kanan)
          Positioned(
            right: 16,
            bottom: 225,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'nav_recenter_btn',
                  backgroundColor: _followMerchant
                      ? const Color(0xFF00B14F)
                      : Colors.white,
                  foregroundColor: _followMerchant
                      ? Colors.white
                      : AppColors.textPrimary,
                  onPressed: () {
                    setState(() => _followMerchant = true);
                    _mapController.move(_merchantLocation, 17.0);
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'nav_bounds_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  onPressed: () {
                    setState(() => _followMerchant = false);
                    _fitBounds();
                  },
                  child: const Icon(Icons.route_rounded),
                ),
              ],
            ),
          ),

          // 4. Bottom Sheet Ringkasan Rute & Tombol Selesai
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B14F).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$etaMinutes',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00883D),
                                ),
                              ),
                              const Text(
                                'menit',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF00883D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    distanceLabel,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Rute Jalan Tercepat',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tujuan: $targetLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCompleting ? null : _completeCall,
                        icon: _isCompleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 22),
                        label: Text(
                          _isHotspotTarget
                              ? 'Sudah Tiba di Area Ramai'
                              : 'Saya Sudah Tiba (Selesai Layani)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B14F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

