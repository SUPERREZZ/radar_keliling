import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/call_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_button.dart';
import '../../../shared/widgets/rk_snackbar.dart';

class ReviewFormScreen extends ConsumerStatefulWidget {
  const ReviewFormScreen({super.key, required this.callId});
  final String callId;

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _textCtrl = TextEditingController();
  bool _submitting = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showRkSnackbar(context, 'Pilih rating dulu sebelum mengirim.',
          isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(callServiceProvider).submitReview(
            callId: widget.callId,
            rating: _rating,
            reviewText:
                _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim(),
          );
      if (!mounted) return;
      showRkSnackbar(context, 'Ulasan berhasil dikirim. Terima kasih!');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'REVIEW_ALREADY_EXISTS'
          ? 'Kamu sudah memberikan ulasan untuk panggilan ini.'
          : e.message;
      showRkSnackbar(context, msg, isError: true);
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal mengirim ulasan.', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Beri Ulasan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Bintang rating ─────────────────────────
              const Text(
                'Bagaimana pengalamanmu?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap bintang untuk memberi penilaian.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: filled ? 0.8 : 1.0,
                            end: filled ? 1.0 : 0.85),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.elasticOut,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 46,
                          color: filled
                              ? AppColors.warning
                              : AppColors.divider,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Label rating
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _rating > 0
                    ? Padding(
                        key: ValueKey(_rating),
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _ratingLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : const SizedBox(height: 12, key: ValueKey(0)),
              ),

              const SizedBox(height: 32),

              // ── Teks ulasan ────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: const TextSpan(
                    text: 'Ceritakan pengalamanmu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: '  (opsional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _textCtrl,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText:
                      'Tulis ulasanmu di sini... (max 500 karakter)',
                  hintStyle: const TextStyle(
                      color: AppColors.textHint, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'Ulasan bersifat anonim — pedagang tidak tahu siapa yang menulis.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    height: 1.4),
              ),

              const SizedBox(height: 28),
              RkButton(
                label: 'Kirim Ulasan',
                onPressed: _rating > 0 ? _submit : null,
                isLoading: _submitting,
                icon: Icons.send_outlined,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String get _ratingLabel => switch (_rating) {
        1 => '😞  Sangat Buruk',
        2 => '😕  Buruk',
        3 => '😐  Cukup',
        4 => '😊  Bagus',
        5 => '🤩  Sangat Bagus!',
        _ => '',
      };
}
