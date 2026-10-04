import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../loyalty_admin_exception.dart';
import '../models/loyalty_birthday.dart';
import '../models/loyalty_customer.dart';
import '../models/loyalty_milestone.dart';
import '../models/loyalty_overview.dart';
import '../models/loyalty_page.dart';
import '../models/loyalty_redemption.dart';
import '../models/loyalty_reward.dart';
import '../models/loyalty_settings.dart';
import '../models/loyalty_tier.dart';
import '../models/loyalty_transaction.dart';

/// Wraps the business-admin Loyalty REST surface
/// (backend/loyalty/.../LoyaltyAdminController) from the owner's point of
/// view -- every endpoint is owner-only, scoped under a provider the caller
/// owns. Not final: tests substitute a subclass, same pattern as
/// [CampaignCenterApi]/`SalonAdminApi`. Paths never repeat the `/api/v1`
/// prefix -- [DioClient]'s base URL already includes it.
class LoyaltyAdminApi {
  final DioClient _dioClient;

  LoyaltyAdminApi(this._dioClient);

  // ---- Settings ----

  Future<LoyaltySettings> fetchSettings(String providerId) => _run(() async {
        final response = await _dioClient.get('/business/$providerId/loyalty/settings');
        return LoyaltySettings.fromJson(response.data as Map<String, dynamic>);
      });

  Future<LoyaltySettings> updateSettings(String providerId, LoyaltySettings settings) => _run(() async {
        final response =
            await _dioClient.put('/business/$providerId/loyalty/settings', data: settings.toUpdateJson());
        return LoyaltySettings.fromJson(response.data as Map<String, dynamic>);
      });

  // ---- Birthdays ----

