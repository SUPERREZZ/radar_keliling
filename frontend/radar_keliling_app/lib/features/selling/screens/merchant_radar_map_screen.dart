import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/buyer_hotspot_model.dart';
import '../../../core/models/call_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/road_routing_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../call/widgets/incoming_call_dialog.dart';
import '../../merchant_profile/providers/merchant_profile_provider.dart';
import '../providers/merchant_radar_provider.dart';
import '../providers/selling_provider.dart';

class MerchantRadarMapScreen extends ConsumerStatefulWidget {
  const MerchantRadarMapScreen({super.key});

  @override
  ConsumerState<MerchantRadarMapScreen> createState() =>
      _MerchantRadarMapScreenState();
}

class _MerchantRadarMapScreenState
    extends ConsumerState<MerchantRadarMapScreen> {
  final MapController _mapController = MapController();
  LatLng _merchantCoord = const LatLng(-7.448830, 112.457453);
  StreamSubscription<LocationResult>? _positionStreamSub;
  Timer? _autoRefreshTimer;

  dynamic _selectedSpot; // DemandHotspotCluster | CallModel
  List<LatLng> _previewRoutePoints = [];
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _initMerchantLocation();
    _initRealtimeListener();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        ref.invalidate(merchantRadarSnapshotProvider);
      }
    });
  }

  @override
  void dispose() {
    ref.read(wsServiceProvider).removeListener('merchant_radar_map');
    _autoRefreshTimer?.cancel();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _initMerchantLocation() async {
    final locService = ref.read(locationServiceProvider);
    final granted = await locService.requestPermission();
    if (!granted) return;

    final pos =
        locService.lastKnownLocation ?? await locService.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() {
        _merchantCoord = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(
        _merchantCoord,
        _calculateZoom(ref.read(merchantRadarRadiusProvider)),
      );
    }

    _positionStreamSub = locService.watchPosition(distanceFilter: 5).listen((
      position,
    ) {
      if (!mounted) return;
      setState(() {
        _merchantCoord = LatLng(position.latitude, position.longitude);
      });
    });
  }

  Future<void> _initRealtimeListener() async {
    try {
      final profile = await ref.read(merchantSelfProfileProvider.future);
      if (!mounted) return;
      final ws = ref.read(wsServiceProvider);
      await ws.subscribeToMerchantChannel(profile.id);
      ws.addListener(
        'merchant_radar_map',
        onEvent: (eventName, data) {
          if (!mounted) return;
          if (eventName == 'IncomingCall' || eventName == '.IncomingCall') {
            ref.invalidate(merchantRadarSnapshotProvider);
            final call = CallModel.fromJson(data);
            _maybeShowIncomingCallDialog(call);
          } else if (eventName == 'CallStatusUpdated' ||
              eventName == '.CallStatusUpdated') {
            ref.invalidate(merchantRadarSnapshotProvider);
          }
        },
        onReconnect: () {
          if (mounted) ref.invalidate(merchantRadarSnapshotProvider);
        },
      );
    } catch (_) {}
  }

  void _maybeShowIncomingCallDialog(CallModel call) {
    if (!mounted || _dialogShowing || call.id.isEmpty) return;
    final handled = ref.read(handledIncomingCallIdsProvider);
    if (handled.contains(call.id)) return;

    ref.read(handledIncomingCallIdsProvider.notifier).state = {
      ...handled,
      call.id,
    };
    _dialogShowing = true;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncomingCallDialog(call: call),
    ).whenComplete(() {
      _dialogShowing = false;
    });
  }

  Future<void> _selectSpot(dynamic spot, LatLng targetCoord) async {
    setState(() {
      _selectedSpot = spot;
      _previewRoutePoints = [];
    });
    try {
      final route = await ref
          .read(roadRoutingServiceProvider)
          .getRoute(_merchantCoord, targetCoord);
      if (mounted && _selectedSpot == spot) {
        setState(() {
          _previewRoutePoints = route.polylinePoints;
        });
      }
    } catch (_) {}
  }

  double _calculateZoom(int radiusMeters) {
    if (radiusMeters <= 500) return 16.2;
    if (radiusMeters <= 1000) return 15.2;
    return 14.3;
  }

  Future<void> _toggleSelling(bool isSelling) async {
    try {
      if (isSelling) {
        await ref.read(sellingProvider.notifier).stopSelling();
      } else {
        await ref.read(sellingProvider.notifier).startSelling();
      }
      if (!mounted) return;
      showRkSnackbar(
        context,
        isSelling
            ? 'Kamu berhenti berjualan.'
            : 'Sekarang kamu aktif dan terlihat di radar pembeli!',
      );
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(
        context,
        'Gagal mengubah status berjualan.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(merchantRadarSnapshotProvider);
    final selectedRadius = ref.watch(merchantRadarRadiusProvider);
    final sellingState = ref.watch(sellingProvider);
    final isSelling = sellingState.valueOrNull ?? false;

    // Jika ada panggilan pending baru dari hasil fetch, tampilkan dialog otomatis
    ref.listen<AsyncValue<MerchantRadarSnapshot>>(
      merchantRadarSnapshotProvider,
      (_, next) {
        final data = next.valueOrNull;
        if (data != null && data.pendingCalls.isNotEmpty) {
          _maybeShowIncomingCallDialog(data.pendingCalls.first);
        }
      },
    );

    return Scaffold(
      body: Stack(
        children: [
          // 1. Peta Interaktif Radar Pedagang
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _merchantCoord,
              initialZoom: _calculateZoom(selectedRadius),
              minZoom: 10.0,
              maxZoom: 18.5,
              onTap: (_, __) {
                if (_selectedSpot != null || _previewRoutePoints.isNotEmpty) {
                  setState(() {
                    _selectedSpot = null;
                    _previewRoutePoints = [];
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.radarkeliling.radar_keliling',
                maxZoom: 18,
              ),

              // Lingkaran Jangkauan Radar Pedagang
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _merchantCoord,
                    radius: selectedRadius.toDouble(),
                    useRadiusInMeter: true,
                    color: AppColors.primary.withOpacity(0.06),
                    borderColor: AppColors.primary.withOpacity(0.35),
                    borderStrokeWidth: 1.8,
                  ),
                ],
              ),

              // Lingkaran Area Ramai / Hotspot Pembeli
              if (snapshotAsync.valueOrNull != null)
                CircleLayer(
                  circles: [
                    ...snapshotAsync.valueOrNull!.hotspots.map((cluster) {
                      final weight = cluster.weight.clamp(0.1, 1.0);
                      final Color heatColor = weight >= 0.7
                          ? Colors.red.shade700
                          : weight >= 0.4
                          ? Colors.deepOrange
                          : Colors.amber.shade700;
                      return CircleMarker(
                        point: LatLng(cluster.latitude, cluster.longitude),
                        radius: 100 + (weight * 90),
                        useRadiusInMeter: true,
                        color: heatColor.withOpacity(0.15 + (weight * 0.16)),
                        borderColor: heatColor.withOpacity(0.75),
                        borderStrokeWidth: 1.8,
                      );
                    }),
                  ],
                ),

              // Garis Jalur Jalan (OSRM Road Polyline) ke titik yang dipilih
              if (_previewRoutePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _previewRoutePoints,
                      strokeWidth: 9.5,
                      color: const Color(0xFF005C3B),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: _previewRoutePoints,
                      strokeWidth: 5.5,
                      color: const Color(0xFF00B14F),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

              // Layer Marker (Gerobak, Hotspot Pembeli, Riwayat, Panggilan Aktif)
              MarkerLayer(
                markers: [
                  // Marker Gerobak Pedagang
                  Marker(
                    point: _merchantCoord,
                    width: 90,
                    height: 85,
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Gerobak Anda',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.storefront,
                              size: 22,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Marker Hotspot Keramaian Pembeli
                  if (snapshotAsync.valueOrNull != null)
                    ...snapshotAsync.valueOrNull!.hotspots.map((cluster) {
                      final weight = cluster.weight.clamp(0.1, 1.0);
                      final Color heatColor = weight >= 0.7
                          ? Colors.red.shade700
                          : weight >= 0.4
                          ? Colors.deepOrange
                          : Colors.amber.shade800;
                      final target = LatLng(
                        cluster.latitude,
                        cluster.longitude,
                      );
                      return Marker(
                        point: target,
                        width: 72,
                        height: 68,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _selectSpot(cluster, target),
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
                                    color: heatColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '🔥 ${cluster.totalRequests} Pembeli',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: heatColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.groups_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                  // Marker Riwayat Titik Permintaan Panggilan
                  if (snapshotAsync.valueOrNull != null)
                    ...snapshotAsync.valueOrNull!.demandHistoryCalls.map((
                      call,
                    ) {
                      final target = LatLng(
                        call.buyerLatitude!,
                        call.buyerLongitude!,
                      );
                      return Marker(
                        point: target,
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _selectSpot(call, target),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  // Marker Panggilan Diterima (Sedang Menuju Pembeli)
                  if (snapshotAsync.valueOrNull != null)
                    ...snapshotAsync.valueOrNull!.acceptedCalls
                        .where((c) => c.hasBuyerCoordinates)
                        .map((call) {
                          final target = LatLng(
                            call.buyerLatitude!,
                            call.buyerLongitude!,
                          );
                          return Marker(
                            point: target,
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: () => _selectSpot(call, target),
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
                                        color: AppColors.success,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Tujuan Aktif',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person_pin_circle,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                  // Marker Panggilan Masuk (Pending)
                  if (snapshotAsync.valueOrNull != null)
                    ...snapshotAsync.valueOrNull!.pendingCalls
                        .where((c) => c.hasBuyerCoordinates)
                        .map((call) {
                          final target = LatLng(
                            call.buyerLatitude!,
                            call.buyerLongitude!,
                          );
                          return Marker(
                            point: target,
                            width: 74,
                            height: 74,
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: () => _selectSpot(call, target),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 62,
                                      height: 62,
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.ring_volume_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                ],
              ),
            ],
          ),

          // 2. Header Atas & Filter Radius
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.radar,
                                  color: Colors.deepOrange,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Radar Sebaran Pembeli',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    snapshotAsync.when(
                                      loading: () => const Text(
                                        'Memindai keramaian pembeli...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      error: (_, __) => const Text(
                                        'Ketuk refresh untuk memindai ulang',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error,
                                        ),
                                      ),
                                      data: (data) => Text(
                                        '🔥 ${data.hotspots.length} Area Ramai • 📞 ${data.pendingCalls.length} Panggilan Masuk',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.deepOrange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [500, 1000, 2000].map((radius) {
                        final isSelected = selectedRadius == radius;
                        final label = radius >= 1000
                            ? '${radius ~/ 1000} km'
                            : '$radius m';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (_) {
                              ref
                                      .read(
                                        merchantRadarRadiusProvider.notifier,
                                      )
                                      .state =
                                  radius;
                              _mapController.move(
                                _merchantCoord,
                                _calculateZoom(radius),
                              );
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primaryLight,
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Tombol Kontrol Peta Mengambang (Kanan)
          Positioned(
            right: 16,
            bottom: _selectedSpot != null ? 245 : 130,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'refresh_merchant_radar_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepOrange,
                  onPressed: () => ref.invalidate(merchantRadarSnapshotProvider),
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'recenter_merchant_map_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: () {
                    _mapController.move(
                      _merchantCoord,
                      _calculateZoom(selectedRadius),
                    );
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'zoom_in_merchant_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  onPressed: () {
                    final z = _mapController.camera.zoom;
                    if (z < 18.0) {
                      _mapController.move(_mapController.camera.center, z + 1);
                    }
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_merchant_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  onPressed: () {
                    final z = _mapController.camera.zoom;
                    if (z > 10.0) {
                      _mapController.move(_mapController.camera.center, z - 1);
                    }
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // 4. Kartu Detail Titik yang Dipilih
          if (_selectedSpot != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 112,
              child: _buildSelectedSpotCard(_selectedSpot),
            ),

          // 5. Bar Bawah Status Berjualan
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelling ? AppColors.success : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSelling
                                ? 'Sedang Jualan Aktif'
                                : 'Status: Istirahat',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            isSelling
                                ? 'Lokasi gerobak terlihat oleh pembeli'
                                : 'Mulai jualan agar terlihat di radar',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: sellingState.isLoading
                          ? null
                          : () => _toggleSelling(isSelling),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelling
                            ? AppColors.error
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(110, 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isSelling ? 'Hentikan' : 'Mulai Jualan',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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

  Widget _buildSelectedSpotCard(dynamic spot) {
    if (spot is DemandHotspotCluster) {
      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.deepOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🔥 Area Ramai (${spot.totalRequests} Aktivitas Pembeli)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          spot.recommendation,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jarak: ${spot.distanceM.toStringAsFixed(0)} m dari gerobak Anda',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() {
                      _selectedSpot = null;
                      _previewRoutePoints = [];
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final hotspotCall = CallModel(
                      id: 'hotspot_${spot.latitude}_${spot.longitude}',
                      buyerId: '',
                      merchantId: '',
                      status: 'accept',
                      locationConsent: true,
                      createdAt: DateTime.now().toIso8601String(),
                      hasReview: false,
                      buyerLatitude: spot.latitude,
                      buyerLongitude: spot.longitude,
                      distanceM: spot.distanceM,
                    );
                    context.push('/selling/navigation', extra: hotspotCall);
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navigasi ke Area Ramai Ini'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (spot is CallModel) {
      final isPending = spot.isPending;
      final isAccepted = spot.status == 'accept';
      final shortId = spot.id.length >= 6
          ? spot.id.substring(0, 6).toUpperCase()
          : spot.id.toUpperCase();

      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPending
                          ? AppColors.error
                          : isAccepted
                          ? AppColors.success
                          : Colors.amber.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPending
                          ? Icons.ring_volume_rounded
                          : isAccepted
                          ? Icons.person_pin_circle
                          : Icons.local_fire_department,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPending
                              ? 'Panggilan Pembeli Masuk!'
                              : isAccepted
                              ? 'Panggilan Aktif (#$shortId)'
                              : 'Riwayat Permintaan (#$shortId)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isPending
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (spot.distanceM != null)
                          Text(
                            'Jarak: ${spot.distanceM!.toStringAsFixed(0)} m dari posisi Anda',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() {
                      _selectedSpot = null;
                      _previewRoutePoints = [];
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isPending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => IncomingCallDialog(call: spot),
                      );
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Respon Panggilan & Navigasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/selling/navigation', extra: spot);
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: Text(
                      isAccepted
                          ? 'Lanjutkan Navigasi ke Pembeli'
                          : 'Navigasi ke Titik Ini',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

