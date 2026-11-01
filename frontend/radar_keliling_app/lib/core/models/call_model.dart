class CallModel {
  const CallModel({
    required this.id,
    required this.buyerId,
    required this.merchantId,
    required this.status,
    required this.locationConsent,
    required this.createdAt,
    required this.hasReview,
    this.buyerLatitude,
    this.buyerLongitude,
    this.distanceM,
  });

  final String id;
  final String buyerId;
  final String merchantId;
  final String
  status; // pending | accept | completed | unanswered | cancelled | expired
  final bool locationConsent;
  final String createdAt;
  final bool hasReview;
  final double? buyerLatitude;
  final double? buyerLongitude;
  final double? distanceM;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accept' || status == 'completed';
  bool get isCompleted => status == 'completed';
  bool get canReview => isAccepted && !hasReview;

  bool get hasBuyerCoordinates =>
      buyerLatitude != null &&
      buyerLongitude != null &&
      buyerLatitude != 0 &&
      buyerLongitude != 0;

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String && val.trim().isNotEmpty) return double.tryParse(val.trim());
    return null;
  }

  static bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) {
      final lower = val.toLowerCase().trim();
      return lower == 'true' || lower == '1';
    }
    if (val is num) return val != 0;
    return false;
  }

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
    id: (json['id'] ?? json['call_id'] ?? '').toString(),
    buyerId: (json['buyer_id'] ?? '').toString(),
    merchantId: (json['merchant_id'] ?? '').toString(),
    status: (json['status'] ?? 'pending').toString(),
    locationConsent: _parseBool(json['location_consent'] ?? json['location_shared']),
    createdAt: (json['created_at'] ?? DateTime.now().toIso8601String()).toString(),
    hasReview: _parseBool(json['has_review']),
    buyerLatitude: _parseDouble(json['buyer_latitude']),
    buyerLongitude: _parseDouble(json['buyer_longitude']),
    distanceM: _parseDouble(json['distance_m']),
  );

  CallModel copyWith({
    String? id,
    String? buyerId,
    String? merchantId,
    String? status,
    bool? locationConsent,
    String? createdAt,
    bool? hasReview,
    double? buyerLatitude,
    double? buyerLongitude,
    double? distanceM,
  }) => CallModel(
    id: id ?? this.id,
    buyerId: buyerId ?? this.buyerId,
    merchantId: merchantId ?? this.merchantId,
    status: status ?? this.status,
    locationConsent: locationConsent ?? this.locationConsent,
    createdAt: createdAt ?? this.createdAt,
    hasReview: hasReview ?? this.hasReview,
    buyerLatitude: buyerLatitude ?? this.buyerLatitude,
    buyerLongitude: buyerLongitude ?? this.buyerLongitude,
    distanceM: distanceM ?? this.distanceM,
  );
}
