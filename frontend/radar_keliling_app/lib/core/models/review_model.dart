class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.rating,
    this.callId,
    this.reviewText,
    this.buyerName,
    this.createdAt,
  });

  final String id;
  final int rating;
  final String? callId;
  final String? reviewText;
  final String? buyerName;
  final String? createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: (json['id'] ?? '').toString(),
    rating: (json['rating'] as num?)?.toInt() ?? 5,
    callId: json['call_id']?.toString(),
    reviewText: json['review_text'] as String?,
    buyerName: json['buyer_name'] as String? ?? 'Pembeli',
    createdAt: json['created_at'] as String?,
  );
}

class ReviewReportModel {
  const ReviewReportModel({
    required this.id,
    required this.reviewId,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reviewId;
  final String reporterId;
  final String reason;
  final String status;
  final String createdAt;

  factory ReviewReportModel.fromJson(Map<String, dynamic> json) =>
      ReviewReportModel(
        id: (json['id'] ?? '').toString(),
        reviewId: (json['review_id'] ?? '').toString(),
        reporterId: (json['reporter_id'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
        status: (json['status'] ?? 'pending').toString(),
        createdAt: (json['created_at'] ?? '').toString(),
      );
}
