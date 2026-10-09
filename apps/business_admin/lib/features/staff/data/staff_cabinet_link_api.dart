import 'package:core_network/core_network.dart';

/// Whether the signed-in owner also works as staff somewhere (backend
/// `GET /me/staff-memberships`). The cabinet itself lives in the consumer app
/// (apps/user_app); this app only needs to know if a link to it is relevant.
class StaffCabinetLinkApi {
  final DioClient _dioClient;

  StaffCabinetLinkApi(this._dioClient);

  /// Total of upcoming appointments waiting for the person's acceptance across
  /// every business they work at; null when they aren't staff anywhere.
  Future<int?> pendingAppointments() async {
    final response = await _dioClient.get('/me/staff-memberships');
    final data = response.data as List<dynamic>;
    if (data.isEmpty) return null;
    return data.fold<int>(0, (sum, e) => sum + ((e as Map<String, dynamic>)['pendingCount'] as num).toInt());
  }
}
