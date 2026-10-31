import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/merchant_model.dart';
import '../models/menu_model.dart';

final merchantServiceProvider = Provider<MerchantService>(
  (ref) => MerchantService(ref.read(apiClientProvider)),
);

class MerchantService {
  MerchantService(this._api);
  final DioClient _api;

  // ── Self profile ─────────────────────────────────────────

  Future<MerchantSelfProfile> getSelfProfile() async {
    final res = await _api.get(Endpoints.merchantProfile);
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return MerchantSelfProfile.fromJson(data);
  }

  Future<MerchantSelfProfile> updateProfile({
    required String businessName,
    String? description,
  }) async {
    final res = await _api.put(Endpoints.merchantProfile, data: {
      'business_name': businessName,
      if (description != null) 'description': description,
    });
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return MerchantSelfProfile.fromJson(data);
  }

  Future<String> uploadProfilePhoto(String filePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: 'profile.jpg'),
    });
    final res = await _api.post(
      Endpoints.merchantProfilePhoto,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return data['profile_photo_url'] as String;
  }

  // ── Selling status ────────────────────────────────────────

  Future<void> startSelling() async {
    await _api.post(Endpoints.sellingStart);
  }

  Future<void> stopSelling() async {
    await _api.post(Endpoints.sellingStop);
  }

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracyM,
    required String recordedAt,
  }) async {
    await _api.put(Endpoints.merchantLocation, data: {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'recorded_at': recordedAt,
    });
  }

  // ── Public profile (buyer) ────────────────────────────────

  Future<MerchantProfile> getPublicProfile(String merchantId) async {
    final res = await _api.get(Endpoints.merchantPublicProfile(merchantId));
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return MerchantProfile.fromJson(data);
  }

  Future<List<MenuItem>> getMenus(String merchantId) async {
    final res = await _api.get(Endpoints.merchantMenusPublic(merchantId));
    final list = (res.data as Map)['data'] as List;
    return list
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MerchantRating> getRating(String merchantId) async {
    final res = await _api.get(Endpoints.merchantRating(merchantId));
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return MerchantRating.fromJson(data);
  }

  // ── Menu CRUD ─────────────────────────────────────────────

  Future<MenuItem> addMenu({
    required String name,
    String? description,
    required double price,
  }) async {
    final res = await _api.post(Endpoints.merchantMenus, data: {
      'name': name,
      if (description != null) 'description': description,
      'price': price,
    });
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return MenuItem.fromJson(data);
  }

  Future<MenuItem> updateMenu({
    required String menuId,
    required String name,
    String? description,
    required double price,
    required bool isAvailable,
  }) async {
    final res = await _api.put(Endpoints.merchantMenuById(menuId), data: {
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      'is_available': isAvailable,
    });
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return MenuItem.fromJson(data);
  }

  Future<void> deleteMenu(String menuId) async {
    await _api.delete(Endpoints.merchantMenuById(menuId));
  }

  Future<MenuPhoto> uploadMenuPhoto({
    required String menuId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: 'menu.jpg'),
    });
    final res = await _api.post(
      Endpoints.merchantMenuPhotos(menuId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return MenuPhoto.fromJson(data);
  }

  Future<void> deleteMenuPhoto(String photoId) async {
    await _api.delete(Endpoints.deleteMenuPhoto(photoId));
  }
}
