import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_config.dart';
import '../../../core/models/merchant_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../call/widgets/call_button.dart';
import '../../merchant_profile/providers/merchant_profile_provider.dart';

class MerchantBottomSheet extends ConsumerWidget {
  const MerchantBottomSheet({super.key, required this.merchant});
  final MerchantRadarItem merchant;

  static Future<void> show(BuildContext context, MerchantRadarItem merchant) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MerchantBottomSheet(merchant: merchant),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      merchantPublicProfileProvider(merchant.merchantId),
    );
    final profile = profileAsync.valueOrNull;
    final photoUrl = merchant.profilePhotoUrl ?? profile?.profilePhotoUrl;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(
                        Icons.storefront,
                        color: AppColors.primary,
                        size: 26,
                      )
                    : CachedNetworkImage(
                        imageUrl: AppConfig.resolveMediaUrl(photoUrl),
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppColors.primaryLight),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.storefront,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.businessName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${merchant.distanceM.toInt()} m dari kamu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (profile != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            profile.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Berjualan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.pop();
                    context.push('/merchant/${merchant.merchantId}');
                  },
                  icon: const Icon(Icons.info_outline, size: 17),
                  label: const Text('Lihat Profil'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CallButton(
                  merchantId: merchant.merchantId,
                  distanceM: merchant.distanceM,
                  onCallDone: () => context.pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
