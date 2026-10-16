import 'package:core_network/core_network.dart';

/// Backend's waitlist (backend/waitlist/.../WaitlistController.java): "tell me when a time frees up at this
/// business". Not final: tests substitute a subclass overriding these methods instead of mocking Dio.
class WaitlistApi {
  final DioClient _dioClient;

  WaitlistApi(this._dioClient);

  /// The ids of the businesses the user is waiting for (active entries only).
  Future<Set<String>> waitingProviderIds(String userId) async {
    final response = await _dioClient.get('/users/$userId/waitlist');
    final data = response.data as List<dynamic>;
    return {for (final entry in data) (entry as Map<String, dynamic>)['providerId'] as String};
  }

  /// Any time will do — no body. Idempotent on the backend.
  Future<void> join(String userId, String providerId) async {
    await _dioClient.put('/users/$userId/waitlist/$providerId');
  }

  /// Idempotent on the backend — safe when the user is not on the list.
  Future<void> leave(String userId, String providerId) async {
    await _dioClient.delete('/users/$userId/waitlist/$providerId');
  }
}
