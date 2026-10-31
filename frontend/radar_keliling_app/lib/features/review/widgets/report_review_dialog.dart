import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/call_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';

class ReportReviewDialog extends ConsumerStatefulWidget {
  const ReportReviewDialog({super.key, required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends ConsumerState<ReportReviewDialog> {
  final _reasonCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      showRkSnackbar(context, 'Alasan laporan wajib diisi.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(callServiceProvider)
          .reportReview(reviewId: widget.reviewId, reason: reason);
      if (!mounted) return;
      Navigator.pop(context);
      showRkSnackbar(context, 'Laporan Anda berhasil dikirim ke moderator.');
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal mengirim laporan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.report_problem_outlined, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text(
            'Laporkan Ulasan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apakah ulasan ini mengandung kata kasar, penipuan, atau konten tidak pantas?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Alasan Laporan',
              hintText: 'Tuliskan alasan laporan Anda...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Kirim Laporan'),
        ),
      ],
    );
  }
}

