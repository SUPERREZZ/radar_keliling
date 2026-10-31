import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/websocket_service.dart';
import '../providers/radar_provider.dart';
import '../widgets/merchant_marker.dart';
import '../widgets/merchant_bottom_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';

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
  }

  Future<void> _initRadar() async {
    final locService = ref.read(locationServiceProvider);
    final granted = await locService.requestPermission();

    if (!granted) {
      setState(() => _locationPermissionDenied = true);
      return;
    }

    final loc = await locService.getCurrentLocation();
    if (loc != null && mounted) {
      setState(() => _userLocation = LatLng(loc.latitude, loc.longitude));
      _mapController.move(_userLocation!, 15);
      _fabAnim.forward();
    }

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
    wsService.connect(
      onEvent: (eventName, data) {
        final notifier = ref.read(radarProvider.notifier);
        if (eventName == 'MerchantLocationUpdated') {
          notifier.updateMerchantLocation(data);
        } else if (eventName == 'MerchantSellingStatusChanged') {
          notifier.updateMerchantSellingStatus(data);
        }
      },
      onReconnect: () => ref.read(radarProvider.notifier).resync(),
    );
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
    _fabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(radarProvider);
    final merchants = radarState.valueOrNull ?? [];
    final visibleMerchants = _maxDistanceM == null
        ? merchants
        : merchants
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
              // Marker posisi user
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 20,
                      height: 20,
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
                onTap: (m) => MerchantBottomSheet.show(context, m),
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
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.radar,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Radar Keliling',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${visibleMerchants.length} pedagang',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Refresh shortcut
                      GestureDetector(
                        onTap: _refreshRadar,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: radarState.isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.primary,
                                  size: 20,
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
        ],
      ),

      // ── FABs ─────────────────────────────────────────────
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton(
          heroTag: 'fab_location',
          onPressed: _centerOnUser,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          child: const Icon(Icons.my_location, size: 22),
        ),
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
