import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../billing/data/billing_exception.dart';
import 'models/admin_booking.dart';
import 'models/admin_provider.dart';
import 'models/admin_service.dart';
import 'models/admin_slot.dart';
import 'models/dashboard_metrics.dart';
import 'models/recurring_schedule_result.dart';

/// Wraps Core's providers/services/booking REST endpoints from the owner's
/// point of view — no new backend surface beyond the two additions this
/// app needed (list-by-owner, list-by-provider), everything else reuses
/// endpoints the customer-facing app already exercises. Not final: tests
/// substitute a subclass, same pattern as the rest of the codebase.
class SalonAdminApi {
  final DioClient _dioClient;

  SalonAdminApi(this._dioClient);

  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async {
    final response = await _dioClient.get('/users/$ownerUserId/providers');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminProvider> createProvider({
    required String ownerUserId,
    required String name,
    required String vertical,
  }) async {
    try {
      final response = await _dioClient.post(
        '/providers',
        data: {'ownerUserId': ownerUserId, 'name': name, 'vertical': vertical},
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

  /// Owner-only (see backend's ProviderController.update()). Name and
  /// location only — vertical and status aren't owner-editable.
  Future<AdminProvider> updateProvider({
    required String providerId,
    required String name,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dioClient.put(
      '/providers/$providerId',
      data: {'name': name, 'latitude': latitude, 'longitude': longitude},
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

  Future<AdminService> createService({
    required String providerId,
    required String title,
    required int durationMinutes,
    required double price,
    required String currency,
  }) async {
    final response = await _dioClient.post(
      '/providers/$providerId/services',
      data: {
        'title': title,
        'durationMinutes': durationMinutes,
        'price': price,
        'currency': currency,
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
  }) async {
    final response = await _dioClient.put(
      '/services/$serviceId',
      data: {
        'title': title,
        'durationMinutes': durationMinutes,
        'price': price,
        'currency': currency,
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

  Future<AdminBooking> completeBooking(String bookingId) async {
    final response = await _dioClient.post('/bookings/$bookingId/complete');
    return AdminBooking.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DashboardMetrics> fetchDashboardMetrics(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/dashboard');
    return DashboardMetrics.fromJson(response.data as Map<String, dynamic>);
  }
}
