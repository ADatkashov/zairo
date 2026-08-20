import 'package:core_network/core_network.dart';

import 'models/admin_booking.dart';
import 'models/admin_provider.dart';
import 'models/admin_service.dart';
import 'models/admin_slot.dart';

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
    final response = await _dioClient.post(
      '/providers',
      data: {'ownerUserId': ownerUserId, 'name': name, 'vertical': vertical},
    );
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

  Future<List<AdminBooking>> listBookings(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/bookings');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminBooking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminBooking> completeBooking(String bookingId) async {
    final response = await _dioClient.post('/bookings/$bookingId/complete');
    return AdminBooking.fromJson(response.data as Map<String, dynamic>);
  }
}
