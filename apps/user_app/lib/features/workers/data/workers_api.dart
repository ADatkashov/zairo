import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'models/booking_worker.dart';
import 'models/favorite_worker.dart';
import 'models/top_worker.dart';
import 'models/worker_profile.dart';

/// Not final: tests substitute a subclass overriding these methods instead of
/// mocking Dio — same pattern as AdsApi/StaffApi.
class WorkersApi {
  final DioClient _dioClient;

  WorkersApi(this._dioClient);

  /// [cityCode] narrows the list to that city (plus businesses that have not set one); null/empty = everywhere.
  Future<List<TopWorker>> listTop({int limit = 10, String? cityCode}) async {
    final response = await _dioClient.get(
      '/workers/top',
      queryParameters: {'limit': limit, if (cityCode != null && cityCode.isNotEmpty) 'city': cityCode},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => TopWorker.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkerProfile> getProfile(String workerId) async {
    final response = await _dioClient.get('/workers/$workerId');
    return WorkerProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Who the customer's booking is with; the backend answers 404 when it has no named person.
  Future<BookingWorker> getBookingWorker(String bookingId) async {
    final response = await _dioClient.get('/bookings/$bookingId/worker');
    return BookingWorker.fromJson(response.data as Map<String, dynamic>);
  }

  /// The customer's "My masters", newest first.
  Future<List<FavoriteWorker>> listFavoriteWorkers(String userId) async {
    final response = await _dioClient.get('/users/$userId/favorite-workers');
    final data = response.data as List<dynamic>;
    return data.map((e) => FavoriteWorker.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// A 404 here means "not on the list" — a normal state, not an error.
  Future<bool> isFavoriteWorker(String userId, String workerId) async {
    try {
      await _dioClient.get('/users/$userId/favorite-workers/$workerId');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      rethrow;
    }
  }

  /// Idempotent on the backend.
  Future<void> addFavoriteWorker(String userId, String workerId) async {
    await _dioClient.post('/users/$userId/favorite-workers/$workerId');
  }

  /// Idempotent on the backend.
  Future<void> removeFavoriteWorker(String userId, String workerId) async {
    await _dioClient.delete('/users/$userId/favorite-workers/$workerId');
  }
}
