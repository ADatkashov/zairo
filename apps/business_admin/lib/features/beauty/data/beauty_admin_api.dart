import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../billing/data/billing_exception.dart';
import 'models/admin_master.dart';
import 'models/admin_master_service_summary.dart';
import 'models/admin_portfolio_item.dart';
import 'models/user_lookup.dart';

/// Wraps the vertical-beauty module's admin-facing endpoints
/// (backend/vertical-beauty/.../MasterController.java). Only meaningful for
/// providers in the beauty vertical — the salon screen only calls this when
/// AdminProvider.vertical == 'beauty'.
class BeautyAdminApi {
  final DioClient _dioClient;

  BeautyAdminApi(this._dioClient);

  Future<List<AdminMaster>> listMasters(String providerId, {bool includeInactive = false}) async {
    final response = await _dioClient.get(
      '/beauty/providers/$providerId/masters',
      queryParameters: {'includeInactive': includeInactive},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminMaster.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Finds a registered user by exact phone (GET /users/lookup); null when
  /// nobody is registered with it.
  Future<UserLookup?> lookupUserByPhone(String phone) async {
    try {
      final response = await _dioClient.get('/users/lookup', queryParameters: {'phone': phone});
      return UserLookup.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Adds an existing registered user as a master — name and photo come from
  /// their profile, nothing is typed in.
  Future<AdminMaster> createMasterFromUser({required String providerId, required String userId}) async {
    try {
      final response = await _dioClient.post(
        '/beauty/providers/$providerId/masters/from-user',
        data: {'userId': userId},
      );
      return AdminMaster.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const BillingException(SubscriptionErrorKey.staffLimitReached);
      }
      rethrow;
    }
  }

  Future<AdminMaster> createMaster({
    required String providerId,
    required String displayName,
    String? bio,
  }) async {
    try {
      final response = await _dioClient.post(
        '/beauty/providers/$providerId/masters',
        data: {'displayName': displayName, 'bio': bio, 'photoUrl': null},
      );
      return AdminMaster.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const BillingException(SubscriptionErrorKey.staffLimitReached);
      }
      rethrow;
    }
  }

  Future<List<AdminPortfolioItem>> listPortfolio(String masterId) async {
    final response = await _dioClient.get('/beauty/masters/$masterId/portfolio');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminPortfolioItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminPortfolioItem> addPortfolioItem({
    required String masterId,
    required String imageUrl,
    String? caption,
  }) async {
    final response = await _dioClient.post(
      '/beauty/masters/$masterId/portfolio',
      data: {'imageUrl': imageUrl, 'caption': caption},
    );
    return AdminPortfolioItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AdminMasterServiceSummary>> listMasterServices(String masterId) async {
    final response = await _dioClient.get('/beauty/masters/$masterId/services');
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminMasterServiceSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> linkService({required String masterId, required String serviceId}) {
    return _dioClient.post('/beauty/masters/$masterId/services/$serviceId');
  }

  Future<void> unlinkService({required String masterId, required String serviceId}) {
    return _dioClient.delete('/beauty/masters/$masterId/services/$serviceId');
  }

  /// Owner-only — replaces the master's photo (null removes it).
  Future<AdminMaster> updateMasterPhoto(String masterId, String? photoUrl) async {
    final response = await _dioClient.put('/beauty/masters/$masterId/photo', data: {'photoUrl': photoUrl});
    return AdminMaster.fromJson(response.data as Map<String, dynamic>);
  }

  /// Soft-delete — see backend's Master.deactivate(). Deactivated masters
  /// stop appearing in provider listings (both here and in the customer app).
  Future<void> deactivateMaster(String masterId) {
    return _dioClient.delete('/beauty/masters/$masterId');
  }

  /// Owner-only, idempotent — undoes deactivateMaster().
  Future<AdminMaster> reactivateMaster(String masterId) async {
    final response = await _dioClient.post('/beauty/masters/$masterId/reactivate');
    return AdminMaster.fromJson(response.data as Map<String, dynamic>);
  }
}