  /// Opted-in members whose birthday is within the next [days] days, soonest first.
  Future<List<LoyaltyBirthday>> fetchBirthdays(String providerId, {int days = 30}) => _run(() async {
        final response = await _dioClient.get(
          '/business/$providerId/loyalty/birthdays',
          queryParameters: {'days': days},
        );
        return (response.data as List<dynamic>)
            .map((e) => LoyaltyBirthday.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Greets a member by hand: an optional personal [message] and an optional
  /// gift of [bonusPoints] (0-1000). Backend: 409 if the member didn't agree to
  /// greetings, was already greeted today, or points are requested while the
  /// program is off.
  Future<void> sendGreeting(String providerId, String userId, {String? message, int? bonusPoints}) => _run(() async {
        await _dioClient.post(
          '/business/$providerId/loyalty/customers/$userId/greet',
          data: {'message': message, 'bonusPoints': bonusPoints},
        );
      });

  // ---- Milestones ----

  Future<List<LoyaltyMilestone>> fetchMilestones(String providerId) => _run(() async {
        final response = await _dioClient.get('/business/$providerId/loyalty/milestones');
        return (response.data as List<dynamic>)
            .map((e) => LoyaltyMilestone.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<List<LoyaltyMilestone>> replaceMilestones(String providerId, List<LoyaltyMilestone> milestones) =>
      _run(() async {
        final response = await _dioClient.put(
          '/business/$providerId/loyalty/milestones',
          data: {'milestones': milestones.map((m) => m.toRequestJson()).toList()},
        );
        return (response.data as List<dynamic>)
            .map((e) => LoyaltyMilestone.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  // ---- Tiers ----

  Future<List<LoyaltyTier>> fetchTiers(String providerId) => _run(() async {
        final response = await _dioClient.get('/business/$providerId/loyalty/tiers');
        return (response.data as List<dynamic>).map((e) => LoyaltyTier.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<List<LoyaltyTier>> replaceTiers(String providerId, List<LoyaltyTier> tiers) => _run(() async {
        final response = await _dioClient.put(
          '/business/$providerId/loyalty/tiers',
          data: {'tiers': tiers.map((t) => t.toRequestJson()).toList()},
        );
        return (response.data as List<dynamic>).map((e) => LoyaltyTier.fromJson(e as Map<String, dynamic>)).toList();
      });

  // ---- Dashboard ----

  Future<LoyaltyOverview> fetchOverview(String providerId) => _run(() async {
        final response = await _dioClient.get('/business/$providerId/loyalty/overview');
        return LoyaltyOverview.fromJson(response.data as Map<String, dynamic>);
      });

  // ---- Customers ----

  Future<LoyaltyPage<LoyaltyCustomerInsight>> fetchCustomers(
    String providerId, {
    int page = 0,
    int size = 20,
  }) =>
      _run(() async {
        final response = await _dioClient.get(
          '/business/$providerId/loyalty/customers',
          queryParameters: {'page': page, 'size': size},
        );
        return LoyaltyPage.fromJson(
          response.data as Map<String, dynamic>,
          (e) => LoyaltyCustomerInsight.fromJson(e),
        );
      });

  Future<LoyaltyCustomerInsight> fetchCustomer(String providerId, String userId) => _run(() async {
        final response = await _dioClient.get('/business/$providerId/loyalty/customers/$userId');
        return LoyaltyCustomerInsight.fromJson(response.data as Map<String, dynamic>);
      });

  /// [delta] positive credits points, negative debits them -- 409 if a debit
  /// would take the balance below zero. [reason] must be non-blank; the
  /// backend rejects a blank one with 400.
  Future<LoyaltyTransaction> adjustPoints(String providerId, String userId, {required int delta, required String reason}) =>
      _run(() async {
        final response = await _dioClient.post(
          '/business/$providerId/loyalty/customers/$userId/adjust',
          data: {'delta': delta, 'reason': reason},
        );
        return LoyaltyTransaction.fromJson(response.data as Map<String, dynamic>);
      });

  // ---- Rewards ----

  Future<List<LoyaltyReward>> fetchRewards(String providerId) => _run(() async {
        final response = await _dioClient.get('/business/$providerId/loyalty/rewards');
        return (response.data as List<dynamic>)
            .map((e) => LoyaltyReward.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<LoyaltyReward> createReward(String providerId, LoyaltyReward draft) => _run(() async {
        final response = await _dioClient.post('/business/$providerId/loyalty/rewards', data: draft.toRequestJson());
        return LoyaltyReward.fromJson(response.data as Map<String, dynamic>);
      });

  Future<LoyaltyReward> updateReward(String providerId, String rewardId, LoyaltyReward draft) => _run(() async {
        final response = await _dioClient.put(
          '/business/$providerId/loyalty/rewards/$rewardId',
          data: draft.toRequestJson(),
        );
        return LoyaltyReward.fromJson(response.data as Map<String, dynamic>);
      });

  Future<LoyaltyReward> activateReward(String providerId, String rewardId) => _run(() async {
        final response = await _dioClient.post('/business/$providerId/loyalty/rewards/$rewardId/activate');
        return LoyaltyReward.fromJson(response.data as Map<String, dynamic>);
      });

  Future<LoyaltyReward> deactivateReward(String providerId, String rewardId) => _run(() async {
        final response = await _dioClient.post('/business/$providerId/loyalty/rewards/$rewardId/deactivate');
        return LoyaltyReward.fromJson(response.data as Map<String, dynamic>);
      });

  /// 409 if the reward has ever been redeemed (`redemptionsCount > 0`) --
  /// callers should prefer [deactivateReward] once that's the case and
  /// surface the 409's message when the owner tries anyway.
  Future<void> deleteReward(String providerId, String rewardId) => _run(() async {
        await _dioClient.delete('/business/$providerId/loyalty/rewards/$rewardId');
      });

  // ---- Redemptions ----

  Future<LoyaltyPage<LoyaltyRedemption>> fetchRedemptions(
    String providerId, {
    int page = 0,
    int size = 20,
  }) =>
      _run(() async {
        final response = await _dioClient.get(
          '/business/$providerId/loyalty/redemptions',
          queryParameters: {'page': page, 'size': size},
        );
        return LoyaltyPage.fromJson(response.data as Map<String, dynamic>, (e) => LoyaltyRedemption.fromJson(e));
      });

  /// The checkout-time "customer shows me a code" flow -- 404 if [code]
  /// doesn't belong to this business, 409 if it's not currently ACTIVE
  /// (already applied/cancelled/expired) or the booking/customer don't
  /// match.
  Future<LoyaltyRedemption> applyRedemption(String providerId, String code, {required String bookingId}) =>
      _run(() async {
        final response = await _dioClient.post(
          '/business/$providerId/loyalty/redemptions/$code/apply',
          data: {'bookingId': bookingId},
        );
        return LoyaltyRedemption.fromJson(response.data as Map<String, dynamic>);
      });

  /// Refunds the spent points to the customer -- e.g. suspected abuse.
  Future<LoyaltyRedemption> cancelRedemption(String providerId, String id, {String? reason}) => _run(() async {
        final response = await _dioClient.post(
          '/business/$providerId/loyalty/redemptions/$id/cancel',
          data: {'reason': reason},
        );
        return LoyaltyRedemption.fromJson(response.data as Map<String, dynamic>);
      });

  /// Every call funnels through here so a 400/403/404/409 always surfaces
  /// as a [LoyaltyAdminException] carrying the backend's own `message`
  /// (see LoyaltyAdminController's Javadoc for what each status means on
  /// this surface) instead of a raw DioException -- callers show
  /// [LoyaltyAdminException.localizedMessage] rather than e.toString().
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final message = data is Map && data['message'] is String ? data['message'] as String : null;
      throw LoyaltyAdminException(statusCode: status, serverMessage: message);
    }
  }
}
