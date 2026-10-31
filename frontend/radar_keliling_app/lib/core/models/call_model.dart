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

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
    id: (json['id'] ?? json['call_id'] ?? '') as String,
    buyerId: (json['buyer_id'] ?? '') as String,
    merchantId: (json['merchant_id'] ?? '') as String,
    status: (json['status'] ?? 'pending') as String,
    locationConsent:
        (json['location_consent'] ?? json['location_shared']) as bool? ?? false,
    createdAt:
        (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
    hasReview: json['has_review'] as bool? ?? false,
    buyerLatitude: (json['buyer_latitude'] as num?)?.toDouble(),
    buyerLongitude: (json['buyer_longitude'] as num?)?.toDouble(),
    distanceM: (json['distance_m'] as num?)?.toDouble(),
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
