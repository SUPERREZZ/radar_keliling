import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Sync initial selling state dari profil
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = await ref.read(merchantSelfProfileProvider.future);
      ref.read(sellingProvider.notifier).setInitialState(profile.isSelling);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleSelling(bool isSelling) async {
    try {
      if (isSelling) {
        await ref.read(sellingProvider.notifier).stopSelling();
        _pulseCtrl.stop();
      } else {
        await ref.read(sellingProvider.notifier).startSelling();
        _pulseCtrl.repeat(reverse: true);
      }
      if (!mounted) return;
      showRkSnackbar(
        context,
        isSelling ? 'Kamu sudah berhenti berjualan.' : 'Sekarang kamu terlihat di radar!',
      );
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal mengubah status.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final sellingState = ref.watch(sellingProvider);
    final isSelling = sellingState.valueOrNull ?? false;
    final isLoading = sellingState.isLoading;

    // Pulse animasi saat aktif
    if (isSelling && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!isSelling && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // ── Header ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  // Edit profil
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.textPrimary),
                    ),
                    onPressed: () => context.push('/profile/edit'),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Tombol utama berjualan ───────────────────
              Center(
                child: GestureDetector(
                  onTap: isLoading ? null : () => _toggleSelling(isSelling),
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: isSelling ? _pulseAnim.value : 1.0,
                      child: child,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelling
                            ? AppColors.primary
                            : AppColors.surface,
                        border: Border.all(
                          color: isSelling
                              ? AppColors.primary
                              : AppColors.divider,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelling
                                ? AppColors.primary.withOpacity(0.35)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: isSelling ? 30 : 10,
                            spreadRadius: isSelling ? 4 : 0,
                          ),
                        ],
                      ),
                      child: isLoading
                          ? CircularProgressIndicator(
                              color:
                                  isSelling ? Colors.white : AppColors.primary,
                              strokeWidth: 3,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelling
                                      ? Icons.stop_circle_outlined
                                      : Icons.play_circle_outline,
                                  size: 52,
                                  color: isSelling
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isSelling
                                      ? 'Berhenti\nBerjualan'
                                      : 'Mulai\nBerjualan',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isSelling
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Status label ─────────────────────────────
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isSelling
                      ? Container(
                          key: const ValueKey('active'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  size: 8, color: AppColors.success),
                              SizedBox(width: 6),
                              Text(
                                'Terlihat di radar pembeli',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          key: const ValueKey('inactive'),
                          'Ketuk tombol untuk mulai berjualan',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                ),
              ),

              const Spacer(),

              // ── Quick menu bawah ─────────────────────────
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.restaurant_menu_outlined,
                    label: 'Kelola\nMenu',
                    onTap: () {
                      // TODO: navigate ke menu management screen
                    },
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.history_outlined,
                    label: 'Riwayat\nPanggilan',
                    onTap: () => context.push('/calls'),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.logout_outlined,
                    label: 'Keluar',
                    onTap: () =>
                        ref.read(authProvider.notifier).logout(),
                    color: AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Icon(icon, color: c, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c,
                    height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
