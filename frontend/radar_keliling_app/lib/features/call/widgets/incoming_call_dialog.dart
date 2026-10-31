import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/call_model.dart';
import '../../../core/services/call_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../selling/providers/merchant_radar_provider.dart';

class IncomingCallDialog extends ConsumerStatefulWidget {
  const IncomingCallDialog({super.key, required this.call});

  final CallModel call;

  @override
  ConsumerState<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends ConsumerState<IncomingCallDialog> {
  bool _isLoading = false;

  Future<void> _answer() async {
    setState(() => _isLoading = true);
    try {
      final accepted = await ref
          .read(callServiceProvider)
          .acceptCall(widget.call.id);
      ref.invalidate(merchantRadarSnapshotProvider);

      final mergedCall = accepted.copyWith(
        buyerLatitude: accepted.buyerLatitude ?? widget.call.buyerLatitude,
        buyerLongitude: accepted.buyerLongitude ?? widget.call.buyerLongitude,
        distanceM: accepted.distanceM ?? widget.call.distanceM,
      );

      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.pop(context, true);
      router.push('/selling/navigation', extra: mergedCall);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showRkSnackbar(
        context,
        'Gagal menerima panggilan. Mungkin sudah dibatalkan.',
        isError: true,
      );
      Navigator.pop(context, false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(callServiceProvider).markUnanswered(widget.call.id);
      ref.invalidate(merchantRadarSnapshotProvider);
      if (!mounted) return;
      Navigator.pop(context, false);
      showRkSnackbar(context, 'Panggilan ditolak.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final shortId = call.id.length >= 6
        ? call.id.substring(0, 6).toUpperCase()
        : call.id.toUpperCase();

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.ring_volume_rounded,
                color: AppColors.accent,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panggilan Masuk!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ada pembeli memanggil gerobak kamu',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pembeli #$shortId',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          call.distanceM != null && call.distanceM! > 0
                              ? 'Jarak sekitar ${call.distanceM!.toStringAsFixed(0)} m dari kamu'
                              : 'Menunggu kamu menghampiri lokasi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (call.hasBuyerCoordinates) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.route_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lokasi dibagikan (${call.buyerLatitude!.toStringAsFixed(5)}, ${call.buyerLongitude!.toStringAsFixed(5)})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actionsOverflowButtonSpacing: 8,
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _reject,
            child: const Text(
              'Tolak',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _answer,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.navigation_rounded, size: 18),
            label: const Text('Terima & Navigasi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(150, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

