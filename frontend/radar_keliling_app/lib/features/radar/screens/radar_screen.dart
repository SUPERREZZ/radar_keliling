import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
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

    await ref.read(radarProvider.notifier).loadRadar();
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
    await ref.read(radarProvider.notifier).loadRadar();
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
    final user = ref.watch(authProvider).valueOrNull;
    final radarState = ref.watch(radarProvider);
    final merchants = radarState.valueOrNull ?? [];

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
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          border:
                              Border.all(color: Colors.white, width: 2.5),
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
                merchants: merchants,
                onTap: (m) => MerchantBottomSheet.show(context, m),
              ),
            ],
          ),

          // ── Top bar ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                          const Icon(Icons.radar,
                              color: AppColors.primary, size: 20),
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
                          if (radarState.isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            )
                          else
                            Text(
                              '${merchants.length} pedagang',
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
                  // Menu akun
                  GestureDetector(
                    onTap: () => _showAccountMenu(context, user?.role),
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
                      child: const Icon(Icons.person_outline,
                          color: AppColors.textPrimary, size: 20),
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
                    Icon(Icons.location_off_outlined,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Izin lokasi ditolak. Aktifkan lokasi untuk melihat pedagang terdekat.',
                        style:
                            TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // ── FABs ─────────────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Refresh
          FloatingActionButton.small(
            heroTag: 'fab_refresh',
            onPressed: _refreshRadar,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            elevation: 2,
            child: const Icon(Icons.refresh, size: 20),
          ),
          const SizedBox(height: 10),
          // Lokasi user
          ScaleTransition(
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
        ],
      ),

      // ── Bottom nav ────────────────────────────────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar, color: AppColors.primary),
            label: 'Radar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon:
                Icon(Icons.history, color: AppColors.primary),
            label: 'Riwayat',
          ),
        ],
        onDestinationSelected: (i) {
          if (i == 1) context.push('/calls');
        },
      ),
    );
  }

  void _showAccountMenu(BuildContext context, String? role) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            if (role == 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined,
                    color: AppColors.primary),
                title: const Text('Panel Admin'),
                onTap: () {
                  context.pop();
                  context.push('/admin/reports');
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout_outlined,
                  color: AppColors.error),
              title: const Text('Keluar',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                context.pop();
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
