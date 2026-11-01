import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/call_model.dart';
import '../../../core/services/call_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_button.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../auth/providers/auth_provider.dart';

final _callDetailProvider = FutureProvider.autoDispose.family<CallModel, String>(
  (ref, callId) {
    return ref.read(callServiceProvider).getCallById(callId);
  },
);

class CallDetailScreen extends ConsumerWidget {
  const CallDetailScreen({super.key, required this.callId});
  final String callId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callAsync = ref.watch(_callDetailProvider(callId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Panggilan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: callAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => const Center(child: Text('Gagal memuat detail')),
        data: (call) => _CallDetailContent(call: call),
      ),
    );
  }
}

class _CallDetailContent extends ConsumerStatefulWidget {
  const _CallDetailContent({required this.call});
  final CallModel call;

  @override
  ConsumerState<_CallDetailContent> createState() => _CallDetailContentState();
}

class _CallDetailContentState extends ConsumerState<_CallDetailContent>
    with SingleTickerProviderStateMixin {
  bool _cancelling = false;
  bool _accepting = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Color get _statusColor => switch (widget.call.status) {
    'accept' || 'completed' => AppColors.success,
    'unanswered' => AppColors.warning,
    'cancelled' || 'expired' => AppColors.textHint,
    _ => AppColors.primary,
  };

  String get _statusLabel => switch (widget.call.status) {
    'accept' => 'Diterima',
    'completed' => 'Selesai Dilayani',
    'unanswered' => 'Tidak Dijawab',
    'cancelled' => 'Dibatalkan',
    'expired' => 'Kedaluwarsa',
    _ => 'Menunggu',
  };

  IconData get _statusIcon => switch (widget.call.status) {
    'accept' || 'completed' => Icons.check_circle_outline,
    'unanswered' => Icons.do_not_disturb_alt_outlined,
    'cancelled' => Icons.cancel_outlined,
    'expired' => Icons.hourglass_disabled_outlined,
    _ => Icons.pending_outlined,
  };

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ref.read(callServiceProvider).cancelCall(widget.call.id);
      if (!mounted) return;
      showRkSnackbar(context, 'Panggilan berhasil dibatalkan.');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal membatalkan panggilan.', isError: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _acceptAndNavigate() async {
    setState(() => _accepting = true);
    try {
      final accepted = await ref
          .read(callServiceProvider)
          .acceptCall(widget.call.id);
      final merged = accepted.copyWith(
        buyerLatitude: accepted.buyerLatitude ?? widget.call.buyerLatitude,
        buyerLongitude: accepted.buyerLongitude ?? widget.call.buyerLongitude,
        distanceM: accepted.distanceM ?? widget.call.distanceM,
      );
      if (!mounted) return;
      context.pushReplacement('/selling/navigation', extra: merged);
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal menerima panggilan.', isError: true);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _rejectCall() async {
    setState(() => _cancelling = true);
    try {
      await ref.read(callServiceProvider).markUnanswered(widget.call.id);
      if (!mounted) return;
      showRkSnackbar(context, 'Panggilan ditolak.');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal menolak panggilan.', isError: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final user = ref.watch(authProvider).valueOrNull;
    final isMerchant = user?.isMerchant ?? false;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Status card utama ─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon, color: _statusColor, size: 36),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _statusColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(call.createdAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Info detail ───────────────────────────────
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Lokasi dibagikan',
                  value: call.locationConsent ? 'Ya' : 'Tidak',
                ),
                if (call.distanceM != null)
                  _InfoRow(
                    icon: Icons.straighten_rounded,
                    label: 'Jarak ke Pembeli',
                    value: '${call.distanceM!.toStringAsFixed(0)} m',
                  ),
                _InfoRow(
                  icon: Icons.fingerprint,
                  label: 'ID Panggilan',
                  value: call.id.length >= 8
                      ? call.id.substring(0, 8).toUpperCase()
                      : call.id.toUpperCase(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Aksi Pedagang ─────────────────────────────
            if (isMerchant && call.isPending) ...[
              RkButton(
                label: 'Terima & Navigasi ke Pembeli',
                onPressed: _acceptAndNavigate,
                isLoading: _accepting,
                color: AppColors.primary,
                icon: Icons.navigation_rounded,
              ),
              const SizedBox(height: 10),
              RkButton(
                label: 'Tolak Panggilan',
                onPressed: _rejectCall,
                isLoading: _cancelling,
                color: AppColors.error,
                icon: Icons.close_rounded,
              ),
            ],

            if (isMerchant && call.status == 'accept') ...[
              RkButton(
                label: 'Buka Navigasi ke Lokasi Pembeli',
                onPressed: () =>
                    context.push('/selling/navigation', extra: call),
                color: AppColors.primary,
                icon: Icons.navigation_rounded,
              ),
            ],

            // ── Aksi Pembeli ──────────────────────────────
            if (!isMerchant && call.isPending)
              RkButton(
                label: 'Batalkan Panggilan',
                onPressed: _cancel,
                isLoading: _cancelling,
                color: AppColors.error,
                icon: Icons.cancel_outlined,
              ),

            if (!isMerchant && call.canReview) ...[
              RkButton(
                label: 'Beri Ulasan',
                onPressed: () => context.push('/calls/${call.id}/review'),
                icon: Icons.star_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children:
            children
                .expand(
                  (w) => [
                    w,
                    const Divider(height: 20, color: AppColors.divider),
                  ],
                )
                .toList()
              ..removeLast(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
