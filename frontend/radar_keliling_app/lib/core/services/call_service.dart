import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/call_model.dart';

final callServiceProvider = Provider<CallService>(
  (ref) => CallService(ref.read(apiClientProvider)),
);

class CallService {
  CallService(this._api);
  final DioClient _api;

  Future<CallModel> createCall({
    required String merchantId,
    required bool shareLocation,
    required double buyerLatitude,
    required double buyerLongitude,
    required double gpsAccuracyM,
  }) async {
    final res = await _api.post(
      Endpoints.calls,
      data: {
        'merchant_id': merchantId,
        'share_location': shareLocation,
        'buyer_latitude': buyerLatitude,
        'buyer_longitude': buyerLongitude,
        'gps_accuracy_m': gpsAccuracyM,
      },
    );
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    // Backend response untuk create call pakai 'call_id', bukan 'id'
    if (!data.containsKey('id') && data.containsKey('call_id')) {
      data['id'] = data['call_id'];
    }
    return CallModel.fromJson(data);
  }

  Future<List<CallModel>> getCalls() async {
    final res = await _api.get(Endpoints.calls);
    final list = (res.data as Map)['data'] as List;
    return list
        .map((e) => CallModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CallModel> getCallById(String id) async {
    final res = await _api.get(Endpoints.callById(id));
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return CallModel.fromJson(data);
  }

  Future<CallModel> cancelCall(String id) async {
    final res = await _api.post(Endpoints.callCancel(id));
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return CallModel.fromJson(data);
  }

  // Merchant actions
  Future<CallModel> acceptCall(String id) async {
    final res = await _api.post(Endpoints.callAnswer(id));
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return CallModel.fromJson(data);
  }

  Future<CallModel> markUnanswered(String id) async {
    final res = await _api.post(Endpoints.callUnanswered(id));
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return CallModel.fromJson(data);
  }

  Future<void> submitReview({
    required String callId,
    required int rating,
    String? reviewText,
  }) async {
    await _api.post(
      Endpoints.callReview(callId),
      data: {
        'rating': rating,
        if (reviewText != null && reviewText.isNotEmpty)
          'review_text': reviewText,
      },
    );
  }

  Future<void> reportReview({
    required String reviewId,
    required String reason,
  }) async {
    await _api.post(Endpoints.reviewReport(reviewId), data: {'reason': reason});
  }
}
