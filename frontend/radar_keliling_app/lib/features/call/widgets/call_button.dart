import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/location_service.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../../shared/theme/app_theme.dart';

class CallButton extends ConsumerStatefulWidget {
  const CallButton({
    super.key,
    required this.merchantId,
    required this.distanceM,
    this.onCallDone,
  });

  final String merchantId;
  final double distanceM;
  final VoidCallback? onCallDone;

  @override
  ConsumerState<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends ConsumerState<CallButton> {
  bool _loading = false;

  bool get _inRange =>
      widget.distanceM <= AppConfig.callRadiusMeters;

  Future<void> _handleCall() async {
    if (!_inRange) {
      showRkSnackbar(
        context,
        'Kamu harus dalam radius 200m untuk memanggil pedagang ini.',
        isError: true,
      );
      return;
    }

    // Dialog consent lokasi
    final consent = await _showConsentDialog();
    if (!mounted || consent == null) return;

    setState(() => _loading = true);
    try {
      final locService = ref.read(locationServiceProvider);
      final loc = consent
          ? await locService.getLocationForCall()
          : await locService.getCurrentLocation();

      if (!mounted) return;

      if (consent && loc == null) {
        showRkSnackbar(
          context,
          'Akurasi GPS tidak mencukupi (> 50m). Coba lagi di tempat terbuka.',
          isError: true,
        );
        return;
      }

      await ref.read(callServiceProvider).createCall(
            merchantId: widget.merchantId,
            shareLocation: consent,
            buyerLatitude: loc?.latitude ?? 0,
            buyerLongitude: loc?.longitude ?? 0,
            gpsAccuracyM: loc?.accuracyM ?? 999,
          );

      if (!mounted) return;
      showRkSnackbar(context, 'Panggilan berhasil dikirim!');
      widget.onCallDone?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'LOCATION_OUT_OF_RANGE' =>
          'Kamu sudah di luar jangkauan pedagang ini.',
        'GPS_ACCURACY_INSUFFICIENT' =>
          'Akurasi GPS tidak cukup. Pindah ke tempat terbuka.',
        'CALL_RATE_LIMITED' =>
          'Terlalu banyak panggilan. Tunggu sebentar.',
        'MERCHANT_NOT_SELLING' =>
          'Pedagang sudah tidak berjualan.',
        _ => e.message,
      };
      showRkSnackbar(context, msg, isError: true);
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal mengirim panggilan.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showConsentDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Bagikan Lokasimu?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'Agar pedagang bisa menemukan kamu, lokasi kamu akan dibagikan ke pedagang ini. '
          'Data lokasi dihapus otomatis setelah 24 jam.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak, lanjutkan',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, bagikan',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _inRange ? 1.0 : 0.4,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _handleCall,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.campaign_outlined, size: 18),
        label: const Text('Panggil'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
