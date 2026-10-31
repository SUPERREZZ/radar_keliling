import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../config/app_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/menu_model.dart';
import '../../../core/services/merchant_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/rk_button.dart';
import '../../../shared/widgets/rk_snackbar.dart';
import '../../../shared/widgets/rk_text_field.dart';
import '../providers/merchant_profile_provider.dart';

class MerchantMenuScreen extends ConsumerStatefulWidget {
  const MerchantMenuScreen({super.key});

  @override
  ConsumerState<MerchantMenuScreen> createState() => _MerchantMenuScreenState();
}

class _MerchantMenuScreenState extends ConsumerState<MerchantMenuScreen> {
  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  String? _busyMenuId;

  Future<void> _toggleAvailability(MenuItem menu) async {
    if (_busyMenuId != null) return;
    setState(() => _busyMenuId = menu.id);
    try {
      await ref.read(merchantServiceProvider).toggleMenuAvailability(menu.id);
      ref.invalidate(merchantSelfMenusProvider);
    } on ApiException catch (e) {
      if (mounted) showRkSnackbar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showRkSnackbar(context, 'Gagal mengubah status menu.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busyMenuId = null);
    }
  }

  Future<void> _deleteMenu(MenuItem menu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus menu?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Menu "${menu.name}" akan dihapus permanen.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyMenuId = menu.id);
    try {
      await ref.read(merchantServiceProvider).deleteMenu(menu.id);
      ref.invalidate(merchantSelfMenusProvider);
      if (mounted) showRkSnackbar(context, 'Menu berhasil dihapus.');
    } on ApiException catch (e) {
      if (mounted) showRkSnackbar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showRkSnackbar(context, 'Gagal menghapus menu.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busyMenuId = null);
    }
  }

  Future<void> _addPhoto(MenuItem menu) async {
    if (_busyMenuId != null) return;
    if (menu.photos.length >= AppConfig.maxMenuPhotos) {
      showRkSnackbar(
        context,
        'Maksimal ${AppConfig.maxMenuPhotos} foto per menu.',
        isError: true,
      );
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    if (await file.length() > AppConfig.maxPhotoSizeBytes) {
      if (mounted) {
        showRkSnackbar(context, 'Ukuran foto maksimal 2 MB.', isError: true);
      }
      return;
    }

    setState(() => _busyMenuId = menu.id);
    try {
      await ref
          .read(merchantServiceProvider)
          .uploadMenuPhoto(menuId: menu.id, filePath: file.path);
      ref.invalidate(merchantSelfMenusProvider);
      if (mounted) showRkSnackbar(context, 'Foto menu berhasil ditambahkan.');
    } on ApiException catch (e) {
      if (mounted) showRkSnackbar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showRkSnackbar(context, 'Gagal mengunggah foto menu.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busyMenuId = null);
    }
  }

  Future<void> _deletePhoto(MenuItem menu, MenuPhoto photo) async {
    setState(() => _busyMenuId = menu.id);
    try {
      await ref.read(merchantServiceProvider).deleteMenuPhoto(photo.id);
      ref.invalidate(merchantSelfMenusProvider);
    } on ApiException catch (e) {
      if (mounted) showRkSnackbar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showRkSnackbar(context, 'Gagal menghapus foto menu.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busyMenuId = null);
    }
  }

  Future<void> _openForm({MenuItem? menu}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuFormSheet(
        initial: menu,
        onSubmit: (data) => _saveMenu(data, menu),
      ),
    );
  }

  Future<bool> _saveMenu(_MenuFormData data, MenuItem? existing) async {
    try {
      final service = ref.read(merchantServiceProvider);
      final saved = existing == null
          ? await service.addMenu(
              name: data.name,
              description: data.description,
              price: data.price,
              isAvailable: data.isAvailable,
            )
          : await service.updateMenu(
              menuId: existing.id,
              name: data.name,
              description: data.description,
              price: data.price,
              isAvailable: data.isAvailable,
            );

      if (data.photo != null) {
        await service.uploadMenuPhoto(
          menuId: saved.id,
          filePath: data.photo!.path,
        );
      }

      ref.invalidate(merchantSelfMenusProvider);
      if (mounted) {
        showRkSnackbar(
          context,
          existing == null ? 'Menu berhasil ditambahkan.' : 'Menu diperbarui.',
        );
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) showRkSnackbar(context, e.message, isError: true);
      return false;
    } catch (_) {
      if (mounted) {
        showRkSnackbar(context, 'Gagal menyimpan menu.', isError: true);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final menusAsync = ref.watch(merchantSelfMenusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Menu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: menusAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              const Text('Gagal memuat menu'),
              TextButton(
                onPressed: () => ref.invalidate(merchantSelfMenusProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (menus) {
          if (menus.isEmpty) {
            return _EmptyMenus(onAdd: () => _openForm());
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: menus.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final menu = menus[i];
              return _MenuManageCard(
                menu: menu,
                price: _currency.format(menu.price),
                busy: _busyMenuId == menu.id,
                onEdit: () => _openForm(menu: menu),
                onDelete: () => _deleteMenu(menu),
                onToggle: () => _toggleAvailability(menu),
                onAddPhoto: () => _addPhoto(menu),
                onDeletePhoto: (photo) => _deletePhoto(menu, photo),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyMenus extends StatelessWidget {
  const _EmptyMenus({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Menu kamu masih kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan menu dan harga agar pembeli tahu apa yang kamu jual.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 180,
              child: RkButton(
                label: 'Tambah Menu',
                onPressed: onAdd,
                icon: Icons.add_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuManageCard extends StatelessWidget {
  const _MenuManageCard({
    required this.menu,
    required this.price,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onAddPhoto,
    required this.onDeletePhoto,
  });

  final MenuItem menu;
  final String price;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback onAddPhoto;
  final ValueChanged<MenuPhoto> onDeletePhoto;

  @override
  Widget build(BuildContext context) {
    final cover = menu.photos.isNotEmpty ? menu.photos.first.url : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: cover == null
                        ? Container(
                            color: AppColors.primaryLight,
                            child: const Icon(
                              Icons.fastfood_outlined,
                              color: AppColors.primary,
                              size: 30,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: AppConfig.resolveMediaUrl(cover),
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.primaryLight),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.primaryLight,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (menu.description != null &&
                          menu.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          menu.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit menu')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Hapus menu',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.divider),
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  menu.isAvailable ? 'Tersedia' : 'Habis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: menu.isAvailable
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                else
                  Switch.adaptive(
                    value: menu.isAvailable,
                    activeTrackColor: AppColors.primary,
                    onChanged: (_) => onToggle(),
                  ),
              ],
            ),
            if (menu.photos.isNotEmpty) ...[
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: menu.photos.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == menu.photos.length) {
                      return _AddPhotoTile(onTap: onAddPhoto);
                    }
                    final photo = menu.photos[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: AppConfig.resolveMediaUrl(photo.url),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 64,
                              height: 64,
                              color: AppColors.primaryLight,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: AppColors.primaryLight,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 3,
                          right: 3,
                          child: GestureDetector(
                            onTap: busy ? null : () => onDeletePhoto(photo),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : onAddPhoto,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 17,
                  ),
                  label: const Text('Tambah foto menu'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          size: 20,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _MenuFormData {
  const _MenuFormData({
    required this.name,
    required this.description,
    required this.price,
    required this.isAvailable,
    this.photo,
  });

  final String name;
  final String? description;
  final double price;
  final bool isAvailable;
  final File? photo;
}

class _MenuFormSheet extends StatefulWidget {
  const _MenuFormSheet({required this.onSubmit, this.initial});

  final MenuItem? initial;
  final Future<bool> Function(_MenuFormData data) onSubmit;

  @override
  State<_MenuFormSheet> createState() => _MenuFormSheetState();
}

class _MenuFormSheetState extends State<_MenuFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  bool _available = true;
  bool _saving = false;
  File? _photo;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _descCtrl = TextEditingController(text: initial?.description ?? '');
    _priceCtrl = TextEditingController(
      text: initial == null ? '' : initial.price.toInt().toString(),
    );
    _available = initial?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    if (await file.length() > AppConfig.maxPhotoSizeBytes) {
      if (mounted) {
        showRkSnackbar(context, 'Ukuran foto maksimal 2 MB.', isError: true);
      }
      return;
    }
    setState(() => _photo = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    final success = await widget.onSubmit(
      _MenuFormData(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        price: price,
        isAvailable: _available,
        photo: _photo,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                editing ? 'Edit Menu' : 'Tambah Menu',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),
              RkTextField(
                label: 'Nama menu',
                controller: _nameCtrl,
                prefixIcon: Icons.fastfood_outlined,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama menu wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              RkTextField(
                label: 'Deskripsi (opsional)',
                controller: _descCtrl,
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 12),
              RkTextField(
                label: 'Harga',
                hint: 'Contoh: 15000',
                controller: _priceCtrl,
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Harga harus lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Menu tersedia',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Pembeli hanya melihat menu yang tersedia.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                value: _available,
                activeTrackColor: AppColors.primary,
                onChanged: (value) => setState(() => _available = value),
              ),
              if (!editing) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _saving ? null : _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _photo == null
                              ? const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: AppColors.primary,
                                  size: 22,
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(_photo!, fit: BoxFit.cover),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _photo == null
                                    ? 'Tambah foto menu'
                                    : 'Foto dipilih',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Opsional, maksimal 2 MB.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_photo != null)
                          IconButton(
                            onPressed: () => setState(() => _photo = null),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              RkButton(
                label: editing ? 'Simpan Perubahan' : 'Tambah Menu',
                onPressed: _saving ? null : _submit,
                isLoading: _saving,
                icon: Icons.check_rounded,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
