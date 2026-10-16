import 'package:core_network/core_network.dart';

import 'models/waitlist_entry.dart';

/// Backend's waitlist (backend/waitlist/.../WaitlistController.java): "tell me when a time frees up at this
/// business". Not final: tests substitute a subclass overriding these methods instead of mocking Dio.
class WaitlistApi {
  final DioClient _dioClient;

  WaitlistApi(this._dioClient);

  /// The user's active entries, by business id.
  Future<Map<String, WaitlistEntry>> listEntries(String userId) async {
    final response = await _dioClient.get('/users/$userId/waitlist');
    final data = response.data as List<dynamic>;
    final entries = data.map((e) => WaitlistEntry.fromJson(e as Map<String, dynamic>));
    return {for (final entry in entries) entry.providerId: entry};
  }

  /// Joins for one local calendar [day], or for any time when null. Idempotent on the backend — joining again only
  /// changes the wanted day.
  Future<void> join(String userId, String providerId, {DateTime? day}) async {
    await _dioClient.put(
      '/users/$userId/waitlist/$providerId',
      data: day == null
          ? null
          : {
              'from': DateTime(day.year, day.month, day.day).toUtc().toIso8601String(),
              'to': DateTime(day.year, day.month, day.day + 1).toUtc().toIso8601String(),
            },
    );
  }

  /// Idempotent on the backend — safe when the user is not on the list.
  Future<void> leave(String userId, String providerId) async {
    await _dioClient.delete('/users/$userId/waitlist/$providerId');
  }
}
