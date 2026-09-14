import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../loyalty_exception.dart';
import '../models/loyalty.dart';
import '../models/page.dart';

/// Wraps backend's customer-facing Loyalty surface
/// (backend/loyalty/.../LoyaltyController.java) -- "my rewards" across every
/// business, one business's own loyalty page and reward catalog, this
/// customer's own points history and redemptions. Every call is scoped to
/// the caller's own identity by the server (via the bearer token DioClient
/// already attaches); there's no userId parameter to pass here, unlike
/// FavoritesApi/ReviewsApi which take one explicitly for their own
/// user-scoped paths.
///
/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio -- same pattern as the other feature APIs.
class LoyaltyApi {
  final DioClient _dioClient;

  LoyaltyApi(this._dioClient);

  Future<List<LoyaltyBusinessSummary>> myLoyalty() async {
    final response = await _dioClient.get('/loyalty');
    final data = response.data as List<dynamic>;
    return data.map((e) => LoyaltyBusinessSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Works even for a business the caller has never booked with (an
  /// all-zero, [LoyaltyBusinessDetail.programEnabled] false response) --
  /// never a 404, so no try/catch here unlike [FavoritesApi.isFavorited].
  Future<LoyaltyBusinessDetail> businessLoyalty(String providerId) async {
    final response = await _dioClient.get('/loyalty/businesses/$providerId');
    return LoyaltyBusinessDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// Empty if the business has no enabled program, or none of its rewards
  /// are currently active -- an empty list, never an error.
  Future<List<LoyaltyReward>> rewards(String providerId) async {
    final response = await _dioClient.get('/loyalty/businesses/$providerId/rewards');
    final data = response.data as List<dynamic>;
    return data.map((e) => LoyaltyReward.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Page<LoyaltyTransaction>> history(String providerId, {int page = 0, int size = 20}) async {
    final response = await _dioClient.get(
      '/loyalty/businesses/$providerId/history',
      queryParameters: {'page': page, 'size': size},
    );
    return Page<LoyaltyTransaction>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => LoyaltyTransaction.fromJson(e),
    );
  }

  /// A 409 means the program's disabled, the reward isn't currently
  /// redeemable, or the balance is insufficient -- surfaced as a
  /// [LoyaltyException] carrying the server's own message so the UI can
  /// show a specific, actionable notice instead of a crash. The
  /// insufficient-points case should already be prevented client-side by
  /// disabling the button when [LoyaltyReward.affordable] is false; this is
  /// defense-in-depth against a race (balance spent elsewhere between the
  /// fetch and the tap).
  Future<LoyaltyRedemption> redeem(String rewardId) async {
    try {
      final response = await _dioClient.post('/loyalty/rewards/$rewardId/redeem');
      return LoyaltyRedemption.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw LoyaltyException(_extractMessage(e));
      }
      rethrow;
    }
  }

  Future<Page<LoyaltyRedemption>> myRedemptions({int page = 0, int size = 20}) async {
    final response = await _dioClient.get(
      '/loyalty/redemptions',
      queryParameters: {'page': page, 'size': size},
    );
    return Page<LoyaltyRedemption>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => LoyaltyRedemption.fromJson(e),
    );
  }

  Future<LoyaltyRedemption> getRedemption(String id) async {
    final response = await _dioClient.get('/loyalty/redemptions/$id');
    return LoyaltyRedemption.fromJson(response.data as Map<String, dynamic>);
  }

  /// A 409 means it's no longer ACTIVE (already applied by the business, or
  /// already cancelled/expired) -- same [LoyaltyException] treatment as
  /// [redeem].
  Future<LoyaltyRedemption> cancelRedemption(String id, {String? reason}) async {
    try {
      final response = await _dioClient.post(
        '/loyalty/redemptions/$id/cancel',
        data: {'reason': reason},
      );
      return LoyaltyRedemption.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw LoyaltyException(_extractMessage(e));
      }
      rethrow;
    }
  }

  /// Pulls `message` out of the standard `ApiError` body
  /// (platform-api's ApiError.java) a 4xx response carries -- null if the
  /// body doesn't parse as expected, so callers always have a safe
  /// localized fallback to reach for (see [LoyaltyException.localizedMessage]).
  String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
