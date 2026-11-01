import '../../config/app_config.dart';

class MerchantRadarItem {
  const MerchantRadarItem({
    required this.merchantId,
    required this.businessName,
    required this.latitude,
    required this.longitude,
    required this.distanceM,
    required this.gpsAccuracyM,
    required this.lastUpdatedAt,
    required this.isSelling,
    this.profilePhotoUrl,
  });

  final String merchantId;
  final String businessName;
  final double latitude;
  final double longitude;
  final double distanceM;
  final double gpsAccuracyM;
  final String lastUpdatedAt; // ISO 8601
  final bool isSelling;
  final String? profilePhotoUrl;

  /// True jika lokasi masih segar sesuai ambang batas di AppConfig.
  bool get isLocationFresh {
    try {
      final updated = DateTime.parse(lastUpdatedAt);
      return DateTime.now().toUtc().difference(updated).inSeconds <=
          AppConfig.locationStaleThresholdSeconds;
    } catch (_) {
      return false;
    }
  }

  factory MerchantRadarItem.fromJson(Map<String, dynamic> json) =>
      MerchantRadarItem(
        merchantId: json['merchant_id'] as String,
        businessName: json['business_name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceM: (json['distance_m'] as num).toDouble(),
        gpsAccuracyM: (json['gps_accuracy_m'] as num).toDouble(),
        lastUpdatedAt: json['last_updated_at'] as String,
        isSelling: json['is_selling'] as bool,
        profilePhotoUrl: json['profile_photo_url'] as String?,
      );

  MerchantRadarItem copyWith({
    double? latitude,
    double? longitude,
    double? distanceM,
    double? gpsAccuracyM,
    String? lastUpdatedAt,
    bool? isSelling,
    String? profilePhotoUrl,
  }) => MerchantRadarItem(
    merchantId: merchantId,
    businessName: businessName,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    distanceM: distanceM ?? this.distanceM,
    gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    isSelling: isSelling ?? this.isSelling,
    profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
  );
}

class MerchantProfile {
  const MerchantProfile({
    required this.merchantId,
    required this.businessName,
    this.description,
    this.profilePhotoUrl,
    required this.averageRating,
    required this.totalReviews,
    required this.isSelling,
  });

  final String merchantId;
  final String businessName;
  final String? description;
  final String? profilePhotoUrl;
  final double averageRating;
  final int totalReviews;
  final bool isSelling;

  factory MerchantProfile.fromJson(Map<String, dynamic> json) {
    // endpoint radar pakai merchant_id, profil publik bisa pakai id
    final id = (json['merchant_id'] ?? json['id']) as String;
    return MerchantProfile(
      merchantId: id,
      businessName: json['business_name'] as String,
      description: json['description'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['total_reviews'] as int?) ?? 0,
      isSelling: json['is_selling'] as bool? ?? false,
    );
  }
}

class MerchantSelfProfile {
  const MerchantSelfProfile({
    required this.id,
    required this.userId,
    required this.businessName,
    this.description,
    this.profilePhotoUrl,
    required this.isSelling,
  });

  final String id;
  final String userId;
  final String businessName;
  final String? description;
  final String? profilePhotoUrl;
  final bool isSelling;

  factory MerchantSelfProfile.fromJson(Map<String, dynamic> json) =>
      MerchantSelfProfile(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        businessName: json['business_name'] as String,
        description: json['description'] as String?,
        profilePhotoUrl: json['profile_photo_url'] as String?,
        isSelling: json['is_selling'] as bool,
      );
}

class MerchantRating {
  const MerchantRating({
    required this.merchantId,
    required this.averageRating,
    required this.totalReviews,
  });

  final String merchantId;
  final double averageRating;
  final int totalReviews;

  factory MerchantRating.fromJson(Map<String, dynamic> json) => MerchantRating(
    merchantId: json['merchant_id'] as String,
    averageRating: (json['average_rating'] as num).toDouble(),
    totalReviews: json['total_reviews'] as int,
  );
}
