import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'invitations_api.dart';
import 'models/staff_invitation.dart';
import 'models/user_lookup.dart';

/// Finds registered people for the "add a master / mechanic / cleaner / staff
/// member" dialogs (backend `GET /users/lookup`).
class UserLookupApi {
  final DioClient _dioClient;

  UserLookupApi(this._dioClient);

  /// Exact phone match; null when nobody is registered with it.
  Future<UserLookup?> lookupByPhone(String phone) async {
    try {
      final response = await _dioClient.get('/users/lookup', queryParameters: {'phone': phone});
      return UserLookup.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final userLookupApiProvider = Provider<UserLookupApi>((ref) {
  return UserLookupApi(ref.watch(dioClientProvider));
});

final invitationsApiProvider = Provider<InvitationsApi>((ref) {
  return InvitationsApi(ref.watch(dioClientProvider));
});

/// A business's open invitations, refreshed after inviting / cancelling.
final pendingInvitationsProvider = FutureProvider.autoDispose.family<List<StaffInvitation>, String>((ref, providerId) {
  return ref.watch(invitationsApiProvider).listPending(providerId);
});
