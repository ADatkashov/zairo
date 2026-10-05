import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../billing/data/billing_exception.dart';
import 'models/admin_mechanic.dart';
import 'models/admin_mechanic_service_summary.dart';

/// Wraps the vertical-auto module's admin-facing endpoints
/// (backend/vertical-auto/.../MechanicController.java). Only meaningful for
/// providers in the auto vertical — the salon screen only calls this when
/// AdminProvider.vertical == 'auto'.
class AutoAdminApi {
  final DioClient _dioClient;

  AutoAdminApi(this._dioClient);

  Future<List<AdminMechanic>> listMechanics(String providerId, {bool includeInactive = false}) async {
    final response = await _dioClient.get(
      '/auto/providers/$providerId/mechanics',
      queryParameters: {'includeInactive': includeInactive},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminMechanic.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Adds an existing registered user as a mechanic (POST .../from-user) — name and
  /// photo come from their profile, nothing is typed in.
  Future<AdminMechanic> createMechanicFromUser({required String providerId, required String userId}) async {
    try {
      final response = await _dioClient.post(
        '/auto/providers/$providerId/mechanics/from-user',
        data: {'userId': userId},
      );
      return AdminMechanic.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const BillingException(SubscriptionErrorKey.staffLimitReached);
      }
      rethrow;
    }
  }

  Future<List<AdminMechanicServiceSummary>> listMechanicServices(String mechanicId) async {
    final response = await _dioClient.get('/auto/mechanics/$mechanicId/services');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminMechanicServiceSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> linkService({required String mechanicId, required String serviceId}) {
    return _dioClient.post('/auto/mechanics/$mechanicId/services/$serviceId');
  }

  Future<void> unlinkService({required String mechanicId, required String serviceId}) {
    return _dioClient.delete('/auto/mechanics/$mechanicId/services/$serviceId');
  }

  /// Owner-only — replaces the mechanic's photo (null removes it).
  Future<AdminMechanic> updateMechanicPhoto(String mechanicId, String? photoUrl) async {
    final response = await _dioClient.put('/auto/mechanics/$mechanicId/photo', data: {'photoUrl': photoUrl});
    return AdminMechanic.fromJson(response.data as Map<String, dynamic>);
  }

  /// Soft-delete — see backend's Mechanic.deactivate(). Deactivated mechanics
  /// stop appearing in provider listings (both here and in the customer app).
  Future<void> deactivateMechanic(String mechanicId) {
    return _dioClient.delete('/auto/mechanics/$mechanicId');
  }

  /// Owner-only, idempotent — undoes deactivateMechanic().
  Future<AdminMechanic> reactivateMechanic(String mechanicId) async {
    final response = await _dioClient.post('/auto/mechanics/$mechanicId/reactivate');
    return AdminMechanic.fromJson(response.data as Map<String, dynamic>);
  }
}
