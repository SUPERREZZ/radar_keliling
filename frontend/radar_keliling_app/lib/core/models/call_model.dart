class CallModel {
  const CallModel({
    required this.id,
    required this.buyerId,
    required this.merchantId,
    required this.status,
    required this.locationConsent,
    required this.createdAt,
    required this.hasReview,
  });

  final String id;
  final String buyerId;
  final String merchantId;
  final String status; // pending | accept | unanswered | cancelled | expired
  final bool locationConsent;
  final String createdAt;
  final bool hasReview;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accept';
  bool get canReview => isAccepted && !hasReview;

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
        id: json['id'] as String,
        buyerId: json['buyer_id'] as String,
        merchantId: json['merchant_id'] as String,
        status: json['status'] as String,
        locationConsent: json['location_consent'] as bool? ?? false,
        createdAt: json['created_at'] as String,
        hasReview: json['has_review'] as bool? ?? false,
      );
}
