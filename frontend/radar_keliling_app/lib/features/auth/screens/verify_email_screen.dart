import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/rk_button.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../../shared/theme/app_theme.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.token,
    this.password,
  });

  final String email;
  final String? token; // Token dari deep link

  /// Disimpan hanya di memori untuk mengecek status verifikasi
  /// lewat login ulang. Tidak pernah dimasukkan ke URL / storage.
  final String? password;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _resending = false;
  bool _resentSuccess = false;
  bool _showManualInput = false;
  bool _verifying = false;
  bool _checking = false;
  Timer? _statusTimer;
  final _tokenCtrl = TextEditingController();

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  bool get _canCheckStatus =>
      widget.email.trim().isNotEmpty && (widget.password?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));

    // Auto-verify if token is provided from deep link
    if (widget.token != null && widget.token!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoVerify(widget.token!);
      });
    }

    // Cek status otomatis tiap 15 detik selama halaman ini terbuka.
    // Berguna saat verifikasi dilakukan dari perangkat lain (mis. laptop).
    if (_canCheckStatus) {
      _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _checkVerificationStatus(silent: true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerificationStatus(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _bounceCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _goToLogin() {
    final email = widget.email.trim();
    if (email.isEmpty) {
      context.go('/login');
      return;
    }
    context.go('/login?email=${Uri.encodeComponent(email)}');
  }

  bool _looksAlreadyVerified(String text) {
    final lower = text.toLowerCase();
    return lower.contains('already_verified') ||
        lower.contains('already verified') ||
        lower.contains('sudah diverifikasi') ||
        lower.contains('sudah di verifikasi') ||
        lower.contains('sudah terverifikasi') ||
        lower.contains('telah diverifikasi') ||
        lower.contains('telah di verifikasi');
  }

  bool _isAlreadyVerified(ApiException e) =>
      _looksAlreadyVerified('${e.code} ${e.message}');

  /// Mengecek apakah email sudah diverifikasi dengan mencoba login ulang.
  /// Jika berhasil, sesi disimpan dan user langsung masuk ke dashboard.
  Future<bool> _checkVerificationStatus({
    bool silent = false,
    String successMessage = 'Email sudah terverifikasi. Selamat datang!',
  }) async {
    if (!mounted || _checking) return false;

    final email = widget.email.trim();
    final password = widget.password;
    if (email.isEmpty || password == null || password.isEmpty) {
      if (!silent) {
        showRkSnackbar(context, 'Silakan masuk untuk melanjutkan.');
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _goToLogin();
      }
      return false;
    }

    setState(() => _checking = true);
    try {
      final user = await ref
          .read(authServiceProvider)
          .login(email: email, password: password);
      if (!mounted) return false;

      _statusTimer?.cancel();
      ref.read(authProvider.notifier).setUser(user);
      showRkSnackbar(context, successMessage);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return true;
      context.go(user.homeRoute);
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;

      final text = e.message.toLowerCase();
      final notVerified =
          e.code == 'EMAIL_NOT_VERIFIED' || text.contains('belum diverifikasi');

      if (notVerified) {
        if (!silent) {
          showRkSnackbar(
            context,
            'Email belum terverifikasi. Cek inbox kamu atau kirim ulang email.',
          );
        }
      } else if (e.code == 'INVALID_CREDENTIALS') {
        _statusTimer?.cancel();
        if (!silent) {
          showRkSnackbar(
            context,
            'Sesi login tidak valid. Silakan masuk ulang.',
            isError: true,
          );
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) _goToLogin();
        }
      } else {
        if (!silent) showRkSnackbar(context, e.message, isError: true);
      }
      return false;
    } catch (_) {
      if (!mounted) return false;
      if (!silent) {
        showRkSnackbar(
          context,
          'Gagal mengecek status. Periksa koneksi internet kamu.',
          isError: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _finishVerification({
    String successMessage = 'Email berhasil diverifikasi. Selamat datang!',
  }) async {
    if (_canCheckStatus) {
      final loggedIn = await _checkVerificationStatus(
        successMessage: successMessage,
      );
      if (loggedIn) return;
    }

    if (!mounted) return;
    showRkSnackbar(context, 'Email berhasil diverifikasi. Silakan masuk.');
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    _goToLogin();
  }

  Future<void> _resend() async {
    final email = widget.email.trim();
    if (email.isEmpty) {
      showRkSnackbar(
        context,
        'Email tidak diketahui. Silakan kembali dan masuk ulang.',
        isError: true,
      );
      return;
    }

    setState(() => _resending = true);
    try {
      final message = await ref
          .read(authServiceProvider)
          .resendVerification(email: email);
      if (!mounted) return;

      if (message != null && _looksAlreadyVerified(message)) {
        setState(() => _resending = false);
        await _finishVerification(
          successMessage: 'Email ini sudah terverifikasi. Selamat datang!',
        );
        return;
      }

      setState(() => _resentSuccess = true);
      showRkSnackbar(context, 'Email verifikasi telah dikirim ulang.');
    } on ApiException catch (e) {
      if (!mounted) return;

      // Kalau ternyata email sudah diverifikasi (mis. lewat link di laptop),
      // anggap sukses dan langsung cek status / login.
      if (_isAlreadyVerified(e)) {
        setState(() => _resending = false);
        await _finishVerification(
          successMessage: 'Email ini sudah terverifikasi. Selamat datang!',
        );
        return;
      }

      showRkSnackbar(context, e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      showRkSnackbar(
        context,
        'Gagal mengirim ulang. Coba beberapa saat lagi.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _autoVerify(String token) async {
    setState(() => _verifying = true);
    try {
      await ref.read(authServiceProvider).verifyEmail(token);
      if (!mounted) return;
      await _finishVerification();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _showManualInput = true);
      showRkSnackbar(
        context,
        'Verifikasi otomatis gagal: ${e.message}',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
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
      await _finishVerification();
    } on ApiException catch (e) {
      if (!mounted) return;

      final text = e.message.toLowerCase();
      final expired = text.contains('kedaluwarsa') || text.contains('expired');
      showRkSnackbar(
        context,
        expired
            ? 'Token sudah kedaluwarsa. Klik "Cek Status Verifikasi" jika '
                  'sudah verifikasi dari perangkat lain, atau kirim ulang email.'
            : e.message,
        isError: true,
      );
    } catch (_) {
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
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _goToLogin,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: 'Kembali ke halaman masuk',
        ),
        actions: [
          IconButton(
            onPressed: _checking ? null : () => _checkVerificationStatus(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Cek status verifikasi',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
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
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 38,
                    color: AppColors.primary,
                  ),
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
                'Kami mengirim tautan verifikasi ke\n'
                '${widget.email.trim().isEmpty ? "email kamu" : widget.email}',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tautan berlaku 60 menit dan hanya bisa dipakai sekali.',
                style: TextStyle(fontSize: 13, color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const Text(
                'Sudah verifikasi dari perangkat lain?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              RkButton(
                label: 'Cek Status Verifikasi',
                onPressed: _checking ? null : () => _checkVerificationStatus(),
                isLoading: _checking,
                icon: Icons.sync,
              ),
              if (_canCheckStatus) ...[
                const SizedBox(height: 6),
                const Text(
                  'Status dicek otomatis setiap 15 detik.',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
              const SizedBox(height: 12),

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
                            onPressed: () =>
                                setState(() => _showManualInput = false),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Email dikirim ulang',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _goToLogin,
                child: const Text(
                  'Kembali ke halaman masuk',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
