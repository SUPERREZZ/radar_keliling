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
  final String status; // pending | reviewed | resolved
  final String createdAt;

  factory ReviewReportModel.fromJson(Map<String, dynamic> json) =>
      ReviewReportModel(
        id: json['id'] as String,
        reviewId: json['review_id'] as String,
        reporterId: json['reporter_id'] as String,
        reason: json['reason'] as String,
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
      );
}
