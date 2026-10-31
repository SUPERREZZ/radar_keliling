import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/merchant_model.dart';
import '../../../core/models/menu_model.dart';
import '../../../core/services/merchant_service.dart';

final merchantPublicProfileProvider =
    FutureProvider.family<MerchantProfile, String>((ref, merchantId) {
  return ref.read(merchantServiceProvider).getPublicProfile(merchantId);
});

final merchantMenusProvider =
    FutureProvider.family<List<MenuItem>, String>((ref, merchantId) {
  return ref.read(merchantServiceProvider).getMenus(merchantId);
});

final merchantSelfProfileProvider =
    FutureProvider<MerchantSelfProfile>((ref) {
  return ref.read(merchantServiceProvider).getSelfProfile();
});
