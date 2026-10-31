import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_config.dart';
import '../../../core/models/merchant_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/merchant_profile/providers/merchant_profile_provider.dart';
import '../providers/selling_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';

class SellingHomeScreen extends ConsumerStatefulWidget {
  const SellingHomeScreen({super.key});

  @override
  ConsumerState<SellingHomeScreen> createState() => _SellingHomeScreenState();
}

class _SellingHomeScreenState extends ConsumerState<SellingHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSellingState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sellingProvider.notifier).refreshHeartbeat();
      ref.invalidate(merchantSelfProfileProvider);
      ref.invalidate(merchantSelfMenusProvider);
    }
  }

  Future<void> _syncSellingState() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final profile = await ref.read(merchantSelfProfileProvider.future);
      if (!mounted) return;
      ref.read(sellingProvider.notifier).setInitialState(profile.isSelling);
    } catch (_) {
      if (mounted) {
        showRkSnackbar(
          context,
          'Gagal memuat status berjualan.',
          isError: true,
        );
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _toggleSelling(bool isSelling) async {
    try {
      if (isSelling) {
        await ref.read(sellingProvider.notifier).stopSelling();
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      } else {
        await ref.read(sellingProvider.notifier).startSelling();
        _pulseCtrl.repeat(reverse: true);
      }
      if (!mounted) return;
      showRkSnackbar(
        context,
        isSelling
            ? 'Kamu sudah berhenti berjualan.'
            : 'Sekarang kamu terlihat di radar pembeli.',
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

  Future<void> _logout(bool isSelling) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar dari akun?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isSelling
              ? 'Kamu akan berhenti berjualan dan tidak lagi terlihat di radar.'
              : 'Kamu bisa masuk kembali kapan saja.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (isSelling) {
      try {
        await ref.read(sellingProvider.notifier).stopSelling();
      } catch (_) {
        // Logout tetap dilanjutkan walaupun update status gagal.
      }
    }
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _refreshData() async {
    ref.invalidate(merchantSelfProfileProvider);
    ref.invalidate(merchantSelfMenusProvider);
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) await _syncSellingState();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final profileAsync = ref.watch(merchantSelfProfileProvider);
    final menusAsync = ref.watch(merchantSelfMenusProvider);
    final sellingState = ref.watch(sellingProvider);
    final profile = profileAsync.valueOrNull;
    final isSelling = sellingState.valueOrNull ?? false;
    final isLoading = sellingState.isLoading;
    final menuCount = menusAsync.valueOrNull?.length;

    AsyncValue<MerchantProfile>? publicProfileAsync;
    if (profile != null) {
      publicProfileAsync = ref.watch(merchantPublicProfileProvider(profile.id));
    }
    final rating = publicProfileAsync?.valueOrNull?.averageRating;

    if (isSelling && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!isSelling && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }

    final displayName =
        profile?.businessName ??
        (user?.email.isNotEmpty == true
            ? user!.email.split('@').first
            : 'Pedagang');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _Header(
                displayName: displayName,
                email: user?.email ?? '',
                photoUrl: profile?.profilePhotoUrl,
                onEdit: () => context.push('/profile/edit'),
              ),
              const SizedBox(height: 24),
              _SellingCard(
                isSelling: isSelling,
                isLoading: isLoading,
                pulseAnim: _pulseAnim,
                onToggle: () => _toggleSelling(isSelling),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Menu',
                    value: menuCount?.toString() ?? '—',
                    color: AppColors.primary,
                    onTap: () => context.push('/profile/menus'),
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.star_rounded,
                    label: 'Rating',
                    value: rating == null ? '—' : rating.toStringAsFixed(1),
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: isSelling
                        ? Icons.radar_rounded
                        : Icons.visibility_off_outlined,
                    label: 'Radar',
                    value: isSelling ? 'Aktif' : 'Mati',
                    color: isSelling ? AppColors.success : AppColors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'Aksi Cepat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickTile(
                    icon: Icons.restaurant_menu_outlined,
                    label: 'Kelola\nMenu',
                    color: AppColors.primary,
                    background: AppColors.primaryLight,
                    onTap: () => context.push('/profile/menus'),
                  ),
                  const SizedBox(width: 10),
                  _QuickTile(
                    icon: Icons.history_rounded,
                    label: 'Riwayat\nPanggilan',
                    color: const Color(0xFF2563EB),
                    background: const Color(0xFFEFF6FF),
                    onTap: () => context.push('/calls'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _QuickTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit\nProfil',
                    color: const Color(0xFF7C3AED),
                    background: const Color(0xFFF5F3FF),
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const SizedBox(width: 10),
                  _QuickTile(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    color: AppColors.error,
                    background: const Color(0xFFFEF2F2),
                    onTap: () => _logout(isSelling),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.tips_and_updates_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tips biar makin ramai',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Lengkapi foto profil dan menu, lalu tetap buka aplikasi saat berjualan agar lokasi kamu terus diperbarui.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.onEdit,
  });

  final String displayName;
  final String email;
  final String? photoUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final resolvedPhoto = photoUrl == null
        ? null
        : AppConfig.resolveMediaUrl(photoUrl!);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Pedagang',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Halo, $displayName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onEdit,
          child: Stack(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: resolvedPhoto == null || resolvedPhoto.isEmpty
                    ? const Icon(
                        Icons.storefront,
                        color: AppColors.primary,
                        size: 26,
                      )
                    : CachedNetworkImage(
                        imageUrl: resolvedPhoto,
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
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 9, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SellingCard extends StatelessWidget {
  const _SellingCard({
    required this.isSelling,
    required this.isLoading,
    required this.pulseAnim,
    required this.onToggle,
  });

  final bool isSelling;
  final bool isLoading;
  final Animation<double> pulseAnim;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isSelling
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              )
            : null,
        color: isSelling ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: isSelling ? null : Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: isSelling
                ? AppColors.primary.withOpacity(0.22)
                : Colors.black.withOpacity(0.04),
            blurRadius: isSelling ? 24 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: isSelling ? pulseAnim.value : 1,
                  child: child,
                ),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isSelling
                        ? Colors.white.withOpacity(0.16)
                        : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelling
                        ? Icons.radar_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 30,
                    color: isSelling ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelling ? 'Sedang berjualan' : 'Belum berjualan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isSelling ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isSelling
                          ? 'Posisi kamu tampil di radar pembeli.'
                          : 'Aktifkan agar pembeli di sekitarmu bisa menemukanmu.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isSelling
                            ? Colors.white.withOpacity(0.82)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: isLoading ? null : onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 50,
              decoration: BoxDecoration(
                color: isSelling ? Colors.white : AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: isSelling ? AppColors.primary : Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelling
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_fill_rounded,
                            size: 19,
                            color: isSelling ? AppColors.primary : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSelling
                                ? 'Berhenti Berjualan'
                                : 'Mulai Berjualan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelling
                                  ? AppColors.primary
                                  : Colors.white,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
