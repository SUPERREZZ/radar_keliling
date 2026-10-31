import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../config/app_config.dart';
import '../../../core/models/merchant_model.dart';
import '../../../shared/theme/app_theme.dart';

class MerchantMarkerLayer extends StatelessWidget {
  const MerchantMarkerLayer({
    super.key,
    required this.merchants,
    required this.onTap,
  });

  final List<MerchantRadarItem> merchants;
  final ValueChanged<MerchantRadarItem> onTap;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: merchants
          .where((m) => m.isSelling && m.isLocationFresh)
          .map(
            (m) => Marker(
              point: LatLng(m.latitude, m.longitude),
              width: 56,
              height: 64,
              child: _MarkerWidget(merchant: m, onTap: () => onTap(m)),
            ),
          )
          .toList(),
    );
  }
}

class _MarkerWidget extends StatefulWidget {
  const _MarkerWidget({required this.merchant, required this.onTap});
  final MerchantRadarItem merchant;
  final VoidCallback onTap;

  @override
  State<_MarkerWidget> createState() => _MarkerWidgetState();
}

class _MarkerWidgetState extends State<_MarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: false);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse ring
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(
                          0.15 * (2.0 - _pulseAnim.value),
                        ),
                      ),
                    ),
                  ),
                ),
                // Foto / ikon utama
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.merchant.profilePhotoUrl == null
                        ? Container(
                            color: AppColors.primary,
                            child: const Icon(
                              Icons.storefront,
                              size: 16,
                              color: Colors.white,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: AppConfig.resolveMediaUrl(
                              widget.merchant.profilePhotoUrl!,
                            ),
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.primaryLight),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.primary,
                              child: const Icon(
                                Icons.storefront,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Label jarak
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${widget.merchant.distanceM.toInt()}m',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
