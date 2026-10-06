import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../billing/data/billing_exception.dart';
import 'models/admin_cleaner.dart';
import 'models/admin_cleaner_service_summary.dart';

/// Wraps the vertical-cleaning module's admin-facing endpoints
/// (backend/vertical-cleaning/.../CleanerController.java). Only meaningful
/// for providers in the cleaning vertical — the salon screen only calls
/// this when AdminProvider.vertical == 'cleaning'.
class CleaningAdminApi {
  final DioClient _dioClient;

  CleaningAdminApi(this._dioClient);

  Future<List<AdminCleaner>> listCleaners(String providerId, {bool includeInactive = false}) async {
    final response = await _dioClient.get(
      '/cleaning/providers/$providerId/cleaners',
      queryParameters: {'includeInactive': includeInactive},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminCleaner.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Adds an existing registered user as a cleaner (POST .../from-user) — name and
  /// photo come from their profile, nothing is typed in.
  Future<AdminCleaner> createCleanerFromUser({required String providerId, required String userId}) async {
    try {
      final response = await _dioClient.post(
        '/cleaning/providers/$providerId/cleaners/from-user',
        data: {'userId': userId},
      );
      return AdminCleaner.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const BillingException(SubscriptionErrorKey.staffLimitReached);
      }
      rethrow;
    }
  }

  Future<List<AdminCleanerServiceSummary>> listCleanerServices(String cleanerId) async {
    final response = await _dioClient.get('/cleaning/cleaners/$cleanerId/services');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminCleanerServiceSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> linkService({required String cleanerId, required String serviceId}) {
    return _dioClient.post('/cleaning/cleaners/$cleanerId/services/$serviceId');
  }

  Future<void> unlinkService({required String cleanerId, required String serviceId}) {
    return _dioClient.delete('/cleaning/cleaners/$cleanerId/services/$serviceId');
  }

  /// Owner-only — replaces the cleaner's photo (null removes it).
  Future<AdminCleaner> updateCleanerPhoto(String cleanerId, String? photoUrl) async {
    final response = await _dioClient.put('/cleaning/cleaners/$cleanerId/photo', data: {'photoUrl': photoUrl});
    return AdminCleaner.fromJson(response.data as Map<String, dynamic>);
  }

  /// Soft-delete — see backend's Cleaner.deactivate(). Deactivated cleaners
  /// stop appearing in provider listings (both here and in the customer app).
  Future<void> deactivateCleaner(String cleanerId) {
    return _dioClient.delete('/cleaning/cleaners/$cleanerId');
  }

  /// Owner-only, idempotent — undoes deactivateCleaner().
  Future<AdminCleaner> reactivateCleaner(String cleanerId) async {
    final response = await _dioClient.post('/cleaning/cleaners/$cleanerId/reactivate');
    return AdminCleaner.fromJson(response.data as Map<String, dynamic>);
  }
}
