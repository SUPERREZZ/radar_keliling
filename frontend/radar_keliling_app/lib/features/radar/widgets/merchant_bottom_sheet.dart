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

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
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
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.12),
                      width: 1.5,
                    ),
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
                const SizedBox(width: 14),
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
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
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
                              size: 15,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              profile.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '(${profile.totalReviews} ulasan)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.pop();
                        context.push('/merchant/${merchant.merchantId}');
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text(
                        'Profil & Ulasan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
      ),
    );
  }
}
