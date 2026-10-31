import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/review_model.dart';
import '../providers/admin_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_snackbar.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(adminReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Ulasan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(adminReportsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: reportsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Gagal memuat laporan'),
              TextButton(
                onPressed: () => ref.invalidate(adminReportsProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: AppColors.success),
                  SizedBox(height: 12),
                  Text('Tidak ada laporan yang masuk',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          final pending =
              reports.where((r) => r.status == 'pending').toList();
          final done =
              reports.where((r) => r.status != 'pending').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Perlu Ditinjau',
                    count: pending.length,
                    color: AppColors.warning),
                const SizedBox(height: 8),
                ...pending.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReportCard(report: r),
                    )),
                const SizedBox(height: 16),
              ],
              if (done.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Sudah Ditangani',
                    count: done.length,
                    color: AppColors.textSecondary),
                const SizedBox(height: 8),
                ...done.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReportCard(report: r, dimmed: true),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends ConsumerStatefulWidget {
  const _ReportCard({required this.report, this.dimmed = false});
  final ReviewReportModel report;
  final bool dimmed;

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _hiding = false;

  Future<void> _hideReview() async {
    setState(() => _hiding = true);
    try {
      await ref
          .read(apiClientProvider)
          .patch(Endpoints.adminHideReview(widget.report.reviewId));
      if (!mounted) return;
      showRkSnackbar(context, 'Ulasan berhasil disembunyikan.');
      ref.invalidate(adminReportsProvider);
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal menyembunyikan ulasan.',
          isError: true);
    } finally {
      if (mounted) setState(() => _hiding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.dimmed ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                _StatusBadge(status: widget.report.status),
                const Spacer(),
                Text(
                  _formatDate(widget.report.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Alasan laporan
            Text(
              widget.report.reason,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Review ID: ${widget.report.reviewId.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textHint),
            ),

            // Tombol sembunyikan — hanya untuk laporan pending
            if (widget.report.status == 'pending') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _hiding ? null : _hideReview,
                  icon: _hiding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error),
                        )
                      : const Icon(Icons.visibility_off_outlined,
                          size: 16),
                  label: const Text('Sembunyikan Ulasan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(
                        color: AppColors.error, width: 1),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
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
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending' => (AppColors.warning, 'Menunggu'),
      'reviewed' => (AppColors.primary, 'Ditinjau'),
      'resolved' => (AppColors.success, 'Selesai'),
      _ => (AppColors.textHint, status),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }
}
