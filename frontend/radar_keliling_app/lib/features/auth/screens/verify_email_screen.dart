import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/rk_button.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../../shared/theme/app_theme.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.token});
  final String email;
  final String? token; // Token dari deep link

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  bool _resending = false;
  bool _resentSuccess = false;
  bool _showManualInput = false;
  bool _verifying = false;
  final _tokenCtrl = TextEditingController();

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
    
    // Auto-verify if token is provided from deep link
    if (widget.token != null && widget.token!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoVerify(widget.token!);
      });
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authServiceProvider).resendVerification();
      if (!mounted) return;
      setState(() => _resentSuccess = true);
      showRkSnackbar(context, 'Email verifikasi telah dikirim ulang.');
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(context, 'Gagal mengirim ulang. Coba beberapa saat lagi.',
          isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _autoVerify(String token) async {
    setState(() => _verifying = true);
    try {
      await ref.read(authServiceProvider).verifyEmail(token);
      if (!mounted) return;
      showRkSnackbar(context, '✅ Email berhasil diverifikasi! Silakan login.');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      // Auto-verify failed, show manual input
      setState(() => _showManualInput = true);
      showRkSnackbar(
        context,
        'Verifikasi otomatis gagal. Silakan masukkan token manual.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _verifyManual() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      showRkSnackbar(context, 'Token tidak boleh kosong', isError: true);
      return;
    }

    setState(() => _verifying = true);
    try {
      await ref.read(authServiceProvider).verifyEmail(token);
      if (!mounted) return;
      showRkSnackbar(context, '✅ Email berhasil diverifikasi! Silakan login.');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      showRkSnackbar(
        context,
        'Verifikasi gagal. Token mungkin salah atau sudah kedaluwarsa.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading during auto-verify
    if (_verifying && widget.token != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Memverifikasi email...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: _bounceAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _bounceAnim.value),
                  child: child,
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 38, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Cek email kamu',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Kami mengirim tautan verifikasi ke\n${widget.email}',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tautan berlaku selama 60 menit.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint),
              ),
              const Spacer(),
              
              // Manual token input section
              if (_showManualInput) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Masukkan Token Verifikasi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tokenCtrl,
                        decoration: InputDecoration(
                          hintText: 'Paste token dari email',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RkButton(
                              label: 'Verifikasi',
                              onPressed: _verifyManual,
                              isLoading: _verifying,
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => setState(() => _showManualInput = false),
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                            tooltip: 'Tutup',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Show manual input button if not showing
              if (!_showManualInput)
                TextButton.icon(
                  onPressed: () => setState(() => _showManualInput = true),
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  label: const Text('Punya token verifikasi? Masukkan manual'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              const SizedBox(height: 8),
              if (!_resentSuccess)
                RkButton(
                  label: 'Kirim Ulang Email',
                  onPressed: _resend,
                  isLoading: _resending,
                  outlined: true,
                  icon: Icons.refresh,
                ),
              if (_resentSuccess)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success, size: 18),
                      SizedBox(width: 8),
                      Text('Email dikirim ulang',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(
                  'Kembali ke halaman masuk',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
