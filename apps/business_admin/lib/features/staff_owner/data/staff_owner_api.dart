import 'package:core_network/core_network.dart';

import 'models/needs_attention.dart';

/// The owner's side of staff-related appointments (backend `StaffOwnerController`). Not final:
/// tests substitute a subclass overriding these methods — same pattern as the other APIs.
class StaffOwnerApi {
  final DioClient _dioClient;

  StaffOwnerApi(this._dioClient);

  Future<List<NeedsAttentionItem>> needsAttention(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/appointments/needs-attention');
    final data = response.data as List<dynamic>;
    return data.map((e) => NeedsAttentionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Cancels the appointment: the slot is released, a paid booking is refunded and the customer is
  /// notified. Only the owner can do this — staff can only ask.
  Future<void> cancelAppointment(String providerId, String bookingId, {String? reason}) {
    return _dioClient.post(
      '/providers/$providerId/appointments/$bookingId/cancel',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }
}
