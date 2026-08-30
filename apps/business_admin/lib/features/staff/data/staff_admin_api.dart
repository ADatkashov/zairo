import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../billing/data/billing_exception.dart';
import 'models/admin_staff.dart';
import 'models/admin_staff_service_summary.dart';

/// Wraps the generic `staff` module's admin-facing endpoints
/// (backend/staff/.../StaffController.java). Unlike BeautyAdminApi/
/// AutoAdminApi/CleaningAdminApi, this works for a provider in ANY
/// category — the salon screen falls back to this whenever
/// AdminProvider.vertical isn't one of the three hardcoded verticals with
/// their own staff module.
class StaffAdminApi {
  final DioClient _dioClient;

  StaffAdminApi(this._dioClient);

  Future<List<AdminStaff>> listStaff(String providerId, {bool includeInactive = false}) async {
    final response = await _dioClient.get(
      '/providers/$providerId/staff',
      queryParameters: {'includeInactive': includeInactive},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminStaff.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminStaff> createStaff({
    required String providerId,
    required String displayName,
    String? bio,
  }) async {
    try {
      final response = await _dioClient.post(
        '/providers/$providerId/staff',
        data: {'displayName': displayName, 'bio': bio, 'photoUrl': null},
      );
      return AdminStaff.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const BillingException(SubscriptionErrorKey.staffLimitReached);
      }
      rethrow;
    }
  }

  Future<List<AdminStaffServiceSummary>> listStaffServices(String staffId) async {
    final response = await _dioClient.get('/staff/$staffId/services');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminStaffServiceSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> linkService({required String staffId, required String serviceId}) {
    return _dioClient.post('/staff/$staffId/services/$serviceId');
  }

  Future<void> unlinkService({required String staffId, required String serviceId}) {
    return _dioClient.delete('/staff/$staffId/services/$serviceId');
  }

  /// Soft-delete — see backend's Staff.deactivate(). Deactivated staff stop
  /// appearing in provider listings (both here and in the customer app).
  Future<void> deactivateStaff(String staffId) {
    return _dioClient.delete('/staff/$staffId');
  }

  /// Owner-only, idempotent — undoes deactivateStaff().
  Future<AdminStaff> reactivateStaff(String staffId) async {
    final response = await _dioClient.post('/staff/$staffId/reactivate');
    return AdminStaff.fromJson(response.data as Map<String, dynamic>);
  }
}
