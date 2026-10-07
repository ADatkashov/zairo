import 'package:core_network/core_network.dart';

import 'models/change_request.dart';

/// The customer's answers when their person can't make it (backend `WorkerChangeController`).
/// Not final: tests substitute a subclass overriding these methods.
class ChangeRequestApi {
  final DioClient _dioClient;

  ChangeRequestApi(this._dioClient);

  Future<List<ChangeRequest>> list() async {
    final response = await _dioClient.get('/me/change-requests');
    final data = response.data as List<dynamic>;
    return data.map((e) => ChangeRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> replace(String bookingId, String workerId) => _respond(bookingId, {'choice': 'REPLACE', 'workerId': workerId});

  Future<void> move(String bookingId, String slotId) => _respond(bookingId, {'choice': 'MOVE', 'slotId': slotId});

  /// Cancels with a refund.
  Future<void> cancel(String bookingId) => _respond(bookingId, {'choice': 'CANCEL'});

  Future<void> _respond(String bookingId, Map<String, dynamic> body) =>
      _dioClient.post('/me/change-requests/$bookingId/respond', data: body);
}
