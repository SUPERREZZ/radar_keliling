import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/review_model.dart';

final adminReportsProvider =
    FutureProvider<List<ReviewReportModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get(Endpoints.adminReviewReports);
  final list = (res.data as Map)['data'] as List;
  return list
      .map((e) => ReviewReportModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
