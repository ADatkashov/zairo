import 'package:core_network/core_network.dart';

import 'models/staff_invitation.dart';

/// Invitations for people who have no account yet: once they verify the invited
/// phone they join the business (backend `invitations` module).
class InvitationsApi {
  final DioClient _dioClient;

  InvitationsApi(this._dioClient);

  Future<StaffInvitation> invite({required String providerId, required String phone}) async {
    final response = await _dioClient.post('/providers/$providerId/staff-invitations', data: {'phone': phone});
    return StaffInvitation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<StaffInvitation>> listPending(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/staff-invitations');
    final data = response.data as List<dynamic>;
    return data.map((e) => StaffInvitation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancel(String invitationId) {
    return _dioClient.delete('/staff-invitations/$invitationId');
  }
}
