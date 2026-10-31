import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/menu_model.dart';
import '../providers/merchant_profile_provider.dart';
import '../../../shared/theme/app_theme.dart';

class MenuListScreen extends ConsumerWidget {
  const MenuListScreen({super.key, required this.merchantId});
  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menusAsync = ref.watch(merchantMenusProvider(merchantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: menusAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Gagal memuat menu')),
        data: (menus) {
          if (menus.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_meals, size: 48, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text('Belum ada menu',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: menus.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MenuCard(menu: menus[i]),
          );
        },
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.menu});
  final MenuItem menu;

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto carousel (jika ada)
          if (menu.photos.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                child: PageView.builder(
                  itemCount: menu.photos.length,
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: menu.photos[i].url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) =>
                        Container(color: AppColors.primaryLight),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.textHint),
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        menu.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!menu.isAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Habis',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
                if (menu.description != null &&
                    menu.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    menu.description!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  currency.format(menu.price),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
