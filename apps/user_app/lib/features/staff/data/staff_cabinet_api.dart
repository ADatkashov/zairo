import 'package:core_network/core_network.dart';

import 'models/staff_cabinet.dart';

/// The staff member's own cabinet (backend `StaffPortalController`). Not
/// final: tests substitute a subclass overriding these methods — same
/// pattern as StaffApi.
class StaffCabinetApi {
  final DioClient _dioClient;

  StaffCabinetApi(this._dioClient);

  Future<List<StaffMembership>> memberships() async {
    final response = await _dioClient.get('/me/staff-memberships');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => StaffMembership.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [scope]: `ALL`, `UPCOMING` or `HISTORY`.
  Future<List<StaffAppointment>> appointments(
    String staffId, {
    String scope = 'ALL',
  }) async {
    final response = await _dioClient.get(
      '/me/staff/$staffId/appointments',
      queryParameters: {'scope': scope},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => StaffAppointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> accept(String staffId, String bookingId) =>
      _dioClient.post('/me/staff/$staffId/appointments/$bookingId/accept');

  /// "I can't attend": a request to the business owner. Never a cancellation — the
  /// booking and the customer's payment stay as they are until the owner decides.
  Future<void> cannotAttend(
    String staffId,
    String bookingId, {
    String? reason,
  }) => _dioClient.post(
    '/me/staff/$staffId/appointments/$bookingId/cannot-attend',
    data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
  );

  Future<void> complete(String staffId, String bookingId) =>
      _dioClient.post('/me/staff/$staffId/appointments/$bookingId/complete');

  Future<void> markNoShow(String staffId, String bookingId) =>
      _dioClient.post('/me/staff/$staffId/appointments/$bookingId/no-show');

  Future<StaffRating> rating(String staffId) async {
    final response = await _dioClient.get('/me/staff/$staffId/rating');
    return StaffRating.fromJson(response.data as Map<String, dynamic>);
  }
}
