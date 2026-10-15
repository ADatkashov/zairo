import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../billing/data/billing_exception.dart';
import 'models/admin_booking.dart';
import 'models/admin_payout.dart';
import 'models/admin_provider.dart';
import 'models/admin_service.dart';
import 'models/admin_slot.dart';
import 'models/business_analytics.dart';
import 'models/dashboard_metrics.dart';
import 'models/recurring_schedule_result.dart';
import 'models/schedule_entry.dart';

/// Wraps Core's providers/services/booking REST endpoints from the owner's
/// point of view — no new backend surface beyond the two additions this
/// app needed (list-by-owner, list-by-provider), everything else reuses
/// endpoints the customer-facing app already exercises. Not final: tests
/// substitute a subclass, same pattern as the rest of the codebase.
class SalonAdminApi {
  final DioClient _dioClient;

  SalonAdminApi(this._dioClient);

  /// Returns the deposit percentage (0-100) new bookings at [providerId] will
  /// require. NO_PAYMENT → 0, FULL_PAYMENT → 100.
  Future<int> getDepositPercentage(String providerId) async {
    final response = await _dioClient.get(
      '/payment-settings',
      queryParameters: {'providerId': providerId},
    );
    final data = response.data as Map<String, dynamic>;
    switch (data['depositType']) {
      case 'FULL_PAYMENT':
        return 100;
      case 'DEPOSIT':
        if (data['depositValueType'] == 'PERCENTAGE') {
          return (data['depositValue'] as num).round();
        }
        return 0;
      default:
        return 0;
    }
  }

  Future<void> setDepositPercentage(String providerId, int percentage) async {
    final Map<String, dynamic> body;
    if (percentage <= 0) {
      body = {'depositType': 'NO_PAYMENT'};
    } else if (percentage >= 100) {
      body = {'depositType': 'FULL_PAYMENT'};
    } else {
      body = {
        'depositType': 'DEPOSIT',
        'depositValueType': 'PERCENTAGE',
        'depositValue': percentage,
      };
    }
    await _dioClient.put(
      '/payment-settings',
      queryParameters: {'providerId': providerId},
      data: body,
    );
  }

  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async {
    final response = await _dioClient.get('/users/$ownerUserId/providers');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminProvider> createProvider({
    required String ownerUserId,
    required String name,
    required String vertical,
    required String cityCode,
  }) async {
    try {
      final response = await _dioClient.post(
        '/providers',
        data: {
          'ownerUserId': ownerUserId,
          'name': name,
          'vertical': vertical,
          'cityCode': cityCode,
        },
      );
      return AdminProvider.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const BillingException(SubscriptionErrorKey.providerLimitReached);
      }
      rethrow;
    }
  }

