import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/merchant_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/road_routing_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../providers/radar_provider.dart';
import '../widgets/merchant_bottom_sheet.dart';
import '../widgets/merchant_marker.dart';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _locationPermissionDenied = false;
  double? _maxDistanceM;
  Timer? _autoRefreshTimer;
  StreamSubscription<LocationResult>? _positionSub;

  String? _selectedMerchantId;
  List<LatLng> _routePoints = [];

  late AnimationController _fabAnim;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScale = CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut);

    _initRadar();
    _initWebSocket();

    // Auto-refresh berkala tiap 8 detik untuk memastikan posisi pedagang selalu sinkron
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        ref.read(radarProvider.notifier).loadRadar(keepExisting: true);
      }
    });
  }

  Future<void> _initRadar() async {
    final locService = ref.read(locationServiceProvider);
    final granted = await locService.requestPermission();

    if (!granted) {
      if (mounted) setState(() => _locationPermissionDenied = true);
      return;
    }

    final loc = await locService.getCurrentLocation();
    if (loc != null && mounted) {
      setState(() => _userLocation = LatLng(loc.latitude, loc.longitude));
      _mapController.move(_userLocation!, 15);
      _fabAnim.forward();
    }

    // Stream lokasi buyer secara ringan (tanpa polling berat)
    _positionSub?.cancel();
    _positionSub = locService.watchPosition(distanceFilter: 8).listen((pos) {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });
      ref
          .read(radarProvider.notifier)
          .updateBuyerCoordinates(pos.latitude, pos.longitude);
    });

    final loaded = await ref.read(radarProvider.notifier).loadRadar();
    if (!loaded && mounted) {
      showRkSnackbar(
        context,
        'Radar belum bisa dimuat. Pastikan GPS aktif lalu coba refresh.',
        isError: true,
      );
    }
  }

  void _initWebSocket() {
    final wsService = ref.read(wsServiceProvider);
    wsService.addListener(
      'buyer_radar',
      onEvent: (eventName, data) {
        if (!mounted) return;
        final notifier = ref.read(radarProvider.notifier);
        final event =
            eventName.startsWith('.') ? eventName.substring(1) : eventName;

        if (event == 'MerchantLocationUpdated' ||
            event.endsWith('MerchantLocationUpdated')) {
          notifier.updateMerchantLocation(data);
          final updatedId =
              (data['merchant_id'] ?? data['merchantId']) as String?;
          final isSelling =
              (data['is_selling'] ?? data['isSelling']) as bool? ?? true;

          if (!isSelling &&
              updatedId != null &&
              updatedId == _selectedMerchantId) {
            setState(() {
              _selectedMerchantId = null;
              _routePoints = [];
            });
          } else if (updatedId != null && updatedId == _selectedMerchantId) {
            final lat = (data['latitude'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _loadRouteToMerchant(LatLng(lat, lng));
            }
          }
        } else if (event == 'MerchantSellingStatusChanged' ||
            event.endsWith('MerchantSellingStatusChanged')) {
          notifier.updateMerchantSellingStatus(data);
          final updatedId =
              (data['merchant_id'] ?? data['merchantId']) as String?;
          final isSelling =
              (data['is_selling'] ?? data['isSelling']) as bool? ?? false;

          if (!isSelling &&
              updatedId != null &&
              updatedId == _selectedMerchantId) {
            setState(() {
              _selectedMerchantId = null;
              _routePoints = [];
            });
          }
        }
      },
      onReconnect: () {
        if (mounted) {
          ref.read(radarProvider.notifier).resync();
        }
      },
    );
  }

  Future<void> _loadRouteToMerchant(LatLng merchantCoord) async {
    final userLoc = _userLocation;
    if (userLoc == null) return;
    try {
      final route = await ref
          .read(roadRoutingServiceProvider)
          .getRoute(merchantCoord, userLoc);
      if (mounted) {
        setState(() {
          _routePoints = route.polylinePoints;
        });
      }
    } catch (_) {}
  }

  void _onSelectMerchant(MerchantRadarItem m) {
    setState(() {
      _selectedMerchantId = m.merchantId;
    });
    _loadRouteToMerchant(LatLng(m.latitude, m.longitude));
    MerchantBottomSheet.show(context, m);
  }

  Future<void> _refreshRadar() async {
    final loaded = await ref
        .read(radarProvider.notifier)
        .loadRadar(keepExisting: true);
    if (!mounted) return;
    if (loaded) {
      showRkSnackbar(context, 'Radar berhasil diperbarui.');
    } else {
      showRkSnackbar(
        context,
        'Radar belum bisa diperbarui. Pastikan GPS aktif lalu coba lagi.',
        isError: true,
      );
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15);
    } else {
      showRkSnackbar(context, 'Izin lokasi belum diberikan.', isError: true);
    }
  }

  @override
  void dispose() {
    ref.read(wsServiceProvider).removeListener('buyer_radar');
    _positionSub?.cancel();
    _autoRefreshTimer?.cancel();
    _fabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(radarProvider);
    final allMerchants = radarState.valueOrNull ?? [];
    final activeMerchants = allMerchants
        .where((m) => m.isSelling && m.isLocationFresh)
        .toList(growable: false);
    final visibleMerchants = _maxDistanceM == null
        ? activeMerchants
        : activeMerchants
              .where((m) => m.distanceM <= _maxDistanceM!)
              .toList(growable: false);

    return Scaffold(
      body: Stack(
        children: [
          // ── Peta ─────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? const LatLng(-7.47, 112.43),
              initialZoom: 14,
              maxZoom: 18,
              minZoom: 10,
              onTap: (_, __) {
                if (_routePoints.isNotEmpty || _selectedMerchantId != null) {
                  setState(() {
                    _selectedMerchantId = null;
                    _routePoints = [];
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
              // Lingkaran radius radar 3km
              if (_userLocation != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userLocation!,
                      radius: 3000,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withOpacity(0.04),
                      borderColor: AppColors.primary.withOpacity(0.2),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              // Garis jalur jalan (OSRM Road Polyline) dari pedagang terpilih ke pembeli
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 9.0,
                      color: AppColors.primaryDark.withOpacity(0.85),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.5,
                      color: const Color(0xFF00B14F),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              // Marker posisi user
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              // Marker pedagang
              MerchantMarkerLayer(
                merchants: visibleMerchants,
                onTap: _onSelectMerchant,
              ),
            ],
          ),

          // ── Top bar ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.radar,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Radar Keliling',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      radarState.isLoading
                                          ? 'Memindai pedagang terdekat...'
                                          : '${visibleMerchants.length} Pedagang Aktif',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: visibleMerchants.isNotEmpty
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
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
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _MapFilterChip(
                          label: 'Semua',
                          selected: _maxDistanceM == null,
                          onTap: () => setState(() => _maxDistanceM = null),
                        ),
                        const SizedBox(width: 8),
                        _MapFilterChip(
                          label: '< 500 m',
                          selected: _maxDistanceM == 500,
                          onTap: () => setState(() => _maxDistanceM = 500),
                        ),
                        const SizedBox(width: 8),
                        _MapFilterChip(
                          label: '< 1 km',
                          selected: _maxDistanceM == 1000,
                          onTap: () => setState(() => _maxDistanceM = 1000),
                        ),
                        const SizedBox(width: 8),
                        _MapFilterChip(
                          label: '< 2 km',
                          selected: _maxDistanceM == 2000,
                          onTap: () => setState(() => _maxDistanceM = 2000),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Peringatan izin lokasi ditolak ────────────────
          if (_locationPermissionDenied)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Izin lokasi ditolak. Aktifkan lokasi untuk melihat pedagang terdekat.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Tombol Kontrol Peta Mengambang (Kanan) ────────
          Positioned(
            right: 16,
            bottom: 24,
            child: ScaleTransition(
              scale: _fabScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Refresh radar
                  FloatingActionButton.small(
                    heroTag: 'refresh_buyer_radar_btn',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    onPressed: _refreshRadar,
                    child: radarState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.refresh),
                  ),
                  const SizedBox(height: 10),
                  // Recenter to user
                  FloatingActionButton.small(
                    heroTag: 'recenter_buyer_btn',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    onPressed: _centerOnUser,
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 10),
                  // Zoom in
                  FloatingActionButton.small(
                    heroTag: 'zoom_in_buyer_btn',
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
                  // Zoom out
                  FloatingActionButton.small(
                    heroTag: 'zoom_out_buyer_btn',
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
          ),
        ],
      ),
    );
  }
}

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
