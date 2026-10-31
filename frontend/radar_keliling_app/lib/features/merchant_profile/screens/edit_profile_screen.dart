import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/merchant_service.dart';
import '../providers/merchant_profile_provider.dart';
import '../../../shared/widgets/rk_button.dart';
import '../../../shared/widgets/rk_text_field.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../../shared/theme/app_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingPhoto = false;
  File? _selectedPhoto;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    final size = await file.length();
    if (size > AppConfig.maxPhotoSizeBytes) {
      if (!mounted) return;
      showRkSnackbar(context, 'Ukuran foto maksimal 2 MB.', isError: true);
      return;
    }
    setState(() => _selectedPhoto = file);
  }

  Future<void> _uploadPhoto() async {
    if (_selectedPhoto == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      await ref
          .read(merchantServiceProvider)
          .uploadProfilePhoto(_selectedPhoto!.path);
      if (!mounted) return;
      showRkSnackbar(context, 'Foto profil berhasil diperbarui.');
      ref.invalidate(merchantSelfProfileProvider);
      setState(() => _selectedPhoto = null);
    } on ApiException catch (e) {
      if (!mounted) return;
      showRkSnackbar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(merchantServiceProvider).updateProfile(
            businessName: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(merchantSelfProfileProvider);
      showRkSnackbar(context, 'Profil berhasil diperbarui.');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showRkSnackbar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(merchantSelfProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) =>
            const Center(child: Text('Gagal memuat profil')),
        data: (profile) {
          // Prefill saat pertama load
          if (_nameCtrl.text.isEmpty) {
            _nameCtrl.text = profile.businessName;
            _descCtrl.text = profile.description ?? '';
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Foto profil ───────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: _selectedPhoto != null
                              ? FileImage(_selectedPhoto!) as ImageProvider
                              : (profile.profilePhotoUrl != null
                                  ? NetworkImage(profile.profilePhotoUrl!)
                                  : null),
                          child: (_selectedPhoto == null &&
                                  profile.profilePhotoUrl == null)
                              ? const Icon(Icons.storefront,
                                  size: 36, color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedPhoto != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(
                        width: 160,
                        child: RkButton(
                          label: 'Upload Foto',
                          onPressed: _uploadPhoto,
                          isLoading: _uploadingPhoto,
                          icon: Icons.cloud_upload_outlined,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // ── Form ──────────────────────────────────
                  const Text(
                    'Nama Usaha',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  RkTextField(
                    label: 'Nama Usaha',
                    controller: _nameCtrl,
                    prefixIcon: Icons.storefront_outlined,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Nama usaha wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Deskripsi',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  RkTextField(
                    label: 'Deskripsi singkat usaha',
                    controller: _descCtrl,
                    prefixIcon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  RkButton(
                    label: 'Simpan Perubahan',
                    onPressed: _save,
                    isLoading: _saving,
                    icon: Icons.save_outlined,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