  /// Admin-only listing, used by the moderation screen — e.g.
  /// `status: 'PENDING'` for salons awaiting approval. Not the
  /// customer-facing discovery path (that's search, which only ever
  /// surfaces ACTIVE providers).
  Future<List<AdminProvider>> listProvidersByStatus(String status) async {
    final response = await _dioClient.get('/providers', queryParameters: {'status': status});
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Admin-only — approve/suspend a provider (see backend's
  /// ProviderController.updateStatus()). This is the only way a provider
  /// ever leaves PENDING.
  Future<AdminProvider> updateProviderStatus({required String providerId, required String status}) async {
    final response = await _dioClient.patch('/providers/$providerId/status', data: {'status': status});
    return AdminProvider.fromJson(response.data as Map<String, dynamic>);
  }

  /// Owner-only (see backend's ProviderController.update()). Name,
  /// location, cover photo and city only — vertical and status aren't
  /// owner-editable. [coverPhotoUrl] is the URL StorageApi.uploadBytes
  /// already returned, not a file — this call never uploads bytes itself.
  Future<AdminProvider> updateProvider({
    required String providerId,
    required String name,
    double? latitude,
    double? longitude,
    String? coverPhotoUrl,
    String? cityCode,
  }) async {
    final response = await _dioClient.put(
      '/providers/$providerId',
      // A null cityCode keeps the business's current city on the server; it cannot be cleared, only changed.
      data: {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'coverPhotoUrl': coverPhotoUrl,
        'cityCode': cityCode,
      },
    );
    return AdminProvider.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AdminService>> listServices(String providerId, {bool includeInactive = false}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/services',
      queryParameters: {'includeInactive': includeInactive},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminService.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [catalogServiceId] is the platform-catalog service being offered — the
  /// backend requires it (and that [title] is one of its names) whenever the
  /// business's type has a catalog: businesses don't write their own services.
  Future<AdminService> createService({
    required String providerId,
    required String title,
    required int durationMinutes,
    required double price,
    required String currency,
    String? catalogServiceId,
  }) async {
    final response = await _dioClient.post(
      '/providers/$providerId/services',
      data: {
        'title': title,
        'durationMinutes': durationMinutes,
        'price': price,
        'currency': currency,
        'catalogServiceId': ?catalogServiceId,
      },
    );
    return AdminService.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminService> updateService({
    required String serviceId,
    required String title,
    required int durationMinutes,
    required double price,
    required String currency,
    String? catalogServiceId,
  }) async {
    final response = await _dioClient.put(
      '/services/$serviceId',
      data: {
        'title': title,
        'durationMinutes': durationMinutes,
        'price': price,
        'currency': currency,
        'catalogServiceId': ?catalogServiceId,
      },
    );
    return AdminService.fromJson(response.data as Map<String, dynamic>);
  }

  /// Soft-delete — the service stays referenced by past bookings, just
  /// stops showing up in the salon's active listings (see backend's
  /// ServiceOffering.deactivate()).
  Future<void> deactivateService(String serviceId) {
    return _dioClient.delete('/services/$serviceId');
  }

  /// Owner-only: links the offering to a master-catalog service (PATCH
  /// /services/{id}/catalog-link) — that is how a service picked from the
  /// platform-managed catalog is tied to its catalog entry.
  Future<AdminService> linkCatalogService({
    required String serviceId,
    required String? catalogServiceId,
  }) async {
    final response = await _dioClient.patch(
      '/services/$serviceId/catalog-link',
      data: {'catalogServiceId': catalogServiceId},
    );
    return AdminService.fromJson(response.data as Map<String, dynamic>);
  }

  /// Owner-only, idempotent — undoes deactivateService().
  Future<AdminService> reactivateService(String serviceId) async {
    final response = await _dioClient.post('/services/$serviceId/reactivate');
    return AdminService.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AdminSlot>> listSlots(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/availability-slots');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminSlot.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminSlot> createSlot({
    required String providerId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final response = await _dioClient.post(
      '/providers/$providerId/availability-slots',
      data: {
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
      },
    );
    return AdminSlot.fromJson(response.data as Map<String, dynamic>);
  }

  /// Only an OPEN slot can be removed — see backend's AvailabilitySlotController.delete().
  Future<void> deleteSlot(String slotId) {
    return _dioClient.delete('/availability-slots/$slotId');
  }

  /// [daysOfWeek] uses [DateTime.weekday] values (1=Monday..7=Sunday).
  /// [zoneId] defaults to the device's current fixed UTC offset (e.g.
  /// "+06:00") — this project has no IANA timezone data on the Flutter
  /// side, but Java's ZoneId.of accepts a fixed-offset string just as
  /// validly as "Asia/Almaty", so this is a real zone, not a placeholder.
  Future<RecurringScheduleResult> createRecurringSchedule({
    required String providerId,
    required List<int> daysOfWeek,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int slotDurationMinutes,
    required int breakMinutes,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    List<DateTime> holidays = const [],
  }) async {
    try {
      final response = await _dioClient.post(
        '/providers/$providerId/availability-slots/recurring',
        data: {
          'daysOfWeek': daysOfWeek.map(_dayOfWeekName).toList(),
          'startTime': _formatTime(startHour, startMinute),
          'endTime': _formatTime(endHour, endMinute),
          'slotDurationMinutes': slotDurationMinutes,
          'breakMinutes': breakMinutes,
          'rangeStart': _formatDate(rangeStart),
          'rangeEnd': _formatDate(rangeEnd),
          'holidays': holidays.map(_formatDate).toList(),
          'zoneId': _localZoneOffset(),
        },
      );
      return RecurringScheduleResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const BillingException(SubscriptionErrorKey.featureRequiresUpgrade);
      }
      rethrow;
    }
  }

  static const _dayOfWeekNames = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  static String _dayOfWeekName(int weekday) => _dayOfWeekNames[weekday - 1];

  static String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _localZoneOffset() {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.abs().inHours.toString().padLeft(2, '0');
    final minutes = (offset.abs().inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }

  Future<List<AdminBooking>> listBookings(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/bookings');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminBooking.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The provider's bookings whose slot starts in [from, to) (UTC), oldest
  /// first, each with its slot's start and end. Cancelled ones are included.
  Future<List<ScheduleEntry>> fetchSchedule(String providerId, {required DateTime from, required DateTime to}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/schedule',
      queryParameters: {'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminBooking> completeBooking(String bookingId) async {
    final response = await _dioClient.post('/bookings/$bookingId/complete');
    return AdminBooking.fromJson(response.data as Map<String, dynamic>);
  }

  /// The business's own settlement/payout visibility — see
  /// backend's BusinessPayoutController (owner-only; a business can never
  /// see another business's payouts). One row per COMPLETED booking whose
  /// share is payable; a cancelled/refunded booking never has one at all.
  Future<List<AdminPayout>> listPayouts(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/payouts');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminPayout.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DashboardMetrics> fetchDashboardMetrics(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/dashboard');
    return DashboardMetrics.fromJson(response.data as Map<String, dynamic>);
  }

  /// [from]/[to] are omitted when null -- the backend then defaults to the
  /// current calendar month through now (see BusinessAnalyticsService).
  Map<String, dynamic> _rangeParams(DateTime? from, DateTime? to) {
    return {
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
  }

  Future<BusinessAnalyticsOverview> fetchAnalyticsOverview(String providerId, {DateTime? from, DateTime? to}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/analytics/overview',
      queryParameters: _rangeParams(from, to),
    );
    return BusinessAnalyticsOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BusinessAnalyticsRevenue> fetchAnalyticsRevenue(String providerId, {DateTime? from, DateTime? to}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/analytics/revenue',
      queryParameters: _rangeParams(from, to),
    );
    return BusinessAnalyticsRevenue.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BusinessAnalyticsBookings> fetchAnalyticsBookings(String providerId, {DateTime? from, DateTime? to}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/analytics/bookings',
      queryParameters: _rangeParams(from, to),
    );
    return BusinessAnalyticsBookings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SmartFillPerformance> fetchAnalyticsSmartFill(String providerId, {DateTime? from, DateTime? to}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/analytics/smart-fill',
      queryParameters: _rangeParams(from, to),
    );
    return SmartFillPerformance.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BusinessAnalyticsCustomers> fetchAnalyticsCustomers(String providerId, {DateTime? from, DateTime? to}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/analytics/customers',
      queryParameters: _rangeParams(from, to),
    );
    return BusinessAnalyticsCustomers.fromJson(response.data as Map<String, dynamic>);
  }

  /// Not date-scoped on the server -- "what needs attention right now".
  Future<BusinessActionCenter> fetchAnalyticsActions(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/analytics/actions');
    return BusinessActionCenter.fromJson(response.data as Map<String, dynamic>);
  }

  /// The Action Center's Smart Fill drill-down -- every campaign still
  /// actively trying to recover a slot. Not date-scoped.
  Future<List<SmartFillCampaignSummary>> fetchActiveSmartFillCampaigns(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/analytics/smart-fill/active');
    final data = response.data as List<dynamic>;
    return data.map((e) => SmartFillCampaignSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The Action Center's rebook-opportunity/retention-risk drill-down.
  /// [retentionStatus] narrows to customers currently in that state; omit
  /// for every customer. Not date-scoped.
  Future<List<CustomerListItem>> fetchCustomerList(String providerId, {CustomerRetentionStatus? retentionStatus}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/analytics/customers/list',
      queryParameters: {if (retentionStatus != null) 'retentionStatus': retentionStatus.toWire()},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => CustomerListItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
